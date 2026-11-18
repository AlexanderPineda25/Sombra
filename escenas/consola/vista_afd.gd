## Pestaña "Guardias" de la consola: el AFD real de cada guardia.
##
## Izquierda: una tarjeta por guardia (estado actual, último evento, acción).
## Centro: el diagrama del AFD del guardia seleccionado con todas sus
## transiciones etiquetadas; se resalta el estado actual y la última
## transición que ejecutó. Abajo: la tabla δ completa (6 × 7) con la celda
## que se acaba de usar marcada.
class_name VistaAFD
extends Control

const T := preload("res://escenas/consola/tema.gd")
const ABREV := {"PATRULLA": "PAT", "SOSPECHA": "SOS", "ALERTA": "ALE", "PERSECUCION": "PER",
		"BUSQUEDA": "BUS", "REGRESO": "REG", "REPOSO": "REP", "AVISO": "AVI", "BARRIDO": "BAR",
		"ANALISIS": "ANA"}
## Posición relativa de cada estado en el diagrama.
const POS_GUARDIA := {
	"PATRULLA": Vector2(0.50, 0.10), "SOSPECHA": Vector2(0.88, 0.30), "ALERTA": Vector2(0.88, 0.72),
	"PERSECUCION": Vector2(0.50, 0.92), "BUSQUEDA": Vector2(0.12, 0.72), "REGRESO": Vector2(0.12, 0.30),
}
const POS_RADAR := {
	"REPOSO": Vector2(0.15, 0.5), "AVISO": Vector2(0.5, 0.12), "BARRIDO": Vector2(0.85, 0.5),
	"ANALISIS": Vector2(0.5, 0.88),
}

var partida: Partida
var seleccionado := 0
var tarjetas: Array = []          ## [Rect2, índice] para elegir guardia con el ratón


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for t in tarjetas:
			if t[0].has_point(e.position):
				seleccionado = t[1]
				accept_event()


func _draw() -> void:
	tarjetas.clear()
	draw_rect(Rect2(Vector2.ZERO, size), T.FONDO)
	if partida == null or partida.guardias.is_empty():
		Dibujo.texto(self, "No hay guardias en este nivel.", size / 2, 16, T.SUAVE, true)
		return
	seleccionado = clampi(seleccionado, 0, partida.guardias.size() - 1)
	var ancho_lista := clampf(size.x * 0.26, 200, 270)
	# --- tarjetas --------------------------------------------------------- #
	var alto_t := minf(92.0, (size.y - 10) / partida.guardias.size() - 6)
	for i in partida.guardias.size():
		var g: Guardia = partida.guardias[i]
		var r := Rect2(6, 6 + i * (alto_t + 6), ancho_lista - 12, alto_t)
		tarjetas.append([r, i])
		var col: Color = T.COLOR_ESTADO[g.estado()]
		draw_rect(r, T.PANEL_2 if i == seleccionado else T.PANEL)
		draw_rect(r, T.CIAN if i == seleccionado else T.BORDE, false, 2.0 if i == seleccionado else 1.0)
		draw_rect(Rect2(r.position, Vector2(5, r.size.y)), col)
		Dibujo.texto(self, "G%d" % (g.id + 1), r.position + Vector2(14, 6), 16, T.TEXTO, false, true, false)
		Dibujo.texto(self, g.estado(), r.position + Vector2(48, 7), 14, col, false, true, false)
		if alto_t > 50:
			var ev := g.ultimo_evento
			Dibujo.texto(self, "evento: " + ("'%s' %s" % [ev, Def.NOMBRE_EVENTO[ev]] if ev != "" else "—"),
					r.position + Vector2(14, 30), 12, T.SUAVE, false, false, false)
		if alto_t > 70:
			Dibujo.texto(self, "acción: " + g.afd.salida(), r.position + Vector2(14, 50), 12, T.SUAVE, false, false, false)
		if g.viendo:
			Dibujo.texto(self, "◉ VE AL LADRÓN", Vector2(r.end.x - 98, r.position.y + 8), 11, T.ROJO, false, true, false)

	# --- diagrama --------------------------------------------------------- #
	var g: Guardia = partida.guardias[seleccionado]
	var tabla_alto := 7 * 20.0 + 30
	var zona := Rect2(ancho_lista + 10, 6, size.x - ancho_lista - 16, size.y - tabla_alto - 18)
	draw_rect(zona, T.PANEL)
	draw_rect(zona, T.BORDE, false, 1.0)
	Dibujo.texto(self, "AFD del guardia G%d  ·  M = (Q, Σ, δ, PATRULLA, {PERSECUCION})" % (g.id + 1),
			zona.position + Vector2(10, 6), 14, T.CIAN, false, true, false)
	var ultimo: Array = g.registro[-1] if not g.registro.is_empty() else []
	diagrama(self, g.afd, zona.grow(-34), POS_GUARDIA, ultimo, minf(26.0, zona.size.y * 0.075))
	Dibujo.texto(self, "inicial →", zona.position + Vector2(10, 28), 12, T.SUAVE, false, false, false)
	Dibujo.texto(self, "◎ final (aceptación) = PERSECUCION", Vector2(zona.position.x + 10, zona.end.y - 22), 12,
			T.SUAVE, false, false, false)
	if not ultimo.is_empty():
		var txt := "última: δ(%s, %s) = %s" % [ultimo[1], ultimo[0], ultimo[2]]
		Dibujo.texto(self, txt, Vector2(zona.end.x - 12 - Dibujo.ancho_texto(txt, 13, true), zona.end.y - 22), 13,
				T.AMBAR, false, true, false)

	# --- tabla δ ---------------------------------------------------------- #
	var tz := Rect2(ancho_lista + 10, size.y - tabla_alto - 6, size.x - ancho_lista - 16, tabla_alto)
	tabla(self, g.afd, tz, ultimo)


## Dibuja un AFD como grafo. `ultimo` = [símbolo, origen, destino] resalta una flecha.
static func diagrama(ci: CanvasItem, afd: AFD, zona: Rect2, posiciones: Dictionary, ultimo: Array,
		radio := 24.0) -> void:
	var pos := {}
	for q in afd.estados:
		pos[q] = zona.position + posiciones.get(q, Vector2(0.5, 0.5)) * zona.size
	# agrupa los símbolos por par (origen, destino)
	var pares := {}
	var bucles := {}
	for q in afd.delta:
		for s in afd.delta[q]:
			var d: String = afd.delta[q][s]
			if d == q:
				bucles[q] = bucles.get(q, []) + [s]
			else:
				var k: String = q + ">" + d
				pares[k] = pares.get(k, []) + [s]
	for k in pares:
		var qs: PackedStringArray = k.split(">")
		var a: Vector2 = pos[qs[0]]
		var b: Vector2 = pos[qs[1]]
		var activo: bool = not ultimo.is_empty() and ultimo[1] == qs[0] and ultimo[2] == qs[1]
		var col := T.AMBAR if activo else Color(0.42, 0.52, 0.6, 0.85)
		var dir := (b - a).normalized()
		var lado := dir.orthogonal() * 6.0
		var s := a + dir * radio + lado
		var e := b - dir * radio + lado
		ci.draw_line(s, e, col, 3.0 if activo else 1.5, true)
		ci.draw_colored_polygon(PackedVector2Array([e, e - dir.rotated(-0.38) * 10, e - dir.rotated(0.38) * 10]), col)
		var etiqueta := ",".join(PackedStringArray(pares[k]))
		var m := s.lerp(e, 0.42) + dir.orthogonal() * 11.0
		var w := Dibujo.ancho_texto(etiqueta, 12, true) + 8
		ci.draw_rect(Rect2(m - Vector2(w / 2, 9), Vector2(w, 18)), Color(T.FONDO, 0.92))
		Dibujo.texto(ci, etiqueta, m, 12, T.AMBAR if activo else T.TEXTO, true, true, false)
	for q in pos:
		var c: Vector2 = pos[q]
		var actual: bool = q == afd.actual
		var col: Color = T.COLOR_ESTADO.get(q, T.CIAN)
		if actual:
			ci.draw_circle(c, radio + 6, Color(col, 0.18))
		ci.draw_circle(c, radio, col if actual else T.PANEL_2)
		ci.draw_arc(c, radio, 0, TAU, 40, col, 2.0, true)
		if q in afd.finales:
			ci.draw_arc(c, radio - 4, 0, TAU, 40, col if not actual else T.FONDO, 1.5, true)
		if q == afd.inicial:
			var p := c + Vector2(-radio - 22, 0)
			ci.draw_line(p, c - Vector2(radio, 0), T.TEXTO, 1.5)
			ci.draw_colored_polygon(PackedVector2Array([c - Vector2(radio, 0), c - Vector2(radio + 8, -5),
					c - Vector2(radio + 8, 5)]), T.TEXTO)
		Dibujo.texto(ci, ABREV.get(q, q.substr(0, 3)), c, maxi(8, int(radio * 0.55)), T.FONDO if actual else T.TEXTO,
				true, true, false)
		if bucles.has(q):
			var lazo := ",".join(PackedStringArray(bucles[q]))
			var debajo := c + Vector2(0, radio + 10) if c.y < zona.get_center().y else c + Vector2(0, -radio - 10)
			Dibujo.texto(ci, "↺ " + lazo, debajo, 11, T.SUAVE, true, false, false)


## Tabla de transición δ con la celda usada en último lugar resaltada.
static func tabla(ci: CanvasItem, afd: AFD, zona: Rect2, ultimo: Array) -> void:
	ci.draw_rect(zona, T.PANEL)
	ci.draw_rect(zona, T.BORDE, false, 1.0)
	var simbolos: Array = afd.alfabeto
	var filas: Array = afd.estados
	var col0 := 90.0
	var cw := (zona.size.x - col0 - 8) / simbolos.size()
	var rh := (zona.size.y - 8) / (filas.size() + 1)
	var o := zona.position + Vector2(4, 4)
	Dibujo.texto(ci, "δ", o + Vector2(col0 / 2, rh / 2), 14, T.CIAN, true, true, false)
	for j in simbolos.size():
		Dibujo.texto(ci, simbolos[j], o + Vector2(col0 + cw * (j + 0.5), rh / 2), 13, T.CIAN, true, true, false)
	for i in filas.size():
		var q: String = filas[i]
		var y := o.y + rh * (i + 1)
		var actual: bool = q == afd.actual
		if actual:
			ci.draw_rect(Rect2(o.x, y, zona.size.x - 8, rh), Color(T.COLOR_ESTADO.get(q, T.CIAN), 0.12))
		var pre := ("→" if q == afd.inicial else "") + ("*" if q in afd.finales else "")
		Dibujo.texto(ci, pre + ABREV.get(q, q), Vector2(o.x + col0 / 2, y + rh / 2), 12,
				T.COLOR_ESTADO.get(q, T.TEXTO) if actual else T.TEXTO, true, actual, false)
		for j in simbolos.size():
			var s: String = simbolos[j]
			var d: String = afd.delta[q][s]
			var c := Rect2(o.x + col0 + cw * j, y, cw, rh)
			var usado: bool = not ultimo.is_empty() and ultimo[1] == q and ultimo[0] == s
			if usado:
				ci.draw_rect(c.grow(-1), Color(T.AMBAR, 0.35))
				ci.draw_rect(c.grow(-1), T.AMBAR, false, 1.5)
			Dibujo.texto(ci, ABREV.get(d, d), c.get_center(), 12, T.AMBAR if usado else (T.SUAVE if d == q else T.TEXTO),
					true, usado, false)
