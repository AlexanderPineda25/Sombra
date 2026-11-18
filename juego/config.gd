## Constantes generales del juego.
class_name Config
extends RefCounted

const TILE := 32
const COLS := 30
const FILAS := 20
const ANCHO := COLS * TILE               # 960
const ALTO_MAPA := FILAS * TILE          # 640
const ALTO_HUD := 64
const ALTO := ALTO_MAPA + ALTO_HUD       # 704
const TITULO := "SOMBRA: Robo en el Museo"

# Velocidades en casillas por segundo
const VEL_JUGADOR := 3.4
const VEL_JUGADOR_CORRER := 5.4
const VEL_JUGADOR_AGACHADO := 2.1
const VEL_GUARDIA := {
	"PATRULLA": 2.0,
	"SOSPECHA": 1.3,
	"ALERTA": 2.7,
	"PERSECUCION": 4.3,
	"BUSQUEDA": 2.6,
	"REGRESO": 2.5,
}

# Visión
const ALCANCE_GUARDIA := 6.5             # casillas
const ALCANCE_PERSECUCION := 8.5
const MEDIO_ANGULO_GUARDIA := 36.0       # grados
const ALCANCE_CAMARA := 6.0
const MEDIO_ANGULO_CAMARA := 26.0
const BARRIDO_CAMARA := 50.0             # grados a cada lado
const VEL_GIRO_CAMARA := 32.0            # grados por segundo

# Tiempos (segundos)
const TIEMPO_ALERTA := 9.0
const TIEMPO_BUSQUEDA := 3.5
const TIEMPO_SOSPECHA := 7.0
const TIEMPO_SIN_VER := 0.8
const TIEMPO_ALARMA := 4.0
const TIEMPO_CAMARA_DETECTA := 0.45

# Ruido (radio en casillas)
const RUIDO_CORRER := 4.0
const INTERVALO_RUIDO_CORRER := 0.35
const RUIDO_MONEDA := 7.5
const RUIDO_ALARMA := 14.0
const RUIDO_TERMINAL := 8.0
const ALCANCE_MONEDA := 7.0
const MONEDAS_POR_NIVEL := 3

const RADIO_ATRAPAR := 0.6               # casillas

# Arbustos
const RADIO_ARBUSTO := 0.42              # casillas: área real de ocultamiento
const TIEMPO_PARA_OCULTARSE := 1.0       # segundos sin contacto visual para ocultarse
const RUIDO_CRUJIDO := 2.5               # moverse de pie entre las hojas

# Alerta global por radio
const RADIO_PASOS := 3.0                 # casillas: un guardia oye pasos a esta distancia (de pie)
const RADIO_PASOS_CORRER := 5.5          # casillas: corriendo se le oye desde más lejos
const PUNTOS_BUSQUEDA_AMPLIA := 3        # lugares extra que registra tras una alerta del radar
const RADIO_BUSQUEDA_AMPLIA := 5.0       # casillas alrededor del punto detectado
# Energía para correr: una máquina de Turing estándar lleva la cuenta en unario
const ENERGIA_CELDAS := 16
const ENERGIA_GASTO := 0.18              # s por celda gastada corriendo
const ENERGIA_RECARGA := 0.28            # s por celda recargada
const ENERGIA_ESPERA := 0.6              # s sin correr antes de empezar a recargar
const ENERGIA_MINIMA := 4                # celdas necesarias para volver a correr tras agotarse
const RADIO_RESPUESTA_ALERTA := 14.0     # casillas: más lejos, el guardia busca en su sector
const DURACION_ALERTA_GLOBAL := 12.0     # segundos con la amenaza elevada

# Colores
const PISO_A := Color(32 / 255.0, 38 / 255.0, 56 / 255.0)
const PISO_B := Color(36 / 255.0, 43 / 255.0, 62 / 255.0)
const PARED := Color(74 / 255.0, 82 / 255.0, 108 / 255.0)
const PARED_BORDE := Color(110 / 255.0, 120 / 255.0, 150 / 255.0)
const PARED_SOMBRA := Color(48 / 255.0, 54 / 255.0, 74 / 255.0)
const PLANTA := Color(46 / 255.0, 140 / 255.0, 92 / 255.0)
const PLANTA_OSCURA := Color(28 / 255.0, 96 / 255.0, 62 / 255.0)
const JOYA := [Color(90 / 255.0, 230 / 255.0, 255 / 255.0), Color(255 / 255.0, 110 / 255.0, 200 / 255.0), Color(255 / 255.0, 214 / 255.0, 90 / 255.0)]
const SALIDA_CERRADA := Color(120 / 255.0, 60 / 255.0, 60 / 255.0)
const SALIDA_ABIERTA := Color(70 / 255.0, 210 / 255.0, 120 / 255.0)
const JUGADOR := Color(235 / 255.0, 235 / 255.0, 245 / 255.0)
const JUGADOR_CAPA := Color(60 / 255.0, 64 / 255.0, 92 / 255.0)
const GUARDIA := Color(70 / 255.0, 110 / 255.0, 220 / 255.0)
const GUARDIA_GORRA := Color(30 / 255.0, 44 / 255.0, 96 / 255.0)
const CONO_NORMAL := Color(255 / 255.0, 236 / 255.0, 150 / 255.0)
const CONO_ALERTA := Color(255 / 255.0, 170 / 255.0, 70 / 255.0)
const CONO_PERSECUCION := Color(255 / 255.0, 70 / 255.0, 70 / 255.0)
const CONO_CAMARA := Color(150 / 255.0, 220 / 255.0, 255 / 255.0)
const TEXTO := Color(232 / 255.0, 230 / 255.0, 220 / 255.0)
const TEXTO_SUAVE := Color(160 / 255.0, 162 / 255.0, 180 / 255.0)
const ACENTO := Color(240 / 255.0, 163 / 255.0, 94 / 255.0)
const HUD_FONDO := Color(18 / 255.0, 20 / 255.0, 32 / 255.0)
