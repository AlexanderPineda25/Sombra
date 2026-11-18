# SOMBRA: Robo en el Museo (Godot 4.7)

Juego de infiltración 2D con vista cenital, hecho en **Godot 4.7 (GDScript)**. Eres un ladrón profesional: entra al museo, esquiva las linternas de los guardias, escóndete en los arbustos antes de que el **radar** barra la sala, **hackea las terminales de seguridad resolviendo máquinas de Turing** y escapa con todas las joyas.

Todo el comportamiento del museo está hecho con modelos de la teoría de la computación, y la **consola de seguridad (F1)** los muestra funcionando en vivo:

| Parte del juego | Modelo | Archivo |
|---|---|---|
| Cerebro de cada guardia | AFD de 6 estados (PAT, SOS, ALE, PER, BUS, REG) y 7 eventos (v, r, s, p, l, t, a) | `automatas/definiciones.gd` |
| Camino de regreso del guardia | Autómata de pila (IDA / VUELTA, acepta por pila vacía) | `automatas/pila_regreso.gd` |
| Cámaras de seguridad | AFD de 4 estados (GIRO_IZQ, GIRO_DER, ALARMA, APAGADA) | `automatas/definiciones.gd` |
| Ciclo del radar | AFD de 4 estados (REPOSO → AVISO → BARRIDO → ANALISIS) | `automatas/definiciones.gd` |
| Pantallas del juego | AFD de 7 estados (MENU, JUGANDO, PAUSA, TERMINAL, DERROTA, VICTORIA, FIN) | `escenas/main.gd` |
| Diseño del guardia | Borrador de 7 estados minimizado a 6 | `automatas/afd.gd` → `minimizar()` |
| Cerradura de la vitrina | **MT estándar** (verificador en zigzag de un acertijo de gemas, distinto en cada partida) | `turing/programas.gd` |
| Energía para correr | **MT estándar** (batería en unario: g gasta, c recarga, rechaza si está agotada) | `turing/programas.gd`, `juego/energia.gd` |
| Central de alarmas | **MT estándar** (reconocedor de xⁿyⁿ con dos gemas al azar) | `turing/programas.gd` |
| Puerta de la bóveda | **MT multicinta** (gira las gemas de A según B y compara con K escrita al revés: cabezales en sentidos opuestos) | `turing/programas.gd` |
| Rejilla láser | **MT multipista** (1 cinta, 3 pistas: cada columna láser→máscara→objetivo forma una escalera en la rueda) | `turing/programas.gd` |
| Radar: correlación de sensores | **MT multicinta** (presencia × transpondedor → intrusos) | `turing/programas.gd` |
| Radar: análisis de señales | **MT multipista** (busca la columna intruso=1, visión=1, oculto=0) | `turing/programas.gd` |
| Niveles y patrullas | **Lenguaje SOMBRA**: analizador léxico generado (ER → AFN de Thompson → AFD por subconjuntos → AFD mínimo), analizador sintáctico LL(1) y análisis semántico | `lenguaje/`, `niveles/*.sombra` |
| Música | **Gramática libre de contexto estocástica** (melodías) y **sistema L** (ritmo de Fibonacci) | `herramientas/gramatica_musical.py` |

## La cadena completa

Robar una joya → los guardias reaccionan a la vista, a los ruidos y a los pasos cercanos con su AFD → el radar avisa (AFD: AVISO) y barre 12 sectores (atraviesa paredes; solo los arbustos ocultan) → la **multicinta** cruza los sensores y la **multipista** analiza el resultado → si acepta, **alerta global por radio**: cada guardia recibe el símbolo `a` y TODOS van al punto exacto donde el radar midió al ladrón; si ya no está, pasan a BUSQUEDA y registran varios lugares alrededor → la **música** sube de capa según el peor estado de los AFD → todo queda en el **registro** de la consola F1.

## El lenguaje SOMBRA

Los tres niveles están escritos en un lenguaje propio y se **compilan al iniciar el juego**:

```
nivel "La bóveda" {
	mapa { "##############################"  ... }
	guardia {
		ir (8, 1)
		ir (17, 1)
		ir (17, 5)
		mirar izquierda 1      // se detiene 1 s mirando a la izquierda
		ir (8, 5)
	}
	terminal (9, 7) boveda
	radar (14, 9)
	camara (16, 11) arriba
}
```

| Fase | Cómo se hace | Archivo |
|---|---|---|
| Análisis léxico | 10 reglas escritas como **expresiones regulares** → AFN-ε de **Thompson** (53 estados) → 14 **clases de caracteres** → AFD por **construcción de subconjuntos** (20 estados) → **AFD mínimo** con la misma clase `AFD` de los guardias (17 estados; es una máquina de Moore cuya salida es el token). Prefijo más largo y palabras reservadas por tabla. | `lenguaje/afn.gd`, `lenguaje/analizador_lexico.gd` |
| Análisis sintáctico | Gramática LL(1) en EBNF, **descenso recursivo**, árbol de sintaxis abstracta y recuperación de errores en **modo pánico** (reporta varios errores con línea:columna). | `lenguaje/analizador_sintactico.gd` |
| Análisis semántico | Filas de 30×20, borde de pared, una P y una X, cada `T`/`C` del mapa declarada, desafíos que existen, puntos caminables y rutas conectadas (BFS). | `lenguaje/compilador.gd` |
| Generación e interpretación | Datos del nivel; los guardias **interpretan** su programa de patrulla (`esperar`, `mirar`) mientras su AFD está en PATRULLA. | `juego/niveles.gd`, `juego/guardia.gd` |

En **F1 › Lenguaje SOMBRA** se ve el código del nivel con resaltado hecho por el propio analizador léxico, los tokens, el árbol sintáctico, los errores y cómo se construyó el AFD del léxico. Se puede **editar el programa, compilarlo y reiniciar el nivel con él** (por ejemplo, cambiar las patrullas) sin tocar el archivo.

## Cómo jugar

1. Instala [Godot 4.7](https://godotengine.org/download) (versión estándar).
2. Abre Godot → **Importar** → elige `project.godot`.
3. Pulsa **F5**.

En el menú, **1 · 2 · 3** elige el nivel. Desde la terminal: `godot --path . -- --nivel 3` empieza directo en el nivel 3.

Si exportas el juego, añade `*.sombra` a los filtros de archivos no recurso del preajuste de exportación (los niveles se leen como texto).

## Controles

| Tecla | Acción |
|---|---|
| Flechas / WASD | moverse |
| Shift | correr (más rápido, hace ruido y gasta la barra de ENERGÍA, que se recarga sola al dejar de correr) |
| C o Ctrl | agacharse (más lento, cuesta más verte y los guardias no oyen tus pasos) |
| Clic izquierdo o **Q** | lanzar una moneda para distraer (3 por nivel); Q la lanza hacia el puntero |
| Arbustos | entra en su área para ocultarte (círculo verde = oculto) |
| **E** | usar la terminal de seguridad que tengas al lado |
| Esc | pausa / salir de la terminal |
| **F1** | abrir / cerrar la consola de seguridad (ventana independiente) |

**En una terminal:** clic sobre las casillas subrayadas (o el teclado) para escribir la entrada · **Espacio** ejecutar/pausar · **N** un paso · **R** reiniciar · **Esc** salir.

## Ocultamiento

- Hay que estar **dentro del área** del arbusto, no solo cerca.
- **No se puede ocultar con un guardia mirándote**: hay que romper el contacto visual 1 s.
- Moverse de pie entre las hojas hace un crujido que los guardias cercanos oyen.
- Un guardia que te persigue muy de cerca, o que registra el arbusto durante una búsqueda, te encuentra igual.
- El radar atraviesa las paredes: dentro de su alcance solo te salva estar oculto en un arbusto.

## Guardias que oyen

- Caminar de pie a menos de 3 casillas de un guardia: te oye, **se voltea al instante** y pasa a SOSPECHA.
- Corriendo te oye a 5,5 casillas y pasa a ALERTA (va hacia ti).
- Agachado u oculto no te oye.

## Terminales con gemas

Todas las terminales usan gemas (Rubí, Zafiro, Esmeralda, Ámbar; teclas 1-4 o clic) y cambian en cada partida:

- **Central de alarmas** (estándar): un código de 6 gemas de la forma xⁿyⁿ con dos gemas sorteadas.
- **Bóveda** (multicinta): cada gema tuya B indica cuántos pasos girar la gema del sensor A en la rueda; el resultado debe ser la clave K, escrita al revés (el cabezal 3 retrocede mientras 1 y 2 avanzan).
- **Rejilla láser** (multipista): cada columna (láser, máscara, objetivo) debe ser una escalera en la rueda R→Z→E→A→R.

### Cerradura de la vitrina (acertijo de gemas)

En cada partida la vitrina muestra 4 gemas al azar (Rubí, Zafiro, Esmeralda, Ámbar) y un acertijo: **espejo** (las mismas gemas al revés), **rueda** (cada gema por la siguiente: R→Z→E→A→R), **rivales** (Rubí↔Esmeralda, Zafiro↔Ámbar) o **doble cerrojo** (rueda y al revés). Escribes la clave tras el `#` (clic o teclas 1-4) y una MT estándar la verifica en zigzag: marca una gema de la vitrina, la recuerda en su estado (`lleva_R`, `lleva_Z`...), cruza el `#` y comprueba la gema de la clave.

## Consola de seguridad (F1)

Ventana nativa (`display/window/subwindows/embed_subwindows=false`), única, redimensionable, que se abre al lado del juego. **No pausa el juego**: corre en paralelo y muestra en vivo cada cambio de estado; el foco se queda en el juego para seguir jugando mientras se observa.

- **Guardias · AFD**: tarjeta por guardia, diagrama con todas las transiciones, estado actual, inicial, final, última transición resaltada y la tabla δ completa.
- **Máquinas de Turing**: la última máquina estándar, multicinta y multipista usada (terminal o radar) y la batería de energía, con cintas/pistas, cabezales, estado y últimas operaciones.
- **Radar**: AFD del ciclo, cuenta atrás y las señales P/A/V/O/I por sector.
- **Registro**: detecciones, monedas, cambios de estado, alarmas, alertas, ejecuciones de MT; con filtros.
- **Tutoriales**: los tres tutoriales interactivos.
- **Ajustes**: intervalo, aviso, barrido y alcance del radar, dificultad, volumen e intensidad de la música y volumen de efectos. Se guardan en `user://ajustes.cfg`.

## Tutoriales interactivos

Aparecen la primera vez que usas una terminal de cada tipo (estándar en el nivel 1, multipista en el 2, multicinta en el 3) y se pueden repetir desde F1 › Tutoriales. Cada uno tiene simulaciones paso a paso de máquinas reales, ejercicios con retroalimentación y, en el de multipista, la comparación con la multicinta. Las pistas cortas (radar, arbustos) aparecen una vez durante el juego.

## Música y sonido

Todo el audio es original y se sintetiza con `herramientas/generar_audio.py` (piano eléctrico FM, vibráfono, campanas, bajo pulsado de Karplus-Strong, batería y reverberación de Schroeder estéreo).

- **Un tema por nivel**: vestíbulo en re dórico a 92 BPM con piano eléctrico y escobillas; galería en sol menor armónico a 100 BPM con vibráfono; bóveda en mi frigio a 108 BPM con campanas.
- **Composición con lenguajes formales**: cada frase de la melodía es una derivación de una **gramática libre de contexto estocástica** (FRASE → PREGUNTA RESPUESTA, MOTIVO, ECO, CADENCIA…), y los ritmos de búsqueda salen de un **sistema L** (A → AB, B → A: la palabra de Fibonacci). Las derivaciones quedan en `docs/musica_derivaciones.txt`.
- **Música adaptativa**: cuatro capas sincronizadas (`AudioStreamSynchronized`) se mezclan con fundidos según el peor estado de los AFD: exploración, sospecha, búsqueda, persecución, alarma; remates de victoria y derrota.
- **Ambiente y pasos**: tono de sala del museo, pasos del ladrón (no suenan agachado) y botas del guardia más cercano, más fuertes cuanto más cerca está.
- Las operaciones de las máquinas (leer, escribir, mover, aceptar, rechazar) suenan con un tono que sube con la posición del cabezal; el gestor limita repeticiones, polifonía y arranques simultáneos.

## Efectos visuales

- **Postproceso** (`escenas/postproceso.gdshader`) alimentado por los autómatas: aberración cromática en PERSECUCIÓN, contraste en SOSPECHA/BÚSQUEDA, tinte rojo pulsante en alarma, velo verde y visión de túnel al esconderte, viñeta y grano.
- **Tarjeta de nivel** con el objetivo y los modelos que vigilan esa sala.
- Linternas que cambian de color con el estado del AFD, polvo flotando en la luz, polvo de los pasos al correr, sacudida al activar alarmas o al ser atrapado, reloj sobre el guardia durante una pausa programada.

## Niveles

| Nivel | Guardias | Seguridad | Terminal |
|---|---|---|---|
| 1 · El vestíbulo | 2 | puerta electrónica + radar | MT estándar (acertijo de gemas) |
| 2 · La galería | 3 | cámara + rejilla láser + radar | MT multipista |
| 3 · La bóveda | 5 | 2 cámaras + bóveda + radar | MT multicinta (rueda) + MT estándar xⁿyⁿ |

## Estructura

```
sombra_godot/
├── project.godot
├── lenguaje/                  compilador de niveles: afn.gd, analizador_lexico.gd,
│                              analizador_sintactico.gd, compilador.gd
├── niveles/                   nivel1.sombra, nivel2.sombra, nivel3.sombra
├── turing/                    máquinas de Turing (lógica pura)
│   ├── cinta.gd  maquina_turing.gd  mt_estandar.gd  mt_multicinta.gd  mt_multipista.gd
│   └── programas.gd           las 11 máquinas del museo
├── automatas/                 AFD genérico, autómata de pila y tablas δ
├── juego/                     lógica del juego (sin dibujo)
│   ├── mapa.gd  niveles.gd  partida.gd  config.gd  ajustes.gd
│   ├── jugador.gd  guardia.gd  camara.gd  moneda.gd  desafio.gd
│   ├── seguridad.gd           gestor de seguridad: alertas globales, amenaza, registro (señal `evento`)
│   ├── ocultamiento.gd        reglas de los arbustos
│   └── radar.gd               radar periódico (AFD + MT multicinta + MT multipista)
├── escenas/                   todo lo visual y sonoro
│   ├── main.tscn / main.gd    escena principal, luces, AFD de pantallas, tutoriales
│   ├── audio.gd               gestor de audio (música adaptativa y efectos)
│   ├── vistas.gd  capa_mundo.gd  follaje.gd  capa_accion.gd  interfaz.gd  terminal_ui.gd
│   ├── postproceso.gdshader   viñeta, grano, alarma, aberración
│   └── consola/               consola F1: consola.gd (Window), vista_afd.gd, vista_mt.gd,
│                              vista_radar.gd, vista_lenguaje.gd, tutorial.gd, tema.gd
├── assets/                    sprites, texturas, luces y audio generados
├── herramientas/              generar_arte.py, generar_audio.py, sintesis.py, gramatica_musical.py
├── pruebas/                   pruebas automáticas, experimento y capturas
└── docs/capturas/
```

## Pruebas

```bash
godot --headless --path . -s res://pruebas/pruebas_turing.gd   # 23 pruebas de las máquinas de Turing
godot --headless --path . -s res://pruebas/pruebas.gd          # 45 pruebas del juego, autómatas, radar, audio y tutoriales
godot --headless --path . -s res://pruebas/pruebas_lenguaje.gd # 18 pruebas del lenguaje SOMBRA
godot --headless --path . -s res://pruebas/experimento.gd      # experimento de los regresos
```

Las del lenguaje comprueban que el AFD de subconjuntos y el AFD mínimo dan el mismo token que la simulación directa del AFN en las 7 381 cadenas de hasta 4 caracteres de un alfabeto representativo, el prefijo más largo, las posiciones línea:columna, los mensajes y la recuperación de errores sintácticos, cada regla semántica y que los guardias interpretan sus pausas. Las pruebas de Turing son exhaustivas (incluidos el correlador y el analizador del radar con todas las entradas de hasta 4 y 3 bits). Las del juego comprueban, entre otras cosas: que el radar detecta al ladrón aunque esté detrás de un muro y no al oculto, fuera de alcance o a un guardia; que la alerta manda a todos al punto medido y luego registran el área; que los guardias oyen pasos y se voltean; que la batería limita el correr; que el verificador de gemas acepta exactamente una clave entre todas las de 3 a 5 gemas para cada acertijo; que la música sigue a los AFD con fundidos graduales; que 200 operaciones simultáneas no saturan el audio; y que cada ejercicio de los tutoriales coincide con lo que hace la máquina real.

## Regenerar el arte y el audio

```bash
pip install pillow numpy scipy      # y ffmpeg con libvorbis para la música
python3 herramientas/generar_arte.py
python3 herramientas/generar_audio.py
```

## Autor

Luis Agudelo — Lenguajes de Programación, Universidad de los Llanos.
