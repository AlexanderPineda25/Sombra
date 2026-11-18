## Minijuego 1 · Cerradura de la vitrina: «El patrón del joyero».
##
## Observación: dos ejemplos (vitrina → clave) que la MT ACEPTA muestran la
## regla (rueda, rivales, espejo…). Ejecución: un disco giratorio por gema de
## la clave; se fija con ESPACIO cuando la gema deseada pasa por la ventana
## (timing con tolerancia). Al fijar todos, la entrada «vitrina # clave» se
## ejecuta en la MT ESTÁNDAR (una cinta, un cabezal, zigzag) y ella decide.
## Si rechaza, el disco culpable sale de la posición donde se detuvo el
## cabezal (dato de la propia ejecución).
class_name MJCerradura
extends Minijuego

var vitrina := ""
var discos: Array = []        ## {ang, vel, fijo, gema, patina, error}
var sel := 0
var reloj := 0.0
var reloj_total := 0.0
var escaneo := {}             ## animación de la ejecución real {trans, t, dur, contenido}
var pista_nivel := 0


func _subtitulo() -> String:
	return "MÁQUINA ESTÁNDAR · 1 cinta, 1 cabezal · descifra el patrón y fija los discos a tiempo"


func _intro() -> Array:
	return ["El joyero dejó dos ejemplos de cómo su cerradura transforma el código de la vitrina. Descubre la regla "
			+ "y alinea la clave en los discos: cada disco gira solo y se fija cuando la gema está en la ventana.",
			["← → elegir disco   ·   ↑ ↓ cambiar el sentido de giro (o rueda del ratón)",
			"ESPACIO o clic en el disco: fijar la gema de la ventana   ·   Retroceso: soltar disco",
			"V ver la máquina   ·   T modo accesible (sin reloj)   ·   P pausa   ·   R reiniciar discos"],
			"El reloj no corre ni los deslices cuentan hasta que fijes el primer disco."]


func _velocidad() -> float:
	var v := 0.85 * clampf(Ajustes.dificultad, 0.6, 1.4)
	return v * (0.5 if accesible else 1.0)


func tolerancia() -> float:
	var t := 0.3 + (1.0 - clampf(Ajustes.dificultad, 0.6, 1.4)) * 0.2
	return t + (0.1 if accesible else 0.0)


func _preparar() -> void:
	vitrina = desafio.filas[0]["contenido"].split("#")[0]
	reloj_total = 95.0 / clampf(Ajustes.dificultad, 0.6, 1.4) + vitrina.length() * 6.0
	reloj = reloj_total
	escaneo = {}
	pista_nivel = 0
	sel = 0
	_nuevos_discos()
	if desafio.resuelto:
		var sol: String = desafio.solucion_filas[0].split("#")[1]
		for i in discos.size():
			discos[i]["fijo"] = true
			discos[i]["gema"] = sol[i]
			discos[i]["ang"] = float(G.find(sol[i]))
		desafio.ejecutar_intento([desafio.solucion_filas[0]])


func _nuevos_discos() -> void:
	discos.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(vitrina)                  # reproducible por partida
	for i in vitrina.length():
		discos.append({"ang": rng.randf() * 4.0, "vel": (1.0 + 0.18 * (i % 3)) * (1 if i % 2 == 0 else -1),
				"fijo": false, "gema": "", "patina": 0.0, "error": 0.0})


func _comenzar() -> void:
	avisar("Observa los ejemplos y fija el primer disco cuando su gema esté en la ventana.", CIAN)


## Gema visible en la ventana del disco y su desvío respecto al centro (-0.5..0.5).
func en_ventana(d: Dictionary) -> Array:
	var a := fposmod(float(d["ang"]), 4.0)
	var k := int(round(a)) % 4
	return [G[k], a - round(a)]


func _actualizar(dt: float) -> void:
	if fase == "juego":
		for d in discos:
			d["patina"] = maxf(0.0, d["patina"] - dt)
			d["error"] = maxf(0.0, d["error"] - dt)
			if not d["fijo"]:
				var v: float = d["vel"] * _velocidad()
				if d["patina"] > 0.0:
					v *= 0.15
				d["ang"] = fposmod(d["ang"] + v * dt, 4.0)
		if not ensayo and not accesible:
			reloj -= dt
			if reloj <= 0.0:
				reloj = reloj_total
				fallo_fisico("tiempo agotado en la cerradura")
				avisar("FALLO FÍSICO · se acabó el tiempo y la cerradura chirrió. El reloj vuelve a empezar.", NARANJA)
	elif fase == "verificando":
		escaneo["t"] += dt
		if escaneo["t"] >= escaneo["dur"]:
			_resolver()
	elif fase == "exito":
		escaneo["t"] = escaneo.get("t", 0.0) + dt


# ---------------------------------------------------------------------- #
func _tecla(e: InputEventKey) -> bool:
	if fase != "juego":
		return false
	match e.keycode:
		KEY_LEFT, KEY_A:
			sel = (sel - 1 + discos.size()) % discos.size()
		KEY_RIGHT, KEY_D:
			sel = (sel + 1) % discos.size()
		KEY_UP, KEY_DOWN, KEY_W, KEY_S:
			discos[sel]["vel"] = -discos[sel]["vel"]
		KEY_SPACE, KEY_F:
			fijar(sel)
		KEY_BACKSPACE, KEY_DELETE:
			discos[sel]["fijo"] = false
		KEY_R:
			_nuevos_discos()
			avisar("Discos reiniciados.", SUAVE)
		_:
			return false
	return true


func _gui_input(e: InputEvent) -> void:
	if fase != "juego" or pausado or visor_abierto():
		return
	if e is InputEventMouseButton and e.pressed:
		for i in discos.size():
			if centro_disco(i).distance_to(e.position) < radio() + 8:
				sel = i
				if e.button_index == MOUSE_BUTTON_LEFT:
					if discos[i]["fijo"]:
						discos[i]["fijo"] = false
					else:
						fijar(i)
				elif e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_RIGHT]:
					discos[i]["vel"] = -discos[i]["vel"]
				accept_event()
				return


## Intenta fijar el disco i (acción de timing). Devuelve true si se fijó.
func fijar(i: int) -> bool:
	var d: Dictionary = discos[i]
	if d["fijo"] or d["patina"] > 0.0:
		return false
	var v := en_ventana(d)
	if absf(v[1]) > tolerancia():
		d["patina"] = 0.7
		desliz("el disco %d estaba entre dos gemas" % (i + 1))
		return false
	d["fijo"] = true
	d["gema"] = v[0]
	d["ang"] = float(G.find(v[0]))
	sonar("mt_escribir", 1.0 + i * 0.08)
	if ensayo:
		ensayo = false
		avisar("¡Bien! El reloj empieza a correr. Fija el resto de los discos.", VERDE)
	for k in discos.size():
		var j := (i + 1 + k) % discos.size()
		if not discos[j]["fijo"]:
			sel = j
			break
	if todos_fijos():
		_enviar()
	return true


func todos_fijos() -> bool:
	for d in discos:
		if not d["fijo"]:
			return false
	return true


func clave_actual() -> String:
	var s := ""
	for d in discos:
		s += d["gema"] if d["fijo"] else "?"
	return s


## Construye la entrada bien formada y la ejecuta en la MT estándar.
func _enviar() -> void:
	var contenido := vitrina + "#" + clave_actual()
	var intento := desafio.ejecutar_intento([contenido])
	fase = "verificando"
	escaneo = {"trans": intento["transiciones"], "t": 0.0, "dur": clampf(intento["pasos"] * 0.03, 0.9, 2.2),
			"contenido": contenido}
	sonar("terminal")


func _resolver() -> void:
	var intento: Dictionary = desafio.ultimo_intento
	match intento["resultado"]:
		"ACEPTA":
			exito_formal()
			avisar("La máquina ACEPTÓ «%s»: la vitrina se abre." % escaneo["contenido"], VERDE, 5.0)
		"RECHAZA":
			fase = "juego"
			var trans: Array = intento["transiciones"]
			var pos: int = trans[-1]["posicion"] if not trans.is_empty() else -1
			var idx := pos - vitrina.length() - 1        # casilla de la clave donde se detuvo el cabezal
			if idx >= 0 and idx < discos.size():
				discos[idx]["fijo"] = false
				discos[idx]["error"] = 2.5
				sel = idx
			else:
				for d in discos:
					d["fijo"] = false
			pista_nivel += 1
			var extra := ""
			if pista_nivel == 2:
				extra = " Pista: " + desafio.pista_ayuda
			elif pista_nivel >= 3:
				extra = " Regla: " + desafio.objetivo
			fallo_logico(("el cabezal se detuvo en el disco %d (estado %s)." % [idx + 1, trans[-1]["estado"]]
					if idx >= 0 and idx < discos.size() else "la clave no corresponde.") + extra)
		_:
			fase = "juego"
			error_tecnico()


# ---------------------------------------------------------------------- #
# Dibujo
# ---------------------------------------------------------------------- #
func radio() -> float:
	return 46.0 if discos.size() <= 4 else 40.0


func centro_disco(i: int) -> Vector2:
	var n := discos.size()
	var paso := minf(150.0, (PANEL.size.x - 120) / n)
	var x0 := PANEL.get_center().x - paso * (n - 1) / 2.0
	return Vector2(x0 + i * paso, PANEL.position.y + 372)


func _dibujar_juego() -> void:
	var x0 := PANEL.position.x + 20
	var y := PANEL.position.y + 70
	# --- observación: los ejemplos del joyero
	var caja := Rect2(x0, y, PANEL.size.x - 40, 150)
	draw_rect(caja, Color(1, 1, 1, 0.03))
	draw_rect(caja, Color(CIAN, 0.25), false, 1.0)
	Dibujo.texto(self, "OBSERVA · notas del joyero (dos ejemplos correctos)", caja.position + Vector2(12, 8), 12, CIAN,
			false, true, false)
	for e in desafio.ejemplos.size():
		var ej: Array = desafio.ejemplos[e]
		var p0: String = ej[0]
		var k0: String = ej[1]
		var ex := caja.position.x + 24 + e * 290
		var ey := caja.position.y + 46
		Dibujo.texto(self, "Ejemplo %d" % (e + 1), Vector2(ex, ey - 12), 11, SUAVE, false, false, false)
		for k in p0.length():
			gema_grande(p0[k], Vector2(ex + 18 + k * 34, ey + 26), 34)
		var fx := ex + 18 + p0.length() * 34
		Dibujo.texto(self, "→", Vector2(fx + 8, ey + 26), 22, AMBAR, true, true, false)
		for k in k0.length():
			gema_grande(k0[k], Vector2(fx + 34 + k * 34, ey + 26), 34)
	# el código de la vitrina a transformar
	var vx := caja.end.x - 24 - vitrina.length() * 40
	Dibujo.texto(self, "CÓDIGO DE LA VITRINA", Vector2(vx, caja.position.y + 34), 12, NARANJA, false, true, false)
	for k in vitrina.length():
		var c := Vector2(vx + 20 + k * 40, caja.position.y + 84)
		draw_circle(c, 21, Color(NARANJA, 0.10))
		gema_grande(vitrina[k], c, 42)
	parrafo("¿Qué le pasa a cada gema? ¿Cambia el orden? Aplica la misma regla al código de la vitrina.",
			caja.position + Vector2(24, 118), 560, 12, SUAVE, 1)

	# --- discos
	if not accesible and fase != "exito":
		barra_tiempo(Vector2(x0, PANEL.position.y + 236), 330, reloj, reloj_total if not ensayo else 0.0,
				"RELOJ" if not ensayo else "ENSAYO")
	Dibujo.texto(self, "CLAVE · disco 1 = primera gema tras el #", Vector2(PANEL.get_center().x + 60,
			PANEL.position.y + 236), 12, SUAVE, false, true, false)
	for i in discos.size():
		_dibujar_disco(i)

	# --- la máquina trabajando (cinta real de la ejecución)
	if not escaneo.is_empty():
		_dibujar_escaneo()
	if fase == "exito" and (escaneo.is_empty() or escaneo["t"] > escaneo["dur"] + 0.6):
		_velo("VITRINA ABIERTA", "La máquina aceptó la clave · V: ¿cómo funcionó? · Esc: volver al museo", VERDE)


func _dibujar_disco(i: int) -> void:
	var d: Dictionary = discos[i]
	var c := centro_disco(i)
	var r := radio()
	var seleccionado := i == sel and fase == "juego"
	var col_borde := CIAN if seleccionado else Color(CIAN, 0.3)
	if d["fijo"]:
		col_borde = NARANJA
	if d["error"] > 0.0:
		col_borde = ROJO.lerp(Color.WHITE, 0.5 + 0.5 * sin(tiempo * 20.0))
	if fase == "exito":
		col_borde = VERDE
	var sac := Vector2(randf_range(-2, 2), 0) if d["patina"] > 0.0 else Vector2.ZERO
	c += sac
	draw_circle(c, r + 10, Color(0.02, 0.04, 0.06))
	draw_arc(c, r + 10, 0, TAU, 48, col_borde, 3.0 if seleccionado else 2.0)
	# zona de tolerancia alrededor de la ventana (arriba)
	var tol := tolerancia() * PI / 2
	draw_arc(c, r + 16, -PI / 2 - tol, -PI / 2 + tol, 16, Color(VERDE, 0.85), 4.0)
	# las cuatro gemas del disco (la k está a (k - ang) cuartos de vuelta de la ventana)
	for k in 4:
		var a := -PI / 2 + (k - float(d["ang"])) * PI / 2
		var p := c + Vector2.from_angle(a) * (r - 12)
		gema_grande(G[k], p, 30 if not d["fijo"] or G[k] == d["gema"] else 22)
	# ventana y marca
	var w := c + Vector2(0, -r - 22)
	draw_colored_polygon(PackedVector2Array([w + Vector2(0, 10), w + Vector2(-8, -2), w + Vector2(8, -2)]),
			NARANJA if d["fijo"] else Color.WHITE)
	# centro: gema fijada / candado
	draw_circle(c, 18, Color(0.05, 0.08, 0.12))
	if d["fijo"]:
		gema_grande(d["gema"], c, 30)
		draw_arc(c, 18, 0, TAU, 24, NARANJA, 2.0)
	else:
		Dibujo.texto(self, str(i + 1), c, 16, SUAVE, true, true, false)
	var etiqueta := "FIJADO" if d["fijo"] else ("PATINA" if d["patina"] > 0.0 else ("ERROR" if d["error"] > 0.0
			else "disco %d" % (i + 1)))
	Dibujo.texto(self, etiqueta, c + Vector2(0, r + 30), 12, col_borde, true, true, false)
	if seleccionado:
		Dibujo.texto(self, "▲", c + Vector2(0, r + 48), 14, CIAN, true, true, false)


func _dibujar_escaneo() -> void:
	var trans: Array = escaneo["trans"]
	var contenido: String = escaneo["contenido"]
	var n := trans.size()
	var f := clampf(escaneo["t"] / escaneo["dur"], 0.0, 1.0)
	var k := clampi(int(f * n), 0, maxi(n - 1, 0))
	# reconstruye la cinta hasta el paso k con las transiciones REALES
	var celdas := []
	for ch in contenido:
		celdas.append(ch)
	celdas.append("_")
	for j in range(0, k):
		var t: Dictionary = trans[j]
		var p: int = t["posicion"]
		if p >= 0 and p < celdas.size():
			celdas[p] = t["escrito"]
	var cab: int = trans[k]["posicion"] if n > 0 else 0
	var estado: String = trans[k]["estado"] if n > 0 else "q0"
	var y := PANEL.position.y + 500
	var x := PANEL.get_center().x - celdas.size() * 15
	tira_cinta(Vector2(x, y), celdas, cab, 30, "LA MÁQUINA DE UNA CINTA COMPRUEBA LA CLAVE  ·  paso %d/%d  ·  estado %s" % [
			k + 1, n, estado])
	if f >= 1.0 or fase == "exito":
		var res: String = desafio.ultimo_intento.get("resultado", "")
		var col := VERDE if res == "ACEPTA" else ROJO
		Dibujo.texto(self, "ACEPTA" if res == "ACEPTA" else res, Vector2(x + celdas.size() * 30 + 40, y + 14), 16, col,
				true, true, false)
