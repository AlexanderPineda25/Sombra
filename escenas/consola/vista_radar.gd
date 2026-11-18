## Pestaña "Radar": el AFD del ciclo, el temporizador y las señales que el
## radar registró por sector (las que luego procesan las máquinas de Turing).
class_name VistaRadar
extends Control

const T := preload("res://escenas/consola/tema.gd")

var partida: Partida


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), T.FONDO)
	if partida == null or partida.radares.is_empty():
		Dibujo.texto(self, "Este nivel no tiene radar.", size / 2, 16, T.SUAVE, true)
		return
	var r: Radar = partida.radares[0]
	var mitad := size.x * 0.45
	# --- AFD del ciclo ------------------------------------------------------ #
	var z := Rect2(6, 6, mitad - 12, size.y * 0.55)
	draw_rect(z, T.PANEL)
	draw_rect(z, T.BORDE, false, 1.0)
	Dibujo.texto(self, "AFD del radar (%d, %d)" % [r.tile.x, r.tile.y], z.position + Vector2(10, 6), 14, T.CIAN,
			false, true, false)
	var ult: Array = r.ultima_transicion
	VistaAFD.diagrama(self, r.afd, z.grow(-40), VistaAFD.POS_RADAR, ult, 26.0)
	Dibujo.texto(self, "t: vence el tiempo · f: vuelta completa · n: análisis terminado",
			Vector2(z.position.x + 10, z.end.y - 22), 12, T.SUAVE, false, false, false)

	# --- estado y temporizador --------------------------------------------- #
	var y := z.end.y + 14
	var est := r.estado()
	Dibujo.texto(self, est, Vector2(14, y), 24, T.COLOR_ESTADO.get(est, T.CIAN), false, true, false)
	Dibujo.texto(self, "Acción: " + r.afd.salida(), Vector2(14, y + 32), 14, T.TEXTO, false, false, false)
	var info := ""
	match est:
		Def.REPOSO:
			info = "Próximo escaneo en %.1f s" % maxf(0.0, r.tiempo_restante())
		Def.AVISO:
			info = "¡Escaneo en %.1f s! Escóndete en un arbusto (las paredes no protegen)." % maxf(0.0, r.tiempo_restante())
		_:
			info = "Barriendo… sector %d de %d" % [clampi(r.sector_actual + 1, 0, Radar.SECTORES), Radar.SECTORES]
	Dibujo.texto(self, info, Vector2(14, y + 54), 14, T.AMBAR, false, true, false)
	Dibujo.texto(self, "Intervalo %.0f s · aviso %.1f s · barrido %.1f s · alcance %.0f casillas" % [r.intervalo(),
			Ajustes.radar_aviso, Ajustes.radar_barrido, Ajustes.radar_alcance], Vector2(14, y + 78), 12, T.SUAVE,
			false, false, false)
	var res := r.ultimo_resultado if r.ultimo_resultado != "" else "—"
	Dibujo.texto(self, "Escaneos: %d · último resultado: %s" % [r.escaneos, res], Vector2(14, y + 98), 13,
			T.ROJO if res == "INTRUSION" else T.TEXTO, false, true, false)

	# --- sectores (vista radial) ------------------------------------------- #
	var c := Vector2(mitad + (size.x - mitad) / 2, size.y * 0.33)
	var rad := minf((size.x - mitad) * 0.4, size.y * 0.28)
	draw_circle(c, rad, T.PANEL)
	for s in Radar.SECTORES:
		var a0 := s * TAU / Radar.SECTORES
		var a1 := (s + 1) * TAU / Radar.SECTORES
		var col := Color(0.1, 0.16, 0.2)
		if r.obs_p[s] == 1:
			col = Color(0.15, 0.4, 0.6) if r.obs_a[s] == 1 else (Color(0.2, 0.45, 0.25) if r.obs_o[s] == 1 or
					r.obs_v[s] == 0 else Color(0.6, 0.15, 0.12))
		var pts := PackedVector2Array([c])
		for k in 9:
			pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 8.0)) * rad)
		draw_colored_polygon(pts, col)
		draw_line(c, c + Vector2.from_angle(a0) * rad, T.BORDE, 1.0)
		Dibujo.texto(self, str(s), c + Vector2.from_angle((a0 + a1) / 2) * (rad + 12), 11, T.SUAVE, true, false, false)
	draw_arc(c, rad, 0, TAU, 64, T.CIAN, 1.5)
	if est in [Def.BARRIDO, Def.ANALISIS]:
		draw_line(c, c + Vector2.from_angle(r.angulo) * rad, T.VERDE, 2.5)
	if r.sector_intrusion >= 0:
		var am := (r.sector_intrusion + 0.5) * TAU / Radar.SECTORES
		draw_circle(c + Vector2.from_angle(am) * rad * 0.6, 6, T.ROJO)
	var ly := c.y + rad + 26
	var lx := mitad + 10
	for par in [["guardia (transpondedor)", Color(0.15, 0.4, 0.6)], ["intruso detectado", Color(0.6, 0.15, 0.12)],
			["oculto en arbusto", Color(0.2, 0.45, 0.25)]]:
		draw_rect(Rect2(lx, ly, 12, 12), par[1])
		Dibujo.texto(self, par[0], Vector2(lx + 18, ly - 2), 12, T.SUAVE, false, false, false)
		lx += Dibujo.ancho_texto(par[0], 12) + 40

	# --- cintas de entrada de las máquinas --------------------------------- #
	var tz := Rect2(mitad + 6, ly + 26, size.x - mitad - 12, size.y - ly - 32)
	draw_rect(tz, T.PANEL)
	draw_rect(tz, T.BORDE, false, 1.0)
	var filas := [["P presencia", r.obs_p], ["A transpondedor", r.obs_a], ["V eco recibido", r.obs_v],
			["O oculto", r.obs_o]]
	var intr := []
	for s in Radar.SECTORES:
		intr.append(1 if r.obs_p[s] == 1 and r.obs_a[s] == 0 else 0)
	filas.append(["I = P·¬A", intr])
	var cw := (tz.size.x - 130) / Radar.SECTORES
	var rh := minf(22.0, (tz.size.y - 10) / filas.size())
	for i in filas.size():
		var fy := tz.position.y + 6 + i * rh
		Dibujo.texto(self, filas[i][0], Vector2(tz.position.x + 8, fy + 2), 12, T.CIAN if i == 4 else T.SUAVE,
				false, i == 4, false)
		for s in Radar.SECTORES:
			var v: int = filas[i][1][s]
			var cr := Rect2(tz.position.x + 124 + s * cw, fy, cw - 2, rh - 3)
			draw_rect(cr, Color(0.03, 0.06, 0.09) if v == 0 else Color(0.12, 0.3, 0.38))
			Dibujo.texto(self, str(v), cr.get_center(), 12, T.TEXTO if v == 1 else T.APAGADO, true, v == 1, false)
