## Marco de las terminales de SOMBRA. El visor reproduce el último intento real.
class_name Minijuego
extends Control

const PANEL := Rect2(28, 22, 904, 660)
const ESCENA := Rect2(52, 144, 856, 379)
const TEXTO := Config.TEXTO
const SUAVE := Config.TEXTO_SUAVE
const AMBAR := Config.ACENTO
const VERDE := Config.SALIDA_ABIERTA
const ROJO := Config.CONO_PERSECUCION
const G := ["R", "Z", "E", "A"]

static var accesible := false

var juego
var terminal: Dictionary
var desafio: Desafio
var fase := "intro"
var pausado := false
var tiempo := 0.0
var aviso := ""
var aviso_col := TEXTO
var aviso_t := 0.0
var ensayo := true
var botones := {}


func _ready() -> void:
	hide()
	size = Vector2(960, 704)
	mouse_filter = MOUSE_FILTER_STOP
	_boton("inicio", "Empezar  [Enter]", 52, 172, comenzar)
	_boton("visor", "Ver máquina  [V]", 52, 172, abrir_visor)
	_boton("pausa", "Pausa  [P]", 236, 110, alternar_pausa)
	_boton("accesible", "", 358, 172, alternar_accesible)
	_boton("salir", "Salir  [Esc]", 788, 120, salir)


func _boton(id: String, texto: String, x: float, ancho: float, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.position = Vector2(x, 628)
	b.size = Vector2(ancho, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Config.HUD_FONDO.lightened(0.05 if estado == "normal" else 0.13)
		st.border_color = Color(AMBAR, 0.66 if estado != "disabled" else 0.2)
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		b.add_theme_stylebox_override(estado, st)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(accion)
	add_child(b)
	botones[id] = b


func abrir(t: Dictionary) -> void:
	terminal = t
	desafio = t["desafio"]
	fase = "exito" if desafio.resuelto else "intro"
	pausado = false
	tiempo = 0.0
	aviso_t = 0.0
	ensayo = true
	_preparar()
	show()
	_actualizar_botones()
	var nombres := []
	for f in desafio.filas:
		nombres.append(f["nombre"])
	juego.partida.registrar_maquina(desafio.variante, {"origen": "Terminal · " + desafio.titulo,
			"desafio": desafio, "nombres": nombres})


func cerrar() -> void:
	hide()


func salir() -> void:
	juego.cerrar_terminal()


func comenzar() -> void:
	if fase == "intro":
		fase = "juego"
		_actualizar_botones()


func alternar_pausa() -> void:
	if fase in ["juego", "verificando"]:
		pausado = not pausado
		_actualizar_botones()


func alternar_accesible() -> void:
	accesible = not accesible
	_actualizar_botones()


func visor_abierto() -> bool:
	return juego != null and juego.terminal_ui.visible


func abrir_visor() -> void:
	if desafio.ultimo_intento.is_empty():
		return
	var intento := desafio.ultimo_intento
	juego.terminal_ui.abrir_visor(desafio.copia_para_visor(intento["filas"]), intento)


func _actualizar_botones() -> void:
	botones["inicio"].visible = fase == "intro"
	botones["visor"].visible = fase != "intro"
	botones["pausa"].visible = fase in ["juego", "verificando"]
	botones["visor"].disabled = desafio.ultimo_intento.is_empty()
	botones["accesible"].text = "Modo tranquilo  [T]" if not accesible else "Tranquilo: sí  [T]"
	botones["pausa"].text = "Seguir  [P]" if pausado else "Pausa  [P]"
	botones["salir"].text = "Volver  [Esc]" if fase == "exito" else "Salir  [Esc]"


func avisar(txt: String, color := TEXTO) -> void:
	aviso = txt
	aviso_col = color
	aviso_t = 2.8


func sonar(nombre: String, tono := 1.0) -> void:
	juego.audio.sonar(nombre, tono)


func detectado(mensaje: String, por_maquina := true) -> void:
	if ensayo:
		avisar(mensaje, AMBAR)
		sonar("bloqueado")
		return
	if por_maquina:
		juego.terminal_terminada(false)
	else:
		juego.partida.fallo_fisico(terminal, mensaje)
		sonar("bloqueado")
	avisar(mensaje, ROJO)


func confirmar(contenidos: Array) -> void:
	var intento := desafio.ejecutar_intento(contenidos)
	match intento["resultado"]:
		"ACEPTA":
			completar()
		_:
			avisar("No se pudo completar la comprobación. Reabre la terminal.", AMBAR)


func completar() -> void:
	fase = "exito"
	juego.terminal_terminada(true)
	sonar("mt_acepta")


func _process(dt: float) -> void:
	if not visible:
		return
	if not visor_abierto() and not pausado:
		tiempo += dt
		aviso_t = maxf(0.0, aviso_t - dt)
		if fase in ["juego", "verificando"]:
			_actualizar(minf(dt, 0.05))
	_actualizar_botones()
	queue_redraw()


func _input(e: InputEvent) -> void:
	if not visible or visor_abierto() or not (e is InputEventKey) or not e.pressed:
		return
	var k := e as InputEventKey
	var usada := true
	if not k.echo:
		match k.keycode:
			KEY_ESCAPE: salir()
			KEY_P: alternar_pausa()
			KEY_T: alternar_accesible()
			KEY_V: abrir_visor()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if fase == "intro":
					comenzar()
				elif fase == "exito":
					salir()
				else:
					usada = not pausado and fase == "juego" and _tecla(k)
			_:
				usada = not pausado and fase == "juego" and _tecla(k)
	else:
		usada = not pausado and fase == "juego" and _repetir(k)
	if usada:
		get_viewport().set_input_as_handled()


func _gui_input(e: InputEvent) -> void:
	if visor_abierto() or pausado or fase != "juego":
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_clic(e.position)
		accept_event()


func _draw() -> void:
	if desafio == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02, 0.68))
	draw_rect(PANEL, Config.HUD_FONDO)
	draw_rect(PANEL, Color(AMBAR, 0.55), false)
	draw_rect(ESCENA, Color(0.039, 0.045, 0.068))
	if fase == "exito":
		_dibujar_exito()
		return
	Dibujo.texto(self, desafio.titulo, Vector2(52, 39), 30, TEXTO, false, true)
	Dibujo.texto(self, desafio.objetivo, Vector2(53, 86), 19, TEXTO)
	_derecha(_progreso(), Vector2(904, 112))
	_dibujar_juego()
	var ayuda := "Primera acción de práctica" if fase == "intro" else _ayuda()
	if pausado:
		ayuda = "En pausa · P para seguir"
	elif aviso_t > 0.0:
		ayuda = aviso
	Dibujo.texto(self, ayuda, Vector2(480, 560), 18, aviso_col if aviso_t > 0.0 and not pausado else TEXTO, true)
	if pausado:
		draw_rect(ESCENA, Color(0.02, 0.025, 0.04, 0.68))
		Dibujo.texto(self, "En pausa", ESCENA.get_center(), 32, TEXTO, true, true)


func _dibujar_exito() -> void:
	Dibujo.texto(self, desafio.titulo, Vector2(52, 39), 30, TEXTO, false, true)
	Arte.casilla(self, Arte.SALIDA_ABIERTA if desafio.efecto == "puerta" else Arte.TERMINAL_RESUELTA,
			Rect2(416, 174, 128, 128))
	Dibujo.texto(self, _mensaje_exito(), Vector2(480, 344), 30, VERDE, true, true)
	Dibujo.texto(self, desafio.leccion, Vector2(480, 405), 17, TEXTO, true)
	Dibujo.texto(self, "Pulsa V para ver cómo lo comprobó la máquina.", Vector2(480, 459), 16, SUAVE, true)
	Dibujo.texto(self, "Enter para volver al museo", Vector2(480, 560), 18, TEXTO, true)


func _derecha(s: String, p: Vector2) -> void:
	Dibujo.texto(self, s, p - Vector2(Dibujo.ancho_texto(s, 14, true), 0), 14, AMBAR, false, true, false)


func suelo(r: Rect2i) -> void:
	for y in r.size.y:
		for x in r.size.x:
			Arte.casilla(self, Arte.PISO_CLARO if (x + y) % 2 == 0 else Arte.PISO_OSCURO,
					Rect2(Vector2(r.position + Vector2i(x, y) * 64), Vector2(64, 64)),
					Color(0.68, 0.68, 0.8))


func ficha(gema: String, centro: Vector2, tam: float = 45.0) -> void:
	Dibujo.ficha_juego(self, gema, centro, tam)


func casilla(r: Rect2, resaltada: bool = false) -> void:
	draw_rect(r, Config.HUD_FONDO.lightened(0.07))
	draw_rect(r, AMBAR if resaltada else Color(1, 1, 1, 0.18), false, 2)


func _preparar() -> void: pass
func _actualizar(_dt: float) -> void: pass
func _dibujar_juego() -> void: pass
func _tecla(_e: InputEventKey) -> bool: return false
func _repetir(_e: InputEventKey) -> bool: return false
func _clic(_p: Vector2) -> void: pass
func _progreso() -> String: return ""
func _ayuda() -> String: return ""
func _mensaje_exito() -> String: return "Terminal resuelta"
