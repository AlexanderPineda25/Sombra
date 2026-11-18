## El lector recibe los datos reales del instante en el que se cruza el haz.
class_name MJLaser
extends Minijuego

const Y_PASILLO := 330.0
const DISTANCIA := 665.0
const INICIO := 132.0
const PALETA := Vector2(296, 446)
const CICLO := 4.5

var haces := ""
var mascaras := ""
var encendidos := ""
var avanzados := 0
var mascara := "R"
var x := INICIO
var reloj_haz := 0.0
var bloqueo := 0.0
var cruzar_en_camino := false


func _preparar() -> void:
	haces = desafio.solucion_filas[0]
	mascaras = "_".repeat(haces.length())
	encendidos = "_".repeat(haces.length())
	avanzados = 0
	mascara = "R"
	x = INICIO
	reloj_haz = 0.0
	bloqueo = 0.0
	cruzar_en_camino = false
	if not desafio.resuelto:
		_cargar_filas()
		desafio.construir()


func _cargar_filas() -> void:
	var datos := _datos()
	for i in datos.size():
		desafio.filas[i]["contenido"] = datos[i]


func _datos() -> Array:
	return [haces, mascaras, encendidos]


func refugio(i: int) -> float:
	return INICIO + i * DISTANCIA / haces.length()


func haz_x(i: int) -> float:
	return lerpf(refugio(i), refugio(i + 1), 0.55)


func encendido() -> bool:
	return reloj_haz < (2.0 if accesible else 2.85 + 0.4 * desafio.dificultad)


func _tecla(e: InputEventKey) -> bool:
	if e.keycode >= KEY_1 and e.keycode <= KEY_4:
		mascara = G[e.keycode - KEY_1]
		return true
	if e.keycode in [KEY_RIGHT, KEY_D]:
		cruzar_en_camino = true
		return true
	if e.keycode in [KEY_LEFT, KEY_A]:
		cruzar_en_camino = false
		x = refugio(avanzados)
		return true
	return false


func _clic(p: Vector2) -> void:
	for i in G.size():
		if Rect2(PALETA + Vector2(i * 66, 0), Vector2(58, 56)).has_point(p):
			mascara = G[i]
			return
	if Rect2(600, 446, 210, 56).has_point(p):
		cruzar_en_camino = true


func _actualizar(dt: float) -> void:
	reloj_haz = fposmod(reloj_haz + dt, CICLO)
	bloqueo = maxf(0.0, bloqueo - dt)
	if bloqueo > 0:
		return
	if cruzar_en_camino:
		mover(220 * dt)


func mover(distancia: float) -> void:
	if fase != "juego" or avanzados >= haces.length():
		return
	var siguiente := maxf(refugio(avanzados), x + distancia)
	if x < haz_x(avanzados) and siguiente >= haz_x(avanzados):
		cruzar()
	else:
		x = siguiente


func cruzar() -> void:
	if fase != "juego" or avanzados >= haces.length():
		return
	var i := avanzados
	cruzar_en_camino = false
	mascaras[i] = mascara
	encendidos[i] = "1" if encendido() else "0"
	var intento := desafio.ejecutar_hasta(_datos(), func(m: MTMultipista): return m.cabezal > i)
	match intento["resultado"]:
		"EN CURSO":
			avanzados += 1
			x = refugio(avanzados)
			reloj_haz = 0.0
			ensayo = false
			sonar("puerta", 1.35)
			if avanzados == haces.length():
				confirmar(_datos())
		"RECHAZA":
			mascaras[i] = "_"
			encendidos[i] = "_"
			x = refugio(i)
			bloqueo = 0.42
			detectado("El haz te vio. Prueba la máscara con su misma figura.")
		_:
			x = refugio(i)
			avisar("No se pudo comprobar el cruce. Reabre la terminal.", AMBAR)


func _progreso() -> String:
	return "%d/%d haces" % [avanzados, haces.length()]


func _ayuda() -> String:
	return "1–4 para elegir máscara   ·   → para cruzar   ·   También puedes hacer clic"


func _mensaje_exito() -> String:
	return "Rejilla desactivada"


func _dibujar_juego() -> void:
	suelo(Rect2i(64, 200, 13, 3))
	for i in haces.length() + 1:
		Arte.casilla(self, Arte.ALFOMBRA, Rect2(refugio(i) - 29, Y_PASILLO - 22, 58, 44))
		if i == haces.length():
			continue
		var hx := haz_x(i)
		var activo := i > avanzados or (i == avanzados and encendido())
		var col: Color = Dibujo.COLOR_GEMA[haces[i]]
		if activo:
			draw_rect(Rect2(hx - 18, 255, 36, 129), Color(col, 0.17))
			draw_line(Vector2(hx, 257), Vector2(hx, 384), col, 5, true)
		else:
			draw_line(Vector2(hx, 257), Vector2(hx, 384), Color(col, 0.18), 2, true)
		Arte.casilla(self, Arte.EMISOR_LASER, Rect2(hx - 19, 232, 38, 38))
		ficha(haces[i], Vector2(hx, 220), 34 if i == avanzados else 24)
	if avanzados < haces.length():
		var activa := encendido()
		var mensaje := "Haz encendido" if activa else "Puedes pasar"
		if activa and mascara == haces[avanzados] and fase != "intro":
			mensaje = "Máscara correcta · Cruza"
		Dibujo.texto(self, mensaje, Vector2(480, 171), 18,
				AMBAR if activa and mascara != haces[avanzados] else VERDE, true, true)
	var px := x
	if fase == "intro":
		px = lerpf(INICIO, refugio(1), fposmod(tiempo, 2.5) / 2.5)
	var pos := Vector2(px, Y_PASILLO)
	draw_texture_rect_region(Arte.ladron, Rect2(pos - Vector2(36, 35), Vector2(72, 72)), Rect2(0, 0, 64, 64))
	ficha(haces[0] if fase == "intro" else mascara, pos + Vector2(0, -42), 25)
	Dibujo.texto(self, "Máscaras", Vector2(150, 466), 18, TEXTO, false, true)
	for i in G.size():
		var r := Rect2(PALETA + Vector2(i * 66, 0), Vector2(58, 56))
		casilla(r, G[i] == (haces[0] if fase == "intro" else mascara))
		ficha(G[i], r.get_center() - Vector2(0, 5), 30)
		Dibujo.texto(self, str(i + 1), r.get_center() + Vector2(0, 17), 13, TEXTO, true)
	var r := Rect2(600, 446, 210, 56)
	casilla(r)
	Dibujo.texto(self, "Cruzar  →", r.get_center(), 18, TEXTO, true, true)
