## Base común de las tres variantes de máquina de Turing.
##
##   M = (Q, Σ, Γ, δ, q0, B, q_acepta, q_rechaza)
##
## La lógica no depende de nodos ni escenas de Godot: se puede probar con
## `godot --headless -s res://pruebas/pruebas_turing.gd`.
##
## Convención: si no hay transición definida para la configuración actual, la
## máquina se detiene en el estado de rechazo (función δ parcial).
class_name MaquinaTuring
extends RefCounted

const MOVIMIENTOS := ["L", "R", "S"]

var nombre: String
var tipo := "estandar"          ## "estandar" | "multicinta" | "multipista"
var estados: Array
var alfabeto_entrada: Array
var alfabeto_cinta: Array
var blanco := "_"
var delta := {}                 ## clave "q|símbolos" -> transición
var inicial: String
var acepta: String
var rechaza: String
var explicacion_estados := {}   ## estado -> texto breve para la interfaz

var estado: String
var pasos := 0
var ultima := {}                ## la última transición ejecutada
var historial: Array = []       ## transiciones ejecutadas (las últimas 200)
var error := ""
var usa_gemas := false          ## la interfaz dibuja R, Z, E, A como gemas


func _configurar(p_nombre: String, p_estados: Array, p_entrada: Array, p_cinta: Array,
		p_delta: Dictionary, p_inicial: String, p_acepta: String, p_rechaza: String,
		p_blanco := "_") -> void:
	nombre = p_nombre
	estados = p_estados.duplicate()
	alfabeto_entrada = p_entrada.duplicate()
	alfabeto_cinta = p_cinta.duplicate()
	delta = p_delta.duplicate(true)
	inicial = p_inicial
	acepta = p_acepta
	rechaza = p_rechaza
	blanco = p_blanco
	estado = inicial
	error = validar()
	if error != "":
		push_error(error)


## Comprobaciones de la definición formal. Devuelve "" si todo es correcto.
func validar() -> String:
	for q in [inicial, acepta, rechaza]:
		if not q in estados:
			return "%s: el estado %s no está en Q" % [nombre, q]
	if acepta == rechaza:
		return "%s: el estado de aceptación y el de rechazo deben ser distintos" % nombre
	if not blanco in alfabeto_cinta:
		return "%s: el blanco debe pertenecer a Γ" % nombre
	if blanco in alfabeto_entrada:
		return "%s: el blanco no puede pertenecer a Σ" % nombre
	for s in alfabeto_entrada:
		if not s in alfabeto_cinta:
			return "%s: Σ debe estar contenido en Γ (falta %s)" % [nombre, s]
	for clave in delta:
		var partes: PackedStringArray = clave.split("|")
		if partes.size() != 2 or not partes[0] in estados:
			return "%s: clave de δ inválida %s" % [nombre, clave]
		if partes[0] == acepta or partes[0] == rechaza:
			return "%s: no puede haber transiciones desde un estado de parada (%s)" % [nombre, clave]
		var e := _validar_transicion(partes[1], delta[clave])
		if e != "":
			return "%s: δ(%s): %s" % [nombre, clave, e]
	return ""


## Cada variante valida la forma de sus transiciones.
func _validar_transicion(_leido: String, _t) -> String:
	return ""


func detenida() -> bool:
	return estado == acepta or estado == rechaza


func resultado() -> String:
	if estado == acepta:
		return "ACEPTA"
	if estado == rechaza:
		return "RECHAZA"
	return "EN EJECUCIÓN"


## Ejecuta hasta detenerse o hasta `max_pasos`. Devuelve el resultado.
func ejecutar(max_pasos := 10000) -> String:
	while not detenida() and pasos < max_pasos:
		paso()
	return resultado() if detenida() else "SIN DETENERSE"


func _registrar(t: Dictionary) -> void:
	ultima = t
	historial.append(t)
	if historial.size() > 200:
		historial = historial.slice(-200)
	pasos += 1


## Un paso de la máquina. Lo implementa cada variante.
func paso() -> Dictionary:
	return {}


func _simbolo_valido(s: String) -> bool:
	return s in alfabeto_cinta
