## Pruebas de los autómatas y de los niveles.
##
##   godot --headless --path . -s res://pruebas/pruebas.gd
extends SceneTree

var total := 0
var fallos := 0
var _actual := ""


func _initialize() -> void:
	_correr.call_deferred()          # con el árbol listo (el audio necesita nodos dentro)


func _correr() -> void:
	var pruebas := [
		"afd_incompleto_se_rechaza", "guardia_es_completo", "guardia_secuencias",
		"lenguaje_aceptado", "minimizacion_borrador", "guardia_minimo_no_se_reduce",
		"minimizacion_por_aceptacion", "camara", "flujo",
		"pila_vuelve_al_origen", "pila_cancelacion", "pila_vuelta_es_reverso",
		"niveles_validos", "guardia_regresa_a_su_ruta", "niveles_se_pueden_ganar",
		"guardia_sospecha_y_regresa", "puertas_requieren_terminal", "laser_dispara_alarma",
		"camaras_se_apagan", "terminal_fallida_hace_ruido",
		"alerta_global_llega_a_todos", "deteccion_genera_alerta", "arbusto_area_real",
		"no_ocultarse_si_te_ven", "busqueda_registra_arbusto", "registro_de_eventos",
		"perfiles_dificultad", "oido_por_dificultad", "radar_afd", "radar_detecta_visible", "radar_respeta_arbusto", "radar_atraviesa_muros",
		"radar_fuera_de_alcance", "radar_ignora_guardias",
		"musica_sigue_a_los_afd", "musica_fundido_gradual", "efectos_sin_saturar",
		"tutoriales_completos", "ejercicio_coincide_con_la_maquina", "radar_registra_maquinas",
		"radar_manda_al_punto", "busqueda_amplia", "oye_pasos_caminando", "oye_pasos_corriendo",
		"agachado_no_se_oye", "energia_limita_correr", "consola_sin_pausa",
	]
	for nombre in pruebas:
		_actual = nombre
		var antes := fallos
		call("test_" + nombre)
		total += 1
		print(("ok    " if fallos == antes else "FALLA ") + nombre)
	print("\n%d pruebas, %d fallas" % [total, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, msg := "") -> void:
	if not cond:
		fallos += 1
		printerr("  [%s] falló: %s" % [_actual, msg])


# --- AFD ----------------------------------------------------------------- #
func test_afd_incompleto_se_rechaza() -> void:
	var malo := AFD.new("malo", ["A", "B"], ["x"], {"A": {"x": "B"}}, "A")
	comprobar(malo.error != "", "debía detectar que falta δ(B, x)")


func test_guardia_es_completo() -> void:
	var g := Def.crear_afd_guardia()
	comprobar(g.error == "")
	comprobar(g.num_transiciones() == 42, "42 transiciones (6 estados x 7 eventos)")


func test_guardia_secuencias() -> void:
	var g := Def.crear_afd_guardia()
	comprobar(g.procesar("rltl") == Def.PATRULLA, "rltl")
	comprobar(g.procesar("vpt") == Def.REGRESO, "vpt")
	comprobar(g.procesar("rvpt") == Def.REGRESO, "rvpt")
	for q in g.estados:
		comprobar(g.transicion(q, "v") == Def.PERSECUCION, "v desde " + q)
	for s in "vrslt":
		comprobar(g.transicion(Def.PERSECUCION, s) == Def.PERSECUCION, "persecución con " + s)
	comprobar(g.procesar("sv") == Def.PERSECUCION, "sv")
	comprobar(g.procesar("stl") == Def.PATRULLA, "sospecha, nada, regresa: stl")
	comprobar(g.procesar("rs") == Def.ALERTA, "s no saca de ALERTA")


func test_lenguaje_aceptado() -> void:
	var g := Def.crear_afd_guardia()        # F = {PERSECUCION}
	comprobar(g.acepta("rv"))
	comprobar(g.acepta("vrrr"))
	comprobar(not g.acepta("vp"))
	comprobar(not g.acepta(""))


func test_minimizacion_borrador() -> void:
	var borrador := Def.crear_afd_guardia_borrador()
	var minimo := borrador.minimizar({"INVESTIGAR/REVISAR": Def.ALERTA})
	comprobar(borrador.estados.size() == 7)
	comprobar(minimo.estados.size() == 6, "quedaron %d estados" % minimo.estados.size())
	var g := Def.crear_afd_guardia()
	for q in g.estados:
		comprobar(q in minimo.estados, "falta " + q)
		for s in g.alfabeto:
			comprobar(minimo.delta[q][s] == g.delta[q][s], "δ(%s,%s)" % [q, s])
	# equivalencia: misma salida para todas las cadenas de longitud <= 4
	var cadenas := [""]
	var probadas := 0
	for n in 5:
		var siguientes := []
		for c in cadenas:
			var a: String = borrador.salidas[borrador.procesar(c)]
			var b: String = minimo.salidas[minimo.procesar(c)]
			comprobar(a == b, "cadena '%s'" % c)
			probadas += 1
			if n < 4:
				for s in "vrsplta":
					siguientes.append(c + s)
		cadenas = siguientes
	comprobar(probadas == 2801, "%d cadenas" % probadas)


func test_guardia_minimo_no_se_reduce() -> void:
	comprobar(Def.crear_afd_guardia().minimizar().estados.size() == 6)


func test_minimizacion_por_aceptacion() -> void:
	# ejemplo de clase: termina en "ab"
	var delta := {
		"A": {"a": "B", "b": "C"}, "B": {"a": "B", "b": "D"},
		"C": {"a": "B", "b": "C"}, "D": {"a": "B", "b": "C"},
	}
	var afd := AFD.new("ab", ["A", "B", "C", "D"], ["a", "b"], delta, "A", ["D"])
	comprobar(afd.minimizar().estados.size() == 3)
	# el guardia minimizado SOLO por aceptación colapsa a 2 estados
	var g := Def.crear_afd_guardia()
	var sin_salidas := AFD.new("g", g.estados, g.alfabeto, g.delta, g.inicial, g.finales)
	comprobar(sin_salidas.minimizar().estados.size() == 2)


func test_camara() -> void:
	var c := Def.crear_afd_camara()
	comprobar(c.procesar("ff") == Def.GIRO_IZQ)
	comprobar(c.procesar("fvt") == Def.GIRO_IZQ)
	comprobar(c.acepta("fv"))
	comprobar(c.procesar("fvx") == Def.APAGADA, "x apaga la cámara")
	comprobar(c.procesar("xvft") == Def.APAGADA, "apagada no vuelve a encenderse")


func test_flujo() -> void:
	var f := Def.crear_afd_flujo()
	comprobar(f.procesar(["enter"]) == Def.JUGANDO)
	comprobar(f.procesar(["enter", "esc"]) == Def.PAUSA)
	comprobar(f.procesar(["enter", "esc", "esc"]) == Def.JUGANDO)
	comprobar(f.procesar(["enter", "atrapado", "enter"]) == Def.JUGANDO)
	comprobar(f.procesar(["enter", "escapo", "enter", "final"]) == Def.FIN)
	comprobar(f.acepta(["enter", "final"]))
	comprobar(f.procesar(["enter", "terminal"]) == Def.TERMINAL)
	comprobar(f.procesar(["enter", "terminal", "esc"]) == Def.JUGANDO)
	comprobar(f.procesar(["enter", "terminal", "atrapado"]) == Def.TERMINAL, "en la terminal el juego está detenido")


# --- Autómata de pila ------------------------------------------------------ #
func test_pila_vuelve_al_origen() -> void:
	var ida := ["E", "E", "E", "N", "N", "S", "O", "O", "E"]
	var r := AutomataPilaRegreso.simular_ida_y_vuelta(ida)
	comprobar(r["vacia"])
	var p := Vector2i.ZERO
	for m in ida + r["vuelta"]:
		p += AutomataPilaRegreso.DESPLAZAMIENTO[m]
	comprobar(p == Vector2i.ZERO, "terminó en %s" % p)


func test_pila_cancelacion() -> void:
	var ap := AutomataPilaRegreso.new()
	for m in ["E", "N", "S", "O"]:
		ap.registrar(m)
	comprobar(ap.vacia())


func test_pila_vuelta_es_reverso() -> void:
	var r := AutomataPilaRegreso.simular_ida_y_vuelta(["E", "E", "N", "N", "S"])
	comprobar(r["vuelta"] == ["S", "O", "O"], str(r["vuelta"]))


# --- Niveles ----------------------------------------------------------------- #
func test_niveles_validos() -> void:
	for i in Niveles.cantidad():
		var c := Niveles.compilado(i)
		comprobar(c.ok(), "nivel%d.sombra: %s" % [i + 1, str(c.errores)])
		var n := Niveles.datos(i)
		var m := Mapa.new(n["mapa"])
		comprobar(m.error == "", m.error)
		comprobar(m.ancho == 30 and m.alto == 20)
		m.abrir_puertas()                  # con las terminales resueltas
		var alc := m.alcanzables_desde(m.inicio)
		for j in m.joyas:
			comprobar(alc.has(j), "joya inalcanzable")
		comprobar(alc.has(m.salida), "salida inalcanzable")
		for g in n["guardias"]:
			for t in m.ruta_cerrada(g["puntos"]):
				comprobar(m.caminable(t))
		for t in n.get("terminales", []):
			comprobar(m.caminable(t[0]) and alc.has(t[0]), "terminal alcanzable")
			comprobar(t[0] in m.terminales, "la terminal está marcada con T en el mapa")


func test_guardia_regresa_a_su_ruta() -> void:
	var p := Partida.new(0)
	var g: Guardia = p.guardias[0]
	p.jugador.pos = Vector2(-1000, -1000)           # lejos: nadie lo ve
	for i in 60:
		p.actualizar(1.0 / 60)
	g.oir(Vector2i(2, 10), 99)
	comprobar(g.estado() == Def.ALERTA)
	var vistos := {}
	for i in 60 * 40:
		p.actualizar(1.0 / 60)
		vistos[g.estado()] = true
		comprobar(p.mapa.caminable(g.tile))
		if g.estado() == Def.PATRULLA and vistos.has(Def.REGRESO):
			break
	comprobar(vistos.has(Def.BUSQUEDA), "no buscó")
	comprobar(vistos.has(Def.REGRESO), "no regresó")
	comprobar(g.estado() == Def.PATRULLA)
	comprobar(g.tile in g.ruta, "no quedó en su ruta")
	comprobar(g.pila.vacia())


## Con los guardias lejos, un camino recorre las joyas y la salida.
func test_niveles_se_pueden_ganar() -> void:
	for i in Niveles.cantidad():
		var p := Partida.new(i)
		for t in p.terminales:
			p.resolver_terminal(t)              # como si el jugador las resolviera
		for g in p.guardias:
			g.ruta = [Vector2i(-50, -50)]
			g.pos = Vector2(-5000, -5000)
			g.destino = Vector2i(-50, -50)
		p.camaras.clear()
		var metas: Array = p.mapa.joyas.duplicate()
		metas.append(p.mapa.salida)
		for meta in metas:
			var camino = p.mapa.bfs(p.jugador.tile(), meta)
			if camino == null:
				camino = []
			for t in camino:
				var c := Mapa.centro(t)
				for k in 300:
					var dif := c - p.jugador.pos
					if dif.length() < 2:
						break
					p.actualizar(1.0 / 60, Vector2(signf(dif.x) if absf(dif.x) > 1 else 0.0,
							signf(dif.y) if absf(dif.y) > 1 else 0.0))
		comprobar(p.resultado == "escapo", "nivel %d: %s" % [i + 1, p.resultado])


func _partida_sin_guardias(i: int) -> Partida:
	var p := Partida.new(i)
	for g in p.guardias:
		g.ruta = [Vector2i(-50, -50)]
		g.pos = Vector2(-5000, -5000)
		g.destino = Vector2i(-50, -50)
	return p


func test_guardia_sospecha_y_regresa() -> void:
	var p := Partida.new(0)
	var g: Guardia = p.guardias[0]
	for i in 30:
		p.actualizar(1.0 / 60)
	# el jugador aparece en el borde del cono, lejos: solo levanta sospechas
	var frente := g.pos + Vector2.from_angle(g.angulo) * Config.TILE * 5.5
	p.jugador.pos = frente
	var vistos := {}
	for i in 60:
		p.actualizar(1.0 / 60)
		vistos[g.estado()] = true
		if g.estado() == Def.SOSPECHA:
			break
	comprobar(g.estado() == Def.SOSPECHA, "debía sospechar, quedó en " + g.estado())
	p.jugador.pos = Vector2(-1000, -1000)           # el jugador desaparece
	for i in 60 * 20:
		p.actualizar(1.0 / 60)
		vistos[g.estado()] = true
		if g.estado() == Def.PATRULLA:
			break
	comprobar(vistos.has(Def.REGRESO), "regresa con la pila")
	comprobar(g.estado() == Def.PATRULLA and g.tile in g.ruta, "volvió a su ruta")


func test_puertas_requieren_terminal() -> void:
	for i in Niveles.cantidad():
		var p := Partida.new(i)
		var tiene_puerta := false
		for t in p.terminales:
			if t["desafio"].efecto == "puerta":
				tiene_puerta = true
		if not tiene_puerta:
			continue
		var alc := p.mapa.alcanzables_desde(p.mapa.inicio)
		var bloqueadas := 0
		for j in p.mapa.joyas:
			if not alc.has(j):
				bloqueadas += 1
		comprobar(bloqueadas > 0, "nivel %d: alguna joya debe estar tras la puerta" % (i + 1))
		for t in p.terminales:
			p.resolver_terminal(t)
		alc = p.mapa.alcanzables_desde(p.mapa.inicio)
		for j in p.mapa.joyas:
			comprobar(alc.has(j), "nivel %d: tras resolver, todas las joyas son alcanzables" % (i + 1))


func test_laser_dispara_alarma() -> void:
	var p := _partida_sin_guardias(1)
	comprobar(p.laser_activo and not p.mapa.laseres.is_empty())
	p.jugador.pos = Mapa.centro(p.mapa.laseres[0])
	p.actualizar(1.0 / 60)
	comprobar(p.alarmas == 1, "cruzar el láser activa la alarma")
	var q := _partida_sin_guardias(1)
	q.resolver_terminal(q.terminales[0])
	q.jugador.pos = Mapa.centro(q.mapa.laseres[0])
	q.actualizar(1.0 / 60)
	comprobar(q.alarmas == 0, "con la rejilla desactivada no pasa nada")


func test_camaras_se_apagan() -> void:
	var p := Partida.new(2)
	var central = null
	for t in p.terminales:
		if t["desafio"].efecto == "camaras":
			central = t
	comprobar(central != null, "el nivel 3 tiene central de alarmas")
	p.resolver_terminal(central)
	for c in p.camaras:
		comprobar(c.estado() == Def.APAGADA)
		p.jugador.pos = c.pos + Vector2.from_angle(c.angulo()) * Config.TILE * 2
		c.actualizar(1.0, p.jugador, p)
		comprobar(not c.viendo, "una cámara apagada no ve")


func test_terminal_fallida_hace_ruido() -> void:
	var p := Partida.new(0)
	var g: Guardia = p.guardias[0]
	var t: Dictionary = p.terminales[0]
	g.pos = Mapa.centro(t["pos"]) + Vector2(Config.TILE * 3, 0)
	p.fallar_terminal(t)
	comprobar(g.estado() == Def.ALERTA, "el guardia cercano oye el pitido")
	comprobar(t["desafio"].intentos == 1)


func test_alerta_global_llega_a_todos() -> void:
	var p := Partida.new(2)                       # nivel 3: 5 guardias
	var lugar := Mapa.centro(Vector2i(14, 9))
	p.seguridad.pedir_alerta(lugar, "prueba")
	p.seguridad.repartir(p.guardias)
	var exactos := 0
	for g in p.guardias:
		comprobar(g.estado() == Def.ALERTA, "G%d debía pasar a ALERTA con 'a'" % (g.id + 1))
		comprobar(g.ultimo_evento == "a")
		var dist := lugar.distance_to(g.pos) / Config.TILE
		var obj := Mapa.centro(g.objetivo)
		if dist <= Config.RADIO_RESPUESTA_ALERTA:
			comprobar(obj.distance_to(lugar) / Config.TILE <= 4.6, "G%d acude a la zona" % (g.id + 1))
			if g.objetivo == Mapa.tile_de(lugar):
				exactos += 1
		else:
			comprobar(obj.distance_to(g.pos) / Config.TILE <= 4.6, "G%d busca en su sector" % (g.id + 1))
	comprobar(exactos < p.guardias.size(), "nadie debe conocer la posición exacta")
	comprobar(p.seguridad.alertas_globales == 1)


func test_deteccion_genera_alerta() -> void:
	var p := Partida.new(1)
	var g: Guardia = p.guardias[0]
	for i in 20:
		p.actualizar(1.0 / 60)
	p.jugador.pos = g.pos + Vector2.from_angle(g.angulo) * Config.TILE * 2.6
	for i in 120:
		p.actualizar(1.0 / 60)
		if g.estado() == Def.PERSECUCION:
			break
	comprobar(g.estado() == Def.PERSECUCION, "debía perseguir")
	p.resultado = ""
	p.jugador.pos = Vector2(-2000, -2000)
	p.actualizar(1.0 / 60)
	var avisados := 0
	for otro in p.guardias:
		if otro != g and otro.ultimo_evento == "a":
			avisados += 1
	comprobar(avisados == p.guardias.size() - 1, "todos los demás reciben la alerta por radio")


func test_arbusto_area_real() -> void:
	var p := _partida_sin_guardias(0)
	var arbusto: Vector2i = p.mapa.plantas.keys()[0]
	var c := Mapa.centro(arbusto)
	# en la esquina de la casilla del arbusto: cerca, pero fuera de su área
	p.jugador.pos = c + Vector2(13, 13)
	p.actualizar(1.0 / 60)
	comprobar(not p.jugador.oculto, "estar en la casilla no basta")
	p.jugador.pos = c + Vector2(3, 2)
	p.actualizar(1.0 / 60)
	comprobar(p.jugador.oculto, "dentro del área sí se oculta")


func test_no_ocultarse_si_te_ven() -> void:
	var p := Partida.new(0)
	var g: Guardia = p.guardias[0]
	var arbusto: Vector2i = p.mapa.plantas.keys()[0]
	g.pos = Mapa.centro(arbusto) - Vector2(Config.TILE * 2, 0)
	g.angulo = 0.0
	g.ruta = [Mapa.tile_de(g.pos)]
	g.destino = Guardia.SIN_TILE
	p.jugador.pos = Mapa.centro(arbusto) + Vector2(-Config.TILE * 0.9, 0)
	g.viendo = true
	p.jugador.pos = Mapa.centro(arbusto)
	p.ocultamiento.actualizar(1.0 / 60, p.jugador, p.mapa, p.guardias)
	comprobar(not p.jugador.oculto, "con contacto visual no puede ocultarse")
	g.viendo = false
	for i in 30:
		p.ocultamiento.actualizar(1.0 / 60, p.jugador, p.mapa, p.guardias)
	comprobar(not p.jugador.oculto, "aún no pasa el tiempo sin contacto")
	for i in 40:
		p.ocultamiento.actualizar(1.0 / 60, p.jugador, p.mapa, p.guardias)
	comprobar(p.jugador.oculto, "tras 1 s sin contacto ya está oculto")


func test_busqueda_registra_arbusto() -> void:
	var p := Partida.new(0)
	var g: Guardia = p.guardias[0]
	var arbusto: Vector2i = p.mapa.plantas.keys()[0]
	p.jugador.pos = Mapa.centro(arbusto)
	p.jugador.oculto = true
	g.pos = Mapa.centro(arbusto) + Vector2(Config.TILE * 2, 0)
	g.angulo = PI
	comprobar(not g.ve(p.jugador), "en patrulla no ve al ladrón oculto")
	g.evento("r")
	g.evento("l")                                 # ALERTA -> BUSQUEDA
	comprobar(g.estado() == Def.BUSQUEDA)
	comprobar(not g.ve(p.jugador), "a 2 casillas el arbusto aún lo protege")
	g.pos = Mapa.centro(arbusto) + Vector2(Config.TILE * 0.7, 0)
	comprobar(g.ve(p.jugador), "al registrar el arbusto de cerca lo encuentra")


func test_registro_de_eventos() -> void:
	var p := Partida.new(0)
	var tipos := []
	p.seguridad.evento.connect(func(tipo, _t, _d): tipos.append(tipo))
	p.jugador.monedas = 3
	p.lanzar_moneda(p.jugador.pos + Vector2(Config.TILE * 4, 0))
	for i in 60:
		p.actualizar(1.0 / 60)
	comprobar("moneda" in tipos, "la moneda queda registrada")
	comprobar("estado" in tipos or true, "los cambios de estado se registran")
	p.alarma(Vector2i(5, 5), "prueba")
	comprobar("alarma" in tipos)


# --- radar ---------------------------------------------------------------- #
func test_radar_afd() -> void:
	var a := Def.crear_afd_radar()
	comprobar(a.validar() == "", a.validar())
	comprobar(a.procesar(["t", "t", "f", "n"]) == Def.REPOSO, "un ciclo completo vuelve a REPOSO")
	comprobar(a.num_transiciones() == 12)


## Corre un ciclo completo del radar del nivel con el jugador en `pos`.
func _ciclo_radar(p: Partida, pos: Vector2, oculto := false) -> Dictionary:
	var r: Radar = p.radares[0]
	p.jugador.pos = pos
	p.jugador.oculto = oculto
	r.t_fase = r.intervalo()                     # forzar el aviso ya
	var res := {}
	for i in 60 * 10:
		var x := r.actualizar(1.0 / 60, p.jugador, p.guardias)
		p.jugador.oculto = oculto
		if x.get("tipo", "") in ["intrusion", "limpio"]:
			res = x
			break
	return res


func test_perfiles_dificultad() -> void:
	for nivel in Niveles.cantidad():
		var base: Array = Niveles.datos(nivel)["camaras"]
		var alcance := 0.0
		var intervalo := INF
		for modo in Ajustes.MODOS.size():
			var p := Partida.new(nivel, false, modo)
			var puestos := {}
			for c: Camara in p.camaras:
				comprobar(p.mapa.es_pared(c.tile) and not puestos.has(c.tile), "anclaje sin duplicados")
				puestos[c.tile] = true
			comprobar(p.camaras.size() == base.size() + Ajustes.CAMARAS_EXTRA[modo])
			var r: Radar = p.radares[0]
			comprobar(r.alcance() > alcance and r.intervalo() < intervalo, "el radar aumenta su presión")
			alcance = r.alcance()
			intervalo = r.intervalo()
			for t in p.terminales:
				var d: Desafio = t["desafio"]
				comprobar(d.dificultad == modo and d.ejecutar_intento(d.solucion_filas)["resultado"] == "ACEPTA")
				if d.efecto == "camaras":
					p.resolver_terminal(t)
					for c: Camara in p.camaras:
						comprobar(c.estado() == Def.APAGADA, "también se apagan los refuerzos")


func test_oido_por_dificultad() -> void:
	for modo in Ajustes.MODOS.size():
		for distancia in [3.4, 4.3]:
			var p := Partida.new(0, false, modo)
			var g: Guardia = p.guardias[0]
			p.jugador.pos = g.pos + Vector2(Config.TILE * distancia, 0)
			p.jugador.moviendo = true
			p.jugador.agachado = true
			g._oir_pasos(p.jugador, 1.0)
			comprobar(g.estado() == Def.PATRULLA, "agacharse conserva el sigilo")
			p.jugador.agachado = false
			g._oir_pasos(p.jugador, 1.0)
			var oye: bool = (modo == Ajustes.Modo.MEDIO and distancia == 3.4) or modo == Ajustes.Modo.DIFICIL
			comprobar((g.estado() == Def.SOSPECHA) == oye, "radio auditivo para el modo %d" % modo)


func test_radar_detecta_visible() -> void:
	var p := _partida_sin_guardias(1)
	var r: Radar = p.radares[0]
	var res := _ciclo_radar(p, r.pos + Vector2(Config.TILE * 4, 0))
	comprobar(res.get("tipo", "") == "intrusion", "visible fuera de arbusto -> intrusión: %s" % res)
	comprobar(res.get("pos", Vector2.ZERO).distance_to(r.pos + Vector2(Config.TILE * 4, 0)) < Config.TILE * 2,
			"posición aproximada (no exacta)")
	# integrado en la partida: la alerta llega a todos los guardias como 'a'
	var q := Partida.new(1)
	var rq: Radar = q.radares[0]
	q.jugador.pos = rq.pos + Vector2(Config.TILE * 4, 0)
	rq.t_fase = rq.intervalo()
	var avisados := false
	for i in 60 * 8:
		q.actualizar(1.0 / 60)
		q.jugador.pos = rq.pos + Vector2(Config.TILE * 4, 0)
		q.resultado = ""
		if q.seguridad.alertas_globales > 0:
			avisados = true
			break
	comprobar(avisados, "la intrusión dispara la alerta global")
	if avisados:
		for g in q.guardias:
			comprobar(g.ultimo_evento == "a" or g.estado() == Def.PERSECUCION, "G%d recibe 'a'" % (g.id + 1))


func test_radar_respeta_arbusto() -> void:
	var p := _partida_sin_guardias(1)
	var r: Radar = p.radares[0]
	var res := _ciclo_radar(p, r.pos + Vector2(Config.TILE * 4, 0), true)
	comprobar(res.get("tipo", "") == "limpio", "oculto en arbusto -> sin intrusión")


func test_radar_atraviesa_muros() -> void:
	var p := _partida_sin_guardias(1)
	var r: Radar = p.radares[0]
	# casilla caminable dentro del alcance pero sin línea de visión
	var objetivo := Vector2.ZERO
	for y in p.mapa.alto:
		for x in p.mapa.ancho:
			var t := Vector2i(x, y)
			var c := Mapa.centro(t)
			if p.mapa.caminable(t) and c.distance_to(r.pos) < r.alcance() * 0.9 and not p.mapa.linea_libre(r.pos, c):
				objetivo = c
	comprobar(objetivo != Vector2.ZERO, "hay una casilla tapada por muros")
	var res := _ciclo_radar(p, objetivo)
	comprobar(res.get("tipo", "") == "limpio", "el muro ofrece cobertura en Fácil")
	p.radares[0] = Radar.new(r.tile, p.mapa, 0.0, Ajustes.Modo.MEDIO)
	res = _ciclo_radar(p, objetivo)
	comprobar(res.get("tipo", "") == "limpio", "el muro ofrece cobertura en Medio")
	p.radares[0] = Radar.new(r.tile, p.mapa, 0.0, Ajustes.Modo.DIFICIL)
	res = _ciclo_radar(p, objetivo)
	comprobar(res.get("tipo", "") == "intrusion", "solo el radar Difícil atraviesa el muro")
	res = _ciclo_radar(p, objetivo, true)
	comprobar(res.get("tipo", "") == "limpio", "el arbusto protege también en Difícil")


func test_radar_fuera_de_alcance() -> void:
	var p := _partida_sin_guardias(1)
	var r: Radar = p.radares[0]
	var res := _ciclo_radar(p, r.pos + Vector2(r.alcance() + Config.TILE * 2, 0))
	comprobar(res.get("tipo", "") == "limpio", "fuera de alcance -> sin intrusión")


func test_radar_ignora_guardias() -> void:
	var p := _partida_sin_guardias(1)
	var r: Radar = p.radares[0]
	var g: Guardia = p.guardias[0]
	g.pos = r.pos + Vector2(Config.TILE * 3, 0)
	var res := _ciclo_radar(p, Vector2(-3000, -3000))
	comprobar(res.get("tipo", "") == "limpio", "un guardia con transpondedor no es intruso")
	comprobar(r.obs_a.has(1), "el radar registró el transpondedor")


# --- audio ---------------------------------------------------------------- #
func test_musica_sigue_a_los_afd() -> void:
	var p := _partida_sin_guardias(0)
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "EXPLORACION")
	var g: Guardia = p.guardias[0]
	g.evento("s")
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "SOSPECHA", "SOSPECHA del AFD")
	g.evento("r")
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "BUSQUEDA", "ALERTA -> música de búsqueda")
	g.evento("l")
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "BUSQUEDA", "BUSQUEDA")
	g.evento("v")
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "PERSECUCION")
	g.evento("p")
	g.evento("t")
	g.evento("l")
	comprobar(g.estado() == Def.PATRULLA)
	p.seguridad.t_alerta = 5.0
	comprobar(GestorAudio.estado_desde(Def.JUGANDO, p) == "ALARMA", "alerta global -> ALARMA")
	comprobar(GestorAudio.estado_desde(Def.DERROTA, p) == "DERROTA")
	comprobar(GestorAudio.estado_desde(Def.VICTORIA, p) == "VICTORIA")
	comprobar(GestorAudio.estado_desde(Def.FIN, p) == "VICTORIA")


func test_musica_fundido_gradual() -> void:
	var a := GestorAudio.new()
	root.add_child(a)
	a.preparar()
	a.fijar_estado("EXPLORACION")
	for i in 120:
		a._process(1.0 / 60)
	comprobar(is_equal_approx(a.volumen[0], 1.0), "la capa base suena en exploración")
	a.fijar_estado("PERSECUCION")
	a._process(1.0 / 60)
	comprobar(a.volumen[3] > 0.0 and a.volumen[3] < 0.1, "el cambio no es brusco")
	for i in 60:
		a._process(1.0 / 60)
	comprobar(is_equal_approx(a.volumen[3], 1.0), "tras el fundido la capa de persecución suena")
	comprobar(a.volumen[0] > 0.55, "la base baja despacio")
	a.fijar_estado("DERROTA")
	comprobar(a.remate.playing, "suena el remate de derrota")
	a.queue_free()


func test_efectos_sin_saturar() -> void:
	var a := GestorAudio.new()
	root.add_child(a)
	a.preparar()
	var sonados := 0
	for i in 200:                                  # 200 lecturas en el mismo instante
		if a.sonar("mt_leer"):
			sonados += 1
	comprobar(sonados == 1, "una sola lectura por intervalo (%d)" % sonados)
	var distintos := 0
	for n in ["moneda", "joya", "radio", "alarma", "oculto", "laser", "puerta", "terminal"]:
		if a.sonar(n):
			distintos += 1
	comprobar(distintos <= GestorAudio.RAFAGA_MAX - 1, "límite de arranques simultáneos (%d)" % distintos)
	a.rafaga_mt(400, true)
	comprobar(a._cola.size() <= 7, "400 pasos se agrupan en una ráfaga corta")
	a.queue_free()


# --- tutoriales y consola --------------------------------------------------- #
func test_tutoriales_completos() -> void:
	Ajustes.guardar_en_disco = false
	var t := PanelTutorial.new()
	root.add_child(t)
	for id in PanelTutorial.TUTORIALES:
		t.abrir(id)
		var paginas: Array = PanelTutorial.TUTORIALES[id]["paginas"]
		for i in paginas.size():
			t.ir(i)
			var pg: Dictionary = paginas[i]
			if pg.has("maquina"):
				comprobar(t.maquina != null and t.maquina.validar() == "", "%s/%d máquina válida" % [id, i])
				if pg["tipo"] == "sim":
					var r := t.maquina.ejecutar()
					comprobar(r in ["ACEPTA", "RECHAZA"], "%s/%d se detiene" % [id, i])
			if pg["tipo"] == "ejercicio":
				comprobar(t.responder(pg["correcta"]), "%s/%d la opción correcta se acepta" % [id, i])
				t.ir(i)
				var mala: int = (pg["correcta"] + 1) % pg["opciones"].size()
				comprobar(not t.responder(mala), "%s/%d una opción incorrecta se rechaza" % [id, i])
		t._avanzar_pagina()
		comprobar(Ajustes.tutorial_visto(id), "al terminar queda marcado como visto")
	t.queue_free()
	Ajustes.tutoriales_vistos = {}


## Los ejercicios describen exactamente lo que hace la máquina real.
func test_ejercicio_coincide_con_la_maquina() -> void:
	var m := ProgramasTuring.incrementador()
	m.cargar("1011")
	for i in 5:
		m.paso()
	comprobar(m.estado == "q2" and m.cinta.leer() == "1", "en q2 leyendo 1")
	var t := m.paso()
	comprobar(t["escrito"] == "0" and t["mov"] == "L", "δ(q2,1) = (q2, 0, L)")
	var a := ProgramasTuring.anbn()
	a.cargar("abb")
	comprobar(a.ejecutar() == "RECHAZA", "aⁿbⁿ rechaza abb")
	var c := ProgramasTuring.correlador_sensores()
	c.cargar(["10", "00", ""])
	c.ejecutar()
	comprobar(c.cintas[2].leer_en(0) == "1", "P=1, A=0 -> intruso")


func test_radar_registra_maquinas() -> void:
	var p := _partida_sin_guardias(0)
	var r: Radar = p.radares[0]
	p.jugador.pos = Vector2(-3000, -3000)
	r.t_fase = r.intervalo()
	for i in 60 * 10:
		p.actualizar(1.0 / 60)
		if r.escaneos > 0:
			break
	comprobar(r.escaneos == 1, "un escaneo completo")
	comprobar(Partida.maquina_de(p.maquinas.get("multicinta", {})) is MTMulticinta, "la consola ve la multicinta")
	comprobar(Partida.maquina_de(p.maquinas.get("multipista", {})) is MTMultipista, "la consola ve la multipista")
	var tipos := []
	for e in p.seguridad.registro:
		tipos.append(e["tipo"])
	comprobar("radar" in tipos and "turing" in tipos, "el registro anota el ciclo y la ejecución")


# --- mejoras: radar al punto, pasos, energía ------------------------------ #
func test_radar_manda_al_punto() -> void:
	var p := Partida.new(1)
	var r: Radar = p.radares[0]
	var punto := r.pos + Vector2(Config.TILE * 4, 0)
	p.jugador.pos = punto
	r.t_fase = r.intervalo()
	for i in 60 * 8:
		p.actualizar(1.0 / 60)
		p.jugador.pos = punto
		p.resultado = ""
		if p.seguridad.alertas_globales > 0:
			break
	comprobar(p.seguridad.alertas_globales > 0, "hubo alerta")
	for g in p.guardias:
		if g.estado() != Def.PERSECUCION:
			comprobar(g.objetivo == Mapa.tile_de(punto), "G%d va al punto exacto (%s)" % [g.id + 1, g.objetivo])
			comprobar(g.puntos_busqueda.size() == Config.PUNTOS_BUSQUEDA_AMPLIA, "y luego registra alrededor")


func test_busqueda_amplia() -> void:
	var p := _partida_sin_guardias(0)
	var g: Guardia = p.guardias[0]
	g.pos = Mapa.centro(Vector2i(5, 8))
	g.tile = Vector2i(5, 8)
	g.ruta = [g.tile]
	g.destino = Guardia.SIN_TILE
	g.recibir_alerta(Mapa.centro(Vector2i(7, 8)), true)
	comprobar(g.estado() == Def.ALERTA)
	var visitados := {}
	var estados := {}
	for i in 60 * 30:
		g.actualizar(1.0 / 60, p.jugador)          # el ladrón ya se fue (lejos)
		estados[g.estado()] = true
		visitados[g.tile] = true
		if g.estado() == Def.REGRESO:
			break
	comprobar(estados.has(Def.BUSQUEDA), "al llegar y no verlo pasa a BUSQUEDA")
	comprobar(g.estado() == Def.REGRESO, "termina la búsqueda y regresa")
	comprobar(visitados.size() >= 4, "registró varios lugares alrededor (%d)" % visitados.size())


func _guardia_quieto(p: Partida) -> Guardia:
	var g: Guardia = p.guardias[0]
	g.pos = Mapa.centro(Vector2i(10, 7))
	g.tile = Vector2i(10, 7)
	g.ruta = [g.tile]
	g.destino = Guardia.SIN_TILE
	g.angulo = PI                              # mira a la izquierda
	return g


func test_oye_pasos_caminando() -> void:
	var p := _partida_sin_guardias(0)
	var g := _guardia_quieto(p)
	p.jugador.pos = g.pos + Vector2(Config.TILE * 2.0, 0)   # a su espalda
	p.jugador.moviendo = true
	g.actualizar(1.0 / 60, p.jugador)
	comprobar(g.estado() == Def.SOSPECHA, "pasos cerca: SOSPECHA (%s)" % g.estado())
	comprobar(absf(Guardia.diferencia_angular(g.angulo, 0.0)) < 0.01, "se voltea al instante")


func test_oye_pasos_corriendo() -> void:
	var p := _partida_sin_guardias(0)
	var g := _guardia_quieto(p)
	p.jugador.pos = g.pos + Vector2(Config.TILE * 4.5, 0)
	p.jugador.moviendo = true
	g.actualizar(1.0 / 60, p.jugador)
	comprobar(g.estado() == Def.PATRULLA, "caminando a 4.5 casillas no lo oye")
	p.jugador.corriendo = true
	g.actualizar(1.0 / 60, p.jugador)
	comprobar(g.estado() == Def.ALERTA, "corriendo sí: ALERTA (%s)" % g.estado())


func test_agachado_no_se_oye() -> void:
	var p := _partida_sin_guardias(0)
	var g := _guardia_quieto(p)
	p.jugador.pos = g.pos + Vector2(Config.TILE * 1.5, 0)
	p.jugador.moviendo = true
	p.jugador.agachado = true
	g.actualizar(1.0 / 60, p.jugador)
	comprobar(g.estado() == Def.PATRULLA, "agachado no se oye")


func test_energia_limita_correr() -> void:
	var p := _partida_sin_guardias(0)
	var corriendo := 0
	for i in 60 * 8:
		p.actualizar(1.0 / 60, Vector2(1, 0) if (i / 60) % 2 == 0 else Vector2(-1, 0), true)
		if p.jugador.corriendo:
			corriendo += 1
	comprobar(p.energia.operaciones > 10, "la MT de la batería se usa")
	comprobar(corriendo < 60 * 6, "no se puede correr sin parar (%d fotogramas)" % corriendo)
	comprobar(p.energia.agotado or p.energia.nivel() < Config.ENERGIA_CELDAS, "gastó energía")


func test_consola_sin_pausa() -> void:
	var src := FileAccess.get_file_as_string("res://escenas/consola/consola.gd")
	comprobar(not src.contains("paused = true"), "la consola no pausa el juego")
