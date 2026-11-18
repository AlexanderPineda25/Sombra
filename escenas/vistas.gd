## Vistas animadas de los personajes. Leen el estado de la lógica (Jugador,
## Guardia, Camara) y lo muestran con sprites, animaciones y luces; no deciden
## nada del juego.
class_name Vistas
extends RefCounted


static func _sprite(tex: Texture2D, filas: int, escala: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = 8
	s.vframes = filas
	s.scale = Vector2(escala, escala)
	return s


static func _luz(tex: Texture2D, escala: float, color: Color, energia: float, sombras: bool) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = escala
	l.color = color
	l.energy = energia
	l.shadow_enabled = sombras
	if sombras:
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 2.0
		l.shadow_color = Color(0, 0, 0, 0.0)
	return l


# ====================================================================== #
class Ladron extends Node2D:
	var juego
	var sprite: Sprite2D
	var t_anim := 0.0

	func _ready() -> void:
		sprite = Vistas._sprite(Arte.ladron, 8, 0.8)
		add_child(sprite)
		# luz tenue que deja ver la silueta del ladrón en la oscuridad
		add_child(Vistas._luz(Arte.circulo, 0.32, Color(0.6, 0.7, 1.0), 0.35, false))

	func _process(dt: float) -> void:
		var p: Partida = juego.partida
		var j := p.jugador
		visible = not p.demo
		position = j.pos
		sprite.rotation = j.angulo
		var anim := "idle"
		var fps := 4.0
		if j.accion in ["lanzar", "recoger"] and j.t_accion > 0.0:
			anim = j.accion
			var dur := 0.35 if anim == "lanzar" else 0.4
			_poner(anim, int((1.0 - j.t_accion / dur) * 4.0))
			sprite.modulate.a = 1.0
			return
		elif j.accion == "interactuar":
			anim = "interactuar"
			fps = 6.0
		elif j.agachado:
			anim = "agachado_caminar" if j.moviendo else "agachado"
			fps = 8.0 if j.moviendo else 3.0
		elif j.corriendo:
			anim = "correr"
			fps = 15.0
		elif j.moviendo:
			anim = "caminar"
			fps = 11.0
		t_anim += dt * fps
		_poner(anim, int(t_anim))
		sprite.modulate.a = 0.55 if j.oculto else 1.0

	func _poner(anim: String, cuadro: int) -> void:
		var fila: Array = Arte.LADRON_FILAS[anim]
		sprite.frame = fila[0] * 8 + clampi(cuadro, 0, 999) % fila[1]


# ====================================================================== #
class GuardiaVista extends Node2D:
	var juego
	var guardia: Guardia
	var sprite: Sprite2D
	var linterna: PointLight2D
	var t_anim := 0.0

	func _ready() -> void:
		sprite = Vistas._sprite(Arte.guardias[guardia.variante], 3, 0.82)
		add_child(Vistas._luz(Arte.circulo, 0.3, Color(0.7, 0.8, 1.0), 0.3, false))
		# linterna: luz en cono con sombras proyectadas por los muros
		linterna = Vistas._luz(Arte.cono, 1.0, Color(1.0, 0.95, 0.75), 1.25, true)
		add_child(linterna)
		add_child(sprite)

	func _process(dt: float) -> void:
		var g := guardia
		position = g.pos
		sprite.rotation = g.angulo
		var dir := Vector2.from_angle(g.angulo)
		linterna.position = dir * 12 + dir.orthogonal() * -6
		linterna.rotation = g.angulo
		linterna.texture_scale = g.alcance() / 256.0
		var color := Color(1.0, 0.95, 0.75)
		var energia := 1.2
		match g.estado():
			Def.PERSECUCION:
				color = Color(1.0, 0.35, 0.3)
				energia = 1.6
			Def.ALERTA, Def.BUSQUEDA:
				color = Color(1.0, 0.72, 0.35)
				energia = 1.35
			Def.SOSPECHA:
				color = Color(1.0, 0.86, 0.45)
				energia = 1.3
		linterna.color = linterna.color.lerp(color, minf(1.0, dt * 6.0))
		linterna.energy = lerpf(linterna.energy, energia, minf(1.0, dt * 6.0))
		var anim := "idle"
		var fps := 4.0
		if g.moviendo:
			anim = "correr" if g.estado() == Def.PERSECUCION else "caminar"
			fps = Config.VEL_GUARDIA[g.estado()] * 4.5
		t_anim += dt * fps
		var fila: Array = Arte.GUARDIA_FILAS[anim]
		sprite.frame = fila[0] * 8 + int(t_anim) % fila[1]


# ====================================================================== #
class CamaraVista extends Node2D:
	var camara: Camara
	var sprite: Sprite2D
	var luz: PointLight2D

	func _ready() -> void:
		luz = Vistas._luz(Arte.cono, Config.ALCANCE_CAMARA * Config.TILE / 256.0,
				Color(0.55, 0.8, 1.0), 0.9, true)
		add_child(luz)
		sprite = Sprite2D.new()
		sprite.texture = Arte.camara
		sprite.scale = Vector2(0.5, 0.5)
		add_child(sprite)

	func _process(_dt: float) -> void:
		position = camara.pos
		sprite.rotation = camara.angulo()
		luz.rotation = camara.angulo()
		match camara.estado():
			Def.APAGADA:
				luz.visible = false
				sprite.modulate = Color(0.5, 0.5, 0.5)
			Def.ALARMA:
				luz.color = Color(1.0, 0.3, 0.3)
				luz.energy = 1.3
			_:
				luz.color = Color(0.55, 0.8, 1.0)
				luz.energy = 0.9
