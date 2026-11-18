## Minijuego 3 · Puerta de la bóveda: «Sincronía de los tres mecanismos».
##
## Tres mecanismos, tres cintas, tres cabezales independientes:
##   Sensor A  revela su gema a destellos (hay que mirarla a tiempo).
##   Rotor B   gira solo; ESPACIO lo frena en la gema de la ventana (timing).
##             Su gema es cuántos pasos girar A: R=0, Z=1, E=2, A=3.
##   Lector K  la clave está AL REVÉS: el lector empieza en el extremo
##             derecho y retrocede; solo acepta confirmar (ENTER) cuando su
##             anillo de sincronía está en verde.
## Al confirmar una ronda se escribe la gema en la cinta B y la máquina
## MULTICINTA real se ejecuta desde su estado inicial hasta haber comparado
## esa columna (validación por partes); al final se ejecuta completa. Si
## rechaza, el rotor B queda marcado y se repite la ronda.
class_name MJBoveda
extends Minijuego

var a := ""
var k := ""
var n := 0
var b_conf: Array = []
var ronda := 0
var ang_b := 0.0
var vel_b := 1.0
var frenado := false
var gema_b := ""
var atasco := 0.0
var error_b := 0.0
var t_ronda := 0.0
var reloj := 0.0
var reloj_total := 0.0
var anim: Array = []             ## transiciones reales que se están animando
var anim_t := 0.0
var t_puerta := 0.0
const PASO_ANIM := 0.14


func _subtitulo() -> String:
	return "MÁQUINA MULTICINTA · 3 cintas, 3 cabezales independientes · coordina los tres mecanismos"


func _intro() -> Array:
	return ["Clímax del atraco: la bóveda compara tres mecanismos a la vez. Mira la gema del sensor A, la del lector K "
			+ "(que lee la clave al revés) y frena el rotor B en los pasos que llevan de A a K en la rueda.",
			["ESPACIO: frenar / soltar el rotor B (frena solo si la gema está en la ventana)",
			"ENTER: confirmar la ronda cuando el anillo del lector K esté en VERDE",
			"V ver la máquina   ·   T modo accesible (sensor siempre visible, sin reloj)   ·   P pausa"],
			"En la primera ronda los deslices no cuentan y no hay reloj."]


func maquina() -> MTMulticinta:
	return desafio.maquina as MTMulticinta


func _dif() -> float:
	return clampf(Ajustes.dificultad, 0.6, 1.4)


func tolerancia() -> float:
	return 0.28 + (1.0 - _dif()) * 0.2 + (0.1 if accesible else 0.0)


func periodo_k() -> float:
	return 1.9 / _dif() * (1.4 if accesible else 1.0)


func k_sincronizado() -> bool:
	return fposmod(t_ronda, periodo_k()) < periodo_k() * (0.42 if not accesible else 0.6)


func a_visible() -> bool:
	return accesible or fase != "juego" or fposmod(t_ronda, 2.6) < 1.5


func _preparar() -> void:
	a = desafio.filas[0]["contenido"]
	k = desafio.filas[2]["contenido"]
	n = a.length()
	b_conf.clear()
	for i in n:
		b_conf.append("")
	ronda = 0
	ang_b = 0.3
	frenado = false
	gema_b = ""
	atasco = 0.0
	error_b = 0.0
	t_ronda = 0.0
	anim = []
	t_puerta = 0.0
	reloj_total = 26.0 / _dif()
	reloj = reloj_total
	if desafio.resuelto:
		for i in n:
			b_conf[i] = desafio.solucion_filas[1][i]
		ronda = n
		desafio.ejecutar_intento([a, b_str(), k])
		t_puerta = 9.0
	else:
		desafio.ejecutar_hasta([a, b_str(), k], func(_m): return true)


## Cinta B: las gemas confirmadas; las rondas pendientes llevan el rotor en reposo (R = 0).
func b_str() -> String:
	var s := ""
	for g in b_conf:
		s += g if g != "" else "R"
	return s


func _comenzar() -> void:
	# fase q0 REAL: el cabezal 3 recorre K hasta el final (S, S, R) y vuelve una casilla
	var r := desafio.ejecutar_hasta([a, b_str(), k], func(m): return m.estado != m.inicial)
	anim = r["transiciones"].duplicate()
	anim_t = 0.0
	avisar("El lector K busca el final de la clave: la comparará AL REVÉS. Cabezales 1 y 2 esperan.", CIAN)


func _actualizar(dt: float) -> void:
	if not anim.is_empty():
		anim_t += dt
		if anim_t > anim.size() * PASO_ANIM + 0.3:
			anim = []
		return
	if fase == "exito":
		t_puerta += dt
		return
	if fase != "juego":
		return
	t_ronda += dt
	atasco = maxf(0.0, atasco - dt)
	error_b = maxf(0.0, error_b - dt)
	if not frenado:
		var v := 0.95 * _dif() * (0.55 if accesible else 1.0) * (0.15 if atasco > 0.0 else 1.0)
		ang_b = fposmod(ang_b + v * vel_b * dt, 4.0)
	if not ensayo and not accesible:
		reloj -= dt
		if reloj <= 0.0:
			reloj = reloj_total
			fallo_fisico("el mecanismo de la bóveda se recalentó")
			avisar("FALLO FÍSICO · la ronda tardó demasiado y el mecanismo chirrió. Reloj reiniciado.", NARANJA)


## Gema en la ventana del rotor y su desvío.
func ventana_b() -> Array:
	var p := fposmod(ang_b, 4.0)
	return [G[int(round(p)) % 4], p - round(p)]


func _tecla(e: InputEventKey) -> bool:
	if fase != "juego" or not anim.is_empty():
		return false
	match e.keycode:
		KEY_SPACE:
			frenar()
		KEY_ENTER, KEY_KP_ENTER:
			confirmar()
		KEY_UP, KEY_DOWN:
			vel_b = -vel_b
		_:
			return false
	return true


func _gui_input(e: InputEvent) -> void:
	if fase != "juego" or pausado or visor_abierto() or not anim.is_empty():
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if centro_b().distance_to(e.position) < 90:
			frenar()
			accept_event()
		elif Rect2(PANEL.position.x + 620, PANEL.position.y + 70, 264, 250).has_point(e.position):
			confirmar()
			accept_event()


func frenar() -> bool:
	if atasco > 0.0:
		return false
	if frenado:
		frenado = false
		return true
	var v := ventana_b()
	if absf(v[1]) > tolerancia():
		atasco = 0.8
		desliz("el rotor B frenó entre dos gemas y se atascó")
		return false
	frenado = true
	gema_b = v[0]
	ang_b = float(G.find(gema_b))
	sonar("mt_mover", 0.9)
	return true


func confirmar() -> bool:
	if not frenado:
		avisar("Primero frena el rotor B (ESPACIO).", SUAVE, 1.6)
		return false
	if not k_sincronizado():
		desliz("el lector K no estaba sincronizado")
		return false
	return confirmar_ronda(gema_b)


## Escribe la gema en la cinta B y ejecuta la MT multicinta desde q0 hasta
## que el cabezal 1 haya pasado la columna de esta ronda (o se detenga).
func confirmar_ronda(g: String) -> bool:
	var i := ronda
	b_conf[i] = g
	var r := desafio.ejecutar_hasta([a, b_str(), k], func(m): return m.cintas[0].cabezal > i)
	var trans: Array = r["transiciones"]
	if r["resultado"] == "EN CURSO":
		# solo se animan los pasos nuevos de esta ronda
		var desde := 0
		for t in range(trans.size()):
			if trans[t]["estado"] == "q1" and trans[t]["posicion"][0] == i:
				desde = t
				break
		anim = trans.slice(desde)
		anim_t = 0.0
		ronda += 1
		frenado = false
		ensayo = false
		reloj = reloj_total
		t_ronda = 0.0
		sonar("mt_escribir", 1.0 + i * 0.1)
		if ronda >= n:
			_final()
		else:
			avisar("Ronda %d correcta: %s girada %d = %s. Cabezales 1 y 2 avanzan →, el 3 retrocede ←." % [
					i + 1, NOMBRE[a[i]], G.find(g), NOMBRE[k[n - 1 - i]]], VERDE)
		return true
	if r["resultado"] == "ERROR":
		b_conf[i] = ""
		error_tecnico()
		return false
	if r["resultado"] == "ACEPTA":               # no debería ocurrir antes de la última ronda
		_final()
		return true
	b_conf[i] = ""
	frenado = false
	error_b = 2.5
	var ultima: Dictionary = trans[-1] if not trans.is_empty() else {}
	fallo_logico("en el estado %s leyó (%s): %s girada %d pasos no es la gema que espera K. Repite la ronda." % [
			ultima.get("estado", "?"), ",".join(ultima.get("leido", [])), NOMBRE[a[i]], G.find(g)])
	return false


func _final() -> void:
	var r := desafio.ejecutar_intento([a, b_str(), k])      # ejecución completa desde q0
	if r["resultado"] == "ACEPTA":
		exito_formal()
		t_puerta = 0.0
		avisar("La MT multicinta ACEPTÓ: A girada según B coincide con K leída al revés. ¡La bóveda se abre!", VERDE, 6.0)
	elif r["resultado"] == "ERROR":
		error_tecnico()
	else:
		fallo_logico("la ejecución completa no aceptó las tres cintas.")
		_preparar()


# ---------------------------------------------------------------------- #
# Dibujo
# ---------------------------------------------------------------------- #
func centro_b() -> Vector2:
	return Vector2(PANEL.get_center().x, PANEL.position.y + 200)


## Posiciones de los tres cabezales: animadas con las transiciones reales o
## las de la máquina.
func cabezales() -> Array:
	if not anim.is_empty():
		var idx := clampi(int(anim_t / PASO_ANIM), 0, anim.size() - 1)
		var t: Dictionary = anim[idx]
		var f := clampf(anim_t / PASO_ANIM - idx, 0.0, 1.0)
		var r := []
		for h in 3:
			var p: float = t["posicion"][h]
			var mv: String = t["mov"][h]
			r.append(p + f * (1.0 if mv == "R" else (-1.0 if mv == "L" else 0.0)))
		return r
	var mq := maquina()
	return [float(mq.cintas[0].cabezal), float(mq.cintas[1].cabezal), float(mq.cintas[2].cabezal)]


func _dibujar_juego() -> void:
	var py := PANEL.position.y
	var mq := maquina()
	Dibujo.texto(self, "RONDA %d / %d" % [mini(ronda + 1, n), n], Vector2(PANEL.position.x + 20, py + 64), 14,
			Color.WHITE, false, true, false)
	if fase == "juego" and not accesible:
		barra_tiempo(Vector2(PANEL.position.x + 140, py + 66), 260, reloj, 0.0 if ensayo else reloj_total,
				"RELOJ" if not ensayo else "ENSAYO")
	var i := mini(ronda, n - 1)
	var cab := cabezales()
	# --- sensor A
	var ra := Rect2(PANEL.position.x + 20, py + 90, 250, 230)
	_caja(ra, "SENSOR A", "cabezal 1 →", CIAN)
	var ca := ra.get_center() + Vector2(0, 6)
	if a_visible() and fase != "exito":
		draw_circle(ca, 46, Color(CIAN, 0.12))
		gema_grande(a[i], ca, 74)
	else:
		draw_circle(ca, 46, Color(1, 1, 1, 0.03))
		Dibujo.texto(self, "· · ·", ca, 20, SUAVE, true, true, false)
	Dibujo.texto(self, "gema %d de %d" % [i + 1, n], Vector2(ca.x, ra.end.y - 24), 12, SUAVE, true, false, false)
	# --- rotor B
	var rb := Rect2(PANEL.position.x + 290, py + 90, 324, 230)
	_caja(rb, "ROTOR B · pasos de giro", "cabezal 2 →", ROJO if error_b > 0.0 else NARANJA)
	var cb := centro_b() + Vector2(0, 12)
	var radio := 74.0
	draw_circle(cb, radio + 12, Color(0.02, 0.04, 0.06))
	var col_rotor := ROJO.lerp(Color.WHITE, 0.5 + 0.5 * sin(tiempo * 20)) if error_b > 0.0 else (
			NARANJA if frenado else Color(CIAN, 0.6))
	draw_arc(cb, radio + 12, 0, TAU, 48, col_rotor, 3.0)
	var tol := tolerancia() * PI / 2
	draw_arc(cb, radio + 18, -PI / 2 - tol, -PI / 2 + tol, 16, Color(VERDE, 0.85), 4.0)
	for s in 4:
		var ang := -PI / 2 + (s - ang_b) * PI / 2
		var p := cb + Vector2.from_angle(ang) * (radio - 18)
		gema_grande(G[s], p, 32)
		Dibujo.texto(self, str(s), cb + Vector2.from_angle(ang) * (radio - 46), 13, TEXTO, true, true, false)
	var w := cb + Vector2(0, -radio - 24)
	draw_colored_polygon(PackedVector2Array([w + Vector2(0, 10), w + Vector2(-8, -2), w + Vector2(8, -2)]),
			NARANJA if frenado else Color.WHITE)
	var estado_b := "FRENADO en %s = %d pasos" % [NOMBRE[gema_b], G.find(gema_b)] if frenado else (
			"ATASCADO" if atasco > 0.0 else "GIRANDO · ESPACIO para frenar")
	Dibujo.texto(self, estado_b, Vector2(cb.x, rb.end.y - 14), 12, col_rotor, true, true, false)
	# --- lector K
	var rk := Rect2(PANEL.position.x + 634, py + 90, 250, 230)
	_caja(rk, "LECTOR K · clave al revés", "cabezal 3 ←", AMBAR)
	var ck := rk.get_center() + Vector2(0, 6)
	var sinc := k_sincronizado() and fase == "juego"
	var pk := periodo_k()
	var fr := fposmod(t_ronda, pk) / pk
	draw_arc(ck, 56, -PI / 2, -PI / 2 + TAU * (0.42 if not accesible else 0.6), 32, Color(VERDE, 0.25), 8.0)
	draw_arc(ck, 56, -PI / 2, -PI / 2 + TAU * fr, 32, VERDE if sinc else ROJO, 4.0)
	var pos_k := int(round(cab[2]))
	if pos_k >= 0 and pos_k < n:
		gema_grande(mq.cintas[2].leer_en(pos_k), ck, 70)
	Dibujo.texto(self, "SINCRONIZADO · ENTER" if sinc else "esperando sincronía", Vector2(ck.x, rk.end.y - 24), 12,
			VERDE if sinc else SUAVE, true, true, false)
	parrafo("¿Cuántos pasos hay en la rueda de la gema A a la gema K? Frena el rotor B en ese número.",
			Vector2(PANEL.position.x + 20, py + 330), PANEL.size.x - 40, 13, SUAVE, 1)
	# --- las tres cintas con sus cabezales independientes (datos reales)
	_dibujar_cintas(cab)
	if fase == "exito":
		_dibujar_puerta()


func _caja(r: Rect2, titulo: String, sub: String, col: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.03))
	draw_rect(r, Color(col, 0.6), false, 2.0)
	Dibujo.texto(self, titulo, r.position + Vector2(10, 8), 12, col, false, true, false)
	Dibujo.texto(self, sub, r.position + Vector2(r.size.x - 10 - Dibujo.ancho_texto(sub, 11), 9), 11, SUAVE, false,
			false, false)


func _dibujar_cintas(cab: Array) -> void:
	var mq := maquina()
	var celda := 34.0
	var x0 := PANEL.position.x + 250
	var y0 := PANEL.position.y + 380
	var nombres := ["Cinta A · sensor", "Cinta B · rotor", "Cinta K · clave (al revés)"]
	Dibujo.texto(self, "TRES CINTAS · TRES CABEZALES  (estado %s)" % mq.estado, Vector2(PANEL.position.x + 20, y0 - 22),
			11, SUAVE, false, true, false)
	for t in 3:
		var y := y0 + t * (celda + 14)
		Dibujo.texto(self, nombres[t], Vector2(PANEL.position.x + 30, y + 10), 12, TEXTO, false, true, false)
		for p in range(0, n + 1):
			var r := Rect2(x0 + p * celda, y, celda - 3, celda - 3)
			draw_rect(r, Color(0.06, 0.1, 0.15))
			draw_rect(r, Color(CIAN, 0.2), false, 1.0)
			var s: String = mq.cintas[t].leer_en(p)
			if t == 0 and fase == "juego" and (p > ronda or (p == ronda and not a_visible())):
				s = "?"                       # el sensor revela sus gemas de una en una, a destellos
			if t == 1 and p < n and b_conf[p] == "":
				s = "·"
			if not Dibujo.gema(self, s, r):
				Dibujo.texto(self, s if s != "_" else "␣", r.get_center(), 14, SUAVE, true, true, false)
		var hx := x0 + float(cab[t]) * celda
		var col := AMBAR
		draw_rect(Rect2(hx - 2, y - 3, celda + 1, celda + 3), col, false, 2.5)
		var flecha := "← retrocede" if t == 2 else "→ avanza"
		Dibujo.texto(self, "cabezal %d  %s  (posición %d)" % [t + 1, flecha, int(round(cab[t]))],
				Vector2(x0 + (n + 1) * celda + 18, y + 8), 12, col, false, true, false)


func _dibujar_puerta() -> void:
	# la puerta blindada se abre poco a poco (dos hojas que se apartan)
	var f := clampf((t_puerta - 0.4) / 2.6, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var c := Vector2(PANEL.get_center().x, PANEL.position.y + 300)
	var off := f * 330.0
	var alto := 440.0
	var col := Color(0.14, 0.18, 0.24, 0.97 - f * 0.5)
	for s in [-1, 1]:
		var x_borde: float = c.x + s * off
		var hoja := Rect2(x_borde - (300.0 if s < 0 else 0.0), c.y - alto / 2, 300, alto)
		draw_rect(hoja, col)
		draw_rect(hoja, Color(CIAN, 0.5 - f * 0.3), false, 2.0)
		for b in 5:                                         # pernos del cierre
			var by := c.y - alto / 2 + 50 + b * 85
			draw_circle(Vector2(x_borde - s * 16, by), 7, Color(NARANJA, 0.8 - f * 0.5))
		draw_line(Vector2(x_borde, c.y - alto / 2), Vector2(x_borde, c.y + alto / 2), Color(VERDE, 1.0 - f * 0.6), 3.0)
		# media rueda de la cerradura en cada hoja
		draw_arc(Vector2(x_borde, c.y), 70, PI / 2 if s < 0 else -PI / 2, PI * 1.5 if s < 0 else PI / 2, 24,
				Color(AMBAR, 0.9 - f * 0.6), 6.0)
	if f >= 1.0:
		_velo("BÓVEDA ABIERTA", "La MT multicinta aceptó · V: ¿cómo funcionó? · Esc: volver al museo", VERDE)
