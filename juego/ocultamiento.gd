## Sistema de ocultamiento en los arbustos.
##
## Reglas:
##  1. Cada arbusto tiene un área circular (Config.RADIO_ARBUSTO). No basta
##     con estar en la casilla o cerca: el centro del ladrón debe estar dentro.
##  2. No se puede ocultar mientras un guardia lo está viendo: debe romper el
##     contacto visual durante Config.TIEMPO_PARA_OCULTARSE segundos.
##  3. Moverse de pie dentro del arbusto hace crujir las hojas (ruido pequeño);
##     agachado no hace ruido.
##  4. Un guardia que lo persigue muy de cerca, o que registra el arbusto
##     durante una búsqueda, lo encuentra igual (ver Guardia.ve).
class_name Ocultamiento
extends RefCounted

var arbusto_actual := Vector2i(-99, -99)   ## arbusto en cuya área está el ladrón
var bloqueado := false                     ## entró a la vista de un guardia
var t_sin_contacto := 0.0
var t_crujido := 0.0


## Arbusto cuya área contiene el punto, o (-99, -99) si no hay ninguno.
static func arbusto_en(mapa: Mapa, punto: Vector2) -> Vector2i:
	var t := Mapa.tile_de(punto)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := t + Vector2i(dx, dy)
			if mapa.plantas.has(c) and Mapa.centro(c).distance_to(punto) <= Config.RADIO_ARBUSTO * Config.TILE:
				return c
	return Vector2i(-99, -99)


## Actualiza el estado del ladrón. Devuelve los eventos ocurridos:
## "entra", "oculto", "bloqueado", "sale", "crujido".
func actualizar(dt: float, j: Jugador, mapa: Mapa, guardias: Array) -> Array:
	var eventos := []
	var arbusto := arbusto_en(mapa, j.pos)
	var dentro := arbusto != Vector2i(-99, -99)
	var lo_ven := false
	for g in guardias:
		if g.viendo:
			lo_ven = true
	if dentro and arbusto_actual == Vector2i(-99, -99):
		eventos.append("entra")
		bloqueado = lo_ven
		t_sin_contacto = 0.0
		if bloqueado:
			eventos.append("bloqueado")
	elif not dentro and arbusto_actual != Vector2i(-99, -99):
		if j.oculto:
			eventos.append("sale")
		bloqueado = false
	arbusto_actual = arbusto

	var antes := j.oculto
	if not dentro:
		j.oculto = false
	else:
		if bloqueado:
			t_sin_contacto = 0.0 if lo_ven else t_sin_contacto + dt
			if t_sin_contacto >= Config.TIEMPO_PARA_OCULTARSE:
				bloqueado = false
		j.oculto = not bloqueado
	if j.oculto and not antes:
		eventos.append("oculto")

	# moverse de pie entre las hojas hace ruido
	t_crujido = maxf(0.0, t_crujido - dt)
	if dentro and j.moviendo and not j.agachado and t_crujido <= 0.0:
		t_crujido = 0.6
		eventos.append("crujido")
	return eventos
