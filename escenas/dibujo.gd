## Utilidades de dibujo compartidas por las capas.
class_name Dibujo
extends RefCounted

const FUENTE_UI := preload("res://assets/fuentes/DejaVuSans.ttf")

static var _negrita: FontVariation


static func fuente(negrita := false) -> Font:
	if not negrita:
		return FUENTE_UI
	if _negrita == null:
		_negrita = FontVariation.new()
		_negrita.base_font = FUENTE_UI
		_negrita.variation_embolden = 0.9
	return _negrita


## Escribe texto. Con `centro` la posición es el centro del texto; si no, la
## esquina superior izquierda.
static func texto(ci: CanvasItem, s: String, p: Vector2, tam := 18, color := Config.TEXTO,
		centro := false, negrita := false, sombra := true) -> void:
	var f := fuente(negrita)
	var ancho := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var base := p
	if centro:
		base = Vector2(p.x - ancho / 2.0, p.y + tam * 0.35)
	else:
		base = Vector2(p.x, p.y + tam * 0.8)
	if sombra:
		ci.draw_string(f, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.85))
	ci.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)


static func ancho_texto(s: String, tam: int, negrita := false) -> float:
	return fuente(negrita).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


## Cono de visión: abanico de triángulos cortado por las paredes (raycasting).
static func cono(ci: CanvasItem, mapa: Mapa, origen: Vector2, angulo: float, medio_grados: float,
		alcance: float, color: Color, ignorar := Vector2i(-99, -99)) -> void:
	var medio := deg_to_rad(medio_grados)
	var rayos := 26
	var anterior := Vector2.ZERO
	for i in rayos + 1:
		var a := angulo - medio + 2.0 * medio * i / rayos
		var p := mapa.rayo(origen, a, alcance, ignorar)
		if i > 0:
			ci.draw_primitive(PackedVector2Array([origen, anterior, p]),
					PackedColorArray([color, color, color]), PackedVector2Array())
		anterior = p


static func rombo(ci: CanvasItem, c: Vector2, w: float, h: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -h), c + Vector2(w, -h * 0.2), c + Vector2(0, h), c + Vector2(-w, -h * 0.2)]), color)


const COLOR_GEMA := {"R": Color(0.95, 0.25, 0.3), "Z": Color(0.3, 0.55, 1.0), "E": Color(0.25, 0.85, 0.45),
		"A": Color(1.0, 0.72, 0.2)}


## Dibuja una gema de la cerradura (R, Z, E, A; en minúscula = ya marcada por
## la máquina). Devuelve false si el símbolo no es una gema.
static func gema(ci: CanvasItem, s: String, r: Rect2) -> bool:
	var g := s.to_upper()
	if not COLOR_GEMA.has(g) or s.length() != 1:
		return false
	var marcada := s != g
	var col: Color = COLOR_GEMA[g]
	if marcada:
		col = col.darkened(0.55)
	var c := r.get_center()
	var w := minf(r.size.x, r.size.y) * 0.36
	var pts := PackedVector2Array([c + Vector2(0, -w), c + Vector2(w * 0.85, -w * 0.25), c + Vector2(0, w),
			c + Vector2(-w * 0.85, -w * 0.25)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c + Vector2(0, -w * 0.25), pts[3]]),
			col.lightened(0.35))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), col.lightened(0.5), 1.0)
	texto(ci, g, c + Vector2(0, w * 0.15), int(clampf(w * 0.75, 8, 14)), Color(0, 0, 0, 0.75) if not marcada
			else Color(1, 1, 1, 0.6), true, true, false)
	if marcada:
		ci.draw_line(c + Vector2(w * 0.3, w * 0.75), c + Vector2(w * 0.6, w * 1.05), Color(0.6, 1.0, 0.7), 2.0)
		ci.draw_line(c + Vector2(w * 0.6, w * 1.05), c + Vector2(w * 1.15, w * 0.45), Color(0.6, 1.0, 0.7), 2.0)
	return true


## Siluetas de las fichas jugables. La forma identifica cada tipo sin color.
static func ficha_juego(ci: CanvasItem, gema: String, centro: Vector2, tam: float) -> void:
	var perfil := {
		"R": [Vector2(0, -1), Vector2(0.82, 0), Vector2(0, 1), Vector2(-0.82, 0)],
		"Z": [Vector2(-0.76, -0.76), Vector2(0.76, -0.76), Vector2(0.76, 0.76), Vector2(-0.76, 0.76)],
		"E": [Vector2(0, -1), Vector2(0.93, 0.66), Vector2(-0.93, 0.66)],
		"A": [Vector2(-0.55, -0.79), Vector2(0.55, -0.79), Vector2(0.94, 0), Vector2(0.55, 0.79),
			Vector2(-0.55, 0.79), Vector2(-0.94, 0)],
		"F": [Vector2(0, -1), Vector2(0.82, 0), Vector2(0, 1), Vector2(-0.82, 0)],
	}
	var forma: Array = perfil[gema]
	var puntos := PackedVector2Array()
	for p: Vector2 in forma:
		puntos.append(centro + p * tam * 0.46)
	var col: Color = COLOR_GEMA.get(gema, Color(0.55, 0.57, 0.66))
	ci.draw_colored_polygon(puntos, col.darkened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([puntos[0], puntos[1], centro, puntos[-1]]), col.lightened(0.26))
	puntos.append(puntos[0])
	ci.draw_polyline(puntos, col.lightened(0.48), 2, true)
	if gema == "F":
		ci.draw_polyline(PackedVector2Array([centro + Vector2(0, -0.40) * tam,
				centro + Vector2(-0.12, -0.08) * tam, centro + Vector2(0.13, 0.04) * tam,
				centro + Vector2(0, 0.40) * tam]), Config.HUD_FONDO, 3, true)
