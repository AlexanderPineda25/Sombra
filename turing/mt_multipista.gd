## Máquina de Turing multipista: UNA sola cinta, dividida en k pistas.
##
## Cada casilla guarda una tupla (s1, ..., sk), un símbolo por pista. Hay un
## único cabezal: lee la tupla completa de la casilla, escribe una tupla y se
## mueve una vez. Por eso
##
##   δ : Q × Γ^k → Q × Γ^k × {L, R, S}        (un solo movimiento)
##   delta["q|a1,...,ak"] = [q', [b1,...,bk], m]
##
## Diferencia con la multicinta: aquí todas las pistas están siempre bajo el
## mismo cabezal; allá cada cinta tiene su cabezal y se mueve por su cuenta.
## Una multipista es en realidad una máquina estándar cuyo alfabeto de cinta
## son tuplas: Γ' = Γ × ... × Γ.
class_name MTMultipista
extends MaquinaTuring

var k: int
var celdas := {}            ## posición -> Array de k símbolos (sin las casillas en blanco)
var cabezal := 0


func _init(p_nombre: String, p_k: int, p_estados: Array, p_entrada: Array, p_cinta: Array,
		p_delta: Dictionary, p_inicial: String, p_acepta: String, p_rechaza: String,
		p_blanco := "_") -> void:
	tipo = "multipista"
	k = p_k
	_configurar(p_nombre, p_estados, p_entrada, p_cinta, p_delta, p_inicial, p_acepta,
			p_rechaza, p_blanco)


func _validar_transicion(leido: String, t) -> String:
	var ls := leido.split(",")
	if ls.size() != k:
		return "la tupla leída debe tener %d pistas" % k
	for s in ls:
		if not _simbolo_valido(s):
			return "símbolo leído fuera de Γ"
	if typeof(t) != TYPE_ARRAY or t.size() != 3:
		return "debe ser [estado, [escribe x k], mueve]"
	if not t[0] in estados:
		return "estado destino desconocido"
	if t[1].size() != k:
		return "debe escribir una tupla de %d símbolos" % k
	for s in t[1]:
		if not _simbolo_valido(s):
			return "símbolo escrito fuera de Γ"
	if typeof(t[2]) != TYPE_STRING or not t[2] in MOVIMIENTOS:
		return "la multipista tiene UN solo movimiento"
	return ""


func _blanca() -> Array:
	var b := []
	b.resize(k)
	b.fill(blanco)
	return b


## `pistas`: un String o Array por pista, todas desde la posición 0.
func cargar(pistas: Array) -> void:
	celdas.clear()
	var largo := 0
	for p in pistas:
		largo = maxi(largo, p.length() if typeof(p) == TYPE_STRING else p.size())
	for i in largo:
		var tupla := []
		for j in k:
			var p = pistas[j] if j < pistas.size() else ""
			tupla.append(str(p[i]) if i < (p.length() if typeof(p) == TYPE_STRING else p.size()) else blanco)
		escribir_en(i, tupla)
	reiniciar()


func reiniciar() -> void:
	estado = inicial
	cabezal = 0
	pasos = 0
	ultima = {}
	historial.clear()


func leer() -> Array:
	return leer_en(cabezal)


func leer_en(pos: int) -> Array:
	return celdas.get(pos, _blanca()).duplicate()


func escribir_en(pos: int, tupla: Array) -> void:
	if tupla == _blanca():
		celdas.erase(pos)
	else:
		celdas[pos] = tupla.duplicate()


## Contenido de una pista entre los límites de la cinta.
func pista(j: int) -> String:
	if celdas.is_empty():
		return ""
	var s := ""
	for i in range(celdas.keys().min(), celdas.keys().max() + 1):
		s += leer_en(i)[j]
	return s


func limites() -> Array:
	if celdas.is_empty():
		return [0, -1]
	return [celdas.keys().min(), celdas.keys().max()]


func paso() -> Dictionary:
	if detenida():
		return {}
	var leido := leer()
	var clave := estado + "|" + ",".join(PackedStringArray(leido))
	var t := {"estado": estado, "leido": leido, "posicion": cabezal}
	if not delta.has(clave):
		t.merge({"escrito": leido, "mov": "S", "nuevo": rechaza, "definida": false})
		estado = rechaza
	else:
		var d: Array = delta[clave]
		escribir_en(cabezal, d[1])        # escribe la tupla completa
		match d[2]:                        # un único movimiento
			"L":
				cabezal -= 1
			"R":
				cabezal += 1
		estado = d[0]
		t.merge({"escrito": d[1], "mov": d[2], "nuevo": d[0], "definida": true})
	_registrar(t)
	return t
