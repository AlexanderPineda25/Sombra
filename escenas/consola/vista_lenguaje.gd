## Pestaña "Lenguaje" de la consola F1: el nivel actual escrito en SOMBRA y
## cada fase de su compilación.
##
##   izquierda  editor con resaltado hecho por NUESTRO analizador léxico
##   derecha    gramáticas y árboles · tokens · AFD del analizador léxico
##
## "Compilar" analiza el texto del editor; "Aplicar" reinicia el nivel con el
## programa compilado (por ejemplo, con otras patrullas) sin tocar el archivo.
class_name VistaLenguaje
extends VBoxContainer

const T := preload("res://escenas/consola/tema.gd")
const ARBOLES_MUSICA := "res://assets/audio/gramaticas.json"
const COLOR_TOKEN := {
	"COMENTARIO": Color(0.42, 0.52, 0.58), "CADENA": Color(0.98, 0.78, 0.45), "NUMERO": Color(0.62, 0.86, 1.0),
	"IDENT": Color(0.75, 1.0, 0.72), "LLAVE_A": Color(0.6, 0.66, 0.72), "LLAVE_C": Color(0.6, 0.66, 0.72),
	"PAR_A": Color(0.6, 0.66, 0.72), "PAR_C": Color(0.6, 0.66, 0.72), "COMA": Color(0.6, 0.66, 0.72),
	"DIRECCION": Color(0.95, 0.6, 1.0), "RESERVADA": Color(0.35, 0.86, 1.0),
}

var juego
var editor: CodeEdit
var info: RichTextLabel
var estado_lbl: Label
var pestanas: TabContainer
var tokens_txt: RichTextLabel
var arbol_sombra: Tree
var estado_ast: Label
var arbol_er: Tree
var regla_er: Label
var arbol_musica: Tree
var reglas_musica: TextEdit
var salida_musica: Label
var musica: Dictionary
var lexer_txt: RichTextLabel
var nivel_mostrado := -1
var ultimo: Compilador


## Resaltado de sintaxis con el AFD mínimo del analizador léxico.
class Resaltado:
	extends SyntaxHighlighter

	func _get_line_syntax_highlighting(linea: int) -> Dictionary:
		var r := {}
		var texto := get_text_edit().get_line(linea)
		var tokens := AnalizadorLexico.compartido().analizar(texto, [], true)
		for t in tokens:
			if t["tipo"] == "FIN" or t["tipo"] == "ESPACIO":
				continue
			r[t["col"] - 1] = {"color": VistaLenguaje.color_de(t["tipo"])}
		return r


static func color_de(tipo: String) -> Color:
	if COLOR_TOKEN.has(tipo):
		return COLOR_TOKEN[tipo]
	if tipo in AnalizadorSintactico.DIRECCIONES:
		return COLOR_TOKEN["DIRECCION"]
	return COLOR_TOKEN["RESERVADA"]


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	add_child(cab)
	estado_lbl = Label.new()
	estado_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estado_lbl.add_theme_color_override("font_color", T.CIAN)
	cab.add_child(estado_lbl)
	for b in [["Compilar", _compilar], ["Aplicar y reiniciar nivel", _aplicar], ["Restaurar archivo", _restaurar]]:
		var boton := Button.new()
		boton.text = b[0]
		boton.pressed.connect(b[1])
		cab.add_child(boton)

	var h := HSplitContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(h)
	editor = CodeEdit.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_stretch_ratio = 1.25
	editor.gutters_draw_line_numbers = true
	editor.syntax_highlighter = Resaltado.new()
	editor.add_theme_font_size_override("font_size", 13)
	editor.add_theme_color_override("background_color", T.PANEL)
	editor.add_theme_color_override("font_color", T.TEXTO)
	editor.add_theme_color_override("line_number_color", T.APAGADO)
	editor.add_theme_color_override("current_line_color", Color(T.CIAN, 0.06))
	h.add_child(editor)

	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(der)
	info = _texto(der)
	info.custom_minimum_size = Vector2(0, 104)
	info.size_flags_vertical = Control.SIZE_FILL
	pestanas = TabContainer.new()
	pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	der.add_child(pestanas)
	_gramaticas()
	tokens_txt = _texto(pestanas)
	tokens_txt.name = "Tokens"
	lexer_txt = _texto(pestanas)
	lexer_txt.name = "AFD"
	_lexer()


func _texto(padre: Control) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("normal_font_size", 12)
	t.add_theme_font_size_override("bold_font_size", 12)
	t.add_theme_font_size_override("mono_font_size", 12)
	padre.add_child(t)
	return t


func _panel_gramatica(nombre: String) -> VBoxContainer:
	var p := VBoxContainer.new()
	p.name = nombre
	pestanas.add_child(p)
	return p


func _reglas(p: Control, texto: String) -> TextEdit:
	var visor := TextEdit.new()
	visor.editable = false
	visor.text = texto
	visor.custom_minimum_size.y = 94
	visor.add_theme_font_size_override("font_size", 12)
	visor.add_theme_color_override("font_readonly_color", T.TEXTO)
	p.add_child(visor)
	return visor


func _arbol(p: Control) -> Tree:
	var tree := Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 100
	p.add_child(tree)
	return tree


func _etiqueta(p: Control, texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.add_theme_color_override("font_color", T.CIAN)
	p.add_child(etiqueta)
	return etiqueta


func _gramaticas() -> void:
	var sombra := _panel_gramatica("Gramática")
	_etiqueta(sombra, "Reglas de SOMBRA (EBNF)")
	_reglas(sombra, AnalizadorSintactico.EBNF)
	estado_ast = _etiqueta(sombra, "AST del nivel")
	arbol_sombra = _arbol(sombra)
	arbol_sombra.item_selected.connect(_ir_a_nodo)

	var lexico := _panel_gramatica("Léxico")
	_etiqueta(lexico, "Gramática de las expresiones regulares")
	_reglas(lexico, AFN.EBNF)
	var patrones := OptionButton.new()
	for regla in AnalizadorLexico.REGLAS:
		patrones.add_item(regla[0])
	lexico.add_child(patrones)
	regla_er = _etiqueta(lexico, "")
	arbol_er = _arbol(lexico)
	patrones.item_selected.connect(_mostrar_er)
	_mostrar_er(0)

	var panel_musica := _panel_gramatica("Música")
	var ejemplos := OptionButton.new()
	panel_musica.add_child(ejemplos)
	reglas_musica = _reglas(panel_musica, "")
	salida_musica = _etiqueta(panel_musica, "")
	arbol_musica = _arbol(panel_musica)
	if FileAccess.file_exists(ARBOLES_MUSICA):
		var data = JSON.parse_string(FileAccess.get_file_as_string(ARBOLES_MUSICA))
		if data is Dictionary and data.has_all(["ejemplos", "ritmo", "melodia", "reglas_ritmo"]):
			musica = data
	if musica.is_empty():
		ejemplos.disabled = true
		salida_musica.text = "Los árboles musicales no están disponibles."
		return
	for ejemplo in musica["ejemplos"]:
		ejemplos.add_item(ejemplo["nombre"])
	ejemplos.add_item(musica["ritmo"]["nombre"])
	ejemplos.item_selected.connect(_mostrar_musica)
	_mostrar_musica(0)


func _mostrar_er(i: int) -> void:
	var fuente: String = AnalizadorLexico.REGLAS[i][1]
	regla_er.text = "AST de " + fuente
	regla_er.tooltip_text = fuente
	_mostrar_arbol(arbol_er, AnalizadorLexico.compartido().afn.ast_reglas[i])


func _mostrar_musica(i: int) -> void:
	var ritmo: bool = i == musica["ejemplos"].size()
	var ejemplo: Dictionary = musica["ritmo"] if ritmo else musica["ejemplos"][i]
	reglas_musica.text = musica["reglas_ritmo"] if ritmo else musica["melodia"]
	salida_musica.text = ("Árbol de reescritura" if ritmo else "Árbol de derivación") + " · " + ejemplo["salida"]
	salida_musica.tooltip_text = ejemplo["salida"]
	_mostrar_arbol(arbol_musica, ejemplo["arbol"])


func _mostrar_arbol(tree: Tree, nodo: Dictionary) -> void:
	tree.clear()
	if not nodo.is_empty():
		_agregar_rama(tree, nodo)


func _agregar_rama(tree: Tree, nodo: Dictionary, padre: TreeItem = null) -> void:
	var item := tree.create_item(padre)
	item.set_text(0, nodo["texto"])
	item.set_tooltip_text(0, nodo["texto"])
	item.set_metadata(0, nodo.get("linea", 0))
	for hijo in nodo.get("hijos", []):
		_agregar_rama(tree, hijo, item)
	item.collapsed = nodo.get("plegado", false)


func _ir_a_nodo() -> void:
	var item := arbol_sombra.get_selected()
	if item != null and int(item.get_metadata(0)) > 0:
		editor.set_caret_line(clampi(int(item.get_metadata(0)) - 1, 0, editor.get_line_count() - 1))
		editor.center_viewport_to_caret()


static func nodo_sombra(nodo: Dictionary) -> Dictionary:
	var n := {"texto": nodo["tipo"], "linea": nodo["linea"], "hijos": []}
	match nodo["tipo"]:
		"nivel":
			n["texto"] += " «%s»" % nodo["nombre"]
			for hijo in nodo["hijos"]:
				n["hijos"].append(nodo_sombra(hijo))
		"mapa":
			n["texto"] += " · %d filas" % nodo["filas"].size()
			n["plegado"] = true
			for fila in nodo["filas"]:
				n["hijos"].append({"texto": "fila · " + fila["texto"], "linea": fila["linea"]})
		"guardia":
			for orden in nodo["ordenes"]:
				n["hijos"].append(nodo_sombra(orden))
		"ir", "terminal", "radar", "camara":
			var punto: Vector2i = nodo["punto"]
			n["texto"] += " (%d, %d)" % [punto.x, punto.y]
			if nodo.has("desafio"):
				n["texto"] += " " + nodo["desafio"]
			if nodo.has("direccion"):
				n["texto"] += " " + nodo["direccion"]
		"esperar", "mirar":
			if nodo.has("direccion"):
				n["texto"] += " " + nodo["direccion"]
			n["texto"] += " %s s" % nodo["segundos"]
	n["texto"] += "  ·  L%d" % nodo["linea"]
	return n


func _process(_dt: float) -> void:
	if juego and is_visible_in_tree() and juego.nivel != nivel_mostrado:
		nivel_mostrado = juego.nivel
		var c := Niveles.compilado(nivel_mostrado)
		editor.text = c.fuente
		_mostrar(c)


func _compilar() -> void:
	_mostrar(Compilador.compilar(editor.text))


func _aplicar() -> void:
	var c := Compilador.compilar(editor.text)
	_mostrar(c)
	if c.ok() and juego:
		Niveles.sobrescribir(juego.nivel, c)
		juego.reiniciar_nivel()
		estado_lbl.text = "✓ Nivel recompilado y reiniciado con tu programa"


func _restaurar() -> void:
	if juego == null:
		return
	Niveles.restaurar(juego.nivel)
	var c := Niveles.compilado(juego.nivel)
	editor.text = c.fuente
	_mostrar(c)
	juego.reiniciar_nivel()


func _mostrar(c: Compilador) -> void:
	ultimo = c
	var archivo: String = Niveles.ARCHIVOS[clampi(nivel_mostrado, 0, Niveles.cantidad() - 1)]
	estado_lbl.text = "%s  ·  %s" % [archivo, "compila sin errores ✓" if c.ok() else "%d error(es)" % c.errores.size()]
	estado_lbl.add_theme_color_override("font_color", T.VERDE if c.ok() else T.ROJO)
	# resumen de fases
	var n_tok := c.tokens.size() - 1
	var t := "[b][color=#4ddbff]FASES DE LA COMPILACIÓN[/color][/b]\n"
	t += "[color=#8599a8]1 léxico[/color]  %d tokens   " % n_tok
	t += "[color=#8599a8]2 sintáctico[/color]  %s   " % ("árbol ✓" if not c.ast.is_empty() else "—")
	t += "[color=#8599a8]3 semántico[/color]  %s\n" % ("✓" if c.ok() else "✗")
	if c.ok():
		var d := c.datos
		var pausas := 0
		for g in d["guardias"]:
			pausas += g["acciones"].size()
		t += "[color=#59ff94]4 generación[/color]  guardias: %d (%d pausas programadas) · terminales: %d · radares: %d · cámaras: %d\n" % [
				d["guardias"].size(), pausas, d["terminales"].size(), d["radares"].size(), d["camaras"].size()]
	else:
		t += "\n[b][color=#ff5c52]Errores[/color][/b]\n"
		for e in c.errores.slice(0, 8):
			t += "[color=#ff8a80]• %s[/color]\n" % e
	info.text = t
	_marcar_errores(c)
	# árbol
	estado_ast.text = "AST del nivel · selecciona un nodo para ir a su línea" if c.ok() else "AST del nivel · la compilación tiene errores"
	_mostrar_arbol(arbol_sombra, nodo_sombra(c.ast) if not c.ast.is_empty() else {})
	# tokens
	var lineas := PackedStringArray()
	for tok in c.tokens.slice(0, 400):
		var col := color_de(tok["tipo"])
		var lex: String = tok["lexema"]
		if lex.length() > 34:
			lex = lex.substr(0, 31) + "…"
		lineas.append("[color=#5f7685]%3d:%-3d[/color] [color=#%s]%-10s[/color] %s" % [tok["linea"], tok["col"],
				col.to_html(false), tok["tipo"], lex.replace("[", "[lb]")])
	tokens_txt.text = "[code]%s[/code]" % "\n".join(lineas)


func _marcar_errores(c: Compilador) -> void:
	for i in editor.get_line_count():
		editor.set_line_background_color(i, Color(0, 0, 0, 0))
	for e in c.errores:
		var linea := int(e.get_slice(":", 0)) - 1
		if linea >= 0 and linea < editor.get_line_count():
			editor.set_line_background_color(linea, Color(T.ROJO, 0.18))


## Cómo se construyó el analizador léxico (ER → AFN → AFD → mínimo).
func _lexer() -> void:
	var lex := AnalizadorLexico.compartido()
	var r := lex.resumen()
	var t := "[b][color=#4ddbff]ANALIZADOR LÉXICO GENERADO DESDE EXPRESIONES REGULARES[/color][/b]\n\n"
	t += "%d reglas  →  [b]AFN-ε[/b] (Thompson) %d estados, %d transiciones\n" % [r["reglas"], r["afn_estados"], r["afn_transiciones"]]
	t += "        →  %d [b]clases de caracteres[/b]\n" % r["clases"]
	t += "        →  [b]AFD[/b] (subconjuntos) %d estados\n" % r["afd_estados"]
	t += "        →  [b]AFD mínimo[/b] (particiones por salida) [color=#59ff94]%d estados[/color]\n\n" % r["min_estados"]
	t += "Elige una regla en [b]Léxico[/b] para ver su expresión regular y su AST.\n\n"
	t += "[b]Clases de equivalencia (alfabeto Σ del AFD)[/b]\n[code]"
	for cl in lex.clases:
		t += "%-4s %s\n" % [cl[0], cl[2].replace("[", "[lb]")]
	t += "[/code]\n[b]Salida de cada estado del AFD mínimo (máquina de Moore)[/b]\n[code]"
	for q in lex.minimo.estados:
		var nombre: String = q if q.length() < 22 else q.substr(0, 19) + "…"
		t += "%s%-22s → %s\n" % ["→" if q == lex.minimo.inicial else " ", nombre, lex.minimo.salidas[q]]
	t += "[/code]\nPalabras reservadas: el AFD las reconoce como IDENT y luego se buscan en una tabla: "
	t += ", ".join(PackedStringArray(AnalizadorLexico.RESERVADAS))
	lexer_txt.text = t
