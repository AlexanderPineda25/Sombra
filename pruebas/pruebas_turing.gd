## Pruebas del motor de máquinas de Turing (sin escenas ni gráficos).
##
##   godot --headless --path . -s res://pruebas/pruebas_turing.gd
extends SceneTree

var total := 0
var fallos := 0
var _actual := ""


func _initialize() -> void:
	var pruebas := [
		"validacion", "incrementador_casos", "incrementador_exhaustivo",
		"descripcion_instantanea", "anbn_exhaustivo", "cinta_infinita",
		"multicinta_exhaustivo", "multicinta_cabezales_independientes",
		"multipista_exhaustivo", "multipista_un_solo_cabezal",
		"multipista_no_es_multicinta", "desafios_soluciones", "desafios_fallos",
		"desafio_edicion", "correlador_exhaustivo", "analizador_exhaustivo",
		"clave_gemas_exhaustivo", "cerradura_dinamica", "bateria",
		"equilibrio_gemas_exhaustivo", "rueda_multicinta_exhaustivo", "escalera_multipista_exhaustivo",
		"terminales_dinamicas", "cruce_colores", "reparto_botin",
	]
	for nombre in pruebas:
		_actual = nombre
		var antes := fallos
		call("test_" + nombre)
		total += 1
		print(("ok    " if fallos == antes else "FALLA ") + nombre)
	print("\n%d pruebas de máquinas de Turing, %d fallas" % [total, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, msg := "") -> void:
	if not cond:
		fallos += 1
		printerr("  [%s] falló: %s" % [_actual, msg])


func binario(n: int, ancho: int) -> String:
	var s := ""
	while n > 0:
		s = str(n % 2) + s
		n /= 2
	return s.lpad(ancho, "0")


func palabras(alfabeto: Array, largo: int) -> Array:
	var r := [""]
	for i in largo:
		var nuevas := []
		for w in r:
			for s in alfabeto:
				nuevas.append(w + s)
		r = nuevas
	return r


# ---------------------------------------------------------------------- #
func test_validacion() -> void:
	var desde_parada := MTEstandar.new("mala", ["q0", "qa", "qr"], ["0"], ["0", "_"],
			{"qa|0": ["q0", "0", "R"]}, "q0", "qa", "qr")
	comprobar(desde_parada.error != "", "no puede salir de qa")
	var blanco_en_sigma := MTEstandar.new("mala", ["q0", "qa", "qr"], ["0", "_"], ["0", "_"],
			{}, "q0", "qa", "qr")
	comprobar(blanco_en_sigma.error != "", "el blanco no puede estar en Σ")
	var mov_malo := MTEstandar.new("mala", ["q0", "qa", "qr"], ["0"], ["0", "_"],
			{"q0|0": ["qa", "0", "X"]}, "q0", "qa", "qr")
	comprobar(mov_malo.error != "", "movimiento inválido")
	for m in [ProgramasTuring.incrementador(), ProgramasTuring.anbn(),
			ProgramasTuring.suma_multicinta(), ProgramasTuring.xor_multipista()]:
		comprobar(m.error == "", m.nombre + ": " + m.error)


func test_incrementador_casos() -> void:
	var casos := {"0111": "1000", "1011": "1100", "111": "1000", "0": "1", "1": "10", "0000": "0001"}
	for entrada in casos:
		var m := ProgramasTuring.incrementador()
		m.cargar(entrada)
		comprobar(m.ejecutar() == "ACEPTA", entrada)
		comprobar(m.cinta.contenido() == casos[entrada], "%s -> %s" % [entrada, m.cinta.contenido()])
	var vacia := ProgramasTuring.incrementador()
	vacia.cargar("")
	comprobar(vacia.ejecutar() == "RECHAZA", "la palabra vacía se rechaza")


func test_incrementador_exhaustivo() -> void:
	for largo in range(1, 7):
		for n in int(pow(2, largo)):
			var w := binario(n, largo)
			var m := ProgramasTuring.incrementador()
			m.cargar(w)
			m.ejecutar()
			var esperado := binario(n + 1, largo)
			comprobar(m.cinta.contenido() == esperado, "%s+1 dio %s" % [w, m.cinta.contenido()])


func test_descripcion_instantanea() -> void:
	var m := ProgramasTuring.incrementador()
	m.cargar("01")
	comprobar(m.descripcion_instantanea() == "[q0]01", m.descripcion_instantanea())
	m.paso()
	comprobar(m.descripcion_instantanea() == "0[q1]1", m.descripcion_instantanea())
	comprobar(m.ultima["leido"] == "0" and m.ultima["mov"] == "R")


func test_anbn_exhaustivo() -> void:
	var probadas := 0
	for largo in range(0, 9):
		for w in palabras(["a", "b"], largo):
			var n := largo / 2
			var esperado: bool = largo > 0 and largo % 2 == 0 and w == "a".repeat(n) + "b".repeat(n)
			var m := ProgramasTuring.anbn()
			m.cargar(w)
			var r := m.ejecutar()
			comprobar((r == "ACEPTA") == esperado, "'%s' -> %s" % [w, r])
			probadas += 1
	comprobar(probadas == 511, "%d palabras" % probadas)


func test_cinta_infinita() -> void:
	# el incrementador escribe a la izquierda de la posición 0 cuando desborda
	var m := ProgramasTuring.incrementador()
	m.cargar("11")
	m.ejecutar()
	comprobar(m.cinta.limites()[0] == -1, "creció hacia la izquierda")
	comprobar(m.cinta.contenido() == "100")


func test_multicinta_exhaustivo() -> void:
	for n in range(1, 5):
		var tope := int(pow(2, n))
		for a in tope:
			for b in tope:
				for k in int(pow(2, n + 1)):
					var m := ProgramasTuring.suma_multicinta()
					m.cargar([binario(a, n), binario(b, n), binario(k, n + 1)])
					var r := m.ejecutar()
					if (r == "ACEPTA") != (a + b == k):
						comprobar(false, "%d+%d vs %d dio %s" % [a, b, k, r])
						return


func test_multicinta_cabezales_independientes() -> void:
	var m := ProgramasTuring.suma_multicinta()
	m.cargar(["0101", "0111", "01100"])
	comprobar(m.ejecutar() == "ACEPTA")
	var independiente := false
	for t in m.historial:
		if t["mov"] == ["L", "L", "S"]:
			independiente = true
	comprobar(independiente, "debe haber un paso (L, L, S)")
	# en ese paso las cabezas quedan en posiciones distintas
	m.cargar(["01", "01", "010"])
	while m.estado == "q0":
		m.paso()
	comprobar(m.cintas[0].cabezal != m.cintas[2].cabezal, "cabezas 1 y 3 separadas")
	comprobar(m.cintas[2].contenido() != "", "la cinta 3 conserva la clave")


func test_multipista_exhaustivo() -> void:
	for n in range(1, 5):
		var tope := int(pow(2, n))
		for l in tope:
			for mm in tope:
				for t in tope:
					var m := ProgramasTuring.xor_multipista()
					m.cargar([binario(l, n), binario(mm, n), binario(t, n)])
					var r := m.ejecutar()
					if (r == "ACEPTA") != ((l ^ mm) == t):
						comprobar(false, "%d xor %d vs %d dio %s" % [l, mm, t, r])
						return


func test_multipista_un_solo_cabezal() -> void:
	var m := ProgramasTuring.xor_multipista()
	m.cargar(["10110", "01101", "11011"])
	var t := m.paso()
	comprobar(t["leido"] == ["1", "0", "1"], "lee la tupla completa: %s" % [t["leido"]])
	comprobar(t["escrito"] == ["1", "0", "*"], "escribe una tupla")
	comprobar(typeof(t["mov"]) == TYPE_STRING and t["mov"] == "R", "un solo movimiento")
	comprobar(m.ejecutar() == "ACEPTA")
	comprobar(m.pista(2) == "*****", "la pista 3 quedó marcada: " + m.pista(2))
	comprobar(m.pista(0) == "10110", "la pista 1 no cambia")
	comprobar(m.cabezal == 0, "regresó al inicio")


func test_multipista_no_es_multicinta() -> void:
	# una transición con un movimiento por pista no es válida en la multipista
	var mala := MTMultipista.new("mala", 2, ["q0", "qa", "qr"], ["0"], ["0", "_"],
			{"q0|0,0": ["qa", ["0", "0"], ["R", "L"]]}, "q0", "qa", "qr")
	comprobar(mala.error != "", "la multipista tiene un solo cabezal")
	var mala2 := MTMulticinta.new("mala", 2, ["q0", "qa", "qr"], ["0"], ["0", "_"],
			{"q0|0,0": ["qa", ["0", "0"], "R"]}, "q0", "qa", "qr")
	comprobar(mala2.error != "", "la multicinta mueve cada cabezal")


func test_desafios_soluciones() -> void:
	for id in ["cerradura", "alarma", "boveda", "laser"]:
		var d := Desafio.crear(id)
		var sol: Array = d.solucion_filas
		for i in d.filas.size():
			d.filas[i]["contenido"] = sol[i]
		d.construir()
		d.maquina.ejecutar()
		var r := d.comprobar()
		comprobar(r["exito"], "%s: %s" % [id, r["mensaje"]])


func test_desafios_fallos() -> void:
	for id in ["cerradura", "alarma", "boveda", "laser"]:
		var d := Desafio.crear(id)          # contenido inicial: incorrecto
		d.maquina.ejecutar()
		comprobar(not d.comprobar()["exito"], id + " no debe resolverse solo")
	for semilla in 40:                        # la cerradura nunca empieza resuelta
		var d2 := Desafio.crear("cerradura", semilla)
		d2.maquina.ejecutar()
		comprobar(not d2.comprobar()["exito"], "semilla %d empieza resuelta" % semilla)
		comprobar(d2.filas[0]["contenido"].substr(0, 5) == d2.solucion_filas[0].substr(0, 5), "la vitrina no cambia")


func test_desafio_edicion() -> void:
	var d := Desafio.crear("cerradura", 3)
	var original: String = d.filas[0]["contenido"]
	var limite := original.find("#") + 1
	d.alternar(0, 0)
	comprobar(d.filas[0]["contenido"] == original, "la vitrina no se edita")
	d.alternar(0, limite)
	comprobar(d.filas[0]["contenido"] != original, "el hueco se puede editar")
	d.poner(0, limite, "E")
	comprobar(d.filas[0]["contenido"][limite] == "E")
	comprobar((d.maquina as MTEstandar).cinta.leer_en(limite) == "E")


## El correlador multicinta escribe I = P AND NOT A en cada sector.
func test_correlador_exhaustivo() -> void:
	for n in range(1, 5):
		for vp in range(1 << n):
			for va in range(1 << n):
				var p := binario_ancho(vp, n)
				var a := binario_ancho(va, n)
				var m := ProgramasTuring.correlador_sensores()
				comprobar(m.validar() == "", m.validar())
				m.cargar([p, a, ""])
				comprobar(m.ejecutar() == "ACEPTA", "%s %s" % [p, a])
				var esperado := ""
				for i in n:
					esperado += "1" if p[i] == "1" and a[i] == "0" else "0"
				var obtenido := ""
				for i in n:
					obtenido += m.cintas[2].leer_en(i)
				comprobar(obtenido == esperado, "%s,%s -> %s (esperado %s)" % [p, a, obtenido, esperado])


## La multipista acepta si y solo si hay una columna (I=1, V=1, O=0),
## y deja el cabezal sobre el primer sector que la cumple.
func test_analizador_exhaustivo() -> void:
	for n in range(1, 4):
		for vi in range(1 << n):
			for vv in range(1 << n):
				for vo in range(1 << n):
					var i_ := binario_ancho(vi, n)
					var v := binario_ancho(vv, n)
					var o := binario_ancho(vo, n)
					var m := ProgramasTuring.analizador_radar()
					comprobar(m.validar() == "", m.validar())
					m.cargar([i_, v, o, ""])
					var r := m.ejecutar()
					var primero := -1
					for k in n:
						if i_[k] == "1" and v[k] == "1" and o[k] == "0":
							primero = k
							break
					comprobar(r == ("ACEPTA" if primero >= 0 else "RECHAZA"), "%s/%s/%s -> %s" % [i_, v, o, r])
					if primero >= 0:
						comprobar(m.cabezal == primero, "cabezal en %d (esperado %d)" % [m.cabezal, primero])


func binario_ancho(n: int, ancho: int) -> String:
	var s := ""
	for i in ancho:
		s = str(n % 2) + s
		n /= 2
	return s


## El verificador acepta una clave si y solo si es la que pide el acertijo,
## para todos los acertijos, varias vitrinas y TODAS las claves de 3 a 5 gemas.
func test_clave_gemas_exhaustivo() -> void:
	var gemas := ProgramasTuring.GEMAS
	var vitrinas := ["RZEA", "AAZR", "ERRE", "ZZZZ", "AERZ"]
	for tipo in Desafio.ACERTIJOS:
		var datos: Array = Desafio.ACERTIJOS[tipo]
		var m := ProgramasTuring.verificador_clave(datos[0], datos[1])
		comprobar(m.validar() == "", "%s: %s" % [tipo, m.validar()])
		for v in vitrinas:
			var esperada := ""
			for g in v:
				esperada += datos[0][g]
			if datos[1]:
				esperada = esperada.reverse()
			var aceptadas := 0
			for largo in [3, 4, 5]:
				var total := int(pow(4, largo))
				for n in total:
					var k := ""
					var x := n
					for i in largo:
						k += gemas[x % 4]
						x /= 4
					m = ProgramasTuring.verificador_clave(datos[0], datos[1])
					m.cargar(v + "#" + k)
					var r := m.ejecutar(5000)
					comprobar(r != "", "%s %s#%s no se detiene" % [tipo, v, k])
					if r == "ACEPTA":
						aceptadas += 1
						comprobar(k == esperada, "%s: %s#%s aceptada (esperada %s)" % [tipo, v, k, esperada])
			comprobar(aceptadas == 1, "%s/%s: exactamente una clave aceptada (%d)" % [tipo, v, aceptadas])


func test_cerradura_dinamica() -> void:
	for caso in [[Ajustes.Modo.FACIL, 4, false], [Ajustes.Modo.MEDIO, 5, true], [Ajustes.Modo.DIFICIL, 6, true]]:
		var patrones := {}
		for semilla in 30:
			var d := Desafio.crear("cerradura", semilla, caso[0])
			var patron: String = d.solucion_filas[0].get_slice("#", 0)
			patrones[patron] = true
			comprobar(patron.length() == caso[1] and d.invertir == caso[2])
			comprobar(d.ejecutar_intento(d.solucion_filas)["resultado"] == "ACEPTA")
		comprobar(patrones.size() > 5)


func test_bateria() -> void:
	var e := Energia.new(5)
	comprobar(e.nivel() == 5, "empieza llena")
	comprobar(not e.ordenar("c"), "cargar llena: RECHAZA")
	for i in 5:
		comprobar(e.ordenar("g"), "gastar %d" % i)
		comprobar(e.nivel() == 4 - i)
	comprobar(not e.ordenar("g"), "gastar vacía: RECHAZA")
	comprobar(e.maquina.estado == "qr")
	comprobar(e.ordenar("c") and e.nivel() == 1, "cargar una celda")
	# correr gasta y descansar recarga
	var f := Energia.new()
	for i in 60:
		f.actualizar(0.1, true)
	comprobar(f.agotado and f.nivel() == 0, "6 s corriendo la agotan")
	comprobar(not f.puede_correr())
	for i in 30:
		f.actualizar(0.1, false)
	comprobar(not f.agotado and f.puede_correr(), "descansar la recarga")
	comprobar(f.nivel() > Config.ENERGIA_MINIMA)



static func _palabras(largo: int) -> Array:
	var r := []
	for n in int(pow(4, largo)):
		var w := ""
		var x := n
		for i in largo:
			w += ProgramasTuring.GEMAS[x % 4]
			x /= 4
		r.append(w)
	return r


## xⁿyⁿ con gemas: todas las palabras de hasta 6 gemas, para todos los pares.
func test_equilibrio_gemas_exhaustivo() -> void:
	var G := ProgramasTuring.GEMAS
	for x in G:
		for y in G:
			if x == y:
				continue
			var m0 := ProgramasTuring.equilibrio_gemas(x, y)
			comprobar(m0.validar() == "", m0.validar())
			for largo in range(1, 7):
				for w in _palabras(largo):
					var m := ProgramasTuring.equilibrio_gemas(x, y)
					m.cargar(w)
					var n := largo / 2
					var esperado: bool = largo % 2 == 0 and w == x.repeat(n) + y.repeat(n)
					comprobar((m.ejecutar(2000) == "ACEPTA") == esperado, "%s%s: %s" % [x, y, w])


## Bóveda: para A de 3 gemas fijas, de todas las B y K, acepta solo la correcta.
func test_rueda_multicinta_exhaustivo() -> void:
	var m0 := ProgramasTuring.rueda_multicinta()
	comprobar(m0.validar() == "", m0.validar())
	for a in ["RZE", "AAR", "EZA"]:
		var aceptadas := 0
		for b in _palabras(3):
			for k in _palabras(3):
				var m := ProgramasTuring.rueda_multicinta()
				m.cargar([a, b, k])
				var r := m.ejecutar(500)
				var esperado := ""
				for i in 3:
					esperado += ProgramasTuring.siguiente_gema(a[i], ProgramasTuring.GEMAS.find(b[i]))
				if r == "ACEPTA":
					aceptadas += 1
					comprobar(k == esperado.reverse(), "%s %s %s" % [a, b, k])
		comprobar(aceptadas == 64, "una K por cada B (%d)" % aceptadas)
	# cabezales en sentidos opuestos
	var m := ProgramasTuring.rueda_multicinta()
	m.cargar(["RZ", "ZZ", "EZ"])
	m.paso()
	m.paso()
	m.paso()
	comprobar(m.ultima["mov"] == ["S", "S", "L"] or m.ultima["mov"] == ["R", "R", "L"], str(m.ultima["mov"]))
	m.paso()
	comprobar(m.ultima["mov"] == ["R", "R", "L"], "1 y 2 a la derecha, 3 a la izquierda")


## Rejilla: todas las máscaras de 4 gemas para varios láseres.
func test_escalera_multipista_exhaustivo() -> void:
	var m0 := ProgramasTuring.escalera_multipista()
	comprobar(m0.validar() == "", m0.validar())
	for l in ["RZEA", "AAAA", "ZERZ"]:
		var o := ""
		var bien := ""
		for g in l:
			bien += ProgramasTuring.siguiente_gema(g)
			o += ProgramasTuring.siguiente_gema(g, 2)
		for mm in _palabras(4):
			var m := ProgramasTuring.escalera_multipista()
			m.cargar([l, mm, o])
			comprobar((m.ejecutar(500) == "ACEPTA") == (mm == bien), "%s/%s/%s" % [l, mm, o])


func test_terminales_dinamicas() -> void:
	for id in ["alarma", "boveda", "laser"]:
		var vistos := {}
		for semilla in 30:
			var d := Desafio.crear(id, semilla)
			comprobar(d.maquina.usa_gemas, "%s usa gemas" % id)
			d.maquina.ejecutar(5000)
			comprobar(not d.comprobar()["exito"], "%s/%d no empieza resuelto" % [id, semilla])
			for i in d.filas.size():
				d.filas[i]["contenido"] = d.solucion_filas[i]
			d.construir()
			d.maquina.ejecutar(5000)
			comprobar(d.comprobar()["exito"], "%s/%d se resuelve" % [id, semilla])
			vistos[str(d.solucion_filas)] = true
		comprobar(vistos.size() > 5, "%s cambia entre partidas" % id)


func test_cruce_colores() -> void:
	var m := ProgramasTuring.cruce_multipista()
	for haz in ProgramasTuring.GEMAS:
		for mascara in ProgramasTuring.GEMAS:
			for estado in ["0", "1", "_"]:
				m.cargar([haz, mascara, estado])
				var esperado: bool = estado == "0" or (estado == "1" and haz == mascara)
				comprobar((m.ejecutar() == "ACEPTA") == esperado, str([haz, mascara, estado]))


func test_reparto_botin() -> void:
	var m := ProgramasTuring.reparto_multicinta()
	var gemas := ProgramasTuring.GEMAS + ["F"]
	for lote in palabras(gemas, 3):
		for destinos in palabras(["<", ">", "v"], 3):
			var datos := ["", "", ""]
			var esperado := true
			for i in lote.length():
				datos[0] += lote[i] + destinos[i]
				if destinos[i] in ["<", ">"]:
					datos[1 if destinos[i] == "<" else 2] += lote[i]
				esperado = esperado and ProgramasTuring.destino_botin(lote[i]) == destinos[i]
			m.cargar(datos)
			comprobar((m.ejecutar() == "ACEPTA") == esperado, str(datos))
	m.cargar(["R<Zv", "R", ""])
	comprobar(m.ejecutar() == "RECHAZA", "solo se descartan joyas falsas")
	m.cargar(["R<", "RA", ""])
	comprobar(m.ejecutar() == "RECHAZA", "no pueden sobrar joyas en ninguna bolsa")
