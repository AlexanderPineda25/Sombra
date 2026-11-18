## Un desafío de una terminal de seguridad: une una máquina de Turing con la
## cinta que el jugador manipula y con el objetivo que debe cumplir.
##
## Es lógica de juego pura (sin nodos): la interfaz solo la muestra.
class_name Desafio
extends RefCounted

var id: String
var dificultad: int
var titulo: String
var variante: String          ## "estandar" | "multicinta" | "multipista"
var efecto: String            ## "puerta" | "camaras" | "laser"
var objetivo: String          ## qué debe lograr el jugador
var leccion: String           ## qué enseña sobre el modelo
var pista_ayuda: String       ## ayuda que aparece tras un fallo
var filas: Array = []         ## {nombre, contenido, editable, simbolos}
var maquina: MaquinaTuring
var intentos := 0
var resuelto := false
var solucion_filas: Array = []  ## la entrada que resuelve el desafío (pruebas y terminal resuelta)
# Cerradura de gemas (acertijo generado al azar en cada partida)
var regla := {}               ## gema de la vitrina -> gema de la clave
var invertir := false
var gema_x := ""              ## central de alarmas: L = { xⁿ yⁿ }
var gema_y := ""
var ejemplos: Array = []      ## cerradura: [[vitrina, clave], ...] que la MT ACEPTA (fase de observación)
## Último intento formal (lo llenan los minijuegos y lo repite el visor técnico):
## {filas: Array de contenidos, transiciones: Array, resultado: String, pasos: int, n: int}
var ultimo_intento := {}

const MAX_PASOS := 5000       ## límite de seguridad: más pasos = error técnico, no rechazo

const NOMBRE_GEMA := {"R": "Rubí", "Z": "Zafiro", "E": "Esmeralda", "A": "Ámbar"}
const RUEDA := {"R": "Z", "Z": "E", "E": "A", "A": "R"}
const OPUESTA := {"R": "E", "E": "R", "Z": "A", "A": "Z"}
const IDENTIDAD := {"R": "R", "Z": "Z", "E": "E", "A": "A"}
## Acertijos de la vitrina: [regla, invertir, objetivo, pista]
const ACERTIJOS := {
	"espejo": [IDENTIDAD, true,
		"La vitrina guarda su clave en un espejo: escribe tras el # las MISMAS gemas de la vitrina, pero leídas de DERECHA a IZQUIERDA.",
		"Lee la vitrina empezando por la gema más cercana al #."],
	"rueda": [RUEDA, false,
		"Rueda del museo: Rubí → Zafiro → Esmeralda → Ámbar → Rubí. Cada gema de la clave es la SIGUIENTE en la rueda que la gema de la vitrina.",
		"Si la vitrina muestra un Ámbar, la rueda vuelve a empezar: tras el Ámbar viene el Rubí."],
	"opuestas": [OPUESTA, false,
		"Gemas rivales: el Rubí se opone a la Esmeralda y el Zafiro al Ámbar. La clave cambia cada gema de la vitrina por su rival, en el mismo orden.",
		"Rubí ↔ Esmeralda, Zafiro ↔ Ámbar. No cambies el orden."],
	"espejo_rueda": [RUEDA, true,
		"Doble cerrojo: cada gema avanza una posición en la rueda (R→Z→E→A→R) y además la clave se escribe al revés.",
		"Primero invierte la vitrina; luego cambia cada gema por la siguiente de la rueda."],
}


## `semilla` < 0 elige un acertijo al azar (cada partida es distinta).
static func crear(p_id: String, semilla := -1, modo: int = Ajustes.dificultad) -> Desafio:
	var d := Desafio.new()
	d.id = p_id
	d.dificultad = modo
	var rng := RandomNumberGenerator.new()
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	var G := ProgramasTuring.GEMAS
	var teclas := {"1": "R", "2": "Z", "3": "E", "4": "A"}
	match p_id:
		"cerradura":
			d.regla = IDENTIDAD
			d.invertir = modo >= Ajustes.Modo.MEDIO
			var vitrina := ""
			var n := 4 + modo
			for i in n:
				vitrina += G[rng.randi_range(0, G.size() - 1)]
			if d.invertir and vitrina == vitrina.reverse():
				vitrina[n - 1] = G[(G.find(vitrina[0]) + 1) % G.size()]
			var clave := vitrina.reverse() if d.invertir else vitrina
			d.titulo = "El robot de la vitrina"
			d.variante = "estandar"
			d.efecto = "puerta"
			d.objetivo = "Lleva cada gema al hueco del mismo número."
			d.leccion = "Un solo lector va y vuelve por el riel. Su estado guarda qué gema está comprobando."
			d.pista_ayuda = "Los números iguales hacen pareja."
			d.filas = [{"nombre": "Vitrina # Cerradura", "contenido": vitrina + "#" + "?".repeat(n),
					"editable": true, "editable_desde": n + 1, "simbolos": G.duplicate(), "teclas": teclas}]
			d.solucion_filas = [vitrina + "#" + clave]
		"alarma":
			# dos gemas distintas al azar: el código debe ser xxx yyy
			var x: String = G[rng.randi() % 4]
			var y: String = G[(G.find(x) + 1 + rng.randi() % 3) % 4]
			d.gema_x = x
			d.gema_y = y
			d.titulo = "Central de alarmas"
			d.variante = "estandar"
			d.efecto = "camaras"
			d.objetivo = "La central se calma con un código EN EQUILIBRIO de 6 gemas: primero solo %s, después solo %s, y la misma cantidad de cada una." % [
					NOMBRE_GEMA[x].to_upper(), NOMBRE_GEMA[y].to_upper()]
			d.leccion = "Máquina estándar como reconocedor de L = { xⁿyⁿ }: marca cada %s y busca su pareja %s. Este lenguaje no es regular: ningún AFD puede contar las parejas, una máquina de Turing sí." % [
					NOMBRE_GEMA[x], NOMBRE_GEMA[y]]
			d.pista_ayuda = "Cada %s necesita su pareja %s, y ninguna %s puede ir antes de un %s." % [NOMBRE_GEMA[x],
					NOMBRE_GEMA[y], NOMBRE_GEMA[y], NOMBRE_GEMA[x]]
			var sol := x.repeat(3) + y.repeat(3)
			var inicial := sol
			while inicial == sol:
				inicial = ""
				for i in 6:
					inicial += [x, y][rng.randi() % 2]
			d.filas = [{"nombre": "Código", "contenido": inicial, "editable": true, "simbolos": G.duplicate(),
					"teclas": teclas}]
			d.solucion_filas = [sol]
		"boveda":
			var entrada := ""
			var sol := ""
			var bolsa_a := ""
			var bolsa_b := ""
			var extras := rng.randi_range(0, G.size() - 1)
			var lote := ["R", "A", "Z", "F", "E", "R", G[extras], "F"]
			for i in modo:
				lote.append_array([G[rng.randi_range(0, G.size() - 1)], "F"])
			for i in lote.size():
				var j := rng.randi_range(i, lote.size() - 1)
				var g: String = lote[j]
				lote[j] = lote[i]
				lote[i] = g
				var destino := ProgramasTuring.destino_botin(g)
				entrada += g + "_"
				sol += g + destino
				if destino == "<":
					bolsa_a += g
				elif destino == ">":
					bolsa_b += g
			d.titulo = "Reparto del botín"
			d.variante = "multicinta"
			d.efecto = "puerta"
			d.objetivo = "Clasifica las joyas por su forma. Descarta las que estén rajadas."
			d.leccion = "Cada bolsa tiene su propio lector. Avanza únicamente la bolsa que recibe una joya."
			d.pista_ayuda = "Busca la misma figura en una de las bolsas."
			d.filas = [
				{"nombre": "Botín y destino", "contenido": entrada, "editable": false, "simbolos": []},
				{"nombre": "Bolsa izquierda", "contenido": "", "editable": false, "simbolos": []},
				{"nombre": "Bolsa derecha", "contenido": "", "editable": false, "simbolos": []},
			]
			d.solucion_filas = [sol, bolsa_a, bolsa_b]
		"laser":
			var haces := ""
			for i in 5 + modo:
				haces += G[rng.randi_range(0, G.size() - 1)]
			d.titulo = "Cruce de la galería"
			d.variante = "multipista"
			d.efecto = "laser"
			d.objetivo = "Usa la máscara del mismo color o cruza cuando el haz se apague."
			d.leccion = "Un lector comprueba al mismo tiempo el haz, tu máscara y si había luz."
			d.pista_ayuda = "La figura del haz también aparece en su máscara."
			d.filas = [
				{"nombre": "Haz", "contenido": haces, "editable": false, "simbolos": []},
				{"nombre": "Máscara", "contenido": "_".repeat(haces.length()), "editable": false, "simbolos": []},
				{"nombre": "Encendido al cruzar", "contenido": "_".repeat(haces.length()), "editable": false, "simbolos": []},
			]
			d.solucion_filas = [haces, haces, "1".repeat(haces.length())]
	d.construir()
	return d


## Construye la máquina y carga el contenido actual de las filas.
func construir() -> MaquinaTuring:
	match id:
		"cerradura":
			maquina = ProgramasTuring.verificador_clave(regla, invertir)
		"alarma":
			maquina = ProgramasTuring.equilibrio_gemas(gema_x, gema_y)
		"boveda":
			maquina = ProgramasTuring.reparto_multicinta()
		"laser":
			maquina = ProgramasTuring.cruce_multipista()
	var contenidos := []
	for f in filas:
		contenidos.append(f["contenido"])
	match variante:
		"estandar":
			maquina.cargar(contenidos[0])
		_:
			maquina.cargar(contenidos)
	return maquina


## Cambia el símbolo de una casilla editable al siguiente de su lista.
func alternar(fila: int, pos: int) -> void:
	var f: Dictionary = filas[fila]
	if not editable_en(fila, pos):
		return
	var s: String = f["contenido"]
	var opciones: Array = f["simbolos"]
	var i := opciones.find(s[pos])
	s[pos] = opciones[(i + 1) % opciones.size()]
	f["contenido"] = s
	construir()


func editable_en(fila: int, pos: int) -> bool:
	var f: Dictionary = filas[fila]
	return f["editable"] and pos >= f.get("editable_desde", 0) and pos < f["contenido"].length()


func poner(fila: int, pos: int, simbolo: String) -> void:
	var f: Dictionary = filas[fila]
	if editable_en(fila, pos) and simbolo in f["simbolos"]:
		var s: String = f["contenido"]
		s[pos] = simbolo
		f["contenido"] = s
		construir()


## Revisa el resultado cuando la máquina se detiene.
## Devuelve {exito: bool, mensaje: String}.
func comprobar() -> Dictionary:
	if not maquina.detenida():
		return {"exito": false, "mensaje": "La máquina aún no se detiene."}
	var acepto := maquina.estado == maquina.acepta
	var exito := acepto
	var msg := ""
	match id:
		"cerradura":
			msg = "La máquina %s la clave." % ("ACEPTÓ" if acepto else "RECHAZÓ")
		"alarma":
			msg = "La máquina %s la palabra." % ("ACEPTÓ" if acepto else "RECHAZÓ")
		"boveda":
			msg = "El botín quedó clasificado." if acepto else "Revisa el destino de la joya."
		"laser":
			msg = "Todos los haces quedaron atrás." if acepto else "El haz detectó una máscara distinta."
	return {"exito": exito, "mensaje": msg}


## Carga `contenidos` (uno por fila) en la máquina del desafío, la reinicia y
## la ejecuta hasta que se detenga, con límite de pasos. Guarda TODAS las
## transiciones ejecutadas como `ultimo_intento` (el visor las repite).
##   resultado: "ACEPTA" | "RECHAZA" | "ERROR" (no se detuvo: error técnico)
func ejecutar_intento(contenidos: Array) -> Dictionary:
	return ejecutar_hasta(contenidos, func(_m): return false)


## Igual, pero se detiene antes si `parar.call(maquina)` es verdadero (se usa
## para validar por partes: «la máquina ya comparó la columna i»). En ese caso
## el resultado es "EN CURSO" y la máquina queda en ese punto de su ejecución.
func ejecutar_hasta(contenidos: Array, parar: Callable) -> Dictionary:
	for i in filas.size():
		filas[i]["contenido"] = contenidos[i]
	construir()
	var trans := []
	while not maquina.detenida() and trans.size() < MAX_PASOS and not parar.call(maquina):
		trans.append(maquina.paso())
	var res := "EN CURSO"
	if maquina.detenida():
		res = maquina.resultado()
	elif trans.size() >= MAX_PASOS:
		res = "ERROR"
	registrar_intento(contenidos, trans, res)
	return ultimo_intento


func registrar_intento(contenidos: Array, trans: Array, res: String) -> void:
	ultimo_intento = {"filas": contenidos.duplicate(), "transiciones": trans.duplicate(true), "resultado": res,
			"pasos": trans.size(), "n": int(ultimo_intento.get("n", 0)) + 1}


## Copia de solo lectura para el visor técnico: misma máquina, misma entrada,
## sin tocar el desafío en juego (abrir el visor no cambia el resultado).
func copia_para_visor(contenidos: Array) -> Desafio:
	var c := Desafio.new()
	c.id = id
	c.dificultad = dificultad
	c.titulo = titulo
	c.variante = variante
	c.efecto = efecto
	c.objetivo = objetivo
	c.leccion = leccion
	c.pista_ayuda = pista_ayuda

	c.regla = regla
	c.invertir = invertir
	c.gema_x = gema_x
	c.gema_y = gema_y
	c.filas = filas.duplicate(true)
	for i in c.filas.size():
		c.filas[i]["contenido"] = contenidos[i]
		c.filas[i]["editable"] = false
	c.solucion_filas = contenidos.duplicate()
	c.construir()
	return c


## La entrada que resuelve cada desafío (para las pruebas automáticas).
## La cerradura cambia en cada partida: usar `solucion_filas` de la instancia.
static func solucion(p_id: String) -> Array:
	return crear(p_id, 0).solucion_filas
