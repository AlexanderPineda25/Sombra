## Autómata Finito No determinista con transiciones ε (AFN-ε), construido a
## partir de expresiones regulares con el método de Thompson.
##
## Definición formal: N = (Q, Σ, Δ, q0, F), con Δ : Q × (Σ ∪ {ε}) → P(Q).
##
## Sintaxis de las ER que entiende (la misma de los analizadores léxicos):
##   ab      concatenación          a|b     unión
##   a*      cero o más (Kleene)    a+      una o más     a?   opcional
##   (a)     agrupación             [a-z_]  clase         [^"\n]  clase negada
##   \x      carácter literal (\n salto de línea, \t tabulador)
##
## La propia ER se analiza con una gramática (descenso recursivo).
##
## Cada transición lleva un CONJUNTO de caracteres (índice en `conjuntos`) o
## ε (-1). Así una clase como [a-z] es una sola arista y no 26.
class_name AFN
extends RefCounted

const EPSILON := -1
const EBNF := """union = concat ('|' concat)*
concat = repet repet*
repet = atomo ('*' | '+' | '?')*
atomo = '(' union ')' | '[' clase ']' | '\\' car | car"""

var trans: Array = []          ## trans[q] = [[conjunto, destino], ...]
var conjuntos: Array = []      ## {"neg": bool, "chars": String}
var inicial := 0
var finales := {}              ## estado -> [token, prioridad]
var error := ""
var ast_reglas: Array[Dictionary] = []
var ultimo_ast: Dictionary = {}

# estado del analizador de la ER
var _er := ""
var _i := 0


func nuevo_estado() -> int:
	trans.append([])
	return trans.size() - 1


func arista(desde: int, conjunto: int, hasta: int) -> void:
	trans[desde].append([conjunto, hasta])


func num_estados() -> int:
	return trans.size()


func num_transiciones() -> int:
	var n := 0
	for t in trans:
		n += t.size()
	return n


static func pertenece(conj: Dictionary, c: String) -> bool:
	return (conj["chars"].find(c) >= 0) != conj["neg"]


# ---------------------------------------------------------------------- #
# Construcción
# ---------------------------------------------------------------------- #
## Une varias ER en un solo AFN: un estado inicial nuevo con ε hacia cada una.
## `reglas` = [[token, er], ...]; el orden es la prioridad (la primera gana).
static func desde_reglas(reglas: Array) -> AFN:
	var n := AFN.new()
	n.inicial = n.nuevo_estado()
	for k in reglas.size():
		var frag := n.agregar_er(reglas[k][1])
		if n.error != "":
			n.error = "regla %s: %s" % [reglas[k][0], n.error]
			return n
		n.ast_reglas.append(n.ultimo_ast)
		n.arista(n.inicial, EPSILON, frag[0])
		n.finales[frag[1]] = [reglas[k][0], k]
	return n


## Construye el fragmento de Thompson de una ER. Devuelve [inicio, fin].
func agregar_er(er: String) -> Array:
	_er = er
	_i = 0
	var frag := _union()
	ultimo_ast = frag[2]
	if _i < _er.length() and error == "":
		error = "carácter inesperado '%s' en la posición %d" % [_er[_i], _i]
	return frag.slice(0, 2)


func _ver() -> String:
	return _er[_i] if _i < _er.length() else ""


func _union() -> Array:
	var izq := _concat()
	while _ver() == "|":
		_i += 1
		var der := _concat()
		# Thompson: nuevo inicio con ε a ambas ramas, ambas ε a un nuevo fin
		var s := nuevo_estado()
		var f := nuevo_estado()
		arista(s, EPSILON, izq[0])
		arista(s, EPSILON, der[0])
		arista(izq[1], EPSILON, f)
		arista(der[1], EPSILON, f)
		izq = [s, f, {"texto": "Unión |", "hijos": [izq[2], der[2]]}]
	return izq


func _concat() -> Array:
	var frag := _repet()
	var partes := [frag[2]]
	while _ver() != "" and _ver() != "|" and _ver() != ")":
		var sig := _repet()
		arista(frag[1], EPSILON, sig[0])      # concatenación: ε del fin al inicio
		frag[1] = sig[1]
		partes.append(sig[2])
	if partes.size() > 1:
		frag[2] = {"texto": "Concatenación", "hijos": partes}
	return frag


func _repet() -> Array:
	var frag := _atomo()
	while _ver() in ["*", "+", "?"]:
		var op := _ver()
		_i += 1
		var s := nuevo_estado()
		var f := nuevo_estado()
		arista(s, EPSILON, frag[0])
		arista(frag[1], EPSILON, f)
		if op != "+":
			arista(s, EPSILON, f)            # cero repeticiones
		if op != "?":
			arista(frag[1], EPSILON, frag[0])  # volver a repetir
		frag = [s, f, {"texto": "Repetición " + op, "hijos": [frag[2]]}]
	return frag


func _atomo() -> Array:
	var c := _ver()
	if c == "":
		error = "la expresión termina antes de tiempo"
		return [nuevo_estado(), nuevo_estado(), {"texto": "Operando incompleto"}]
	var inicio := _i
	_i += 1
	if c == "(":
		var frag := _union()
		if _ver() != ")":
			error = "falta ')'"
		_i += 1
		return frag
	var conj := {"neg": false, "chars": ""}
	if c == "[":
		if _ver() == "^":
			conj["neg"] = true
			_i += 1
		while _ver() != "]":
			if _ver() == "":
				error = "falta ']'"
				break
			var a := _literal()
			if _ver() == "-" and _i + 1 < _er.length() and _er[_i + 1] != "]":
				_i += 1
				var b := _literal()
				for code in range(a.unicode_at(0), b.unicode_at(0) + 1):
					conj["chars"] += String.chr(code)
			else:
				conj["chars"] += a
		_i += 1
	elif c == "\\":
		_i -= 1
		conj["chars"] = _literal()
	elif c in ["*", "+", "?", ")", "|"]:
		error = "'%s' sin operando en la posición %d" % [c, _i - 1]
	else:
		conj["chars"] = c
	conjuntos.append(conj)
	var s := nuevo_estado()
	var f := nuevo_estado()
	arista(s, conjuntos.size() - 1, f)
	var nombre := "Clase " if c == "[" else "Literal "
	return [s, f, {"texto": nombre + _er.substr(inicio, _i - inicio)}]


## Un carácter, con escapes \n, \t y \x (literal).
func _literal() -> String:
	var c := _ver()
	_i += 1
	if c != "\\":
		return c
	var e := _ver()
	_i += 1
	match e:
		"n":
			return "\n"
		"t":
			return "\t"
		"r":
			return "\r"
	return e


# ---------------------------------------------------------------------- #
# Operaciones para la construcción de subconjuntos
# ---------------------------------------------------------------------- #
## Cerradura-ε de un conjunto de estados (ordenada, sin repetidos).
func cerradura(estados: Array) -> Array:
	var vistos := {}
	var pila := estados.duplicate()
	while not pila.is_empty():
		var q: int = pila.pop_back()
		if vistos.has(q):
			continue
		vistos[q] = true
		for t in trans[q]:
			if t[0] == EPSILON and not vistos.has(t[1]):
				pila.append(t[1])
	var r := vistos.keys()
	r.sort()
	return r


## mover(T, c): estados a los que se llega desde T leyendo el carácter c.
func mover(estados: Array, c: String) -> Array:
	var r := {}
	for q in estados:
		for t in trans[q]:
			if t[0] != EPSILON and pertenece(conjuntos[t[0]], c):
				r[t[1]] = true
	return r.keys()


## Token que acepta un conjunto de estados (el de mayor prioridad) o "".
func token_de(estados: Array) -> String:
	var mejor := ""
	var prio := 1 << 30
	for q in estados:
		if finales.has(q) and finales[q][1] < prio:
			mejor = finales[q][0]
			prio = finales[q][1]
	return mejor


## Simulación directa del AFN (sin convertir): ¿acepta la cadena completa?
func acepta(cadena: String) -> String:
	var actual := cerradura([inicial])
	for c in cadena:
		actual = cerradura(mover(actual, c))
		if actual.is_empty():
			return ""
	return token_de(actual)
