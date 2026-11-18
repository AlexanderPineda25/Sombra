## Minijuego 2 · Rejilla láser: «Cruce sincronizado».
##
## Un pasillo con un haz por columna de la cinta. Cada haz se enciende y se
## apaga en ciclos. El ladrón espera en los refugios, elige una máscara
## (1-4 / Q E) y cruza cuando el haz está apagado.
##   - Cruzar con el haz encendido: FALLO FÍSICO (ruido), vuelve al refugio.
##     La máquina no interviene.
##   - Cruzar con el haz apagado: el sensor escribe la máscara en la PISTA 2
##     de la columna bajo el cabezal (casilla aún no leída) y la máquina
##     MULTIPISTA da UN paso real: lee la tupla (láser, máscara, objetivo) con
##     su único cabezal. Si hay transición, el cabezal avanza y el tramo queda
##     autorizado; si no, la máquina RECHAZA (fallo lógico) y el checkpoint se
##     restaura repitiendo la ejecución real hasta esa columna.
##   - En la salida la máquina termina su programa (regresa y ACEPTA) y se
##     confirma con una ejecución completa desde el principio.
## El personaje está siempre en el refugio de la columna del cabezal.
class_name MJLaser
extends Minijuego

const SUELO := 392.0
const TECHO := 232.0
const BANDA := 13.0
const CUERPO := 11.0
const VEL := 190.0

var l := ""
var o := ""
var n := 0
var m_eff: Array = []           ## pista 2 tal como la va leyendo la máquina ("_" = aún no escrita)
var x := 0.0
var mascara := "R"
var cruzando := false
var mascara_cruce := ""
var practica_hecha := false
var trans_vivas: Array = []
var t_laser := 0.0
var periodos: Array = []
var fases: Array = []
var bateria := 3
var t_bateria := 0.0
var t_escaner := 0.0
var t_final := 0.0
var destello := {}              ## j -> segundos de destello (verde autorizado / rojo detectado)


func _subtitulo() -> String:
	return "MÁQUINA MULTIPISTA · 1 cinta con 3 pistas, 1 cabezal · cruza cuando el haz esté apagado"


func _intro() -> Array:
	return ["Cruza el pasillo de seguridad tramo a tramo. Cada haz se apaga a ratos: espera en el refugio y pasa en la "
			+ "ventana segura. Antes de cruzar ponte la máscara que completa la escalera láser → máscara → objetivo.",
			["← → o A D: moverte   ·   1 2 3 4 o Q E: cambiar de máscara (también clic en la gema)",
			"F o Shift: escáner (3 cargas, muestra cuándo cambia cada haz)",
			"V ver la máquina   ·   T modo accesible (haces más lentos)   ·   P pausa"],
			"El primer haz blanco es de práctica: si te toca, no pasa nada."]


func gate_x(j: int) -> float:
	return PANEL.position.x + 150.0 + j * ((PANEL.size.x - 250.0) / n)


func salida_x() -> float:
	return PANEL.end.x - 60.0


## Índice de puerta (0 = práctica, c + 1 = columna c) que el ladrón tiene delante.
func activa() -> int:
	if not practica_hecha:
		return 0
	return maquina().cabezal + 1


func maquina() -> MTMultipista:
	return desafio.maquina as MTMultipista


func _preparar() -> void:
	l = desafio.filas[0]["contenido"]
	o = desafio.filas[2]["contenido"]
	n = l.length()
	x = PANEL.position.x + 70.0
	mascara = "R"
	cruzando = false
	practica_hecha = false
	bateria = 3
	t_escaner = 0.0
	t_laser = 0.0
	t_final = 0.0
	destello = {}
	periodos.clear()
	fases.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(l + o)                    # ciclos reproducibles por partida
	for j in n + 1:
		periodos.append(2.1 + rng.randf() * 0.9)
		fases.append(rng.randf() * 3.0)
	m_eff.clear()
	for c in n:
		m_eff.append("_")
	trans_vivas.clear()
	if desafio.resuelto:
		for c in n:
			m_eff[c] = desafio.solucion_filas[1][c]
		desafio.ejecutar_intento([l, "".join(m_eff), o])
		practica_hecha = true
		x = salida_x() + 20
		return
	# cinta inicial: pista 2 vacía; el cabezal empieza en la columna 0 (q0)
	desafio.ejecutar_hasta([l, "".join(m_eff), o], func(_m): return true)


func _escala() -> float:
	return clampf(Ajustes.dificultad, 0.6, 1.4) * (0.65 if accesible else 1.0)


func periodo(j: int) -> float:
	return periodos[j] / _escala()


func fraccion_on() -> float:
	return 0.45 + 0.1 * (clampf(Ajustes.dificultad, 0.6, 1.4) - 1.0)


func haz_encendido(j: int) -> bool:
	if j > 0 and j - 1 < maquina().cabezal:
		return false                          # tramo ya autorizado: haz desactivado
	var p := periodo(j)
	return fposmod(t_laser + fases[j], p) < p * fraccion_on()


## Segundos hasta el próximo cambio del haz j.
func hasta_cambio(j: int) -> float:
	var p := periodo(j)
	var m := fposmod(t_laser + fases[j], p)
	var on := p * fraccion_on()
	return on - m if m < on else p - m


func _comenzar() -> void:
	avisar("Primero el haz de práctica (blanco). Cruza cuando se apague.", CIAN)


# ---------------------------------------------------------------------- #
func _actualizar(dt: float) -> void:
	for j in destello.keys():
		destello[j] -= dt
		if destello[j] <= 0.0:
			destello.erase(j)
	if fase == "verificando":
		t_final += dt
		if t_final > 1.4:
			_confirmar()
		return
	if fase != "juego":
		return
	t_laser += dt
	t_escaner = maxf(0.0, t_escaner - dt)
	t_bateria += dt
	if t_bateria > 25.0 and bateria < 3:
		t_bateria = 0.0
		bateria += 1
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	mover(dir * VEL * dt)


## Desplaza al ladrón y resuelve los cruces (lo usan también las pruebas).
func mover(dx: float) -> void:
	x = clampf(x + dx, PANEL.position.x + 50.0, PANEL.end.x - 30.0)
	var j := activa()
	if j > n:
		if x > salida_x():
			_llegar_salida()
		return
	var gx := gate_x(j)
	var dentro := absf(x - gx) < BANDA + CUERPO
	if dentro:
		if not cruzando:
			cruzando = true
			mascara_cruce = mascara
		if haz_encendido(j):
			_detectado(j)
	elif cruzando:
		cruzando = false
		if x > gx:
			_cruce_completo(j)
	elif x > gx:                     # nunca se salta un haz sin cruzarlo
		x = gx - BANDA - CUERPO - 1.0


func _detectado(j: int) -> void:
	cruzando = false
	destello[j] = 0.6
	x = gate_x(j) - 48.0
	if j == 0:
		sonar("laser", 1.3)
		avisar("ENSAYO · el haz te habría detectado. Sin castigo: espera a que se apague.", AMBAR)
		return
	sonar("laser")
	fallo_fisico("cruzó el haz %d encendido" % j)
	avisar("FALLO FÍSICO · cruzaste el haz encendido (timing). La máquina no leyó nada; vuelves al refugio.", NARANJA)


func _cruce_completo(j: int) -> void:
	if j == 0:
		practica_hecha = true
		ensayo = false
		destello[0] = 0.6
		sonar("mt_leer")
		avisar("¡Así se cruza! Desde aquí los haces son reales: mira láser (arriba) y objetivo (abajo).", VERDE)
		return
	procesar_columna(j - 1, mascara_cruce)


## El sensor del tramo c escribe la máscara en la pista 2 y la máquina da un paso.
func procesar_columna(c: int, m: String) -> bool:
	var mq := maquina()
	if mq.cabezal != c or mq.estado != mq.inicial:
		push_error("MJLaser: cabezal %d desincronizado del tramo %d" % [mq.cabezal, c])
		return false
	m_eff[c] = m
	mq.escribir_en(c, [l[c], m, o[c]])        # casilla bajo el cabezal, aún sin leer
	desafio.filas[1]["contenido"] = "".join(m_eff)
	var t := mq.paso()
	trans_vivas.append(t)
	var tupla := "(%s, %s, %s)" % [l[c], m, o[c]]
	if mq.estado == mq.inicial and mq.cabezal == c + 1:
		desafio.registrar_intento([l, "".join(m_eff), o], trans_vivas, "EN CURSO")
		destello[c + 1] = 0.8
		sonar("mt_escribir", 1.0 + c * 0.06)
		avisar("Tramo %d autorizado: el cabezal leyó %s y avanzó a la columna %d." % [c + 1, tupla, c + 2], VERDE)
		return true
	# sin transición: la máquina se detuvo RECHAZANDO
	desafio.registrar_intento([l, "".join(m_eff), o], trans_vivas, mq.resultado())
	var rechazo: Dictionary = desafio.ultimo_intento
	destello[c + 1] = 0.8
	x = gate_x(c + 1) - 48.0
	# checkpoint: repite la ejecución real hasta dejar el cabezal en la columna c
	m_eff[c] = "_"
	var rest := desafio.ejecutar_hasta([l, "".join(m_eff), o], func(mm): return mm.cabezal >= c)
	trans_vivas = rest["transiciones"].duplicate()
	desafio.ultimo_intento = rechazo
	fallo_logico("leyó %s: la máscara %s no está entre %s y %s en la rueda. Vuelves al refugio." % [
			tupla, NOMBRE[m], NOMBRE[l[c]], NOMBRE[o[c]]])
	return false


func _llegar_salida() -> void:
	if fase != "juego":
		return
	fase = "verificando"
	t_final = 0.0
	var mq := maquina()
	while not mq.detenida() and trans_vivas.size() < Desafio.MAX_PASOS:
		trans_vivas.append(mq.paso())          # q1: el cabezal regresa al inicio
	desafio.registrar_intento([l, "".join(m_eff), o], trans_vivas,
			mq.resultado() if mq.detenida() else "ERROR")
	sonar("terminal")


func _confirmar() -> void:
	var vivo: String = desafio.ultimo_intento["resultado"]
	var completo := desafio.ejecutar_intento([l, "".join(m_eff), o])   # ejecución completa desde q0
	if vivo == "ACEPTA" and completo["resultado"] == "ACEPTA":
		exito_formal()
		avisar("La máquina multipista ACEPTÓ las %d columnas. La rejilla se apaga." % n, VERDE, 5.0)
	elif completo["resultado"] == "ERROR" or vivo == "ERROR":
		fase = "juego"
		error_tecnico()
	else:
		fase = "juego"
		fallo_logico("la ejecución completa no aceptó la cinta.")


# ---------------------------------------------------------------------- #
func _tecla(e: InputEventKey) -> bool:
	if fase != "juego":
		return false
	match e.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			poner_mascara(G[e.keycode - KEY_1])
		KEY_Q:
			poner_mascara(G[(G.find(mascara) + 3) % 4])
		KEY_E:
			poner_mascara(G[(G.find(mascara) + 1) % 4])
		KEY_F, KEY_SHIFT:
			escaner()
		_:
			return false
	return true


func poner_mascara(g: String) -> void:
	if cruzando:
		avisar("La máscara queda fija mientras cruzas el haz.", SUAVE, 1.5)
		return
	mascara = g
	sonar("mt_mover", 1.0 + G.find(g) * 0.1)


func escaner() -> void:
	if t_escaner > 0.0:
		return
	if bateria <= 0:
		avisar("Escáner sin batería (se recarga una carga cada 25 s).", SUAVE, 2.0)
		return
	bateria -= 1
	t_bateria = 0.0
	t_escaner = 3.0
	sonar("radar_ping", 1.4)


func _gui_input(e: InputEvent) -> void:
	if fase != "juego" or pausado or visor_abierto():
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in 4:
			if _rect_mascara(i).has_point(e.position):
				poner_mascara(G[i])
				accept_event()
				return


func _rect_mascara(i: int) -> Rect2:
	return Rect2(PANEL.position.x + 120 + i * 52, PANEL.position.y + 74, 44, 44)


# ---------------------------------------------------------------------- #
# Dibujo
# ---------------------------------------------------------------------- #
func _dibujar_juego() -> void:
	var px := PANEL.position.x
	# selector de máscara y escáner
	Dibujo.texto(self, "MÁSCARA", Vector2(px + 20, PANEL.position.y + 88), 12, SUAVE, false, true, false)
	for i in 4:
		var r := _rect_mascara(i)
		var puesta: bool = G[i] == mascara
		draw_rect(r, Color(1, 1, 1, 0.08 if puesta else 0.03))
		draw_rect(r, NARANJA if puesta else Color(CIAN, 0.3), false, 3.0 if puesta else 1.0)
		gema_grande(G[i], r.get_center(), 34)
		Dibujo.texto(self, str(i + 1), r.position + Vector2(3, 1), 10, SUAVE, false, true, false)
	var ex := px + 360
	Dibujo.texto(self, "ESCÁNER", Vector2(ex, PANEL.position.y + 80), 12, SUAVE, false, true, false)
	for i in 3:
		var r := Rect2(ex + 70 + i * 22, PANEL.position.y + 80, 16, 14)
		draw_rect(r, CIAN if i < bateria else Color(1, 1, 1, 0.08))
	if t_escaner > 0.0:
		Dibujo.texto(self, "ACTIVO %.1f s" % t_escaner, Vector2(ex + 140, PANEL.position.y + 80), 12, CIAN, false, true, false)
	parrafo("Escalera de arriba abajo: láser → máscara → objetivo, seguidos en la rueda.",
			Vector2(ex, PANEL.position.y + 102), 520, 12, SUAVE, 1)
	# pasillo
	var pasillo := Rect2(px + 20, TECHO - 40, PANEL.size.x - 40, SUELO - TECHO + 70)
	draw_rect(pasillo, Color(0.03, 0.05, 0.08))
	for k in range(int(pasillo.position.x), int(pasillo.end.x), 32):
		draw_line(Vector2(k, SUELO), Vector2(k + 16, SUELO + 22), Color(CIAN, 0.06), 1.0)
	draw_line(Vector2(pasillo.position.x, SUELO), Vector2(pasillo.end.x, SUELO), Color(CIAN, 0.4), 2.0)
	draw_line(Vector2(pasillo.position.x, TECHO - 30), Vector2(pasillo.end.x, TECHO - 30), Color(CIAN, 0.25), 2.0)
	# salida
	var sx := salida_x()
	var abierta := practica_hecha and maquina().cabezal >= n
	draw_rect(Rect2(sx, TECHO - 20, PANEL.end.x - 20 - sx, SUELO - TECHO + 20),
			Color(VERDE if abierta else ROJO, 0.12))
	Dibujo.texto(self, "SALIDA", Vector2(sx + 22, TECHO - 6), 11, VERDE if abierta else ROJO, true, true, false)
	# refugios
	for j in n + 1:
		var a := (gate_x(j - 1) if j > 0 else px + 40.0) + 26.0
		var b := gate_x(j) - 26.0
		draw_rect(Rect2(a, SUELO - 8, b - a, 8), Color(CIAN, 0.18))
	for j in n + 1:
		_dibujar_haz(j)
	_dibujar_ladron()
	_dibujar_cinta()
	if fase == "exito":
		_velo("REJILLA DESACTIVADA", "La máquina aceptó · V: ¿cómo funcionó? · Esc: volver al museo", VERDE)


func _dibujar_haz(j: int) -> void:
	var gx := gate_x(j)
	var practica := j == 0
	var c := j - 1
	var autorizado := not practica and c < maquina().cabezal and practica_hecha
	if practica and practica_hecha:
		autorizado = true
	var on := haz_encendido(j) and not autorizado and fase == "juego"
	var col_haz: Color = Color.WHITE
	if not practica:
		col_haz = Dibujo.COLOR_GEMA[l[c]]
	var es_activa := j == activa()
	# emisor y receptor
	var emisor := Rect2(gx - 20, TECHO - 26, 40, 34)
	var receptor := Rect2(gx - 20, SUELO - 30, 40, 30)
	draw_rect(emisor, Color(0.08, 0.12, 0.18))
	draw_rect(receptor, Color(0.08, 0.12, 0.18))
	var borde := VERDE if autorizado else (CIAN if es_activa else Color(CIAN, 0.3))
	if destello.has(j):
		borde = VERDE if autorizado else ROJO
	draw_rect(emisor, borde, false, 2.0)
	draw_rect(receptor, borde, false, 2.0)
	if practica:
		Dibujo.texto(self, "ENSAYO", Vector2(gx, TECHO - 40), 11, AMBAR, true, true, false)
	else:
		gema_grande(l[c], emisor.get_center(), 28)
		gema_grande(o[c], receptor.get_center(), 26)
		Dibujo.texto(self, "láser", Vector2(gx, TECHO - 40), 10, SUAVE, true, false, false)
		Dibujo.texto(self, "objetivo", Vector2(gx, SUELO + 12), 10, SUAVE, true, false, false)
		# hueco de la máscara (centro de la escalera)
		var hueco := Rect2(gx + 18, (TECHO + SUELO) / 2 - 30, 30, 30)
		draw_rect(hueco, Color(0.05, 0.08, 0.12))
		draw_rect(hueco, borde, false, 1.0)
		if autorizado:
			Dibujo.gema(self, m_eff[c].to_upper(), hueco)
		else:
			Dibujo.texto(self, "?", hueco.get_center(), 16, SUAVE, true, true, false)
	# el haz
	var y0 := TECHO + 8
	var y1 := SUELO - 30
	if on:
		draw_line(Vector2(gx, y0), Vector2(gx, y1), Color(col_haz, 0.25), 18.0)
		draw_line(Vector2(gx, y0), Vector2(gx, y1), col_haz, 4.0)
	elif not autorizado:
		var aviso_on := hasta_cambio(j) < 0.35 and fase == "juego"
		var a := 0.5 if aviso_on and int(tiempo * 16) % 2 == 0 else 0.12
		for k in range(int(y0), int(y1), 12):
			draw_line(Vector2(gx, k), Vector2(gx, k + 5), Color(col_haz, a), 2.0)
	else:
		Dibujo.texto(self, "✓", Vector2(gx, (TECHO + SUELO) / 2 + 30), 18, VERDE, true, true, false)
	# escáner: cuenta atrás del ciclo
	if t_escaner > 0.0 and not autorizado and fase == "juego":
		var h := hasta_cambio(j)
		var txt := ("APAGA EN %.1f" if haz_encendido(j) else "ENCIENDE EN %.1f") % h
		Dibujo.texto(self, txt, Vector2(gx, TECHO + 18), 10, CIAN, true, true, false)
		var r := Rect2(gx - 22, TECHO + 28, 44, 5)
		draw_rect(r, Color(1, 1, 1, 0.08))
		var p := periodo(j)
		draw_rect(Rect2(r.position, Vector2(r.size.x * fposmod(t_laser + fases[j], p) / p, r.size.y)), CIAN)
		draw_rect(Rect2(r.position + Vector2(r.size.x * fraccion_on(), 0), Vector2(1, r.size.y)), ROJO)


func _dibujar_ladron() -> void:
	var base := Vector2(x, SUELO - 2)
	var col := Color(0.12, 0.14, 0.2)
	draw_rect(Rect2(base + Vector2(-CUERPO, -46), Vector2(CUERPO * 2, 36)), col)
	draw_circle(base + Vector2(0, -56), 10, col)
	draw_rect(Rect2(base + Vector2(-CUERPO, -46), Vector2(CUERPO * 2, 36)), Color(CIAN, 0.7), false, 1.5)
	draw_arc(base + Vector2(0, -56), 10, 0, TAU, 20, Color(CIAN, 0.7), 1.5)
	draw_line(base + Vector2(-6, -10), base + Vector2(-8, 0), Color(CIAN, 0.7), 2.0)
	draw_line(base + Vector2(6, -10), base + Vector2(8, 0), Color(CIAN, 0.7), 2.0)
	# la máscara que lleva (fija mientras cruza)
	var g := mascara_cruce if cruzando else mascara
	Dibujo.gema(self, g, Rect2(base + Vector2(6, -74), Vector2(24, 24)))


## La única cinta de 3 pistas, con su único cabezal (datos reales de la MT).
func _dibujar_cinta() -> void:
	var mq := maquina()
	var celda := 28.0
	var x0 := PANEL.get_center().x - (n + 2) * celda / 2.0
	var y0 := SUELO + 40
	Dibujo.texto(self, "UNA CINTA · 3 PISTAS · 1 CABEZAL  (estado %s)" % mq.estado, Vector2(x0 - 150, y0 - 2), 11,
			SUAVE, false, true, false)
	var nombres := ["láser", "máscara", "objetivo"]
	for p in 3:
		Dibujo.texto(self, nombres[p], Vector2(x0 - 62, y0 + 16 + p * celda), 10, SUAVE, false, false, false)
		for i in range(-1, n + 1):
			var r := Rect2(x0 + (i + 1) * celda, y0 + 12 + p * celda, celda - 2, celda - 2)
			draw_rect(r, Color(0.06, 0.1, 0.15))
			var s: String = mq.leer_en(i)[p]
			if not Dibujo.gema(self, s, r):
				Dibujo.texto(self, "␣", r.get_center(), 12, Color(SUAVE, 0.5), true, false, false)
	var hx := x0 + (mq.cabezal + 1) * celda
	draw_rect(Rect2(hx - 2, y0 + 10, celda + 2, celda * 3 + 2), AMBAR, false, 2.5)
