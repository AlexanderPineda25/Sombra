## Colores y tema visual de la consola de seguridad (estilo terminal de museo).
class_name TemaConsola
extends RefCounted

const FONDO := Color(0.035, 0.055, 0.075)
const PANEL := Color(0.06, 0.09, 0.12)
const PANEL_2 := Color(0.08, 0.12, 0.16)
const BORDE := Color(0.20, 0.42, 0.50)
const CIAN := Color(0.30, 0.86, 1.0)
const VERDE := Color(0.35, 1.0, 0.58)
const ROJO := Color(1.0, 0.36, 0.32)
const AMBAR := Color(1.0, 0.78, 0.35)
const TEXTO := Color(0.86, 0.91, 0.95)
const SUAVE := Color(0.52, 0.62, 0.70)
const APAGADO := Color(0.25, 0.32, 0.38)

## Color de cada estado del guardia (coherente con los conos del juego).
const COLOR_ESTADO := {
	"PATRULLA": Color(0.45, 0.85, 0.65), "REGRESO": Color(0.55, 0.75, 0.95),
	"SOSPECHA": Color(1.0, 0.85, 0.35), "ALERTA": Color(1.0, 0.65, 0.3),
	"BUSQUEDA": Color(1.0, 0.55, 0.25), "PERSECUCION": Color(1.0, 0.33, 0.3),
	"REPOSO": Color(0.45, 0.85, 0.65), "AVISO": Color(1.0, 0.8, 0.3),
	"BARRIDO": Color(0.35, 1.0, 0.6), "ANALISIS": Color(0.3, 0.86, 1.0),
}

## Color de cada tipo de evento del registro.
const COLOR_EVENTO := {
	"deteccion": ROJO, "alerta": ROJO, "alarma": Color(1.0, 0.5, 0.35), "estado": AMBAR,
	"moneda": Color(1.0, 0.85, 0.4), "ruido": Color(0.85, 0.8, 1.0), "turing": CIAN, "radar": VERDE, "oculto": Color(0.55, 0.95, 0.6),
	"joya": Color(0.6, 0.95, 1.0),
}


static func caja(fondo: Color, borde := BORDE, grosor := 1, radio := 4, margen := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	return s


static func crear() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXTO)
	t.set_stylebox("panel", "Panel", caja(FONDO, FONDO, 0, 0))
	t.set_stylebox("panel", "PanelContainer", caja(PANEL))
	# pestañas
	t.set_stylebox("panel", "TabContainer", caja(FONDO, BORDE, 1, 0, 6))
	t.set_stylebox("tab_selected", "TabContainer", caja(PANEL_2, CIAN, 0, 0, 8))
	var sel: StyleBoxFlat = t.get_stylebox("tab_selected", "TabContainer")
	sel.border_width_bottom = 3
	t.set_stylebox("tab_unselected", "TabContainer", caja(FONDO, FONDO, 0, 0, 8))
	t.set_stylebox("tab_hovered", "TabContainer", caja(PANEL, PANEL, 0, 0, 8))
	t.set_stylebox("tabbar_background", "TabContainer", caja(Color(0.02, 0.035, 0.05), FONDO, 0, 0, 0))
	t.set_color("font_selected_color", "TabContainer", CIAN)
	t.set_color("font_unselected_color", "TabContainer", SUAVE)
	t.set_color("font_hovered_color", "TabContainer", TEXTO)
	# botones
	t.set_stylebox("normal", "Button", caja(PANEL_2, BORDE, 1, 4, 6))
	t.set_stylebox("hover", "Button", caja(Color(0.1, 0.17, 0.22), CIAN, 1, 4, 6))
	t.set_stylebox("pressed", "Button", caja(Color(0.12, 0.22, 0.28), CIAN, 2, 4, 6))
	t.set_stylebox("disabled", "Button", caja(FONDO, APAGADO, 1, 4, 6))
	t.set_stylebox("focus", "Button", caja(Color(0, 0, 0, 0), AMBAR, 1, 4, 6))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", CIAN)
	t.set_color("font_pressed_color", "Button", AMBAR)
	t.set_color("font_disabled_color", "Button", APAGADO)
	t.set_stylebox("normal", "RichTextLabel", caja(Color(0.02, 0.035, 0.05), BORDE, 1, 2, 8))
	t.set_color("default_color", "RichTextLabel", TEXTO)
	t.set_color("font_color", "CheckBox", TEXTO)
	t.set_stylebox("slider", "HSlider", caja(PANEL_2, BORDE, 1, 2, 2))
	t.set_stylebox("grabber_area", "HSlider", caja(Color(0.15, 0.5, 0.6), CIAN, 0, 2, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", caja(Color(0.2, 0.65, 0.75), CIAN, 0, 2, 2))
	return t
