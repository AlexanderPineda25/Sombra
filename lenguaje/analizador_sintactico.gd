## Analizador sintáctico descendente recursivo (LL(1)) del lenguaje SOMBRA.
##
## Produce un árbol de sintaxis abstracta (AST) de diccionarios:
##   {"tipo": "nivel", "nombre": ..., "hijos": [...], "linea": n}
## Ante un error de sintaxis se registra "línea:col  se esperaba X" y se
## recupera saltando hasta el siguiente '}' (modo pánico).
class_name AnalizadorSintactico
extends RefCounted

const SENTENCIAS := ["MAPA", "GUARDIA", "TERMINAL", "RADAR", "CAMARA"]
const DIRECCIONES := ["IZQUIERDA", "DERECHA", "ARRIBA", "ABAJO"]
const EBNF := """programa = nivel FIN
nivel = 'nivel' CADENA '{' sentencia* '}'
sentencia = mapa | guardia | terminal | radar | camara
mapa = 'mapa' '{' CADENA+ '}'
guardia = 'guardia' '{' orden+ '}'
orden = 'ir' punto | 'esperar' NUMERO | 'mirar' direccion NUMERO
terminal = 'terminal' punto IDENT
radar = 'radar' punto
camara = 'camara' punto direccion
punto = '(' NUMERO ',' NUMERO ')'
direccion = 'izquierda' | 'derecha' | 'arriba' | 'abajo'"""

var tokens: Array
var i := 0
var errores: Array = []


func _init(p_tokens: Array) -> void:
	tokens = p_tokens


func actual() -> Dictionary:
	return tokens[mini(i, tokens.size() - 1)]


func ver(tipo: String) -> bool:
	return actual()["tipo"] == tipo


## Consume un token del tipo esperado; si no está, registra el error.
func esperar(tipo: String, que := "") -> Dictionary:
	var t := actual()
	if t["tipo"] == tipo:
		i += 1
		return t
	_error(t, "se esperaba %s y llegó %s" % [que if que != "" else _bonito(tipo), _describir(t)])
	return {}


func _error(t: Dictionary, msg: String) -> void:
	errores.append("%d:%d  %s" % [t["linea"], t["col"], msg])


static func _bonito(tipo: String) -> String:
	match tipo:
		"LLAVE_A":
			return "'{'"
		"LLAVE_C":
			return "'}'"
		"PAR_A":
			return "'('"
		"PAR_C":
			return "')'"
		"COMA":
			return "','"
		"CADENA":
			return "un texto entre comillas"
		"NUMERO":
			return "un número"
		"IDENT":
			return "un nombre"
		"FIN":
			return "el final del archivo"
	return "'%s'" % tipo.to_lower()


static func _describir(t: Dictionary) -> String:
	if t["tipo"] == "FIN":
		return "el final del archivo"
	return "'%s'" % t["lexema"]


## Modo pánico: salta tokens hasta el comienzo de la siguiente sentencia (o el
## '}' que cierra el nivel) para seguir analizando y reportar más errores.
func _sincronizar() -> void:
	while not ver("FIN") and not actual()["tipo"] in SENTENCIAS:
		if ver("LLAVE_C") and i + 1 < tokens.size() and tokens[i + 1]["tipo"] == "FIN":
			return
		i += 1


# ---------------------------------------------------------------------- #
# Reglas
# ---------------------------------------------------------------------- #
func programa() -> Dictionary:
	var n := nivel()
	if not ver("FIN"):
		_error(actual(), "sobra %s después del nivel" % _describir(actual()))
	return n


func nivel() -> Dictionary:
	var t := esperar("NIVEL")
	var nombre := esperar("CADENA")
	var nodo := {"tipo": "nivel", "nombre": _sin_comillas(nombre), "hijos": [],
			"linea": t.get("linea", 1)}
	esperar("LLAVE_A")
	while not ver("LLAVE_C") and not ver("FIN"):
		var antes := errores.size()
		var s := sentencia()
		if not s.is_empty():
			nodo["hijos"].append(s)
		if errores.size() > antes:
			_sincronizar()
	esperar("LLAVE_C")
	return nodo


func sentencia() -> Dictionary:
	match actual()["tipo"]:
		"MAPA":
			return mapa()
		"GUARDIA":
			return guardia()
		"TERMINAL":
			return terminal()
		"RADAR":
			return radar()
		"CAMARA":
			return camara()
	_error(actual(), "se esperaba mapa, guardia, terminal, radar o camara y llegó %s" % _describir(actual()))
	return {}


func mapa() -> Dictionary:
	var t := esperar("MAPA")
	var filas: Array = []
	esperar("LLAVE_A")
	if not ver("CADENA"):
		_error(actual(), "el mapa necesita al menos una fila entre comillas")
	while ver("CADENA"):
		filas.append({"texto": _sin_comillas(actual()), "linea": actual()["linea"]})
		i += 1
	esperar("LLAVE_C")
	return {"tipo": "mapa", "filas": filas, "linea": t["linea"]}


func guardia() -> Dictionary:
	var t := esperar("GUARDIA")
	var ordenes: Array = []
	esperar("LLAVE_A")
	while ver("IR") or ver("ESPERAR") or ver("MIRAR"):
		ordenes.append(orden())
	if ordenes.is_empty():
		_error(actual(), "se esperaba ir, esperar o mirar y llegó %s" % _describir(actual()))
	esperar("LLAVE_C")
	return {"tipo": "guardia", "ordenes": ordenes, "linea": t["linea"]}


func orden() -> Dictionary:
	var t := actual()
	i += 1
	match t["tipo"]:
		"IR":
			return {"tipo": "ir", "punto": punto(), "linea": t["linea"]}
		"ESPERAR":
			return {"tipo": "esperar", "segundos": numero(), "linea": t["linea"]}
	var dir := direccion()
	return {"tipo": "mirar", "direccion": dir, "segundos": numero(), "linea": t["linea"]}


func terminal() -> Dictionary:
	var t := esperar("TERMINAL")
	var p := punto()
	var desafio := esperar("IDENT", "el nombre del desafío")
	return {"tipo": "terminal", "punto": p, "desafio": desafio.get("lexema", ""), "linea": t["linea"]}


func radar() -> Dictionary:
	var t := esperar("RADAR")
	return {"tipo": "radar", "punto": punto(), "linea": t["linea"]}


func camara() -> Dictionary:
	var t := esperar("CAMARA")
	var p := punto()
	return {"tipo": "camara", "punto": p, "direccion": direccion(), "linea": t["linea"]}


func punto() -> Vector2i:
	esperar("PAR_A")
	var x := numero()
	esperar("COMA")
	var y := numero()
	esperar("PAR_C")
	return Vector2i(int(x), int(y))


func numero() -> float:
	var t := esperar("NUMERO")
	return float(t.get("lexema", "0"))


func direccion() -> String:
	var t := actual()
	if t["tipo"] in DIRECCIONES:
		i += 1
		return t["lexema"]
	_error(t, "se esperaba una dirección (izquierda, derecha, arriba, abajo) y llegó %s" % _describir(t))
	return "derecha"


static func _sin_comillas(t: Dictionary) -> String:
	var s: String = t.get("lexema", "\"\"")
	return s.substr(1, s.length() - 2)
