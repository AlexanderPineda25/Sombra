## Autómata de pila (AP) de la ruta de regreso del guardia.
##
## Cuando un guardia abandona su ruta (oyó un ruido o vio al jugador), cada
## paso que da se apila. Para volver no necesita búsqueda de caminos: desapila
## los pasos y camina en la dirección opuesta. Está de vuelta exactamente
## cuando la pila queda vacía.
##
##   P = (Q, Σ, Γ, δ, q0, Z0, F)
##   Q  = {IDA, VUELTA}        Σ = {N, S, E, O}       Γ = {N, S, E, O, Z0}
##   q0 = IDA                  F = ∅ (acepta por pila vacía)
##
##   δ(IDA, m, X)           = (IDA, mX)     apila el paso m
##   δ(IDA, m, opuesto(m))  = (IDA, λ)      un paso de ida y vuelta se cancela
##   δ(IDA, λ, X)           = (VUELTA, X)   el guardia decide regresar
##   δ(VUELTA, λ, m)        = (VUELTA, λ)   desapila m y camina opuesto(m)
##   δ(VUELTA, λ, Z0)       = (VUELTA, λ)   pila vacía: llegó a su puesto
class_name AutomataPilaRegreso
extends RefCounted

const OPUESTO := {"N": "S", "S": "N", "E": "O", "O": "E"}
const DESPLAZAMIENTO := {
	"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "O": Vector2i(-1, 0),
}
const FONDO := "Z0"

var estado: String = "IDA"
var pila: Array = [FONDO]
var traza: Array = []      ## descripciones instantáneas recientes


static func direccion(d: Vector2i) -> String:
	for k in DESPLAZAMIENTO:
		if DESPLAZAMIENTO[k] == d:
			return k
	return ""


func reiniciar() -> void:
	estado = "IDA"
	pila = [FONDO]
	traza = []


func tope() -> String:
	return pila[-1]


func tamano() -> int:
	return pila.size() - 1          # sin contar Z0


func vacia() -> bool:
	return pila.size() == 1


func contenido() -> String:
	var s := ""
	for i in range(pila.size() - 1, 0, -1):
		s += pila[i]
	return s + "Z0"


func _anotar(entrada: String) -> void:
	traza.append([estado, entrada, contenido()])
	if traza.size() > 60:
		traza = traza.slice(-60)


## Lee un paso de ida (N, S, E u O).
func registrar(p: String) -> void:
	if not OPUESTO.has(p):
		push_error("paso inválido: " + p)
		return
	# Si el guardia vuelve a salir mientras regresaba, retoma la ida desde
	# donde va: lo que queda en la pila sigue siendo válido.
	estado = "IDA"
	if tope() != FONDO and tope() == OPUESTO[p]:
		pila.pop_back()                   # δ(IDA, m, opuesto(m)) = (IDA, λ)
	else:
		pila.append(p)                    # δ(IDA, m, X) = (IDA, mX)
	_anotar(p)


## δ(IDA, λ, X) = (VUELTA, X)
func iniciar_vuelta() -> void:
	estado = "VUELTA"
	_anotar("λ")


## δ(VUELTA, λ, m) = (VUELTA, λ). Devuelve el paso a caminar, o "" si la pila
## ya está vacía (acepta).
func siguiente_regreso() -> String:
	if estado != "VUELTA":
		iniciar_vuelta()
	if vacia():
		return ""
	var m: String = pila.pop_back()
	_anotar("λ")
	return OPUESTO[m]


## Simula un recorrido completo: apila `pasos` y luego desapila.
## Devuelve {"vuelta": [...], "vacia": bool}.
static func simular_ida_y_vuelta(pasos: Array) -> Dictionary:
	var ap := AutomataPilaRegreso.new()
	for p in pasos:
		ap.registrar(p)
	var vuelta := []
	while true:
		var m := ap.siguiente_regreso()
		if m == "":
			break
		vuelta.append(m)
	return {"vuelta": vuelta, "vacia": ap.vacia()}
