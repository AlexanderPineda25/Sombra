## Gestor de audio: música adaptativa por capas, ambiente y efectos.
##
## Cada nivel tiene su propio tema (musica_n1_*, musica_n2_*, musica_n3_*),
## compuesto con una gramática estocástica y un sistema L
## (herramientas/generar_audio.py).
##
## Música: cuatro capas sincronizadas (AudioStreamSynchronized) que nunca se
## detienen; solo cambia el volumen de cada una con fundidos suaves según el
## estado musical, que se deduce de los AFD de los guardias, del radar y de
## las alarmas (ver `estado_desde`).
##
##   EXPLORACION  base                       (todos en PATRULLA / REGRESO)
##   SOSPECHA     base + tensión             (algún guardia en SOSPECHA)
##   BUSQUEDA     base + tensión + búsqueda  (ALERTA o BUSQUEDA)
##   PERSECUCION  todas las capas            (PERSECUCION)
##   ALARMA       búsqueda + persecución     (alarma o alerta global activa)
##   VICTORIA / DERROTA: la base baja a un fondo suave y suena un remate.
##
## Continuidad (corrección del corte de música): las pistas duran ~18-21 s y
## se importaban con loop=false, así que la música callaba a los pocos
## segundos de cada nivel. Ahora cada capa y el ambiente se importan con
## loop=true y, además, `_cargar_en_bucle` fuerza el bucle al cargarlas (los
## .import no viajaban con el repositorio porque estaban en .gitignore).
## El reproductor vive en este nodo, hijo de Main, que nunca se destruye (el
## juego no cambia de escena: niveles y terminales se rehacen dentro de
## Main), y tiene PROCESS_MODE_ALWAYS: sigue sonando con el árbol en pausa.
## Solo se llama a play() al preparar y al cambiar de tema de nivel.
##
## Efectos: un grupo de reproductores reutilizables con límite de polifonía y
## un tiempo mínimo entre repeticiones del mismo sonido, para que las
## máquinas de Turing (que pueden dar cientos de pasos) no saturen el audio.
class_name GestorAudio
extends Node

const CAPAS := ["base", "tension", "busqueda", "persecucion"]
const MEZCLA := {
	"MENU":        [0.65, 0.0, 0.0, 0.0],
	"EXPLORACION": [1.0, 0.0, 0.0, 0.0],
	"SOSPECHA":    [1.0, 0.85, 0.0, 0.0],
	"BUSQUEDA":    [0.85, 0.55, 1.0, 0.0],
	"PERSECUCION": [0.55, 0.3, 0.75, 1.0],
	"ALARMA":      [0.5, 0.45, 1.0, 0.8],
	"TERMINAL":    [0.7, 0.35, 0.0, 0.0],
	"VICTORIA":    [0.3, 0.0, 0.0, 0.0],
	"DERROTA":     [0.25, 0.0, 0.0, 0.0],
}
## Segundos que tarda un fundido completo (subir es más rápido que bajar).
const FUNDIDO_SUBIDA := 0.9
const FUNDIDO_BAJADA := 2.4
const EFECTOS := ["mt_leer", "mt_escribir", "mt_mover", "mt_acepta", "mt_rechaza", "radar_aviso",
		"radar_barrido", "radar_ping", "moneda", "joya", "oculto", "crujido", "bloqueado", "radio",
		"alarma", "puerta", "terminal", "sospecha", "persecucion", "laser", "paso", "paso_guardia", "nivel"]
const POLIFONIA := 12
const RAFAGA_MAX := 6              ## efectos que pueden arrancar en 0.1 s
## Tiempo mínimo entre dos reproducciones del mismo efecto.
const ESPERA := {
	"mt_leer": 0.07, "mt_escribir": 0.07, "mt_mover": 0.06, "crujido": 0.25,
	"radio": 0.6, "sospecha": 0.5, "persecucion": 1.2, "alarma": 1.4, "moneda": 0.1,
	"radar_ping": 0.15, "paso": 0.12, "paso_guardia": 0.18, "nivel": 1.0,
}
const TEMAS := ["n1", "n2", "n3"]
const AMBIENTE_DB := -15.0
const FUNDIDO_TEMA := 0.45         ## segundos para bajar (y luego subir) al cambiar de tema

var musica: AudioStreamPlayer
var sync: AudioStreamSynchronized
var capas_web: Array[AudioStreamPlayer] = []
var volumen: Array = [0.0, 0.0, 0.0, 0.0]   ## lineal, el actual de cada capa
var estado := "MENU"
var cambios_estado := 0                     ## para pruebas y la consola
var efectos: Dictionary = {}
var reproductores: Array = []
var ultimo: Dictionary = {}                 ## efecto -> instante de la última vez
var inicios: Array = []                     ## instantes de los últimos arranques
var reproducidos: Array = []                ## historial (para pruebas y la consola)
var descartados := 0
var reloj := 0.0
var remate: AudioStreamPlayer
var ambiente: AudioStreamPlayer
var tema_actual := ""
var t_paso := 0.0
var t_paso_guardia := 0.0
var _cola: Array = []                       ## [instante, nombre, tono]
var _tema_pendiente := ""                   ## tema que entra cuando termina el fundido
var _nivel_tema := 1.0                      ## 0..1, fundido del reproductor al cambiar de tema
var reinicios_musica := 0                   ## veces que se llamó play() (no debe crecer al jugar)


func _ready() -> void:
	preparar()


## Crea los reproductores (idempotente; las pruebas lo llaman directamente).
func preparar() -> void:
	if musica != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	if OS.has_feature("web"):
		# En Web sin hilos, Web Audio mezcla muestras sin depender de cada
		# fotograma de Godot. Todas las capas arrancan en el mismo fotograma.
		for i in CAPAS.size():
			var capa := AudioStreamPlayer.new()
			capa.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
			capa.bus = "Musica"
			add_child(capa)
			capas_web.append(capa)
		musica = capas_web[0]
	else:
		sync = AudioStreamSynchronized.new()
		sync.stream_count = CAPAS.size()
		musica = AudioStreamPlayer.new()
		musica.stream = sync
		musica.bus = "Musica"
		add_child(musica)
	fijar_tema("n1")
	remate = AudioStreamPlayer.new()
	remate.bus = "Musica"
	add_child(remate)
	ambiente = AudioStreamPlayer.new()
	ambiente.stream = _cargar_en_bucle("res://assets/audio/ambiente_museo.ogg")
	ambiente.bus = "Efectos"
	ambiente.volume_db = -80.0
	add_child(ambiente)
	ambiente.play()
	for i in POLIFONIA:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		reproductores.append(p)
	for nombre in EFECTOS:
		efectos[nombre] = load("res://assets/audio/sfx_%s.wav" % nombre)


func _buses() -> void:
	for nombre in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(nombre) == -1:
			# Ampliar al final conserva los índices de los buses de Web Audio.
			AudioServer.bus_count += 1
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nombre)
			AudioServer.set_bus_send(i, "Master")


# ------------------------------------------------------------------ música
## Carga una pista y garantiza que se repita sin fin.
static func _cargar_en_bucle(ruta: String) -> AudioStream:
	var st: AudioStream = load(ruta)
	if st is AudioStreamOggVorbis or st is AudioStreamMP3:
		st.loop = true
	elif st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = int(st.get_length() * st.mix_rate)
	return st


## Cambia el tema (uno por nivel). Si ya suena otro, baja el reproductor,
## cambia las cuatro capas juntas (vuelven a empezar sincronizadas) y lo
## vuelve a subir. Si es el mismo tema no hace nada: la música sigue donde
## iba (reintentar un nivel o entrar a una terminal no la reinicia).
func fijar_tema(clave: String) -> void:
	var destino := _tema_pendiente if _tema_pendiente != "" else tema_actual
	if clave == destino or not clave in TEMAS:
		return
	if tema_actual == "" or not musica.playing:
		_aplicar_tema(clave)
	else:
		_tema_pendiente = clave


func _aplicar_tema(clave: String) -> void:
	tema_actual = clave
	_tema_pendiente = ""
	for i in CAPAS.size():
		var pista := _cargar_en_bucle("res://assets/audio/musica_%s_%s.ogg" % [clave, CAPAS[i]])
		if sync != null:
			sync.set_sync_stream(i, pista)
		else:
			capas_web[i].stream = pista
			# Decodifica las cuatro pistas antes de arrancar la primera.
			if not AudioServer.is_stream_registered_as_sample(pista):
				AudioServer.register_stream_as_sample(pista)
		_aplicar_volumen_capa(i)
	if sync != null:
		musica.play()
	else:
		for capa in capas_web:
			capa.play()
	reinicios_musica += 1


func _aplicar_volumen_capa(i: int) -> void:
	if sync != null:
		sync.set_sync_stream_volume(i, linear_to_db(maxf(volumen[i], 0.0001)))
	else:
		var db := linear_to_db(maxf(volumen[i] * _nivel_tema, 0.0001))
		if not is_equal_approx(capas_web[i].volume_db, db):
			capas_web[i].volume_db = db


## Estado del reproductor (consola F1 y pruebas de continuidad).
func diagnostico() -> Dictionary:
	var bus := AudioServer.get_bus_index("Musica")
	return {"tema": tema_actual, "sonando": musica.playing, "pausada": musica.stream_paused,
			"posicion": musica.get_playback_position(), "bus": musica.bus,
			"bus_db": AudioServer.get_bus_volume_db(bus), "bus_mute": AudioServer.is_bus_mute(bus),
			"reinicios": reinicios_musica, "estado": estado}


## Estado musical a partir del flujo del juego y de la partida.
static func estado_desde(flujo: String, p: Partida) -> String:
	match flujo:
		Def.MENU:
			return "MENU"
		Def.VICTORIA, Def.FIN:
			return "VICTORIA"
		Def.DERROTA:
			return "DERROTA"
	if p == null or p.demo:
		return "MENU"
	var alarma := p.seguridad.t_alerta > 0.0
	for c in p.camaras:
		if c.estado() == Def.ALARMA:
			alarma = true
	var peor := 0
	const ORDEN := {Def.PATRULLA: 0, Def.REGRESO: 0, Def.SOSPECHA: 1, Def.ALERTA: 2,
			Def.BUSQUEDA: 2, Def.PERSECUCION: 3}
	for g in p.guardias:
		peor = maxi(peor, ORDEN[g.estado()])
	if peor == 3:
		return "PERSECUCION"
	if alarma:
		return "ALARMA"
	if flujo == Def.TERMINAL and peor == 0:
		return "TERMINAL"
	return ["EXPLORACION", "SOSPECHA", "BUSQUEDA"][peor]


func fijar_estado(nuevo: String) -> void:
	if nuevo == estado:
		return
	var antes := estado
	estado = nuevo
	cambios_estado += 1
	if nuevo == "VICTORIA":
		remate.stream = load("res://assets/audio/remate_victoria.ogg")
		remate.play()
	elif nuevo == "DERROTA":
		remate.stream = load("res://assets/audio/remate_derrota.ogg")
		remate.play()
	elif antes in ["VICTORIA", "DERROTA"]:
		remate.stop()


func objetivo(i: int) -> float:
	var v: float = MEZCLA[estado][i]
	if i > 0:
		v = minf(1.0, v * Ajustes.musica_intensidad)
	return v


func _process(dt: float) -> void:
	reloj += dt
	_volumen_buses()
	# fundido del cambio de tema: baja, cambia las capas y vuelve a subir
	if _tema_pendiente != "":
		_nivel_tema = move_toward(_nivel_tema, 0.0, dt / FUNDIDO_TEMA)
		if _nivel_tema <= 0.0:
			_aplicar_tema(_tema_pendiente)
	else:
		_nivel_tema = move_toward(_nivel_tema, 1.0, dt / FUNDIDO_TEMA)
	if sync != null:
		musica.volume_db = linear_to_db(maxf(_nivel_tema, 0.0001))
	for i in CAPAS.size():
		var meta := objetivo(i)
		var vel := 1.0 / (FUNDIDO_SUBIDA if meta > volumen[i] else FUNDIDO_BAJADA)
		volumen[i] = move_toward(volumen[i], meta, dt * vel)
		_aplicar_volumen_capa(i)
	# ambiente del museo: solo durante la partida, más bajo si hay persecución
	var meta_amb := AMBIENTE_DB if estado in ["EXPLORACION", "SOSPECHA", "BUSQUEDA", "TERMINAL"] else -60.0
	ambiente.volume_db = move_toward(ambiente.volume_db, meta_amb, dt * 20.0)
	# efectos programados (ráfagas de las máquinas de Turing)
	while not _cola.is_empty() and _cola[0][0] <= reloj:
		var e: Array = _cola.pop_front()
		sonar(e[1], e[2])


func _volumen_buses() -> void:
	var m := AudioServer.get_bus_index("Musica")
	var e := AudioServer.get_bus_index("Efectos")
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(Ajustes.musica_volumen * 0.8, 0.0001)))
	AudioServer.set_bus_volume_db(e, linear_to_db(maxf(Ajustes.efectos_volumen, 0.0001)))


# ------------------------------------------------------------------ pasos
## Pasos del ladrón (no suenan agachado) y del guardia más cercano: su volumen
## sube al acercarse, así se le oye venir antes de verlo.
func pasos(dt: float, p: Partida) -> void:
	if p == null or p.demo:
		return
	var j := p.jugador
	t_paso -= dt
	if j.moviendo and not j.agachado and t_paso <= 0.0:
		t_paso = 0.22 if j.corriendo else 0.36
		sonar("paso", randf_range(0.9, 1.1), -6.0 if j.corriendo else -12.0)
	t_paso_guardia -= dt
	var cerca: Guardia = null
	var dmin := 1e9
	for g in p.guardias:
		var d: float = g.pos.distance_to(j.pos) / Config.TILE
		if g.moviendo and d < dmin:
			dmin = d
			cerca = g
	if cerca != null and dmin < 8.0 and t_paso_guardia <= 0.0:
		var corre: bool = cerca.estado() in [Def.PERSECUCION, Def.ALERTA]
		t_paso_guardia = 0.28 if corre else 0.45
		sonar("paso_guardia", randf_range(0.92, 1.05), lerpf(-4.0, -24.0, dmin / 8.0))


# ----------------------------------------------------------------- efectos
## Reproduce un efecto respetando la espera mínima y la polifonía.
## Devuelve false si se descartó para no saturar.
func sonar(nombre: String, tono := 1.0, volumen_db := 0.0) -> bool:
	if not efectos.has(nombre):
		return false
	if reloj - float(ultimo.get(nombre, -99.0)) < float(ESPERA.get(nombre, 0.05)):
		descartados += 1
		return false
	inicios = inicios.filter(func(t): return reloj - t < 0.1)
	if inicios.size() >= RAFAGA_MAX:
		descartados += 1
		return false
	var libre: AudioStreamPlayer = null
	for p in reproductores:
		if not p.playing:
			libre = p
			break
	if libre == null:
		descartados += 1
		return false
	ultimo[nombre] = reloj
	inicios.append(reloj)
	reproducidos.append(nombre)
	if reproducidos.size() > 64:
		reproducidos = reproducidos.slice(-64)
	libre.stream = efectos[nombre]
	libre.pitch_scale = tono
	libre.volume_db = volumen_db
	libre.play()
	return true


func programar(retraso: float, nombre: String, tono := 1.0) -> void:
	_cola.append([reloj + retraso, nombre, tono])
	_cola.sort_custom(func(a, b): return a[0] < b[0])


## Un paso de una máquina de Turing: lectura o escritura y luego el movimiento.
## El tono sube con la posición del cabezal para "oír" por dónde va.
func operacion_mt(t: Dictionary) -> void:
	if t.is_empty():
		return
	var pos = t.get("posicion", 0)
	var cabeza: int = pos[0] if pos is Array else int(pos)
	var tono := 1.0 + clampf(cabeza, 0, 12) * 0.03
	var escribe: bool = str(t.get("escrito", "")) != str(t.get("leido", ""))
	sonar("mt_escribir" if escribe else "mt_leer", tono)
	var mov = t.get("mov", "S")
	var se_mueve := false
	if mov is Array:
		for m in mov:
			se_mueve = se_mueve or m != "S"
	else:
		se_mueve = mov != "S"
	if se_mueve:
		programar(0.05, "mt_mover", tono)
	if not t.get("definida", true):
		programar(0.08, "mt_rechaza")


## Muchas operaciones a la vez (el radar procesa todo en un fotograma): se
## agrupan en una ráfaga corta de unos pocos pitidos y el resultado.
func rafaga_mt(pasos: int, acepta: bool) -> void:
	var n := clampi(pasos / 8, 2, 6)
	for k in n:
		programar(k * 0.08, "mt_leer" if k % 2 == 0 else "mt_escribir", 1.0 + k * 0.08)
	programar(n * 0.08 + 0.05, "mt_acepta" if acepta else "mt_rechaza")


## Efectos visuales de la partida que también suenan.
func efecto(ef: Dictionary) -> void:
	match ef["tipo"]:
		"joya":
			sonar("joya")
		"moneda":
			sonar("moneda")
		"resuelto":
			sonar("mt_acepta")
		"error":
			sonar("mt_rechaza")
		"laser_cruzado":
			sonar("laser")
		"puertas":
			sonar("puerta")
		"laser", "camaras":
			sonar("puerta", 1.3)
		"oculto":
			sonar("oculto")
		"bloqueado":
			sonar("bloqueado")
		"sale":
			sonar("crujido", 0.8)
		"crujido":
			sonar("crujido")
		"agotado":
			sonar("mt_rechaza", 0.8)
		"radar_aviso":
			sonar("radar_aviso")
		"radar_barrido":
			sonar("radar_barrido")
		"radar_intrusion":
			sonar("radar_ping", 0.8)
			rafaga_mt(ef.get("pasos", 30), true)
		"radar_limpio":
			rafaga_mt(ef.get("pasos", 30), false)


## Eventos del gestor de seguridad (señal Seguridad.evento).
func evento_seguridad(tipo: String, _texto: String, datos: Dictionary) -> void:
	match tipo:
		"alerta":
			sonar("radio")
		"alarma":
			sonar("alarma")
		"estado":
			match datos.get("despues", ""):
				Def.SOSPECHA:
					sonar("sospecha")
				Def.PERSECUCION:
					sonar("persecucion")
