## Capa del museo: piso, muros con pinturas, pedestales, salida, puertas,
## terminales y emisores láser. Está bajo el CanvasModulate, así que solo se
## ve bien donde llegan las luces (linternas, focos de las vitrinas...).
extends Node2D

const T := Config.TILE

var juego


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p: Partida = juego.partida
	var mapa := p.mapa
	var tiempo: float = juego.tiempo
	for y in mapa.alto:
		for x in mapa.ancho:
			var t := Vector2i(x, y)
			var r := Rect2(x * T, y * T, T, T)
			if mapa.es_puerta(t):
				Arte.casilla(self, Arte.PISO_OSCURO, r)
				continue
			if mapa.es_pared(t):
				var abajo := t + Vector2i(0, 1)
				if not mapa.es_pared(abajo) and abajo.y < mapa.alto:
					var cuadro := (x * 7 + y * 13) % 6
					var idx := Arte.PINTURA + cuadro if cuadro < 3 and x % 3 == 1 else Arte.PARED_FRENTE
					Arte.casilla(self, idx, r)
				else:
					Arte.casilla(self, Arte.PARED, r)
			else:
				Arte.casilla(self, Arte.PISO_CLARO if (x + y) % 2 == 0 else Arte.PISO_OSCURO, r)
				if mapa.es_pared(t + Vector2i(0, -1)):          # sombra del muro
					draw_rect(Rect2(r.position, Vector2(T, 9)), Color(0, 0, 0, 0.32))
				if mapa.es_pared(t + Vector2i(-1, 0)):
					draw_rect(Rect2(r.position, Vector2(5, T)), Color(0, 0, 0, 0.18))

	# alfombra de la salida
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var t: Vector2i = mapa.salida + Vector2i(dx, dy)
			if mapa.caminable(t):
				Arte.casilla(self, Arte.ALFOMBRA, Rect2(t.x * T, t.y * T, T, T), Color(1, 1, 1, 0.85))
	Arte.casilla(self, Arte.SALIDA_ABIERTA if p.salida_abierta() else Arte.SALIDA_CERRADA,
			Rect2(mapa.salida.x * T, mapa.salida.y * T, T, T))

	# pedestales con joyas (la vitrina brilla mientras la joya sigue ahí)
	for i in mapa.joyas.size():
		var t: Vector2i = mapa.joyas[i]
		var c := Mapa.centro(t)
		Arte.casilla(self, Arte.PEDESTAL, Rect2(c - Vector2(T, T) * 0.62, Vector2(T, T) * 1.24))
		if t in p.joyas:
			var flota := sin(tiempo * 2.0 + i) * 1.5
			Arte.joya(self, i, c + Vector2(0, flota), 22)
			Arte.casilla(self, Arte.VITRINA, Rect2(c - Vector2(T, T) * 0.55, Vector2(T, T) * 1.1))

	# puertas electrónicas
	for t in mapa.puertas:
		var r := Rect2(t.x * T, t.y * T, T, T)
		Arte.casilla(self, Arte.PUERTA_ABIERTA if mapa.puertas_abiertas else Arte.PUERTA_CERRADA, r)

	# terminales
	for term in p.terminales:
		var t: Vector2i = term["pos"]
		var resuelta: bool = term["desafio"].resuelto
		var r := Rect2(Mapa.centro(t) - Vector2(T, T) * 0.6, Vector2(T, T) * 1.2)
		Arte.casilla(self, Arte.TERMINAL_RESUELTA if resuelta else Arte.TERMINAL, r)

	# emisores de la rejilla láser
	for t in mapa.laseres:
		var c := Mapa.centro(t)
		# los emisores van en los muros que cierran el paso
		var vertical := mapa.es_pared(t + Vector2i(0, -1)) and mapa.es_pared(t + Vector2i(0, 1))
		draw_set_transform(c, 0.0 if vertical else PI / 2, Vector2.ONE)
		Arte.casilla(self, Arte.EMISOR_LASER, Rect2(-T / 2.0, -T / 2.0, T, T),
				Color.WHITE if p.laser_activo else Color(0.5, 0.5, 0.5))
		draw_set_transform(Vector2.ZERO)
