## Analizador léxico del lenguaje SOMBRA, generado automáticamente a partir de
## expresiones regulares, como hacen lex/flex:
##
##   1. ER de cada token  ──Thompson──▶  un AFN-ε por token, unidos por ε
##   2. Clases de equivalencia de caracteres (Σ finito: los caracteres que se
##      comportan igual en todas las ER caen en la misma clase)
##   3. AFN-ε  ──construcción de subconjuntos──▶  AFD
##   4. AFD  ──minimización (particiones)──▶  AFD mínimo
##
## El AFD resultante es una máquina de Moore: la SALIDA de cada estado es el
## token que reconoce (o "—"). Por eso se minimiza con la misma clase AFD que
## los guardias: la partición inicial se hace por salida, no solo por
## aceptación, para no confundir un NUMERO con un IDENT.
##
## El análisis usa la regla del prefijo más largo (maximal munch): avanza
## mientras el AFD no muera y se queda con el último estado de aceptación.
class_name AnalizadorLexico
extends RefCounted

## Reglas en orden de prioridad: [token, ER]. Los tokens en IGNORAR no se
## entregan al analizador sintáctico.
const REGLAS := [
	["ESPACIO", "[ \\t\\r\\n]+"],
	["COMENTARIO", "//[^\\n]*"],
	["NUMERO", "-?[0-9]+(\\.[0-9]+)?"],
	["IDENT", "[a-zA-Z_áéíóúñÁÉÍÓÚÑ][a-zA-Z0-9_áéíóúñÁÉÍÓÚÑ]*"],
	["CADENA", "\"[^\"\\n]*\""],
	["LLAVE_A", "\\{"],
	["LLAVE_C", "\\}"],
	["PAR_A", "\\("],
	["PAR_C", "\\)"],
	["COMA", ","],
]
const IGNORAR := ["ESPACIO", "COMENTARIO"]
## Palabras reservadas: el AFD las reconoce como IDENT y luego se buscan en
## esta tabla (así el autómata no crece una rama por palabra).
const RESERVADAS := ["nivel", "mapa", "guardia", "ir", "esperar", "mirar", "terminal", "radar",
		"camara", "izquierda", "derecha", "arriba", "abajo"]
const MUERTO := "∅"

var afn: AFN
var afd: AFD                   ## AFD de la construcción de subconjuntos
var minimo: AFD                ## AFD mínimo (el que se usa)
var clase_de := {}             ## carácter -> símbolo "c0".."ck"
var clase_otro := ""           ## clase de cualquier carácter no mencionado
var clases: Array = []         ## [símbolo, representante, descripción]
var conjuntos_dfa: Array = []  ## estado del AFD -> estados del AFN que representa
var error := ""

static var _compartido: AnalizadorLexico


## El analizador se construye una sola vez y se reutiliza.
static func compartido() -> AnalizadorLexico:
	if _compartido == null:
		_compartido = AnalizadorLexico.new()
	return _compartido


func _init(reglas: Array = REGLAS) -> void:
	afn = AFN.desde_reglas(reglas)
	if afn.error != "":
		error = afn.error
		return
	_clases_equivalencia()
	_subconjuntos()
	minimo = afd.minimizar()


# ---------------------------------------------------------------------- #
# 2. Clases de equivalencia
# ---------------------------------------------------------------------- #
func _clases_equivalencia() -> void:
	var universo := {}
	for conj in afn.conjuntos:
		for c in conj["chars"]:
			universo[c] = true
	var otro := "\u0001"                # representa a todo carácter no mencionado
	var firma_de := {}
	var orden: Array = []
	for c in universo.keys() + [otro]:
		var firma := ""
		for conj in afn.conjuntos:
			firma += "1" if AFN.pertenece(conj, c) else "0"
		if not firma_de.has(firma):
			firma_de[firma] = []
			orden.append(firma)
		firma_de[firma].append(c)
	for k in orden.size():
		var simbolo := "c%d" % k
		var miembros: Array = firma_de[orden[k]]
		var desc := ""
		for c in miembros:
			if c == otro:
				clase_otro = simbolo
			else:
				clase_de[c] = simbolo
		desc = _describir(miembros, otro)
		clases.append([simbolo, miembros[0], desc])


static func _describir(miembros: Array, otro: String) -> String:
	var vis: Array = []
	for c in miembros:
		if c == otro:
			vis.append("otro")
		elif c == "\n":
			vis.append("\\n")
		elif c == "\t":
			vis.append("\\t")
		elif c == "\r":
			vis.append("\\r")
		elif c == " ":
			vis.append("␣")
		else:
			vis.append(c)
	if vis.size() > 8:
		return "%s…%s (%d)" % ["".join(PackedStringArray(vis.slice(0, 4))), vis[-1], vis.size()]
	return " ".join(PackedStringArray(vis))


func simbolo(c: String) -> String:
	return clase_de.get(c, clase_otro)


# ---------------------------------------------------------------------- #
# 3. Construcción de subconjuntos
# ---------------------------------------------------------------------- #
func _subconjuntos() -> void:
	var simbolos: Array = []
	for cl in clases:
		simbolos.append(cl[0])
	var inicio := afn.cerradura([afn.inicial])
	conjuntos_dfa = [inicio]
	var nombre_de := {str(inicio): "D0"}
	var estados: Array = ["D0"]
	var delta := {}
	var salidas := {}
	var pendientes: Array = [inicio]
	while not pendientes.is_empty():
		var T: Array = pendientes.pop_front()
		var q: String = nombre_de[str(T)]
		delta[q] = {}
		var tok := afn.token_de(T)
		salidas[q] = tok if tok != "" else "—"
		for cl in clases:
			var U := afn.cerradura(afn.mover(T, cl[1]))
			if U.is_empty():
				delta[q][cl[0]] = MUERTO
				continue
			var k := str(U)
			if not nombre_de.has(k):
				nombre_de[k] = "D%d" % estados.size()
				estados.append(nombre_de[k])
				conjuntos_dfa.append(U)
				pendientes.append(U)
			delta[q][cl[0]] = nombre_de[k]
	# estado muerto explícito: así δ es total, como pide la definición de AFD
	estados.append(MUERTO)
	conjuntos_dfa.append([])
	delta[MUERTO] = {}
	for s in simbolos:
		delta[MUERTO][s] = MUERTO
	salidas[MUERTO] = "—"
	var finales: Array = []
	for q in estados:
		if salidas[q] != "—":
			finales.append(q)
	afd = AFD.new("Analizador léxico", estados, simbolos, delta, "D0", finales, salidas)


## Estado muerto del AFD mínimo (el bloque que contiene a ∅).
func _muerto_minimo() -> String:
	for q in minimo.estados:
		if q == MUERTO or q.begins_with(MUERTO + "/") or q.ends_with("/" + MUERTO) or ("/" + MUERTO + "/") in q:
			return q
	return MUERTO


# ---------------------------------------------------------------------- #
# Análisis
# ---------------------------------------------------------------------- #
## Divide el texto en tokens: {tipo, lexema, linea, col}. Los errores léxicos
## se devuelven en `errores` (["línea:col  mensaje"]) y se salta el carácter.
func analizar(texto: String, errores: Array = [], incluir_ignorados := false) -> Array:
	var tokens: Array = []
	var muerto := _muerto_minimo()
	var i := 0
	var linea := 1
	var col := 1
	var n := texto.length()
	while i < n:
		var q := minimo.inicial
		var j := i
		var ultimo_fin := -1
		var ultimo_tok := ""
		while j < n:
			q = minimo.transicion(q, simbolo(texto[j]))
			if q == muerto:
				break
			j += 1
			var s: String = minimo.salidas[q]
			if s != "—":
				ultimo_fin = j
				ultimo_tok = s
		if ultimo_fin < 0:
			errores.append("%d:%d  carácter inesperado '%s'" % [linea, col, texto[i].c_escape()])
			ultimo_fin = i + 1
			ultimo_tok = ""
		var lexema := texto.substr(i, ultimo_fin - i)
		if ultimo_tok != "" and (incluir_ignorados or not ultimo_tok in IGNORAR):
			var tipo := ultimo_tok
			if tipo == "IDENT" and lexema in RESERVADAS:
				tipo = lexema.to_upper()
			tokens.append({"tipo": tipo, "lexema": lexema, "linea": linea, "col": col})
		for c in lexema:
			if c == "\n":
				linea += 1
				col = 1
			else:
				col += 1
		i = ultimo_fin
	tokens.append({"tipo": "FIN", "lexema": "", "linea": linea, "col": col})
	return tokens


## Resumen de la construcción (para la consola F1 y el informe).
func resumen() -> Dictionary:
	return {
		"reglas": REGLAS.size(),
		"afn_estados": afn.num_estados(),
		"afn_transiciones": afn.num_transiciones(),
		"clases": clases.size(),
		"afd_estados": afd.estados.size(),
		"min_estados": minimo.estados.size(),
	}
