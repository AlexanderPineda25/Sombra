## Pruebas del lenguaje SOMBRA: ER → AFN → AFD → AFD mínimo, analizador
## léxico, analizador sintáctico, análisis semántico y niveles.
##
##   godot --headless --path . -s res://pruebas/pruebas_lenguaje.gd
extends SceneTree

var total := 0
var fallos := 0
var _actual := ""


func _initialize() -> void:
	var pruebas := [
		"thompson_basico", "thompson_operadores", "clase_negada", "er_mal_formada",
		"afd_equivale_al_afn", "minimo_equivale_y_no_crece", "lexer_tokens", "lexer_prefijo_mas_largo",
		"lexer_posiciones", "lexer_error", "parser_arbol", "parser_errores", "parser_recuperacion",
		"semantico_mapa", "semantico_referencias", "semantico_rutas", "niveles_compilan",
		"guardia_interpreta_pausas",
	]
	for nombre in pruebas:
		_actual = nombre
		var antes := fallos
		call("test_" + nombre)
		total += 1
		print(("ok    " if fallos == antes else "FALLA ") + nombre)
	print("\n%d pruebas del lenguaje, %d fallas" % [total, fallos])
	quit(1 if fallos > 0 else 0)


func comprobar(cond: bool, msg := "") -> void:
	if not cond:
		fallos += 1
		printerr("  [%s] falló: %s" % [_actual, msg])


func _txt(errores: Array) -> String:
	return "\n".join(PackedStringArray(errores))


func _afn(er: String) -> AFN:
	return AFN.desde_reglas([["T", er]])


# --- Thompson -------------------------------------------------------------- #
func test_thompson_basico() -> void:
	var n := _afn("ab|c")
	comprobar(n.acepta("ab") == "T" and n.acepta("c") == "T")
	comprobar(n.acepta("a") == "" and n.acepta("abc") == "" and n.acepta("") == "")


func test_thompson_operadores() -> void:
	var n := _afn("-?[0-9]+(\\.[0-9]+)?")
	for ok in ["0", "42", "-7", "3.14", "-0.5"]:
		comprobar(n.acepta(ok) == "T", ok)
	for mal in ["", "-", "1.", ".5", "1..2", "a"]:
		comprobar(n.acepta(mal) == "", mal)
	var k := _afn("(ab)*")
	comprobar(k.acepta("") == "T" and k.acepta("abab") == "T" and k.acepta("aba") == "")


func test_clase_negada() -> void:
	var n := _afn("\"[^\"\\n]*\"")
	comprobar(n.acepta("\"hola mundo\"") == "T")
	comprobar(n.acepta("\"a\"b\"") == "", "no admite comillas dentro")
	comprobar(n.acepta("\"a\nb\"") == "", "no admite salto de línea")


func test_er_mal_formada() -> void:
	for er in ["(ab", "[a-z", "*a", "a|*"]:
		comprobar(_afn(er).error != "", er)


# --- subconjuntos y minimización ------------------------------------------- #
## Todas las cadenas de largo ≤ 4 sobre un alfabeto representativo: el AFD de
## subconjuntos y el mínimo deben dar el mismo token que la simulación del AFN.
func _cadenas(alfabeto: Array, largo: int) -> Array:
	var r: Array = [""]
	var capa: Array = [""]
	for k in largo:
		var nueva: Array = []
		for s in capa:
			for c in alfabeto:
				nueva.append(s + c)
		r.append_array(nueva)
		capa = nueva
	return r


func _token_afd(lex: AnalizadorLexico, a: AFD, cadena: String) -> String:
	var q := a.inicial
	for c in cadena:
		q = a.transicion(q, lex.simbolo(c))
	var s: String = a.salidas[q]
	return "" if s == "—" else s


func test_afd_equivale_al_afn() -> void:
	var lex := AnalizadorLexico.new()
	comprobar(lex.error == "", lex.error)
	comprobar(lex.afd.error == "", "el AFD de subconjuntos es completo")
	var malas := 0
	for s in _cadenas(["a", "1", ".", "-", "\"", "/", " ", "{", "é"], 4):
		if lex.afn.acepta(s) != _token_afd(lex, lex.afd, s):
			malas += 1
	comprobar(malas == 0, "%d cadenas distintas" % malas)


func test_minimo_equivale_y_no_crece() -> void:
	var lex := AnalizadorLexico.new()
	var r := lex.resumen()
	comprobar(r["min_estados"] <= r["afd_estados"], str(r))
	comprobar(r["clases"] < 20, "clases de equivalencia: %d" % r["clases"])
	var malas := 0
	for s in _cadenas(["a", "1", ".", "-", "\"", "/", " ", "{", "é"], 4):
		if _token_afd(lex, lex.afd, s) != _token_afd(lex, lex.minimo, s):
			malas += 1
	comprobar(malas == 0, "%d cadenas distintas entre AFD y mínimo" % malas)
	print("      AFN %d estados · %d clases · AFD %d estados · mínimo %d" % [r["afn_estados"],
			r["clases"], r["afd_estados"], r["min_estados"]])


# --- analizador léxico ----------------------------------------------------- #
func _tipos(tokens: Array) -> Array:
	var r: Array = []
	for t in tokens:
		r.append(t["tipo"])
	return r


func test_lexer_tokens() -> void:
	var lex := AnalizadorLexico.compartido()
	var tk := lex.analizar("guardia { ir (2, 7) esperar 1.5 } // fin")
	comprobar(_tipos(tk) == ["GUARDIA", "LLAVE_A", "IR", "PAR_A", "NUMERO", "COMA", "NUMERO", "PAR_C",
			"ESPERAR", "NUMERO", "LLAVE_C", "FIN"], str(_tipos(tk)))
	var id := lex.analizar("cerradura bóveda_2")
	comprobar(_tipos(id) == ["IDENT", "IDENT", "FIN"], "identificadores con tilde")


func test_lexer_prefijo_mas_largo() -> void:
	var lex := AnalizadorLexico.compartido()
	var tk := lex.analizar("nivelX -12.5x")
	comprobar(tk[0]["tipo"] == "IDENT" and tk[0]["lexema"] == "nivelX", "nivelX no es la palabra 'nivel'")
	comprobar(tk[1]["lexema"] == "-12.5" and tk[2]["lexema"] == "x")


func test_lexer_posiciones() -> void:
	var tk := AnalizadorLexico.compartido().analizar("nivel\n  \"A\" {\n}")
	comprobar(tk[1]["linea"] == 2 and tk[1]["col"] == 3, str(tk[1]))
	comprobar(tk[3]["linea"] == 3 and tk[3]["col"] == 1, str(tk[3]))


func test_lexer_error() -> void:
	var errores: Array = []
	var tk := AnalizadorLexico.compartido().analizar("ir @ (1, 2)", errores)
	comprobar(errores.size() == 1 and errores[0].begins_with("1:4"), str(errores))
	comprobar(_tipos(tk) == ["IR", "PAR_A", "NUMERO", "COMA", "NUMERO", "PAR_C", "FIN"], "sigue tras el error")


# --- analizador sintáctico --------------------------------------------------- #
func _parsear(texto: String) -> AnalizadorSintactico:
	var p := AnalizadorSintactico.new(AnalizadorLexico.compartido().analizar(texto))
	p.programa()
	return p


func test_parser_arbol() -> void:
	var p := AnalizadorSintactico.new(AnalizadorLexico.compartido().analizar(
			"nivel \"Prueba\" { guardia { ir (1, 1) mirar abajo 2 } radar (3, 4) camara (0, 1) arriba }"))
	var ast := p.programa()
	comprobar(p.errores.is_empty(), str(p.errores))
	comprobar(ast["nombre"] == "Prueba" and ast["hijos"].size() == 3)
	var g: Dictionary = ast["hijos"][0]
	comprobar(g["ordenes"][1]["tipo"] == "mirar" and g["ordenes"][1]["direccion"] == "abajo")
	comprobar(ast["hijos"][1]["punto"] == Vector2i(3, 4))
	comprobar(Compilador.arbol(ast).size() == 6, "\n".join(PackedStringArray(Compilador.arbol(ast))))


func test_parser_errores() -> void:
	var p := _parsear("nivel \"A\" { radar (3 4) }")
	comprobar(p.errores.size() >= 1 and "se esperaba ','" in p.errores[0], str(p.errores))
	p = _parsear("nivel \"A\" { guardia { } }")
	comprobar(not p.errores.is_empty() and "ir, esperar o mirar" in p.errores[0], str(p.errores))
	p = _parsear("nivel \"A\" { puerta (1, 1) }")
	comprobar(not p.errores.is_empty() and "'puerta'" in p.errores[0], str(p.errores))
	p = _parsear("nivel \"A\" { mapa { \"#\" }")
	comprobar(not p.errores.is_empty() and "final del archivo" in p.errores[-1], str(p.errores))


func test_parser_recuperacion() -> void:
	# dos sentencias rotas: el modo pánico permite informar de ambas
	var p := _parsear("nivel \"A\" {\n guardia { ir (1, ) }\n camara (1, 1) adelante\n radar (2, 2)\n}")
	comprobar(p.errores.size() >= 2, str(p.errores))
	comprobar(p.errores[0].begins_with("2:") and p.errores[1].begins_with("3:"), str(p.errores))


# --- análisis semántico ------------------------------------------------------- #
func _nivel(cuerpo: String, mapa_extra := "") -> String:
	var filas: Array = []
	for y in 20:
		if y == 0 or y == 19:
			filas.append("#".repeat(30))
		else:
			filas.append("#" + ".".repeat(28) + "#")
	filas[1] = "#P" + ".".repeat(26) + "J#"
	filas[18] = "#" + ".".repeat(26) + "X.#"
	if mapa_extra != "":
		filas[5] = mapa_extra
	var txt := "nivel \"Prueba\" {\n mapa {\n"
	for f in filas:
		txt += "  \"%s\"\n" % f
	return txt + " }\n" + cuerpo + "\n}"


func test_semantico_mapa() -> void:
	var ok := Compilador.compilar(_nivel("guardia { ir (2, 2) ir (10, 2) }"))
	comprobar(ok.ok(), str(ok.errores))
	var corta := Compilador.compilar(_nivel("guardia { ir (2, 2) }", "#....#"))
	comprobar(not corta.ok() and "deben ser 30" in _txt(corta.errores), str(corta.errores))
	var rara := Compilador.compilar(_nivel("guardia { ir (2, 2) }", "#" + "?".repeat(28) + "#"))
	comprobar(not rara.ok() and "desconocido" in _txt(rara.errores), str(rara.errores))


func test_semantico_referencias() -> void:
	var fila := "#....T.......C..............#"
	fila = fila.substr(0, 29) + "#"
	var c := Compilador.compilar(_nivel("guardia { ir (2, 2) }\n terminal (5, 5) cerradura\n camara (13, 5) abajo",
			fila))
	comprobar(c.ok(), str(c.errores))
	c = Compilador.compilar(_nivel("guardia { ir (2, 2) }\n terminal (6, 5) cerradura\n camara (13, 5) abajo",
			fila))
	comprobar("no está sobre una 'T'" in _txt(c.errores) and "no tiene terminal declarada" in _txt(c.errores),
			str(c.errores))
	c = Compilador.compilar(_nivel("guardia { ir (2, 2) }\n terminal (5, 5) caja_fuerte\n camara (13, 5) abajo",
			fila))
	comprobar("desafío desconocido" in _txt(c.errores), str(c.errores))


func test_semantico_rutas() -> void:
	var c := Compilador.compilar(_nivel("guardia { ir (0, 0) }"))
	comprobar("es pared" in _txt(c.errores), str(c.errores))
	c = Compilador.compilar(_nivel("guardia { esperar 2 ir (2, 2) }"))
	comprobar("después de un 'ir'" in _txt(c.errores), str(c.errores))
	c = Compilador.compilar(_nivel("radar (3, 3)"))
	comprobar("al menos un guardia" in _txt(c.errores), str(c.errores))
	c = Compilador.compilar(_nivel("guardia { ir (2, 2) mirar arriba 1.5 ir (8, 2) esperar 2 }"))
	comprobar(c.ok(), str(c.errores))
	var acc: Dictionary = c.datos["guardias"][0]["acciones"]
	comprobar(acc[0]["tipo"] == "mirar" and is_equal_approx(acc[0]["angulo"], deg_to_rad(270.0)))
	comprobar(acc[1]["tipo"] == "esperar" and acc[1]["segundos"] == 2.0)


# --- niveles -------------------------------------------------------------------- #
func test_niveles_compilan() -> void:
	for i in Niveles.cantidad():
		var c := Niveles.compilado(i)
		comprobar(c.ok(), "nivel %d: %s" % [i + 1, str(c.errores)])
		var d := Niveles.datos(i)
		comprobar(d["mapa"].size() == 20 and d["guardias"].size() >= 2)
		var pausas := 0
		for g in d["guardias"]:
			pausas += g["acciones"].size()
		comprobar(pausas >= 3, "el nivel %d programa pausas en las patrullas" % (i + 1))


func test_guardia_interpreta_pausas() -> void:
	var d := Niveles.datos(0)
	var m := Mapa.new(d["mapa"])
	var prog: Dictionary = d["guardias"][0]
	var g := Guardia.new(0, prog, m)
	comprobar(not g.pausas.is_empty(), "la ruta expandida conserva las pausas")
	var j := Jugador.new(Vector2i(1, 1))
	j.pos = Vector2(-1000, -1000)
	var vio_pausa := false
	var quieto := 0.0
	var antes := g.pos
	for k in 60 * 40:
		g.actualizar(1.0 / 60, j, true)
		if g.en_pausa():
			vio_pausa = true
			if g.pos == antes:
				quieto += 1.0 / 60
		antes = g.pos
	comprobar(vio_pausa, "el guardia nunca se detuvo")
	comprobar(quieto > 1.5, "quieto %.2f s durante las pausas" % quieto)
	comprobar(g.estado() == Def.PATRULLA)
