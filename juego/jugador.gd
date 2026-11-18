## El ladrón que controla la persona que juega.
class_name Jugador
extends RefCounted

const T := Config.TILE
const RADIO := 0.3 * Config.TILE

var pos: Vector2
var angulo := 0.0
var corriendo := false
var moviendo := false
var oculto := false
var monedas := Config.MONEDAS_POR_NIVEL
var paso_anim := 0.0
var agachado := false
var accion := ""           ## animación de acción: "lanzar", "recoger", "interactuar"
var t_accion := 0.0


func _init(t: Vector2i) -> void:
	pos = Mapa.centro(t)


func tile() -> Vector2i:
	return Mapa.tile_de(pos)


func _choca(p: Vector2, mapa: Mapa) -> bool:
	for esquina in [Vector2(-RADIO, -RADIO), Vector2(RADIO, -RADIO),
			Vector2(-RADIO, RADIO), Vector2(RADIO, RADIO)]:
		if mapa.es_pared(Mapa.tile_de(p + esquina)):
			return true
	return false


func hacer(nombre: String, duracion := 0.45) -> void:
	accion = nombre
	t_accion = duracion


## Mueve al jugador separando los ejes para que se deslice por las paredes.
## Agachado camina más lento y cuesta más verlo; correr hace ruido.
func actualizar(dt: float, dir: Vector2, correr: bool, mapa: Mapa, agachar := false) -> void:
	if t_accion > 0.0:
		t_accion -= dt
		if t_accion <= 0.0 and accion != "interactuar":
			accion = ""
	agachado = agachar and not correr
	moviendo = dir != Vector2.ZERO
	corriendo = correr and moviendo
	if not moviendo:
		return
	dir = dir.normalized()
	var vel := Config.VEL_JUGADOR * T
	if corriendo:
		vel = Config.VEL_JUGADOR_CORRER * T
	elif agachado:
		vel = Config.VEL_JUGADOR_AGACHADO * T
	angulo = dir.angle()
	var nx := Vector2(pos.x + dir.x * vel * dt, pos.y)
	if not _choca(nx, mapa):
		pos = nx
	var ny := Vector2(pos.x, pos.y + dir.y * vel * dt)
	if not _choca(ny, mapa):
		pos = ny
	paso_anim += dt * (14.0 if corriendo else (6.0 if agachado else 9.0))
