## Máquina de Turing estándar: una cinta y un cabezal.
##
##   δ : Q × Γ → Q × Γ × {L, R, S}
##   delta["q|a"] = [q', b, m]   "en q leyendo a: escribe b, mueve m, pasa a q'"
class_name MTEstandar
extends MaquinaTuring

var cinta: CintaTuring


func _init(p_nombre: String, p_estados: Array, p_entrada: Array, p_cinta: Array,
		p_delta: Dictionary, p_inicial: String, p_acepta: String, p_rechaza: String,
		p_blanco := "_") -> void:
	tipo = "estandar"
	cinta = CintaTuring.new(p_blanco)
	_configurar(p_nombre, p_estados, p_entrada, p_cinta, p_delta, p_inicial, p_acepta,
			p_rechaza, p_blanco)


func _validar_transicion(leido: String, t) -> String:
	if not _simbolo_valido(leido):
		return "símbolo leído fuera de Γ"
	if typeof(t) != TYPE_ARRAY or t.size() != 3:
		return "debe ser [estado, escribe, mueve]"
	if not t[0] in estados:
		return "estado destino desconocido"
	if not _simbolo_valido(t[1]):
		return "símbolo escrito fuera de Γ"
	if not t[2] in MOVIMIENTOS:
		return "movimiento inválido"
	return ""


## Carga la palabra de entrada (debe estar en Σ*) y reinicia la máquina.
func cargar(entrada) -> bool:
	for s in entrada:
		if not str(s) in alfabeto_entrada:
			push_error("%s: '%s' no está en Σ" % [nombre, s])
			return false
	cinta.cargar(entrada)
	reiniciar()
	return true


func reiniciar() -> void:
	estado = inicial
	cinta.cabezal = 0
	pasos = 0
	ultima = {}
	historial.clear()


func paso() -> Dictionary:
	if detenida():
		return {}
	var leido := cinta.leer()
	var clave := estado + "|" + leido
	var t := {"estado": estado, "leido": leido, "posicion": cinta.cabezal}
	if not delta.has(clave):
		# sin transición: la máquina se detiene rechazando
		t.merge({"escrito": leido, "mov": "S", "nuevo": rechaza, "definida": false})
		estado = rechaza
	else:
		var d: Array = delta[clave]
		cinta.escribir(d[1])
		cinta.mover(d[2])
		estado = d[0]
		t.merge({"escrito": d[1], "mov": d[2], "nuevo": d[0], "definida": true})
	_registrar(t)
	return t


## Descripción instantánea: contenido de la cinta con el estado delante del
## símbolo que lee el cabezal, por ejemplo "01[q1]10".
func descripcion_instantanea() -> String:
	var l := cinta.limites()
	var desde := mini(l[0], cinta.cabezal)
	var hasta := maxi(l[1], cinta.cabezal)
	var s := ""
	for i in range(desde, hasta + 1):
		if i == cinta.cabezal:
			s += "[" + estado + "]"
		s += cinta.leer_en(i)
	return s
