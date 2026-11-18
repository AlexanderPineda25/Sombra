## Definición de los autómatas concretos del juego.
## Todos son AFD completos: cada estado tiene una transición por cada evento.
class_name Def
extends RefCounted

# ====================================================================== #
# 1. AFD del guardia (6 estados)
# ====================================================================== #
#   v -> ve al jugador (su barra de sospecha se llenó)
#   r -> oye un ruido (pasos corriendo, moneda, alarma)
#   s -> ve algo raro (la sospecha supera el umbral, pero aún no lo identifica)
#   p -> pierde de vista al jugador
#   l -> llega a su destino
#   t -> se le acaba el tiempo en el estado actual
#   a -> recibe una alerta global por radio (un compañero o un radar lo detectó)
const ALFABETO_GUARDIA := ["v", "r", "s", "p", "l", "t", "a"]

const NOMBRE_EVENTO := {
	"v": "ve al jugador",
	"r": "oye un ruido",
	"s": "ve algo raro",
	"p": "pierde de vista",
	"l": "llega a su destino",
	"t": "se acaba el tiempo",
	"a": "alerta por radio",
}

const PATRULLA := "PATRULLA"
const SOSPECHA := "SOSPECHA"
const ALERTA := "ALERTA"
const PERSECUCION := "PERSECUCION"
const BUSQUEDA := "BUSQUEDA"
const REGRESO := "REGRESO"

const ESTADOS_GUARDIA := [PATRULLA, SOSPECHA, ALERTA, PERSECUCION, BUSQUEDA, REGRESO]

## Nombre en pantalla de cada estado.
const ETIQUETA := {
	PATRULLA: "Patrullando",
	SOSPECHA: "Sospechando",
	ALERTA: "Investigando un ruido",
	PERSECUCION: "Persiguiendo",
	BUSQUEDA: "Buscando",
	REGRESO: "Regresando a su ruta",
}

const ACCION_GUARDIA := {
	PATRULLA: "seguir la ruta",
	SOSPECHA: "acercarse despacio a mirar",
	ALERTA: "ir hacia el ruido",
	PERSECUCION: "perseguir al jugador",
	BUSQUEDA: "buscar en la última posición",
	REGRESO: "desapilar la ruta y volver",
}

const DELTA_GUARDIA := {
	PATRULLA:    {"v": PERSECUCION, "r": ALERTA,      "s": SOSPECHA,    "p": PATRULLA,    "l": PATRULLA,    "t": PATRULLA, "a": ALERTA},
	SOSPECHA:    {"v": PERSECUCION, "r": ALERTA,      "s": SOSPECHA,    "p": SOSPECHA,    "l": SOSPECHA,    "t": REGRESO, "a": ALERTA},
	ALERTA:      {"v": PERSECUCION, "r": ALERTA,      "s": ALERTA,      "p": ALERTA,      "l": BUSQUEDA,    "t": REGRESO, "a": ALERTA},
	PERSECUCION: {"v": PERSECUCION, "r": PERSECUCION, "s": PERSECUCION, "p": BUSQUEDA,    "l": PERSECUCION, "t": PERSECUCION, "a": PERSECUCION},
	BUSQUEDA:    {"v": PERSECUCION, "r": ALERTA,      "s": BUSQUEDA,    "p": BUSQUEDA,    "l": BUSQUEDA,    "t": REGRESO, "a": ALERTA},
	REGRESO:     {"v": PERSECUCION, "r": ALERTA,      "s": SOSPECHA,    "p": REGRESO,     "l": PATRULLA,    "t": REGRESO, "a": ALERTA},
}


## AFD mínimo del guardia (6 estados).
static func crear_afd_guardia() -> AFD:
	return AFD.new("Guardia", ESTADOS_GUARDIA, ALFABETO_GUARDIA, DELTA_GUARDIA, PATRULLA,
			[PERSECUCION], ACCION_GUARDIA)


# Primer diseño del guardia (7 estados). Se distinguía "investigar un ruido en
# patrulla" (INVESTIGAR) de "revisar un ruido durante la búsqueda" (REVISAR).
# Al minimizar se comprueba que son equivalentes y se fusionan en ALERTA.
const INVESTIGAR := "INVESTIGAR"
const REVISAR := "REVISAR"

const DELTA_GUARDIA_BORRADOR := {
	PATRULLA:    {"v": PERSECUCION, "r": INVESTIGAR,  "s": SOSPECHA,    "p": PATRULLA,    "l": PATRULLA,    "t": PATRULLA, "a": INVESTIGAR},
	SOSPECHA:    {"v": PERSECUCION, "r": INVESTIGAR,  "s": SOSPECHA,    "p": SOSPECHA,    "l": SOSPECHA,    "t": REGRESO, "a": INVESTIGAR},
	INVESTIGAR:  {"v": PERSECUCION, "r": INVESTIGAR,  "s": INVESTIGAR,  "p": INVESTIGAR,  "l": BUSQUEDA,    "t": REGRESO, "a": INVESTIGAR},
	REVISAR:     {"v": PERSECUCION, "r": REVISAR,     "s": REVISAR,     "p": REVISAR,     "l": BUSQUEDA,    "t": REGRESO, "a": REVISAR},
	PERSECUCION: {"v": PERSECUCION, "r": PERSECUCION, "s": PERSECUCION, "p": BUSQUEDA,    "l": PERSECUCION, "t": PERSECUCION, "a": PERSECUCION},
	BUSQUEDA:    {"v": PERSECUCION, "r": REVISAR,     "s": BUSQUEDA,    "p": BUSQUEDA,    "l": BUSQUEDA,    "t": REGRESO, "a": REVISAR},
	REGRESO:     {"v": PERSECUCION, "r": INVESTIGAR,  "s": SOSPECHA,    "p": REGRESO,     "l": PATRULLA,    "t": REGRESO, "a": INVESTIGAR},
}

const ACCION_GUARDIA_BORRADOR := {
	PATRULLA: "seguir la ruta",
	SOSPECHA: "acercarse despacio a mirar",
	INVESTIGAR: "ir hacia el ruido",
	REVISAR: "ir hacia el ruido",
	PERSECUCION: "perseguir al jugador",
	BUSQUEDA: "buscar en la última posición",
	REGRESO: "desapilar la ruta y volver",
}


static func crear_afd_guardia_borrador() -> AFD:
	return AFD.new("Guardia (borrador)",
			[PATRULLA, SOSPECHA, INVESTIGAR, REVISAR, PERSECUCION, BUSQUEDA, REGRESO],
			ALFABETO_GUARDIA, DELTA_GUARDIA_BORRADOR, PATRULLA, [PERSECUCION],
			ACCION_GUARDIA_BORRADOR)


# ====================================================================== #
# 2. AFD de la cámara de seguridad
# ====================================================================== #
#   f -> terminó de girar hacia un lado
#   v -> ve al jugador
#   t -> se acabó la alarma
#   x -> la central de alarmas la desactiva (la máquina de Turing aceptó)
const GIRO_IZQ := "GIRO_IZQ"
const GIRO_DER := "GIRO_DER"
const ALARMA := "ALARMA"
const APAGADA := "APAGADA"
const ALFABETO_CAMARA := ["f", "v", "t", "x"]

const DELTA_CAMARA := {
	GIRO_IZQ: {"f": GIRO_DER, "v": ALARMA,  "t": GIRO_IZQ, "x": APAGADA},
	GIRO_DER: {"f": GIRO_IZQ, "v": ALARMA,  "t": GIRO_DER, "x": APAGADA},
	ALARMA:   {"f": ALARMA,   "v": ALARMA,  "t": GIRO_IZQ, "x": APAGADA},
	APAGADA:  {"f": APAGADA,  "v": APAGADA, "t": APAGADA,  "x": APAGADA},
}

const ACCION_CAMARA := {
	GIRO_IZQ: "girar a la izquierda",
	GIRO_DER: "girar a la derecha",
	ALARMA: "sonar la alarma",
	APAGADA: "ninguna (desactivada)",
}


static func crear_afd_camara() -> AFD:
	return AFD.new("Cámara", [GIRO_IZQ, GIRO_DER, ALARMA, APAGADA], ALFABETO_CAMARA,
			DELTA_CAMARA, GIRO_IZQ, [ALARMA], ACCION_CAMARA)


# ====================================================================== #
# 2b. AFD del ciclo del radar
# ====================================================================== #
#   t -> vence el temporizador de la fase actual
#   f -> el barrido completó la vuelta
#   n -> el análisis terminó (con o sin intrusión)
const REPOSO := "REPOSO"
const AVISO := "AVISO"
const BARRIDO := "BARRIDO"
const ANALISIS := "ANALISIS"
const ALFABETO_RADAR := ["t", "f", "n"]

const DELTA_RADAR := {
	REPOSO:   {"t": AVISO,    "f": REPOSO,   "n": REPOSO},
	AVISO:    {"t": BARRIDO,  "f": AVISO,    "n": AVISO},
	BARRIDO:  {"t": BARRIDO,  "f": ANALISIS, "n": BARRIDO},
	ANALISIS: {"t": ANALISIS, "f": ANALISIS, "n": REPOSO},
}

const ACCION_RADAR := {
	REPOSO: "esperar el próximo ciclo",
	AVISO: "advertir que va a escanear",
	BARRIDO: "girar y registrar observaciones por sector",
	ANALISIS: "procesar las señales con las máquinas de Turing",
}


static func crear_afd_radar() -> AFD:
	return AFD.new("Radar", [REPOSO, AVISO, BARRIDO, ANALISIS], ALFABETO_RADAR, DELTA_RADAR,
			REPOSO, [], ACCION_RADAR)


# ====================================================================== #
# 3. AFD del flujo del juego (pantallas)
# ====================================================================== #
#   enter    -> tecla Enter
#   esc      -> tecla Escape
#   atrapado -> un guardia alcanzó al jugador
#   escapo   -> el jugador salió con las joyas (quedan niveles)
#   final    -> el jugador salió del último nivel
#   terminal -> el jugador abre una terminal de seguridad
const MENU := "MENU"
const JUGANDO := "JUGANDO"
const PAUSA := "PAUSA"
const TERMINAL := "TERMINAL"
const DERROTA := "DERROTA"
const VICTORIA := "VICTORIA"
const FIN := "FIN"
const ALFABETO_FLUJO := ["enter", "esc", "atrapado", "escapo", "final", "terminal"]


static func delta_flujo() -> Dictionary:
	var d := {}
	for q in [MENU, JUGANDO, PAUSA, TERMINAL, DERROTA, VICTORIA, FIN]:
		d[q] = {}
		for s in ALFABETO_FLUJO:
			d[q][s] = q                     # por defecto se queda
	d[MENU]["enter"] = JUGANDO
	d[JUGANDO]["esc"] = PAUSA
	d[JUGANDO]["atrapado"] = DERROTA
	d[JUGANDO]["escapo"] = VICTORIA
	d[JUGANDO]["final"] = FIN
	d[JUGANDO]["terminal"] = TERMINAL
	d[TERMINAL]["esc"] = JUGANDO
	d[PAUSA]["esc"] = JUGANDO
	d[PAUSA]["enter"] = MENU
	d[DERROTA]["enter"] = JUGANDO
	d[DERROTA]["esc"] = MENU
	d[VICTORIA]["enter"] = JUGANDO
	d[VICTORIA]["esc"] = MENU
	d[FIN]["enter"] = MENU
	d[FIN]["esc"] = MENU
	return d


static func crear_afd_flujo() -> AFD:
	return AFD.new("Flujo del juego", [MENU, JUGANDO, PAUSA, TERMINAL, DERROTA, VICTORIA, FIN],
			ALFABETO_FLUJO, delta_flujo(), MENU, [FIN])
