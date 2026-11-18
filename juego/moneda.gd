## Moneda lanzada para distraer: al caer hace un ruido.
class_name Moneda
extends RefCounted

const DURACION := 0.4

var origen: Vector2
var tile: Vector2i
var destino: Vector2
var t := 0.0
var aterrizo := false


func _init(p_origen: Vector2, destino_tile: Vector2i) -> void:
	origen = p_origen
	tile = destino_tile
	destino = Mapa.centro(destino_tile)


func pos() -> Vector2:
	var f := minf(1.0, t / DURACION)
	var p := origen.lerp(destino, f)
	p.y -= sin(f * PI) * Config.TILE * 0.8
	return p


## Devuelve true en el instante en que cae al suelo.
func actualizar(dt: float) -> bool:
	t += dt
	if not aterrizo and t >= DURACION:
		aterrizo = true
		return true
	return false
