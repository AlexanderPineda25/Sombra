## Compilador de niveles: código SOMBRA → datos del nivel.
##
## Fases (las de cualquier compilador):
##   1. análisis léxico     AnalizadorLexico   (AFD generado desde ER)
##   2. análisis sintáctico AnalizadorSintactico (LL(1), produce el AST)
##   3. análisis semántico  aquí: reglas que la gramática no puede expresar
##      (filas del mismo largo, puntos dentro del mapa y caminables, rutas
##      conectadas, cada T y C del mapa declarada, desafíos que existen...)
##   4. generación          aquí: el diccionario que usa Partida
##
## El resultado guarda todo lo intermedio (tokens, AST, errores) para que la
## consola F1 pueda mostrar cada fase.
class_name Compilador
extends RefCounted

const ANCHO := 30
const ALTO := 20
const LEYENDA := "#.PJXHCTDL"
const DESAFIOS := ["cerradura", "laser", "boveda", "alarma"]
const ANGULO := {"derecha": 0.0, "abajo": 90.0, "izquierda": 180.0, "arriba": 270.0}

var fuente := ""
var tokens: Array = []
var ast: Dictionary = {}
var errores: Array = []        ## "línea:col  mensaje" (léxicos, sintácticos y semánticos)
var datos: Dictionary = {}     ## el nivel generado (vacío si hubo errores)


static func compilar(texto: String) -> Compilador:
	var c := Compilador.new()
	c.fuente = texto
	c._compilar()
	return c


func ok() -> bool:
	return errores.is_empty()


func _compilar() -> void:
	var lex := AnalizadorLexico.compartido()
	tokens = lex.analizar(fuente, errores)
	var p := AnalizadorSintactico.new(tokens)
	ast = p.programa()
	errores.append_array(p.errores)
	if not errores.is_empty():
		return
	_semantico()


func _err(linea: int, msg: String) -> void:
	errores.append("%d:1  %s" % [linea, msg])


# ---------------------------------------------------------------------- #
# Análisis semántico y generación
# ---------------------------------------------------------------------- #
func _semantico() -> void:
	var mapas: Array = []
	var guardias: Array = []
	var terminales: Array = []
	var radares: Array = []
	var camaras: Array = []
	for s in ast["hijos"]:
		match s["tipo"]:
			"mapa":
				mapas.append(s)
			"guardia":
				guardias.append(s)
			"terminal":
				terminales.append(s)
			"radar":
				radares.append(s)
			"camara":
				camaras.append(s)
	if mapas.size() != 1:
		_err(ast["linea"], "el nivel debe tener exactamente un mapa (tiene %d)" % mapas.size())
		return
	var filas: Array = []
	for f in mapas[0]["filas"]:
		filas.append(f["texto"])
	if not _validar_mapa(mapas[0]):
		return
	var mapa := Mapa.new(filas)

	# terminales: deben estar sobre una T y cada T debe tener su terminal
	var salida_term: Array = []
	var vistas := {}
	for t in terminales:
		var p: Vector2i = t["punto"]
		if _letra(filas, p) != "T":
			_err(t["linea"], "la terminal %s no está sobre una 'T' del mapa" % _p(p))
		if not t["desafio"] in DESAFIOS:
			_err(t["linea"], "desafío desconocido '%s' (existen: %s)" % [t["desafio"], ", ".join(PackedStringArray(DESAFIOS))])
		vistas[p] = true
		salida_term.append([p, t["desafio"]])
	for p in _buscar(filas, "T"):
		if not vistas.has(p):
			_err(mapas[0]["linea"], "la 'T' en %s no tiene terminal declarada" % _p(p))

	# cámaras: sobre una C (que es pared)
	var salida_cam: Array = []
	vistas.clear()
	for c in camaras:
		var p: Vector2i = c["punto"]
		if _letra(filas, p) != "C":
			_err(c["linea"], "la cámara %s no está sobre una 'C' del mapa" % _p(p))
		vistas[p] = true
		salida_cam.append([p, ANGULO[c["direccion"]]])
	for p in _buscar(filas, "C"):
		if not vistas.has(p):
			_err(mapas[0]["linea"], "la 'C' en %s no tiene cámara declarada" % _p(p))

	var salida_rad: Array = []
	for r in radares:
		if not mapa.caminable(r["punto"]):
			_err(r["linea"], "el radar %s está sobre una pared" % _p(r["punto"]))
		salida_rad.append(r["punto"])

	# guardias: puntos caminables, rutas conectadas, acciones tras un 'ir'
	var salida_g: Array = []
	for g in guardias:
		var puntos: Array = []
		var acciones := {}
		for o in g["ordenes"]:
			if o["tipo"] == "ir":
				var p: Vector2i = o["punto"]
				if not mapa.caminable(p):
					_err(o["linea"], "el guardia no puede ir a %s: es pared" % _p(p))
				elif not puntos.is_empty() and mapa.bfs(puntos[-1], p) == null and puntos[-1] != p:
					_err(o["linea"], "no hay camino de %s a %s" % [_p(puntos[-1]), _p(p)])
				puntos.append(p)
			else:
				if puntos.is_empty():
					_err(o["linea"], "'%s' debe ir después de un 'ir' (¿dónde se detiene?)" % o["tipo"])
					continue
				if o["segundos"] <= 0 or o["segundos"] > 10:
					_err(o["linea"], "la pausa debe durar entre 0 y 10 segundos")
				var acc := {"tipo": o["tipo"], "segundos": o["segundos"]}
				if o["tipo"] == "mirar":
					acc["angulo"] = deg_to_rad(ANGULO[o["direccion"]])
				acciones[puntos.size() - 1] = acc
		if puntos.is_empty():
			_err(g["linea"], "el guardia necesita al menos un 'ir'")
			continue
		if puntos.size() > 1 and mapa.bfs(puntos[-1], puntos[0]) == null:
			_err(g["linea"], "la ruta no se puede cerrar: no hay camino de %s a %s" % [_p(puntos[-1]), _p(puntos[0])])
		salida_g.append({"puntos": puntos, "acciones": acciones})
	if salida_g.is_empty():
		_err(ast["linea"], "el nivel necesita al menos un guardia")

	if not errores.is_empty():
		return
	datos = {
		"titulo": ast["nombre"],
		"mapa": filas,
		"guardias": salida_g,
		"terminales": salida_term,
		"radares": salida_rad,
		"camaras": salida_cam,
	}


func _validar_mapa(m: Dictionary) -> bool:
	var antes := errores.size()
	var filas: Array = m["filas"]
	if filas.size() != ALTO:
		_err(m["linea"], "el mapa debe tener %d filas (tiene %d)" % [ALTO, filas.size()])
	var cuenta := {"P": 0, "X": 0, "J": 0}
	for f in filas:
		var txt: String = f["texto"]
		if txt.length() != ANCHO:
			_err(f["linea"], "la fila mide %d casillas; deben ser %d" % [txt.length(), ANCHO])
		for k in txt.length():
			var c := txt[k]
			if LEYENDA.find(c) < 0:
				_err(f["linea"], "símbolo '%s' desconocido en la columna %d (leyenda: %s)" % [c, k, LEYENDA])
			if cuenta.has(c):
				cuenta[c] += 1
	if cuenta["P"] != 1:
		_err(m["linea"], "debe haber exactamente un punto de partida P (hay %d)" % cuenta["P"])
	if cuenta["X"] != 1:
		_err(m["linea"], "debe haber exactamente una salida X (hay %d)" % cuenta["X"])
	if cuenta["J"] == 0:
		_err(m["linea"], "el museo necesita al menos una joya J")
	if errores.size() == antes:
		# el borde debe ser pared para que nadie salga del mapa
		for k in ANCHO:
			if filas[0]["texto"][k] != "#" or filas[-1]["texto"][k] != "#":
				_err(m["linea"], "el borde superior e inferior deben ser pared")
				break
		for f in filas:
			if f["texto"][0] != "#" or f["texto"][-1] != "#":
				_err(f["linea"], "la fila debe empezar y terminar en pared")
	return errores.size() == antes


static func _letra(filas: Array, p: Vector2i) -> String:
	if p.y < 0 or p.y >= filas.size() or p.x < 0 or p.x >= filas[p.y].length():
		return ""
	return filas[p.y][p.x]


static func _buscar(filas: Array, letra: String) -> Array:
	var r: Array = []
	for y in filas.size():
		for x in filas[y].length():
			if filas[y][x] == letra:
				r.append(Vector2i(x, y))
	return r


static func _p(p: Vector2i) -> String:
	return "(%d, %d)" % [p.x, p.y]


## AST en texto con sangría (consola F1 e informe).
static func arbol(nodo: Dictionary) -> Array:
	var lineas: Array = ["nivel \"%s\"" % nodo.get("nombre", "")]
	var hijos: Array = nodo.get("hijos", [])
	for k in hijos.size():
		var h: Dictionary = hijos[k]
		var ult: bool = k == hijos.size() - 1
		var rama := "└─ " if ult else "├─ "
		var sang := "   " if ult else "│  "
		match h["tipo"]:
			"mapa":
				lineas.append(rama + "mapa  %d × %d" % [h["filas"][0]["texto"].length() if h["filas"].size() > 0 else 0,
						h["filas"].size()])
			"guardia":
				lineas.append(rama + "guardia")
				var ords: Array = h["ordenes"]
				for j in ords.size():
					var o: Dictionary = ords[j]
					var r2 := "└─ " if j == ords.size() - 1 else "├─ "
					match o["tipo"]:
						"ir":
							lineas.append(sang + r2 + "ir %s" % _p(o["punto"]))
						"esperar":
							lineas.append(sang + r2 + "esperar %s s" % o["segundos"])
						"mirar":
							lineas.append(sang + r2 + "mirar %s %s s" % [o["direccion"], o["segundos"]])
			"terminal":
				lineas.append(rama + "terminal %s %s" % [_p(h["punto"]), h["desafio"]])
			"radar":
				lineas.append(rama + "radar %s" % _p(h["punto"]))
			"camara":
				lineas.append(rama + "camara %s %s" % [_p(h["punto"]), h["direccion"]])
	return lineas
