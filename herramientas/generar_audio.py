"""Genera la música adaptativa y los efectos de sonido de SOMBRA.

Todo el audio es original y sintetizado aquí (no usa muestras externas):
    python3 herramientas/generar_audio.py

MÚSICA: un tema por nivel, cada uno con cuatro capas de 8 compases que suenan
sincronizadas y se mezclan según el nivel de amenaza (escenas/audio.gd):
    base        pad + bajo pulsado + melodía (exploración)
    tension     cuerdas en trémolo + arpegio + platillos   (sospecha)
    busqueda    ostinato + toms con ritmo de un sistema L  (búsqueda)
    persecucion batería completa + stabs + melodía aguda   (persecución / alarma)

    nivel 1 · Vestíbulo   re menor dórico, 92 BPM, piano eléctrico FM, escobillas
    nivel 2 · Galería     sol menor armónico, 100 BPM, vibráfono
    nivel 3 · Bóveda      mi frigio, 108 BPM, campanas y pulso grave

Las melodías salen de una gramática libre de contexto estocástica y los ritmos
de la búsqueda de un sistema L (ver gramatica_musical.py). Las derivaciones
quedan en docs/musica_derivaciones.txt.

Remates: victoria y derrota. Ambiente del museo en bucle.
Efectos: operaciones de las máquinas de Turing, radar, moneda, joya, pasos...
"""
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np

import gramatica_musical as gm
from sintesis import (SR, aro, bajo_pulsado, bandpass, bombo, caja, campana, cuerdas, decay, env,
                      escobilla, highpass, hz, lowpass, pad, piano_electrico, platillo, poner, reverb,
                      ruido, saw, sine, square, t_, tom, vibrafono)

RAIZ = Path(__file__).resolve().parent.parent
OUT = RAIZ / "assets" / "audio"

# ------------------------------------------------------------------- temas
TEMAS = {
    "n1": {
        "tonica": 50, "escala": [0, 2, 3, 5, 7, 9, 10],
        "acordes": [[50, 53, 57, 60, 64], [46, 50, 53, 57, 62], [43, 46, 50, 53, 57], [45, 49, 52, 55, 58]],
        "instrumento": "piano", "octava_mel": 12,
    },
    "n2": {
        "tonica": 43, "escala": [0, 2, 3, 5, 7, 8, 11],
        "acordes": [[43, 46, 50, 57], [39, 43, 46, 50], [48, 51, 55, 58], [50, 54, 57, 60]],
        "instrumento": "vibrafono", "octava_mel": 36,
    },
    "n3": {
        "tonica": 40, "escala": [0, 1, 3, 5, 7, 8, 10],
        "acordes": [[40, 47, 52, 55], [41, 48, 53, 57], [40, 47, 52, 55], [47, 51, 54, 57]],
        "instrumento": "campana", "octava_mel": 36,
    },
}
COMPASES = 8


class Tema:
    def __init__(self, clave):
        self.clave = clave
        self.d = TEMAS[clave]
        _, bpm, self.semilla = gm.TEMAS_GRAMATICA[clave]
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bar = self.beat * 4
        self.largo = self.bar * COMPASES
        self.n = int(round(self.largo * SR))
        self.melodia = self._componer()

    def buf(self):
        return np.zeros((self.n, 2))

    def acorde(self, compas):
        return self.d["acordes"][(compas // 2) % 4]

    def nota_de_grado(self, g):
        e = self.d["escala"]
        return self.d["tonica"] + self.d["octava_mel"] + e[g % 7] + 12 * (g // 7)

    def _componer(self):
        """Cuatro frases de 2 compases, cada una derivada de la gramática. En los
        tiempos fuertes la nota se ajusta a la nota del acorde más cercana."""
        notas = []
        for f in range(4):
            sem = self.semilla * 10 + f
            frase, _, _ = gm.melodia(sem, 2)
            for g, ini, dur in frase:
                t0 = f * 16 + ini
                if g is None:
                    continue
                m = self.nota_de_grado(g)
                if ini % 4 == 0:
                    m = self._ajustar(m, self.acorde(t0 // 8))
                notas.append((m, t0, dur))
        return notas

    @staticmethod
    def _ajustar(m, acorde):
        clases = {n % 12 for n in acorde}
        for d in (0, -1, 1, -2, 2):
            if (m + d) % 12 in clases:
                return m + d
        return m

    def instrumento(self, f, dur):
        i = self.d["instrumento"]
        if i == "piano":
            return piano_electrico(f, dur)
        if i == "vibrafono":
            return vibrafono(f, dur)
        return campana(f, dur)


# ------------------------------------------------------------------- capas
def capa_base(T):
    b = T.buf()
    for c in range(0, COMPASES, 2):
        p = pad([n + 12 for n in T.acorde(c)[:4]], T.bar * 2 + 0.8, 950)
        poner(b, p, c * T.bar, 0.13)
    for c in range(COMPASES):
        ac = T.acorde(c)
        raiz = ac[0] - 12
        sig = T.acorde(c + 1)[0] - 12
        linea = [raiz, raiz + 7, raiz + 12 if c % 2 else raiz + 3, sig + (1 if sig < raiz else -1)]
        for k, n in enumerate(linea):                     # bajo caminante
            x = bajo_pulsado(hz(n), T.beat * 1.1, 0.35)
            poner(b, x, c * T.bar + k * T.beat, 0.42 if k == 0 else 0.3, -0.1)
        for k in (1, 3):                                   # escobillas en 2 y 4
            poner(b, escobilla(0.2), c * T.bar + k * T.beat, 0.05, 0.3)
    corchea = T.beat / 2
    for m, t0, dur in T.melodia:
        x = T.instrumento(hz(m), max(0.4, dur * corchea * 1.6))
        poner(b, x, t0 * corchea, 0.16, 0.25)
    return reverb(b, 0.3, 1.1)


def capa_tension(T):
    b = T.buf()
    corchea = T.beat / 2
    patron = gm.ritmo_fibonacci(16, 3)
    for c in range(COMPASES):
        ac = T.acorde(c)
        if c % 2 == 0:
            poner(b, cuerdas(hz(ac[2] + 24), T.bar * 2), c * T.bar, 0.08, -0.4)
        arp = [ac[0] + 24, ac[1] + 24, ac[2] + 24, ac[1] + 24]
        for k in range(8):
            x = vibrafono(hz(arp[k % 4]), 0.5) if T.d["instrumento"] != "campana" else campana(hz(arp[k % 4]), 0.5)
            poner(b, x * decay(len(x), 0.12), c * T.bar + k * corchea, 0.09 if k % 2 == 0 else 0.05, 0.4)
        for s in range(16):
            if patron[s]:
                poner(b, platillo(0.05), c * T.bar + s * T.beat / 4, 0.07 if s % 4 else 0.04, 0.2)
        # latido grave en 1 y "y" del 1
        for k, g in ((0, 0.3), (0.5, 0.18)):
            poner(b, sine(52, 0.35) * decay(int(0.35 * SR), 0.1), c * T.bar + k * T.beat, g)
    return reverb(b, 0.25, 0.9)


def capa_busqueda(T):
    b = T.buf()
    semi = T.beat / 4
    acentos = gm.ritmo_fibonacci(16, 0)
    rim = gm.ritmo_fibonacci(16, 5)
    for c in range(COMPASES):
        raiz = T.acorde(c)[0] - 12
        for s in range(16):
            t0 = c * T.bar + s * semi
            if s % 2 == 0:
                n = raiz + (12 if acentos[s] and s % 4 else 0)
                x = saw(hz(n), semi * 1.8, 10)
                x = lowpass(x, 600 + 600 * acentos[s]) * env(len(x), 0.004, 0.06, 0.5, 0.04)
                poner(b, x, t0, 0.3 if acentos[s] else 0.2, -0.15)
            if rim[s] and s % 2 == 1:
                poner(b, aro(), t0, 0.12, 0.35)
        for k, f0 in ((0, 110), (2.5, 90), (3.5, 130)):
            poner(b, tom(f0), c * T.bar + k * T.beat, 0.32, -0.3 + 0.2 * k)
        m = bandpass(ruido(0.12), 1500, 4000) * decay(int(0.12 * SR), 0.03)
        poner(b, m, c * T.bar + 3 * T.beat, 0.1, 0.5)
    return reverb(b, 0.18, 0.8)


def capa_persecucion(T):
    b = T.buf()
    for c in range(COMPASES):
        ac = T.acorde(c)
        for k in range(4):
            t0 = c * T.bar + k * T.beat
            poner(b, bombo(), t0, 0.55)
            if k in (1, 3):
                poner(b, caja(), t0, 0.38, 0.1)
            for s in range(4):
                poner(b, platillo(0.04, 0.01), t0 + s * T.beat / 4, 0.08 if s % 2 else 0.05, 0.35)
            stab = np.zeros(int(0.2 * SR))
            for n in ac[:3]:
                stab += saw(hz(n + 12), 0.2, 10)
            stab = lowpass(stab, 2400) * env(len(stab), 0.003, 0.05, 0.3, 0.1)
            poner(b, stab, t0 + T.beat / 2, 0.1, -0.35)
    corchea = T.beat / 2
    for m, t0, dur in T.melodia:                       # melodía de la gramática, aguda y urgente
        x = lowpass(square(hz(m + 12), dur * corchea * 0.95, 5), 3200)
        x *= env(len(x), 0.004, 0.05, 0.6, 0.05)
        poner(b, x, t0 * corchea, 0.07, 0.15)
    t = np.arange(T.n) / SR
    sirena = np.sin(2 * np.pi * np.cumsum(700 + 160 * np.sin(2 * np.pi * t / T.bar)) / SR)
    poner(b, lowpass(sirena, 1500) * 0.02, 0, 1.0, 0.0)
    return reverb(b, 0.15, 0.8)


# ----------------------------------------------------------------- remates
def remate_victoria():
    b = np.zeros((int(3.6 * SR), 2))
    for k, n in enumerate([62, 66, 69, 74, 78]):
        poner(b, vibrafono(hz(n), 2.0), k * 0.12, 0.3, -0.4 + 0.2 * k, False)
    poner(b, pad([62, 66, 69, 74], 2.6, 1800, 0.1), 0.6, 0.12, 0, False)
    return reverb(b, 0.35, 1.2, False)


def remate_derrota():
    b = np.zeros((int(3.8 * SR), 2))
    for k, n in enumerate([62, 61, 58, 50]):
        x = saw(hz(n), 0.9, 8) * env(int(0.9 * SR), 0.01, 0.2, 0.6, 0.4)
        poner(b, lowpass(x, 1200), k * 0.45, 0.3, 0.2 - 0.15 * k, False)
    poner(b, sine(hz(38), 2.0) * decay(int(2.0 * SR), 0.7), 1.35, 0.5, 0, False)
    return reverb(b, 0.3, 1.3, False)


def remate_alarma():
    dur = 1.6
    t = t_(dur)
    f = np.where((t * 4).astype(int) % 2 == 0, 880, 660)
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5
    return lowpass(x, 2500) * env(len(t), 0.01, 0.1, 0.8, 0.3)


def ambiente():
    """Tono de sala del museo: zumbido eléctrico, aire acondicionado y un
    reloj lejano. 16 s en bucle."""
    d = 16.0
    b = np.zeros((int(d * SR), 2))
    t = t_(d)
    zumbido = 0.5 * np.sin(2 * np.pi * 60 * t) + 0.2 * np.sin(2 * np.pi * 120 * t)
    poner(b, zumbido * 0.04, 0, 1.0, 0)
    aire = lowpass(ruido(d), 400)
    poner(b, aire * 0.25, 0, 1.0, -0.5)
    poner(b, lowpass(ruido(d), 350) * 0.25, 0, 1.0, 0.5)
    for k in range(16):                               # reloj de péndulo lejano
        tic = bandpass(ruido(0.03), 2000, 5000) * decay(int(0.03 * SR), 0.005)
        poner(b, tic, k * 1.0, 0.05 if k % 2 else 0.035, 0.7)
    return reverb(b, 0.4, 1.4)


kick = bombo


def poner_m(buf, x, inicio, gan=1.0, envolver=True):
    """Versión mono de poner (efectos)."""
    i = int(inicio * SR)
    n = len(x)
    L = len(buf)
    if i + n <= L:
        buf[i:i + n] += x * gan
    else:
        buf[i:] += x[:L - i] * gan


# ---------------------------------------------------------------- efectos
def sfx():
    s = {}
    s["mt_leer"] = sine(1760, 0.035) * decay(int(0.035 * SR), 0.01)
    f = np.linspace(1100, 1650, int(0.05 * SR))
    s["mt_escribir"] = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 * env(len(f), 0.002, 0.02, 0.6, 0.02)
    s["mt_mover"] = (bandpass(ruido(0.02), 500, 3000) + 0.5 * sine(620, 0.02)) * decay(int(0.02 * SR), 0.006)
    buf = np.zeros(int(0.6 * SR))
    for k, n in enumerate([72, 76, 79, 84]):
        poner_m(buf, sine(hz(n), 0.3) * decay(int(0.3 * SR), 0.08), k * 0.07, 1.0, False)
    s["mt_acepta"] = buf
    s["mt_rechaza"] = lowpass(square(110, 0.35, 12), 1600) * env(int(0.35 * SR), 0.005, 0.05, 0.8, 0.1)
    buf = np.zeros(int(0.5 * SR))
    for k in range(2):
        poner_m(buf, sine(988, 0.12) * env(int(0.12 * SR), 0.005, 0.02, 0.8, 0.03), k * 0.2, 1.0, False)
    s["radar_aviso"] = buf
    d = 1.0
    f = 380 + 900 * t_(d) / d
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(int(d * SR), 0.05, 0.2, 0.5, 0.4)
    s["radar_barrido"] = lowpass(x, 2200) * 0.6 + 0.2 * bandpass(ruido(d), 300, 1500) * env(int(d * SR), 0.2, 0.2, 0.6, 0.4)
    s["radar_ping"] = (sine(1320, 0.6) + 0.3 * sine(2640, 0.6)) * decay(int(0.6 * SR), 0.15)
    x = np.zeros(int(0.5 * SR))
    for k, (ff, tau) in enumerate([(2093, 0.08), (3410, 0.05), (5200, 0.03)]):
        x[:] += sine(ff, 0.5) * decay(len(x), tau) * (1 / (k + 1))
    rebote = np.zeros_like(x)
    poner_m(rebote, x[: int(0.2 * SR)] * 0.4, 0.13, 1.0, False)
    s["moneda"] = x + rebote
    buf = np.zeros(int(1.0 * SR))
    for k, n in enumerate([81, 85, 88, 93, 97]):
        poner_m(buf, (sine(hz(n), 0.6) + 0.3 * sine(hz(n) * 2.01, 0.6)) * decay(int(0.6 * SR), 0.15), k * 0.06, 0.6, False)
    s["joya"] = buf
    def susurro(d, bajo, alto):
        n = int(d * SR)
        trem = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 14 * t_(d)))
        return bandpass(ruido(d), bajo, alto) * trem * env(n, 0.03, 0.1, 0.6, d * 0.5)
    s["oculto"] = susurro(0.45, 1500, 5000)
    s["crujido"] = susurro(0.2, 2000, 6000)
    buf = np.zeros(int(0.4 * SR))
    poner_m(buf, square(330, 0.12, 5) * env(int(0.12 * SR), 0.005, 0.02, 0.7, 0.03), 0.0, 1, False)
    poner_m(buf, square(247, 0.18, 5) * env(int(0.18 * SR), 0.005, 0.02, 0.7, 0.06), 0.14, 1, False)
    s["bloqueado"] = lowpass(buf, 2000)
    d = 0.55
    radio = bandpass(ruido(d), 800, 3200) * 0.5 * env(int(d * SR), 0.01, 0.05, 0.6, 0.1)
    radio += sine(1200, d) * 0.3 * ((t_(d) * 20).astype(int) % 2) * env(int(d * SR), 0.01, 0.05, 0.6, 0.1)
    s["radio"] = radio
    s["alarma"] = remate_alarma()
    d = 0.6
    golpe = np.zeros(int(d * SR))
    poner_m(golpe, kick()[: int(0.15 * SR)], 0.45, 0.6, False)
    s["puerta"] = lowpass(ruido(d), 900) * env(int(d * SR), 0.15, 0.2, 0.4, 0.2) + golpe
    buf = np.zeros(int(0.5 * SR))
    for k, n in enumerate([84, 79, 88]):
        poner_m(buf, square(hz(n), 0.07, 4) * env(int(0.07 * SR), 0.003, 0.02, 0.6, 0.02), k * 0.09, 0.5, False)
    s["terminal"] = buf
    f = np.linspace(500, 900, int(0.3 * SR))
    s["sospecha"] = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(f), 0.01, 0.05, 0.6, 0.15)
    d = 0.7
    hit = np.zeros(int(d * SR))
    for n in (62, 65, 68):
        hit += saw(hz(n + 12), d, 10)
    s["persecucion"] = lowpass(hit, 3000) * env(int(d * SR), 0.003, 0.1, 0.5, 0.4) + 0.8 * np.pad(kick(), (0, len(hit) - len(kick())))
    s["laser"] = lowpass(saw(1400, 0.3, 4), 3000) * decay(int(0.3 * SR), 0.08)
    return s




def efectos_nuevos():
    s = {}
    # pasos del ladrón: golpe sordo + roce
    d = 0.12
    s["paso"] = (lowpass(ruido(d), 500) * 0.8 + 0.4 * sine(90, d)) * decay(int(d * SR), 0.025)
    # pasos del guardia: botas, más graves y con taco
    d = 0.16
    x = (lowpass(ruido(d), 350) + 0.6 * sine(70, d)) * decay(int(d * SR), 0.035)
    taco = bandpass(ruido(0.03), 1500, 4000) * decay(int(0.03 * SR), 0.006)
    x[: len(taco)] += taco * 0.5
    s["paso_guardia"] = x
    # tarjeta de nivel: acorde de campana
    b = np.zeros(int(2.0 * SR))
    for k, n in enumerate([62, 69, 74]):
        poner_m(b, campana(hz(n), 1.8), k * 0.05, 0.4, False)
    s["nivel"] = b
    return s


def guardar_wav(ruta, x, pico, canales):
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x / m * pico, -1, 1)
    datos = (x * 32767).astype("<i2")
    with wave.open(str(ruta), "wb") as w:
        w.setnchannels(canales)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())


def guardar(nombre, x, pico=0.85):
    """Efecto mono en WAV."""
    OUT.mkdir(parents=True, exist_ok=True)
    guardar_wav(OUT / f"{nombre}.wav", x, pico, 1)
    print(f"  {nombre}.wav  {len(x) / SR:.2f} s")


IMPORT_OGG = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[params]

loop={bucle}
loop_offset=0
bpm={bpm}
beat_count={beats}
bar_beats=4
"""


def guardar_ogg(nombre, x, pico=0.85, bucle=True, bpm=0, beats=0):
    """Música estéreo en Ogg Vorbis (con su .import en bucle para Godot)."""
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        w = Path(tmp) / "x.wav"
        guardar_wav(w, x, pico, 2)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(w), "-c:a", "libvorbis", "-q:a", "5",
                        str(OUT / f"{nombre}.ogg")], check=True)
    imp = OUT / f"{nombre}.ogg.import"
    if not imp.exists():
        imp.write_text(IMPORT_OGG.format(bucle="true" if bucle else "false", bpm=bpm, beats=beats))
    print(f"  {nombre}.ogg  {len(x) / SR:.2f} s")


def main():
    temas = [Tema(k) for k in TEMAS]
    print("Música:")
    for T in temas:
        beats = COMPASES * 4
        bpm = T.bpm
        guardar_ogg(f"musica_{T.clave}_base", capa_base(T), 0.7, True, bpm, beats)
        guardar_ogg(f"musica_{T.clave}_tension", capa_tension(T), 0.6, True, bpm, beats)
        guardar_ogg(f"musica_{T.clave}_busqueda", capa_busqueda(T), 0.7, True, bpm, beats)
        guardar_ogg(f"musica_{T.clave}_persecucion", capa_persecucion(T), 0.75, True, bpm, beats)
    guardar_ogg("remate_victoria", remate_victoria(), 0.85, False)
    guardar_ogg("remate_derrota", remate_derrota(), 0.85, False)
    guardar_ogg("ambiente_museo", ambiente(), 0.5, True)
    gm.exportar_documentacion(RAIZ)
    print("Efectos:")
    todos = sfx()
    todos.update(efectos_nuevos())
    for nombre, x in todos.items():
        guardar("sfx_" + nombre, x, 0.8)


if __name__ == "__main__":
    main()
