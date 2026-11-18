## SOMBRA: Robo en el Museo — escena principal.
##
## El flujo de pantallas es un AFD: cada tecla o resultado de la partida es un
## símbolo, y aquí solo se ejecutan los efectos de entrar a cada estado.
##
## Árbol de nodos (se arma en _ready y, por nivel, en cargar()):
##   Main (Node2D)
##   ├── Mundo (Node2D)              piso, muros, pedestales, puertas, terminales
##   ├── Nivel (Node2D)              se rehace en cada nivel:
##   │   ├── Oclusores               LightOccluder2D de los muros (sombras)
##   │   ├── Ambiente                focos de las vitrinas, salida, terminales
##   │   ├── Camaras / Guardias      sprites animados con su luz en cono
##   │   └── Ladron                  sprite animado del jugador
##   ├── Follaje (Node2D)            plantas, por encima de los personajes
##   ├── Oscuridad (CanvasModulate)  oscurece el museo
##   ├── LuzJugador (PointLight2D)   visión del ladrón
##   ├── Accion (CanvasLayer 1)      conos, ruidos, iconos, láseres, partículas
##   ├── Postproceso (CanvasLayer 1) viñeta, grano, alarma, aberración (shader)
##   ├── Interfaz (CanvasLayer 2)    HUD, tarjeta de nivel, pistas y pantallas
##   ├── Terminal (CanvasLayer 3)    interfaz de las máquinas de Turing
##   ├── Tutorial (CanvasLayer 4)    tutorial interactivo que aparece la primera vez
##   ├── Audio (GestorAudio)         música adaptativa y efectos
##   └── Consola (Window nativa)     consola de seguridad F1 (AFD, MT, radar, registro)
extends Node2D

const CapaMundo := preload("res://escenas/capa_mundo.gd")
const CapaFollaje := preload("res://escenas/follaje.gd")
const CapaAccion := preload("res://escenas/capa_accion.gd")
const CapaInterfaz := preload("res://escenas/interfaz.gd")
const UITerminal := preload("res://escenas/terminal_ui.gd")

const T := Config.TILE

var flujo: AFD = Def.crear_afd_flujo()
var partida: Partida
var nivel := 0
var consola: ConsolaSeguridad
var capa_tutorial: CanvasLayer
var panel_tutorial: PanelTutorial
var pistas_dadas := {}           ## pistas cortas ya mostradas en esta sesión
var guardia_sel := 0
var tiempo := 0.0
var saltar_menu := false
var luz: PointLight2D
var oscuridad: CanvasModulate
var nodo_nivel: Node2D
var oclusores_puertas: Array = []
var luces_laser: Array = []
var accion
var terminal_ui
var ui                           ## capa de interfaz (HUD, pistas, pantallas)
var terminal_abierta = null      ## la terminal en uso (o null)
var audio: GestorAudio
var post: ShaderMaterial          ## shader de postproceso (lo alimentan los AFD)
var capa_accion: CanvasLayer
var sacudida := 0.0               ## intensidad de la sacudida de cámara
var t_intro := 99.0               ## segundos desde que empezó el nivel (tarjeta)
var polvo: CPUParticles2D
var _post_vals := {"aberracion": 0.0, "alarma": 0.0, "oculto": 0.0, "tension": 0.0}
var _alarmas_vistas := 0


## Atajos que funcionan aunque el juego esté en pausa (F1 abre/cierra la consola).
class Atajos:
	extends Node
	var juego

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F1:
			if not juego.capa_tutorial.visible:
				juego.consola.alternar()
			get_viewport().set_input_as_handled()
		elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and juego.capa_tutorial.visible:
			juego.cerrar_tutorial()
			get_viewport().set_input_as_handled()


func _ready() -> void:
	# argumentos: godot -- --nivel 2
	var args := OS.get_cmdline_user_args()
	var i := args.find("--nivel")
	if i >= 0 and i + 1 < args.size():
		nivel = clampi(int(args[i + 1]), 1, Niveles.cantidad()) - 1
		saltar_menu = nivel > 0
	Ajustes.cargar()
	_armar_escena()
	cargar(0, true)                       # fondo animado del menú
	if saltar_menu:
		disparar("enter")


func _armar_escena() -> void:
	var mundo = Node2D.new()
	mundo.name = "Mundo"
	mundo.set_script(CapaMundo)
	mundo.juego = self
	add_child(mundo)

	nodo_nivel = Node2D.new()
	nodo_nivel.name = "Nivel"
	add_child(nodo_nivel)

	var follaje = Node2D.new()
	follaje.name = "Follaje"
	follaje.set_script(CapaFollaje)
	follaje.juego = self
	add_child(follaje)

	oscuridad = CanvasModulate.new()
	oscuridad.name = "Oscuridad"
	oscuridad.color = Color(0.27, 0.29, 0.40)
	add_child(oscuridad)

	luz = Vistas._luz(Arte.circulo, 1.05, Color(0.85, 0.9, 1.0), 0.75, true)
	luz.name = "LuzJugador"
	add_child(luz)

	polvo = _crear_polvo()
	add_child(polvo)

	capa_accion = CanvasLayer.new()
	capa_accion.name = "Accion"
	capa_accion.layer = 1
	add_child(capa_accion)
	accion = Node2D.new()
	accion.set_script(CapaAccion)
	accion.juego = self
	capa_accion.add_child(accion)

	var capa_post := CanvasLayer.new()
	capa_post.name = "Postproceso"
	capa_post.layer = 1
	add_child(capa_post)
	var velo_post := ColorRect.new()
	velo_post.size = Vector2(Config.ANCHO, Config.ALTO_MAPA)
	velo_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = preload("res://escenas/postproceso.gdshader")
	velo_post.material = post
	capa_post.add_child(velo_post)

	var capa_ui := CanvasLayer.new()
	capa_ui.name = "Interfaz"
	capa_ui.layer = 2
	add_child(capa_ui)
	ui = Node2D.new()
	ui.set_script(CapaInterfaz)
	ui.juego = self
	capa_ui.add_child(ui)

	var capa_term := CanvasLayer.new()
	capa_term.name = "Terminal"
	capa_term.layer = 3
	add_child(capa_term)
	terminal_ui = Control.new()
	terminal_ui.set_script(UITerminal)
	terminal_ui.juego = self
	capa_term.add_child(terminal_ui)

	audio = GestorAudio.new()
	audio.name = "Audio"
	add_child(audio)
	terminal_ui.operacion.connect(audio.operacion_mt)

	capa_tutorial = CanvasLayer.new()
	capa_tutorial.name = "Tutorial"
	capa_tutorial.layer = 4
	capa_tutorial.process_mode = Node.PROCESS_MODE_ALWAYS
	capa_tutorial.visible = false
	add_child(capa_tutorial)
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.01, 0.03, 0.78)
	velo.size = Vector2(Config.ANCHO, Config.ALTO)
	capa_tutorial.add_child(velo)
	panel_tutorial = PanelTutorial.new()
	panel_tutorial.position = Vector2(60, 40)
	panel_tutorial.size = Vector2(Config.ANCHO - 120, Config.ALTO - 80)
	panel_tutorial.terminado.connect(func(_id): cerrar_tutorial())
	capa_tutorial.add_child(panel_tutorial)

	consola = ConsolaSeguridad.new()
	consola.name = "Consola"
	consola.juego = self
	add_child(consola)
	var at := Atajos.new()
	at.juego = self
	add_child(at)


# ---------------------------------------------------------------------- #
# Flujo de pantallas (AFD)
# ---------------------------------------------------------------------- #
func disparar(evento: String) -> void:
	var antes := flujo.actual
	var despues := flujo.paso(evento)
	if antes == despues:
		return
	if antes == Def.TERMINAL:
		_al_cerrar_terminal()
	match despues:
		Def.MENU:
			cargar(0, true)
		Def.JUGANDO:
			if antes == Def.MENU:
				cargar(nivel if saltar_menu else 0)
				saltar_menu = false
			elif antes == Def.DERROTA:
				cargar(nivel)                 # reintentar
			elif antes == Def.VICTORIA:
				cargar(nivel + 1)             # siguiente nivel
		Def.TERMINAL:
			_al_abrir_terminal()


func cargar(indice: int, demo := false) -> void:
	nivel = indice
	partida = Partida.new(indice, demo)
	guardia_sel = 0
	if audio:
		partida.seguridad.evento.connect(audio.evento_seguridad)
		audio.fijar_tema(GestorAudio.TEMAS[indice % GestorAudio.TEMAS.size()])
	if accion:
		accion.etiquetas.clear()
		accion.marcas.clear()
	_armar_nivel()
	_alarmas_vistas = 0
	t_intro = 99.0 if demo else 0.0
	if not demo and audio:
		audio.sonar("nivel")


## Reinicia el nivel actual (la consola lo usa tras recompilar su programa).
func reiniciar_nivel() -> void:
	if flujo.actual == Def.TERMINAL:
		disparar("esc")
	cargar(nivel, partida.demo)


## Construye los nodos que dependen del nivel: sombras, luces y personajes.
func _armar_nivel() -> void:
	for h in nodo_nivel.get_children():
		h.queue_free()
	oclusores_puertas.clear()
	luces_laser.clear()
	var mapa := partida.mapa

	# muros que proyectan sombra (filas de casillas unidas en rectángulos)
	var oclusores := Node2D.new()
	oclusores.name = "Oclusores"
	nodo_nivel.add_child(oclusores)
	var camaras_t := {}
	for c in partida.camaras:
		camaras_t[c.tile] = true
	for y in mapa.alto:
		var x := 0
		while x < mapa.ancho:
			var t := Vector2i(x, y)
			if mapa.es_pared(t) and not mapa.es_puerta(t) and not camaras_t.has(t):
				var x0 := x
				while x < mapa.ancho and mapa.es_pared(Vector2i(x, y)) and not mapa.es_puerta(Vector2i(x, y)) \
						and not camaras_t.has(Vector2i(x, y)):
					x += 1
				oclusores.add_child(_oclusor(Rect2(x0 * T, y * T, (x - x0) * T, T)))
			else:
				x += 1
	for t in mapa.puertas:
		var o := _oclusor(Rect2(t.x * T, t.y * T, T, T))
		oclusores.add_child(o)
		oclusores_puertas.append(o)

	# iluminación del museo: focos sobre las vitrinas, salida y terminales
	var ambiente := Node2D.new()
	ambiente.name = "Ambiente"
	nodo_nivel.add_child(ambiente)
	for i in mapa.joyas.size():
		var foco := Vistas._luz(Arte.circulo, 0.55, Config.JOYA[i % 3].lerp(Color(1, 0.9, 0.7), 0.5), 0.9, false)
		foco.position = Mapa.centro(mapa.joyas[i])
		ambiente.add_child(foco)
	var luz_salida := Vistas._luz(Arte.circulo, 0.6, Color(1.0, 0.3, 0.25), 0.8, false)
	luz_salida.name = "LuzSalida"
	luz_salida.position = Mapa.centro(mapa.salida)
	ambiente.add_child(luz_salida)
	for term in partida.terminales:
		var brillo := Vistas._luz(Arte.circulo, 0.4, Color(0.3, 0.85, 1.0), 0.9, false)
		brillo.position = Mapa.centro(term["pos"])
		ambiente.add_child(brillo)
	for r in partida.radares:
		var verde := Vistas._luz(Arte.circulo, 0.45, Color(0.35, 1.0, 0.7), 0.8, false)
		verde.position = r.pos
		ambiente.add_child(verde)
	for t in mapa.laseres:
		var rojo := Vistas._luz(Arte.circulo, 0.35, Color(1.0, 0.2, 0.2), 0.9, false)
		rojo.position = Mapa.centro(t)
		ambiente.add_child(rojo)
		luces_laser.append(rojo)

	# personajes
	for c in partida.camaras:
		var vc := Vistas.CamaraVista.new()
		vc.camara = c
		nodo_nivel.add_child(vc)
	for g in partida.guardias:
		var vg := Vistas.GuardiaVista.new()
		vg.juego = self
		vg.guardia = g
		nodo_nivel.add_child(vg)
	var vl := Vistas.Ladron.new()
	vl.juego = self
	nodo_nivel.add_child(vl)


## Motas de polvo que flotan por el museo: solo se ven donde hay luz
## (linternas, focos), porque están bajo la oscuridad del CanvasModulate.
func _crear_polvo() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Polvo"
	p.amount = 140
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(Config.ANCHO / 2.0, Config.ALTO_MAPA / 2.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(Config.ANCHO / 2.0, Config.ALTO_MAPA / 2.0)
	p.direction = Vector2(1, -0.3)
	p.spread = 180.0
	p.gravity = Vector2(0, -2)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.95, 0.85, 0.0))
	grad.add_point(0.3, Color(1, 0.95, 0.85, 0.55))
	grad.add_point(0.7, Color(1, 0.95, 0.85, 0.45))
	grad.set_color(grad.get_point_count() - 1, Color(1, 0.95, 0.85, 0.0))
	p.color_ramp = grad
	return p


func _oclusor(r: Rect2) -> LightOccluder2D:
	var o := LightOccluder2D.new()
	var poli := OccluderPolygon2D.new()
	poli.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
	o.occluder = poli
	return o


# ---------------------------------------------------------------------- #
# Terminales de seguridad
# ---------------------------------------------------------------------- #
func _al_abrir_terminal() -> void:
	partida.jugador.hacer("interactuar", 0.0)
	audio.sonar("terminal")
	terminal_ui.abrir(terminal_abierta)
	var variante: String = terminal_abierta["desafio"].variante
	if not Ajustes.tutorial_visto(variante):
		mostrar_tutorial(variante)


func _al_cerrar_terminal() -> void:
	partida.jugador.accion = ""
	terminal_ui.cerrar()
	terminal_abierta = null


## Llamado por la interfaz de la terminal cuando la máquina se detiene.
func terminal_terminada(exito: bool) -> void:
	if terminal_abierta == null:
		return
	if exito:
		partida.resolver_terminal(terminal_abierta)
	else:
		partida.fallar_terminal(terminal_abierta)


func cerrar_terminal() -> void:
	disparar("esc")


# ---------------------------------------------------------------------- #
func _unhandled_input(e: InputEvent) -> void:
	if flujo.actual == Def.TERMINAL:
		return                              # la terminal maneja su teclado
	if e is InputEventKey and e.pressed and not e.echo:
		if flujo.actual == Def.MENU and e.keycode >= KEY_1 and e.keycode < KEY_1 + Niveles.cantidad():
			nivel = e.keycode - KEY_1        # elegir nivel desde el menú
			saltar_menu = true
			disparar("enter")
			return
		match e.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				disparar("enter")
			KEY_ESCAPE:
				disparar("esc")
			KEY_E:
				if flujo.actual == Def.JUGANDO:
					var t = partida.terminal_cercana()
					if t != null:
						terminal_abierta = t
						disparar("terminal")
			KEY_Q:
				if flujo.actual == Def.JUGANDO:
					lanzar_moneda_q()
			KEY_TAB:
				guardia_sel += 1
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if flujo.actual == Def.JUGANDO:
			partida.lanzar_moneda(e.position)


func _direccion() -> Vector2:
	var d := Vector2.ZERO
	if consola.bloquea_jugador():
		return d
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		d.x += 1
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		d.y += 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		d.y -= 1
	return d


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	tiempo += dt
	match flujo.actual:
		Def.MENU:
			partida.actualizar(dt)
		Def.JUGANDO:
			var libre := not consola.bloquea_jugador()
			var correr := libre and Input.is_physical_key_pressed(KEY_SHIFT)
			var agachar := libre and (Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL))
			partida.actualizar(dt, _direccion(), correr, agachar)
			if partida.resultado == "atrapado":
				sacudir(9.0)
				disparar("atrapado")
			elif partida.resultado == "escapo":
				var ultimo := nivel >= Niveles.cantidad() - 1
				disparar("final" if ultimo else "escapo")
	actualizar_visuales()
	_efectos_pantalla(dt)


## Sacudida de cámara y postproceso. Los valores salen de los estados de los
## autómatas: persecución → aberración, alarma (cámara en ALARMA o alerta
## global) → tinte rojo, sospecha/búsqueda → contraste, oculto → velo verde.
func _efectos_pantalla(dt: float) -> void:
	t_intro += dt
	var p := partida
	var metas := {"aberracion": 0.0, "alarma": 0.0, "oculto": 0.0, "tension": 0.0}
	if not p.demo and flujo.actual in [Def.JUGANDO, Def.TERMINAL, Def.DERROTA]:
		for g in p.guardias:
			match g.estado():
				Def.PERSECUCION:
					metas["aberracion"] = 1.0
					metas["tension"] = 1.0
				Def.SOSPECHA, Def.ALERTA, Def.BUSQUEDA:
					metas["tension"] = maxf(metas["tension"], 0.7)
		var en_alarma := p.seguridad.t_alerta > 0.0
		for c in p.camaras:
			en_alarma = en_alarma or c.estado() == Def.ALARMA
		metas["alarma"] = 1.0 if en_alarma else 0.0
		metas["oculto"] = 1.0 if p.jugador.oculto else 0.0
		if p.alarmas > _alarmas_vistas:
			_alarmas_vistas = p.alarmas
			sacudir(5.0)
	for k in metas:
		_post_vals[k] = move_toward(_post_vals[k], metas[k], dt * 2.5)
		post.set_shader_parameter(k, _post_vals[k])
	post.set_shader_parameter("tiempo", tiempo)
	post.set_shader_parameter("foco", p.jugador.pos / Vector2(Config.ANCHO, Config.ALTO))
	post.set_shader_parameter("vineta", 0.35 if p.demo else 0.55)
	# sacudida: mueve el mundo y la capa de acción juntos (el HUD queda fijo)
	sacudida = move_toward(sacudida, 0.0, dt * 18.0)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * sacudida if sacudida > 0.05 else Vector2.ZERO
	position = off
	capa_accion.offset = off


func sacudir(fuerza: float) -> void:
	sacudida = maxf(sacudida, fuerza)


## Sincroniza luces y efectos con el estado de la partida.
func actualizar_visuales() -> void:
	luz.visible = not partida.demo
	luz.position = partida.jugador.pos
	if partida.mapa.puertas_abiertas and not oclusores_puertas.is_empty():
		for o in oclusores_puertas:
			o.queue_free()
		oclusores_puertas.clear()
	for l in luces_laser:
		l.visible = partida.laser_activo
	var salida := nodo_nivel.get_node_or_null("Ambiente/LuzSalida")
	if salida:
		salida.color = Color(0.3, 1.0, 0.5) if partida.salida_abierta() else Color(1.0, 0.3, 0.25)
	audio.fijar_estado(GestorAudio.estado_desde(flujo.actual, partida))
	if flujo.actual == Def.JUGANDO:
		audio.pasos(get_process_delta_time(), partida)
	for ef in partida.efectos:
		accion.efecto(ef)
		audio.efecto(ef)
		_pista_por_efecto(ef["tipo"])
	partida.efectos.clear()


## Q lanza una moneda hacia el puntero; si el puntero está fuera del museo,
## la lanza hacia donde mira el ladrón.
func lanzar_moneda_q() -> void:
	var destino := get_global_mouse_position()
	var dentro := Rect2(0, 0, Config.ANCHO, Config.ALTO_MAPA).has_point(destino)
	if not dentro or destino.distance_to(partida.jugador.pos) < T:
		destino = partida.jugador.pos + Vector2.from_angle(partida.jugador.angulo) * Config.ALCANCE_MONEDA * T
	partida.lanzar_moneda(destino)


# ---------------------------------------------------------------------- #
# Tutoriales y pistas progresivas
# ---------------------------------------------------------------------- #
## Muestra el tutorial interactivo dentro del juego (pausa la partida).
func mostrar_tutorial(id: String) -> void:
	if consola.visible:
		consola.cerrar()
	panel_tutorial.abrir(id)
	capa_tutorial.visible = true
	get_tree().paused = true


func cerrar_tutorial() -> void:
	Ajustes.marcar_tutorial(panel_tutorial.id)
	capa_tutorial.visible = false
	get_tree().paused = false


const PISTAS := {
	"radar_aviso": "RADAR: atraviesa paredes. Escóndete en un arbusto antes del barrido.",
	"oculto": "Oculto: guardias y radar no te ven… salvo que te busquen muy de cerca.",
	"bloqueado": "No puedes esconderte mientras un guardia te está mirando.",
	"radar_limpio": "El radar analiza con dos máquinas de Turing. Míralas en F1 › Máquinas de Turing.",
	"radar_intrusion": "¡El radar te detectó! Todos los guardias van al punto donde te midió.",
	"agotado": "Sin energía: deja de correr unos segundos para que la batería se recargue."
}


func _pista_por_efecto(tipo: String) -> void:
	if PISTAS.has(tipo) and not partida.demo:
		pista(tipo, PISTAS[tipo])


## Pista breve en pantalla; cada una aparece una sola vez por sesión.
func pista(id: String, texto: String) -> void:
	if pistas_dadas.has(id):
		return
	pistas_dadas[id] = true
	ui.avisar(texto)
