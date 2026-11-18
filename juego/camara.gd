## Cámara de seguridad controlada por un AFD de 3 estados.
class_name Camara
extends RefCounted

const T := Config.TILE

var tile: Vector2i
var mapa: Mapa
var pos: Vector2
var base: float
var desfase := 0.0
var afd: AFD
var t_ver := 0.0
var t_alarma := 0.0
var t_aviso := 0.0
var viendo := false


func _init(t: Vector2i, angulo_base: float, p_mapa: Mapa) -> void:
	tile = t
	mapa = p_mapa
	pos = Mapa.centro(t)
	base = deg_to_rad(angulo_base)
	afd = Def.crear_afd_camara()


func estado() -> String:
	return afd.actual


func angulo() -> float:
	return base + deg_to_rad(desfase)


func ve(j: Jugador) -> bool:
	if j.oculto:
		return false
	var dif := j.pos - pos
	if dif.length() > Config.ALCANCE_CAMARA * T:
		return false
	if absf(Guardia.diferencia_angular(dif.angle(), angulo())) > deg_to_rad(Config.MEDIO_ANGULO_CAMARA):
		return false
	return mapa.linea_libre(pos, j.pos, tile)


## La central de alarmas (máquina de Turing) envía el símbolo x.
func desactivar() -> void:
	afd.paso("x")
	viendo = false


func actualizar(dt: float, j: Jugador, partida, demo := false) -> void:
	if estado() == Def.APAGADA:
		return
	match estado():
		Def.GIRO_IZQ:
			desfase -= Config.VEL_GIRO_CAMARA * dt
			if desfase <= -Config.BARRIDO_CAMARA:
				desfase = -Config.BARRIDO_CAMARA
				afd.paso("f")
		Def.GIRO_DER:
			desfase += Config.VEL_GIRO_CAMARA * dt
			if desfase >= Config.BARRIDO_CAMARA:
				desfase = Config.BARRIDO_CAMARA
				afd.paso("f")
		Def.ALARMA:
			t_alarma += dt
			if t_alarma > Config.TIEMPO_ALARMA:
				afd.paso("t")

	viendo = (not demo) and ve(j)
	if viendo:
		t_ver += dt
		if estado() != Def.ALARMA and t_ver >= Config.TIEMPO_CAMARA_DETECTA:
			afd.paso("v")
			t_alarma = 0.0
			t_aviso = 0.0
			partida.alarma(j.tile())     # la alarma llega a los guardias como "r"
			partida.seguridad.pedir_alerta(j.pos, "cámara de seguridad")
		elif estado() == Def.ALARMA:
			t_alarma = 0.0
			t_aviso += dt
			if t_aviso > 1.0:
				t_aviso = 0.0
				partida.alarma(j.tile())
	else:
		t_ver = maxf(0.0, t_ver - dt)
