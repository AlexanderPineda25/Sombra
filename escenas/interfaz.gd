## Interfaz: HUD, pistas breves y pantallas del flujo
## (menú, pausa, derrota, victoria). Cada pantalla es la salida de un estado
## del AFD de flujo.
extends Node2D

var juego
var avisos: Array = []           ## pistas breves: {texto, t}

const DURACION_INTRO := 4.2


func _process(dt: float) -> void:
	for a in avisos:
		a["t"] += dt
	avisos = avisos.filter(func(a): return a["t"] < 5.0)
	queue_redraw()


func avisar(texto: String) -> void:
	avisos.append({"texto": texto, "t": 0.0})


func _draw() -> void:
	var p: Partida = juego.partida
	var estado: String = juego.flujo.actual
	if estado in [Def.JUGANDO, Def.TERMINAL] and not p.demo:
		_peligro(p)
	if estado != Def.MENU:
		_hud(p)
		_avisos()
	if estado in [Def.JUGANDO, Def.PAUSA] and not p.demo and juego.t_intro < DURACION_INTRO:
		_tarjeta_nivel(p, juego.t_intro)
	match estado:
		Def.MENU:
			_menu(juego.tiempo)
		Def.PAUSA:
			_pausa()
		Def.DERROTA:
			_derrota(p)
		Def.VICTORIA:
			_victoria(p, false)
		Def.FIN:
			_victoria(p, true)


# ====================================================================== #
# HUD
# ====================================================================== #
func _hud(p: Partida) -> void:
	var y0 := float(Config.ALTO_MAPA)
	draw_rect(Rect2(0, y0, Config.ANCHO, Config.ALTO_HUD), Config.HUD_FONDO)
	draw_line(Vector2(0, y0), Vector2(Config.ANCHO, y0), Color8(60, 64, 92), 2)
	Dibujo.texto(self, p.nombre, Vector2(16, y0 + 8), 20, Config.TEXTO, false, true)
	var j := p.jugador
	var est := "Sigiloso"
	if j.oculto:
		est = "Escondido"
	elif p.energia.agotado:
		est = "Agotado"
	elif j.corriendo:
		est = "Corriendo (haces ruido)"
	elif j.agachado:
		est = "Agachado"
	Dibujo.texto(self, est, Vector2(16, y0 + 36), 16, Config.TEXTO_SUAVE)

	_energia(p, Vector2(232, y0 + 12))

	for i in p.total_joyas:
		var col := Color.WHITE if i < p.recogidas else Color(0.25, 0.27, 0.35)
		Arte.joya(self, i, Vector2(384 + i * 28, y0 + 22), 24, col)
	Dibujo.texto(self, "Joyas", Vector2(374, y0 + 38), 15, Config.TEXTO_SUAVE)

	for i in j.monedas:
		draw_texture_rect(Arte.moneda, Rect2(494 + i * 18, y0 + 14, 16, 16), false)
	Dibujo.texto(self, "Monedas · Q / clic", Vector2(494, y0 + 39), 13, Config.TEXTO_SUAVE)

	var seg := int(p.tiempo)
	Dibujo.texto(self, "%02d:%02d" % [seg / 60, seg % 60], Vector2(680, y0 + 14), 28, Config.TEXTO, false, true)

	var aviso := "Sin detectar"
	var col := Color8(110, 210, 140)
	for g in p.guardias:
		if g.estado() == Def.PERSECUCION:
			aviso = "¡TE VIERON!"
			col = Color8(255, 90, 90)
			break
		if g.estado() in [Def.ALERTA, Def.BUSQUEDA, Def.SOSPECHA]:
			aviso = "Sospechan..."
			col = Color8(255, 200, 80)
	Dibujo.texto(self, aviso, Vector2(Config.ANCHO - 16 - Dibujo.ancho_texto(aviso, 22, true), y0 + 10), 22, col, false, true)
	Dibujo.texto(self, "F1: consola", Vector2(Config.ANCHO - 100, y0 + 40), 15, Config.TEXTO_SUAVE)
	# radar: cuenta atrás del próximo escaneo
	if not p.radares.is_empty() and not p.demo:
		var r: Radar = p.radares[0]
		var txt := "Radar %.0f s" % maxf(0.0, r.tiempo_restante())
		var col_r := Color(0.45, 0.9, 0.7)
		if r.estado() == Def.AVISO:
			txt = "¡RADAR!"
			col_r = Color(1.0, 0.8, 0.3) if int(juego.tiempo * 6) % 2 == 0 else Color(1.0, 0.4, 0.3)
		elif r.estado() in [Def.BARRIDO, Def.ANALISIS]:
			txt = "Escaneando…"
			col_r = Color(0.35, 1.0, 0.6)
		Dibujo.texto(self, txt, Vector2(742, y0 + 40), 14, col_r, false, true)
	# terminales resueltas
	var resueltas := 0
	for t in p.terminales:
		if t["desafio"].resuelto:
			resueltas += 1
	if not p.terminales.is_empty():
		Dibujo.texto(self, "Terminales %d/%d" % [resueltas, p.terminales.size()], Vector2(560 + 60, y0 + 40), 15,
				Color(0.35, 1.0, 0.6) if resueltas == p.terminales.size() else Color(0.4, 0.85, 1.0))


## Barra de energía: es la cinta de la máquina de Turing de la batería
## (una casilla por celda; llena = 1, vacía = 0).
func _energia(p: Partida, o: Vector2) -> void:
	var e := p.energia
	var col := Color(0.35, 1.0, 0.6)
	if e.agotado:
		col = Color(1.0, 0.4, 0.3) if int(juego.tiempo * 5) % 2 == 0 else Color(0.6, 0.2, 0.15)
	elif e.fraccion() < 0.35:
		col = Color(1.0, 0.75, 0.3)
	Dibujo.texto(self, "ENERGÍA · Shift", o, 12, Config.TEXTO_SUAVE, false, true)
	var w := 7.0
	for i in e.celdas:
		var r := Rect2(o.x + i * (w + 1), o.y + 20, w, 14)
		var llena := e.maquina.cinta.leer_en(i + 1) == "1"
		draw_rect(r, col if llena else Color(0.12, 0.13, 0.18))
	draw_rect(Rect2(o.x - 2, o.y + 18, e.celdas * (w + 1) + 3, 18), Color(0.4, 0.45, 0.6), false, 1.0)


## Viñeta roja y aviso cuando algún guardia o cámara está viendo al ladrón.
func _peligro(p: Partida) -> void:
	var nivel := 0.0
	for g in p.guardias:
		if g.viendo:
			nivel = maxf(nivel, 1.0 if g.estado() == Def.PERSECUCION else clampf(g.sospecha, 0.25, 1.0))
	for c in p.camaras:
		if c.viendo:
			nivel = maxf(nivel, 0.8)
	if nivel <= 0.0:
		return
	var pulso := 0.6 + 0.4 * sin(juego.tiempo * 9.0)
	var a := 0.32 * nivel * pulso
	var w := float(Config.ANCHO)
	var h := float(Config.ALTO_MAPA)
	for k in 6:
		var g := 26.0 * (k + 1)
		var alfa := a * (1.0 - k / 6.0) * 0.35
		draw_rect(Rect2(0, 0, w, g), Color(1, 0.1, 0.1, alfa))
		draw_rect(Rect2(0, h - g, w, g), Color(1, 0.1, 0.1, alfa))
		draw_rect(Rect2(0, 0, g, h), Color(1, 0.1, 0.1, alfa))
		draw_rect(Rect2(w - g, 0, g, h), Color(1, 0.1, 0.1, alfa))
	var jp := p.jugador.pos
	draw_arc(jp, 20, -PI / 2, -PI / 2 + TAU * nivel, 32, Color(1, 0.25, 0.2, 0.9), 3)
	Dibujo.texto(self, "¡ZONA PELIGROSA!" if nivel < 1.0 else "¡TE VIERON!", Vector2(w / 2, 22), 18,
			Color(1, 0.4, 0.35), true, true)


func _avisos() -> void:
	for i in avisos.size():
		var a: Dictionary = avisos[i]
		var alfa := clampf(minf(a["t"] * 4.0, (5.0 - a["t"]) * 2.0), 0.0, 1.0)
		var w := Dibujo.ancho_texto(a["texto"], 16, true) + 28
		var r := Rect2(Config.ANCHO / 2.0 - w / 2, 46 + i * 34, w, 28)
		draw_rect(r, Color(0.03, 0.07, 0.1, 0.9 * alfa))
		draw_rect(r, Color(0.3, 0.86, 1.0, alfa), false, 1.5)
		Dibujo.texto(self, a["texto"], r.get_center(), 16, Color(1, 1, 1, alfa), true, true, false)


# ====================================================================== #
# Pantallas
# ====================================================================== #
func _velo(alfa := 0.67) -> void:
	draw_rect(Rect2(0, 0, Config.ANCHO, Config.ALTO), Color(0.02, 0.02, 0.05, alfa))


func _menu(tiempo: float) -> void:
	_velo(0.55)
	var cx := Config.ANCHO / 2.0
	# título con un barrido de linterna que lo recorre
	var titulo := "SOMBRA"
	var ancho := Dibujo.ancho_texto(titulo, 96, true)
	var x0 := cx - ancho / 2.0
	var barrido := fmod(tiempo * 0.35, 1.6) - 0.3
	var x := x0
	for c in titulo:
		var w := Dibujo.ancho_texto(c, 96, true)
		var f := clampf(1.0 - absf((x + w / 2.0 - x0) / ancho - barrido) * 4.0, 0.0, 1.0)
		var col := Color8(240, 236, 220).lerp(Color(1.0, 0.86, 0.5), f)
		Dibujo.texto(self, c, Vector2(x + w / 2.0, 140), 96, col, true, true)
		x += w
	Dibujo.texto(self, "Robo en el Museo", Vector2(cx, 210), 32, Config.ACENTO, true)
	Dibujo.texto(self, "Roba las joyas y escapa sin que te atrapen.", Vector2(cx, 262), 20, Config.TEXTO, true)

	# niveles
	var nombres := ["El vestíbulo", "La galería", "La bóveda"]
	var maquinas := ["MT estándar", "MT multipista", "MT multicinta + estándar"]
	for i in Niveles.cantidad():
		var r := Rect2(cx - 330 + i * 225, 300, 210, 84)
		var hover := 0.5 + 0.5 * sin(tiempo * 2.0 + i)
		draw_rect(r, Color(0.04, 0.06, 0.1, 0.88))
		draw_rect(r, Color(Config.ACENTO, 0.45 + 0.25 * hover), false, 1.5)
		Dibujo.texto(self, str(i + 1), r.position + Vector2(22, 26), 34, Config.ACENTO, true, true)
		Dibujo.texto(self, nombres[i], r.position + Vector2(44, 14), 18, Config.TEXTO, false, true)
		Dibujo.texto(self, maquinas[i], r.position + Vector2(44, 40), 13, Color(0.45, 0.85, 1.0))
		Dibujo.texto(self, "nivel%d.sombra" % (i + 1), r.position + Vector2(44, 58), 12, Config.TEXTO_SUAVE)

	var lineas := [
		"WASD / flechas: moverte    C: agacharte    Shift: correr    Clic o Q: moneda",
		"E: terminal (máquinas de Turing)    Esc: pausa    F1: consola (AFD, MT, radar, lenguaje)",
	]
	for i in lineas.size():
		Dibujo.texto(self, lineas[i], Vector2(cx, 420 + i * 28), 17, Config.TEXTO_SUAVE, true)
	# franja de modelos de computación
	var modelos := ["AFD", "AP", "MT estándar", "MT multicinta", "MT multipista", "ER → AFN → AFD", "Gramática LL(1)",
			"Gramática musical"]
	var total := 0.0
	for m in modelos:
		total += Dibujo.ancho_texto(m, 13, true) + 26
	var xm := cx - total / 2.0
	for m in modelos:
		var w := Dibujo.ancho_texto(m, 13, true) + 18
		draw_rect(Rect2(xm, 488, w, 22), Color(0.06, 0.12, 0.16, 0.9))
		draw_rect(Rect2(xm, 488, w, 22), Color(0.3, 0.86, 1.0, 0.5), false, 1.0)
		Dibujo.texto(self, m, Vector2(xm + w / 2, 499), 13, Color(0.55, 0.92, 1.0), true, true, false)
		xm += w + 8
	if int(tiempo * 2) % 2 == 0:
		Dibujo.texto(self, "ENTER: empezar      1 · 2 · 3: elegir nivel", Vector2(cx, 556), 26, Color.WHITE, true, true)


## Tarjeta al empezar un nivel: nombre, objetivo y los modelos que lo vigilan.
func _tarjeta_nivel(p: Partida, t: float) -> void:
	var alfa := clampf(minf(t * 3.0, (DURACION_INTRO - t) * 1.6), 0.0, 1.0)
	var cx := Config.ANCHO / 2.0
	var desliz := (1.0 - minf(t * 3.0, 1.0)) * 30.0
	var r := Rect2(cx - 310, 140 - desliz, 620, 272)
	draw_rect(r, Color(0.02, 0.03, 0.06, 0.9 * alfa))
	draw_rect(r, Color(Config.ACENTO, 0.8 * alfa), false, 2.0)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4), Color(Config.ACENTO, alfa))
	var partes := p.nombre.split(" · ")
	Dibujo.texto(self, partes[0].to_upper(), Vector2(cx, r.position.y + 34), 20, Color(Config.ACENTO, alfa), true, true)
	Dibujo.texto(self, partes[1] if partes.size() > 1 else p.nombre, Vector2(cx, r.position.y + 74), 44,
			Color(1, 1, 1, alfa), true, true)
	var obj := "Roba %d joyas%s y escapa por la salida." % [p.total_joyas,
			", desactiva %d terminal%s" % [p.terminales.size(), "es" if p.terminales.size() > 1 else ""] \
			if not p.terminales.is_empty() else ""]
	Dibujo.texto(self, obj, Vector2(cx, r.position.y + 116), 17, Color(Config.TEXTO, alfa), true)
	var modelos := PackedStringArray()
	modelos.append("%d guardias: AFD de 6 estados + autómata de pila" % p.guardias.size())
	if not p.camaras.is_empty():
		modelos.append("%d cámara%s: AFD" % [p.camaras.size(), "s" if p.camaras.size() > 1 else ""])
	if not p.radares.is_empty():
		modelos.append("radar: AFD + MT multicinta + MT multipista")
	var vars := PackedStringArray()
	for term in p.terminales:
		var v: String = {"estandar": "MT estándar", "multicinta": "MT multicinta", "multipista": "MT multipista"}[term["desafio"].variante]
		if not v in vars:
			vars.append(v)
	if not vars.is_empty():
		modelos.append("terminales: " + " y ".join(vars))
	for i in modelos.size():
		Dibujo.texto(self, "▸ " + modelos[i], Vector2(r.position.x + 40, r.position.y + 148 + i * 22), 15,
				Color(0.55, 0.9, 1.0, alfa))
	var c := Niveles.compilado(p.indice)
	var pausas := 0
	for g in c.datos.get("guardias", []):
		pausas += g["acciones"].size()
	Dibujo.texto(self, "compilado desde %s · %d tokens · %d pausas de patrulla programadas" % [
			Niveles.ARCHIVOS[p.indice], c.tokens.size() - 1, pausas],
			Vector2(cx, r.end.y - 14), 12, Color(Config.TEXTO_SUAVE, alfa), true)


func _pausa() -> void:
	_velo()
	var cx := Config.ANCHO / 2.0
	Dibujo.texto(self, "PAUSA", Vector2(cx, 280), 72, Config.TEXTO, true, true)
	Dibujo.texto(self, "Esc: continuar      Enter: salir al menú", Vector2(cx, 360), 22, Config.TEXTO_SUAVE, true)


func _derrota(p: Partida) -> void:
	_velo(0.75)
	var cx := Config.ANCHO / 2.0
	Dibujo.texto(self, "¡TE ATRAPARON!", Vector2(cx, 260), 72, Color8(255, 90, 90), true, true)
	Dibujo.texto(self, "Joyas robadas: %d/%d" % [p.recogidas, p.total_joyas], Vector2(cx, 340), 24, Config.TEXTO, true)
	Dibujo.texto(self, "Enter: reintentar      Esc: menú", Vector2(cx, 400), 22, Config.TEXTO_SUAVE, true)


static func calificacion(p: Partida) -> Array:
	if p.detecciones() == 0 and p.alarmas == 0:
		return ["Sombra perfecta", Color8(120, 220, 160)]
	if p.detecciones() <= 1:
		return ["Ladrón profesional", Color8(240, 210, 120)]
	return ["Escape por los pelos", Color8(255, 150, 100)]


func _victoria(p: Partida, ultimo: bool) -> void:
	_velo(0.75)
	var cx := Config.ANCHO / 2.0
	Dibujo.texto(self, "¡GOLPE COMPLETADO!" if ultimo else "¡ESCAPASTE!", Vector2(cx, 220), 64, Color8(120, 220, 160), true, true)
	var cal := calificacion(p)
	Dibujo.texto(self, cal[0], Vector2(cx, 290), 32, cal[1], true, true)
	var seg := int(p.tiempo)
	var datos := [
		"Tiempo: %02d:%02d" % [seg / 60, seg % 60],
		"Veces que te persiguieron: %d" % p.detecciones(),
		"Alarmas activadas: %d" % p.alarmas,
		"Monedas usadas: %d" % p.monedas_usadas,
	]
	for i in datos.size():
		Dibujo.texto(self, datos[i], Vector2(cx, 340 + i * 28), 21, Config.TEXTO, true)
	var cont: Dictionary = p.seguridad.contador
	var resumen := "Bajo el capó: %d transiciones de AFD · %d ejecuciones de MT · %d avisos de radio" % [
			cont.get("estado", 0), cont.get("turing", 0), cont.get("alerta", 0)]
	Dibujo.texto(self, resumen, Vector2(cx, 462), 15, Color(0.5, 0.88, 1.0), true)
	Dibujo.texto(self, "Enter: volver al menú" if ultimo else "Enter: siguiente nivel      Esc: menú",
			Vector2(cx, 500), 22, Config.TEXTO_SUAVE, true)
