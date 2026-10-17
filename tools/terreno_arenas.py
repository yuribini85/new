#!/usr/bin/env python3
"""Terreno das arenas (decisão 78, pedido do usuário): o que diferencia uma arena
é o chão, desenhado como curvas de nível (rampas, valas, platôs em degraus,
poços), não o contorno nem ilhas de pneus. Mesmos termos de sim/arena_forma.gd:

  monte  {c, r, h}                       gaussiana (h<0: cratera)
  vala   {tipo, a, b, largura, fundo, h}  ao longo de a→b, fundo plano (h>0: dique)
  rampa  {tipo, a, b, largura, h, queda}  sobe de a (0) até h em b e cai em queda m
  plato  {tipo, c+r | pontos, encosta, h} topo plano (h<0: poço)
  max: true  assenta por cima em vez de somar (a rampa que leva ao platô; os
             trechos de uma vala em anel não afundam a emenda)

Coordenadas em metros, no sistema já escalado de data/arena.json (muro de
tools/arenas_novas.py e das quatro originais). Alturas e formas são desenho,
não balanceamento; ajustar no playtest.

Confere: largadas (até 20 carros) em chão quase plano e fora das ilhas; a
inclinação máxima dentro do muro. Grava relevo e obstáculos em data/arena.json.
Uso: python3 tools/terreno_arenas.py [--checar] [--previa DIR]
"""
import json
import math
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ARQ = RAIZ / "data" / "arena.json"

INCLINACAO_LARGADA = 0.2  # tg do ângulo do chão onde um carro larga
INCLINACAO_MAX = 0.85  # tg (≈40°), onde dois termos se encostam; cada um sozinho fica em 0,6
# Suavização (pedido do usuário: "desníveis muito íngremes"): alturas × ESCALA_H
# e cada encosta com pelo menos ENCOSTA_POR_M m de largura por m de desnível
# (a encosta em smoothstep inclina no máximo 1,5/2,5 = 0,6 ≈ 31°); rampa no
# máximo RAMPA_MAX de subida.
ESCALA_H = 0.7
ENCOSTA_POR_M = 2.5
RAMPA_MAX = 0.3


def elipse(cx, cy, rx, ry, n=20, giro=0.0):
    return [[round(cx + rx * math.cos(2 * math.pi * k / n) * math.cos(giro) - ry * math.sin(2 * math.pi * k / n) * math.sin(giro), 2),
             round(cy + rx * math.cos(2 * math.pi * k / n) * math.sin(giro) + ry * math.sin(2 * math.pi * k / n) * math.cos(giro), 2)]
            for k in range(n)]


def ret(x0, x1, y0, y1):
    return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]


def polar(r, graus):
    return [round(r * math.cos(math.radians(graus)), 2), round(r * math.sin(math.radians(graus)), 2)]


def anel_de_valas(r, n, pular, largura, fundo, h):
    """Vala em anel de raio r, em n trechos, sem os de índice em `pular` (passagens)."""
    return [{"tipo": "vala", "a": polar(r, 360 * k / n), "b": polar(r, 360 * (k + 1) / n),
             "largura": largura, "fundo": fundo, "h": h, "max": True} for k in range(n) if k not in pular]


TERRENO = {
    # Club: a várzea para aprender. Uma vala de drenagem rasa na diagonal (com
    # passagem no meio) e duas rampinhas viradas para o centro.
    "varzea_galpao": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "vala", "a": [-24, -19], "b": [-5, -4], "largura": 7, "fundo": 2, "h": -1.3},
            {"tipo": "vala", "a": [5, 4], "b": [24, 19], "largura": 7, "fundo": 2, "h": -1.3},
            {"tipo": "rampa", "a": [-26, 18], "b": [-17, 11], "largura": 7, "h": 1.4, "queda": 3},
            {"tipo": "rampa", "a": [26, -18], "b": [17, -11], "largura": 7, "h": 1.4, "queda": 3},
        ],
    },
    # Sport: o curral cortado em X por duas valas que se cruzam no meio; rampas nos dois quadrantes de cima e de baixo saltam para ele.
    "curral_fardos": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "vala", "a": [-26, -15], "b": [26, 15], "largura": 8, "fundo": 3, "h": -1.5, "max": True},
            {"tipo": "vala", "a": [-26, 15], "b": [26, -15], "largura": 8, "fundo": 3, "h": -1.5, "max": True},
            {"tipo": "rampa", "a": [0, 30], "b": [0, 19], "largura": 8, "h": 1.8, "queda": 3},
            {"tipo": "rampa", "a": [0, -30], "b": [0, -19], "largura": 8, "h": 1.8, "queda": 3},
        ],
    },
    # National: a pedreira em bancadas, três degraus descendo para o canto
    # sudeste; montes de entulho do outro lado e uma rampa na beira do corte.
    "patio_pedreira": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "pontos": elipse(4, -4, 26, 20, giro=-0.5), "encosta": 4, "h": -2.2},
            {"tipo": "plato", "pontos": elipse(8, -8, 16, 12, giro=-0.5), "encosta": 3.5, "h": -2.2},
            {"tipo": "plato", "pontos": elipse(11, -11, 7, 5, giro=-0.5), "encosta": 3, "h": -2.2},
            {"c": [-22, 22], "r": 12, "h": 2.4},
            {"c": [-32, -6], "r": 9, "h": 1.8},
            {"tipo": "rampa", "a": [-24, 7], "b": [-15, 3], "largura": 8, "h": 1.6, "queda": 3},
        ],
    },
    # International: o fosso do cais corta a arena de leste a oeste, com duas
    # passagens; um cais alto no nordeste com rampa e uma rampa de salto no sul.
    "fosso_docas": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "vala", "a": [-38, 0], "b": [-16, 0], "largura": 10, "fundo": 4, "h": -2.6},
            {"tipo": "vala", "a": [-5, 0], "b": [5, 0], "largura": 10, "fundo": 4, "h": -2.6},
            {"tipo": "vala", "a": [16, 0], "b": [38, 0], "largura": 10, "fundo": 4, "h": -2.6},
            {"tipo": "plato", "pontos": ret(26, 44, 12, 24), "encosta": 3, "h": 2.0, "max": True},
            {"tipo": "rampa", "a": [12, 18], "b": [26, 18], "largura": 8, "h": 2.0, "max": True},
            {"tipo": "rampa", "a": [-24, -20], "b": [-24, -10], "largura": 7, "h": 1.8, "queda": 2.5},
        ],
    },
    # Pro: o monte de sucata no meio (a ilha), cercado por um anel de vala com
    # três passagens e três rampas tangentes por fora.
    "anel_ferro_velho": {
        "obstaculos": [{"c": [0, 0], "r": 8}],
        "relevo": [
            {"tipo": "plato", "c": [0, 0], "r": 11, "encosta": 5, "h": 1.8},
            *anel_de_valas(20.5, 12, {0, 4, 8}, 7, 2, -1.8),
            *[{"tipo": "rampa", "a": polar(30.5, g - 15), "b": polar(30.5, g + 1), "largura": 4, "h": 1.7, "queda": 3}
              for g in (60, 180, 300)],
        ],
    },
    # Elite: a mesa no meio com a caldeira em cima; três rampas sobem até a
    # beira e três ravinas descem entre elas.
    "cratera_vale": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "c": [-2, 0], "r": 15, "encosta": 6, "h": 4.0},
            {"tipo": "plato", "c": [-2, 0], "r": 6, "encosta": 3.5, "h": -3.4},
            *[{"tipo": "rampa", "a": [round(-2 + 29 * math.cos(math.radians(g)), 2), round(29 * math.sin(math.radians(g)), 2)],
               "b": [round(-2 + 17 * math.cos(math.radians(g)), 2), round(17 * math.sin(math.radians(g)), 2)],
               "largura": 9, "h": 4.0, "max": True} for g in (0, 150, 240)],
            *[{"tipo": "vala", "a": [round(-2 + 26 * math.cos(math.radians(g)), 2), round(26 * math.sin(math.radians(g)), 2)],
               "b": [round(-2 + 30 * math.cos(math.radians(g)), 2), round(30 * math.sin(math.radians(g)), 2)],
               "largura": 8, "fundo": 2, "h": -2.4} for g in (60, 180, 300)],
        ],
    },
    # Grid #8 (Redline Union): a plataforma de carga alta a oeste com rampa,
    # dois poços de fundição desencontrados e um dique baixo entre eles.
    "patio_fundicao": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "pontos": ret(-38, -24, -11, 11), "encosta": 3, "h": 2.2, "max": True},
            {"tipo": "rampa", "a": [-10, 0], "b": [-24, 0], "largura": 8, "h": 2.2, "max": True},
            {"tipo": "plato", "pontos": ret(4, 16, -13, 1), "encosta": 2.5, "h": -2.0},
            {"tipo": "plato", "pontos": ret(28, 40, -1, 13), "encosta": 2.5, "h": -2.0},
            {"tipo": "vala", "a": [22, -12], "b": [22, 12], "largura": 4, "fundo": 1, "h": 1.0},
        ],
    },
    # Grid #5 (Last Exit Club): estacionamento em dois andares no noroeste,
    # com rampa do chão ao primeiro e do primeiro ao segundo; na ala leste a
    # rampa de saída e a doca rebaixada.
    "estacionamento_saida": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "pontos": ret(-26, -4, 6, 29), "encosta": 3, "h": 2.4, "max": True},
            {"tipo": "plato", "pontos": ret(-24, -15, 19, 27), "encosta": 6, "h": 4.6, "max": True},
            {"tipo": "rampa", "a": [-17, -10], "b": [-17, 6], "largura": 8, "h": 2.4, "max": True},
            {"tipo": "rampa", "a": [-2, 23], "b": [-15, 23], "largura": 6, "h": 4.6, "max": True},
            {"tipo": "rampa", "a": [40, -2], "b": [28, -2], "largura": 8, "h": 2.0, "queda": 3.5},
            {"tipo": "plato", "pontos": ret(16, 30, -24, -14), "encosta": 2.5, "h": -1.8},
        ],
    },
    # Grid #3 (Blackwater Racing): o reservatório seco em três degraus até o
    # fundo, o canal do vertedouro cortando os degraus e duas rampas na
    # primeira bancada saltando para dentro.
    "bacia_blackwater": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "pontos": elipse(0, 0, 38, 22), "encosta": 4, "h": -2.0},
            {"tipo": "plato", "pontos": elipse(0, 0, 25, 14), "encosta": 3.5, "h": -2.0},
            {"tipo": "plato", "pontos": elipse(0, 0, 12, 6.5), "encosta": 3, "h": -2.0},
            {"tipo": "vala", "a": [12, 7], "b": [29, 19], "largura": 9, "fundo": 2.5, "h": -2.2, "max": True},
            {"tipo": "rampa", "a": [-35, 0], "b": [-31.5, 0], "largura": 7, "h": 1.3, "queda": 3},
            {"tipo": "rampa", "a": [35, -6], "b": [31.5, -5.5], "largura": 7, "h": 1.3, "queda": 3},
        ],
    },
    # Grid #1 (Hollow Saints, o confronto): o altar é um platô alto no meio do
    # claustro, com rampas pelos braços leste e oeste; os braços norte e sul
    # têm um fosso atravessado e uma cripta rebaixada no fundo.
    "claustro_vazio": {
        "obstaculos": [],
        "relevo": [
            {"tipo": "plato", "c": [0, 0], "r": 7, "encosta": 4, "h": 2.8, "max": True},
            {"tipo": "rampa", "a": [22, 0], "b": [7, 0], "largura": 8, "h": 2.8, "max": True},
            {"tipo": "rampa", "a": [-22, 0], "b": [-7, 0], "largura": 8, "h": 2.8, "max": True},
            {"tipo": "vala", "a": [-22, 29], "b": [22, 29], "largura": 8, "fundo": 3, "h": -2.4},
            {"tipo": "vala", "a": [-22, -29], "b": [22, -29], "largura": 8, "fundo": 3, "h": -2.4},
            {"tipo": "plato", "pontos": ret(-10, 10, 14, 22), "encosta": 2.5, "h": -1.4},
            {"tipo": "plato", "pontos": ret(-10, 10, -22, -14), "encosta": 2.5, "h": -1.4},
        ],
    },
}


# --- Mesma conta de sim/arena_forma.gd --------------------------------------------

def smooth(a, b, x):
    if b == a:
        return 0.0 if x < a else 1.0
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else min(max(((p[0] - ax) * dx + (p[1] - ay) * dy) / l2, 0.0), 1.0)
    return math.hypot(p[0] - ax - t * dx, p[1] - ay - t * dy)


def dentro(p, pts):
    x, y = p
    d = False
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            d = not d
    return d


def termo(t, p):
    h = t["h"]
    tipo = t.get("tipo", "monte")
    if tipo == "vala":
        d = seg_dist(p, t["a"], t["b"])
        meia, mf = t["largura"] / 2, t.get("fundo", 0) / 2
        return h * (1 - smooth(0, 1, min(max((d - mf) / max(meia - mf, 0.01), 0), 1)))
    if tipo == "rampa":
        ax, ay = t["a"]
        ex, ey = t["b"][0] - ax, t["b"][1] - ay
        comp = math.hypot(ex, ey)
        dx, dy = ex / comp, ey / comp
        u = (p[0] - ax) * dx + (p[1] - ay) * dy
        v = abs((p[0] - ax) * -dy + (p[1] - ay) * dx)
        queda = t.get("queda", 3.0)
        lon = 0.0
        if 0 <= u <= comp:
            lon = u / comp
        elif comp < u < comp + queda:
            lon = 1 - smooth(0, queda, u - comp)
        meia = t["largura"] / 2
        return h * lon * (1 - smooth(meia, meia + t.get("encosta", max(1.5, abs(h) * 1.2)), v))
    if tipo == "plato":
        if "pontos" in t:
            pts = t["pontos"]
            d = 0.0 if dentro(p, pts) else min(seg_dist(p, pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts)))
        else:
            d = max(math.dist(p, t["c"]) - t["r"], 0.0)
        return h * (1 - smooth(0, t.get("encosta", 3.0), d))
    s = t["r"] * 0.5
    return h * math.exp(-((p[0] - t["c"][0]) ** 2 + (p[1] - t["c"][1]) ** 2) / (2 * s * s))


def muro_dist(p, muro):
    d = min(seg_dist(p, muro[i], muro[(i + 1) % len(muro)]) for i in range(len(muro)))
    return d if dentro(p, muro) else -d


def altura(a, p, borda=True):
    h = sum(termo(t, p) for t in a["relevo"] if not t.get("max"))
    for t in a["relevo"]:
        if t.get("max"):
            v = termo(t, p)
            peso = min(abs(v) / (0.3 * abs(t["h"])), 1.0)
            h += ((max(h, v) if t["h"] > 0 else min(h, v)) - h) * peso
    b = a.get("borda", {})
    if borda and b.get("largura", 0) > 0:
        h += b["altura"] * (1 - smooth(0, b["largura"], max(muro_dist(p, a["muro"]), 0)))
    return h


def gradiente(a, p, e=0.5, borda=True):
    return ((altura(a, (p[0] + e, p[1]), borda) - altura(a, (p[0] - e, p[1]), borda)) / (2 * e),
            (altura(a, (p[0], p[1] + e), borda) - altura(a, (p[0], p[1] - e), borda)) / (2 * e))


def centro(pts):
    return [sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)]


def largada(pts, ang, frac):
    c = centro(pts)
    dx, dy = math.cos(ang), math.sin(ang)
    longe = math.inf
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        ex, ey = x2 - x1, y2 - y1
        den = dx * ey - dy * ex
        if abs(den) < 1e-12:
            continue
        t = ((x1 - c[0]) * ey - (y1 - c[1]) * ex) / den
        u = ((x1 - c[0]) * dy - (y1 - c[1]) * dx) / den
        if t >= 0 and 0 <= u <= 1:
            longe = min(longe, t)
    return [c[0] + dx * longe * frac, c[1] + dy * longe * frac]


def caixa(muro):
    xs = [p[0] for p in muro]
    ys = [p[1] for p in muro]
    return min(xs), max(xs), min(ys), max(ys)


def checar(a, frac):
    erros = []
    for n in (4, 8, 12, 16, 20):
        for k in range(n):
            q = largada(a["muro"], 2 * math.pi * k / n, frac)
            # A borda junto ao muro já inclina a largada (decisão 59); conta o resto.
            g = math.hypot(*gradiente(a, q, borda=False))
            if g > INCLINACAO_LARGADA:
                erros.append(f"{a['id']}: largada {k}/{n} em {[round(v, 1) for v in q]} no declive {g:.2f}")
            for o in a["obstaculos"]:
                if math.dist(q, o["c"]) - o["r"] < 2.5:
                    erros.append(f"{a['id']}: largada {k}/{n} em cima da ilha {o['c']}")
    for o in a["obstaculos"]:
        if not dentro(o["c"], a["muro"]):
            erros.append(f"{a['id']}: ilha {o['c']} fora do muro")
    x0, x1, y0, y1 = caixa(a["muro"])
    pior = 0.0
    y = y0
    while y <= y1:
        x = x0
        while x <= x1:
            if muro_dist((x, y), a["muro"]) > 1.0:
                pior = max(pior, math.hypot(*gradiente(a, (x, y), borda=False)))
            x += 1.0
        y += 1.0
    if pior > INCLINACAO_MAX:
        erros.append(f"{a['id']}: inclinação {pior:.2f} (máx. {INCLINACAO_MAX})")
    return erros, pior


def previa(a, frac, caminho, px_m=4):
    """Mapa de cima: relevo sombreado com curvas de nível de 0,5 m, muro e largadas."""
    from PIL import Image, ImageDraw
    x0, x1, y0, y1 = caixa(a["muro"])
    x0, x1, y0, y1 = x0 - 3, x1 + 3, y0 - 3, y1 + 3
    w, h = int((x1 - x0) * px_m), int((y1 - y0) * px_m)
    passo = 1.0 / px_m * 2
    alt = {}
    for j in range(0, h, 2):
        for i in range(0, w, 2):
            p = (x0 + i / px_m, y1 - j / px_m)
            alt[(i, j)] = altura(a, p) if muro_dist(p, a["muro"]) > -0.5 else None
    img = Image.new("RGB", (w, h), (30, 30, 34))
    pix = img.load()
    for (i, j), v in alt.items():
        if v is None:
            continue
        vx = alt.get((i + 2, j)) if alt.get((i + 2, j)) is not None else v
        vy = alt.get((i, j + 2)) if alt.get((i, j + 2)) is not None else v
        luz = 0.75 + 1.6 * ((v - vx) * 0.7 + (vy - v) * 0.7) / passo * 0.3
        t = min(max((v + 6) / 12, 0), 1)
        base = (int(90 + 120 * t), int(70 + 90 * t), int(50 + 50 * t))
        cor = tuple(min(max(int(c * luz), 0), 255) for c in base)
        if math.floor(v * 2) != math.floor(vx * 2) or math.floor(v * 2) != math.floor(vy * 2):
            cor = (20, 20, 20)
        for di in range(2):
            for dj in range(2):
                if i + di < w and j + dj < h:
                    pix[i + di, j + dj] = cor
    d = ImageDraw.Draw(img)
    tela = lambda q: ((q[0] - x0) * px_m, (y1 - q[1]) * px_m)
    d.polygon([tela(q) for q in a["muro"]], outline=(230, 60, 40))
    for o in a["obstaculos"]:
        cx, cy = tela(o["c"])
        r = o["r"] * px_m
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(240, 240, 240), width=2)
    for k in range(20):
        cx, cy = tela(largada(a["muro"], 2 * math.pi * k / 20, frac))
        d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(80, 200, 255))
    d.text((6, 4), f"{a['nome']} ({a['licenca']}{' · Grid' if a.get('grid') else ''})", fill=(255, 255, 255))
    img.save(caminho)


def suavizar(t):
    t = dict(t)
    t["h"] = round(t["h"] * ESCALA_H, 2)
    h = abs(t["h"])
    tipo = t.get("tipo", "monte")
    if tipo == "plato":
        t["encosta"] = round(max(t.get("encosta", 3.0), ENCOSTA_POR_M * h), 2)
    elif tipo == "vala":
        if (t["largura"] - t.get("fundo", 0)) / 2 < ENCOSTA_POR_M * h:
            t["largura"] = round(t.get("fundo", 0) + 2 * ENCOSTA_POR_M * h, 2)
    elif tipo == "rampa":
        t["encosta"] = round(max(t.get("encosta", 1.5), ENCOSTA_POR_M * h), 2)
        t["queda"] = round(max(t.get("queda", 3.0), ENCOSTA_POR_M * h), 2)
        ax, ay = t["a"]
        bx, by = t["b"]
        comp = math.hypot(bx - ax, by - ay)
        if h / comp > RAMPA_MAX:
            k = h / RAMPA_MAX / comp
            t["a"] = [round(bx - (bx - ax) * k, 2), round(by - (by - ay) * k, 2)]
    else:
        t["r"] = round(max(t["r"], 2 * h), 2)
    return t


def main():
    dados = json.loads(ARQ.read_text(encoding="utf-8"))
    frac = float(dados["largada_raio_frac"])
    por_id = {a["id"]: a for a in dados["arenas"]}
    faltam = set(por_id) - set(TERRENO)
    if faltam:
        print("arenas sem terreno:", ", ".join(sorted(faltam)))
        sys.exit(1)
    novas = {}
    erros = []
    for id_, t in TERRENO.items():
        a = dict(por_id[id_])
        a["obstaculos"] = t["obstaculos"]
        a["relevo"] = [suavizar(x) for x in t["relevo"]]
        novas[id_] = a
        e, pior = checar(a, frac)
        erros += e
        print(f"{id_:22s} {len(t['relevo']):2d} termos  inclinação máx. {pior:.2f}")
    if "--previa" in sys.argv:
        pasta = Path(sys.argv[sys.argv.index("--previa") + 1])
        pasta.mkdir(parents=True, exist_ok=True)
        for a in novas.values():
            previa(a, frac, pasta / f"{a['id']}.png")
    if erros:
        print("\n".join(erros))
        sys.exit(1)
    if "--checar" in sys.argv:
        dif = [i for i, a in novas.items() if por_id[i] != a]
        if dif:
            print("arena.json desatualizado:", ", ".join(dif))
            sys.exit(1)
        print("ok")
        return
    dados["arenas"] = [novas[a["id"]] for a in dados["arenas"]]
    ARQ.write_text(json.dumps(dados, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
