## Cinta de una máquina de Turing: infinita en ambos sentidos.
##
## Solo se guardan las casillas que no tienen el símbolo blanco, así que la
## cinta puede crecer sin límite hacia la izquierda o la derecha.
class_name CintaTuring
extends RefCounted

var blanco: String
var celdas := {}          ## posición (int) -> símbolo (String)
var cabezal := 0


func _init(p_blanco := "_") -> void:
	blanco = p_blanco


## Escribe `simbolos` (String o Array) a partir de la posición `desde`.
func cargar(simbolos, desde := 0) -> void:
	celdas.clear()
	cabezal = 0
	var i := desde
	for s in simbolos:
		escribir_en(i, str(s))
		i += 1


func leer() -> String:
	return celdas.get(cabezal, blanco)


func leer_en(pos: int) -> String:
	return celdas.get(pos, blanco)


func escribir(s: String) -> void:
	escribir_en(cabezal, s)


func escribir_en(pos: int, s: String) -> void:
	if s == blanco:
		celdas.erase(pos)
	else:
		celdas[pos] = s


## L = izquierda, R = derecha, S = quieto.
func mover(m: String) -> void:
	match m:
		"L":
			cabezal -= 1
		"R":
			cabezal += 1


## [mínima, máxima] posición con contenido (o [0, -1] si está vacía).
func limites() -> Array:
	if celdas.is_empty():
		return [0, -1]
	var ks := celdas.keys()
	return [ks.min(), ks.max()]


## Contenido entre los límites, sin blancos a los extremos.
func contenido() -> String:
	var l := limites()
	var s := ""
	for i in range(l[0], l[1] + 1):
		s += leer_en(i)
	return s


func copiar() -> CintaTuring:
	var c := CintaTuring.new(blanco)
	c.celdas = celdas.duplicate()
	c.cabezal = cabezal
	return c
