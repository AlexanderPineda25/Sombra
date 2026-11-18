## Guardia controlado por un AFD (comportamiento) y un autómata de pila
## (ruta de regreso a su puesto).
##
## El guardia no decide con "if" sobre su estado cuándo cambiar: traduce lo que
## percibe en símbolos (v, r, p, l, t) y se los entrega al AFD con evento().
## El estado actual decide solo QUÉ HACE (la salida del estado).
class_name Guardia
extends RefCounted

const T := Config.TILE
const SIN_TILE := Vector2i(-99, -99)

var id: int
var mapa: Mapa
var ruta: Array
var idx := 0
var tile: Vector2i
var pos: Vector2
var destino := SIN_TILE
var angulo := 0.0

var afd: AFD
var pila: AutomataPilaRegreso

var objetivo := SIN_TILE
var ultimo_visto := SIN_TILE
var sospecha := 0.0
var t_estado := 0.0
var t_sin_ver := 0.0
var mirando := false
var t_mirando := 0.0
var mirar_base := 0.0
var viendo := false
var detenido := false
var ultimo_evento := ""
var registro: Array = []          ## [evento, estado_antes, estado_despues]
var persecuciones := 0
var moviendo := false
var variante := 0                 ## aspecto del uniforme (0, 1 o 2)
var seguridad: Seguridad          ## para registrar eventos y pedir alertas por radio
var rng := RandomNumberGenerator.new()
var puntos_busqueda: Array = []   ## lugares por registrar tras una alerta del radar
var multiplicador_oido: float
var multiplicador_vista: float
var t_oido := 0.0                 ## evita reaccionar a cada paso en cada fotograma
## Pausas del programa de patrulla (lenguaje SOMBRA): índice de la ruta ->
## {tipo: "esperar" | "mirar", segundos, angulo}. El guardia las interpreta
## al llegar a ese punto mientras está en PATRULLA.
var pausas := {}
var pausa_restante := 0.0
var pausa_actual := {}
var pausa_hecha := -1
var pausa_base := 0.0


## `programa` es un Array de casillas o, si viene del compilador de niveles,
## {puntos: [...], acciones: {indice_del_punto: pausa}}.
func _init(p_id: int, programa, p_mapa: Mapa, modo := Ajustes.Modo.FACIL) -> void:
	multiplicador_oido = Ajustes.OIDO[modo]
	multiplicador_vista = Ajustes.VISTA[modo]
	id = p_id
	variante = p_id % 3
	rng.seed = 1000 + p_id
	mapa = p_mapa
	var puntos: Array = programa["puntos"] if programa is Dictionary else programa
	var acciones: Dictionary = programa.get("acciones", {}) if programa is Dictionary else {}
	_armar_ruta(puntos, acciones)
	tile = ruta[0]
	pos = Mapa.centro(tile)
	var siguiente: Vector2i = ruta[1 % ruta.size()]
	angulo = Vector2(siguiente - tile).angle()
	afd = Def.crear_afd_guardia()
	pila = AutomataPilaRegreso.new()


## Expande los puntos de la ruta con BFS (como Mapa.ruta_cerrada) y anota en
## qué posición de la ruta expandida cae cada punto con pausa.
func _armar_ruta(puntos: Array, acciones: Dictionary) -> void:
	ruta = [puntos[0]]
	if acciones.has(0):
		pausas[0] = acciones[0]
	for k in puntos.size():
		var b: Vector2i = puntos[(k + 1) % puntos.size()]
		var tramo = mapa.bfs(puntos[k], b)
		if tramo == null:
			push_error("no hay camino de %s a %s" % [puntos[k], b])
			break
		ruta.append_array(tramo)
		if k + 1 < puntos.size() and acciones.has(k + 1):
			pausas[ruta.size() - 1] = acciones[k + 1]
	if ruta.size() > 1:
		ruta.pop_back()               # el último repite el primero


func en_pausa() -> bool:
	return pausa_restante > 0.0


static func diferencia_angular(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


static func girar_hacia(actual: float, objetivo_ang: float, maximo: float) -> float:
	var d := diferencia_angular(objetivo_ang, actual)
	if absf(d) <= maximo:
		return objetivo_ang
	return actual + maximo * signf(d)


# --- AFD ---------------------------------------------------------------- #
func estado() -> String:
	return afd.actual


func evento(simbolo: String) -> String:
	var antes := afd.actual
	var despues := afd.paso(simbolo)
	ultimo_evento = simbolo
	if antes != despues:
		registro.append([simbolo, antes, despues])
		if registro.size() > 12:
			registro = registro.slice(-12)
		if seguridad:
			seguridad.registrar("estado", "G%d: δ(%s, %s) = %s  (%s)" % [id + 1, antes, simbolo, despues,
					Def.NOMBRE_EVENTO[simbolo]], {"guardia": id, "antes": antes, "despues": despues, "simbolo": simbolo})
		_entrar(despues, antes)
	return despues


## Acciones al entrar en un estado (la "salida" del AFD).
func _entrar(nuevo: String, antes: String) -> void:
	t_estado = 0.0
	mirando = false
	pausa_restante = 0.0
	match nuevo:
		Def.REGRESO:
			pila.iniciar_vuelta()
		Def.PATRULLA:
			pila.reiniciar()
			sospecha = 0.0
			puntos_busqueda.clear()
			if tile in ruta:
				idx = ruta.find(tile)
		Def.BUSQUEDA:
			if antes == Def.PERSECUCION and ultimo_visto != SIN_TILE:
				objetivo = ultimo_visto
			else:
				objetivo = tile
		Def.PERSECUCION:
			puntos_busqueda.clear()
			sospecha = 1.0
			persecuciones += 1
			if seguridad:
				seguridad.registrar("deteccion", "G%d detectó al ladrón e inicia la persecución." % (id + 1),
						{"guardia": id})
				# el guardia comunica el incidente por radio a sus compañeros
				var visto := Mapa.centro(ultimo_visto) if ultimo_visto != SIN_TILE else pos
				seguridad.pedir_alerta(visto, "radio del guardia G%d" % (id + 1))


func oir(t: Vector2i, radio: float) -> bool:
	if Mapa.centro(t).distance_to(pos) > radio * T:
		return false
	if estado() != Def.PERSECUCION:
		objetivo = t
	evento("r")
	return true


## Alerta global recibida por radio (símbolo a).
## - Del radar (`exacto`): el radar midió la posición, así que TODOS van a ese
##   punto. Si al llegar el ladrón ya no está, registran el área circundante.
## - De un compañero o una cámara: nadie conoce la posición exacta; los
##   cercanos acuden con un margen de error y los lejanos registran su sector.
func recibir_alerta(lugar: Vector2, exacto := false) -> void:
	if estado() == Def.PERSECUCION:
		evento("a")                      # δ(PERSECUCION, a) = PERSECUCION
		return
	var dist := lugar.distance_to(pos) / T
	if exacto:
		var t := Mapa.tile_de(lugar)
		objetivo = t if mapa.caminable(t) else mapa.casilla_cercana(t, 1.0, rng)
		puntos_busqueda.clear()
		for k in Config.PUNTOS_BUSQUEDA_AMPLIA:
			puntos_busqueda.append(mapa.casilla_cercana(objetivo, Config.RADIO_BUSQUEDA_AMPLIA, rng))
	elif dist <= Config.RADIO_RESPUESTA_ALERTA:
		var error := clampf(dist * 0.25, 1.0, 4.0)
		objetivo = mapa.casilla_cercana(Mapa.tile_de(lugar), error, rng)
	else:
		objetivo = mapa.casilla_cercana(tile, 4.0, rng)
	evento("a")


# --- visión ------------------------------------------------------------- #
func alcance() -> float:
	return (Config.ALCANCE_PERSECUCION if estado() == Def.PERSECUCION else Config.ALCANCE_GUARDIA) * T


func ve(j: Jugador) -> bool:
	var dif := j.pos - pos
	var d := dif.length()
	if d > alcance():
		return false
	if j.oculto:
		# el arbusto lo protege, salvo de un guardia que lo persigue muy de cerca
		# o que registra los arbustos durante una búsqueda
		var cerca_persecucion := estado() == Def.PERSECUCION and d < 1.5 * T
		var registra_arbusto := estado() == Def.BUSQUEDA and d < 0.85 * T
		if not (cerca_persecucion or registra_arbusto):
			return false
	if d > 0.9 * T:
		if absf(diferencia_angular(dif.angle(), angulo)) > deg_to_rad(Config.MEDIO_ANGULO_GUARDIA):
			return false
	return mapa.linea_libre(pos, j.pos)


# --- actualización ------------------------------------------------------- #
func actualizar(dt: float, j: Jugador, demo := false) -> void:
	t_estado += dt
	var visible := (not demo) and ve(j)
	viendo = visible
	detenido = false

	if visible:
		ultimo_visto = j.tile()
		t_sin_ver = 0.0
		if estado() == Def.PERSECUCION:
			evento("v")
		else:
			var d := j.pos.distance_to(pos) / T
			var tasa := 2.6 if d < 2.5 else (1.5 if d < 4.5 else 0.85)
			if j.corriendo:
				tasa *= 1.4
			if j.agachado:
				tasa *= 0.55            # agachado cuesta más verlo
			if estado() in [Def.ALERTA, Def.BUSQUEDA, Def.SOSPECHA]:
				tasa *= 1.6
			sospecha += tasa * multiplicador_vista * dt   # la dificultad acelera la detección
			if sospecha >= 1.0:
				evento("v")
			elif sospecha > 0.3 and estado() in [Def.PATRULLA, Def.REGRESO]:
				objetivo = j.tile()
				evento("s")             # vio algo raro: SOSPECHA
			if estado() == Def.SOSPECHA:
				# se detiene y se queda mirando qué fue eso
				objetivo = j.tile()
				detenido = true
				angulo = girar_hacia(angulo, (j.pos - pos).angle(), 4.0 * dt)
	else:
		if not demo:
			_oir_pasos(j, dt)
		if estado() == Def.PERSECUCION:
			t_sin_ver += dt
			if t_sin_ver > Config.TIEMPO_SIN_VER:
				evento("p")
		else:
			sospecha = maxf(0.0, sospecha - (0.22 if estado() == Def.SOSPECHA else 0.35) * dt)

	if estado() == Def.SOSPECHA and (sospecha <= 0.0 or t_estado > Config.TIEMPO_SOSPECHA):
		evento("t")                         # no era nada: vuelve con la pila
	if estado() == Def.ALERTA and t_estado > Config.TIEMPO_ALERTA:
		evento("t")
	if estado() in [Def.BUSQUEDA, Def.SOSPECHA] and mirando:
		t_mirando += dt
		angulo = mirar_base + sin(t_mirando * 2.6) * 1.4
		if estado() == Def.BUSQUEDA and t_mirando > Config.TIEMPO_BUSQUEDA:
			if not puntos_busqueda.is_empty():
				# búsqueda amplia: registra el siguiente lugar alrededor del punto
				objetivo = puntos_busqueda.pop_front()
				mirando = false
				t_estado = 0.0
			else:
				evento("t")

	if estado() == Def.PATRULLA and pausa_restante > 0.0:
		_pausar(dt)
		detenido = true
	if not detenido:
		_mover(dt, j)


## Ejecuta la pausa en curso: 'mirar' gira hacia una dirección y se queda;
## 'esperar' se queda quieto barriendo con la linterna a ambos lados.
func _pausar(dt: float) -> void:
	pausa_restante -= dt
	var dur: float = pausa_actual["segundos"]
	var t := dur - pausa_restante
	if pausa_actual["tipo"] == "mirar":
		angulo = girar_hacia(angulo, pausa_actual["angulo"], 5.0 * dt)
	else:
		angulo = pausa_base + sin(t * 2.2) * 0.9
	if pausa_restante <= 0.0:
		pausa_restante = 0.0


## Pasos cercanos: caminar de pie a menos de RADIO_PASOS casillas hace que el
## guardia sospeche y se voltee al instante; correr se oye desde más lejos y
## lo pone en ALERTA. Agachado u oculto no se le oye.
func _oir_pasos(j: Jugador, dt: float) -> void:
	t_oido = maxf(0.0, t_oido - dt)
	if j.oculto or not j.moviendo or j.agachado or estado() == Def.PERSECUCION:
		return
	var d := j.pos.distance_to(pos) / T
	var radio := Config.RADIO_PASOS_CORRER if j.corriendo else Config.RADIO_PASOS
	if d > radio * multiplicador_oido:
		return
	angulo = (j.pos - pos).angle()          # se voltea de inmediato
	mirando = false
	if t_oido > 0.0:
		return
	t_oido = 0.5
	objetivo = j.tile()
	if j.corriendo:
		sospecha = maxf(sospecha, 0.6)
		evento("r")                          # lo oye correr: va hacia allá (ALERTA)
	else:
		sospecha = maxf(sospecha, 0.35)
		if estado() in [Def.PATRULLA, Def.REGRESO, Def.SOSPECHA]:
			evento("s")                      # pasos cerca: SOSPECHA
	if seguridad:
		seguridad.registrar("ruido", "G%d oye pasos %s a %.1f casillas y se voltea." % [id + 1,
				"corriendo" if j.corriendo else "caminando", d], {"guardia": id})


func _iniciar_paso(sig: Vector2i, registrar: bool) -> void:
	if not mapa.caminable(sig):
		destino = SIN_TILE
		return
	if registrar:
		pila.registrar(AutomataPilaRegreso.direccion(sig - tile))
	destino = sig


func _elegir_destino(j: Jugador) -> void:
	match estado():
		Def.PATRULLA:
			if ruta[idx] == tile and pausas.has(idx) and pausa_hecha != idx:
				pausa_hecha = idx              # interpreta la orden del programa
				pausa_actual = pausas[idx]
				pausa_restante = pausa_actual["segundos"]
				pausa_base = angulo
				return
			if ruta[idx] != tile:
				if tile in ruta:
					idx = ruta.find(tile)
				else:
					var camino = mapa.bfs(tile, ruta[idx])
					if camino:
						_iniciar_paso(camino[0], false)
					return
			idx = (idx + 1) % ruta.size()
			pausa_hecha = -1
			_iniciar_paso(ruta[idx], false)

		Def.ALERTA:
			if objetivo == SIN_TILE or tile == objetivo:
				evento("l")
				return
			var camino = mapa.bfs(tile, objetivo)
			if not camino:
				evento("l")
				return
			_iniciar_paso(camino[0], true)

		Def.PERSECUCION:
			var meta := j.tile() if viendo else ultimo_visto
			if meta != SIN_TILE and meta != tile:
				var camino = mapa.bfs(tile, meta)
				if camino:
					_iniciar_paso(camino[0], true)

		Def.BUSQUEDA:
			if objetivo != SIN_TILE and tile != objetivo:
				var camino = mapa.bfs(tile, objetivo)
				if camino:
					_iniciar_paso(camino[0], true)
					return
			if not mirando:
				mirando = true
				t_mirando = 0.0
				mirar_base = angulo
				evento("l")

		Def.SOSPECHA:
			# se acerca despacio a donde vio algo; cada paso va a la pila
			if objetivo != SIN_TILE and tile != objetivo:
				var camino = mapa.bfs(tile, objetivo)
				if camino:
					_iniciar_paso(camino[0], true)
					return
			if not mirando:
				mirando = true
				t_mirando = 0.0
				mirar_base = angulo

		Def.REGRESO:
			var p := pila.siguiente_regreso()
			if p == "":
				evento("l")               # pila vacía: volvió a su puesto
				return
			_iniciar_paso(tile + AutomataPilaRegreso.DESPLAZAMIENTO[p], false)


func _mover(dt: float, j: Jugador) -> void:
	moviendo = false
	if destino == SIN_TILE:
		_elegir_destino(j)
		if destino == SIN_TILE:
			return
	var meta := Mapa.centro(destino)
	var dif := meta - pos
	var d := dif.length()
	var paso: float = Config.VEL_GUARDIA[estado()] * T * dt
	if d > 0.01 and not mirando:
		angulo = girar_hacia(angulo, dif.angle(), 9.0 * dt)
	moviendo = true
	if d <= paso:
		pos = meta
		tile = destino
		destino = SIN_TILE
	else:
		pos += dif / d * paso


## "!" persiguiendo, "?" sospechando, "" tranquilo.
func icono() -> String:
	if estado() == Def.PERSECUCION:
		return "!"
	if estado() in [Def.ALERTA, Def.BUSQUEDA, Def.SOSPECHA] or sospecha > 0.05:
		return "?"
	return ""
