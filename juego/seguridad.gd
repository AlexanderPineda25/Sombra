## Gestor de seguridad del museo: alertas globales, nivel de amenaza y
## registro de eventos. Es lógica pura; la escena escucha la señal `evento`
## (audio, consola F1) sin que el juego dependa de ella.
class_name Seguridad
extends RefCounted

## Se emite con cada suceso relevante: tipo, texto para el registro y datos.
signal evento(tipo: String, texto: String, datos: Dictionary)

## Peso de cada estado del guardia en el nivel de amenaza.
const PESO_ESTADO := {
	"PATRULLA": 0.0, "REGRESO": 0.1, "SOSPECHA": 0.35,
	"ALERTA": 0.5, "BUSQUEDA": 0.65, "PERSECUCION": 1.0,
}

var registro: Array = []            ## {t, tipo, texto}
var pendientes: Array = []          ## alertas por radio a repartir este fotograma
var alertas_globales := 0
var amenaza := 0.0                  ## 0 = sigilo ... 1 = persecución
var t_alerta := 0.0                 ## la alerta global eleva la amenaza un rato
var tiempo := 0.0


## Cuántos eventos de cada tipo hubo en la partida (no se recorta, a
## diferencia del registro): resumen de la pantalla de victoria.
var contador := {}


func registrar(tipo: String, texto: String, datos := {}) -> void:
	contador[tipo] = int(contador.get(tipo, 0)) + 1
	registro.append({"t": tiempo, "tipo": tipo, "texto": texto})
	if registro.size() > 300:
		registro = registro.slice(-300)
	evento.emit(tipo, texto, datos)


## Un guardia o un radar pide avisar a todos: se reparte en `repartir`.
## Con `exacto` (el radar mide la posición) todos van a ese punto exacto.
func pedir_alerta(pos: Vector2, origen: String, exacto := false) -> void:
	pendientes.append({"pos": pos, "origen": origen, "exacto": exacto})


## Envía las alertas pendientes por radio. Cada guardia recibe el símbolo `a`
## y decide según su distancia: los cercanos acuden a la zona (con un margen
## de error, nadie sabe la posición exacta) y los lejanos buscan en su sector.
func repartir(guardias: Array) -> void:
	for p in pendientes:
		alertas_globales += 1
		t_alerta = Config.DURACION_ALERTA_GLOBAL
		registrar("alerta", "ALERTA GLOBAL (%s): todos los guardias reciben el aviso por radio." % p["origen"],
				{"pos": p["pos"]})
		for g in guardias:
			g.recibir_alerta(p["pos"], p.get("exacto", false))
	pendientes.clear()


func actualizar(dt: float, guardias: Array) -> void:
	tiempo += dt
	t_alerta = maxf(0.0, t_alerta - dt)
	var a := 0.0
	for g in guardias:
		a = maxf(a, PESO_ESTADO.get(g.estado(), 0.0))
	if t_alerta > 0.0:
		a = maxf(a, 0.7)
	amenaza = a


## Nombre del nivel de amenaza (lo usan la música y el HUD).
func nivel() -> String:
	if amenaza >= 0.95:
		return "PERSECUCION"
	if amenaza >= 0.6:
		return "BUSQUEDA"
	if amenaza >= 0.3:
		return "SOSPECHA"
	return "SIGILO"
