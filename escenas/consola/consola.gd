## Consola de seguridad del museo (tecla F1).
##
## Es una ventana NATIVA independiente (Window con embed_subwindows = false en
## project.godot): se puede mover, redimensionar y cerrar con su botón o con
## F1 / Esc. Hay una sola instancia, creada una vez por la escena principal.
## NO pausa el juego: corre en paralelo y muestra en vivo los cambios de
## estado de los autómatas, las máquinas de Turing y el registro. Al abrirla
## el foco se queda en el juego, así que se puede seguir jugando.
##
## Pestañas: Guardias (AFD) · Máquinas de Turing · Radar · Registro ·
##           Tutoriales · Ajustes · Lenguaje SOMBRA (código del nivel y su compilación)
class_name ConsolaSeguridad
extends Window

const T := preload("res://escenas/consola/tema.gd")
const PESTANAS := ["Guardias · AFD", "Máquinas de Turing", "Radar", "Registro", "Tutoriales", "Ajustes",
		"Lenguaje SOMBRA"]
const FILTROS := {
	"Todo": [], "Detecciones": ["deteccion", "alerta"], "Ruidos": ["moneda", "ruido"], "Estados": ["estado"],
	"Alarmas": ["alarma", "alerta"], "Turing": ["turing"], "Radar": ["radar"], "Escondites": ["oculto"],
}

var juego
var pestanas: TabContainer
var vista_afd: VistaAFD
var vista_radar: VistaRadar
var vista_lenguaje: VistaLenguaje
var vistas_mt := {}               ## variante -> VistaMT
var textos_mt := {}               ## variante -> RichTextLabel (últimas operaciones)
var registro_txt: RichTextLabel
var filtro := "Todo"
var tutorial: PanelTutorial
var botones_tut := {}
var aperturas := 0
var _firma_registro := ""
var _t_refresco := 0.0


class Atajos:
	extends Node
	var consola

	func _input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_F1, KEY_ESCAPE]:
			consola.cerrar()
			get_viewport().set_input_as_handled()


func _init() -> void:
	title = "SOMBRA · Consola de seguridad del museo"
	size = Vector2i(1080, 720)
	min_size = Vector2i(780, 560)
	visible = false
	wrap_controls = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = T.crear()
	close_requested.connect(cerrar)


func _ready() -> void:
	var fondo := Panel.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var raiz := VBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.offset_left = 8
	raiz.offset_top = 6
	raiz.offset_right = -8
	raiz.offset_bottom = -8
	add_child(raiz)
	var cab := HBoxContainer.new()
	raiz.add_child(cab)
	var t := Label.new()
	t.text = "◉ CONSOLA DE SEGURIDAD · MUSEO NACIONAL"
	t.add_theme_color_override("font_color", T.CIAN)
	t.add_theme_font_size_override("font_size", 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var ayuda := Label.new()
	ayuda.text = "F1 / Esc: cerrar"
	ayuda.add_theme_color_override("font_color", T.SUAVE)
	cab.add_child(ayuda)

	pestanas = TabContainer.new()
	pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(pestanas)

	vista_afd = VistaAFD.new()
	_pestana(vista_afd, 0)
	_pestana(_crear_turing(), 1)
	vista_radar = VistaRadar.new()
	_pestana(vista_radar, 2)
	_pestana(_crear_registro(), 3)
	_pestana(_crear_tutoriales(), 4)
	_pestana(_crear_ajustes(), 5)
	vista_lenguaje = VistaLenguaje.new()
	vista_lenguaje.juego = juego
	_pestana(vista_lenguaje, 6)

	var at := Atajos.new()
	at.consola = self
	add_child(at)


func _pestana(nodo: Control, i: int) -> void:
	nodo.name = PESTANAS[i]
	nodo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pestanas.add_child(nodo)


# ------------------------------------------------------------------ abrir
func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


## Abre la consola SIN pausar el juego: todo se sigue actualizando en vivo.
## El foco vuelve a la ventana del juego para que se pueda seguir jugando
## mientras se observan los autómatas (`enfocar` lo deja en la consola).
func abrir(pestana := -1, enfocar := false) -> void:
	if pestana >= 0:
		pestanas.current_tab = pestana
	if not visible:
		aperturas += 1
		# al lado de la ventana del juego si cabe en la pantalla; si no, encima
		var raiz := get_tree().root
		var pantalla := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var al_lado := raiz.position + Vector2i(raiz.size.x + 8, 0)
		if pantalla.size.x > 0 and al_lado.x + size.x <= pantalla.end.x:
			position = al_lado
		else:
			position = raiz.position + Vector2i(maxi(0, raiz.size.x - size.x) / 2 + 40, 60)
		show()
	_enlazar()
	if enfocar:
		grab_focus()
	else:
		get_tree().root.grab_focus.call_deferred()


func cerrar() -> void:
	hide()
	get_tree().root.grab_focus()


## El ladrón no se mueve mientras se escribe/hace clic en la consola (si el
## foco está en el juego, se juega normalmente con la consola abierta).
func bloquea_jugador() -> bool:
	return visible and has_focus()


func _enlazar() -> void:
	var p: Partida = juego.partida if juego else null
	vista_afd.partida = p
	vista_radar.partida = p


func _process(dt: float) -> void:
	if not visible:
		return
	_enlazar()
	_t_refresco -= dt
	if _t_refresco > 0.0:
		return
	_t_refresco = 0.2
	_refrescar_turing()
	_refrescar_registro()


# ------------------------------------------------------- máquinas de Turing
func _crear_turing() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for variante in ["estandar", "multicinta", "multipista", "bateria"]:
		var h := HBoxContainer.new()
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if variante == "bateria":
			h.size_flags_stretch_ratio = 0.6
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var vista := VistaMT.new()
		vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vista.size_flags_stretch_ratio = 2.2
		h.add_child(vista)
		vistas_mt[variante] = vista
		var txt := RichTextLabel.new()
		txt.bbcode_enabled = true
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_font_size_override("normal_font_size", 12)
		txt.add_theme_font_size_override("bold_font_size", 12)
		h.add_child(txt)
		textos_mt[variante] = txt
	return v


const NOMBRE_VARIANTE := {"estandar": "ESTÁNDAR", "multicinta": "MULTICINTA", "multipista": "MULTIPISTA",
		"bateria": "ESTÁNDAR · BATERÍA"}
const USO := {
	"estandar": "Claves de acceso: acertijo de gemas de la vitrina y central de alarmas.",
	"bateria": "Energía para correr en unario: g gasta una celda, c recarga una. Rechaza si está agotada.",
	"multicinta": "Varios sensores a la vez: bóveda y correlador del radar.",
	"multipista": "Capas de vigilancia en una cinta: rejilla láser y analizador del radar.",
}


func _refrescar_turing() -> void:
	var p: Partida = juego.partida if juego else null
	for variante in vistas_mt:
		var vista: VistaMT = vistas_mt[variante]
		var entrada: Dictionary = p.maquinas.get(variante, {}) if p else {}
		var m: MaquinaTuring = Partida.maquina_de(entrada)
		vista.maquina = m
		vista.titulo = "%s · %s" % [NOMBRE_VARIANTE[variante], entrada.get("origen", "sin uso todavía")]
		vista.nombres = entrada.get("nombres", [])
		var t := "[color=#4ddbff][b]%s[/b][/color]\n[color=#8599a8]%s[/color]\n" % [NOMBRE_VARIANTE[variante], USO[variante]]
		if m == null:
			t += "\nAún no se ha ejecutado en esta partida."
		else:
			if m.explicacion_estados.has(m.estado):
				t += "\n[color=#ffc759]%s[/color]: %s\n" % [m.estado, m.explicacion_estados[m.estado]]
			t += "\n[b]Últimas operaciones[/b]\n"
			var ult: Array = m.historial.slice(-(3 if variante == "bateria" else 6))
			ult.reverse()
			for u in ult:
				t += "• " + VistaMT.formato_transicion(u) + "\n"
		textos_mt[variante].text = t


# ----------------------------------------------------------------- registro
func _crear_registro() -> Control:
	var v := VBoxContainer.new()
	var filtros := HBoxContainer.new()
	filtros.add_theme_constant_override("separation", 6)
	v.add_child(filtros)
	for f in FILTROS:
		var b := Button.new()
		b.text = f
		b.toggle_mode = true
		b.button_pressed = f == filtro
		b.pressed.connect(func():
			filtro = f
			for o in filtros.get_children():
				o.button_pressed = o.text == f
			_firma_registro = ""
			_refrescar_registro())
		filtros.add_child(b)
	registro_txt = RichTextLabel.new()
	registro_txt.bbcode_enabled = true
	registro_txt.scroll_following = true
	registro_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	registro_txt.add_theme_font_size_override("normal_font_size", 13)
	v.add_child(registro_txt)
	return v


func _refrescar_registro() -> void:
	if juego == null or registro_txt == null:
		return
	var reg: Array = juego.partida.seguridad.registro
	var firma := "%s|%d|%s" % [filtro, reg.size(), str(reg[-1]["t"]) if not reg.is_empty() else ""]
	if firma == _firma_registro:
		return
	_firma_registro = firma
	var tipos: Array = FILTROS[filtro]
	var lineas := PackedStringArray()
	for e in reg:
		if not tipos.is_empty() and not e["tipo"] in tipos:
			continue
		var col: Color = T.COLOR_EVENTO.get(e["tipo"], T.TEXTO)
		var seg := int(e["t"])
		lineas.append("[color=#5f7685]%02d:%02d.%d[/color]  [color=#%s][b]%-9s[/b][/color] %s" % [seg / 60, seg % 60,
				int(fmod(e["t"], 1.0) * 10), col.to_html(false), e["tipo"].to_upper(), e["texto"]])
	if lineas.is_empty():
		lineas.append("[color=#5f7685]Sin eventos de este tipo todavía.[/color]")
	registro_txt.text = "\n".join(lineas)


# --------------------------------------------------------------- tutoriales
func _crear_tutoriales() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	for id in ["estandar", "multicinta", "multipista"]:
		var b := Button.new()
		b.pressed.connect(func(): abrir_tutorial(id))
		h.add_child(b)
		botones_tut[id] = b
	tutorial = PanelTutorial.new()
	tutorial.id = "estandar"
	tutorial.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial.terminado.connect(func(_id): _marcar_botones())
	v.add_child(tutorial)
	_marcar_botones()
	return v


func _marcar_botones() -> void:
	for id in botones_tut:
		botones_tut[id].text = ("✓ " if Ajustes.tutorial_visto(id) else "• ") + PanelTutorial.TUTORIALES[id]["titulo"]


func abrir_tutorial(id: String) -> void:
	abrir(4, true)
	tutorial.abrir(id)
	_marcar_botones()


# ------------------------------------------------------------------ ajustes
func _crear_ajustes() -> Control:
	var scroll := ScrollContainer.new()
	var g := GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 12)
	scroll.add_child(g)
	_deslizador(g, "Intervalo entre escaneos del radar", "radar_intervalo", 8, 45, 1, " s")
	_deslizador(g, "Aviso previo al escaneo", "radar_aviso", 1, 5, 0.5, " s")
	_deslizador(g, "Duración del barrido", "radar_barrido", 1.5, 6, 0.5, " s")
	_deslizador(g, "Alcance del radar", "radar_alcance", 5, 14, 1, " casillas")
	_deslizador(g, "Dificultad de la vigilancia", "dificultad", 0.6, 1.5, 0.1, "×")
	_deslizador(g, "Volumen de la música", "musica_volumen", 0, 1, 0.05, "")
	_deslizador(g, "Intensidad de la música adaptativa", "musica_intensidad", 0, 1.5, 0.1, "×")
	_deslizador(g, "Volumen de los efectos", "efectos_volumen", 0, 1, 0.05, "")
	var l2 := Label.new()
	l2.text = "Tutoriales"
	g.add_child(l2)
	var b := Button.new()
	b.text = "Volver a mostrarlos durante el juego"
	b.pressed.connect(func():
		Ajustes.tutoriales_vistos = {}
		Ajustes.guardar()
		_marcar_botones())
	g.add_child(b)
	g.add_child(Control.new())
	return scroll


func _deslizador(g: GridContainer, texto: String, clave: String, mn: float, mx: float, paso: float, unidad: String) -> void:
	var l := Label.new()
	l.text = texto
	g.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = paso
	s.value = Ajustes.valor(clave)
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(110, 0)
	v.add_theme_color_override("font_color", T.AMBAR)
	var mostrar := func(x: float): v.text = ("%.0f" % x if paso >= 1 else "%.2f" % x).trim_suffix(".00") + unidad
	mostrar.call(s.value)
	s.value_changed.connect(func(x):
		Ajustes.set_valor(clave, x)
		Ajustes.guardar()
		mostrar.call(x))
	g.add_child(v)
