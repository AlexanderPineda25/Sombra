## Plantas grandes: se dibujan por encima de los personajes para que el ladrón
## pueda esconderse entre las hojas.
extends Node2D

const T := Config.TILE

var juego


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p: Partida = juego.partida
	var tiempo: float = juego.tiempo
	var escondido := p.jugador.tile() if p.jugador.oculto and not p.demo else Vector2i(-99, -99)
	for t in p.mapa.plantas:
		var c := Mapa.centro(t)
		var vaiven := sin(tiempo * 1.3 + t.x * 0.7) * 0.04
		var alfa := 0.72 if t == escondido else 1.0
		draw_set_transform(c, vaiven, Vector2.ONE)
		Arte.casilla(self, Arte.PLANTA, Rect2(-T * 0.75, -T * 0.75, T * 1.5, T * 1.5), Color(1, 1, 1, alfa))
		draw_set_transform(Vector2.ZERO)
