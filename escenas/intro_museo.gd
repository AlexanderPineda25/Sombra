## Secuencia de apertura construida con los mismos sprites y suelo del juego.
extends Control

signal terminada

const DURACION := 4.8
const CUADRO := 64
const PASILLO := Vector2(96, 290)
const PUERTA := Vector2(736, 290)
const EMISOR := Vector2(500, 213)
const OSCURO := Color(0.035, 0.044, 0.076)

var tiempo := 0.0


func _process(dt: float) -> void:
	tiempo += dt
	if tiempo >= DURACION:
		terminar()
	else:
		queue_redraw()


func _input(evento: InputEvent) -> void:
	if not visible:
		return
	var saltar := false
	if evento is InputEventKey and evento.pressed and not evento.echo:
		saltar = evento.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif evento is InputEventMouseButton and evento.pressed:
		saltar = evento.button_index == MOUSE_BUTTON_LEFT
	if saltar:
		get_viewport().set_input_as_handled()
		terminar()


func terminar() -> void:
	hide()
	set_process(false)
	terminada.emit()
	queue_free()


func _draw() -> void:
	var lienzo := Rect2(0, 0, Config.ANCHO, Config.ALTO)
	draw_rect(lienzo, OSCURO)
	_dibujar_pasillo()
	_dibujar_vigilancia()
	_dibujar_ladron()
	draw_rect(Rect2(0, 0, Config.ANCHO, 144), OSCURO)
	draw_rect(Rect2(0, 560, Config.ANCHO, 144), OSCURO)
	draw_line(Vector2(96, 119), Vector2(864, 119), Color(Config.ACENTO, 0.24))
	Dibujo.texto(self, "Museo Nacional", Vector2(480, 93), 25, Config.TEXTO, true, true)
	Dibujo.texto(self, "Esc, Enter o clic para saltar", Vector2(480, 636), 16, Config.TEXTO_SUAVE, true)
	var alfa := maxf(1.0 - tiempo / 0.42, smoothstep(4.22, DURACION, tiempo))
	draw_rect(lienzo, Color(OSCURO, clampf(alfa, 0.0, 1.0)))


func _dibujar_pasillo() -> void:
	var suelo := Color(0.35, 0.37, 0.53)
	for y in 4:
		for x in 12:
			var pos := PASILLO + Vector2(x * CUADRO, y * CUADRO - CUADRO)
			var pieza := Arte.PISO_CLARO if (x + y) % 2 == 0 else Arte.PISO_OSCURO
			Arte.casilla(self, pieza, Rect2(pos, Vector2.ONE * CUADRO), suelo)
	for x in 12:
		var pos := PASILLO + Vector2(x * CUADRO, -CUADRO * 2)
		Arte.casilla(self, Arte.PARED_FRENTE, Rect2(pos, Vector2.ONE * CUADRO), suelo)
	var abierta := tiempo > 3.45
	var color := Config.SALIDA_ABIERTA if abierta else Config.ACENTO
	Arte.casilla(self, Arte.PUERTA_ABIERTA if abierta else Arte.PUERTA_CERRADA,
			Rect2(PUERTA - Vector2(0, 44), Vector2(94, 155)), suelo.lightened(0.23))
	draw_rect(Rect2(PUERTA + Vector2(35, -52), Vector2(24, 3)), color)


func _dibujar_vigilancia() -> void:
	var barrido := lerpf(2.55, 0.82, smoothstep(1.1, 3.1, tiempo))
	var luz := Config.CONO_CAMARA
	for i in 5:
		var ancho := 0.33 - i * 0.037
		var a := EMISOR + Vector2.from_angle(barrido - ancho) * 304.0
		var b := EMISOR + Vector2.from_angle(barrido + ancho) * 304.0
		draw_colored_polygon(PackedVector2Array([EMISOR, a, b]), Color(luz, 0.052))
	draw_circle(EMISOR, 6, Color(luz, 0.12))
	draw_circle(EMISOR, 2, luz)


func _dibujar_ladron() -> void:
	var x := lerpf(122, 350, smoothstep(0.25, 1.55, tiempo))
	x += lerpf(0, 428, smoothstep(2.25, 4.28, tiempo))
	var camina := tiempo < 1.55 or tiempo > 2.25
	var fila := 1 if camina else 0
	var cuadro := int(tiempo * 11) % 8 if camina else 0
	var pos := Vector2(x, 365)
	draw_set_transform(pos)
	draw_circle(Vector2(0, 12), 31, Color(0.025, 0.04, 0.07, 0.45))
	draw_texture_rect_region(Arte.ladron, Rect2(-38, -38, 76, 76),
			Rect2(cuadro * CUADRO, fila * CUADRO, CUADRO, CUADRO))
	draw_set_transform(Vector2.ZERO)
