## Mapa de casillas: lectura del nivel, caminos (BFS) y línea de visión.
##
## Leyenda:  # pared   . piso   P jugador   J joya   X salida
##           H planta (escondite)   C cámara (pared con cámara)
##           T terminal   D puerta electrónica   L rejilla láser
class_name Mapa
extends RefCounted

const T := Config.TILE
const VECINOS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var filas: Array
var ancho: int
var alto: int
var paredes := {}            ## conjunto: Vector2i -> true
var plantas := {}
var joyas: Array = []
var salida := Vector2i(-1, -1)
var inicio := Vector2i(-1, -1)
var terminales: Array = []   ## casillas con terminal (se puede caminar sobre ellas)
var puertas: Array = []      ## casillas de puerta electrónica
var puertas_abiertas := false
var laseres: Array = []      ## casillas cruzadas por la rejilla láser
var error := ""


func _init(p_filas: Array) -> void:
	filas = p_filas
	alto = filas.size()
	ancho = filas[0].length()
	for y in alto:
		var fila: String = filas[y]
		if fila.length() != ancho:
			error = "fila %d mide %d, se esperaban %d" % [y, fila.length(), ancho]
		for x in fila.length():
			var c := fila[x]
			var t := Vector2i(x, y)
			match c:
				"#", "C":
					paredes[t] = true
				"H":
					plantas[t] = true
				"T":
					terminales.append(t)
				"D":
					puertas.append(t)
					paredes[t] = true      # cerrada hasta resolver su terminal
				"L":
					laseres.append(t)
				"J":
					joyas.append(t)
				"X":
					salida = t
				"P":
					inicio = t
	if inicio.x < 0 or salida.x < 0:
		error = "el mapa necesita P y X"


# --- puertas -------------------------------------------------------------- #
func abrir_puertas() -> void:
	puertas_abiertas = true
	for t in puertas:
		paredes.erase(t)


func es_puerta(t: Vector2i) -> bool:
	return t in puertas


# --- casillas ----------------------------------------------------------- #
func es_pared(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= ancho or t.y >= alto:
		return true
	return paredes.has(t)


func caminable(t: Vector2i) -> bool:
	return not es_pared(t)


func vecinos(t: Vector2i) -> Array:
	var r := []
	for d in VECINOS:
		var n: Vector2i = t + d
		if caminable(n):
			r.append(n)
	return r


static func tile_de(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


static func centro(t: Vector2i) -> Vector2:
	return Vector2(t.x * T + T / 2.0, t.y * T + T / 2.0)


# --- caminos (búsqueda en anchura) --------------------------------------- #
## Camino más corto de origen a destino (sin incluir el origen).
## Devuelve [] si origen == destino y null si no hay camino.
func bfs(origen: Vector2i, destino: Vector2i):
	if origen == destino:
		return []
	if not caminable(destino):
		return null
	var previo := {origen: origen}
	var cola := [origen]
	var i := 0
	while i < cola.size():
		var t: Vector2i = cola[i]
		i += 1
		if t == destino:
			break
		for n in vecinos(t):
			if not previo.has(n):
				previo[n] = t
				cola.append(n)
	if not previo.has(destino):
		return null
	var camino := []
	var t := destino
	while t != origen:
		camino.append(t)
		t = previo[t]
	camino.reverse()
	return camino


func alcanzables_desde(origen: Vector2i) -> Dictionary:
	var vistos := {origen: true}
	var cola := [origen]
	var i := 0
	while i < cola.size():
		var t: Vector2i = cola[i]
		i += 1
		for n in vecinos(t):
			if not vistos.has(n):
				vistos[n] = true
				cola.append(n)
	return vistos


## Casilla caminable al azar a menos de `radio` casillas de `centro`,
## alcanzable caminando desde él (búsqueda en anchura acotada).
func casilla_cercana(centro: Vector2i, radio: float, rng: RandomNumberGenerator) -> Vector2i:
	if not caminable(centro):
		for d in VECINOS + [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if caminable(centro + d):
				centro = centro + d
				break
	if not caminable(centro):
		return centro
	var vistos := {centro: true}
	var cola := [centro]
	var i := 0
	while i < cola.size():
		var t: Vector2i = cola[i]
		i += 1
		for n in vecinos(t):
			if not vistos.has(n) and Vector2(n - centro).length() <= radio:
				vistos[n] = true
				cola.append(n)
	return cola[rng.randi() % cola.size()]


## Une los puntos de patrulla en un circuito cerrado de casillas.
func ruta_cerrada(puntos: Array) -> Array:
	var ruta := [puntos[0]]
	for k in puntos.size():
		var a: Vector2i = puntos[k]
		var b: Vector2i = puntos[(k + 1) % puntos.size()]
		var tramo = bfs(a, b)
		if tramo == null:
			push_error("no hay camino de %s a %s" % [a, b])
			return ruta
		ruta.append_array(tramo)
	ruta.pop_back()               # el último repite el primero
	return ruta


# --- visión -------------------------------------------------------------- #
## true si ninguna pared corta el segmento p1-p2 (en píxeles).
func linea_libre(p1: Vector2, p2: Vector2, ignorar := Vector2i(-99, -99)) -> bool:
	var dist := p1.distance_to(p2)
	var pasos := maxi(1, int(dist / (T / 4.0)))
	for i in range(1, pasos):
		var t := tile_de(p1.lerp(p2, float(i) / pasos))
		if t != ignorar and es_pared(t):
			return false
	return true


## Punto donde un rayo choca con una pared o alcanza su largo.
func rayo(origen: Vector2, angulo: float, alcance: float, ignorar := Vector2i(-99, -99)) -> Vector2:
	var dir := Vector2(cos(angulo), sin(angulo))
	var paso := T / 5.0
	var d := 0.0
	while d < alcance:
		d += paso
		var p := origen + dir * d
		var t := tile_de(p)
		if t != ignorar and es_pared(t):
			return p - dir * paso * 0.5
	return origen + dir * alcance
