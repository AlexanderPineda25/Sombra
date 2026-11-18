## Radar de vigilancia periódica.
##
## Su ciclo es un AFD (REPOSO -> AVISO -> BARRIDO -> ANALISIS -> REPOSO).
## Durante el BARRIDO gira 360° y registra, por cada sector, cuatro señales:
##   P presencia · A transpondedor autorizado · V eco recibido · O oculto
## (en Difícil el eco atraviesa paredes)
## En el ANALISIS las procesa con dos máquinas de Turing:
##   1. Multicinta (correlador): cruza P con A sector a sector -> intrusos I.
##   2. Multipista (analizador): busca una columna (I=1, V=1, O=0).
## Si la multipista ACEPTA hay intrusión: el radar dispara una alerta global
## con la posición medida y todos los guardias acuden a ese punto.
## Los arbustos ocultan al ladrón en todos los modos.
class_name Radar
extends RefCounted

const SECTORES := 12

var dificultad: int
var atraviesa_paredes: bool
var tile: Vector2i
var pos: Vector2
var mapa: Mapa
var afd: AFD
var t_fase := 0.0
var angulo := 0.0                 ## dirección actual del barrido
var obs_p: Array = []             ## una entrada por sector
var obs_a: Array = []
var obs_v: Array = []
var obs_o: Array = []
var distancia_sector: Array = []  ## distancia medida al objetivo de cada sector
var posicion_sector: Array = []   ## posición medida del ladrón en cada sector
var sector_actual := -1
var correlador: MTMulticinta      ## última ejecución (la muestra la consola F1)
var analizador: MTMultipista
var ultimo_resultado := ""        ## "" | "INTRUSION" | "LIMPIO"
var sector_intrusion := -1
var escaneos := 0
var ultima_transicion: Array = []  ## [símbolo, origen, destino] (para la consola)


func _init(p_tile: Vector2i, p_mapa: Mapa, desfase := 0.0, modo := Ajustes.Modo.FACIL) -> void:
	dificultad = modo
	atraviesa_paredes = modo == Ajustes.Modo.DIFICIL
	tile = p_tile
	mapa = p_mapa
	pos = Mapa.centro(tile)
	afd = Def.crear_afd_radar()
	t_fase = -desfase
	_limpiar_observaciones()


func estado() -> String:
	return afd.actual


func alcance() -> float:
	return (Ajustes.radar_alcance + dificultad) * Config.TILE


func intervalo() -> float:
	return Ajustes.radar_intervalo * Ajustes.RADAR_INTERVALO[dificultad]


func duracion_aviso() -> float:
	return Ajustes.radar_aviso * Ajustes.RADAR_AVISO[dificultad]


func extremo_barrido(direccion: float) -> Vector2:
	if atraviesa_paredes:
		return pos + Vector2.from_angle(direccion) * alcance()
	return mapa.rayo(pos, direccion, alcance())


func tiempo_restante() -> float:
	match estado():
		Def.REPOSO:
			return intervalo() - t_fase
		Def.AVISO:
			return duracion_aviso() - t_fase
	return 0.0


func _paso(simbolo: String) -> void:
	var antes := afd.actual
	ultima_transicion = [simbolo, antes, afd.paso(simbolo)]


func _limpiar_observaciones() -> void:
	for arr in [obs_p, obs_a, obs_v, obs_o, distancia_sector, posicion_sector]:
		arr.clear()
		for i in SECTORES:
			arr.append(0)


static func sector_de(angulo_rad: float) -> int:
	return int(floor(fposmod(angulo_rad, TAU) / (TAU / SECTORES))) % SECTORES


## Lo que el radar percibe en el sector `s` en este instante.
func observar(s: int, j: Jugador, guardias: Array) -> void:
	var jugador_en := _en_sector(j.pos, s)
	if jugador_en:
		obs_p[s] = 1
		obs_a[s] = 0                         # el ladrón no lleva transpondedor
		obs_v[s] = 1 if atraviesa_paredes or mapa.linea_libre(pos, j.pos) else 0
		obs_o[s] = 1 if j.oculto else 0
		distancia_sector[s] = pos.distance_to(j.pos)
		posicion_sector[s] = j.pos
		return
	for g in guardias:
		if _en_sector(g.pos, s) and (atraviesa_paredes or mapa.linea_libre(pos, g.pos)):
			obs_p[s] = 1
			obs_a[s] = 1
			obs_v[s] = 1


func _en_sector(p: Vector2, s: int) -> bool:
	return p.distance_to(pos) <= alcance() and sector_de((p - pos).angle()) == s


## Avanza el radar. Devuelve un diccionario con lo ocurrido ({} si nada):
##   {"tipo": "aviso" | "barrido" | "intrusion" | "limpio", ...}
func actualizar(dt: float, j: Jugador, guardias: Array) -> Dictionary:
	t_fase += dt
	match estado():
		Def.REPOSO:
			if t_fase >= intervalo():
				_paso("t")
				t_fase = 0.0
				return {"tipo": "aviso"}
		Def.AVISO:
			if t_fase >= duracion_aviso():
				_paso("t")
				t_fase = 0.0
				angulo = 0.0
				sector_actual = -1
				_limpiar_observaciones()
				return {"tipo": "barrido"}
		Def.BARRIDO:
			angulo = TAU * t_fase / Ajustes.radar_barrido
			var s := sector_de(angulo) if angulo < TAU else SECTORES
			# registra cada sector por el que pasa la línea de barrido
			for k in range(sector_actual + 1, mini(s + 1, SECTORES)):
				observar(k, j, guardias)
			sector_actual = s
			if angulo >= TAU:
				_paso("f")
				t_fase = 0.0
		Def.ANALISIS:
			_paso("n")
			t_fase = 0.0
			return analizar()
	return {}


## Procesa las observaciones con las dos máquinas de Turing.
func analizar() -> Dictionary:
	escaneos += 1
	correlador = ProgramasTuring.correlador_sensores()
	correlador.cargar([_bits(obs_p), _bits(obs_a), ""])
	correlador.ejecutar()
	var intrusos := ""
	for i in SECTORES:
		intrusos += correlador.cintas[2].leer_en(i)
	analizador = ProgramasTuring.analizador_radar()
	analizador.cargar([intrusos, _bits(obs_v), _bits(obs_o), ""])
	var r := analizador.ejecutar()
	if r == "ACEPTA":
		ultimo_resultado = "INTRUSION"
		sector_intrusion = analizador.cabezal
		# posición medida cuando la línea de barrido pasó por el sector
		var medida: Vector2 = posicion_sector[sector_intrusion]
		return {"tipo": "intrusion", "sector": sector_intrusion, "pos": medida,
				"pasos": correlador.pasos + analizador.pasos}
	ultimo_resultado = "LIMPIO"
	sector_intrusion = -1
	return {"tipo": "limpio", "pasos": correlador.pasos + analizador.pasos}


static func _bits(arr: Array) -> String:
	var s := ""
	for b in arr:
		s += str(b)
	return s
