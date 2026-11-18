"""Bloques de síntesis de sonido para SOMBRA (todo original, sin muestras).

Osciladores, envolventes, filtros, instrumentos (piano eléctrico FM,
vibráfono, campana, bajo pulsado Karplus-Strong, pad, batería) y una
reverberación de Schroeder estéreo que respeta el bucle.
"""
import numpy as np
from scipy.signal import lfilter

SR = 32000
rng = np.random.default_rng(7)


def hz(nota: float) -> float:
    """Frecuencia de una nota MIDI."""
    return 440.0 * 2 ** ((nota - 69) / 12)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.01, d=0.1, s=0.7, r=0.1):
    """ADSR de n muestras (tiempos en segundos)."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    sus = max(0, n - a - d - r)
    e = np.concatenate([
        np.linspace(0, 1, max(a, 1)), np.linspace(1, s, max(d, 1)),
        np.full(sus, s), np.linspace(s, 0, max(r, 1))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def saw(f, dur, armonicos=12, detune=0.0):
    t = t_(dur)
    y = np.zeros_like(t)
    for k in range(1, armonicos + 1):
        if f * k > SR / 2.2:
            break
        y += np.sin(2 * np.pi * f * (1 + detune) * k * t) / k
    return y * 0.6


def square(f, dur, armonicos=9):
    t = t_(dur)
    y = np.zeros_like(t)
    for k in range(1, armonicos * 2, 2):
        if f * k > SR / 2.2:
            break
        y += np.sin(2 * np.pi * f * k * t) / k
    return y * 0.7


def sine(f, dur, fase=0.0):
    return np.sin(2 * np.pi * f * t_(dur) + fase)


def lowpass(x, corte):
    """Paso bajo de un polo aplicado dos veces (12 dB/oct)."""
    a = np.exp(-2 * np.pi * corte / SR)
    y = lfilter([1 - a], [1, -a], x, axis=0)
    return lfilter([1 - a], [1, -a], y, axis=0)


def highpass(x, corte):
    return x - lowpass(x, corte)


def bandpass(x, bajo, alto):
    return lowpass(highpass(x, bajo), alto)


def ruido(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def silencio(dur, canales=2):
    return np.zeros((int(dur * SR), canales))


def poner(buf, x, inicio, gan=1.0, pan=0.0, envolver=True):
    """Suma x (mono o estéreo) en buf estéreo a partir de `inicio` (s).
    `pan` va de -1 (izquierda) a 1 (derecha), con ley de potencia constante.
    Si `envolver`, la cola da la vuelta al principio: el bucle es perfecto."""
    if x.ndim == 1:
        ang = (pan + 1) * np.pi / 4
        x = np.stack([x * np.cos(ang), x * np.sin(ang)], axis=1) * np.sqrt(2)
    i = int(inicio * SR) % len(buf)
    n = len(x)
    L = len(buf)
    if i + n <= L:
        buf[i:i + n] += x * gan
    else:
        primera = L - i
        buf[i:] += x[:primera] * gan
        if envolver:
            resto = x[primera:] * gan
            while len(resto) > 0:
                k = min(len(resto), L)
                buf[:k] += resto[:k]
                resto = resto[k:]


# ------------------------------------------------------------- instrumentos
def piano_electrico(f, dur, brillo=1.0):
    """Piano eléctrico por síntesis FM (portadora y moduladora 1:1, índice que
    decae: el ataque suena metálico y se apaga a un tono cálido)."""
    t = t_(dur)
    indice = (1.8 * brillo) * np.exp(-t * 5) + 0.25
    mod = np.sin(2 * np.pi * f * t)
    y = np.sin(2 * np.pi * f * t + indice * mod)
    y += 0.25 * np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 40)      # "tine" del ataque
    y *= decay(len(t), 0.9) * env(len(t), 0.003, 0.05, 1.0, 0.08)
    y *= 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)                        # trémolo suave
    return y


def vibrafono(f, dur):
    t = t_(dur)
    y = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 6) \
        + 0.12 * np.sin(2 * np.pi * f * 10 * t) * np.exp(-t * 14)
    y *= decay(len(t), 1.1) * env(len(t), 0.002, 0.02, 1.0, 0.1)
    return y * (1 + 0.35 * np.sin(2 * np.pi * 5.5 * t))               # motor del vibráfono


def campana(f, dur):
    t = t_(dur)
    y = np.zeros_like(t)
    for ratio, amp, tau in [(1, 1, 1.4), (2.76, 0.45, 0.8), (5.4, 0.25, 0.4), (8.93, 0.12, 0.2)]:
        y += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / tau)
    return y * env(len(t), 0.002, 0.01, 1.0, 0.05)


def bajo_pulsado(f, dur, brillo=0.5):
    """Cuerda pulsada de Karplus-Strong: un ráfaga de ruido recircula por una
    línea de retardo con un promedio (filtro paso bajo) en el lazo."""
    n = int(dur * SR)
    N = max(2, int(SR / f))
    x = np.zeros(n)
    x[:N] = lowpass(rng.uniform(-1, 1, N), 400 + 3000 * brillo)
    g = 0.996
    a = np.zeros(N + 2)
    a[0] = 1
    a[N] = -g / 2
    a[N + 1] = -g / 2
    y = lfilter([1], a, x)
    y += 0.5 * np.sin(2 * np.pi * f * t_(dur)) * decay(n, 0.5)          # cuerpo grave
    return y * env(n, 0.002, 0.05, 1.0, 0.06)


def pad(notas, dur, corte=900, ataque=0.9):
    """Colchón de sierras desafinadas, una por canal (ancho estéreo)."""
    izq = np.zeros(int(dur * SR))
    der = np.zeros(int(dur * SR))
    for n in notas:
        izq += saw(hz(n), dur, 8, -0.0035)
        der += saw(hz(n), dur, 8, 0.0035)
    e = env(len(izq), ataque, 0.5, 0.8, 1.2)
    return np.stack([lowpass(izq, corte) * e, lowpass(der, corte) * e], axis=1)


def cuerdas(f, dur):
    """Nota de cuerdas en trémolo (tensión)."""
    t = t_(dur)
    y = saw(f, dur, 10, 0.002) + saw(f, dur, 10, -0.002)
    y = lowpass(y, 1800) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 7 * t)))
    return y * env(len(t), 0.4, 0.3, 0.8, 0.6)


def bombo():
    d = 0.32
    fs = 140 * np.exp(-t_(d) * 20) + 46
    return np.sin(2 * np.pi * np.cumsum(fs) / SR) * decay(int(d * SR), 0.1)


def caja():
    d = 0.22
    return (0.65 * bandpass(ruido(d), 1200, 7000) + 0.35 * sine(185, d)) * decay(int(d * SR), 0.055)


def escobilla(d=0.18):
    """Barrido de escobilla de jazz sobre el parche."""
    return bandpass(ruido(d), 2500, 8000) * env(int(d * SR), d * 0.5, 0.02, 0.6, d * 0.4)


def platillo(d=0.05, tau=0.012):
    return highpass(ruido(d), 7000) * decay(int(d * SR), tau)


def tom(f0=110, d=0.35):
    fs = f0 * np.exp(-t_(d) * 5) + f0 * 0.5
    return np.sin(2 * np.pi * np.cumsum(fs) / SR) * decay(int(d * SR), 0.13)


def aro():
    d = 0.06
    return (bandpass(ruido(d), 1500, 5000) + 0.5 * sine(900, d)) * decay(int(d * SR), 0.008)


# ------------------------------------------------------------ reverberación
def _comb(x, retardo, g):
    a = np.zeros(retardo + 1)
    a[0] = 1
    a[retardo] = -g
    return lfilter([1], a, x)


def _pasatodo(x, retardo, g):
    b = np.zeros(retardo + 1)
    a = np.zeros(retardo + 1)
    b[0] = -g
    b[retardo] = 1
    a[0] = 1
    a[retardo] = -g
    return lfilter(b, a, x)


def reverb(buf, mezcla=0.25, tamano=1.0, bucle=True):
    """Reverberación de Schroeder (4 filtros peine en paralelo + 2 pasatodo
    en serie) con retardos distintos por canal. Con `bucle`, procesa el
    fragmento dos veces seguidas y se queda con la segunda vuelta: la cola de
    la reverberación del final cae sobre el principio y el bucle no salta."""
    x = np.concatenate([buf, buf]) if bucle else buf
    salida = np.zeros_like(x)
    for canal, desfase in ((0, 0), (1, 23)):
        s = x[:, canal]
        acc = np.zeros_like(s)
        for ms, g in ((29.7, 0.80), (37.1, 0.79), (41.1, 0.78), (43.7, 0.77)):
            acc += _comb(s, int((ms * tamano) * SR / 1000) + desfase, g)
        acc = _pasatodo(acc, int(5.0 * SR / 1000) + desfase // 3, 0.7)
        acc = _pasatodo(acc, int(1.7 * SR / 1000), 0.7)
        salida[:, canal] = lowpass(acc, 5000) * 0.25
    mezclado = x * (1 - mezcla) + salida * mezcla
    return mezclado[len(buf):] if bucle else mezclado
