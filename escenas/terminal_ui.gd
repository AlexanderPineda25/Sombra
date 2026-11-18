## Interfaz de una terminal de seguridad: muestra la máquina de Turing del
## desafío (cintas, pistas, cabezales, estado, transición) y deja editar la
## entrada, ejecutar paso a paso, pausar y reiniciar.
##
## Solo dibuja y recibe órdenes: la lógica está en turing/ y juego/desafio.gd.
extends Control

## Cada paso de la máquina (lo escucha el gestor de audio y la consola F1).
signal operacion(t: Dictionary)

const ANCHO := 960.0
const ALTO := 704.0
const PANEL := Rect2(28, 22, 904, 660)
const CIAN := Color(0.30, 0.86, 1.0)
const VERDE := Color(0.35, 1.0, 0.58)
const ROJO := Color(1.0, 0.36, 0.32)
const AMBAR := Color(1.0, 0.78, 0.35)
const FONDO := Color(0.035, 0.06, 0.10, 0.97)
const TEXTO := Color(0.88, 0.92, 0.96)
const SUAVE := Color(0.55, 0.64, 0.74)
const FLECHA := {"L": "←", "R": "→", "S": "•"}
const NOMBRE_VARIANTE := {
	"estandar": "MÁQUINA DE TURING ESTÁNDAR · 1 cinta, 1 cabezal",
	"multicinta": "MÁQUINA MULTICINTA · 3 cintas, 3 cabezales",
	"multipista": "MÁQUINA MULTIPISTA · 1 cinta con 3 pistas, 1 cabezal",
}
const EFECTO := {"puerta": "La puerta electrónica se abrió.", "camaras": "Todas las cámaras quedaron apagadas.",
		"laser": "La rejilla láser se apagó."}

var juego
var terminal = null
var desafio: Desafio
var corriendo := false
var t_paso := 0.0
var velocidad := 1                 ## 1, 2 o 4 pasos por intervalo
var cabezal_visual: Array = []     ## posición animada de cada cabezal
var celdas: Array = []             ## zonas clicables {rect, fila, pos}
var cursor := 0                    ## casilla editable seleccionada con el teclado
var informado := false             ## ya se avisó al juego del resultado de esta ejecución
var resultado := {}
var tiempo := 0.0
var botones := {}
## Modo visor: superposición didáctica que repite la ejecución REAL del último
## intento de un minijuego sobre una copia del desafío (no toca la partida).
var modo_visor := false
var intento_visor := {}


func _ready() -> void:
	visible = false
	position = Vector2.ZERO
	size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var y := PANEL.end.y - 58
	_boton("ejecutar", "▶  Ejecutar", Vector2(PANEL.position.x + 24, y), 170, _alternar_ejecucion)
	_boton("paso", "Paso", Vector2(PANEL.position.x + 206, y), 130, _un_paso)
	_boton("reiniciar", "↺  Reiniciar", Vector2(PANEL.position.x + 348, y), 150, _reiniciar)
	_boton("velocidad", "Velocidad x1", Vector2(PANEL.position.x + 510, y), 150, _cambiar_velocidad)
	_boton("salir", "✕  Salir", Vector2(PANEL.end.x - 154, y), 130, _salir)


func _boton(id: String, texto: String, pos: Vector2, ancho: float, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.size = Vector2(ancho, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"normal": Color(0.07, 0.14, 0.2), "hover": Color(0.1, 0.24, 0.32),
				"pressed": Color(0.16, 0.4, 0.5), "disabled": Color(0.06, 0.08, 0.1)}[estado]
		st.border_color = CIAN if estado != "disabled" else Color(0.2, 0.25, 0.3)
		st.set_border_width_all(2)
		st.set_corner_radius_all(8)
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
	corriendo = false
	informado = desafio.resuelto
	resultado = {}
	cursor = 0
	var fe := _fila_editable()
	if fe >= 0:
		cursor = desafio.filas[fe].get("editable_desde", 0)
	if desafio.resuelto:
		# muestra la máquina ya resuelta con la solución en la cinta
		var sol := desafio.solucion_filas
		for i in desafio.filas.size():
			desafio.filas[i]["contenido"] = sol[i]
		desafio.construir()
		desafio.maquina.ejecutar()
		resultado = desafio.comprobar()
	else:
		desafio.construir()
	_sincronizar_cabezales(true)
	visible = true
	var nombres := []
	for f in desafio.filas:
		nombres.append(f["nombre"])
	juego.partida.registrar_maquina(desafio.variante, {"origen": "Terminal · " + desafio.titulo,
			"desafio": desafio, "nombres": nombres})


func cerrar() -> void:
	visible = false
	corriendo = false
	modo_visor = false
	botones["salir"].text = "✕  Salir"


## Abre el visor técnico sobre un minijuego: `copia` es un desafío de solo
## lectura con la entrada del intento; `intento` trae las transiciones que
## ejecutó la máquina en el juego (para comprobar que la repetición coincide).
func abrir_visor(copia: Desafio, intento: Dictionary) -> void:
	modo_visor = true
	intento_visor = intento
	terminal = null
	desafio = copia
	corriendo = false
	informado = true
	resultado = {}
	desafio.construir()
	_sincronizar_cabezales(true)
	botones["salir"].text = "✕  Volver"
	visible = true


func _salir() -> void:
	if modo_visor:
		cerrar()
	else:
		juego.cerrar_terminal()


## En el visor, un intento a medias se repite solo hasta donde llegó en el juego.
func _limite_visor() -> int:
	if modo_visor and intento_visor.get("resultado", "") == "EN CURSO":
		return int(intento_visor.get("pasos", 0))
	return -1


func _alternar_ejecucion() -> void:
	if desafio.maquina.detenida():
		_reiniciar()
	corriendo = not corriendo


func _un_paso() -> void:
	corriendo = false
	_avanzar()


func _reiniciar() -> void:
	corriendo = false
	informado = desafio.resuelto
	resultado = {}
	desafio.construir()
	_sincronizar_cabezales(true)


func _cambiar_velocidad() -> void:
	velocidad = {1: 2, 2: 4, 4: 1}[velocidad]
	botones["velocidad"].text = "Velocidad x%d" % velocidad


func _editable() -> bool:
	return desafio.maquina.pasos == 0 and not corriendo and not desafio.resuelto and not modo_visor


func _avanzar() -> void:
	var m := desafio.maquina
	if m.detenida():
		return
	var lim := _limite_visor()
	if lim >= 0 and m.pasos >= lim:
		corriendo = false
		return
	operacion.emit(m.paso())
	if m.detenida():
		corriendo = false
		resultado = desafio.comprobar()
		if not informado:
			informado = true
			juego.terminal_terminada(resultado["exito"])


func _cabezales() -> Array:
	var m := desafio.maquina
	match desafio.variante:
		"estandar":
			return [(m as MTEstandar).cinta.cabezal]
		"multicinta":
			var r := []
			for c in (m as MTMulticinta).cintas:
				r.append(c.cabezal)
			return r
		_:
			return [(m as MTMultipista).cabezal]


func _sincronizar_cabezales(de_golpe := false) -> void:
	var reales := _cabezales()
	if de_golpe or cabezal_visual.size() != reales.size():
		cabezal_visual = []
		for h in reales:
			cabezal_visual.append(float(h))


func _process(dt: float) -> void:
	if not visible:
		return
	tiempo += dt
	if corriendo:
		t_paso += dt
		var intervalo := 0.42 / velocidad
		while t_paso >= intervalo and corriendo:
			t_paso -= intervalo
			_avanzar()
	var reales := _cabezales()
	for i in reales.size():
		cabezal_visual[i] = lerpf(cabezal_visual[i], float(reales[i]), minf(1.0, dt * 14.0))
	botones["ejecutar"].text = "Pausar" if corriendo else "▶  Ejecutar"
	botones["paso"].disabled = desafio.maquina.detenida()
	queue_redraw()


# ---------------------------------------------------------------------- #
# Entrada
# ---------------------------------------------------------------------- #
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for c in celdas:
			if c["rect"].has_point(e.position):
				if _editable():
					desafio.alternar(c["fila"], c["pos"])
					cursor = c["pos"]
					_sincronizar_cabezales(true)
				accept_event()
				return


func _input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var fila := _fila_editable()
	match e.keycode:
		KEY_ESCAPE, KEY_V:
			if modo_visor or e.keycode == KEY_ESCAPE:
				_salir()
		KEY_SPACE:
			_alternar_ejecucion()
		KEY_N, KEY_PERIOD:
			_un_paso()
		KEY_R:
			_reiniciar()
		KEY_LEFT:
			cursor = maxi(desafio.filas[fila].get("editable_desde", 0) if fila >= 0 else 0, cursor - 1)
		KEY_RIGHT:
			if fila >= 0:
				cursor = mini(desafio.filas[fila]["contenido"].length() - 1, cursor + 1)
		_:
			var letra := String.chr(e.unicode).to_lower() if e.unicode > 0 else ""
			if fila >= 0 and desafio.filas[fila].has("teclas"):
				letra = desafio.filas[fila]["teclas"].get(letra, "")   # 1-4 = gemas
			if fila >= 0 and _editable() and letra in desafio.filas[fila]["simbolos"]:
				desafio.poner(fila, cursor, letra)
				cursor = mini(desafio.filas[fila]["contenido"].length() - 1, cursor + 1)
				_sincronizar_cabezales(true)
	get_viewport().set_input_as_handled()


func _fila_editable() -> int:
	for i in desafio.filas.size():
		if desafio.filas[i]["editable"]:
			return i
	return -1


# ---------------------------------------------------------------------- #
# Dibujo
# ---------------------------------------------------------------------- #
func _draw() -> void:
	if desafio == null:
		return
	var m := desafio.maquina
	draw_rect(Rect2(0, 0, ANCHO, ALTO), Color(0, 0.01, 0.03, 0.72))
	# panel con borde de neón
	draw_rect(PANEL.grow(6), Color(CIAN, 0.08))
	draw_rect(PANEL, FONDO)
	draw_rect(PANEL, Color(CIAN, 0.85), false, 2.0)
	for k in range(int(PANEL.position.y) + 4, int(PANEL.end.y), 4):        # líneas de barrido
		draw_line(Vector2(PANEL.position.x + 2, k), Vector2(PANEL.end.x - 2, k), Color(1, 1, 1, 0.012))
	var x0 := PANEL.position.x + 24
	var y := PANEL.position.y + 18

	# encabezado
	Dibujo.texto(self, desafio.titulo.to_upper(), Vector2(x0, y), 26, Color.WHITE, false, true, false)
	_pastilla(NOMBRE_VARIANTE[desafio.variante], Vector2(x0, y + 38), CIAN)
	var estado_txt := "LISTA"
	var estado_col := CIAN
	if desafio.resuelto:
		estado_txt = "ACCESO CONCEDIDO"
		estado_col = VERDE
	elif not resultado.is_empty() and not resultado["exito"]:
		estado_txt = "ACCESO DENEGADO"
		estado_col = ROJO
	elif corriendo:
		estado_txt = "EJECUTANDO"
		estado_col = AMBAR
	if modo_visor:
		estado_txt = "VISOR · intento #%d" % int(intento_visor.get("n", 1))
		estado_col = AMBAR
	_pastilla(estado_txt, Vector2(PANEL.end.x - 24 - Dibujo.ancho_texto(estado_txt, 13, true) - 24, y + 4), estado_col)

	# objetivo
	y += 76
	draw_rect(Rect2(x0 - 8, y - 6, PANEL.size.x - 32, 52), Color(1, 1, 1, 0.035))
	draw_rect(Rect2(x0 - 8, y - 6, 3, 52), AMBAR)
	_parrafo("OBJETIVO  " + desafio.objetivo, Vector2(x0 + 4, y), PANEL.size.x - 56, 14, TEXTO, 2)

	# cintas / pistas
	y += 66
	_dibujar_cintas(Rect2(x0 - 8, y, PANEL.size.x - 32, 250))

	# estado y transición
	y += 262
	var izq := Rect2(x0 - 8, y, 400, 104)
	var der := Rect2(x0 + 404, y, PANEL.size.x - 444, 104)
	for r in [izq, der]:
		draw_rect(r, Color(1, 1, 1, 0.035))
		draw_rect(r, Color(CIAN, 0.25), false, 1.0)
	Dibujo.texto(self, "ESTADO ACTUAL", izq.position + Vector2(12, 8), 12, SUAVE, false, true, false)
	var col_estado := VERDE if m.estado == m.acepta else (ROJO if m.estado == m.rechaza else AMBAR)
	var tam_estado := 30 if Dibujo.ancho_texto(m.estado, 30, true) < 66 else 20
	var ancho_estado := Dibujo.ancho_texto(m.estado, tam_estado, true)
	Dibujo.texto(self, m.estado, izq.position + Vector2(12, 26 if tam_estado == 30 else 32), tam_estado, col_estado,
			false, true, false)
	Dibujo.texto(self, "paso %d" % m.pasos, izq.position + Vector2(izq.size.x - 70, 10), 13, SUAVE, false, false, false)
	var x_exp := maxf(84.0, ancho_estado + 26)
	_parrafo(m.explicacion_estados.get(m.estado, ""), izq.position + Vector2(x_exp, 30), izq.size.x - x_exp - 12, 13,
			TEXTO, 4)

	Dibujo.texto(self, "ÚLTIMA TRANSICIÓN", der.position + Vector2(12, 8), 12, SUAVE, false, true, false)
	if m.ultima.is_empty():
		_parrafo("Aún no se ejecuta ningún paso. Edita la entrada (clic o teclado) y pulsa Ejecutar o Paso.",
				der.position + Vector2(12, 30), der.size.x - 24, 13, SUAVE, 3)
	else:
		var u := m.ultima
		Dibujo.texto(self, _formato_transicion(u), der.position + Vector2(12, 30), 15, Color.WHITE, false, true, false)
		_parrafo(_explicar_transicion(u), der.position + Vector2(12, 56), der.size.x - 24, 13, TEXTO, 3)

	# lección del modelo
	y += 114
	_parrafo("¿QUÉ ESTÁS VIENDO?  " + desafio.leccion, Vector2(x0, y), PANEL.size.x - 48, 13, SUAVE, 3)

	# visor: comparación con la ejecución registrada en el minijuego
	if modo_visor:
		var banda_v := Rect2(PANEL.position.x + 16, PANEL.end.y - 136, PANEL.size.x - 32, 70)
		var lim := _limite_visor()
		var reg: String = intento_visor.get("resultado", "")
		var pasos_reg := int(intento_visor.get("pasos", 0))
		var txt := ""
		var col := CIAN
		if m.detenida() or (lim >= 0 and m.pasos >= lim):
			var igual := m.pasos == pasos_reg and (lim >= 0 or m.resultado() == reg)
			col = VERDE if igual else ROJO
			txt = "Repetición: %s en %d pasos. En el minijuego la máquina dio %s en %d pasos: %s" % [
					m.resultado() if lim < 0 else "pausa", m.pasos, reg, pasos_reg,
					"COINCIDEN ✓" if igual else "NO COINCIDEN ✗"]
		else:
			txt = "VISOR TÉCNICO · repite la ejecución real del intento #%d (%s, %d pasos). Usa Paso o Ejecutar; V o Esc vuelve al minijuego sin cambiar nada." % [
					int(intento_visor.get("n", 1)), reg, pasos_reg]
		draw_rect(banda_v, Color(0.02, 0.05, 0.07, 1.0))
		draw_rect(banda_v, col, false, 2.0)
		_parrafo(txt, banda_v.position + Vector2(16, 12), banda_v.size.x - 32, 14, TEXTO, 3)
		return

	# resultado
	if not resultado.is_empty():
		var exito: bool = resultado["exito"]
		var banda := Rect2(PANEL.position.x + 16, PANEL.end.y - 136, PANEL.size.x - 32, 70)
		draw_rect(banda.grow(4), Color(VERDE if exito else ROJO, 0.18))
		draw_rect(banda, Color(0.02, 0.05, 0.07, 1.0))
		draw_rect(banda, VERDE if exito else ROJO, false, 2.0)
		var titulo := "ACCESO CONCEDIDO" if exito else "ACCESO DENEGADO"
		Dibujo.texto(self, titulo, banda.position + Vector2(16, 10), 22, VERDE if exito else ROJO, false, true, false)
		var detalle: String = resultado["mensaje"] + " " + (EFECTO[desafio.efecto] if exito else
				"¡Bip! Los guardias cercanos oyeron el error. " + desafio.pista_ayuda)
		_parrafo(detalle, banda.position + Vector2(270, 12), banda.size.x - 286, 13, TEXTO, 3)


func _pastilla(txt: String, pos: Vector2, col: Color) -> void:
	var w := Dibujo.ancho_texto(txt, 13, true) + 22
	draw_rect(Rect2(pos, Vector2(w, 24)), Color(col, 0.14))
	draw_rect(Rect2(pos, Vector2(w, 24)), col, false, 1.5)
	Dibujo.texto(self, txt, pos + Vector2(11, 4), 13, col, false, true, false)


## Texto con salto de línea automático.
func _parrafo(txt: String, pos: Vector2, ancho: float, tam: int, col: Color, max_lineas := 3, centro := false) -> void:
	var palabras := txt.split(" ")
	var linea := ""
	var y := pos.y
	var lineas := 0
	for p in palabras:
		var prueba := (linea + " " + p).strip_edges()
		if Dibujo.ancho_texto(prueba, tam) > ancho and linea != "":
			_linea(linea, Vector2(pos.x, y), ancho, tam, col, centro)
			y += tam + 5
			lineas += 1
			linea = p
			if lineas >= max_lineas:
				return
		else:
			linea = prueba
	if linea != "":
		_linea(linea, Vector2(pos.x, y), ancho, tam, col, centro)


func _linea(txt: String, pos: Vector2, ancho: float, tam: int, col: Color, centro: bool) -> void:
	if centro:
		Dibujo.texto(self, txt, Vector2(pos.x + ancho / 2, pos.y + tam * 0.45), tam, col, true, false, false)
	else:
		Dibujo.texto(self, txt, pos, tam, col, false, false, false)


func _formato_transicion(u: Dictionary) -> String:
	var q: String = u["estado"]
	var n: String = u["nuevo"]
	if not u["definida"]:
		return "δ(%s, %s) no está definida → %s" % [q, _simbolos(u["leido"]), n]
	match desafio.variante:
		"estandar":
			return "δ(%s, %s) = (%s, %s, %s)" % [q, u["leido"], n, u["escrito"], u["mov"]]
		"multicinta":
			return "δ(%s, (%s)) = (%s, (%s), (%s))" % [q, ",".join(u["leido"]), n,
					",".join(u["escrito"]), ",".join(u["mov"])]
		_:
			return "δ(%s, [%s]) = (%s, [%s], %s)" % [q, "|".join(u["leido"]), n,
					"|".join(u["escrito"]), u["mov"]]


func _simbolos(s) -> String:
	if typeof(s) == TYPE_ARRAY:
		return "(" + ",".join(s) + ")"
	return str(s)


func _explicar_transicion(u: Dictionary) -> String:
	if not u["definida"]:
		return "Sin transición para lo que leyó: la máquina se detiene y RECHAZA."
	match desafio.variante:
		"estandar":
			return "Leyó '%s', escribió '%s' y movió el cabezal %s." % [u["leido"], u["escrito"],
					{"L": "a la izquierda", "R": "a la derecha", "S": "a ningún lado"}[u["mov"]]]
		"multicinta":
			var partes := []
			for i in u["mov"].size():
				partes.append("C%d %s" % [i + 1, FLECHA[u["mov"][i]]])
			return "Leyó las 3 cintas a la vez y movió cada cabezal por su cuenta: " + ", ".join(partes) + "."
		_:
			return "Leyó la columna [%s] de las 3 pistas, escribió [%s] y el ÚNICO cabezal fue %s." % [
					"|".join(u["leido"]), "|".join(u["escrito"]), FLECHA[u["mov"]]]


## Las cintas: estándar (1), multicinta (3 con cabezal propio) o multipista
## (1 cinta de 3 pistas con un único cabezal que abarca la columna).
func _dibujar_cintas(area: Rect2) -> void:
	celdas.clear()
	var m := desafio.maquina
	var n := desafio.filas.size()
	var multipista := desafio.variante == "multipista"
	# ventana de posiciones visibles
	var minimo := -1
	var maximo := 0
	for f in desafio.filas:
		maximo = maxi(maximo, f["contenido"].length())
	for i in n:
		var l := _limites(i)
		minimo = mini(minimo, l[0] - 1)
		maximo = maxi(maximo, l[1] + 2)
	for h in _cabezales():
		minimo = mini(minimo, h - 1)
		maximo = maxi(maximo, h + 2)
	var etiqueta_w := 196.0
	var columnas := maximo - minimo + 1
	var celda := minf(50.0, (area.size.x - etiqueta_w - 16) / columnas)
	var alto_fila := 46.0
	var hueco := 0.0 if multipista else 26.0
	var total_alto := n * alto_fila + (n - 1) * hueco
	var y0 := area.position.y + (area.size.y - total_alto) / 2 + 8
	var x0 := area.position.x + etiqueta_w
	var u := m.ultima
	var editable := _editable()
	var fila_ed := _fila_editable()

	if multipista:
		Dibujo.texto(self, "UNA CINTA · 3 PISTAS", Vector2(area.position.x + 6, y0 - 26), 12, CIAN, false, true, false)

	for i in n:
		var f: Dictionary = desafio.filas[i]
		var fy := y0 + i * (alto_fila + hueco)
		Dibujo.texto(self, f["nombre"], Vector2(area.position.x + 6, fy + alto_fila / 2 - 8), 13,
				TEXTO if not f["editable"] else AMBAR, false, true, false)
		for c in columnas:
			var pos := minimo + c
			var r := Rect2(x0 + c * celda, fy, celda - (3 if not multipista else 2), alto_fila - (0 if multipista else 0))
			var sim := _leer(i, pos)
			var dentro = pos >= 0 and pos < f["contenido"].length()
			var fondo := Color(0.06, 0.1, 0.15)
			if sim == "*":
				fondo = Color(0.06, 0.22, 0.14)
			elif sim == "X":
				fondo = Color(0.28, 0.06, 0.06)
			draw_rect(r, fondo)
			# casilla recién escrita: destello
			if not u.is_empty() and _fue_escrita(u, i, pos):
				var a := clampf(1.0 - fmod(tiempo * 2.0, 1.0), 0.0, 1.0) * 0.0 + 0.35
				draw_rect(r, Color(AMBAR, a))
			draw_rect(r, Color(CIAN, 0.22), false, 1.0)
			var col := TEXTO if sim != "_" else Color(0.3, 0.38, 0.46)
			if sim == "*":
				col = VERDE
			elif sim == "X":
				col = ROJO
			if not (m.usa_gemas and Dibujo.gema(self, sim, r)):
				Dibujo.texto(self, sim if sim != "_" else "␣", r.get_center(), 22, col, true, true, false)
			if desafio.editable_en(i, pos) and dentro:
				draw_line(Vector2(r.position.x + 4, r.end.y - 3), Vector2(r.end.x - 4, r.end.y - 3),
						AMBAR if editable else Color(AMBAR, 0.3), 2.0)
				if editable and i == fila_ed and pos == cursor:
					draw_rect(r.grow(1), AMBAR, false, 2.0)
				celdas.append({"rect": r, "fila": i, "pos": pos})
			if c == 0 or pos == 0:
				pass
		# índice de posición bajo la última fila
		if i == n - 1:
			for c in columnas:
				var pos := minimo + c
				if pos % 2 == 0:
					Dibujo.texto(self, str(pos), Vector2(x0 + c * celda + celda / 2 - 1, fy + alto_fila + 12),
							10, SUAVE, true, false, false)

	# cabezales
	var cabezas := cabezal_visual
	if multipista:
		var hx = x0 + (cabezas[0] - minimo) * celda
		var r := Rect2(hx - 3, y0 - 6, celda + 3, total_alto + 12)
		draw_rect(r, Color(AMBAR, 0.12))
		draw_rect(r, AMBAR, false, 3.0)
		_triangulo(Vector2(hx + celda / 2 - 1, y0 - 8))
		Dibujo.texto(self, "cabezal", Vector2(hx + celda / 2, y0 - 30), 11, AMBAR, true, true, false)
	else:
		for i in cabezas.size():
			var fy := y0 + i * (alto_fila + hueco)
			var hx = x0 + (cabezas[i] - minimo) * celda
			var r := Rect2(hx - 2, fy - 3, celda + 1, alto_fila + 6)
			draw_rect(r, AMBAR, false, 3.0)
			_triangulo(Vector2(hx + celda / 2 - 1, fy - 5))
			if desafio.variante == "multicinta":
				Dibujo.texto(self, "C%d" % (i + 1), Vector2(hx + celda / 2, fy - 17), 10, AMBAR, true, true, false)


func _triangulo(punta: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(-8, -10), punta + Vector2(8, -10)]), AMBAR)


func _leer(fila: int, pos: int) -> String:
	var m := desafio.maquina
	match desafio.variante:
		"estandar":
			return (m as MTEstandar).cinta.leer_en(pos)
		"multicinta":
			return (m as MTMulticinta).cintas[fila].leer_en(pos)
		_:
			return (m as MTMultipista).leer_en(pos)[fila]


func _limites(fila: int) -> Array:
	var m := desafio.maquina
	match desafio.variante:
		"estandar":
			return (m as MTEstandar).cinta.limites()
		"multicinta":
			return (m as MTMulticinta).cintas[fila].limites()
		_:
			return (m as MTMultipista).limites()


func _fue_escrita(u: Dictionary, fila: int, pos: int) -> bool:
	match desafio.variante:
		"estandar":
			return u["posicion"] == pos and u["escrito"] != u["leido"]
		"multicinta":
			return u["posicion"][fila] == pos and u["escrito"][fila] != u["leido"][fila]
		_:
			return u["posicion"] == pos and u["escrito"][fila] != u["leido"][fila]
