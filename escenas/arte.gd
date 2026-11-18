## Recursos gráficos compartidos (texturas generadas por herramientas/generar_arte.py).
class_name Arte
extends RefCounted

# índices de la hoja assets/tiles/museo.png (casillas de 64 px, 8 por fila)
const PISO_CLARO := 0
const PISO_OSCURO := 1
const PARED := 2
const PARED_FRENTE := 3
const PINTURA := 4            # 4, 5 y 6
const PEDESTAL := 7
const VITRINA := 8
const PLANTA := 9
const SALIDA_CERRADA := 10
const SALIDA_ABIERTA := 11
const PUERTA_CERRADA := 12
const PUERTA_ABIERTA := 13
const TERMINAL := 14
const TERMINAL_RESUELTA := 15
const EMISOR_LASER := 16
const ALFOMBRA := 17

# filas de las hojas de personajes (8 cuadros de 64 px por fila)
const LADRON_FILAS := {
	"idle": [0, 4], "caminar": [1, 8], "correr": [2, 8], "agachado": [3, 4],
	"agachado_caminar": [4, 8], "lanzar": [5, 4], "recoger": [6, 4], "interactuar": [7, 4],
}
const GUARDIA_FILAS := {"idle": [0, 4], "caminar": [1, 8], "correr": [2, 8]}

static var museo: Texture2D = preload("res://assets/tiles/museo.png")
static var ladron: Texture2D = preload("res://assets/sprites/ladron.png")
static var guardias: Array = [
	preload("res://assets/sprites/guardia_0.png"),
	preload("res://assets/sprites/guardia_1.png"),
	preload("res://assets/sprites/guardia_2.png"),
]
static var camara: Texture2D = preload("res://assets/sprites/camara.png")
static var joyas: Texture2D = preload("res://assets/sprites/joyas.png")
static var moneda: Texture2D = preload("res://assets/sprites/moneda.png")
static var cono: Texture2D = preload("res://assets/luces/cono.png")
static var circulo: Texture2D = preload("res://assets/luces/circulo.png")


static func region(indice: int) -> Rect2:
	return Rect2((indice % 8) * 64, (indice / 8) * 64, 64, 64)


## Dibuja la casilla `indice` de la hoja del museo ocupando `destino`.
static func casilla(ci: CanvasItem, indice: int, destino: Rect2, color := Color.WHITE) -> void:
	ci.draw_texture_rect_region(museo, destino, region(indice), color)


static func joya(ci: CanvasItem, i: int, centro: Vector2, tam: float, color := Color.WHITE) -> void:
	ci.draw_texture_rect_region(joyas, Rect2(centro - Vector2(tam, tam) / 2, Vector2(tam, tam)),
			Rect2((i % 3) * 64, 0, 64, 64), color)
