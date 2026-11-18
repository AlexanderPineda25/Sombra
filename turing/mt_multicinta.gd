## Máquina de Turing multicinta: k cintas independientes, cada una con su
## propio cabezal.
##
##   δ : Q × Γ^k → Q × Γ^k × {L, R, S}^k
##   delta["q|a1,a2,...,ak"] = [q', [b1,...,bk], [m1,...,mk]]
##
## En cada paso global la máquina lee a la vez el símbolo bajo cada cabezal,
## y con una sola transición escribe en todas las cintas y mueve cada cabezal
## por separado (uno puede ir a la izquierda mientras otro se queda quieto).
class_name MTMulticinta
extends MaquinaTuring

var k: int
var cintas: Array = []      ## Array[CintaTuring]


func _init(p_nombre: String, p_k: int, p_estados: Array, p_entrada: Array, p_cinta: Array,
		p_delta: Dictionary, p_inicial: String, p_acepta: String, p_rechaza: String,
		p_blanco := "_") -> void:
	tipo = "multicinta"
	k = p_k
	for i in k:
		cintas.append(CintaTuring.new(p_blanco))
	_configurar(p_nombre, p_estados, p_entrada, p_cinta, p_delta, p_inicial, p_acepta,
			p_rechaza, p_blanco)


static func clave_de(simbolos: Array) -> String:
	return ",".join(PackedStringArray(simbolos))


func _validar_transicion(leido: String, t) -> String:
	var ls := leido.split(",")
	if ls.size() != k:
		return "se deben leer %d símbolos" % k
	for s in ls:
		if not _simbolo_valido(s):
			return "símbolo leído fuera de Γ"
	if typeof(t) != TYPE_ARRAY or t.size() != 3:
		return "debe ser [estado, [escribe x k], [mueve x k]]"
	if not t[0] in estados:
		return "estado destino desconocido"
	if typeof(t[1]) != TYPE_ARRAY or typeof(t[2]) != TYPE_ARRAY:
		return "cada cinta tiene su propio movimiento: [estado, [escribe x k], [mueve x k]]"
	if t[1].size() != k or t[2].size() != k:
		return "debe escribir y mover en las %d cintas" % k
	for s in t[1]:
		if not _simbolo_valido(s):
			return "símbolo escrito fuera de Γ"
	for m in t[2]:
		if not m in MOVIMIENTOS:
			return "movimiento inválido"
	return ""


## `entradas`: un String o Array por cinta. `desde`: posición inicial de cada
## contenido (por defecto 0).
func cargar(entradas: Array, desde: Array = []) -> void:
	for i in k:
		var d: int = desde[i] if i < desde.size() else 0
		cintas[i].cargar(entradas[i] if i < entradas.size() else "", d)
	reiniciar()


func reiniciar() -> void:
	estado = inicial
	for c in cintas:
		c.cabezal = 0
	pasos = 0
	ultima = {}
	historial.clear()


func leer() -> Array:
	var r := []
	for c in cintas:
		r.append(c.leer())
	return r


func paso() -> Dictionary:
	if detenida():
		return {}
	var leidos := leer()
	var posiciones := []
	for c in cintas:
		posiciones.append(c.cabezal)
	var clave := estado + "|" + clave_de(leidos)
	var t := {"estado": estado, "leido": leidos, "posicion": posiciones}
	if not delta.has(clave):
		var quietos := []
		quietos.resize(k)
		quietos.fill("S")
		t.merge({"escrito": leidos, "mov": quietos, "nuevo": rechaza, "definida": false})
		estado = rechaza
	else:
		var d: Array = delta[clave]
		for i in k:                       # todas las cintas en el mismo paso
			cintas[i].escribir(d[1][i])
			cintas[i].mover(d[2][i])
		estado = d[0]
		t.merge({"escrito": d[1], "mov": d[2], "nuevo": d[0], "definida": true})
	_registrar(t)
	return t
