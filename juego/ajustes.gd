## Ajustes configurables por el jugador (se guardan en user://ajustes.cfg).
## Se pueden cambiar desde la pestaña "Ajustes" de la consola F1.
class_name Ajustes
extends RefCounted

const ARCHIVO := "user://ajustes.cfg"

static var radar_intervalo := 22.0      ## segundos entre dos escaneos
static var radar_aviso := 2.5           ## segundos de advertencia antes del barrido
static var radar_barrido := 3.0         ## duración de una vuelta completa
static var radar_alcance := 9.0         ## casillas
static var musica_volumen := 0.8        ## 0..1
static var musica_intensidad := 1.0     ## cuánto suben las capas con la amenaza (0..1.5)
static var efectos_volumen := 0.8       ## 0..1
static var dificultad := 1.0            ## 0.6 fácil, 1 normal, 1.4 difícil
static var tutoriales_vistos := {}      ## id -> true
static var guardar_en_disco := true     ## las pruebas lo apagan

const CLAVES := ["radar_intervalo", "radar_aviso", "radar_barrido", "radar_alcance",
		"musica_volumen", "musica_intensidad", "efectos_volumen", "dificultad"]


static func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	for k in CLAVES:
		if cfg.has_section_key("ajustes", k):
			set_valor(k, cfg.get_value("ajustes", k))
	tutoriales_vistos = cfg.get_value("progreso", "tutoriales", {})


static func guardar() -> void:
	if not guardar_en_disco:
		return
	var cfg := ConfigFile.new()
	for k in CLAVES:
		cfg.set_value("ajustes", k, valor(k))
	cfg.set_value("progreso", "tutoriales", tutoriales_vistos)
	cfg.save(ARCHIVO)


static func tutorial_visto(id: String) -> bool:
	return tutoriales_vistos.has(id)


static func marcar_tutorial(id: String) -> void:
	tutoriales_vistos[id] = true
	guardar()


static func valor(k: String):
	match k:
		"radar_intervalo": return radar_intervalo
		"radar_aviso": return radar_aviso
		"radar_barrido": return radar_barrido
		"radar_alcance": return radar_alcance
		"musica_volumen": return musica_volumen
		"musica_intensidad": return musica_intensidad
		"efectos_volumen": return efectos_volumen
		"dificultad": return dificultad
	return null


static func set_valor(k: String, v) -> void:
	match k:
		"radar_intervalo": radar_intervalo = float(v)
		"radar_aviso": radar_aviso = float(v)
		"radar_barrido": radar_barrido = float(v)
		"radar_alcance": radar_alcance = float(v)
		"musica_volumen": musica_volumen = float(v)
		"musica_intensidad": musica_intensidad = float(v)
		"efectos_volumen": efectos_volumen = float(v)
		"dificultad": dificultad = float(v)
