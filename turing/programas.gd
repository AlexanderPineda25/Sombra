## Programas concretos de máquinas de Turing que usan los sistemas de
## seguridad del museo. Cada función construye la máquina con su tabla δ.
class_name ProgramasTuring
extends RefCounted


# ====================================================================== #
# 1. Estándar (transductor): incrementador binario
# ====================================================================== #
# Recorre el número hasta el final y suma 1 desde la derecha, propagando el
# acarreo:  0111 -> 1000,  1011 -> 1100,  111 -> 1000.
static func incrementador() -> MTEstandar:
	var d := {
		"q0|0": ["q1", "0", "R"],      # hay al menos un dígito
		"q0|1": ["q1", "1", "R"],
		"q0|_": ["qr", "_", "S"],      # palabra vacía: no hay número
		"q1|0": ["q1", "0", "R"],      # ir al final del número
		"q1|1": ["q1", "1", "R"],
		"q1|_": ["q2", "_", "L"],      # llegó al final: volver un paso
		"q2|1": ["q2", "0", "L"],      # 1 + acarreo = 0, el acarreo sigue
		"q2|0": ["qa", "1", "S"],      # 0 + acarreo = 1, termina
		"q2|_": ["qa", "1", "S"],      # desbordamiento: nuevo dígito
	}
	var m := MTEstandar.new("Incrementador binario", ["q0", "q1", "q2", "qa", "qr"],
			["0", "1"], ["0", "1", "_"], d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Inicio: comprueba que haya un número en la cinta.",
		"q1": "Avanza a la derecha hasta el final del número.",
		"q2": "Suma 1 desde la derecha: cada 1 pasa a 0 y el acarreo sigue.",
		"qa": "ACEPTA: el número ya quedó incrementado en la cinta.",
		"qr": "RECHAZA: la cinta estaba vacía.",
	}
	return m


# ====================================================================== #
# 2. Estándar (reconocedor): L = { aⁿbⁿ | n ≥ 1 }
# ====================================================================== #
# Marca la primera a con X, busca la primera b y la marca con Y, vuelve y
# repite. Acepta si al final solo quedan Y. Este lenguaje no es regular: un
# AFD no puede reconocerlo, una máquina de Turing sí.
static func anbn() -> MTEstandar:
	var d := {
		"q0|a": ["q1", "X", "R"],
		"q0|Y": ["q3", "Y", "R"],
		"q1|a": ["q1", "a", "R"],
		"q1|Y": ["q1", "Y", "R"],
		"q1|b": ["q2", "Y", "L"],
		"q2|a": ["q2", "a", "L"],
		"q2|Y": ["q2", "Y", "L"],
		"q2|X": ["q0", "X", "R"],
		"q3|Y": ["q3", "Y", "R"],
		"q3|_": ["qa", "_", "S"],
	}
	var m := MTEstandar.new("Reconocedor aⁿbⁿ", ["q0", "q1", "q2", "q3", "qa", "qr"],
			["a", "b"], ["a", "b", "X", "Y", "_"], d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Toma la siguiente 'a' y la marca con X.",
		"q1": "Busca hacia la derecha la primera 'b' sin marcar.",
		"q2": "Marcó la 'b' con Y; regresa hasta la última X.",
		"q3": "No quedan 'a': comprueba que solo haya Y hasta el final.",
		"qa": "ACEPTA: hay tantas 'a' como 'b' y en orden.",
		"qr": "RECHAZA: no hay transición para lo que leyó.",
	}
	return m


# ====================================================================== #
# 3. Multicinta (3 cintas): verificador de suma binaria  A + B = K
# ====================================================================== #
# Cinta 1: A (n bits)   Cinta 2: B (n bits)   Cinta 3: K (n+1 bits)
# Fase 1 (q0): las tres cabezas avanzan juntas hasta el final de A.
# Ajuste: las cabezas 1 y 2 retroceden y la 3 se queda quieta (L, L, S),
#         porque K tiene un dígito más.
# Fase 2 (c0/c1 = acarreo): suma bit a bit de derecha a izquierda; si el bit
#         coincide con K lo marca con * en la cinta 3, si no, rechaza.
static func suma_multicinta() -> MTMulticinta:
	var d := {}
	var bits := ["0", "1"]
	for a in bits:
		for b in bits:
			for k in bits:
				d["q0|%s,%s,%s" % [a, b, k]] = ["q0", [a, b, k], ["R", "R", "R"]]
	for k in bits:
		d["q0|_,_,%s" % k] = ["c0", ["_", "_", k], ["L", "L", "S"]]
	for c in [0, 1]:
		for a in bits:
			for b in bits:
				for k in bits:
					var total: int = int(a) + int(b) + c
					var s := str(total % 2)
					if k == s:
						d["c%d|%s,%s,%s" % [c, a, b, k]] = ["c%d" % (total / 2), [a, b, "*"], ["L", "L", "L"]]
					else:
						d["c%d|%s,%s,%s" % [c, a, b, k]] = ["qr", [a, b, "X"], ["S", "S", "S"]]
		for k in bits:
			if k == str(c):
				d["c%d|_,_,%s" % [c, k]] = ["qa", ["_", "_", "*"], ["S", "S", "S"]]
			else:
				d["c%d|_,_,%s" % [c, k]] = ["qr", ["_", "_", "X"], ["S", "S", "S"]]
	var m := MTMulticinta.new("Verificador de suma A + B = K", 3,
			["q0", "c0", "c1", "qa", "qr"], ["0", "1"], ["0", "1", "*", "X", "_"],
			d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Las tres cabezas avanzan juntas hasta el final de los números.",
		"c0": "Suma sin acarreo: lee A, B y K a la vez y compara el bit.",
		"c1": "Suma con acarreo 1: lee A, B y K a la vez y compara el bit.",
		"qa": "ACEPTA: A + B es exactamente la clave K.",
		"qr": "RECHAZA: un bit de la suma no coincide con la clave.",
	}
	return m


# ====================================================================== #
# 4. Multipista (3 pistas): verificador de la rejilla láser
# ====================================================================== #
# Pista 1: patrón del láser L   Pista 2: máscara M   Pista 3: objetivo T
# En cada casilla el único cabezal lee la tupla (l, m, t): si l XOR m = t la
# marca con * en la pista 3 y avanza; si no, escribe X y rechaza. Al terminar
# vuelve al principio y acepta.
static func xor_multipista() -> MTMultipista:
	var d := {}
	var bits := ["0", "1"]
	for l in bits:
		for m in bits:
			for t in bits:
				var x := "1" if l != m else "0"
				if x == t:
					d["q0|%s,%s,%s" % [l, m, t]] = ["q0", [l, m, "*"], "R"]
				else:
					d["q0|%s,%s,%s" % [l, m, t]] = ["qr", [l, m, "X"], "S"]
	d["q0|_,_,_"] = ["q1", ["_", "_", "_"], "L"]
	for l in bits:
		for m in bits:
			d["q1|%s,%s,*" % [l, m]] = ["q1", [l, m, "*"], "L"]
	d["q1|_,_,_"] = ["qa", ["_", "_", "_"], "R"]
	var maq := MTMultipista.new("Verificador de rejilla láser", 3, ["q0", "q1", "qa", "qr"],
			["0", "1"], ["0", "1", "*", "X", "_"], d, "q0", "qa", "qr")
	maq.explicacion_estados = {
		"q0": "Lee la tupla (láser, máscara, objetivo) y comprueba láser XOR máscara = objetivo.",
		"q1": "Todas las casillas cumplen: el cabezal regresa al inicio.",
		"qa": "ACEPTA: la máscara cancela el láser.",
		"qr": "RECHAZA: en esta casilla la máscara no cancela el láser.",
	}
	return maq


# ====================================================================== #
# 5. Multicinta (3 cintas): correlador de sensores del radar
# ====================================================================== #
# Cinta 1: P  presencia detectada por el radar en cada sector (1 = hay alguien)
# Cinta 2: A  transpondedor autorizado en ese sector (1 = es un guardia)
# Cinta 3:    salida: 1 si hay presencia SIN autorización (intruso), si no 0
# Las tres cabezas leen a la vez el mismo sector y avanzan juntas.
static func correlador_sensores() -> MTMulticinta:
	var d := {}
	for p in ["0", "1"]:
		for a in ["0", "1"]:
			var intruso := "1" if p == "1" and a == "0" else "0"
			d["q0|%s,%s,_" % [p, a]] = ["q0", [p, a, intruso], ["R", "R", "R"]]
	d["q0|_,_,_"] = ["qa", ["_", "_", "_"], ["S", "S", "S"]]
	var m := MTMulticinta.new("Correlador de sensores del radar", 3, ["q0", "qa", "qr"],
			["0", "1"], ["0", "1", "_"], d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Cruza sector a sector la presencia del radar con los transpondedores de los guardias.",
		"qa": "Terminó: la cinta 3 marca los sectores con un intruso sin autorizar.",
		"qr": "Error de lectura de los sensores.",
	}
	return m


# ====================================================================== #
# 6. Multipista (4 pistas): analizador de señales del radar
# ====================================================================== #
# Pista 1: I intruso (salida del correlador)   Pista 2: V hubo eco (el radar atraviesa paredes)
# Pista 3: O el objetivo está oculto (arbusto)  Pista 4: resultado del análisis
# Busca una columna (1, 1, 0): intruso, con eco y no oculto. Si la encuentra
# la marca con ! y ACEPTA (intrusión confirmada); si llega al final sin
# encontrarla, RECHAZA (no hay intrusión).
static func analizador_radar() -> MTMultipista:
	var d := {}
	for i in ["0", "1"]:
		for v in ["0", "1"]:
			for o in ["0", "1"]:
				if i == "1" and v == "1" and o == "0":
					d["q0|%s,%s,%s,_" % [i, v, o]] = ["qa", [i, v, o, "!"], "S"]
				else:
					d["q0|%s,%s,%s,_" % [i, v, o]] = ["q0", [i, v, o, "."], "R"]
	d["q0|_,_,_,_"] = ["qr", ["_", "_", "_", "_"], "S"]
	var m := MTMultipista.new("Analizador de señales del radar", 4, ["q0", "qa", "qr"],
			["0", "1"], ["0", "1", "!", ".", "_"], d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Recorre los sectores buscando la columna (intruso, con eco, no oculto).",
		"qa": "ACEPTA: intrusión confirmada en el sector marcado con !",
		"qr": "RECHAZA: ningún sector cumple el patrón; no hay intrusión.",
	}
	return m


# ====================================================================== #
# 7. Estándar: batería de energía para correr (contador en unario)
# ====================================================================== #
# Cinta:  C 1 1 1 1 0 0 0 ]      C = orden (g gastar, c cargar)
#         cada 1 es una celda de energía, cada 0 una celda vacía, ] el final.
# gastar: va a la derecha hasta el primer 0 (o ]), retrocede y borra el
#         último 1. Si no queda ninguno llega a la orden y RECHAZA (agotado).
# cargar: va a la derecha hasta el primer 0 y lo cambia por 1. Si llega a ]
#         la batería ya estaba llena y RECHAZA.
static func bateria() -> MTEstandar:
	var d := {
		"q0|g": ["qg", "g", "R"],
		"q0|c": ["qc", "c", "R"],
		"qg|1": ["qg", "1", "R"],      # busca el final de la energía
		"qg|0": ["qb", "0", "L"],
		"qg|]": ["qb", "]", "L"],
		"qb|1": ["qa", "0", "S"],      # borra la última celda: gastada
		"qb|g": ["qr", "g", "S"],      # no había energía: agotado
		"qc|1": ["qc", "1", "R"],
		"qc|0": ["qa", "1", "S"],      # llena la primera celda vacía
		"qc|]": ["qr", "]", "S"],      # ya estaba llena
	}
	var m := MTEstandar.new("Batería de energía", ["q0", "qg", "qb", "qc", "qa", "qr"],
			["g", "c", "0", "1", "]"], ["g", "c", "0", "1", "]", "_"], d, "q0", "qa", "qr")
	m.explicacion_estados = {
		"q0": "Lee la orden: g = gastar energía, c = cargar.",
		"qg": "Gastar: avanza sobre las celdas llenas (1) hasta el final de la energía.",
		"qb": "Retrocede una casilla para borrar la última celda llena.",
		"qc": "Cargar: avanza hasta la primera celda vacía (0).",
		"qa": "ACEPTA: la operación se hizo.",
		"qr": "RECHAZA: batería agotada (al gastar) o llena (al cargar).",
	}
	return m


# ====================================================================== #
# 8. Estándar: verificador de la clave de gemas de la vitrina
# ====================================================================== #
# Cinta:  P P P P # K K K K    P = secuencia que muestra la vitrina,
#                              K = la clave que escribe el jugador.
# La clave correcta es f(P) (cada gema transformada por la regla f) y, si
# `invertir`, leída de derecha a izquierda. La máquina va en zigzag:
#   q0     marca la primera gema sin marcar de P (la pasa a minúscula) y
#          "recuerda" cuál era entrando en el estado lleva_X;
#   lleva_X cruza hasta K y compara con la primera gema sin marcar de K
#          (o la última, si invierte); si coincide con f(X) la marca;
#   vuelve regresa hasta la última gema marcada de P y repite;
#   fin    cuando P está toda marcada, K también debe estarlo: ACEPTA.
# Cualquier diferencia deja a la máquina sin transición: RECHAZA.
const GEMAS := ["R", "Z", "E", "A"]


static func verificador_clave(regla: Dictionary, invertir: bool) -> MTEstandar:
	var d := {}
	var minus := {}
	for g in GEMAS:
		minus[g] = g.to_lower()
	var estados := ["q0", "vuelve", "vuelve_p", "fin", "qa", "qr"]
	for g in GEMAS:
		var lleva: String = "lleva_" + g
		var busca: String = "busca_" + g
		estados.append_array([lleva, busca])
		d["q0|" + g] = [lleva, minus[g], "R"]
		# cruza el resto de P hasta el separador
		for h in GEMAS:
			d[lleva + "|" + h] = [lleva, h, "R"]
		var esperado: String = regla[g]
		if not invertir:
			d[lleva + "|#"] = [busca, "#", "R"]
			for h in GEMAS:
				d[busca + "|" + minus[h]] = [busca, minus[h], "R"]      # salta las ya marcadas
			d[busca + "|" + esperado] = ["vuelve", minus[esperado], "L"]
		else:
			var ir: String = "ir_" + g
			estados.append(ir)
			d[lleva + "|#"] = [ir, "#", "R"]
			for h in GEMAS:                                            # hasta el final de K
				d[ir + "|" + h] = [ir, h, "R"]
				d[ir + "|" + minus[h]] = [ir, minus[h], "R"]
			d[ir + "|_"] = [busca, "_", "L"]
			for h in GEMAS:
				d[busca + "|" + minus[h]] = [busca, minus[h], "L"]      # salta las marcadas del final
			d[busca + "|" + esperado] = ["vuelve", minus[esperado], "L"]
	# volver: cruza K hasta el separador y luego P hasta la última marcada
	for h in GEMAS:
		d["vuelve|" + h] = ["vuelve", h, "L"]
		d["vuelve|" + minus[h]] = ["vuelve", minus[h], "L"]
		d["vuelve_p|" + h] = ["vuelve_p", h, "L"]
		d["vuelve_p|" + minus[h]] = ["q0", minus[h], "R"]
	d["vuelve|#"] = ["vuelve_p", "#", "L"]
	# P completa: K debe estar toda marcada
	d["q0|#"] = ["fin", "#", "R"]
	for h in GEMAS:
		d["fin|" + minus[h]] = ["fin", minus[h], "R"]
	d["fin|_"] = ["qa", "_", "S"]
	var alfabeto := GEMAS.duplicate()
	var cinta := GEMAS.duplicate()
	for g in GEMAS:
		cinta.append(minus[g])
	alfabeto.append("#")
	cinta.append_array(["#", "_"])
	var m := MTEstandar.new("Verificador de la clave de gemas", estados, alfabeto, cinta, d, "q0", "qa", "qr")
	m.usa_gemas = true
	m.explicacion_estados = {
		"q0": "Toma la siguiente gema de la vitrina y la marca (minúscula).",
		"vuelve": "Coincidió: regresa por la clave hacia el separador #.",
		"vuelve_p": "Regresa por la vitrina hasta la última gema marcada.",
		"fin": "La vitrina está completa: revisa que no sobren gemas en la clave.",
		"qa": "ACEPTA: la clave corresponde a la vitrina.",
		"qr": "RECHAZA: una gema de la clave no corresponde.",
	}
	for g in GEMAS:
		m.explicacion_estados["lleva_" + g] = "Recuerda la gema %s y cruza hasta la clave." % g
		m.explicacion_estados["busca_" + g] = "Busca en la clave la gema que corresponde a %s: debe ser %s." % [g, regla[g]]
		m.explicacion_estados["ir_" + g] = "Va al final de la clave (se compara al revés)."
	return m



static func _cinta_gemas(extra: Array = []) -> Array:
	var c := GEMAS.duplicate()
	for g in GEMAS:
		c.append(g.to_lower())
	c.append_array(extra)
	c.append("_")
	return c


static func siguiente_gema(g: String, pasos := 1) -> String:
	return GEMAS[(GEMAS.find(g) + pasos) % 4]


# ====================================================================== #
# 9. Estándar: central de alarmas con gemas  L = { xⁿ yⁿ | n ≥ 1 }
# ====================================================================== #
# El mismo reconocedor de aⁿbⁿ, pero con dos gemas elegidas al azar en cada
# partida. Marca cada x (minúscula) y su pareja y; cualquier otra gema deja a
# la máquina sin transición y RECHAZA.
static func equilibrio_gemas(x: String, y: String) -> MTEstandar:
	var mx := x.to_lower()
	var my := y.to_lower()
	var d := {
		"q0|" + x: ["q1", mx, "R"],
		"q0|" + my: ["q3", my, "R"],
		"q1|" + x: ["q1", x, "R"],
		"q1|" + my: ["q1", my, "R"],
		"q1|" + y: ["q2", my, "L"],
		"q2|" + x: ["q2", x, "L"],
		"q2|" + my: ["q2", my, "L"],
		"q2|" + mx: ["q0", mx, "R"],
		"q3|" + my: ["q3", my, "R"],
		"q3|_": ["qa", "_", "S"],
	}
	var m := MTEstandar.new("Central de alarmas: %sⁿ%sⁿ" % [x, y], ["q0", "q1", "q2", "q3", "qa", "qr"],
			GEMAS.duplicate(), _cinta_gemas(), d, "q0", "qa", "qr")
	m.usa_gemas = true
	m.explicacion_estados = {
		"q0": "Toma la siguiente gema %s y la marca." % x,
		"q1": "Busca hacia la derecha la primera gema %s sin marcar." % y,
		"q2": "Marcó su pareja %s; regresa hasta la última %s marcada." % [y, x],
		"q3": "No quedan %s: comprueba que solo haya %s marcadas hasta el final." % [x, y],
		"qa": "ACEPTA: tantas %s como %s y en orden." % [x, y],
		"qr": "RECHAZA: sobra o falta una gema, o hay una gema que no corresponde.",
	}
	return m


# ====================================================================== #
# 10. Multicinta: bóveda de la rueda (cabezales en sentidos opuestos)
# ====================================================================== #
# Cinta 1: A (sensor)  Cinta 2: B (jugador)  Cinta 3: K (clave, AL REVÉS)
# Cada gema vale sus pasos en la rueda: R 0, Z 1, E 2, A 3.
# Debe cumplirse K[n-1-i] = A[i] girada B[i] pasos.
#   q0: solo el cabezal 3 avanza hasta el final de K (S, S, R).
#   q1: los cabezales 1 y 2 avanzan a la DERECHA y el 3 a la IZQUIERDA
#       (R, R, L): cada uno a su ritmo y en su sentido. Si la gema de K
#       coincide, la marca; si no, RECHAZA.
static func rueda_multicinta() -> MTMulticinta:
	var d := {}
	for a in GEMAS:
		for b in GEMAS:
			for k in GEMAS:
				d["q0|%s,%s,%s" % [a, b, k]] = ["q0", [a, b, k], ["S", "S", "R"]]
				if k == siguiente_gema(a, GEMAS.find(b)):
					d["q1|%s,%s,%s" % [a, b, k]] = ["q1", [a, b, k.to_lower()], ["R", "R", "L"]]
			d["q0|%s,%s,_" % [a, b]] = ["q1", [a, b, "_"], ["S", "S", "L"]]
	d["q1|_,_,_"] = ["qa", ["_", "_", "_"], ["S", "S", "S"]]
	var m := MTMulticinta.new("Bóveda de la rueda (A girada B = K al revés)", 3, ["q0", "q1", "qa", "qr"],
			GEMAS.duplicate(), _cinta_gemas(), d, "q0", "qa", "qr")
	m.usa_gemas = true
	m.explicacion_estados = {
		"q0": "Solo el cabezal 3 avanza hasta el final de la clave (S, S, R).",
		"q1": "Cabezales 1 y 2 a la derecha, cabezal 3 a la izquierda (R, R, L): gira A según B y compara con K.",
		"qa": "ACEPTA: las tres cintas terminaron a la vez y todo coincide.",
		"qr": "RECHAZA: una gema de K no es la de A girada B pasos (o sobran gemas).",
	}
	return m


# ====================================================================== #
# 11. Multipista: rejilla láser en escalera
# ====================================================================== #
# Pista 1: láser L   Pista 2: máscara M (jugador)   Pista 3: objetivo O
# Cada columna debe ser una escalera en la rueda: M = siguiente(L) y
# O = siguiente(M). El único cabezal lee la columna entera, marca la
# máscara (minúscula) y avanza; al final regresa al inicio y ACEPTA.
static func escalera_multipista() -> MTMultipista:
	var d := {}
	for l in GEMAS:
		var m_ok := siguiente_gema(l)
		var o_ok := siguiente_gema(m_ok)
		d["q0|%s,%s,%s" % [l, m_ok, o_ok]] = ["q0", [l, m_ok.to_lower(), o_ok], "R"]
		d["q1|%s,%s,%s" % [l, m_ok.to_lower(), o_ok]] = ["q1", [l, m_ok.to_lower(), o_ok], "L"]
	d["q0|_,_,_"] = ["q1", ["_", "_", "_"], "L"]
	d["q1|_,_,_"] = ["qa", ["_", "_", "_"], "R"]
	var maq := MTMultipista.new("Rejilla láser en escalera", 3, ["q0", "q1", "qa", "qr"],
			GEMAS.duplicate(), _cinta_gemas(), d, "q0", "qa", "qr")
	maq.usa_gemas = true
	maq.explicacion_estados = {
		"q0": "Lee la columna (láser, máscara, objetivo): ¿forman una escalera en la rueda?",
		"q1": "Todas las columnas cumplen: el cabezal regresa al inicio.",
		"qa": "ACEPTA: la máscara desvía todos los láseres.",
		"qr": "RECHAZA: en esta columna la máscara no forma la escalera.",
	}
	return maq
