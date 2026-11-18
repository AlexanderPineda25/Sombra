## Energía para correr, llevada por una máquina de Turing estándar.
##
## La cinta guarda la batería en unario:  g 1 1 1 1 1 0 0 0 ]
## Cada operación escribe una orden en la casilla 0 (g gastar, c cargar),
## pone el cabezal al principio y ejecuta la máquina hasta que se detiene
## (ver ProgramasTuring.bateria). La máquina RECHAZA si se intenta gastar sin
## energía (agotado) o cargar con la batería llena.
class_name Energia
extends RefCounted

var maquina: MTEstandar
var celdas := Config.ENERGIA_CELDAS
var agotado := false              ## tras vaciarse, hay que recargar un mínimo
var t_gasto := 0.0
var t_recarga := 0.0
var t_reposo := 0.0
var operaciones := 0


func _init(p_celdas := Config.ENERGIA_CELDAS) -> void:
	celdas = p_celdas
	maquina = ProgramasTuring.bateria()
	maquina.cargar("g" + "1".repeat(celdas) + "]")


## Ejecuta una orden ("g" o "c") en la máquina. Devuelve true si ACEPTA.
func ordenar(orden: String) -> bool:
	maquina.cinta.escribir_en(0, orden)
	maquina.cinta.cabezal = 0
	maquina.estado = maquina.inicial
	maquina.pasos = 0
	operaciones += 1
	return maquina.ejecutar(200) == "ACEPTA"


## Celdas llenas: se leen directamente de la cinta.
func nivel() -> int:
	var n := 0
	for i in range(1, celdas + 1):
		if maquina.cinta.leer_en(i) == "1":
			n += 1
	return n


func fraccion() -> float:
	return float(nivel()) / celdas


func puede_correr() -> bool:
	return not agotado and nivel() > 0


## Avanza el tiempo. `corriendo` = el jugador corre y se mueve este fotograma.
func actualizar(dt: float, corriendo: bool) -> void:
	if corriendo:
		t_reposo = 0.0
		t_recarga = 0.0
		t_gasto += dt
		while t_gasto >= Config.ENERGIA_GASTO:
			t_gasto -= Config.ENERGIA_GASTO
			if not ordenar("g") or nivel() == 0:
				agotado = true
				break
	else:
		t_gasto = 0.0
		t_reposo += dt
		if t_reposo >= Config.ENERGIA_ESPERA:
			t_recarga += dt
			while t_recarga >= Config.ENERGIA_RECARGA:
				t_recarga -= Config.ENERGIA_RECARGA
				ordenar("c")
	if agotado and nivel() >= Config.ENERGIA_MINIMA:
		agotado = false
