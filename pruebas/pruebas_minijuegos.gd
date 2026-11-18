## Integración de las terminales, el visor y la música.
## godot --headless --path . -s res://pruebas/pruebas_minijuegos.gd
extends SceneTree

const G := ["R", "Z", "E", "A"]

var main
var total := 0
var fallos := 0
var _actual := ""


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	Ajustes.guardar_en_disco = false
	Minijuego.accesible = false
	main = load("res://escenas/main.tscn").instantiate()
	root.add_child(main)
	Ajustes.dificultad = Ajustes.Modo.FACIL
	main.set_process(false)
	var pruebas := [
		"robot_y_visor", "robot_rechazo_y_reintento", "robot_luz",
		"laser_detecta_y_conserva_refugio", "laser_apagado", "botin_reparto_y_descarte",
		"dificultad_desde_menu", "minijuegos_dificiles", "robustez_cerrar_a_medias", "persistencia_y_un_solo_minijuego", "alarma_sigue_en_panel",
		"musica_en_bucle", "musica_no_se_reinicia", "musica_cambio_tema", "musica_respeta_volumen",
	]
	for nombre in pruebas:
		_actual = nombre
		var antes := fallos
		call("test_" + nombre)
		total += 1
		print(("ok    " if fallos == antes else "FALLA ") + nombre)
	print("\n%d pruebas de minijuegos y música, %d fallas" % [total, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, msg := "") -> void:
	if not cond:
		fallos += 1
		printerr("  [%s] falló: %s" % [_actual, msg])


## Carga el nivel y abre su terminal `id` como lo haría el jugador.
func abrir(nivel: int, id: String) -> Minijuego:
	if main.flujo.actual == Def.TERMINAL:
		main.disparar("esc")
	main.cargar(nivel)
	main.flujo.actual = Def.JUGANDO
	for t in main.partida.terminales:
		if t["desafio"].id == id:
			main.terminal_abierta = t
	main.disparar("terminal")
	var mj: Minijuego = main.minijuegos[id]
	comprobar(mj.visible, "el minijuego %s se abre" % id)
	mj.comenzar()
	return mj



func clic(mj: Minijuego, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	mj._gui_input(e)


func tecla(mj: Minijuego, k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	mj._input(e)


func riel(mj: MJCerradura, i: int) -> void:
	clic(mj, Vector2(mj.posicion(i), MJCerradura.Y_RIEL))
	for j in 32:
		mj._actualizar(0.05)


func llenar_robot(mj: MJCerradura, incorrecto := false) -> void:
	Minijuego.accesible = true
	var n := mj.vitrina.length()
	var rotar := 0
	if incorrecto:
		for i in range(1, n):
			if mj.vitrina[i] != mj.vitrina[0]:
				rotar = i
				break
		# La entrada de prueba debe tener al menos dos tipos de joya.
		if rotar == 0:
			mj.vitrina[1] = G[(G.find(mj.vitrina[0]) + 1) % G.size()]
			rotar = 1
	for i in n:
		riel(mj, i)
		riel(mj, n + 1 + mj._hueco((i + rotar) % n))
	Minijuego.accesible = false


func verificar_visor(mj: Minijuego) -> void:
	var datos := mj.desafio.ultimo_intento.duplicate(true)
	tecla(mj, KEY_V)
	comprobar(main.terminal_ui.visible and main.terminal_ui.modo_visor, "V abre el visor")
	for i in datos["pasos"]:
		main.terminal_ui._un_paso()
	var m: MaquinaTuring = main.terminal_ui.desafio.maquina
	comprobar(m.historial == datos["transiciones"], "el visor reproduce las transiciones reales")
	main.terminal_ui._salir()
	comprobar(mj.desafio.ultimo_intento == datos and mj.visible, "el visor conserva el intento y el minijuego")


func test_robot_y_visor() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	llenar_robot(mj)
	mj.avanzar_lectura(12)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "EN CURSO", "el lector avanza en vivo")
	verificar_visor(mj)
	mj.avanzar_lectura(Desafio.MAX_PASOS)
	comprobar(mj.fase == "exito" and main.partida.mapa.puertas_abiertas, "la MT abre la vitrina")
	verificar_visor(mj)


func test_robot_rechazo_y_reintento() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	llenar_robot(mj, true)
	mj.avanzar_lectura(Desafio.MAX_PASOS)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "RECHAZA" and not mj.desafio.resuelto)
	comprobar(mj.fase == "juego" and "hueco" in mj.aviso)
	tecla(mj, KEY_SPACE)
	comprobar(mj.carga >= 0 and "_" in mj.clave, "se puede corregir el hueco que señaló el lector")


func test_robot_luz() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var n := mj.vitrina.length()
	riel(mj, 0)
	riel(mj, n + 1 + mj._hueco(0))
	riel(mj, 1)
	mj.reloj_luz = 4.6
	mj.x = MJCerradura.CENTRO
	mj._actualizar(0.01)
	comprobar(mj.carga == -1 and mj.clave.count("_") == n - 1, "la luz solo devuelve la gema en tránsito")
	comprobar(mj.desafio.intentos == 0, "el lector aún no comparó la clave")


func test_laser_detecta_y_conserva_refugio() -> void:
	var mj: MJLaser = abrir(1, "laser")
	tecla(mj, KEY_1 + G.find(mj.haces[0]))
	clic(mj, Vector2(700, 475))
	for j in 14:
		mj._actualizar(0.05)
	comprobar(mj.avanzados == 1 and mj.encendidos[0] == "1")
	verificar_visor(mj)
	mj.mascara = G[(G.find(mj.haces[1]) + 1) % G.size()]
	mj.mover(120)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "RECHAZA")
	comprobar(mj.avanzados == 1 and mj.x == mj.refugio(1) and mj.desafio.intentos == 1)
	for i in range(1, mj.haces.length()):
		tecla(mj, KEY_1 + G.find(mj.haces[i]))
		mj.mover(120)
	comprobar(mj.fase == "exito" and not main.partida.laser_activo)
	verificar_visor(mj)


func test_laser_apagado() -> void:
	var mj: MJLaser = abrir(1, "laser")
	mj.reloj_haz = 4.0
	mj.mascara = G[(G.find(mj.haces[0]) + 1) % G.size()]
	mj.mover(120)
	var m := mj.desafio.maquina as MTMultipista
	comprobar(mj.avanzados == 1 and m.cabezal == 1 and m.ultima["leido"][2] == "0")


func test_botin_reparto_y_descarte() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	var correcta := ProgramasTuring.destino_botin(mj.gema_actual())
	tecla(mj, KEY_LEFT if correcta != "<" else KEY_DOWN)
	comprobar(mj.indice == 0 and mj.desafio.ultimo_intento["resultado"] == "RECHAZA" and mj.desafio.intentos == 0)
	var descartadas := 0
	for i in mj.cantidad:
		var antes := Vector2i(mj.izquierda.length(), mj.derecha.length())
		var destino := ProgramasTuring.destino_botin(mj.gema_actual())
		if i == 2:
			mj.enviar(">" if destino == "<" else "<")
			var rechazado := mj.desafio.maquina as MTMulticinta
			comprobar(rechazado.estado == rechazado.rechaza and rechazado.cintas[0].cabezal == 2 * i + 1)
			comprobar(mj.indice == i and mj.desafio.intentos == 1, "se conserva el botín ya clasificado")
		if destino == "v":
			descartadas += 1
		tecla(mj, {"<": KEY_LEFT, ">": KEY_RIGHT, "v": KEY_DOWN}[destino])
		var m := mj.desafio.maquina as MTMulticinta
		var avance := Vector2i(m.cintas[1].cabezal, m.cintas[2].cabezal) - antes
		comprobar(avance == {"<": Vector2i(1, 0), ">": Vector2i(0, 1), "v": Vector2i.ZERO}[destino])
		mj._actualizar(0.3)
	comprobar(descartadas == 2 and mj.fase == "exito" and main.partida.mapa.puertas_abiertas)
	verificar_visor(mj)


func test_dificultad_desde_menu() -> void:
	main.cerrar_terminal()
	main.flujo.actual = Def.MENU
	var e := InputEventKey.new()
	e.keycode = KEY_RIGHT
	e.pressed = true
	main._unhandled_input(e)
	comprobar(Ajustes.dificultad == Ajustes.Modo.MEDIO)
	var clic_menu := InputEventMouseButton.new()
	clic_menu.button_index = MOUSE_BUTTON_LEFT
	clic_menu.position = main.ui.rect_dificultad(Ajustes.Modo.DIFICIL).get_center()
	clic_menu.pressed = true
	main._unhandled_input(clic_menu)
	comprobar(Ajustes.dificultad == Ajustes.Modo.DIFICIL)
	e.keycode = KEY_2
	main._unhandled_input(e)
	comprobar(main.nivel == 1 and main.partida.dificultad == Ajustes.Modo.DIFICIL)
	Ajustes.elegir_dificultad(Ajustes.Modo.FACIL)
	comprobar(main.partida.dificultad == Ajustes.Modo.DIFICIL, "el nivel en curso conserva sus reglas")


func test_minijuegos_dificiles() -> void:
	Ajustes.elegir_dificultad(Ajustes.Modo.DIFICIL)
	var robot := abrir(0, "cerradura") as MJCerradura
	comprobar(robot.vitrina.length() == 6 and robot.desafio.invertir)
	llenar_robot(robot)
	robot.avanzar_lectura(Desafio.MAX_PASOS)
	comprobar(robot.fase == "exito")
	var laser := abrir(1, "laser") as MJLaser
	comprobar(laser.haces.length() == 7)
	for i in laser.haces.length():
		laser.mascara = laser.haces[i]
		laser.cruzar()
	comprobar(laser.fase == "exito")
	var botin := abrir(2, "boveda") as MJBoveda
	comprobar(botin.cantidad == 12 and botin._limite() == 0.0, "la primera joya sigue siendo práctica")
	botin.enviar(ProgramasTuring.destino_botin(botin.gema_actual()))
	botin._actualizar(3.8)
	comprobar(botin.indice == 1 and "atascó" in botin.aviso)
	Minijuego.accesible = true
	comprobar(botin._limite() == 0.0)
	for i in range(1, botin.cantidad):
		botin.enviar(ProgramasTuring.destino_botin(botin.gema_actual()))
		botin._actualizar(0.3)
	comprobar(botin.fase == "exito")
	Minijuego.accesible = false
	Ajustes.elegir_dificultad(Ajustes.Modo.FACIL)


func test_robustez_cerrar_a_medias() -> void:
	var mj: MJLaser = abrir(1, "laser")
	mj.mascara = mj.haces[0]
	mj.mover(120)
	var t := mj.terminal
	main.cerrar_terminal()
	comprobar(main.flujo.actual == Def.JUGANDO and not mj.visible)
	main.terminal_abierta = t
	main.disparar("terminal")
	comprobar(mj.visible and mj.fase == "intro" and mj.avanzados == 0)
	main.cerrar_terminal()


func test_persistencia_y_un_solo_minijuego() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	llenar_robot(mj)
	mj.avanzar_lectura(Desafio.MAX_PASOS)
	var t := mj.terminal
	main.cerrar_terminal()
	main.terminal_abierta = t
	main.disparar("terminal")
	var abiertos := 0
	for m in main.minijuegos.values():
		abiertos += 1 if m.visible else 0
	comprobar(abiertos == 1 and mj.fase == "exito")
	main.cerrar_terminal()


func test_alarma_sigue_en_panel() -> void:
	main.cargar(2)
	main.flujo.actual = Def.JUGANDO
	for t in main.partida.terminales:
		if t["desafio"].id == "alarma":
			main.terminal_abierta = t
	Ajustes.tutoriales_vistos["estandar"] = true
	main.disparar("terminal")
	comprobar(main.terminal_ui.visible and not main.terminal_ui.modo_visor, "la central de alarmas usa el panel clásico")
	main.disparar("esc")


# ---------------------------------------------------------------------- #
# Música
# ---------------------------------------------------------------------- #
func test_musica_en_bucle() -> void:
	var a: GestorAudio = main.audio
	for i in GestorAudio.CAPAS.size():
		var st = a.sync.get_sync_stream(i)
		comprobar(st != null and st.loop, "la capa %d se repite" % i)
	comprobar(a.ambiente.stream.loop, "el ambiente se repite")
	for tema in GestorAudio.TEMAS:
		for capa in GestorAudio.CAPAS:
			var st := GestorAudio._cargar_en_bucle("res://assets/audio/musica_%s_%s.ogg" % [tema, capa])
			comprobar(st.loop, "%s %s con loop" % [tema, capa])
	comprobar(a.process_mode == Node.PROCESS_MODE_ALWAYS, "sigue sonando con el árbol en pausa")
	var reproductores := 0
	for h in a.get_children():
		if h is AudioStreamPlayer and h.stream == a.sync:
			reproductores += 1
	comprobar(reproductores == 1, "un único reproductor de música")


func test_musica_no_se_reinicia() -> void:
	var a: GestorAudio = main.audio
	main.cargar(0)
	for k in 30:
		a._process(0.1)
	var r: int = a.reinicios_musica
	var tema: String = a.tema_actual
	var mj: MJCerradura = abrir(0, "cerradura")
	llenar_robot(mj, true)
	mj.avanzar_lectura(Desafio.MAX_PASOS)
	mj.abrir_visor()
	main.terminal_ui._alternar_ejecucion()
	main.terminal_ui._un_paso()
	main.terminal_ui._salir()
	mj.alternar_pausa()
	mj.alternar_pausa()
	main.disparar("esc")
	main.cargar(0)                             # reintentar el nivel
	main.get_tree().paused = true
	a._process(0.1)
	main.get_tree().paused = false
	for k in 10:
		a._process(0.1)
	comprobar(a.reinicios_musica == r and a.tema_actual == tema,
			"entrar, fallar, ver la máquina, pausar y reintentar no reinicia la música (%d -> %d)" % [r, a.reinicios_musica])
	comprobar(a._nivel_tema > 0.99, "sin fundidos a silencio")


func test_musica_cambio_tema() -> void:
	var a: GestorAudio = main.audio
	main.cargar(0)
	for k in 20:
		a._process(0.1)
	var r: int = a.reinicios_musica
	main.cargar(1)
	main.cargar(1)
	comprobar(a.tema_actual == "n1" and a._tema_pendiente == "n2", "el tema nuevo espera al fundido")
	for k in 20:
		a._process(0.05)
	comprobar(a.tema_actual == "n2" and a.reinicios_musica == r + 1, "un solo cambio, sin duplicar")
	for k in 20:
		a._process(0.05)
	comprobar(a._nivel_tema > 0.99, "vuelve a volumen completo")
	main.cargar(0)
	for k in 30:
		a._process(0.05)


func test_musica_respeta_volumen() -> void:
	var a: GestorAudio = main.audio
	var antes := Ajustes.musica_volumen
	Ajustes.musica_volumen = 0.0
	for k in 5:
		a._process(0.1)
	var bus := AudioServer.get_bus_index("Musica")
	comprobar(AudioServer.get_bus_volume_db(bus) < -60.0, "volumen 0 silencia el bus de música")
	comprobar(a.reinicios_musica >= 1, "el gestor no intenta forzar la reproducción")
	Ajustes.musica_volumen = antes
	a._process(0.1)
	comprobar(AudioServer.get_bus_volume_db(bus) > -10.0, "al subirlo vuelve a sonar")
