"""Composición con lenguajes formales.

1. MELODÍAS: una gramática libre de contexto ESTOCÁSTICA genera las frases.
   G = (N, Σ, P, FRASE), donde los terminales son pasos en grados de la
   escala con su duración en corcheas:

       FRASE      → PREGUNTA RESPUESTA
       PREGUNTA   → MOTIVO ECO
       RESPUESTA  → MOTIVO CADENCIA | ECO CADENCIA
       MOTIVO     → PASO PASO SALTO | LARGA SILENCIO PASO PASO | ARPEGIO PASO
       ECO        → (repite el último MOTIVO un grado más arriba)
       PASO       → +1/1 | -1/1                 (grado ±1, una corchea)
       SALTO      → +3/2 | -2/2 | +4/2          (salto, una negra)
       LARGA      → 0/4                          (misma nota, una blanca)
       SILENCIO   → r/2
       ARPEGIO    → +2/1 +2/1 +3/2
       CADENCIA   → T/4                          (vuelve a la tónica)

   ECO es la única regla con memoria (repite un motivo transpuesto): así
   la melodía tiene "pregunta y respuesta" como una frase escrita a mano.
   Cada derivación se guarda en docs/musica_derivaciones.txt.

2. RITMOS: un sistema L (Lindenmayer), A → AB, B → A, genera la palabra de
   Fibonacci ABAABABAABAAB...; A = golpe, B = silencio. Es un ritmo que
   nunca se repite exactamente, ideal para la percusión de la búsqueda.
"""
import random

REGLAS = {
    "FRASE": [(["PREGUNTA", "RESPUESTA"], 1.0)],
    "PREGUNTA": [(["MOTIVO", "ECO"], 1.0)],
    "RESPUESTA": [(["MOTIVO", "CADENCIA"], 0.6), (["ECO", "CADENCIA"], 0.4)],
    "MOTIVO": [(["PASO", "PASO", "SALTO"], 0.4), (["LARGA", "SILENCIO", "PASO", "PASO"], 0.3),
               (["ARPEGIO", "PASO"], 0.3)],
    "PASO": [(["+1/1"], 0.5), (["-1/1"], 0.5)],
    "SALTO": [(["+3/2"], 0.35), (["-2/2"], 0.4), (["+4/2"], 0.25)],
    "LARGA": [(["0/4"], 1.0)],
    "SILENCIO": [(["r/2"], 1.0)],
    "ARPEGIO": [(["+2/1", "+2/1", "+3/2"], 1.0)],
    "CADENCIA": [(["T/4"], 1.0)],
}


def derivar(semilla, inicial="FRASE"):
    """Derivación por la izquierda. Devuelve (terminales, formas sentenciales).

    Como siempre se expande el no terminal de más a la izquierda, cuando se
    llega a un ECO el MOTIVO anterior ya está completo: ECO copia esos
    terminales un grado más arriba."""
    r = random.Random(semilla)
    forma = [inicial]
    pasos = [" ".join(forma)]
    inicio_motivo = 0
    while True:
        i = next((k for k, s in enumerate(forma) if s in REGLAS or s == "ECO"), -1)
        if i < 0:
            break
        s = forma[i]
        if s == "ECO":
            copia = forma[inicio_motivo:i]
            cuerpo = ([_transponer(copia[0], 1)] + copia[1:]) if copia else ["0/2"]
        else:
            if s == "MOTIVO":
                inicio_motivo = i
            opciones = REGLAS[s]
            x = r.random() * sum(p for _, p in opciones)
            for cuerpo, p in opciones:
                x -= p
                if x <= 0:
                    break
            cuerpo = list(cuerpo)
        forma = forma[:i] + cuerpo + forma[i + 1:]
        pasos.append(" ".join(forma))
    return forma, pasos


def _transponer(t, d):
    """Sube un terminal d grados: el primer paso de un motivo arrastra al resto."""
    paso, dur = t.split("/")
    if paso in ("r", "T"):
        return t
    return f"{int(paso) + d:+d}/{dur}"


def melodia(semilla, compases=4):
    """Convierte una derivación en [(grado_absoluto | None, inicio_corcheas, dur_corcheas)].
    Ajusta la frase a `compases` compases de 4/4 (8 corcheas por compás)."""
    total = compases * 8
    terminales, pasos = derivar(semilla)
    notas = []
    grado = 4                    # empieza en la quinta
    t = 0
    for term in terminales:
        paso, dur = term.split("/")
        dur = int(dur)
        if t >= total:
            break
        if paso == "r":
            notas.append((None, t, dur))
        else:
            if paso == "T":
                grado = 0 if grado < 4 else 7
            else:
                nuevo = grado + int(paso)
                if nuevo < -1 or nuevo > 9:          # se sale del registro: rebota
                    nuevo = grado - int(paso)
                grado = nuevo
            notas.append((grado, t, dur))
        t += dur
    # estira la última nota hasta completar la frase
    if t < total and notas:
        g, i, d = notas[-1]
        notas[-1] = (g, i, d + total - t)
    elif t > total and notas:
        g, i, d = notas[-1]
        notas[-1] = (g, i, max(1, total - i))
    return notas, terminales, pasos


def sistema_l(axioma="A", reglas=None, iteraciones=6):
    """Reescritura paralela de un sistema L (todas las letras a la vez)."""
    reglas = reglas or {"A": "AB", "B": "A"}
    palabra = axioma
    historia = [palabra]
    for _ in range(iteraciones):
        palabra = "".join(reglas.get(c, c) for c in palabra)
        historia.append(palabra)
    return palabra, historia


def ritmo_fibonacci(golpes=16, desfase=0):
    """Patrón de `golpes` semicorcheas tomado de la palabra de Fibonacci."""
    palabra, _ = sistema_l(iteraciones=8)
    trozo = palabra[desfase:desfase + golpes]
    return [c == "A" for c in trozo]
