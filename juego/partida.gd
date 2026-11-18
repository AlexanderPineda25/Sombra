## Una partida de un nivel: reúne el mapa y las entidades y aplica las reglas.
class_name Partida
extends RefCounted

const T := Config.TILE

## Círculo que se expande para mostrar un ruido.
class Onda:
	var pos: Vector2
	var radio: float
	var color: Color
	var t := 0.0
	var duracion := 0.7

	func _init(p: Vector2, r: float, c: Color) -> void:
		pos = p
		radio = r
		color = c

	func viva() -> bool:
		return t < duracion


var indice: int
var nombre: String
var mapa: Mapa
var jugador: Jugador
var guardias: Array = []
var camaras: Array = []
var joyas: Array = []
var total_joyas := 0
var recogidas := 0
var monedas: Array = []
var ondas: Array = []
var destellos: Array = []        ## [pos, t] al recoger una joya
var tiempo := 0.0
var t_ruido := 0.0
var resultado := ""              ## "" | "atrapado" | "escapo"
var alarmas := 0
var monedas_usadas := 0
var demo := false
var terminales: Array = []      ## {pos: Vector2i, desafio: Desafio}
var laser_activo := true
var t_laser := 0.0              ## espera entre dos alarmas del láser
var efectos: Array = []         ## eventos visuales pendientes para la escena
var alarmas_silenciadas := false
var seguridad := Seguridad.new()
var ocultamiento := Ocultamiento.new()
var radares: Array = []
var energia := Energia.new()     ## batería para correr (máquina de Turing estándar)
## Última máquina de Turing de cada tipo usada en la partida (la muestra la
## consola F1): variante -> {origen, desafio | maquina, nombres}
var maquinas := {}


func _init(p_indice: int, p_demo := false) -> void:
	var datos: Dictionary = Niveles.datos(p_indice)
	indice = p_indice
	nombre = datos["nombre"]
	mapa = Mapa.new(datos["mapa"])
	jugador = Jugador.new(mapa.inicio)
	var rutas: Array = datos["guardias"]
	for i in rutas.size():
		var g := Guardia.new(i, rutas[i], mapa)
		g.seguridad = seguridad
		guardias.append(g)
	for c in datos["camaras"]:
		camaras.append(Camara.new(c[0], c[1], mapa))
	for t in datos.get("terminales", []):
		terminales.append({"pos": t[0], "desafio": Desafio.crear(t[1])})
	var rads: Array = datos.get("radares", [])
	for i in rads.size():
		# el primer escaneo llega antes, para que el jugador conozca el radar pronto
		radares.append(Radar.new(rads[i], mapa, -Ajustes.radar_intervalo * 0.4 + i * 3.0))
	laser_activo = not mapa.laseres.is_empty()
	joyas = mapa.joyas.duplicate()
	total_joyas = joyas.size()
	demo = p_demo
	maquinas["bateria"] = {"origen": "Energía del ladrón (Shift)", "maquina": energia.maquina,
			"nombres": ["Batería"]}


# --- eventos ------------------------------------------------------------- #
func salida_abierta() -> bool:
	return recogidas >= total_joyas


func detecciones() -> int:
	var n := 0
	for g in guardias:
		n += g.persecuciones
	return n


## Un ruido llega como símbolo "r" a todos los guardias dentro del radio.
func ruido(t: Vector2i, radio: float, color := Color.WHITE) -> void:
	for g in guardias:
		g.oir(t, radio)
	ondas.append(Onda.new(Mapa.centro(t), radio * T, color))


# --- terminales de seguridad ------------------------------------------- #
## La terminal junto al jugador (o null si no hay ninguna a su alcance).
func terminal_cercana():
	for t in terminales:
		if Mapa.centro(t["pos"]).distance_to(jugador.pos) < Config.TILE * 1.25:
			return t
	return null


## Aplica el efecto de un desafío resuelto: la salida de la máquina de Turing
## se convierte en un cambio en el museo.
func resolver_terminal(t: Dictionary) -> void:
	var d: Desafio = t["desafio"]
	if d.resuelto:
		return
	d.resuelto = true
	seguridad.registrar("turing", "%s: la máquina %s ACEPTÓ. Sistema desactivado." % [d.titulo, d.variante])
	match d.efecto:
		"puerta":
			mapa.abrir_puertas()
			efectos.append({"tipo": "puertas"})
		"camaras":
			alarmas_silenciadas = true
			for c in camaras:
				c.desactivar()               # símbolo x en el AFD de cada cámara
			efectos.append({"tipo": "camaras"})
		"laser":
			laser_activo = false
			efectos.append({"tipo": "laser"})
	efectos.append({"tipo": "resuelto", "pos": Mapa.centro(t["pos"])})


## Un intento fallido hace sonar un pitido: los guardias cercanos lo oyen.
func fallar_terminal(t: Dictionary) -> void:
	t["desafio"].intentos += 1
	seguridad.registrar("turing", "%s: la máquina RECHAZÓ. Pitido de error." % t["desafio"].titulo)
	ruido(t["pos"], Config.RUIDO_TERMINAL, Color(1.0, 0.45, 0.3))
	efectos.append({"tipo": "error", "pos": Mapa.centro(t["pos"])})


## Un fallo FÍSICO en un minijuego (mal tiempo, cruzar con el láser encendido,
## forzar un rotor): hace ruido, pero NO es un rechazo de la máquina de Turing
## y no cuenta como intento lógico.
func fallo_fisico(t: Dictionary, motivo: String) -> void:
	seguridad.registrar("seguridad", "%s: fallo físico (%s). Ruido en la terminal." % [t["desafio"].titulo, motivo])
	ruido(t["pos"], Config.RUIDO_TERMINAL * 0.75, Color(1.0, 0.7, 0.3))
	efectos.append({"tipo": "bloqueado", "pos": Mapa.centro(t["pos"])})


func alarma(t: Vector2i, origen := "cámara") -> void:
	alarmas += 1
	seguridad.registrar("alarma", "Alarma activada por %s." % origen, {"pos": Mapa.centro(t)})
	ruido(t, Config.RUIDO_ALARMA, Color(1.0, 0.31, 0.31))


func lanzar_moneda(destino_px: Vector2) -> bool:
	var j := jugador
	if j.monedas <= 0 or resultado != "":
		return false
	var dif := destino_px - j.pos
	var d := dif.length()
	if d < 4.0:
		return false
	var alcance := minf(d, Config.ALCANCE_MONEDA * T)
	var fin := mapa.rayo(j.pos, dif.angle(), alcance)
	var t := Mapa.tile_de(fin)
	if not mapa.caminable(t):
		return false
	j.monedas -= 1
	monedas_usadas += 1
	j.angulo = dif.angle()
	j.hacer("lanzar", 0.35)
	monedas.append(Moneda.new(j.pos, t))
	return true


# --- actualización ------------------------------------------------------- #
func actualizar(dt: float, dir := Vector2.ZERO, correr := false, agachar := false) -> void:
	if resultado != "":
		return
	tiempo += dt
	var j := jugador
	if not demo:
		var antes := energia.agotado
		j.actualizar(dt, dir, correr and energia.puede_correr(), mapa, agachar)
		energia.actualizar(dt, j.corriendo)
		if energia.agotado and not antes:
			seguridad.registrar("turing", "Batería: la MT RECHAZA la orden g (gastar): energía agotada.",
					{"maquina": "bateria"})
			efectos.append({"tipo": "agotado", "pos": j.pos})
	if demo:
		j.oculto = true
	else:
		for ev in ocultamiento.actualizar(dt, j, mapa, guardias):
			match ev:
				"oculto":
					seguridad.registrar("oculto", "El ladrón se ocultó en un arbusto.")
					efectos.append({"tipo": "oculto", "pos": j.pos})
				"bloqueado":
					seguridad.registrar("oculto", "No puede ocultarse: un guardia lo está viendo.")
					efectos.append({"tipo": "bloqueado", "pos": j.pos})
				"sale":
					seguridad.registrar("oculto", "El ladrón salió del arbusto.")
					efectos.append({"tipo": "sale", "pos": j.pos})
				"crujido":
					ruido(j.tile(), Config.RUIDO_CRUJIDO, Color(0.5, 1.0, 0.6))
					efectos.append({"tipo": "crujido", "pos": j.pos})

	# correr hace ruido
	if j.corriendo:
		t_ruido += dt
		if t_ruido >= Config.INTERVALO_RUIDO_CORRER:
			t_ruido = 0.0
			ruido(j.tile(), Config.RUIDO_CORRER, Color(0.78, 0.78, 1.0))
	else:
		t_ruido = Config.INTERVALO_RUIDO_CORRER * 0.6

	# joyas y salida
	if j.tile() in joyas:
		joyas.erase(j.tile())
		recogidas += 1
		destellos.append([j.pos, 0.0])
		j.hacer("recoger", 0.4)
		efectos.append({"tipo": "joya", "pos": Mapa.centro(j.tile())})
		seguridad.registrar("joya", "Joya robada (%d/%d)." % [recogidas, total_joyas])
	if salida_abierta() and j.tile() == mapa.salida and not demo:
		resultado = "escapo"

	# rejilla láser: cruzarla activa la alarma
	t_laser = maxf(0.0, t_laser - dt)
	if laser_activo and not demo and j.tile() in mapa.laseres and t_laser <= 0.0:
		t_laser = 2.0
		alarma(j.tile(), "la rejilla láser")
		efectos.append({"tipo": "laser_cruzado", "pos": j.pos})

	# monedas
	for m in monedas:
		if m.actualizar(dt):
			efectos.append({"tipo": "moneda", "pos": Mapa.centro(m.tile)})
			seguridad.registrar("moneda", "Una moneda cae en (%d, %d): ruido de radio %.1f." % [m.tile.x, m.tile.y,
					Config.RUIDO_MONEDA], {"pos": Mapa.centro(m.tile)})
			ruido(m.tile, Config.RUIDO_MONEDA, Color(1.0, 0.84, 0.35))
	monedas = monedas.filter(func(m): return m.t < Moneda.DURACION + 0.6)

	# guardias y cámaras
	for g in guardias:
		g.actualizar(dt, j, demo)
		if not demo and g.pos.distance_to(j.pos) < Config.RADIO_ATRAPAR * T:
			resultado = "atrapado"
	for c in camaras:
		c.actualizar(dt, j, self, demo)
	if not demo:
		for r in radares:
			_actualizar_radar(r, dt)
	seguridad.repartir(guardias)
	seguridad.actualizar(dt, guardias)

	for o in ondas:
		o.t += dt
	ondas = ondas.filter(func(o): return o.viva())
	for d in destellos:
		d[1] += dt
	destellos = destellos.filter(func(d): return d[1] < 0.8)


# --- máquinas de Turing usadas --------------------------------------------- #
func registrar_maquina(variante: String, entrada: Dictionary) -> void:
	maquinas[variante] = entrada


## La máquina de una entrada de `maquinas` (las terminales la reconstruyen al
## reiniciar, por eso se guarda el desafío y no la máquina).
static func maquina_de(entrada: Dictionary) -> MaquinaTuring:
	if entrada.has("desafio"):
		return entrada["desafio"].maquina
	return entrada.get("maquina", null)


# --- radares ------------------------------------------------------------- #
func _actualizar_radar(r: Radar, dt: float) -> void:
	var res := r.actualizar(dt, jugador, guardias)
	if res.is_empty():
		return
	match res["tipo"]:
		"aviso":
			seguridad.registrar("radar", "Radar (%d, %d): AFD REPOSO -t-> AVISO. Escaneo en %.1f s." % [r.tile.x,
					r.tile.y, Ajustes.radar_aviso], {"pos": r.pos})
			efectos.append({"tipo": "radar_aviso", "pos": r.pos})
		"barrido":
			seguridad.registrar("radar", "Radar: AVISO -t-> BARRIDO. Registrando %d sectores." % Radar.SECTORES,
					{"pos": r.pos})
			efectos.append({"tipo": "radar_barrido", "pos": r.pos})
		"intrusion", "limpio":
			registrar_maquina("multicinta", {"origen": "Radar · correlador de sensores", "maquina": r.correlador,
					"nombres": ["P presencia", "A transp.", "I intruso"]})
			registrar_maquina("multipista", {"origen": "Radar · analizador de señales", "maquina": r.analizador,
					"nombres": ["I intruso", "V eco", "O oculto", "Resultado"]})
	match res["tipo"]:
		"intrusion":
			seguridad.registrar("turing", "Radar: MT multicinta + multipista ACEPTAN en %d pasos -> INTRUSIÓN en el sector %d." % [
					res["pasos"], res["sector"]], {"maquina": "radar"})
			alarmas += 1
			seguridad.registrar("alarma", "Alarma del radar: intruso fuera de escondite.", {"pos": res["pos"]})
			seguridad.pedir_alerta(res["pos"], "radar", true)
			efectos.append({"tipo": "radar_intrusion", "pos": r.pos, "objetivo": res["pos"], "pasos": res["pasos"]})
		"limpio":
			seguridad.registrar("turing", "Radar: la MT multipista RECHAZA (%d pasos): sin intrusos visibles." % res["pasos"],
					{"maquina": "radar"})
			efectos.append({"tipo": "radar_limpio", "pos": r.pos, "pasos": res["pasos"]})
