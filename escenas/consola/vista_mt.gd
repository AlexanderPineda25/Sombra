## Dibuja cualquier máquina de Turing (estándar, multicinta o multipista):
## cintas o pistas, cabezales, estado y la última transición.
## Se usa en la consola F1 y en los tutoriales.
class_name VistaMT
extends Control

const T := preload("res://escenas/consola/tema.gd")

var maquina: MaquinaTuring
var nombres: Array = []           ## nombre de cada cinta / pista (opcional)
var titulo := ""
var compacta := false             ## sin línea de transición ni estado (para tarjetas pequeñas)


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


# --- acceso genérico a las tres variantes ----------------------------------- #
static func num_filas(m: MaquinaTuring) -> int:
	if m is MTMulticinta:
		return (m as MTMulticinta).k
	if m is MTMultipista:
		return (m as MTMultipista).k
	return 1


static func simbolo(m: MaquinaTuring, fila: int, pos: int) -> String:
	if m is MTMulticinta:
		return (m as MTMulticinta).cintas[fila].leer_en(pos)
	if m is MTMultipista:
		return (m as MTMultipista).leer_en(pos)[fila]
	return (m as MTEstandar).cinta.leer_en(pos)


static func cabezales(m: MaquinaTuring) -> Array:
	if m is MTMulticinta:
		var r := []
		for c in (m as MTMulticinta).cintas:
			r.append(c.cabezal)
		return r
	if m is MTMultipista:
		return [(m as MTMultipista).cabezal]
	return [(m as MTEstandar).cinta.cabezal]


static func limites(m: MaquinaTuring) -> Array:
	var a := 0
	var b := 0
	if m is MTMulticinta:
		for c in (m as MTMulticinta).cintas:
			var l: Array = c.limites()
			a = mini(a, l[0])
			b = maxi(b, l[1])
	elif m is MTMultipista:
		var l: Array = (m as MTMultipista).limites()
		a = l[0]
		b = l[1]
	else:
		var l: Array = (m as MTEstandar).cinta.limites()
		a = l[0]
		b = l[1]
	for h in cabezales(m):
		a = mini(a, h)
		b = maxi(b, h)
	return [a, b]


static func texto_simbolos(s) -> String:
	if s is Array:
		return "(" + ",".join(PackedStringArray(s)) + ")"
	return str(s)


## δ(q, a) = (q', b, M) de la última transición, en una línea.
static func formato_transicion(u: Dictionary) -> String:
	if u.is_empty():
		return "Aún no ha dado ningún paso."
	if not u.get("definida", true):
		return "δ(%s, %s) no está definida → RECHAZA" % [u["estado"], texto_simbolos(u["leido"])]
	return "δ(%s, %s) = (%s, %s, %s)" % [u["estado"], texto_simbolos(u["leido"]), u["nuevo"],
			texto_simbolos(u["escrito"]), texto_simbolos(u["mov"])]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, T.PANEL)
	draw_rect(r, T.BORDE, false, 1.0)
	if maquina == null:
		Dibujo.texto(self, "Sin ejecuciones todavía.", r.get_center(), 14, T.SUAVE, true, false, false)
		return
	var m := maquina
	var y := 8.0
	var cab := titulo if titulo != "" else m.nombre
	Dibujo.texto(self, cab, Vector2(10, y), 14, T.CIAN, false, true, false)
	var res := m.resultado()
	var col_res := T.VERDE if res == "ACEPTA" else (T.ROJO if res == "RECHAZA" else T.AMBAR)
	var est := "%s · %d pasos" % [m.estado, m.pasos]
	if res != "":
		est = "%s · %s · %d pasos" % [res, m.estado, m.pasos]
	Dibujo.texto(self, est, Vector2(size.x - 10 - Dibujo.ancho_texto(est, 13, true), y), 13, col_res, false, true, false)
	y += 26
	var n := num_filas(m)
	var multipista := m is MTMultipista
	var lim := limites(m)
	var desde: int = lim[0] - 1
	var hasta: int = lim[1] + 2
	var etiqueta := 104.0 if not compacta else 60.0
	var reserva := 58.0 if not compacta else 4.0
	var disponible_alto := size.y - y - reserva
	var hueco := 0.0 if multipista else 10.0
	var alto := clampf((disponible_alto - hueco * (n - 1)) / n, 16.0, 44.0)
	var celda := clampf((size.x - etiqueta - 20) / float(hasta - desde + 1), 12.0, 42.0)
	var visibles := int((size.x - etiqueta - 20) / celda)
	if hasta - desde + 1 > visibles:
		# centra la ventana en el primer cabezal
		var h: int = cabezales(m)[0]
		desde = h - visibles / 2
		hasta = desde + visibles - 1
	var x0 := etiqueta + 10
	var tam := int(clampf(alto * 0.5, 10, 20))
	# centra verticalmente el bloque de cintas en el espacio libre
	y += maxf(0.0, (disponible_alto - (n * alto + (n - 1) * hueco)) / 2.0)
	for f in n:
		var fy := y + f * (alto + hueco)
		var nombre: String = nombres[f] if f < nombres.size() else (("Pista %d" if multipista else "Cinta %d") % (f + 1))
		if n == 1 and nombres.is_empty():
			nombre = "Cinta"
		var tam_n := mini(tam - 1, 13)
		Dibujo.texto(self, nombre, Vector2(10, fy + alto / 2 - tam_n * 0.5), tam_n, T.SUAVE, false, false, false)
		for pos in range(desde, hasta + 1):
			var c := Rect2(x0 + (pos - desde) * celda, fy, celda - 2, alto - (0 if multipista else 0))
			var s := simbolo(m, f, pos)
			var fondo := Color(0.03, 0.06, 0.09)
			if s == "!" or s == "X":
				fondo = Color(0.3, 0.07, 0.07)
			elif s == "*" or s == ".":
				fondo = Color(0.05, 0.18, 0.12)
			draw_rect(c, fondo)
			draw_rect(c, Color(T.CIAN, 0.18), false, 1.0)
			var col := T.TEXTO if s != m.blanco else T.APAGADO
			if not (m.usa_gemas and Dibujo.gema(self, s, c)):
				Dibujo.texto(self, s if s != m.blanco else "␣", c.get_center(), tam, col, true, true, false)
	# cabezales
	var cabs := cabezales(m)
	if multipista:
		var hx: float = x0 + (cabs[0] - desde) * celda
		var total := n * alto
		draw_rect(Rect2(hx - 2, y - 3, celda + 2, total + 6), T.AMBAR, false, 2.5)
		_flecha(Vector2(hx + celda / 2 - 1, y - 4))
	else:
		for i in cabs.size():
			var fy := y + i * (alto + hueco)
			var hx: float = x0 + (cabs[i] - desde) * celda
			draw_rect(Rect2(hx - 2, fy - 2, celda + 2, alto + 4), T.AMBAR, false, 2.0)
	if not compacta:
		var ty := size.y - 24
		if m.explicacion_estados.has(m.estado):
			Dibujo.texto(self, "%s: %s" % [m.estado, m.explicacion_estados[m.estado]], Vector2(10, ty - 22), 13,
					T.TEXTO, false, false, false)
		Dibujo.texto(self, formato_transicion(m.ultima), Vector2(10, ty), 13, T.AMBAR, false, true, false)


func _flecha(punta: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(-6, -7), punta + Vector2(6, -7)]), T.AMBAR)
