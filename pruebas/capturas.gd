## Genera capturas de pantalla del juego en docs/capturas.
##
##   godot --path . res://pruebas/capturas.tscn
## (necesita ventana o un servidor X virtual; no funciona con --headless)
extends Node

const MainEscena := preload("res://escenas/main.tscn")
const DT := 1.0 / 60

var juego
var carpeta := ""


func _ready() -> void:
	Ajustes.guardar_en_disco = false
	for id in ["estandar", "multicinta", "multipista"]:
		Ajustes.tutoriales_vistos[id] = true
	carpeta = ProjectSettings.globalize_path("res://docs/capturas")
	DirAccess.make_dir_recursive_absolute(carpeta)
	juego = MainEscena.instantiate()
	add_child(juego)
	juego.set_process(false)           # el guion controla el tiempo
	await _guion()
	get_tree().quit()


func avanzar(seg: float, dir := Vector2.ZERO, agachar := false) -> void:
	for i in int(seg * 60):
		juego.tiempo += DT
		juego.partida.actualizar(DT, dir, false, agachar)


func mover_a(t: Vector2i, agachar := false) -> void:
	var p: Partida = juego.partida
	var camino = p.mapa.bfs(p.jugador.tile(), t)
	if camino == null:
		return
	for paso in camino:
		var c := Mapa.centro(paso)
		for k in 200:
			var dif := c - p.jugador.pos
			if absf(dif.x) < 2 and absf(dif.y) < 2:
				break
			juego.tiempo += DT
			p.actualizar(DT, Vector2(signf(dif.x) if absf(dif.x) > 1 else 0.0,
					signf(dif.y) if absf(dif.y) > 1 else 0.0), false, agachar)
			if p.resultado != "":
				p.resultado = ""


func guardar(nombre: String, frames := 4, con_tarjeta := false) -> void:
	var t_intro: float = juego.t_intro
	juego._efectos_pantalla(1.0)           # postproceso al valor de los AFD
	juego.t_intro = t_intro if con_tarjeta else 99.0
	juego.actualizar_visuales()
	for i in frames:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(carpeta.path_join(nombre))
	print("ok ", nombre)


func guardar_ventana(nombre: String, frames := 6) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
	var img: Image = juego.consola.get_texture().get_image()
	img.save_png(carpeta.path_join(nombre))
	print("ok ", nombre)


## Hace correr el radar del nivel hasta que llegue a `estado`.
func radar_hasta(estado: String, extra := 0.0) -> void:
	var r: Radar = juego.partida.radares[0]
	for i in 60 * 40:
		if r.estado() == estado:
			break
		avanzar(DT)
	avanzar(extra)


func abrir_terminal(i: int) -> void:
	var t: Dictionary = juego.partida.terminales[i]
	juego.partida.jugador.pos = Mapa.centro(t["pos"])
	juego.terminal_abierta = t
	juego.disparar("terminal")


func pasos(n: int) -> void:
	for i in n:
		juego.terminal_ui._un_paso()
	juego.terminal_ui._sincronizar_cabezales(true)


func _guion() -> void:
	avanzar(3)
	await guardar("01_menu.png")

	# ---- nivel 1: máquina estándar (incrementador) --------------------- #
	juego.disparar("enter")
	avanzar(1.0)
	mover_a(Vector2i(15, 14))
	avanzar(0.3)
	await guardar("02_nivel1_terminal.png")

	abrir_terminal(0)
	var d: Desafio = juego.partida.terminales[0]["desafio"]
	for i in 4:
		d.poner(0, 5 + i, d.solucion_filas[0][5 + i])
	juego.terminal_ui._reiniciar()
	pasos(13)
	await guardar("03_turing_estandar.png", 8)
	pasos(300)
	await guardar("04_turing_estandar_exito.png", 8)
	juego.cerrar_terminal()
	avanzar(0.5)
	mover_a(Vector2i(13, 12))
	await guardar("05_puerta_abierta.png")

	# guardia que sospecha
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	var g: Guardia = juego.partida.guardias[0]
	avanzar(0.6)
	juego.partida.jugador.pos = g.pos + Vector2.from_angle(g.angulo) * Config.TILE * 5.2
	for i in 90:
		juego.tiempo += DT
		juego.partida.actualizar(DT)
		if g.estado() == Def.SOSPECHA:
			break
	avanzar(0.3)
	await guardar("06_sospecha.png")

	# ---- nivel 2: máquina multipista (rejilla láser) -------------------- #
	juego.cargar(1)
	juego.flujo.actual = Def.JUGANDO
	avanzar(1.0)
	juego.partida.jugador.pos = Mapa.centro(Vector2i(22, 4))
	avanzar(0.4)
	await guardar("07_nivel2_laser.png")
	abrir_terminal(0)
	d = juego.partida.terminales[0]["desafio"]
	for i in 5:
		d.poner(1, i, d.solucion_filas[1][i])
	juego.terminal_ui._reiniciar()
	pasos(3)
	await guardar("08_turing_multipista.png", 8)
	juego.cerrar_terminal()

	# intento fallido en la multipista
	juego.cargar(1)
	juego.flujo.actual = Def.JUGANDO
	abrir_terminal(0)
	d = juego.partida.terminales[0]["desafio"]
	for i in 5:
		d.poner(1, i, d.solucion_filas[1][i])
	d.poner(1, 3, ProgramasTuring.siguiente_gema(d.solucion_filas[1][3]))   # un error
	juego.terminal_ui._reiniciar()
	pasos(12)
	await guardar("09_turing_denegado.png", 8)
	juego.cerrar_terminal()

	# ---- nivel 3: máquina multicinta (bóveda) ---------------------------- #
	juego.cargar(2)
	juego.flujo.actual = Def.JUGANDO
	avanzar(2.0)
	await guardar("10_nivel3.png")
	abrir_terminal(0)
	d = juego.partida.terminales[0]["desafio"]
	for i in 4:
		d.poner(1, i, d.solucion_filas[1][i])
	juego.terminal_ui._reiniciar()
	pasos(6)
	await guardar("11_turing_multicinta.png", 8)
	pasos(20)
	await guardar("12_turing_multicinta_exito.png", 8)
	juego.cerrar_terminal()
	abrir_terminal(1)
	d = juego.partida.terminales[1]["desafio"]
	for i in 6:
		d.poner(0, i, d.solucion_filas[0][i])
	juego.terminal_ui._reiniciar()
	pasos(9)
	await guardar("13_turing_anbn.png", 8)
	pasos(60)
	juego.cerrar_terminal()
	avanzar(1.0)
	await guardar("14_nivel3_camaras_apagadas.png")

	# ---- pantallas finales ---------------------------------------------- #
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	juego.disparar("atrapado")
	await guardar("15_derrota.png")
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	juego.partida.tiempo = 74.0
	juego.partida.recogidas = juego.partida.total_joyas
	juego.partida.monedas_usadas = 1
	juego.disparar("escapo")
	await guardar("16_victoria.png")

	# ---- radar, arbustos y consola F1 (nivel 1) ------------------------- #
	juego.flujo.actual = Def.MENU
	juego.disparar("enter")
	var p: Partida = juego.partida
	var r: Radar = p.radares[0]
	p.jugador.pos = Mapa.centro(Vector2i(8, 11))
	r.t_fase = r.intervalo() - 0.3
	radar_hasta(Def.AVISO, 1.0)
	p.jugador.pos = Mapa.centro(Vector2i(8, 11))
	await guardar("17_radar_aviso.png")
	radar_hasta(Def.BARRIDO, Ajustes.radar_barrido * 0.45)
	await guardar("18_radar_barrido.png")
	radar_hasta(Def.REPOSO, 0.4)
	await guardar("19_radar_intrusion.png")
	# escondido en el arbusto durante el siguiente escaneo
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	p = juego.partida
	r = p.radares[0]
	p.jugador.pos = Mapa.centro(Vector2i(3, 9))
	avanzar(0.2)
	r.t_fase = r.intervalo()
	radar_hasta(Def.BARRIDO, Ajustes.radar_barrido * 0.7)
	await guardar("20_oculto_en_arbusto.png")
	radar_hasta(Def.REPOSO, 0.3)

	# energía: corre hasta gastar parte de la batería
	for i in 90:
		juego.tiempo += DT
		p.actualizar(DT, Vector2(1, 0) if (i / 30) % 2 == 0 else Vector2(-1, 0), true)
	await guardar("29_energia.png")

	# terminal estándar resuelta para que la consola la muestre
	abrir_terminal(0)
	var d0: Desafio = p.terminales[0]["desafio"]
	for i in 4:
		d0.poner(0, 5 + i, d0.solucion_filas[0][5 + i])
	juego.terminal_ui._reiniciar()
	pasos(300)
	juego.cerrar_terminal()
	p.guardias[0].evento("r")
	avanzar(0.5)
	juego.consola.size = Vector2i(1080, 720)
	juego.consola.abrir(0)
	await guardar_ventana("21_consola_guardias.png", 10)
	juego.consola.abrir(1)
	await guardar_ventana("22_consola_turing.png")
	juego.consola.abrir(2)
	await guardar_ventana("23_consola_radar.png")
	juego.consola.abrir(3)
	await guardar_ventana("24_consola_registro.png")
	juego.consola.abrir_tutorial("multipista")
	juego.consola.tutorial.ir(3)
	await guardar_ventana("25_consola_tutorial_comparacion.png")
	juego.consola.abrir(5)
	await guardar_ventana("26_consola_ajustes.png")
	juego.consola.cerrar()

	juego.consola.abrir(6)
	await guardar_ventana("31_consola_lenguaje.png", 12)
	juego.consola.cerrar()

	# tarjeta de inicio de nivel
	juego.cargar(1)
	juego.flujo.actual = Def.JUGANDO
	juego.t_intro = 1.3
	await guardar("30_tarjeta_nivel.png", 4, true)

	# persecución: aberración cromática y contraste
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	p = juego.partida
	var gp: Guardia = p.guardias[0]
	avanzar(0.5)
	p.jugador.pos = gp.pos + Vector2.from_angle(gp.angulo) * Config.TILE * 3.0
	for i in 120:
		juego.tiempo += DT
		p.actualizar(DT)
		if gp.estado() == Def.PERSECUCION:
			break
	avanzar(0.25)
	await guardar("32_persecucion.png")

	# pausa programada en el lenguaje SOMBRA
	juego.cargar(2)
	juego.flujo.actual = Def.JUGANDO
	p = juego.partida
	p.jugador.pos = Mapa.centro(Vector2i(1, 1))
	for i in 60 * 30:
		juego.tiempo += DT
		p.actualizar(DT)
		var alguno := false
		for gg in p.guardias:
			alguno = alguno or (gg.en_pausa() and gg.pausa_restante < gg.pausa_actual["segundos"] * 0.6)
		if alguno:
			break
	await guardar("33_pausa_programada.png")

	# alerta global: tinte de alarma
	p.seguridad.t_alerta = 5.0
	await guardar("34_alarma.png")

	# tutorial dentro del juego (primera terminal)
	Ajustes.tutoriales_vistos.erase("estandar")
	juego.cargar(0)
	juego.flujo.actual = Def.JUGANDO
	abrir_terminal(0)
	juego.panel_tutorial._paso()
	juego.panel_tutorial._paso()
	juego.panel_tutorial._paso()
	await guardar("27_tutorial_estandar.png", 8)
	juego.panel_tutorial.ir(1)
	juego.panel_tutorial.responder(0)
	await guardar("28_tutorial_ejercicio.png", 8)
	juego.cerrar_tutorial()
