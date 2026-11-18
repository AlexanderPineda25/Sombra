## Pruebas de los tres minijuegos de máquinas de Turing y de la continuidad
## de la música (matriz mínima de la especificación).
##
##   godot --headless --path . -s res://pruebas/pruebas_minijuegos.gd
##
## Los minijuegos se conducen llamando a sus acciones (fijar disco, moverse,
## frenar rotor…) con tiempos controlados: así los casos son reproducibles.
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
	Ajustes.dificultad = 1.0
	Minijuego.accesible = false
	main = load("res://escenas/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var pruebas := [
		"mt1_valido", "mt1_invalido_y_reintento", "mt1_timing_es_fisico", "mt1_visor_reproduce",
		"mt1_ejemplos_aceptados", "mt1_dificultad",
		"mt2_valido", "mt2_mascara_erronea", "mt2_mal_timing", "mt2_una_cinta_tres_pistas", "mt2_visor_en_curso",
		"mt3_valido", "mt3_b_erroneo", "mt3_inversion_k", "mt3_cabezales_independientes", "mt3_timing_es_fisico",
		"robustez_cerrar_a_medias", "persistencia_y_un_solo_minijuego", "alarma_sigue_en_panel",
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


func terminal(mj: Minijuego) -> Dictionary:
	return mj.terminal


# ---------------------------------------------------------------------- #
# MT1 · Cerradura de la vitrina
# ---------------------------------------------------------------------- #
func _clave(mj: MJCerradura) -> String:
	return mj.desafio.solucion_filas[0].split("#")[1]


func _fijar_bien(mj: MJCerradura, i: int, g: String) -> bool:
	mj.discos[i]["patina"] = 0.0
	mj.discos[i]["ang"] = float(G.find(g)) + 0.05           # dentro de la tolerancia
	return mj.fijar(i)


func test_mt1_valido() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var clave := _clave(mj)
	for i in clave.length():
		comprobar(_fijar_bien(mj, i, clave[i]), "fija el disco %d" % i)
	comprobar(mj.fase == "verificando", "al fijar todos se envía a la MT")
	mj._actualizar(5.0)
	var it: Dictionary = mj.desafio.ultimo_intento
	comprobar(it["resultado"] == "ACEPTA", "la MT estándar acepta (%s)" % it["resultado"])
	comprobar(mj.desafio.maquina is MTEstandar, "es la máquina estándar de una cinta")
	comprobar(it["filas"][0] == mj.vitrina + "#" + clave, "entrada bien formada vitrina#clave")
	comprobar(mj.desafio.resuelto and main.partida.mapa.puertas_abiertas, "la vitrina/puerta se abre")
	comprobar(mj.fase == "exito")


func test_mt1_invalido_y_reintento() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var clave := _clave(mj)
	var mala: String = G[(G.find(clave[1]) + 1) % 4]
	for i in clave.length():
		_fijar_bien(mj, i, mala if i == 1 else clave[i])
	mj._actualizar(5.0)
	var it: Dictionary = mj.desafio.ultimo_intento
	comprobar(it["resultado"] == "RECHAZA", "la MT rechaza la clave con un disco mal")
	comprobar(not mj.desafio.resuelto and not main.partida.mapa.puertas_abiertas)
	comprobar(terminal(mj)["desafio"].intentos == 1, "cuenta como intento lógico")
	comprobar(not mj.discos[1]["fijo"] and mj.discos[1]["error"] > 0.0,
			"se marca el disco 2, el que señala la posición del cabezal")
	comprobar(mj.discos[0]["fijo"] and mj.discos[2]["fijo"], "los demás discos siguen fijados")
	comprobar(mj.fase == "juego", "se permite reintentar")
	_fijar_bien(mj, 1, clave[1])
	mj._actualizar(5.0)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "ACEPTA" and mj.desafio.resuelto, "el reintento abre")


func test_mt1_timing_es_fisico() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var clave := _clave(mj)
	mj.discos[0]["ang"] = float(G.find(clave[0])) + 0.49     # entre dos gemas
	comprobar(not mj.fijar(0), "fuera de la ventana no se fija")
	comprobar(mj.sobrecarga == 0, "en el ensayo el desliz no cuenta")
	_fijar_bien(mj, 0, clave[0])                              # termina el ensayo
	var regs_antes: int = main.partida.seguridad.contador.get("seguridad", 0)
	for k in 3:
		mj.discos[1]["patina"] = 0.0
		mj.discos[1]["ang"] = 1.5
		mj.fijar(1)
	comprobar(mj.fallos_fisicos == 1, "tres deslices = un fallo físico (ruido)")
	comprobar(main.partida.seguridad.contador.get("seguridad", 0) == regs_antes + 1, "se registra como físico")
	comprobar(terminal(mj)["desafio"].intentos == 0, "un fallo físico NO es un rechazo de la MT")
	comprobar(mj.desafio.ultimo_intento.is_empty(), "la MT no se ejecutó")
	mj.reloj = 0.01
	mj._actualizar(0.05)
	comprobar(mj.fallos_fisicos == 2 and is_equal_approx(mj.reloj, mj.reloj_total), "reloj agotado = fallo físico")
	Minijuego.accesible = true
	var r := mj.reloj
	mj._actualizar(1.0)
	comprobar(is_equal_approx(mj.reloj, r), "modo accesible: sin reloj")
	Minijuego.accesible = false


func test_mt1_visor_reproduce() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var clave := _clave(mj)
	for i in clave.length():
		_fijar_bien(mj, i, G[(G.find(clave[i]) + 2) % 4] if i == clave.length() - 1 else clave[i])
	mj._actualizar(5.0)
	var it: Dictionary = mj.desafio.ultimo_intento
	var intentos: int = mj.desafio.intentos
	mj.abrir_visor()
	var tu = main.terminal_ui
	comprobar(tu.visible and tu.modo_visor and mj.visible, "el visor se abre encima del minijuego")
	var reproducidas := []
	for k in 6000:
		if tu.desafio.maquina.detenida():
			break
		tu._avanzar()
		reproducidas.append(tu.desafio.maquina.ultima)
	comprobar(reproducidas.size() == it["pasos"], "mismo número de pasos (%d / %d)" % [reproducidas.size(), it["pasos"]])
	var iguales := true
	for k in mini(reproducidas.size(), it["transiciones"].size()):
		iguales = iguales and reproducidas[k] == it["transiciones"][k]
	comprobar(iguales, "el visor muestra las MISMAS transiciones que ejecutó el minijuego")
	comprobar(tu.desafio.maquina.resultado() == it["resultado"])
	tu._salir()
	comprobar(not tu.visible and mj.visible, "cerrar el visor vuelve al minijuego")
	comprobar(mj.desafio.ultimo_intento == it and mj.desafio.intentos == intentos and not mj.desafio.resuelto,
			"abrir/cerrar el visor no cambia el desafío")
	comprobar(main.flujo.actual == Def.TERMINAL)


func test_mt1_ejemplos_aceptados() -> void:
	for semilla in 30:
		var d := Desafio.crear("cerradura", semilla)
		comprobar(d.ejemplos.size() == 2, "dos ejemplos (semilla %d)" % semilla)
		var m := ProgramasTuring.verificador_clave(d.regla, d.invertir)
		for e in d.ejemplos:
			m.cargar(e[0] + "#" + e[1])
			comprobar(m.ejecutar() == "ACEPTA", "el ejemplo %s#%s lo acepta la MT" % [e[0], e[1]])


func test_mt1_dificultad() -> void:
	for par in [[0.6, 3], [1.0, 4], [1.4, 5]]:
		Ajustes.dificultad = par[0]
		var d := Desafio.crear("cerradura", 7)
		comprobar(d.solucion_filas[0].split("#")[0].length() == par[1], "dificultad %s -> %d gemas" % par)
		var m := ProgramasTuring.verificador_clave(d.regla, d.invertir)
		m.cargar(d.solucion_filas[0])
		comprobar(m.ejecutar() == "ACEPTA", "la solución generada es aceptada")
	Ajustes.dificultad = 1.0


# ---------------------------------------------------------------------- #
# MT2 · Rejilla láser
# ---------------------------------------------------------------------- #
## Espera (adelantando el reloj de los haces) a una ventana segura y cruza el haz j.
func _cruzar(mj: MJLaser, j: int, mascara: String) -> void:
	mj.poner_mascara(mascara)
	mj.x = mj.gate_x(j) - 40.0
	for k in 2000:
		if not mj.haz_encendido(j) and mj.hasta_cambio(j) > 0.6:
			break
		mj.t_laser += 0.01
	for k in 40:
		mj.mover(3.0)
		if mj.activa() != j or mj.x < mj.gate_x(j) - 45.0:
			break


func test_mt2_valido() -> void:
	var mj: MJLaser = abrir(1, "laser")
	var sol: String = mj.desafio.solucion_filas[1]
	_cruzar(mj, 0, "R")
	comprobar(mj.practica_hecha and not mj.ensayo, "se supera el haz de ensayo")
	for c in mj.n:
		_cruzar(mj, c + 1, sol[c])
		comprobar(mj.maquina().cabezal == c + 1, "columna %d autorizada, el cabezal avanza" % c)
		comprobar(mj.x > mj.gate_x(c + 1) and (c + 2 > mj.n or mj.x < mj.gate_x(c + 2)),
				"el ladrón está en el refugio de la columna del cabezal")
	for k in 400:
		mj.mover(4.0)
		if mj.fase != "juego":
			break
	comprobar(mj.fase == "verificando", "al llegar a la salida la máquina termina su programa")
	mj._actualizar(2.0)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "ACEPTA", "la multipista acepta")
	comprobar(mj.desafio.resuelto and not main.partida.laser_activo, "la rejilla del museo se apaga")
	comprobar(mj.fallos_logicos == 0 and mj.fallos_fisicos == 0)


func test_mt2_mascara_erronea() -> void:
	var mj: MJLaser = abrir(1, "laser")
	var sol: String = mj.desafio.solucion_filas[1]
	_cruzar(mj, 0, "R")
	_cruzar(mj, 1, sol[0])
	var mala: String = G[(G.find(sol[1]) + 2) % 4]
	_cruzar(mj, 2, mala)
	comprobar(mj.desafio.ultimo_intento["resultado"] == "RECHAZA", "rechazo lógico de la MT")
	comprobar(terminal(mj)["desafio"].intentos == 1 and mj.fallos_logicos == 1 and mj.fallos_fisicos == 0,
			"cuenta como fallo LÓGICO, no físico")
	comprobar(mj.maquina().cabezal == 1 and mj.maquina().estado == "q0", "checkpoint: la máquina vuelve a la columna 1")
	comprobar(mj.x < mj.gate_x(2) and mj.x > mj.gate_x(1), "el ladrón vuelve al refugio de esa columna")
	_cruzar(mj, 2, sol[1])
	comprobar(mj.maquina().cabezal == 2, "tras corregir la máscara se avanza")


func test_mt2_mal_timing() -> void:
	var mj: MJLaser = abrir(1, "laser")
	_cruzar(mj, 0, "R")
	var pasos_antes: int = mj.desafio.ultimo_intento["pasos"]
	mj.x = mj.gate_x(1) - 40.0
	for k in 2000:
		if mj.haz_encendido(1) and mj.hasta_cambio(1) > 0.6:
			break
		mj.t_laser += 0.01
	for k in 20:
		mj.mover(3.0)
		if mj.fallos_fisicos > 0:
			break
	comprobar(mj.fallos_fisicos == 1, "cruzar con el haz encendido es un fallo físico")
	comprobar(terminal(mj)["desafio"].intentos == 0 and mj.fallos_logicos == 0, "no es un rechazo de la MT")
	comprobar(mj.maquina().cabezal == 0 and mj.desafio.ultimo_intento["pasos"] == pasos_antes,
			"la máquina no leyó nada")
	comprobar(mj.x < mj.gate_x(1), "vuelve al refugio")


func test_mt2_una_cinta_tres_pistas() -> void:
	var mj: MJLaser = abrir(1, "laser")
	var mq := mj.maquina()
	comprobar(mq is MTMultipista and mq.k == 3, "una cinta de 3 pistas")
	comprobar(typeof(mq.cabezal) == TYPE_INT, "un único cabezal")
	var sol: String = mj.desafio.solucion_filas[1]
	_cruzar(mj, 0, "R")
	_cruzar(mj, 1, sol[0])
	var t: Dictionary = mj.desafio.ultimo_intento["transiciones"][-1]
	comprobar(t["leido"].size() == 3 and typeof(t["mov"]) == TYPE_STRING, "lee una tupla y hace UN movimiento")


func test_mt2_visor_en_curso() -> void:
	var mj: MJLaser = abrir(1, "laser")
	var sol: String = mj.desafio.solucion_filas[1]
	_cruzar(mj, 0, "R")
	_cruzar(mj, 1, sol[0])
	_cruzar(mj, 2, sol[1])
	var it: Dictionary = mj.desafio.ultimo_intento
	comprobar(it["resultado"] == "EN CURSO" and it["pasos"] == 2, "registro en curso de 2 pasos")
	mj.abrir_visor()
	var tu = main.terminal_ui
	for k in 50:
		tu._avanzar()
	comprobar(tu.desafio.maquina.pasos == 2, "el visor se detiene donde va la máquina del juego")
	comprobar(tu.desafio.maquina.historial == it["transiciones"], "mismas transiciones reales")
	comprobar(tu.desafio.maquina.cabezal == mj.maquina().cabezal, "mismo cabezal")
	tu._salir()
	comprobar(mj.maquina().cabezal == 2 and mj.fase == "juego", "el minijuego sigue igual")


# ---------------------------------------------------------------------- #
# MT3 · Bóveda
# ---------------------------------------------------------------------- #
func test_mt3_valido() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	var sol: String = mj.desafio.solucion_filas[1]
	var mq := mj.maquina()
	comprobar(mq is MTMulticinta and mq.k == 3, "tres cintas")
	comprobar(mq.cintas[2].cabezal == mj.n - 1 and mq.cintas[0].cabezal == 0,
			"fase q0 real: el cabezal 3 fue al final y los otros esperan")
	for i in mj.n:
		comprobar(mj.confirmar_ronda(sol[i]), "ronda %d" % i)
		if i < mj.n - 1:
			mq = mj.maquina()
			comprobar(mq.cintas[0].cabezal == i + 1 and mq.cintas[1].cabezal == i + 1, "A y B avanzan")
			comprobar(mq.cintas[2].cabezal == mj.n - 2 - i, "K retrocede (lee al revés)")
	comprobar(mj.desafio.ultimo_intento["resultado"] == "ACEPTA", "la multicinta acepta")
	comprobar(mj.desafio.resuelto and main.partida.mapa.puertas_abiertas, "la bóveda se abre")


func test_mt3_b_erroneo() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	var sol: String = mj.desafio.solucion_filas[1]
	mj.confirmar_ronda(sol[0])
	comprobar(not mj.confirmar_ronda(G[(G.find(sol[1]) + 1) % 4]), "desplazamiento de B erróneo")
	comprobar(mj.desafio.ultimo_intento["resultado"] == "RECHAZA", "rechazo de la MT")
	comprobar(mj.ronda == 1 and mj.b_conf[1] == "" and mj.error_b > 0.0, "se marca el rotor y se repite la ronda")
	comprobar(terminal(mj)["desafio"].intentos == 1 and mj.fallos_fisicos == 0)
	comprobar(mj.confirmar_ronda(sol[1]) and mj.ronda == 2, "tras corregir se avanza")


func test_mt3_inversion_k() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	var sol: String = mj.desafio.solucion_filas[1]
	var k: String = mj.k
	var r := mj.desafio.ejecutar_intento([mj.a, sol, k])
	comprobar(r["resultado"] == "ACEPTA", "con K al revés acepta")
	if k != k.reverse():
		r = mj.desafio.ejecutar_intento([mj.a, sol, k.reverse()])
		comprobar(r["resultado"] == "RECHAZA", "si K no está invertida, la MT rechaza")


func test_mt3_cabezales_independientes() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	var sol: String = mj.desafio.solucion_filas[1]
	for i in mj.n:
		mj.confirmar_ronda(sol[i])
	var movs := {}
	for t in mj.desafio.ultimo_intento["transiciones"]:
		movs[",".join(t["mov"])] = true
	comprobar(movs.has("S,S,R"), "solo el cabezal 3 avanza en q0")
	comprobar(movs.has("R,R,L"), "1 y 2 a la derecha mientras 3 retrocede")


func test_mt3_timing_es_fisico() -> void:
	var mj: MJBoveda = abrir(2, "boveda")
	mj.anim = []
	mj.ang_b = 1.5
	comprobar(not mj.frenar() and mj.atasco > 0.0, "frenar entre dos gemas atasca el rotor")
	mj.atasco = 0.0
	mj.ang_b = 2.02
	comprobar(mj.frenar() and mj.gema_b == "E", "frena dentro de la tolerancia")
	mj.t_ronda = mj.periodo_k() * 0.8                 # fuera de la ventana de sincronía
	comprobar(not mj.confirmar(), "confirmar sin sincronía no envía nada a la MT")
	comprobar(mj.ronda == 0 and terminal(mj)["desafio"].intentos == 0, "no es un intento lógico")


# ---------------------------------------------------------------------- #
# Robustez, persistencia, regresión
# ---------------------------------------------------------------------- #
func test_robustez_cerrar_a_medias() -> void:
	var mj: MJLaser = abrir(1, "laser")
	var sol: String = mj.desafio.solucion_filas[1]
	_cruzar(mj, 0, "R")
	_cruzar(mj, 1, sol[0])
	main.cerrar_terminal()
	comprobar(main.flujo.actual == Def.JUGANDO and not mj.visible, "se cierra sin error")
	comprobar(main.terminal_abierta == null)
	main.terminal_abierta = mj.terminal
	main.disparar("terminal")
	comprobar(mj.visible and mj.fase == "intro" and mj.maquina().cabezal == 0, "al volver empieza limpio")
	main.disparar("esc")


func test_persistencia_y_un_solo_minijuego() -> void:
	var mj: MJCerradura = abrir(0, "cerradura")
	var monedas: int = main.partida.jugador.monedas
	var clave := _clave(mj)
	for i in clave.length():
		_fijar_bien(mj, i, clave[i])
	mj._actualizar(5.0)
	var abiertos := 0
	for m in main.minijuegos.values():
		abiertos += 1 if m.visible else 0
	comprobar(abiertos == 1, "un solo minijuego visible")
	main.cerrar_terminal()
	comprobar(main.partida.jugador.monedas == monedas, "no se pierde progreso no relacionado")
	main.terminal_abierta = mj.terminal
	main.disparar("terminal")
	comprobar(mj.fase == "exito" and mj.desafio.resuelto, "reabrir una terminal resuelta muestra el éxito")
	main.disparar("esc")
	comprobar(main.capa_tutorial.visible == false and not main.get_tree().paused, "no se pausa el juego")


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
	var clave := _clave(mj)
	for i in clave.length():
		_fijar_bien(mj, i, G[(G.find(clave[i]) + 1) % 4])
	mj._actualizar(5.0)                        # fallo
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
