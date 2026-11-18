## El robot lleva una sola gema. El lector recorre el riel al comprobar el patrón.
class_name MJCerradura
extends Minijuego

const Y_RIEL := 325.0
const CENTRO := 480.0
const LUZ_CICLO := [5.6, 5.0, 4.6]

var vitrina := ""
var clave := ""
var origenes: Array[int] = []
var carga := -1
var destino := 0
var x := 0.0
var usar_al_llegar := false
var reloj_luz := 0.0
var transiciones: Array = []
var lectura := 0.0


func _preparar() -> void:
	vitrina = desafio.solucion_filas[0].get_slice("#", 0)
	clave = "_".repeat(vitrina.length())
	origenes.resize(vitrina.length())
	origenes.fill(-1)
	carga = -1
	destino = 0
	x = posicion(0)
	usar_al_llegar = false
	reloj_luz = 0.0
	transiciones.clear()
	if not desafio.resuelto:
		desafio.filas[0]["contenido"] = vitrina + "#" + "?".repeat(vitrina.length())
		desafio.construir()


func _paso_riel() -> float:
	return 64.0 if vitrina.length() > 5 else 72.0


func posicion(i: int) -> float:
	return CENTRO + (i - vitrina.length()) * _paso_riel()


func _tecla(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_LEFT, KEY_A: mover(-1)
		KEY_RIGHT, KEY_D: mover(1)
		KEY_SPACE: interactuar()
		_: return false
	return true


func _repetir(e: InputEventKey) -> bool:
	return e.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D] and _tecla(e)


func _clic(p: Vector2) -> void:
	if absf(p.y - Y_RIEL) > 70:
		return
	var i := roundi((p.x - CENTRO) / _paso_riel()) + vitrina.length()
	if i >= 0 and i <= vitrina.length() * 2 and i != vitrina.length():
		destino = i
		usar_al_llegar = true


func mover(direccion: int) -> void:
	destino = clampi(destino + direccion, 0, vitrina.length() * 2)
	usar_al_llegar = false


func _actualizar(dt: float) -> void:
	if fase == "verificando":
		lectura += dt * maxf(16.0, (vitrina.length() * vitrina.length()) * 2.0)
		avanzar_lectura(floori(lectura))
		return
	x = move_toward(x, posicion(destino), dt * 520)
	reloj_luz = fposmod(reloj_luz + dt, LUZ_CICLO[desafio.dificultad])
	if luz_encendida() and carga >= 0 and absf(x - CENTRO) < 46:
		var inicial := carga
		carga = -1
		destino = inicial
		x = posicion(destino)
		usar_al_llegar = false
		reloj_luz = 0.0
		detectado("La luz devolvió la gema. Cruza cuando se apague.", false)
		return
	if usar_al_llegar and is_equal_approx(x, posicion(destino)):
		usar_al_llegar = false
		interactuar()


func _encendido_desde() -> float:
	return 4.45 - 0.65 * desafio.dificultad


func luz_encendida() -> bool:
	return not ensayo and not accesible and reloj_luz >= _encendido_desde()


func interactuar() -> void:
	if not is_equal_approx(x, posicion(destino)):
		return
	var n := vitrina.length()
	if destino < n:
		if carga == -1 and destino not in origenes:
			carga = destino
			sonar("joya")
		elif carga == destino:
			carga = -1
		return
	if destino == n:
		return
	var i := destino - n - 1
	if carga == -1 and origenes[i] >= 0:
		carga = origenes[i]
		origenes[i] = -1
		clave[i] = "_"
	elif carga >= 0 and origenes[i] == -1:
		clave[i] = vitrina[carga]
		origenes[i] = carga
		carga = -1
		sonar("puerta", 1.25)
		if not "_" in clave:
			desafio.filas[0]["contenido"] = vitrina + "#" + clave
			desafio.construir()
			transiciones.clear()
			lectura = 0.0
			fase = "verificando"
		elif ensayo and i == _hueco(origenes[i]):
			ensayo = false
			reloj_luz = 0.0


func avanzar_lectura(hasta: int) -> void:
	var m := desafio.maquina
	var anteriores := transiciones.size()
	while not m.detenida() and transiciones.size() < mini(hasta, Desafio.MAX_PASOS):
		transiciones.append(m.paso())
	if anteriores == transiciones.size():
		return
	var resultado := "EN CURSO"
	if m.detenida():
		resultado = m.resultado()
	elif transiciones.size() >= Desafio.MAX_PASOS:
		resultado = "ERROR"
	desafio.registrar_intento([vitrina + "#" + clave], transiciones, resultado)
	if resultado != "EN CURSO":
		terminar_lectura()


func terminar_lectura() -> void:
	var resultado: String = desafio.ultimo_intento["resultado"]
	if resultado == "ACEPTA":
		completar()
	elif resultado == "RECHAZA":
		fase = "juego"
		var m := desafio.maquina as MTEstandar
		var i := clampi(m.cinta.cabezal - vitrina.length() - 1, 0, clave.length() - 1)
		destino = vitrina.length() + 1 + i
		x = posicion(destino)
		detectado("Revisa el hueco %d. Puedes recoger su gema." % _numero(i))
	else:
		fase = "juego"
		avisar("No se pudo revisar la clave. Reabre la terminal.", AMBAR)


func _hueco(i: int) -> int:
	return vitrina.length() - 1 - i if desafio.invertir else i


func _numero(hueco: int) -> int:
	return _hueco(hueco) + 1


func _progreso() -> String:
	return "%d/%d gemas" % [clave.length() - clave.count("_"), vitrina.length()]


func _ayuda() -> String:
	if fase == "verificando":
		return "El lector compara las gemas de la vitrina."
	if carga >= 0:
		if origenes[_hueco(carga)] != -1:
			return "Hueco ocupado. Devuelve la gema a su lugar en la vitrina."
		return "Lleva la gema al hueco %d  ·  Clic o flechas + Espacio" % (carga + 1)
	return "Clic para recoger una gema  ·  También puedes usar flechas + Espacio"


func _mensaje_exito() -> String:
	return "Cerradura abierta"


func _dibujar_juego() -> void:
	var n := vitrina.length()
	suelo(Rect2i(64, 207, 13, 4))
	Dibujo.texto(self, "Vitrina", Vector2(247, 180), 19, TEXTO, true, true)
	Dibujo.texto(self, "Cerradura", Vector2(713, 180), 19, TEXTO, true, true)
	draw_line(Vector2(103, Y_RIEL), Vector2(857, Y_RIEL), SUAVE, 6)
	var luz := luz_encendida()
	var aviso_luz := not ensayo and not accesible and reloj_luz >= _encendido_desde() - 0.8
	draw_rect(Rect2(CENTRO - 46, 225, 92, 222), Color(AMBAR, 0.33 if luz else (0.14 if aviso_luz else 0.035)))
	Arte.casilla(self, Arte.EMISOR_LASER, Rect2(CENTRO - 22, 206, 44, 44))
	for i in n:
		var izq := Vector2(posicion(i), Y_RIEL)
		var der := Vector2(posicion(n + 1 + i), Y_RIEL)
		casilla(Rect2(izq - Vector2(29, 29), Vector2(58, 58)), fase == "intro" and i == 0)
		casilla(Rect2(der - Vector2(29, 29), Vector2(58, 58)), carga >= 0 and _hueco(carga) == i)
		if i not in origenes and i != carga:
			ficha(vitrina[i], izq)
		if clave[i] != "_":
			ficha(clave[i], der)
		Dibujo.texto(self, str(i + 1), izq + Vector2(0, 48), 17, TEXTO, true, true)
		Dibujo.texto(self, str(_numero(i)), der + Vector2(0, 48), 17, TEXTO, true, true)
	if fase == "intro":
		var a := Vector2(posicion(0), Y_RIEL)
		var b := Vector2(posicion(n + 1 + _hueco(0)), Y_RIEL)
		var p := a.lerp(b, fposmod(tiempo, 2.6) / 2.6)
		ficha(vitrina[0], p - Vector2(0, 56), 26)
	elif fase == "verificando" and not transiciones.is_empty():
		var t: Dictionary = transiciones[mini(int(lectura), transiciones.size() - 1)]
		var punto := Vector2(posicion(int(t["posicion"])), Y_RIEL)
		draw_rect(Rect2(punto - Vector2(31, 31), Vector2(62, 62)), VERDE, false, 3)
		_robot(punto + Vector2(0, 89), str(t["estado"]).get_slice("_", 1) if str(t["estado"]).begins_with("lleva_") else "")
	else:
		_robot(Vector2(x, Y_RIEL + 89), vitrina[carga] if carga >= 0 else "")
	if aviso_luz:
		Dibujo.texto(self, "Luz encendida" if luz else "Se enciende pronto", Vector2(CENTRO, 470), 16, AMBAR, true, true)


func _robot(p: Vector2, gema: String) -> void:
	draw_rect(Rect2(p - Vector2(22, 12), Vector2(44, 28)), Config.HUD_FONDO.lightened(0.25))
	draw_rect(Rect2(p - Vector2(17, 26), Vector2(34, 20)), Config.HUD_FONDO.lightened(0.37))
	draw_circle(p + Vector2(-7, -17), 3, VERDE)
	draw_circle(p + Vector2(7, -17), 3, VERDE)
	draw_rect(Rect2(p + Vector2(-21, 13), Vector2(42, 7)), Config.HUD_FONDO)
	if gema != "":
		ficha(gema, p + Vector2(0, 2), 23)
