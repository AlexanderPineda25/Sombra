"""
Genera el arte del juego (sprites animados, texturas del museo y luces).

    python3 herramientas/generar_arte.py

Todo se dibuja con código a 4x y se reduce con filtro Lanczos para obtener
bordes suaves. Vista cenital (top-down): los personajes miran hacia la derecha
(+x) y el juego los rota hacia donde caminan.

Salida en assets/:
  sprites/ladron.png          8 filas x 8 cuadros de 64 px
  sprites/guardia_0..2.png    3 filas x 8 cuadros (tres uniformes)
  sprites/camara.png, joyas.png, moneda.png
  tiles/museo.png             texturas de 64 px por casilla
  luces/cono.png, luces/circulo.png
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
S = 4                    # sobremuestreo
CELDA = 64               # tamaño final de cada cuadro
C = CELDA * S            # tamaño de trabajo
MEDIO = C / 2


def rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mezclar(c1, c2, t):
    a, b = rgba(c1), rgba(c2)
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def nuevo(w=C, h=C):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def elipse(d, cx, cy, rx, ry, color, borde=None, ancho=0):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color,
              outline=borde, width=ancho)


def capsula(d, p1, p2, grosor, color, borde=None):
    """Segmento grueso con extremos redondeados."""
    if borde:
        d.line([p1, p2], fill=borde, width=int(grosor + 6))
        for p in (p1, p2):
            elipse(d, p[0], p[1], grosor / 2 + 3, grosor / 2 + 3, borde)
    d.line([p1, p2], fill=color, width=int(grosor))
    for p in (p1, p2):
        elipse(d, p[0], p[1], grosor / 2, grosor / 2, color)


def rect_redondo(d, x0, y0, x1, y1, r, color, borde=None, ancho=0):
    d.rounded_rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], r,
                        fill=color, outline=borde, width=ancho)


def reducir(img, w=CELDA, h=CELDA):
    return img.resize((w, h), Image.LANCZOS)


def sombra_suave(img, cx, cy, rx, ry, alfa=95):
    capa = nuevo(img.width, img.height)
    elipse(ImageDraw.Draw(capa), cx, cy, rx, ry, (0, 0, 0, alfa))
    capa = capa.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(capa)


# ====================================================================== #
# Personajes
# ====================================================================== #
LADRON = {
    "torso": "#262a31", "torso_luz": "#363b45", "borde": "#0b0c0f",
    "pantalon": "#1f2126", "bota": "#15161a", "bota_luz": "#2b2d33",
    "manga": "#22252b", "mano": "#0f1012", "mano_luz": "#2a2c31",
    "cabeza": "#131418", "cabeza_luz": "#2b2e36", "piel": "#c99a7c",
    "mochila": "#3a3f47", "mochila_luz": "#4c525c", "correa": "#17181c",
    "chaleco": "#1a1d22", "chaleco_luz": "#3a3f48",
}

GUARDIAS = [
    {"camisa": "#5d86c4", "camisa_luz": "#86a8db", "gorra": "#1c2a4a", "gorra_luz": "#34497a",
     "pantalon": "#1b2236", "piel": "#e0b48f", "insignia": "#f2c94c"},
    {"camisa": "#4f6f8f", "camisa_luz": "#7896b3", "gorra": "#181f30", "gorra_luz": "#2f3b57",
     "pantalon": "#1a1f2b", "piel": "#9b6b4c", "insignia": "#f2c94c"},
    {"camisa": "#6f7fa8", "camisa_luz": "#97a5c9", "gorra": "#22284a", "gorra_luz": "#3c4677",
     "pantalon": "#20243a", "piel": "#c58e6a", "insignia": "#e9d27a"},
]
GUARDIA_COMUN = {"borde": "#0b0d14", "bota": "#111216", "bota_luz": "#2a2c33",
                 "cinturon": "#16171b", "hebilla": "#d9b44a", "linterna": "#3b3f47",
                 "linterna_luz": "#9aa1ad", "lente": "#fff3c4", "radio": "#101114"}


def pies(d, x, y_lado, avance, ancho_pie, color, luz, pantalon):
    """Pierna y bota. `avance` desplaza el pie hacia delante (+) o atrás (-)."""
    cadera = (MEDIO - 6, MEDIO + y_lado)
    pie = (MEDIO + avance + 10, MEDIO + y_lado)
    capsula(d, cadera, (pie[0] - 10, pie[1]), 26, rgba(pantalon))
    rect_redondo(d, pie[0] - 24, pie[1] - ancho_pie / 2, pie[0] + 24, pie[1] + ancho_pie / 2, 11,
                 rgba(color), rgba("#08090b"), 3)
    rect_redondo(d, pie[0] + 2, pie[1] - ancho_pie / 2 + 5, pie[0] + 20, pie[1] + ancho_pie / 2 - 5, 7,
                 rgba(luz))


def dibujar_ladron(pose, f, n):
    """Ladrón visto desde arriba mirando a +x. pose: idle, caminar, correr,
    agachado, agachado_caminar, lanzar, recoger, interactuar."""
    p = LADRON
    img = nuevo()
    fase = 2 * math.pi * f / n
    zancada, brazo, adelanto, escala = 0, 0, 0, 1.0
    respira = math.sin(fase) * 2
    if pose == "caminar":
        zancada, brazo = 24 * math.sin(fase), 16 * math.sin(fase)
    elif pose == "correr":
        zancada, brazo, adelanto = 36 * math.sin(fase), 28 * math.sin(fase), 8
    elif pose == "agachado":
        escala, adelanto = 0.9, 6
    elif pose == "agachado_caminar":
        escala, adelanto = 0.9, 6
        zancada, brazo = 14 * math.sin(fase), 6 * math.sin(fase)
    elif pose == "recoger":
        adelanto = [4, 12, 16, 8][f % 4]
    sombra_suave(img, MEDIO + 10, MEDIO + 14, 66 * escala, 56 * escala)
    d = ImageDraw.Draw(img)

    # piernas
    agach = pose.startswith("agachado")
    ancho_pie = 26
    if agach:
        pies(d, 0, -26, 20 + zancada, ancho_pie, p["bota"], p["bota_luz"], p["pantalon"])
        pies(d, 0, 26, 20 - zancada, ancho_pie, p["bota"], p["bota_luz"], p["pantalon"])
    else:
        pies(d, 0, -22, zancada, ancho_pie, p["bota"], p["bota_luz"], p["pantalon"])
        pies(d, 0, 22, -zancada, ancho_pie, p["bota"], p["bota_luz"], p["pantalon"])

    cx = MEDIO + adelanto
    rx, ry = 36 * escala, (58 + respira * 0.5) * escala

    # mochila (detrás)
    rect_redondo(d, cx - rx - 30, MEDIO - 38 * escala, cx - rx + 24, MEDIO + 38 * escala, 14,
                 rgba(p["mochila"]), rgba(p["borde"]), 4)
    rect_redondo(d, cx - rx - 26, MEDIO - 30 * escala, cx - rx + 2, MEDIO + 30 * escala, 10,
                 rgba(p["mochila_luz"]))
    d.line([(cx - rx - 18, MEDIO - 22), (cx - rx - 18, MEDIO + 22)], fill=rgba("#23262c"), width=4)
    for yy in (-20, 20):
        elipse(d, cx - rx - 8, MEDIO + yy * escala, 5, 5, rgba("#8a8f99"))

    # brazos (posición de las manos según la pose)
    hombro_i = (cx + 2, MEDIO - ry + 10)
    hombro_d = (cx + 2, MEDIO + ry - 10)
    mano_i = (cx + 30 - brazo, MEDIO - ry - 2)
    mano_d = (cx + 30 + brazo, MEDIO + ry + 2)
    moneda = None
    if agach:
        mano_i = (cx + 40, MEDIO - 34)
        mano_d = (cx + 40, MEDIO + 34)
    if pose == "lanzar":
        etapas = [(-26, 70), (0, 76), (70, 50), (50, 58)]
        dx, dy = etapas[f % 4]
        mano_d = (cx + dx, MEDIO + dy)
        mano_i = (cx + 34, MEDIO - ry + 4)
        if f % 4 < 2:
            moneda = mano_d
    elif pose == "recoger":
        alcance = [40, 66, 78, 54][f % 4]
        mano_i = (cx + alcance, MEDIO - 24)
        mano_d = (cx + alcance, MEDIO + 24)
    elif pose == "interactuar":
        tecla = [0, 6, -4, 4][f % 4]
        mano_i = (cx + 58 + tecla, MEDIO - 20)
        mano_d = (cx + 58 - tecla, MEDIO + 20)
    for hombro, mano in ((hombro_i, mano_i), (hombro_d, mano_d)):
        capsula(d, hombro, mano, 22, rgba(p["manga"]), rgba(p["borde"]))

    # torso con chaleco táctico
    elipse(d, cx, MEDIO, rx + 4, ry + 4, rgba(p["borde"]))
    elipse(d, cx, MEDIO, rx, ry, rgba(p["torso"]))
    elipse(d, cx - 6, MEDIO - 8, rx * 0.72, ry * 0.75, rgba(p["torso_luz"]))
    elipse(d, cx + 2, MEDIO + 4, rx * 0.66, ry * 0.7, rgba(p["torso"]))
    # correas de la mochila sobre los hombros
    for yy in (-30, 30):
        d.line([(cx - rx + 4, MEDIO + yy * escala), (cx + rx - 6, MEDIO + yy * 1.05 * escala)],
               fill=rgba(p["correa"]), width=7)
    # bolsillos del chaleco en el pecho
    for yy in (-24, 0, 24):
        rect_redondo(d, cx + 14, MEDIO + yy * escala - 9, cx + 30, MEDIO + yy * escala + 9, 4,
                     rgba(p["chaleco"]), rgba(p["chaleco_luz"]), 2)

    # guantes
    for mano in (mano_i, mano_d):
        elipse(d, mano[0], mano[1], 14, 14, rgba("#050506"))
        elipse(d, mano[0], mano[1], 11, 11, rgba(p["mano"]))
        elipse(d, mano[0] - 3, mano[1] - 3, 5, 5, rgba(p["mano_luz"]))
    if moneda:
        elipse(d, moneda[0] + 10, moneda[1], 7, 7, rgba("#ffd35a"), rgba("#a07a1c"), 2)

    # cabeza con pasamontañas
    hx = cx + 8 + (10 if agach else 0) + (6 if pose == "recoger" else 0)
    elipse(d, hx, MEDIO, 33, 33, rgba(p["borde"]))
    elipse(d, hx, MEDIO, 30, 30, rgba(p["cabeza"]))
    for r in (24, 16, 9):
        d.arc([hx - r, MEDIO - r, hx + r, MEDIO + r], 200, 340, fill=rgba("#1d1f25"), width=3)
    elipse(d, hx - 8, MEDIO - 9, 13, 10, rgba(p["cabeza_luz"]))
    # rendija de los ojos al frente
    rect_redondo(d, hx + 14, MEDIO - 16, hx + 29, MEDIO + 16, 7, rgba(p["piel"]))
    for yy in (-8, 8):
        elipse(d, hx + 23, MEDIO + yy, 4, 4, rgba("#1a1110"))
        elipse(d, hx + 24, MEDIO + yy - 1, 1.5, 1.5, rgba("#ffffff"))
    return reducir(img)


def dibujar_guardia(var, pose, f, n):
    """Guardia de seguridad visto desde arriba mirando a +x, con linterna en la
    mano derecha. pose: idle, caminar, correr."""
    p = dict(GUARDIA_COMUN, **GUARDIAS[var])
    img = nuevo()
    fase = 2 * math.pi * f / n
    zancada, brazo, adelanto = 0, 0, 0
    respira = math.sin(fase) * 2
    if pose == "caminar":
        zancada, brazo = 22 * math.sin(fase), 14 * math.sin(fase)
    elif pose == "correr":
        zancada, brazo, adelanto = 34 * math.sin(fase), 24 * math.sin(fase), 6
    sombra_suave(img, MEDIO + 10, MEDIO + 14, 70, 60)
    d = ImageDraw.Draw(img)
    pies(d, 0, -24, zancada, 28, p["bota"], p["bota_luz"], p["pantalon"])
    pies(d, 0, 24, -zancada, 28, p["bota"], p["bota_luz"], p["pantalon"])

    cx = MEDIO + adelanto
    rx, ry = 38, 60 + respira * 0.5
    # cinturón con equipo (asoma alrededor del torso)
    elipse(d, cx - 2, MEDIO, rx + 8, ry + 6, rgba(p["cinturon"]))
    rect_redondo(d, cx - 18, MEDIO + ry - 2, cx + 6, MEDIO + ry + 14, 4, rgba(p["radio"]))  # radio
    elipse(d, cx - 4, MEDIO + ry + 14, 3, 3, rgba("#c0392b"))
    rect_redondo(d, cx - 30, MEDIO - ry - 12, cx - 4, MEDIO - ry + 4, 5, rgba("#22242a"))   # funda

    # brazos: el derecho sostiene la linterna al frente; el izquierdo se balancea
    hombro_i = (cx + 2, MEDIO - ry + 10)
    hombro_d = (cx + 2, MEDIO + ry - 10)
    mano_i = (cx + 26 - brazo, MEDIO - ry - 2)
    mano_d = (cx + 62, MEDIO + 26 + (brazo * 0.2 if pose != "idle" else 0))
    for hombro, mano, manga in ((hombro_i, mano_i, True), (hombro_d, mano_d, True)):
        medio = ((hombro[0] + mano[0]) / 2, (hombro[1] + mano[1]) / 2)
        capsula(d, hombro, medio, 24, rgba(p["camisa"]), rgba(p["borde"]))
        capsula(d, medio, mano, 18, rgba(p["piel"]), rgba(p["borde"]))
    # linterna en la mano derecha
    lx, ly = mano_d
    rect_redondo(d, lx - 6, ly - 8, lx + 40, ly + 8, 5, rgba(p["linterna"]), rgba("#07080a"), 3)
    rect_redondo(d, lx + 30, ly - 11, lx + 46, ly + 11, 4, rgba(p["linterna_luz"]), rgba("#07080a"), 3)
    elipse(d, lx + 46, ly, 5, 10, rgba(p["lente"]))
    elipse(d, mano_d[0], mano_d[1], 10, 10, rgba(p["piel"]))
    elipse(d, mano_i[0], mano_i[1], 10, 10, rgba(p["piel"]), rgba(p["borde"]), 2)

    # torso con camisa de uniforme
    elipse(d, cx, MEDIO, rx + 4, ry + 4, rgba(p["borde"]))
    elipse(d, cx, MEDIO, rx, ry, rgba(p["camisa"]))
    elipse(d, cx - 6, MEDIO - 10, rx * 0.7, ry * 0.72, rgba(p["camisa_luz"]))
    elipse(d, cx + 2, MEDIO + 4, rx * 0.66, ry * 0.7, rgba(p["camisa"]))
    # charreteras y placa
    for yy in (-1, 1):
        rect_redondo(d, cx - 16, MEDIO + yy * (ry - 18) - 7, cx + 12, MEDIO + yy * (ry - 18) + 7, 4,
                     rgba(p["gorra"]))
    poligono_placa = [(cx + 22, MEDIO - 30), (cx + 30, MEDIO - 24), (cx + 26, MEDIO - 14),
                      (cx + 18, MEDIO - 14), (cx + 14, MEDIO - 24)]
    d.polygon(poligono_placa, fill=rgba(p["insignia"]), outline=rgba("#7a5a10"))

    # cabeza con gorra
    hx = cx + 6
    for yy in (-30, 30):
        elipse(d, hx - 2, MEDIO + yy, 7, 7, rgba(p["piel"]), rgba(p["borde"]), 2)   # orejas
    d.pieslice([hx - 2, MEDIO - 30, hx + 46, MEDIO + 30], -70, 70, fill=rgba("#0b0f1c"))  # visera
    d.pieslice([hx + 2, MEDIO - 26, hx + 42, MEDIO + 26], -65, 65, fill=rgba(p["gorra"]))
    elipse(d, hx, MEDIO, 31, 31, rgba(p["borde"]))
    elipse(d, hx, MEDIO, 28, 28, rgba(p["gorra"]))
    elipse(d, hx - 6, MEDIO - 7, 16, 14, rgba(p["gorra_luz"]))
    elipse(d, hx, MEDIO, 4, 4, rgba(p["gorra_luz"]))                     # botón
    elipse(d, hx + 22, MEDIO, 6, 7, rgba(p["insignia"]), rgba("#7a5a10"), 2)  # escudo
    return reducir(img)


def hoja(filas, columnas, dibujar):
    out = Image.new("RGBA", (columnas * CELDA, len(filas) * CELDA), (0, 0, 0, 0))
    for r, (pose, n) in enumerate(filas):
        for f in range(columnas):
            out.paste(dibujar(pose, f % n, n), (f * CELDA, r * CELDA))
    return out


FILAS_LADRON = [("idle", 4), ("caminar", 8), ("correr", 8), ("agachado", 4),
                ("agachado_caminar", 8), ("lanzar", 4), ("recoger", 4), ("interactuar", 4)]
FILAS_GUARDIA = [("idle", 4), ("caminar", 8), ("correr", 8)]


# ====================================================================== #
# Objetos
# ====================================================================== #
def dibujar_camara():
    img = nuevo()
    d = ImageDraw.Draw(img)
    sombra_suave(img, MEDIO + 6, MEDIO + 8, 44, 40, 80)
    rect_redondo(d, MEDIO - 46, MEDIO - 46, MEDIO + 46, MEDIO + 46, 16, rgba("#2b303b"), rgba("#0c0e12"), 5)
    elipse(d, MEDIO, MEDIO, 34, 34, rgba("#1a1e26"))
    rect_redondo(d, MEDIO - 10, MEDIO - 24, MEDIO + 74, MEDIO + 24, 12, rgba("#d9dde4"), rgba("#0c0e12"), 5)
    rect_redondo(d, MEDIO + 4, MEDIO - 16, MEDIO + 60, MEDIO - 6, 4, rgba("#ffffff"))
    rect_redondo(d, MEDIO + 62, MEDIO - 20, MEDIO + 82, MEDIO + 20, 8, rgba("#20242c"), rgba("#0c0e12"), 4)
    elipse(d, MEDIO + 78, MEDIO, 10, 13, rgba("#2f5fd0"))
    elipse(d, MEDIO + 80, MEDIO - 4, 4, 4, rgba("#bfe0ff"))
    return reducir(img)


COLORES_JOYA = [("#5ae6ff", "#c8f8ff", "#1b6f8a"), ("#ff6ec7", "#ffd0ee", "#8a1e5e"),
                ("#ffd35a", "#fff1c2", "#8a6410")]


def dibujar_joya(i):
    base, luz, oscuro = COLORES_JOYA[i]
    img = nuevo()
    d = ImageDraw.Draw(img)
    r = 64
    puntos = [(MEDIO + r * math.cos(a), MEDIO + r * math.sin(a))
              for a in [math.radians(-90 + 45 * k) for k in range(8)]]
    d.polygon(puntos, fill=rgba(oscuro))
    interior = [(MEDIO + 40 * math.cos(a), MEDIO + 40 * math.sin(a))
                for a in [math.radians(-90 + 45 * k) for k in range(8)]]
    for k in range(8):
        tono = mezclar(base, luz, (math.cos(math.radians(45 * k + 60)) + 1) / 2)
        d.polygon([puntos[k], puntos[(k + 1) % 8], interior[(k + 1) % 8], interior[k]], fill=tono)
    d.polygon(interior, fill=rgba(base))
    d.polygon([interior[7], interior[0], interior[1], (MEDIO, MEDIO)], fill=rgba(luz))
    d.line(puntos + [puntos[0]], fill=rgba("#ffffff", 160), width=3)
    elipse(d, MEDIO - 18, MEDIO - 22, 9, 6, rgba("#ffffff", 230))
    return reducir(img)


def dibujar_moneda():
    img = nuevo()
    d = ImageDraw.Draw(img)
    elipse(d, MEDIO, MEDIO, 60, 60, rgba("#ffd35a"), rgba("#8a6410"), 10)
    elipse(d, MEDIO, MEDIO, 38, 38, rgba("#f2b632"))
    elipse(d, MEDIO - 16, MEDIO - 18, 12, 8, rgba("#fff5cf"))
    return reducir(img, 32, 32)


# ====================================================================== #
# Texturas del museo (casillas de 64 px)
# ====================================================================== #
def ruido_marmol(tam, semilla, base, vena):
    rng = np.random.default_rng(semilla)
    y, x = np.mgrid[0:tam, 0:tam] / tam
    v = np.zeros((tam, tam))
    for k in range(4):
        fx, fy, fase = rng.uniform(1, 4), rng.uniform(1, 4), rng.uniform(0, 6.28)
        v += np.sin((x * fx + y * fy) * 6.28 + fase + 2.5 * np.sin(y * 9 + k)) / (k + 1)
    vetas = np.exp(-np.abs(v) * 7)
    b = np.array(rgba(base)[:3], float)
    c = np.array(rgba(vena)[:3], float)
    grano = rng.normal(0, 3, (tam, tam, 1))
    pix = b * (1 - vetas[..., None] * 0.6) + c * (vetas[..., None] * 0.6) + grano
    alfa = np.full((tam, tam, 1), 255.0)
    return Image.fromarray(np.clip(np.concatenate([pix, alfa], 2), 0, 255).astype("uint8"), "RGBA")


def piso(semilla, base, vena, borde):
    img = ruido_marmol(64, semilla, base, vena)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 63], outline=rgba(borde), width=1)
    d.line([(1, 1), (62, 1)], fill=rgba("#ffffff", 22))
    return img


def pared_superior():
    img = Image.new("RGBA", (64, 64), rgba("#3a4054"))
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    for _ in range(90):
        x, y = rng.randrange(64), rng.randrange(64)
        d.point((x, y), fill=rgba("#454c63"))
    d.rectangle([0, 0, 63, 63], outline=rgba("#2c3141"), width=2)
    d.line([(2, 2), (61, 2)], fill=rgba("#59617c"), width=2)
    return img


def pared_frente(cuadro=None):
    """Cara frontal de un muro que da hacia el sur, con zócalo y, a veces, una pintura."""
    img = Image.new("RGBA", (64, 64), rgba("#5b6380"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 20], fill=rgba("#3a4054"))           # parte superior del muro
    d.line([(0, 20), (63, 20)], fill=rgba("#7c86a8"), width=2)
    d.rectangle([0, 50, 63, 63], fill=rgba("#40465c"))          # zócalo
    d.line([(0, 50), (63, 50)], fill=rgba("#2c3141"), width=2)
    if cuadro is not None:
        rng = random.Random(cuadro)
        d.rectangle([12, 24, 51, 47], fill=rgba("#c9a24a"))
        d.rectangle([15, 27, 48, 44], fill=rgba("#1b1f2a"))
        colores = [["#e07a5f", "#3d405b", "#81b29a", "#f2cc8f"],
                   ["#264653", "#2a9d8f", "#e9c46a", "#f4a261"],
                   ["#5e548e", "#9f86c0", "#be95c4", "#e0b1cb"]][cuadro % 3]
        for _ in range(9):
            x, y = rng.randrange(15, 44), rng.randrange(27, 41)
            d.ellipse([x, y, x + rng.randrange(4, 10), y + rng.randrange(3, 7)],
                      fill=rgba(rng.choice(colores)))
        d.rectangle([12, 24, 51, 47], outline=rgba("#7a5c1e"), width=1)
    return img


def alfombra():
    img = Image.new("RGBA", (64, 64), rgba("#6b1e2c"))
    d = ImageDraw.Draw(img)
    d.rectangle([3, 3, 60, 60], outline=rgba("#c9a24a"), width=2)
    d.rectangle([8, 8, 55, 55], outline=rgba("#8c2a3b"), width=1)
    return img


def pedestal():
    img = nuevo()
    d = ImageDraw.Draw(img)
    sombra_suave(img, MEDIO + 10, MEDIO + 14, 96, 96, 110)
    rect_redondo(d, MEDIO - 96, MEDIO - 96, MEDIO + 96, MEDIO + 96, 18, rgba("#e8e2d4"), rgba("#7f7868"), 8)
    rect_redondo(d, MEDIO - 74, MEDIO - 74, MEDIO + 74, MEDIO + 74, 12, rgba("#2b2236"))
    rect_redondo(d, MEDIO - 66, MEDIO - 66, MEDIO + 66, MEDIO + 66, 10, rgba("#3e3150"))
    return reducir(img)


def vitrina():
    """Vidrio encima del pedestal (se dibuja sobre la joya)."""
    img = nuevo()
    d = ImageDraw.Draw(img)
    rect_redondo(d, MEDIO - 80, MEDIO - 80, MEDIO + 80, MEDIO + 80, 14, rgba("#bfe9ff", 34),
                 rgba("#dff6ff", 150), 5)
    d.polygon([(MEDIO - 70, MEDIO - 70), (MEDIO - 20, MEDIO - 70), (MEDIO - 70, MEDIO - 20)],
              fill=rgba("#ffffff", 70))
    return reducir(img)


def planta():
    img = nuevo()
    d = ImageDraw.Draw(img)
    sombra_suave(img, MEDIO + 12, MEDIO + 14, 92, 92, 110)
    elipse(d, MEDIO, MEDIO, 62, 62, rgba("#8a5a3c"), rgba("#4a2e1c"), 8)
    elipse(d, MEDIO, MEDIO, 48, 48, rgba("#3a2618"))
    rng = random.Random(7)
    for k in range(14):
        a = 2 * math.pi * k / 14 + rng.uniform(-0.1, 0.1)
        largo = rng.uniform(80, 112)
        puntas = [(MEDIO, MEDIO),
                  (MEDIO + math.cos(a - 0.22) * largo * 0.6, MEDIO + math.sin(a - 0.22) * largo * 0.6),
                  (MEDIO + math.cos(a) * largo, MEDIO + math.sin(a) * largo),
                  (MEDIO + math.cos(a + 0.22) * largo * 0.6, MEDIO + math.sin(a + 0.22) * largo * 0.6)]
        verde = rng.choice(["#2f8f5b", "#3aa66b", "#257a4c", "#47b878"])
        d.polygon(puntas, fill=rgba(verde), outline=rgba("#14462c"))
        d.line([(MEDIO, MEDIO), puntas[2]], fill=rgba("#7fd6a0"), width=3)
    elipse(d, MEDIO, MEDIO, 16, 16, rgba("#1d5e3a"))
    return reducir(img)


def salida(abierta):
    img = nuevo()
    d = ImageDraw.Draw(img)
    color = "#46d278" if abierta else "#c0392b"
    rect_redondo(d, MEDIO - 108, MEDIO - 108, MEDIO + 108, MEDIO + 108, 20, rgba("#262b38"), rgba("#0c0e12"), 8)
    for k in range(-80, 90, 32):
        d.line([(MEDIO - 84, MEDIO + k), (MEDIO + 84, MEDIO + k)], fill=rgba("#3a4152"), width=12)
    rect_redondo(d, MEDIO - 108, MEDIO - 108, MEDIO + 108, MEDIO + 108, 20, None, rgba(color), 10)
    d.polygon([(MEDIO - 40, MEDIO - 50), (MEDIO + 50, MEDIO), (MEDIO - 40, MEDIO + 50)],
              fill=rgba(color, 230 if abierta else 120))
    return reducir(img)


def puerta(abierta):
    img = nuevo()
    d = ImageDraw.Draw(img)
    rect_redondo(d, 0, MEDIO - 120, C, MEDIO + 120, 6, rgba("#1d2129"))
    if abierta:
        rect_redondo(d, 0, MEDIO - 120, 22, MEDIO + 120, 4, rgba("#59627a"))
        rect_redondo(d, C - 22, MEDIO - 120, C, MEDIO + 120, 4, rgba("#59627a"))
        d.line([(30, MEDIO), (C - 30, MEDIO)], fill=rgba("#46d278", 120), width=6)
    else:
        rect_redondo(d, 4, MEDIO - 116, C - 4, MEDIO + 116, 10, rgba("#7a8399"), rgba("#11141a"), 8)
        for x in range(40, C - 30, 44):
            d.line([(x, MEDIO - 100), (x, MEDIO + 100)], fill=rgba("#5d6578"), width=8)
        rect_redondo(d, MEDIO - 30, MEDIO - 30, MEDIO + 30, MEDIO + 30, 8, rgba("#20242c"), rgba("#11141a"), 5)
        elipse(d, MEDIO, MEDIO, 12, 12, rgba("#ff4b4b"))
    return reducir(img)


def terminal(resuelta):
    img = nuevo()
    d = ImageDraw.Draw(img)
    sombra_suave(img, MEDIO + 10, MEDIO + 12, 96, 80, 110)
    rect_redondo(d, MEDIO - 100, MEDIO - 80, MEDIO + 100, MEDIO + 92, 18, rgba("#2a2f3c"), rgba("#0b0d12"), 8)
    color = "#46d278" if resuelta else "#38d6ff"
    rect_redondo(d, MEDIO - 78, MEDIO - 62, MEDIO + 78, MEDIO + 12, 10, rgba("#06121a"), rgba(color), 6)
    for k in range(4):
        d.line([(MEDIO - 64, MEDIO - 46 + k * 14), (MEDIO - 64 + (40 + k * 23) % 120, MEDIO - 46 + k * 14)],
               fill=rgba(color), width=6)
    for fila in range(2):
        for col in range(7):
            x0 = MEDIO - 80 + col * 23
            y0 = MEDIO + 28 + fila * 24
            rect_redondo(d, x0, y0, x0 + 18, y0 + 18, 4, rgba("#4a5266"))
    return reducir(img)


def emisor_laser():
    img = nuevo()
    d = ImageDraw.Draw(img)
    for y in (MEDIO - 108, MEDIO + 108):
        rect_redondo(d, MEDIO - 24, y - 16, MEDIO + 24, y + 16, 8, rgba("#2a2f3c"), rgba("#0b0d12"), 5)
        elipse(d, MEDIO, y, 8, 8, rgba("#ff3b3b"))
    return reducir(img)


# ====================================================================== #
# Luces
# ====================================================================== #
def luz_cono(tam=512, medio_grados=38.0):
    """Cono con el vértice en el centro de la textura, apuntando a +x."""
    y, x = np.mgrid[0:tam, 0:tam].astype(float)
    dx, dy = x - tam / 2, y - tam / 2
    r = np.hypot(dx, dy) / (tam / 2)
    ang = np.degrees(np.abs(np.arctan2(dy, dx)))
    radial = np.clip(1 - r, 0, 1) ** 0.75
    borde = np.clip((medio_grados - ang) / 7.0, 0, 1)
    cerca = np.clip(r * 6, 0, 1)
    v = radial * borde * (0.35 + 0.65 * cerca)
    v = (v * 255).astype("uint8")
    return Image.fromarray(np.dstack([np.full_like(v, 255)] * 3 + [v]), "RGBA")


def luz_circulo(tam=256):
    y, x = np.mgrid[0:tam, 0:tam].astype(float)
    r = np.hypot(x - tam / 2, y - tam / 2) / (tam / 2)
    v = (np.clip(1 - r, 0, 1) ** 1.6 * 255).astype("uint8")
    return Image.fromarray(np.dstack([np.full_like(v, 255)] * 3 + [v]), "RGBA")


# ====================================================================== #
def main():
    for sub in ("sprites", "tiles", "luces"):
        os.makedirs(os.path.join(RAIZ, sub), exist_ok=True)

    hoja(FILAS_LADRON, 8, dibujar_ladron).save(os.path.join(RAIZ, "sprites", "ladron.png"))
    for v in range(len(GUARDIAS)):
        hoja(FILAS_GUARDIA, 8, lambda pose, f, n, v=v: dibujar_guardia(v, pose, f, n)).save(
            os.path.join(RAIZ, "sprites", f"guardia_{v}.png"))
    dibujar_camara().save(os.path.join(RAIZ, "sprites", "camara.png"))
    joyas = Image.new("RGBA", (64 * 3, 64), (0, 0, 0, 0))
    for i in range(3):
        joyas.paste(dibujar_joya(i), (64 * i, 0))
    joyas.save(os.path.join(RAIZ, "sprites", "joyas.png"))
    dibujar_moneda().save(os.path.join(RAIZ, "sprites", "moneda.png"))

    # hoja de casillas: el orden lo usa juego/arte.gd
    tiles = [
        piso(1, "#8f897c", "#b3ac9c", "#77726a"),       # 0 mármol claro
        piso(2, "#5a5e6b", "#7a8092", "#4a4e5a"),       # 1 mármol oscuro
        pared_superior(),                               # 2
        pared_frente(),                                 # 3
        pared_frente(0), pared_frente(1), pared_frente(2),  # 4, 5, 6 pinturas
        pedestal(),                                     # 7
        vitrina(),                                      # 8
        planta(),                                       # 9
        salida(False), salida(True),                    # 10, 11
        puerta(False), puerta(True),                    # 12, 13
        terminal(False), terminal(True),                # 14, 15
        emisor_laser(),                                 # 16
        alfombra(),                                     # 17
    ]
    museo = Image.new("RGBA", (64 * 8, 64 * 3), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        museo.paste(t, ((i % 8) * 64, (i // 8) * 64))
    museo.save(os.path.join(RAIZ, "tiles", "museo.png"))

    luz_cono().save(os.path.join(RAIZ, "luces", "cono.png"))
    luz_circulo().save(os.path.join(RAIZ, "luces", "circulo.png"))
    print("arte generado en", os.path.abspath(RAIZ))


if __name__ == "__main__":
    main()
