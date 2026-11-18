## Una cinta trae las joyas y cada bolsa avanza solo cuando recibe una.
class_name MJBoveda
extends Minijuego

const IZQUIERDA := Rect2(74, 274, 223, 174)
const DERECHA := Rect2(663, 274, 223, 174)
const DESCARTE := Rect2(383, 444, 194, 62)

var entrada := ""
var izquierda := ""
var derecha := ""
var indice := 0
var cantidad := 0
var llegada := 0.0
var espera := 0.0
var salida := ""
var joya_saliente := ""
var anim_salida := 0.0


func _preparar() -> void:
	entrada = desafio.solucion_filas[0]
	cantidad = entrada.length() / 2
	for i in cantidad:
		entrada[i * 2 + 1] = "_"
	izquierda = ""
	derecha = ""
	indice = 0
	llegada = 0.0
	espera = 0.0
	anim_salida = 0.0
	if not desafio.resuelto:
		desafio.filas[0]["contenido"] = entrada
		desafio.filas[1]["contenido"] = ""
		desafio.filas[2]["contenido"] = ""
		desafio.construir()


func _actualizar(dt: float) -> void:
	var velocidad := 1.25 if accesible else minf(4.0, 2.35 + indice * 0.18)
	llegada = minf(1.0, llegada + dt * velocidad)
	if fase == "juego" and llegada >= 1.0 and _limite() > 0.0:
		espera += dt
		if espera >= _limite():
			espera = 0.0
			llegada = 0.0
			detectado("La cinta se atascó. Elige el destino de esta joya.", false)
	else:
		espera = 0.0
	anim_salida = maxf(0.0, anim_salida - dt)
	if fase == "verificando" and anim_salida == 0.0:
		confirmar([entrada, izquierda, derecha])


func _limite() -> float:
	if accesible or ensayo or desafio.dificultad == Ajustes.Modo.FACIL:
		return 0.0
	return 5.0 if desafio.dificultad == Ajustes.Modo.MEDIO else 3.0


func _tecla(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_LEFT, KEY_A: enviar("<")
		KEY_RIGHT, KEY_D: enviar(">")
		KEY_DOWN, KEY_S: enviar("v")
		_: return false
	return true


func _clic(p: Vector2) -> void:
	if IZQUIERDA.has_point(p):
		enviar("<")
	elif DERECHA.has_point(p):
		enviar(">")
	elif DESCARTE.has_point(p):
		enviar("v")


func enviar(destino: String) -> void:
	if fase != "juego" or indice >= cantidad or anim_salida > 0.0:
		return
	var g := gema_actual()
	var a := izquierda + (g if destino == "<" else "")
	var b := derecha + (g if destino == ">" else "")
	entrada[indice * 2 + 1] = destino
	var hasta := 2 * (indice + 1)
	var intento := desafio.ejecutar_hasta([entrada, a, b], func(m: MTMulticinta): return m.cintas[0].cabezal >= hasta)
	match intento["resultado"]:
		"EN CURSO":
			indice += 1
			izquierda = a
			derecha = b
			ensayo = false
			llegada = 0.0
			joya_saliente = g
			salida = destino
			anim_salida = 0.24
			sonar("joya", 1.05)
			if indice == cantidad:
				fase = "verificando"
		"RECHAZA":
			entrada[indice * 2 + 1] = "_"
			if g == "F":
				detectado("La joya está rajada. Usa Descartar  ↓")
			else:
				detectado("Esa bolsa no coincide. Busca la misma figura.")
		_:
			entrada[indice * 2 + 1] = "_"
			avisar("No se pudo comprobar el destino. Reabre la terminal.", AMBAR)


func gema_actual() -> String:
	return entrada[indice * 2] if indice < cantidad else ""


func _progreso() -> String:
	return "%d/%d joyas" % [indice, cantidad]


func _ayuda() -> String:
	return "← Bolsa izquierda   ·   ↓ Descartar   ·   → Bolsa derecha"


func _mensaje_exito() -> String:
	return "Bóveda abierta"


func _dibujar_juego() -> void:
	suelo(Rect2i(64, 181, 13, 5))
	if _limite() > 0.0 and fase == "juego":
		var f := 1.0 - espera / _limite()
		draw_rect(Rect2(400, 161, 160, 8), Color(SUAVE, 0.3))
		draw_rect(Rect2(400, 161, 160 * f, 8), ROJO if f < 0.3 else AMBAR)
	var r := Rect2(435, 192, 90, 236)
	draw_rect(r, Color(0.08, 0.09, 0.13))
	draw_rect(r, SUAVE, false, 2)
	for y in 8:
		draw_line(Vector2(r.position.x + 2, 195 + y * 32), Vector2(r.end.x - 2, 195 + y * 32),
				Color(SUAVE, 0.36), 2)
	var demo := fase == "intro"
	var curso := fposmod(tiempo, 2.4) / 2.4 if demo else llegada
	var g := gema_actual()
	var destino := ProgramasTuring.destino_botin(g)
	_bolsa(IZQUIERDA, "←  Bolsa izquierda", ["R", "A"], izquierda, (demo or ensayo) and destino == "<")
	_bolsa(DERECHA, "Bolsa derecha  →", ["Z", "E"], derecha, (demo or ensayo) and destino == ">")
	casilla(DESCARTE, (demo or ensayo) and destino == "v")
	ficha("F", DESCARTE.position + Vector2(26, 31), 32)
	Dibujo.texto(self, "Descartar  ↓", DESCARTE.get_center() + Vector2(16, 0), 17, TEXTO, true, true)
	draw_rect(Rect2(446, 358, 68, 65), Color(AMBAR, 0.52), false, 2)
	if g != "":
		var p := Vector2(480, lerpf(222, 390, curso))
		if demo and curso > 0.68:
			p = Vector2(480, 390).lerp(_boca(destino), (curso - 0.68) / 0.32)
		ficha(g, p, 54)
	if anim_salida > 0.0:
		var t := 1.0 - anim_salida / 0.24
		ficha(joya_saliente, Vector2(480, 390).lerp(_boca(salida), t), 38)


func _boca(destino: String) -> Vector2:
	match destino:
		"<": return IZQUIERDA.get_center()
		">": return DERECHA.get_center()
		_: return DESCARTE.get_center()


func _bolsa(r: Rect2, titulo: String, tipos: Array, contenido: String, foco: bool) -> void:
	casilla(r, foco)
	Dibujo.texto(self, titulo, r.get_center() - Vector2(0, 62), 17, TEXTO, true, true)
	ficha(tipos[0], r.get_center() - Vector2(26, 18), 37)
	ficha(tipos[1], r.get_center() + Vector2(26, -18), 37)
	for i in contenido.length():
		ficha(contenido[i], r.position + Vector2(25 + (i % 6) * 32, 112 + (i / 6) * 34), 26)
