## Niveles del juego.
##
## Cada nivel está escrito en el lenguaje SOMBRA (res://niveles/nivelN.sombra)
## y se compila al iniciar: análisis léxico con un AFD generado desde
## expresiones regulares, análisis sintáctico LL(1) y análisis semántico
## (ver lenguaje/compilador.gd). Si un archivo tiene errores, el juego los
## muestra en la consola F1 › Lenguaje y usa el nivel 1 como respaldo.
##
## Formato generado (el que usa Partida):
##   titulo, mapa (filas), guardias [{puntos, acciones}], terminales [[casilla, desafío]],
##   radares [casilla], camaras [[casilla, grados]]
class_name Niveles
extends RefCounted

const CARPETA := "res://niveles/"
const ARCHIVOS := ["nivel1.sombra", "nivel2.sombra", "nivel3.sombra"]

# Anclajes sobre muros y orientación hacia corredores. Se añaden por orden.
const CAMARAS_REFUERZO := [
	[[Vector2i(12, 6), 90], [Vector2i(25, 6), -90], [Vector2i(17, 16), 0]],
	[[Vector2i(22, 11), -90], [Vector2i(19, 7), 90], [Vector2i(9, 17), 0]],
	[[Vector2i(11, 7), 90], [Vector2i(21, 8), 90], [Vector2i(25, 15), 90]],
]

static var _compilados: Array = []


static func cantidad() -> int:
	return ARCHIVOS.size()


static func compilado(i: int) -> Compilador:
	if _compilados.is_empty():
		for archivo in ARCHIVOS:
			_compilados.append(Compilador.compilar(leer(CARPETA + archivo)))
	return _compilados[i]


static func leer(ruta: String) -> String:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Datos del nivel i, listos para Partida.
static func datos(i: int) -> Dictionary:
	var c := compilado(i)
	var d: Dictionary
	if c.ok():
		d = c.datos.duplicate(true)
	else:
		for e in c.errores:
			push_error("%s:%s" % [ARCHIVOS[i], e])
		d = compilado(0).datos.duplicate(true)
	d["nombre"] = "Nivel %d · %s" % [i + 1, d["titulo"]]
	return d


## Reemplaza en memoria el nivel i por un programa compilado (consola F1).
static func sobrescribir(i: int, c: Compilador) -> void:
	compilado(i)
	_compilados[i] = c


## Vuelve a compilar el nivel i desde su archivo.
static func restaurar(i: int) -> void:
	compilado(i)
	_compilados[i] = Compilador.compilar(leer(CARPETA + ARCHIVOS[i]))
