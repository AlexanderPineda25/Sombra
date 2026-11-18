## Tutoriales interactivos de las tres máquinas de Turing.
##
## Cada tutorial es una lista corta de páginas:
##   "sim"        una máquina real que el jugador ejecuta paso a paso
##   "ejercicio"  una pregunta con opciones y retroalimentación inmediata
##   "tabla"      comparación multicinta vs multipista
## El mismo panel se usa dentro del juego (la primera vez que aparece cada
## máquina) y en la pestaña "Tutoriales" de la consola F1.
class_name PanelTutorial
extends PanelContainer

signal terminado(id: String)

const T := preload("res://escenas/consola/tema.gd")

const TUTORIALES := {
	"estandar": {
		"titulo": "Máquina de Turing estándar",
		"paginas": [
			{"tipo": "sim", "titulo": "El robot de la vitrina",
			"texto": "En Fácil, lleva cada gema al hueco con el mismo número. Pulsa [b]Paso[/b] y sigue al cabezal: la máquina recuerda una gema, cruza hasta la cerradura y comprueba la pareja.",
			"maquina": "clave_vitrina", "entrada": "RE#RE", "entradas": ["RE#RE", "RE#ER"],
			"etiquetas": ["Parejas correctas", "Gemas cambiadas"]},
			{"tipo": "sim", "titulo": "Cinta y cabezal",
			"texto": "Una cinta infinita y un cabezal. En cada paso: [b]lee[/b] un símbolo, [b]escribe[/b] otro, se [b]mueve[/b] (L, R o S) y cambia de [b]estado[/b].",
			"maquina": "incrementador", "entrada": "1011", "formula": "δ(q, a) = (q', b, M)"},
			{"tipo": "ejercicio", "titulo": "¿Qué escribe?",
			"texto": "Está en q2 (llevando el acarreo) y lee 1.  δ(q2, 1) = (q2, 0, L).",
			"maquina": "incrementador", "entrada": "1011", "previos": 5,
			"pregunta": "¿Qué símbolo queda en la casilla?", "opciones": ["0", "1", "␣ (blanco)"], "correcta": 0,
			"explica": "δ ordena escribir 0: 1 + acarreo = 10, el acarreo sigue a la izquierda."},
			{"tipo": "sim", "titulo": "Aceptar o rechazar",
			"texto": "La máquina se detiene en [color=#59ff94]qa[/color] (acepta) o [color=#ff5c52]qr[/color] (rechaza). Si δ no está definida, rechaza. Prueba otra entrada:",
			"maquina": "anbn", "entrada": "aabb", "entradas": ["aabb", "aab", "abab"]},
			{"tipo": "ejercicio", "titulo": "Reconocer un lenguaje",
			"texto": "La máquina reconoce L = { aⁿbⁿ | n ≥ 1 }.",
			"maquina": "anbn", "entrada": "abb",
			"pregunta": "¿Acepta la palabra «abb»?", "opciones": ["Sí", "No"], "correcta": 1,
			"explica": "Sobra una b: al final queda una b sin pareja y la máquina rechaza. En el museo, la central de alarmas usa esta máquina."},
			{"tipo": "ejercicio", "titulo": "Recuerda la pareja",
			"texto": "En Fácil, la vitrina tiene una esmeralda en el 1 y un ámbar en el 2.",
			"pregunta": "¿Qué colocas en el hueco 1?", "opciones": ["Esmeralda", "Ámbar", "Rubí"], "correcta": 0,
			"explica": "La pieza del número 1 va al hueco con ese mismo número."},
		],
	},
	"multicinta": {
		"titulo": "Máquina multicinta",
		"paginas": [
			{"tipo": "sim", "titulo": "El reparto del botín",
			"texto": "Pulsa [b]Paso[/b]. Cuando llega una joya a la bolsa izquierda, el cabezal de la derecha se queda quieto. Prueba también qué ocurre si mandas el rubí a la bolsa equivocada.",
			"maquina": "reparto", "entrada": ["R<Z>Fv", "R", "Z"], "nombres": ["Cinta del botín", "Bolsa izquierda", "Bolsa derecha"],
			"entradas": [["R<Z>Fv", "R", "Z"], ["R>Z>Fv", "", "RZ"]],
			"etiquetas": ["Reparto correcto", "Rubí en la bolsa equivocada"]},
			{"tipo": "sim", "titulo": "Varias cintas, varios cabezales",
			"texto": "k cintas, cada una con [b]su propio cabezal[/b]. δ lee k símbolos a la vez y da k escrituras y [b]k movimientos independientes[/b].",
			"maquina": "suma_multicinta", "entrada": ["101", "011", "1000"], "nombres": ["A", "B", "Resultado"],
			"formula": "δ(q, a₁,…,aₖ) = (q', b₁,…,bₖ, M₁,…,Mₖ)"},
			{"tipo": "ejercicio", "titulo": "Movimientos",
			"texto": "Observa los cabezales: cada uno avanza por su cuenta.",
			"maquina": "suma_multicinta", "entrada": ["101", "011", "1000"], "nombres": ["A", "B", "Resultado"], "previos": 4,
			"pregunta": "Con 3 cintas, ¿cuántos movimientos indica cada transición?", "opciones": ["1", "3", "6"],
			"correcta": 1, "explica": "Uno por cabezal: (M₁, M₂, M₃)."},
			{"tipo": "sim", "titulo": "En el museo: el radar",
			"texto": "El radar cruza dos sensores sector a sector. Intruso = hay presencia [b]y[/b] no lleva transpondedor.",
			"maquina": "correlador_sensores", "entrada": ["0110", "0100", ""],
			"nombres": ["P presencia", "A transp.", "I intruso"]},
			{"tipo": "ejercicio", "titulo": "Correlación",
			"texto": "Un sector con P = 1 y A = 0.",
			"maquina": "correlador_sensores", "entrada": ["10", "00", ""], "nombres": ["P presencia", "A transp.", "I intruso"],
			"pregunta": "¿Qué escribe en la cinta de intrusos?", "opciones": ["1", "0", "␣"], "correcta": 0,
			"explica": "Presencia sin transpondedor: es un intruso (1)."},
		],
	},
	"multipista": {
		"titulo": "Máquina multipista",
		"paginas": [
			{"tipo": "sim", "titulo": "Una cinta, varias pistas",
			"texto": "En el pasillo, un solo cabezal comprueba tres datos a la vez. Si el haz está encendido, la máscara debe coincidir. Pulsa [b]Paso[/b] para ver qué decide con cada haz.",
			"maquina": "cruce", "entrada": ["RZE", "AZE", "011"], "nombres": ["Haz", "Máscara", "Encendido"],
			"entradas": [["RZE", "AZE", "011"], ["RZE", "AZE", "111"]],
			"etiquetas": ["Primer haz apagado", "Primer haz encendido"],
			"formula": "δ(q, (a₁,…,aₖ)) = (q', (b₁,…,bₖ), M)"},
			{"tipo": "ejercicio", "titulo": "Cabezales",
			"texto": "El analizador del radar usa 4 pistas.",
			"maquina": "analizador_radar", "entrada": ["0010", "1110", "0000", ""],
			"nombres": ["I intruso", "V eco", "O oculto", "Resultado"],
			"pregunta": "¿Cuántos cabezales tiene una máquina de 4 pistas?", "opciones": ["1", "4", "2"], "correcta": 0,
			"explica": "Uno: las pistas comparten el cabezal y siempre se leen juntas."},
			{"tipo": "sim", "titulo": "En el museo: análisis del radar",
			"texto": "Busca una columna con intruso, con eco y no oculto (1, 1, 0). Si la encuentra, [color=#59ff94]acepta[/color]: ¡alerta!",
			"maquina": "analizador_radar", "entrada": ["0010", "1110", "0010", ""],
			"nombres": ["I intruso", "V eco", "O oculto", "Resultado"],
			"entradas": [["0010", "1110", "0010", ""], ["0010", "1110", "0000", ""]],
			"etiquetas": ["Oculto en arbusto", "Al descubierto"]},
			{"tipo": "tabla", "titulo": "Multicinta vs multipista"},
			{"tipo": "ejercicio", "titulo": "¿Cuál conviene?",
			"texto": "Hay que recorrer dos secuencias a ritmos distintos (una avanza y la otra espera).",
			"pregunta": "¿Qué máquina lo hace más cómodo?", "opciones": ["Multicinta", "Multipista"], "correcta": 0,
			"explica": "Con cabezales independientes cada secuencia avanza a su ritmo. La multipista obliga a mover todo junto."},
		],
	},
}

var id := ""
var pagina := 0
var maquina: MaquinaTuring
var corriendo := false
var t_paso := 0.0
var respondida := -1
var aciertos := 0

var _titulo: Label
var _indice: Label
var _texto: RichTextLabel
var _vista: VistaMT
var _controles: HBoxContainer
var _pregunta: Label
var _opciones: HBoxContainer
var _retro: RichTextLabel
var _tabla: Control
var _anterior: Button
var _siguiente: Button
var _ejecutar: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", T.caja(T.FONDO, T.CIAN, 2, 6, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var cab := HBoxContainer.new()
	v.add_child(cab)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 20)
	_titulo.add_theme_color_override("font_color", T.CIAN)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(_titulo)
	_indice = Label.new()
	_indice.add_theme_color_override("font_color", T.SUAVE)
	cab.add_child(_indice)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.add_theme_font_size_override("normal_font_size", 15)
	_texto.add_theme_font_size_override("bold_font_size", 15)
	_texto.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	v.add_child(_texto)
	_vista = VistaMT.new()
	_vista.custom_minimum_size = Vector2(0, 170)
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_vista)
	_tabla = TablaComparacion.new()
	_tabla.custom_minimum_size = Vector2(0, 220)
	_tabla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabla)
	_controles = HBoxContainer.new()
	_controles.add_theme_constant_override("separation", 8)
	v.add_child(_controles)
	_pregunta = Label.new()
	_pregunta.add_theme_font_size_override("font_size", 16)
	_pregunta.add_theme_color_override("font_color", T.AMBAR)
	_pregunta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_pregunta)
	_opciones = HBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 10)
	v.add_child(_opciones)
	_retro = RichTextLabel.new()
	_retro.bbcode_enabled = true
	_retro.fit_content = true
	_retro.scroll_active = false
	_retro.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	v.add_child(_retro)
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	v.add_child(pie)
	_anterior = _boton(pie, "◀  Anterior", func(): ir(pagina - 1))
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(hueco)
	_siguiente = _boton(pie, "Siguiente  ▶", _avanzar_pagina)
	if id != "":
		abrir(id)


func _boton(padre: Control, texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


func abrir(p_id: String) -> void:
	id = p_id
	aciertos = 0
	if _titulo == null:
		return                       # se completa en _ready
	ir(0)


func ir(n: int) -> void:
	var paginas: Array = TUTORIALES[id]["paginas"]
	pagina = clampi(n, 0, paginas.size() - 1)
	var pg: Dictionary = paginas[pagina]
	corriendo = false
	respondida = -1
	_titulo.text = "%s · %s" % [TUTORIALES[id]["titulo"], pg["titulo"]]
	_indice.text = "%d / %d" % [pagina + 1, paginas.size()]
	_texto.text = pg.get("texto", "")
	if pg.has("formula"):
		_texto.text += "\n[color=#ffc759][b]%s[/b][/color]" % pg["formula"]
	_anterior.disabled = pagina == 0
	_siguiente.text = "Terminar  ✓" if pagina == paginas.size() - 1 else "Siguiente  ▶"
	_tabla.visible = pg["tipo"] == "tabla"
	_vista.visible = pg.has("maquina")
	if pg.has("maquina"):
		_cargar(pg, pg["entrada"])
	for h in _controles.get_children():
		h.queue_free()
	for h in _opciones.get_children():
		h.queue_free()
	_retro.text = ""
	_pregunta.visible = pg["tipo"] == "ejercicio"
	_opciones.visible = pg["tipo"] == "ejercicio"
	_controles.visible = pg["tipo"] == "sim"
	if pg["tipo"] == "sim":
		_boton(_controles, "Paso", func(): _paso())
		_ejecutar = _boton(_controles, "▶ Ejecutar", func(): corriendo = not corriendo)
		_boton(_controles, "↺ Reiniciar", func(): _cargar(pg, pg["entrada"]))
		var entradas: Array = pg.get("entradas", [])
		if not entradas.is_empty():
			var sep := VSeparator.new()
			_controles.add_child(sep)
			for k in entradas.size():
				var e = entradas[k]
				var etiqueta: String = pg.get("etiquetas", [])[k] if k < pg.get("etiquetas", []).size() else \
						"Entrada «%s»" % (e if e is String else ",".join(PackedStringArray(e)))
				_boton(_controles, etiqueta, func(): _cargar(pg, e))
	elif pg["tipo"] == "ejercicio":
		_pregunta.text = pg["pregunta"]
		for i in pg["opciones"].size():
			var k: int = i
			_boton(_opciones, pg["opciones"][i], func(): responder(k))


func _cargar(pg: Dictionary, entrada) -> void:
	maquina = crear_maquina(pg["maquina"])
	if maquina is MTEstandar:
		(maquina as MTEstandar).cargar(entrada)
	elif maquina is MTMulticinta:
		(maquina as MTMulticinta).cargar(entrada)
	else:
		(maquina as MTMultipista).cargar(entrada)
	for i in pg.get("previos", 0):
		maquina.paso()
	_vista.maquina = maquina
	_vista.nombres = pg.get("nombres", [])
	corriendo = false


static func crear_maquina(nombre: String) -> MaquinaTuring:
	match nombre:
		"incrementador": return ProgramasTuring.incrementador()
		"clave_vitrina": return ProgramasTuring.verificador_clave(Desafio.IDENTIDAD, false)
		"anbn": return ProgramasTuring.anbn()
		"suma_multicinta": return ProgramasTuring.suma_multicinta()
		"cruce": return ProgramasTuring.cruce_multipista()
		"reparto": return ProgramasTuring.reparto_multicinta()
		"correlador_sensores": return ProgramasTuring.correlador_sensores()
		"analizador_radar": return ProgramasTuring.analizador_radar()
	return null


func _paso() -> void:
	if maquina and not maquina.detenida():
		var t := maquina.paso()
		var juego = get_tree().current_scene
		if juego and juego.get("audio") != null:
			juego.audio.operacion_mt(t)


## Elige una opción del ejercicio. Devuelve true si es la correcta.
func responder(k: int) -> bool:
	var pg: Dictionary = TUTORIALES[id]["paginas"][pagina]
	var ok: bool = k == pg["correcta"]
	if respondida == -1 and ok:
		aciertos += 1
	respondida = k
	var botones := _opciones.get_children()
	for i in botones.size():
		var b: Button = botones[i]
		if i == pg["correcta"]:
			b.add_theme_color_override("font_color", T.VERDE)
		elif i == k:
			b.add_theme_color_override("font_color", T.ROJO)
	if ok:
		_retro.text = "[color=#59ff94][b]¡Correcto![/b][/color] " + pg["explica"]
	else:
		_retro.text = "[color=#ff5c52][b]No exactamente.[/b][/color] " + pg["explica"]
	var juego = get_tree().current_scene if is_inside_tree() else null
	if juego and juego.get("audio") != null:
		juego.audio.sonar("mt_acepta" if ok else "mt_rechaza")
	return ok


func _avanzar_pagina() -> void:
	var paginas: Array = TUTORIALES[id]["paginas"]
	if pagina >= paginas.size() - 1:
		Ajustes.marcar_tutorial(id)
		terminado.emit(id)
	else:
		ir(pagina + 1)


func _process(dt: float) -> void:
	if not is_visible_in_tree() or maquina == null:
		return
	if corriendo:
		t_paso += dt
		if t_paso >= 0.35:
			t_paso = 0.0
			_paso()
			if maquina.detenida():
				corriendo = false
	if _ejecutar and is_instance_valid(_ejecutar):
		_ejecutar.text = "Pausar" if corriendo else "▶ Ejecutar"


func _unhandled_key_input(e: InputEvent) -> void:
	if not is_visible_in_tree() or not (e is InputEventKey and e.pressed):
		return
	match e.keycode:
		KEY_RIGHT:
			_avanzar_pagina()
			accept_event()
		KEY_LEFT:
			ir(pagina - 1)
			accept_event()
		KEY_SPACE:
			_paso()
			accept_event()


## Tabla comparativa multicinta vs multipista.
class TablaComparacion:
	extends Control

	const FILAS := [
		["", "Multicinta", "Multipista"],
		["Cintas", "k cintas", "1 cinta con k pistas"],
		["Cabezales", "k (independientes)", "1 (lee la columna)"],
		["Movimientos por paso", "k: (M₁,…,Mₖ)", "1: M"],
		["Una casilla guarda", "1 símbolo por cinta", "una tupla (a₁,…,aₖ)"],
		["En SOMBRA", "bóveda · correlador del radar", "rejilla láser · analizador del radar"],
		["Poder de cómputo", "igual que la estándar", "igual que la estándar"],
	]

	func _process(_dt: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var T2 := TemaConsola
		draw_rect(Rect2(Vector2.ZERO, size), T2.PANEL)
		var rh := size.y / FILAS.size()
		var c0 := size.x * 0.28
		var cw := (size.x - c0) / 2
		for i in FILAS.size():
			var y := i * rh
			if i % 2 == 1:
				draw_rect(Rect2(0, y, size.x, rh), Color(1, 1, 1, 0.03))
			for j in 3:
				var x := 0.0 if j == 0 else c0 + cw * (j - 1)
				var w := c0 if j == 0 else cw
				var col := T2.CIAN if i == 0 else (T2.SUAVE if j == 0 else T2.TEXTO)
				Dibujo.texto(self, FILAS[i][j], Vector2(x + w / 2, y + rh / 2), 15 if i == 0 else 14, col, true,
						i == 0, false)
			draw_line(Vector2(0, y), Vector2(size.x, y), T2.BORDE, 1.0)
		draw_line(Vector2(c0, 0), Vector2(c0, size.y), T2.BORDE, 1.0)
		draw_line(Vector2(c0 + cw, 0), Vector2(c0 + cw, size.y), T2.BORDE, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), T2.BORDE, false, 1.0)
