## Base de los tres minijuegos de las terminales (cerradura, rejilla láser y
## bóveda): marco visual, introducción breve, ensayo, pausa, HUD, avisos,
## modo accesible y acceso al visor técnico de la máquina.
##
## Regla de oro: la VALIDEZ LÓGICA la decide siempre la máquina de Turing del
## desafío (Desafio.ejecutar_intento / ejecutar_hasta). Godot solo gestiona lo
## físico (tiempo, timing, colisiones con el haz) y lo distingue:
##   fallo físico  -> Partida.fallo_fisico (ruido; no es un rechazo de la MT)
##   fallo lógico  -> la MT RECHAZÓ -> juego.terminal_terminada(false)
##   error técnico -> la MT no se detuvo en MAX_PASOS (no es culpa del jugador)
class_name Minijuego
extends Control

const ANCHO := 960.0
const ALTO := 704.0
const PANEL := Rect2(28, 22, 904, 660)
const CIAN := Color(0.30, 0.86, 1.0)
const VERDE := Color(0.35, 1.0, 0.58)
const ROJO := Color(1.0, 0.36, 0.32)
const AMBAR := Color(1.0, 0.78, 0.35)
const NARANJA := Color(1.0, 0.55, 0.2)
const FONDO := Color(0.035, 0.06, 0.10, 0.97)
const TEXTO := Color(0.88, 0.92, 0.96)
const SUAVE := Color(0.55, 0.64, 0.74)
const G := ["R", "Z", "E", "A"]
const NOMBRE := {"R": "Rubí", "Z": "Zafiro", "E": "Esmeralda", "A": "Ámbar"}
const SOBRECARGA_MAX := 3

static var accesible := false      ## sin límite de tiempo, más lento y más tolerante (se conserva)

var juego
var terminal = null
var desafio: Desafio
var fase := "intro"                ## intro | juego | verificando | exito
var pausado := false
var tiempo := 0.0
var aviso := ""
var aviso_col := TEXTO
var aviso_t := 0.0
var sobrecarga := 0                ## deslices físicos acumulados
var fallos_logicos := 0
var fallos_fisicos := 0
var ensayo := true                 ## el primer tramo de cada minijuego no se castiga
var botones := {}


func _ready() -> void:
	visible = false
	position = Vector2.ZERO
	size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var y := PANEL.end.y - 46
	_boton("visor", "Ver la máquina (V)", Vector2(PANEL.position.x + 16, y), 186, abrir_visor)
	_boton("pausa", "Pausa (P)", Vector2(PANEL.position.x + 210, y), 112, alternar_pausa)
	_boton("accesible", "", Vector2(PANEL.position.x + 330, y), 196, alternar_accesible)
	_boton("salir", "Salir (Esc)", Vector2(PANEL.end.x - 132, y), 116, func(): juego.cerrar_terminal())


func _boton(id: String, texto: String, pos: Vector2, ancho: float, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.size = Vector2(ancho, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"normal": Color(0.07, 0.14, 0.2), "hover": Color(0.1, 0.24, 0.32),
				"pressed": Color(0.16, 0.4, 0.5), "disabled": Color(0.06, 0.08, 0.1)}[estado]
		st.border_color = CIAN if estado != "disabled" else Color(0.2, 0.25, 0.3)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		b.add_theme_stylebox_override(estado, st)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(accion)
	add_child(b)
	botones[id] = b


# ---------------------------------------------------------------------- #
func abrir(t) -> void:
	terminal = t
	desafio = t["desafio"]
	pausado = false
	aviso = ""
	aviso_t = 0.0
	sobrecarga = 0
	fallos_fisicos = 0
	fallos_logicos = 0
	ensayo = true
	fase = "exito" if desafio.resuelto else "intro"
	_preparar()
	visible = true
	var nombres := []
	for f in desafio.filas:
		nombres.append(f["nombre"])
	juego.partida.registrar_maquina(desafio.variante, {"origen": "Terminal · " + desafio.titulo,
			"desafio": desafio, "nombres": nombres})


func cerrar() -> void:
	visible = false


func comenzar() -> void:
	if fase != "intro":
		return
	fase = "juego"
	_comenzar()


func alternar_pausa() -> void:
	if fase in ["juego", "verificando"]:
		pausado = not pausado


func alternar_accesible() -> void:
	accesible = not accesible
	avisar("Modo accesible " + ("ACTIVADO: sin reloj, más lento y más tolerante." if accesible else "desactivado."),
			CIAN)


func visor_abierto() -> bool:
	return juego != null and juego.terminal_ui.visible


## Abre la superposición técnica con la ÚLTIMA ejecución real de la máquina.
func abrir_visor() -> void:
	if desafio.ultimo_intento.is_empty():
		avisar("La máquina aún no ha ejecutado nada en este intento.", SUAVE)
		return
	var intento: Dictionary = desafio.ultimo_intento
	juego.terminal_ui.abrir_visor(desafio.copia_para_visor(intento["filas"]), intento)


# ---------------------------------------------------------------------- #
# Virtuales de cada minijuego
# ---------------------------------------------------------------------- #
func _preparar() -> void:
	pass


func _comenzar() -> void:
	pass


func _actualizar(_dt: float) -> void:
	pass


func _dibujar_juego() -> void:
	pass


## Devuelve true si la tecla la usó el minijuego.
func _tecla(_e: InputEventKey) -> bool:
	return false


func _intro() -> Array:
	return ["", [], ""]          ## [texto (2-3 frases), controles, ensayo]


func _subtitulo() -> String:
	return ""


# ---------------------------------------------------------------------- #
# Consecuencias (física, lógica, técnica)
# ---------------------------------------------------------------------- #
func avisar(txt: String, col := TEXTO, dur := 3.2) -> void:
	aviso = txt
	aviso_col = col
	aviso_t = dur


func sonar(nombre: String, tono := 1.0) -> void:
	if juego and juego.audio:
		juego.audio.sonar(nombre, tono)


## Fallo físico grave: hace ruido en el museo (no es un rechazo de la MT).
func fallo_fisico(motivo: String) -> void:
	fallos_fisicos += 1
	juego.partida.fallo_fisico(terminal, motivo)
	juego.sacudir(3.0)
	sonar("bloqueado")


## Desliz leve (mal timing): en el ensayo no cuenta; varios seguidos hacen ruido.
func desliz(motivo: String) -> void:
	sonar("bloqueado", 1.2)
	if ensayo:
		avisar("ENSAYO · %s. Sin castigo: vuelve a intentarlo." % motivo, AMBAR)
		return
	sobrecarga += 1
	if sobrecarga >= SOBRECARGA_MAX:
		sobrecarga = 0
		fallo_fisico("deslices: " + motivo)
		avisar("FALLO FÍSICO · %s. Demasiados deslices: hiciste ruido." % motivo, NARANJA)
	else:
		avisar("Desliz físico · %s (%d/%d antes de hacer ruido)." % [motivo, sobrecarga, SOBRECARGA_MAX], AMBAR)


## La máquina RECHAZÓ: es un intento lógico fallido (pitido, cuenta intentos).
func fallo_logico(msg: String) -> void:
	fallos_logicos += 1
	juego.terminal_terminada(false)
	juego.sacudir(2.0)
	avisar("RECHAZO DE LA MÁQUINA · " + msg, ROJO, 4.5)


func error_tecnico() -> void:
	avisar("ERROR TÉCNICO: la máquina no se detuvo en %d pasos. No es culpa tuya; pulsa R para reintentar." %
			Desafio.MAX_PASOS, Color(0.8, 0.6, 1.0), 6.0)


## La máquina ACEPTÓ: se aplica el efecto en el museo.
func exito_formal() -> void:
	fase = "exito"
	juego.terminal_terminada(true)
	sonar("mt_acepta")


# ---------------------------------------------------------------------- #
func _process(dt: float) -> void:
	if not visible:
		return
	tiempo += dt
	botones["accesible"].text = "Modo accesible: " + ("SÍ (T)" if accesible else "NO (T)")
	botones["pausa"].text = "Seguir (P)" if pausado else "Pausa (P)"
	botones["visor"].disabled = desafio.ultimo_intento.is_empty()
	if not visor_abierto() and not pausado and fase in ["juego", "verificando", "exito"]:
		_actualizar(dt)
	if not visor_abierto() and not pausado:
		aviso_t = maxf(0.0, aviso_t - dt)
	queue_redraw()


func _input(e: InputEvent) -> void:
	if not visible or visor_abierto() or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	match k.keycode:
		KEY_ESCAPE:
			juego.cerrar_terminal()
		KEY_P:
			alternar_pausa()
		KEY_V:
			abrir_visor()
		KEY_T:
			alternar_accesible()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if fase == "intro":
				comenzar()
			elif not pausado:
				_tecla(k)
		_:
			if fase != "intro" and not pausado:
				_tecla(k)
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------- #
# Dibujo común
# ---------------------------------------------------------------------- #
func _draw() -> void:
	if desafio == null:
		return
	draw_rect(Rect2(0, 0, ANCHO, ALTO), Color(0, 0.01, 0.03, 0.78))
	draw_rect(PANEL.grow(6), Color(CIAN, 0.08))
	draw_rect(PANEL, FONDO)
	draw_rect(PANEL, Color(CIAN, 0.85), false, 2.0)
	for k in range(int(PANEL.position.y) + 4, int(PANEL.end.y), 4):
		draw_line(Vector2(PANEL.position.x + 2, k), Vector2(PANEL.end.x - 2, k), Color(1, 1, 1, 0.012))
	var x0 := PANEL.position.x + 20
	Dibujo.texto(self, desafio.titulo.to_upper(), Vector2(x0, PANEL.position.y + 12), 22, Color.WHITE, false, true, false)
	Dibujo.texto(self, _subtitulo(), Vector2(x0, PANEL.position.y + 42), 13, NARANJA, false, true, false)
	_dibujar_juego()
	_dibujar_hud_comun()
	if aviso_t > 0.0 and aviso != "":
		var a := clampf(aviso_t / 0.4, 0.0, 1.0)
		var r := Rect2(PANEL.position.x + 40, PANEL.end.y - 130, PANEL.size.x - 80, 44)
		draw_rect(r, Color(0.02, 0.04, 0.06, 0.94 * a))
		draw_rect(r, Color(aviso_col, a), false, 2.0)
		parrafo(aviso, r.position + Vector2(14, 8), r.size.x - 28, 14, Color(aviso_col.lightened(0.2), a), 2)
	if fase == "intro":
		_dibujar_intro()
	elif pausado:
		_velo("PAUSA", "P para continuar · V ver la máquina · Esc salir al museo", CIAN)


func _dibujar_hud_comun() -> void:
	# leyenda de gemas, siempre visible
	var x := PANEL.end.x - 20
	var y := PANEL.position.y + 14
	for i in range(G.size() - 1, -1, -1):
		var g: String = G[i]
		var txt: String = "%s=%s" % [g, NOMBRE[g]]
		var w := Dibujo.ancho_texto(txt, 12) + 26
		x -= w
		Dibujo.gema(self, g, Rect2(x, y - 2, 22, 22))
		Dibujo.texto(self, txt, Vector2(x + 22, y + 2), 12, SUAVE, false, false, false)
	# rueda del museo
	var rueda := "Rueda: R → Z → E → A → R"
	Dibujo.texto(self, rueda, Vector2(PANEL.end.x - 20 - Dibujo.ancho_texto(rueda, 12, true), y + 26), 12, CIAN,
			false, true, false)
	# deslices y fallos
	var hy := PANEL.end.y - 46 - 26
	var info := "Intentos lógicos fallidos: %d   ·   Fallos físicos: %d" % [fallos_logicos, fallos_fisicos]
	Dibujo.texto(self, info, Vector2(PANEL.position.x + 20, hy), 12, SUAVE, false, false, false)
	var sx := PANEL.end.x - 20 - SOBRECARGA_MAX * 18
	Dibujo.texto(self, "Deslices", Vector2(sx - 62, hy), 12, SUAVE, false, false, false)
	for i in SOBRECARGA_MAX:
		var c := Rect2(sx + i * 18, hy + 1, 12, 12)
		draw_rect(c, AMBAR if i < sobrecarga else Color(1, 1, 1, 0.1))
		draw_rect(c, Color(AMBAR, 0.6), false, 1.0)


func _dibujar_intro() -> void:
	var datos := _intro()
	var r := Rect2(PANEL.position.x + 90, PANEL.position.y + 120, PANEL.size.x - 180, 400)
	draw_rect(Rect2(PANEL.position.x, PANEL.position.y + 70, PANEL.size.x, PANEL.size.y - 130), Color(0, 0.01, 0.03, 0.82))
	draw_rect(r, Color(0.03, 0.07, 0.11, 0.98))
	draw_rect(r, CIAN, false, 2.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), NARANJA)
	Dibujo.texto(self, "MISIÓN", r.position + Vector2(24, 20), 14, NARANJA, false, true, false)
	parrafo(datos[0], r.position + Vector2(24, 48), r.size.x - 48, 17, Color.WHITE, 5)
	var y := r.position.y + 160
	Dibujo.texto(self, "CONTROLES", Vector2(r.position.x + 24, y), 13, CIAN, false, true, false)
	y += 24
	for c in datos[1]:
		Dibujo.texto(self, "•  " + str(c), Vector2(r.position.x + 30, y), 14, TEXTO, false, false, false)
		y += 22
	y += 8
	parrafo("ENSAYO  " + str(datos[2]), Vector2(r.position.x + 24, y), r.size.x - 48, 13, AMBAR, 2)
	var p := 0.6 + 0.4 * sin(tiempo * 4.0)
	Dibujo.texto(self, "ENTER o ESPACIO para empezar", Vector2(r.get_center().x, r.end.y - 26), 18,
			Color(VERDE, p), true, true, false)


func _velo(titulo: String, sub: String, col: Color) -> void:
	var r := Rect2(PANEL.position.x + 160, PANEL.position.y + 250, PANEL.size.x - 320, 110)
	draw_rect(r, Color(0.02, 0.04, 0.06, 0.96))
	draw_rect(r, col, false, 2.0)
	Dibujo.texto(self, titulo, Vector2(r.get_center().x, r.position.y + 36), 28, col, true, true, false)
	Dibujo.texto(self, sub, Vector2(r.get_center().x, r.position.y + 78), 14, TEXTO, true, false, false)


## Barra de tiempo (si `total` <= 0 o modo accesible, muestra «sin reloj»).
func barra_tiempo(pos: Vector2, ancho: float, restante: float, total: float, etiqueta := "RELOJ") -> void:
	Dibujo.texto(self, etiqueta, pos, 12, SUAVE, false, true, false)
	var r := Rect2(pos + Vector2(64, 2), Vector2(ancho - 64, 12))
	draw_rect(r, Color(1, 1, 1, 0.06))
	if accesible or total <= 0.0:
		Dibujo.texto(self, "sin reloj (modo accesible)" if accesible else "sin reloj durante el ensayo",
				r.position + Vector2(6, -1), 11, CIAN, false, false, false)
		return
	var f := clampf(restante / total, 0.0, 1.0)
	var col := VERDE if f > 0.5 else (AMBAR if f > 0.2 else ROJO)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
	draw_rect(r, Color(col, 0.6), false, 1.0)
	Dibujo.texto(self, "%d s" % ceili(restante), r.end + Vector2(6, -13), 11, col, false, true, false)


## Tira de cinta compacta para ver a la MT trabajar mientras se juega.
func tira_cinta(origen: Vector2, celdas: Array, cabezal: int, celda := 26.0, titulo := "", col_cab := AMBAR) -> void:
	if titulo != "":
		Dibujo.texto(self, titulo, origen + Vector2(0, -18), 11, SUAVE, false, true, false)
	for i in celdas.size():
		var r := Rect2(origen + Vector2(i * celda, 0), Vector2(celda - 2, celda - 2))
		draw_rect(r, Color(0.06, 0.1, 0.15))
		draw_rect(r, Color(CIAN, 0.2), false, 1.0)
		var s := str(celdas[i])
		if not Dibujo.gema(self, s, r):
			Dibujo.texto(self, s if s != "_" else "␣", r.get_center(), 14, TEXTO if s != "_" else SUAVE, true, true, false)
	if cabezal >= -1 and cabezal <= celdas.size():
		var hx := origen.x + cabezal * celda
		draw_rect(Rect2(hx - 1, origen.y - 2, celda, celda + 2), col_cab, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(hx + celda / 2 - 1, origen.y - 3),
				Vector2(hx + celda / 2 - 6, origen.y - 9), Vector2(hx + celda / 2 + 4, origen.y - 9)]), col_cab)


func parrafo(txt: String, pos: Vector2, ancho: float, tam: int, col: Color, max_lineas := 3) -> void:
	var palabras := txt.split(" ")
	var linea := ""
	var y := pos.y
	var lineas := 0
	for p in palabras:
		var prueba := (linea + " " + p).strip_edges()
		if Dibujo.ancho_texto(prueba, tam) > ancho and linea != "":
			Dibujo.texto(self, linea, Vector2(pos.x, y), tam, col, false, false, false)
			y += tam + 5
			lineas += 1
			linea = p
			if lineas >= max_lineas:
				return
		else:
			linea = prueba
	if linea != "":
		Dibujo.texto(self, linea, Vector2(pos.x, y), tam, col, false, false, false)


func pastilla(txt: String, pos: Vector2, col: Color, tam := 12) -> float:
	var w := Dibujo.ancho_texto(txt, tam, true) + 18
	draw_rect(Rect2(pos, Vector2(w, tam + 10)), Color(col, 0.14))
	draw_rect(Rect2(pos, Vector2(w, tam + 10)), col, false, 1.5)
	Dibujo.texto(self, txt, pos + Vector2(9, 4), tam, col, false, true, false)
	return w


func gema_grande(g: String, c: Vector2, tam: float) -> void:
	Dibujo.gema(self, g, Rect2(c - Vector2(tam, tam) / 2, Vector2(tam, tam)))


## Paso de una gema a otra en la rueda (0..3).
static func pasos_rueda(desde: String, hasta: String) -> int:
	return (G.find(hasta) - G.find(desde) + 4) % 4
