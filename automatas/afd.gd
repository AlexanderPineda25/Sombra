## Autómata Finito Determinista (AFD) genérico.
##
## Definición formal: M = (Q, Σ, δ, q0, F)
##   Q  -> estados
##   Σ  -> alfabeto (aquí: eventos del juego)
##   δ  -> función de transición total  δ: Q × Σ -> Q   (delta[q][s] = q')
##   q0 -> estado inicial
##   F  -> estados de aceptación
##
## Cada estado puede tener una "salida" (como en una máquina de Moore): la
## acción que ejecuta la entidad mientras está en ese estado.
## Los guardias, las cámaras y el flujo de pantallas son instancias de esta
## misma clase.
class_name AFD
extends RefCounted

var nombre: String
var estados: Array
var alfabeto: Array
var delta: Dictionary
var inicial: String
var finales: Array
var salidas: Dictionary
var actual: String
var historial: Array = []
var ultimas_vueltas: Array = []   ## particiones de la última minimización
var error: String = ""            ## vacío si el AFD es válido


func _init(p_nombre: String, p_estados: Array, p_alfabeto: Array, p_delta: Dictionary,
		p_inicial: String, p_finales: Array = [], p_salidas: Dictionary = {}) -> void:
	nombre = p_nombre
	estados = p_estados.duplicate()
	alfabeto = p_alfabeto.duplicate()
	delta = p_delta.duplicate(true)
	inicial = p_inicial
	finales = p_finales.duplicate()
	salidas = p_salidas.duplicate()
	error = validar()
	if error != "":
		push_error(error)
	actual = inicial
	historial = [inicial]


# ---------------------------------------------------------------------- #
# Validación
# ---------------------------------------------------------------------- #
## Comprueba que δ sea una función total sobre Q × Σ. Devuelve "" si es válida.
func validar() -> String:
	if not inicial in estados:
		return "%s: estado inicial desconocido" % nombre
	for f in finales:
		if not f in estados:
			return "%s: estado final desconocido %s" % [nombre, f]
	for q in estados:
		for s in alfabeto:
			if not delta.has(q) or not delta[q].has(s):
				return "%s: falta δ(%s, %s). El AFD debe ser completo." % [nombre, q, s]
			if not delta[q][s] in estados:
				return "%s: δ(%s, %s) lleva a un estado que no existe" % [nombre, q, s]
	if not salidas.is_empty():
		for q in estados:
			if not salidas.has(q):
				return "%s: el estado %s no tiene salida" % [nombre, q]
	return ""


# ---------------------------------------------------------------------- #
# Ejecución
# ---------------------------------------------------------------------- #
func transicion(estado: String, simbolo: String) -> String:
	return delta[estado][simbolo]


## Lee un símbolo (evento) y avanza el estado actual.
func paso(simbolo: String) -> String:
	if not simbolo in alfabeto:
		push_error("%s: '%s' no está en Σ" % [nombre, simbolo])
		return actual
	actual = delta[actual][simbolo]
	historial.append(actual)
	if historial.size() > 200:
		historial = historial.slice(-200)
	return actual


func reiniciar() -> void:
	actual = inicial
	historial = [inicial]


## δ extendida: estado al que se llega con la cadena, sin cambiar el actual.
## La cadena puede ser un String ("rvpt") o un Array (["enter", "esc"]).
func procesar(cadena, desde: String = "") -> String:
	var q := inicial if desde == "" else desde
	for s in cadena:
		q = delta[q][s]
	return q


func acepta(cadena) -> bool:
	return procesar(cadena) in finales


func salida() -> String:
	return salidas.get(actual, "")


# ---------------------------------------------------------------------- #
# Minimización (refinamiento de particiones)
# ---------------------------------------------------------------------- #
func alcanzables() -> Array:
	var vistos := [inicial]
	var pendientes := [inicial]
	while not pendientes.is_empty():
		var q = pendientes.pop_back()
		for s in alfabeto:
			var d = delta[q][s]
			if not d in vistos:
				vistos.append(d)
				pendientes.append(d)
	return vistos


## Devuelve un AFD equivalente con el mínimo número de estados.
##  1. Se eliminan los estados inalcanzables.
##  2. Partición inicial: por salida si el autómata tiene salidas (Moore);
##     si no, por final / no final.
##  3. Se refina: dos estados siguen juntos solo si, con cada símbolo, llegan
##     al mismo bloque (misma "firma").
##  4. Se repite hasta que ninguna vuelta parta un bloque.
## `nombres` renombra los bloques fusionados: {"A/B": "NUEVO"}.
func minimizar(nombres: Dictionary = {}) -> AFD:
	var alc := alcanzables()
	var vivos := []
	for q in estados:
		if q in alc:
			vivos.append(q)

	var bloques := {}
	for q in vivos:
		var clave = salidas[q] if not salidas.is_empty() else (q in finales)
		if not bloques.has(clave):
			bloques[clave] = []
		bloques[clave].append(q)
	var particion: Array = bloques.values()
	ultimas_vueltas = [particion.duplicate(true)]

	while true:
		var indice := {}
		for i in particion.size():
			for q in particion[i]:
				indice[q] = i
		var nueva := []
		for b in particion:
			var grupos := {}
			var orden := []
			for q in b:
				var firma := []
				for s in alfabeto:
					firma.append(indice[delta[q][s]])
				var k := str(firma)
				if not grupos.has(k):
					grupos[k] = []
					orden.append(k)
				grupos[k].append(q)
			for k in orden:
				nueva.append(grupos[k])
		ultimas_vueltas.append(nueva.duplicate(true))
		if nueva.size() == particion.size():
			break
		particion = nueva

	var nombre_de := {}
	var nuevos_estados := []
	for b in particion:
		var unido := "/".join(PackedStringArray(b))
		var n: String = nombres.get(unido, b[0] if b.size() == 1 else unido)
		nuevos_estados.append(n)
		for q in b:
			nombre_de[q] = n

	var nuevo_delta := {}
	var nuevas_salidas := {}
	for b in particion:
		var rep = b[0]
		var n = nombre_de[rep]
		nuevo_delta[n] = {}
		for s in alfabeto:
			nuevo_delta[n][s] = nombre_de[delta[rep][s]]
		if not salidas.is_empty():
			nuevas_salidas[n] = salidas[rep]
	var nuevos_finales := []
	for q in finales:
		if nombre_de.has(q) and not nombre_de[q] in nuevos_finales:
			nuevos_finales.append(nombre_de[q])

	return AFD.new(nombre + " (mínimo)", nuevos_estados, alfabeto, nuevo_delta,
			nombre_de[inicial], nuevos_finales, nuevas_salidas)


## Número de transiciones definidas en δ.
func num_transiciones() -> int:
	var n := 0
	for q in delta:
		n += delta[q].size()
	return n


## Tabla de transición en texto (consola o informe).
func tabla() -> String:
	var ancho := 0
	for q in estados:
		ancho = maxi(ancho, q.length())
	ancho += 4
	var cab := "δ".rpad(ancho)
	for s in alfabeto:
		cab += str(s).rpad(ancho)
	var filas := [cab]
	for q in estados:
		var marca: String = ("→" if q == inicial else " ") + ("*" if q in finales else " ")
		var fila: String = (marca + q).rpad(ancho)
		for s in alfabeto:
			fila += str(delta[q][s]).rpad(ancho)
		filas.append(fila)
	return "\n".join(PackedStringArray(filas))
