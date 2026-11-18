## Un desafío de una terminal de seguridad: une una máquina de Turing con la
## cinta que el jugador manipula y con el objetivo que debe cumplir.
##
## Es lógica de juego pura (sin nodos): la interfaz solo la muestra.
class_name Desafio
extends RefCounted

var id: String
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
var acertijo := ""            ## "espejo" | "rueda" | "opuestas" | "espejo_rueda"
var regla := {}               ## gema de la vitrina -> gema de la clave
var invertir := false
var gema_x := ""              ## central de alarmas: L = { xⁿ yⁿ }
var gema_y := ""

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
static func crear(p_id: String, semilla := -1) -> Desafio:
	var d := Desafio.new()
	d.id = p_id
	var rng := RandomNumberGenerator.new()
	if semilla >= 0:
		rng.seed = semilla
	else:
		rng.randomize()
	var G := ProgramasTuring.GEMAS
	var teclas := {"1": "R", "2": "Z", "3": "E", "4": "A"}
	match p_id:
		"cerradura":
			var tipos := ACERTIJOS.keys()
			d.acertijo = tipos[rng.randi() % tipos.size()]
			var datos: Array = ACERTIJOS[d.acertijo]
			d.regla = datos[0]
			d.invertir = datos[1]
			var vitrina := ""
			while vitrina == "" or (d.invertir and d.regla == IDENTIDAD and vitrina == vitrina.reverse()):
				vitrina = ""
				for i in 4:
					vitrina += ProgramasTuring.GEMAS[rng.randi() % 4]
			d.titulo = "Cerradura de la vitrina"
			d.variante = "estandar"
			d.efecto = "puerta"
			d.objetivo = datos[2]
			d.leccion = "Máquina estándar: UNA cinta y UN cabezal. Va en zigzag: marca una gema de la vitrina (minúscula), la recuerda en su ESTADO, cruza el # y comprueba la gema de la clave. Así compara dos secuencias con una sola cinta."
			d.pista_ayuda = datos[3]
			var clave := ""
			for g in vitrina:
				clave += d.regla[g]
			if d.invertir:
				clave = clave.reverse()
			# la clave inicial siempre es incorrecta: la primera gema está girada
			var inicial: String = RUEDA[clave[0]] + clave.substr(1)
			d.filas = [{"nombre": "Vitrina # Clave", "contenido": vitrina + "#" + inicial, "editable": true,
					"editable_desde": 5, "simbolos": ProgramasTuring.GEMAS.duplicate(),
					"teclas": {"1": "R", "2": "Z", "3": "E", "4": "A"}}]
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
			var a := ""
			var b := ""
			for i in 4:
				a += G[rng.randi() % 4]
				b += G[rng.randi() % 4]
			var k := ""
			for i in 4:
				k += ProgramasTuring.siguiente_gema(a[i], G.find(b[i]))
			k = k.reverse()
			var inicial_b := b
			while inicial_b == b:
				inicial_b = ""
				for i in 4:
					inicial_b += G[rng.randi() % 4]
			d.titulo = "Puerta de la bóveda"
			d.variante = "multicinta"
			d.efecto = "puerta"
			d.objetivo = "Rueda R→Z→E→A. Cada gema tuya (B) dice cuántos pasos girar la gema del sensor (A): Rubí 0, Zafiro 1, Esmeralda 2, Ámbar 3. El resultado debe ser la clave K… que está escrita AL REVÉS."
			d.leccion = "Máquina multicinta: TRES cintas y TRES cabezales independientes. Primero solo el cabezal 3 va al final (S, S, R); después los cabezales 1 y 2 avanzan a la derecha mientras el 3 retrocede (R, R, L). Una multipista no podría hacerlo: su único cabezal mueve todas las pistas juntas."
			d.pista_ayuda = "Compara la PRIMERA gema de A con la ÚLTIMA de K: ¿cuántos pasos hay en la rueda de una a otra?"
			d.filas = [
				{"nombre": "Cinta 1 · A (sensor)", "contenido": a, "editable": false, "simbolos": []},
				{"nombre": "Cinta 2 · B (tú)", "contenido": inicial_b, "editable": true, "simbolos": G.duplicate(),
						"teclas": teclas},
				{"nombre": "Cinta 3 · K (al revés)", "contenido": k, "editable": false, "simbolos": []},
			]
			d.solucion_filas = [a, b, k]
		"laser":
			var l := ""
			var m := ""
			var o := ""
			for i in 5:
				var g: String = G[rng.randi() % 4]
				l += g
				m += ProgramasTuring.siguiente_gema(g)
				o += ProgramasTuring.siguiente_gema(g, 2)
			var inicial_m := m
			while inicial_m == m:
				inicial_m = ""
				for i in 5:
					inicial_m += G[rng.randi() % 4]
			d.titulo = "Rejilla láser"
			d.variante = "multipista"
			d.efecto = "laser"
			d.objetivo = "Cada columna debe formar una ESCALERA en la rueda R→Z→E→A→R: láser, máscara y objetivo seguidos, de arriba abajo. Escribe la máscara en la pista 2."
			d.leccion = "Máquina multipista: UNA sola cinta con TRES pistas. Cada casilla guarda una tupla (láser, máscara, objetivo) y el único cabezal la lee completa; todas las pistas se mueven juntas."
			d.pista_ayuda = "La máscara es la gema que sigue al láser en la rueda… y justo la anterior al objetivo."
			d.filas = [
				{"nombre": "Pista 1 · láser", "contenido": l, "editable": false, "simbolos": []},
				{"nombre": "Pista 2 · máscara (tú)", "contenido": inicial_m, "editable": true, "simbolos": G.duplicate(),
						"teclas": teclas},
				{"nombre": "Pista 3 · objetivo", "contenido": o, "editable": false, "simbolos": []},
			]
			d.solucion_filas = [l, m, o]
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
			maquina = ProgramasTuring.rueda_multicinta()
		"laser":
			maquina = ProgramasTuring.escalera_multipista()
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
			msg = "A girada según B %s K." % ("coincide con" if acepto else "no coincide con")
		"laser":
			msg = "La máscara %s la escalera." % ("completa" if acepto else "no completa")
	return {"exito": exito, "mensaje": msg}


## La entrada que resuelve cada desafío (para las pruebas automáticas).
## La cerradura cambia en cada partida: usar `solucion_filas` de la instancia.
static func solucion(p_id: String) -> Array:
	return crear(p_id, 0).solucion_filas
