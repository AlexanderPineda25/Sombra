## Experimento con los guardias: 20 partidas de 90 s por nivel, con un ruido
## en una casilla aleatoria cada 3 s y el jugador fuera del mapa.
## Mide transiciones, regresos, precisión del regreso y altura de la pila.
##
##   godot --headless --path . -s res://pruebas/experimento.gd
extends SceneTree

const DT := 1.0 / 60


func _initialize() -> void:
	seed(7)
	for nivel in Niveles.cantidad():
		var transiciones := 0
		var regresos := 0
		var exactos := 0
		var pilas := []
		var tiempo_estado := {}
		var frames := 0
		var t0 := Time.get_ticks_usec()
		for n in 20:
			var p := Partida.new(nivel)
			p.jugador.pos = Vector2(-5000, -5000)
			var casillas := p.mapa.alcanzables_desde(p.mapa.inicio).keys()
			var previo := {}
			var maxp := {}
			for g in p.guardias:
				previo[g] = g.estado()
				maxp[g] = 0
			for f in 60 * 90:
				if f % 180 == 0:
					p.ruido(casillas[randi() % casillas.size()], Config.RUIDO_MONEDA)
				p.actualizar(DT)
				frames += 1
				for g in p.guardias:
					var e: String = g.estado()
					tiempo_estado[e] = tiempo_estado.get(e, 0.0) + DT
					maxp[g] = maxi(maxp[g], g.pila.tamano())
					if e != previo[g]:
						transiciones += 1
						if previo[g] == Def.REGRESO and e == Def.PATRULLA:
							regresos += 1
							if g.tile in g.ruta:
								exactos += 1
							pilas.append(maxp[g])
							maxp[g] = 0
						previo[g] = e
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		var suma := 0.0
		for v in tiempo_estado.values():
			suma += v
		var media := 0.0
		for x in pilas:
			media += x
		media /= maxi(1, pilas.size())
		print("nivel %d: transiciones %d, regresos %d, exactos %d, pila max %d, pila media %.1f, ms/frame %.3f"
				% [nivel + 1, transiciones, regresos, exactos, pilas.max(), media, ms])
		var porc := {}
		for k in tiempo_estado:
			porc[k] = snappedf(100.0 * tiempo_estado[k] / suma, 0.1)
		print("  % tiempo ", porc)
	quit()
