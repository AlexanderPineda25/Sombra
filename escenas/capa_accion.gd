## Capa de acción (sin iluminar): contornos de los conos de visión, ondas de
## ruido, monedas en vuelo, rayos láser, iconos de los guardias, indicaciones
## y partículas. Va en un CanvasLayer propio para que la oscuridad no la tape.
extends Node2D

const T := Config.TILE

var juego
var etiquetas: Array = []       ## textos flotantes: {pos, texto, color, t, dur}
var marcas: Array = []          ## zonas estimadas por el radar: {pos, t}
var huellas: Array = []         ## polvo de los pasos al correr: {pos, t}
var t_huella := 0.0


func _process(dt: float) -> void:
	for e in etiquetas:
		e["t"] += dt
	etiquetas = etiquetas.filter(func(e): return e["t"] < e["dur"])
	for m in marcas:
		m["t"] += dt
	marcas = marcas.filter(func(m): return m["t"] < 4.0)
	for h in huellas:
		h["t"] += dt
	huellas = huellas.filter(func(h): return h["t"] < 0.6)
	var j: Jugador = juego.partida.jugador
	t_huella -= dt
	if j.corriendo and j.moviendo and t_huella <= 0.0 and not juego.partida.demo:
		t_huella = 0.11
		var lado := Vector2.from_angle(j.angulo).orthogonal() * (5.0 if huellas.size() % 2 == 0 else -5.0)
		huellas.append({"pos": j.pos + lado - Vector2.from_angle(j.angulo) * 6, "t": 0.0})
	queue_redraw()


func etiqueta(pos: Vector2, texto: String, color: Color, dur := 1.6) -> void:
	# una etiqueta nueva en el mismo lugar reemplaza a la anterior
	etiquetas = etiquetas.filter(func(e): return e["pos"].distance_to(pos) > 12.0)
	etiquetas.append({"pos": pos, "texto": texto, "color": color, "t": 0.0, "dur": dur})


# --- partículas ------------------------------------------------------------- #
func efecto(ef: Dictionary) -> void:
	var p: Partida = juego.partida
	match ef["tipo"]:
		"joya":
			_chispas(ef["pos"], Color(0.6, 0.95, 1.0), 40, 90.0)
		"moneda":
			_chispas(ef["pos"], Color(1.0, 0.85, 0.35), 18, 60.0)
		"resuelto":
			_chispas(ef["pos"], Color(0.35, 1.0, 0.55), 50, 110.0)
		"error":
			_chispas(ef["pos"], Color(1.0, 0.4, 0.3), 30, 80.0)
		"laser_cruzado":
			_chispas(ef["pos"], Color(1.0, 0.2, 0.2), 30, 70.0)
		"puertas":
			for t in p.mapa.puertas:
				_chispas(Mapa.centro(t), Color(0.6, 0.9, 1.0), 20, 70.0)
		"laser":
			for t in p.mapa.laseres:
				_chispas(Mapa.centro(t), Color(1.0, 0.3, 0.3), 16, 50.0)
		"camaras":
			for c in p.camaras:
				_chispas(c.pos, Color(0.6, 0.85, 1.0), 20, 60.0)
		"oculto":
			_chispas(ef["pos"], Color(0.45, 1.0, 0.55), 22, 45.0)
			etiqueta(ef["pos"] + Vector2(0, -26), "OCULTO", Color(0.55, 1.0, 0.6))
		"bloqueado":
			_chispas(ef["pos"], Color(1.0, 0.35, 0.3), 14, 40.0)
			etiqueta(ef["pos"] + Vector2(0, -26), "¡TE ESTÁN VIENDO!", Color(1.0, 0.45, 0.4), 1.8)
		"sale":
			_chispas(ef["pos"], Color(0.6, 0.85, 0.5), 10, 35.0)
			etiqueta(ef["pos"] + Vector2(0, -26), "VISIBLE", Color(1.0, 0.85, 0.5), 1.2)
		"agotado":
			etiqueta(ef["pos"] + Vector2(0, -26), "SIN ENERGÍA", Color(1.0, 0.6, 0.3), 1.4)
		"radar_aviso":
			etiqueta(ef["pos"] + Vector2(0, -34), "RADAR: ESCANEO INMINENTE", Color(1.0, 0.85, 0.3), 2.4)
		"radar_intrusion":
			_chispas(ef["pos"], Color(1.0, 0.3, 0.3), 30, 80.0)
			etiqueta(ef["pos"] + Vector2(0, -34), "MT ACEPTA · INTRUSIÓN", Color(1.0, 0.4, 0.35), 2.6)
			marcas.append({"pos": ef["objetivo"], "t": 0.0})
		"radar_limpio":
			etiqueta(ef["pos"] + Vector2(0, -34), "MT RECHAZA · SIN INTRUSOS", Color(0.5, 1.0, 0.7), 2.0)


func _chispas(pos: Vector2, color: Color, cantidad: int, velocidad: float) -> void:
	var part := CPUParticles2D.new()
	part.position = pos
	part.one_shot = true
	part.explosiveness = 0.9
	part.amount = cantidad
	part.lifetime = 0.8
	part.spread = 180.0
	part.gravity = Vector2.ZERO
	part.initial_velocity_min = velocidad * 0.4
	part.initial_velocity_max = velocidad
	part.damping_min = 60.0
	part.damping_max = 120.0
	part.scale_amount_min = 1.5
	part.scale_amount_max = 3.5
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color, 0.0))
	part.color_ramp = grad
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	part.material = mat
	add_child(part)
	part.emitting = true
	get_tree().create_timer(1.2).timeout.connect(part.queue_free)


# --- dibujo ------------------------------------------------------------------ #
func _draw() -> void:
	var p: Partida = juego.partida
	var tiempo: float = juego.tiempo
	var mapa := p.mapa

	# contorno sutil de los conos (la luz real la ponen las linternas)
	for g in p.guardias:
		var col := Config.CONO_NORMAL
		match g.estado():
			Def.PERSECUCION:
				col = Config.CONO_PERSECUCION
			Def.ALERTA, Def.BUSQUEDA, Def.SOSPECHA:
				col = Config.CONO_ALERTA
		col.a = 0.07 if g.estado() != Def.PERSECUCION else 0.12
		Dibujo.cono(self, mapa, g.pos, g.angulo, Config.MEDIO_ANGULO_GUARDIA, g.alcance(), col)
	for c in p.camaras:
		if c.estado() == Def.APAGADA:
			continue
		var col := Config.CONO_PERSECUCION if c.estado() == Def.ALARMA else Config.CONO_CAMARA
		col.a = 0.08
		Dibujo.cono(self, mapa, c.pos, c.angulo(), Config.MEDIO_ANGULO_CAMARA,
				Config.ALCANCE_CAMARA * T, col, c.tile)

	_dibujar_radares(p, tiempo)

	# rejilla láser
	if p.laser_activo:
		for t in mapa.laseres:
			var c := Mapa.centro(t)
			var vertical := mapa.es_pared(t + Vector2i(0, -1)) and mapa.es_pared(t + Vector2i(0, 1))
			var eje := Vector2(0, 1) if vertical else Vector2(1, 0)
			var parpadeo := 0.75 + 0.25 * sin(tiempo * 22.0 + t.x)
			for k in [-0.3, 0.0, 0.3]:
				var lado = eje.orthogonal() * k * T
				var a = c - eje * T * 0.45 + lado
				var b = c + eje * T * 0.45 + lado
				draw_line(a, b, Color(1.0, 0.15, 0.15, 0.35 * parpadeo), 5.0)
				draw_line(a, b, Color(1.0, 0.6, 0.6, parpadeo), 1.5)

	for h in huellas:
		var f: float = h["t"] / 0.6
		draw_circle(h["pos"], 2.0 + 5.0 * f, Color(0.75, 0.72, 0.65, 0.35 * (1.0 - f)))

	# ondas de ruido
	for o in p.ondas:
		var f: float = o.t / o.duracion
		var r: float = o.radio * f
		if r > 2:
			draw_arc(o.pos, r, 0, TAU, 64, Color(o.color, 0.55 * (1 - f)), 2.5)

	for m in p.monedas:
		if not m.aterrizo:
			draw_texture_rect(Arte.moneda, Rect2(m.pos() - Vector2(6, 6), Vector2(12, 12)), false)

	# indicadores sobre los guardias
	for g in p.guardias:
		var icono = g.icono()
		if icono != "":
			var col := Color8(255, 80, 80) if icono == "!" else Color8(255, 200, 80)
			var salto := absf(sin(tiempo * 6)) * 3
			var base = g.pos + Vector2(0, -30 - salto)
			draw_circle(base, 10, Color(0.05, 0.05, 0.08, 0.85))
			draw_arc(base, 10, 0, TAU, 24, col, 2)
			Dibujo.texto(self, icono, base, 16, col, true, true, false)
		if g.en_pausa():
			# pausa programada en el lenguaje SOMBRA: reloj que se vacía
			var c: Vector2 = g.pos + Vector2(14, -18)
			var f: float = g.pausa_restante / maxf(0.01, g.pausa_actual["segundos"])
			draw_circle(c, 6, Color(0.05, 0.06, 0.09, 0.8))
			draw_arc(c, 6, -PI / 2, -PI / 2 + TAU * f, 16, Color(0.6, 0.8, 1.0, 0.9), 2.0)
		if g.estado() != Def.PERSECUCION and g.sospecha > 0.02:
			var w := 28.0
			var b = g.pos + Vector2(-w / 2, -20)
			draw_rect(Rect2(b, Vector2(w, 4)), Color(0.1, 0.1, 0.14, 0.9))
			draw_rect(Rect2(b, Vector2(w * minf(1, g.sospecha), 4)), Color8(255, 200, 80))

	# indicación de las terminales
	if juego.flujo.actual == Def.JUGANDO and not p.demo:
		var cerca = p.terminal_cercana()
		for term in p.terminales:
			var c := Mapa.centro(term["pos"])
			var resuelta: bool = term["desafio"].resuelto
			if term == cerca:
				var y := c.y - 30 + sin(tiempo * 4) * 2
				var txt = "E · " + ("Terminal resuelta" if resuelta else term["desafio"].titulo)
				var ancho := Dibujo.ancho_texto(txt, 14, true) + 18
				draw_rect(Rect2(c.x - ancho / 2, y - 12, ancho, 24), Color(0.03, 0.08, 0.12, 0.92))
				draw_rect(Rect2(c.x - ancho / 2, y - 12, ancho, 24),
						Color(0.35, 1.0, 0.6) if resuelta else Color(0.3, 0.85, 1.0), false, 1.5)
				Dibujo.texto(self, txt, Vector2(c.x, y), 14, Color.WHITE, true, true, false)
			elif not resuelta:
				var pulso := 0.5 + 0.5 * sin(tiempo * 3 + c.x)
				draw_arc(c, 18 + pulso * 4, 0, TAU, 32, Color(0.3, 0.85, 1.0, 0.25 + 0.3 * pulso), 1.5)

	# indicador de ocultamiento sobre el ladrón
	if not p.demo:
		var j := p.jugador
		var arb := p.ocultamiento.arbusto_actual
		if arb != Vector2i(-99, -99):
			var col := Color(0.45, 1.0, 0.55) if j.oculto else Color(1.0, 0.45, 0.35)
			draw_arc(Mapa.centro(arb), Config.RADIO_ARBUSTO * T, 0, TAU, 32, Color(col, 0.7), 1.5)
			if j.oculto:
				var b := j.pos + Vector2(0, -24)
				draw_circle(b, 8, Color(0.04, 0.08, 0.05, 0.85))
				# ojo tachado
				draw_arc(b, 5, PI * 0.15, PI * 0.85, 8, col, 1.5)
				draw_arc(b, 5, PI * 1.15, PI * 1.85, 8, col, 1.5)
				draw_line(b + Vector2(-6, 6), b + Vector2(6, -6), col, 1.5)
			elif p.ocultamiento.bloqueado:
				var f := minf(1.0, p.ocultamiento.t_sin_contacto / Config.TIEMPO_PARA_OCULTARSE)
				draw_arc(j.pos, 15, -PI / 2, -PI / 2 + TAU * f, 24, col, 2.5)

	for e in etiquetas:
		var f: float = e["t"] / e["dur"]
		Dibujo.texto(self, e["texto"], e["pos"] + Vector2(0, -18 * f), 13, Color(e["color"], 1.0 - f * f),
				true, true)

	for d in p.destellos:
		var f: float = d[1] / 0.8
		Dibujo.texto(self, "+1 joya", d[0] + Vector2(0, -24 - 30 * f), 18, Config.JOYA[0], true, true)

	# alarma: borde rojo parpadeante
	for c in p.camaras:
		if c.estado() == Def.ALARMA and int(tiempo * 4) % 2 == 0:
			draw_rect(Rect2(3, 3, Config.ANCHO - 6, Config.ALTO_MAPA - 6), Color8(220, 40, 40), false, 6)
			break

	if juego.consola and juego.consola.visible and not p.demo:
		for g in p.guardias:
			Dibujo.texto(self, "G%d %s  pila:%d" % [g.id + 1, g.estado(), g.pila.tamano()],
					g.pos + Vector2(0, 26), 12, Color.WHITE, true)
		for c in p.camaras:
			Dibujo.texto(self, c.estado(), c.pos + Vector2(0, 20), 12, Color8(180, 230, 255), true)


# --- radar ------------------------------------------------------------------- #
func _dibujar_radares(p: Partida, tiempo: float) -> void:
	for m in marcas:
		var f: float = m["t"] / 4.0
		var r := T * (1.2 + 1.2 * sin(m["t"] * 5.0) * 0.15)
		draw_arc(m["pos"], r * 2.0, 0, TAU, 40, Color(1.0, 0.3, 0.3, 0.6 * (1 - f)), 2.0)
		draw_arc(m["pos"], r, 0, TAU, 32, Color(1.0, 0.3, 0.3, 0.35 * (1 - f)), 1.0)
		Dibujo.texto(self, "detectado aquí", m["pos"] + Vector2(0, -r * 2 - 8), 11,
				Color(1.0, 0.5, 0.45, 1 - f), true, true)
	for r in p.radares:
		var alc: float = r.alcance()
		var est: String = r.estado()
		match est:
			Def.REPOSO:
				var falta: float = clampf(r.tiempo_restante() / r.intervalo(), 0.0, 1.0)
				draw_arc(r.pos, alc, 0, TAU, 96, Color(0.3, 0.9, 0.7, 0.08), 1.0)
				draw_arc(r.pos, 15, -PI / 2, -PI / 2 + TAU * (1.0 - falta), 32, Color(0.3, 0.9, 0.7, 0.8), 2.5)
			Def.AVISO:
				var pulso := 0.5 + 0.5 * sin(tiempo * 14.0)
				draw_arc(r.pos, alc, 0, TAU, 96, Color(1.0, 0.8, 0.25, 0.25 + 0.45 * pulso), 2.5)
				Dibujo.texto(self, "%.1f" % maxf(0.0, r.tiempo_restante()), r.pos + Vector2(0, -26), 14,
						Color(1.0, 0.85, 0.3), true, true)
			Def.BARRIDO, Def.ANALISIS:
				draw_arc(r.pos, alc, 0, TAU, 96, Color(0.35, 1.0, 0.6, 0.25), 1.5)
				# El dibujo del haz sigue el alcance real del barrido.
				var cola := 0.6
				var n := 14
				for k in n:
					var a0: float = r.angulo - cola * float(k) / n
					var a1: float = r.angulo - cola * float(k + 1) / n
					var e0: Vector2 = r.extremo_barrido(a0)
					var e1: Vector2 = r.extremo_barrido(a1)
					var alfa := 0.32 * (1.0 - float(k) / n)
					draw_colored_polygon(PackedVector2Array([r.pos, e0, e1]), Color(0.3, 1.0, 0.55, alfa))
				draw_line(r.pos, r.extremo_barrido(r.angulo), Color(0.6, 1.0, 0.75, 0.9), 2.0)
				# sectores ya registrados con presencia
				for s in Radar.SECTORES:
					if r.obs_p[s] == 1:
						var am := (s + 0.5) * TAU / Radar.SECTORES
						var col := Color(0.4, 0.8, 1.0) if r.obs_a[s] == 1 else Color(1.0, 0.4, 0.35)
						draw_circle(r.pos + Vector2.from_angle(am) * 22, 3, col)
		# el aparato
		draw_circle(r.pos, 11, Color(0.07, 0.1, 0.12))
		draw_arc(r.pos, 11, 0, TAU, 24, Color(0.4, 0.9, 0.75), 1.5)
		var plato: float = r.angulo if est in [Def.BARRIDO, Def.ANALISIS] else tiempo * 0.6
		draw_line(r.pos, r.pos + Vector2.from_angle(plato) * 9, Color(0.7, 1.0, 0.85), 2.5)
		draw_circle(r.pos, 3, Color(1.0, 0.4, 0.35) if r.ultimo_resultado == "INTRUSION" else Color(0.4, 1.0, 0.6))
