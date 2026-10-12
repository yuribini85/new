#!/usr/bin/env python3
"""Arenas novas (decisão 75): duas para as licenças sem arena (Club e Sport) e
quatro exclusivas dos desafios do The Grid (arena 1, 2, 3 e o confronto).
Mesmo formato das de data/arena.json (decisão 59): muro em polígono, obstáculos
(ilhas: c, r), relevo (lombada h>0, cratera h<0, gaussiana de raio r) e a borda
que sobe junto ao muro. Cada forma é desenhada em unidades livres e escalada
para a área do círculo de raio_m (como as quatro originais); obstáculos e relevo
escalam junto, alturas não. Confere a largada (até 20 carros, fração
largada_raio_frac): dentro do muro e com folga dos obstáculos.
Alturas e formas são desenho, não balanceamento.

Grava (ou atualiza, pelo id) em data/arena.json → arenas.
Uso: python3 tools/arenas_novas.py [--checar]
"""
import json
import math
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ARQ = RAIZ / "data" / "arena.json"

# grid: só nos desafios do The Grid (o campeonato não sorteia).
ARENAS = [
    {   # Club: um pátio de terra cercado, quase plano, sem ilhas (para aprender).
        "id": "varzea_galpao", "nome": "Várzea do Galpão", "licenca": "CLUB",
        "muro": [[10, 0], [8.5, 5.5], [4, 8.5], [-3, 8.8], [-8.5, 5.5], [-10, -0.5], [-8, -6], [-2, -8.6],
                 [5, -7.8]],
        "obstaculos": [],
        "relevo": [{"c": [0, 0], "r": 9, "h": -1.6}, {"c": [5.5, 3.5], "r": 3.5, "h": 0.9}],
        "borda": {"largura": 4.0, "altura": 1.2},
    },
    {   # Sport: curral hexagonal com dois fardos no meio e lombadas leves.
        "id": "curral_fardos", "nome": "Curral dos Fardos", "licenca": "SPORT",
        "muro": [[10, 0], [5, 8.66], [-5, 8.66], [-10, 0], [-5, -8.66], [5, -8.66]],
        "obstaculos": [{"c": [-3.2, 1.2], "r": 0.75}, {"c": [3.2, -1.2], "r": 0.75}],
        "relevo": [{"c": [0, 5], "r": 3.6, "h": 1.4}, {"c": [0, -5], "r": 3.6, "h": 1.4},
                   {"c": [0, 0], "r": 4.5, "h": -1.2}],
        "borda": {"largura": 5.0, "altura": 1.5},
    },
    {   # Grid arena 1 (#8, Redline Union, sindicato de chão de fábrica): galpão
        # retangular com as docas recortadas e três pilhas de lingotes em linha.
        "id": "patio_fundicao", "nome": "Pátio da Fundição", "licenca": "SPORT", "grid": True,
        "muro": [[12, -7], [12, 7], [5, 7], [5, 5], [1, 5], [1, 7], [-12, 7], [-12, -7], [-1, -7], [-1, -5],
                 [-5, -5], [-5, -7]],
        "obstaculos": [{"c": [-6, 0], "r": 0.9}, {"c": [0, 0], "r": 0.9}, {"c": [6, 0], "r": 0.9}],
        "relevo": [{"c": [-3, 3], "r": 3.0, "h": 1.6}, {"c": [3, -3], "r": 3.0, "h": 1.6},
                   {"c": [9, 4], "r": 3.5, "h": -1.8}, {"c": [-9, -4], "r": 3.5, "h": -1.8}],
        "borda": {"largura": 5.0, "altura": 1.8},
    },
    {   # Grid arena 2 (#5, Last Exit Club): estacionamento de beira de estrada em
        # L, quatro colunas e as rampas de acesso.
        "id": "estacionamento_saida", "nome": "Estacionamento da Última Saída", "licenca": "NATIONAL", "grid": True,
        "muro": [[11, -9], [11, 2], [6, 2], [3, 5], [3, 10], [-10, 10], [-10, -9]],
        "obstaculos": [{"c": [-4, 4.5], "r": 0.7}, {"c": [-4, -3.5], "r": 0.7}, {"c": [3, -3.5], "r": 0.7},
                       {"c": [-0.5, 0.5], "r": 0.7}],
        "relevo": [{"c": [8, -6], "r": 4.0, "h": 2.3}, {"c": [-7, 7.5], "r": 4.0, "h": 2.3},
                   {"c": [0, -6.5], "r": 3.5, "h": -1.6}, {"c": [-7, -1], "r": 3.0, "h": 1.2}],
        "borda": {"largura": 6.0, "altura": 2.2},
    },
    {   # Grid arena 3 (#3, Blackwater Racing): bacia oval de um reservatório
        # seco, o fundo puxa a briga para o meio e um anel de lombadas em volta.
        "id": "bacia_blackwater", "nome": "Bacia de Blackwater", "licenca": "PRO", "grid": True,
        "muro": [[round(13 * math.cos(t), 2), round(8.5 * math.sin(t), 2)]
                 for t in [2 * math.pi * k / 14 for k in range(14)]],
        "obstaculos": [{"c": [-7.5, 0], "r": 0.8}, {"c": [7.5, 0], "r": 0.8}],
        "relevo": [{"c": [0, 0], "r": 10.0, "h": -6.0}] +
                  [{"c": [round(8.5 * math.cos(t), 2), round(5.5 * math.sin(t), 2)], "r": 2.6, "h": 1.7}
                   for t in [math.pi / 4 + math.pi / 2 * k for k in range(4)]],
        "borda": {"largura": 7.0, "altura": 3.0},
    },
    {   # Confronto (#1, Hollow Saints): claustro em cruz, o altar de pedra no
        # meio e uma cratera em cada braço; o muro mais alto de todas.
        "id": "claustro_vazio", "nome": "Claustro Vazio", "licenca": "PRO", "grid": True,
        "muro": [[11, -4], [11, 4], [4, 4], [4, 11], [-4, 11], [-4, 4], [-11, 4], [-11, -4], [-4, -4],
                 [-4, -11], [4, -11], [4, -4]],
        "obstaculos": [{"c": [0, 0], "r": 1.6}],
        "relevo": [{"c": [7.5, 0], "r": 3.5, "h": -2.6}, {"c": [-7.5, 0], "r": 3.5, "h": -2.6},
                   {"c": [0, 7.5], "r": 3.5, "h": -2.6}, {"c": [0, -7.5], "r": 3.5, "h": -2.6},
                   {"c": [0, 0], "r": 7.0, "h": 2.4}],
        "borda": {"largura": 8.0, "altura": 3.4},
    },
]


def area(pts):
    return abs(sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                   for i in range(len(pts)))) / 2


def centro(pts):
    return [sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)]


def dentro(p, pts):
    x, y = p
    d = False
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            d = not d
    return d


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


def escalar(a, raio):
    k = math.sqrt(math.pi * raio * raio / area(a["muro"]))
    s = lambda v: round(v * k, 2)
    r = {kk: vv for kk, vv in a.items() if kk not in ("muro", "obstaculos", "relevo")}
    r["muro"] = [[s(x), s(y)] for x, y in a["muro"]]
    r["obstaculos"] = [{"c": [s(o["c"][0]), s(o["c"][1])], "r": s(o["r"])} for o in a["obstaculos"]]
    r["relevo"] = [{"c": [s(o["c"][0]), s(o["c"][1])], "r": s(o["r"]), "h": o["h"]} for o in a["relevo"]]
    return r


def checar(a, raio, frac, n_max=20):
    erros = []
    alvo = math.pi * raio * raio
    if abs(area(a["muro"]) - alvo) > alvo * 0.01:
        erros.append(f"{a['id']}: área {area(a['muro']):.0f} m² (alvo {alvo:.0f})")
    for n in (4, 8, 12, 16, n_max):
        for k in range(n):
            q = largada(a["muro"], 2 * math.pi * k / n, frac)
            if not dentro(q, a["muro"]):
                erros.append(f"{a['id']}: largada {k}/{n} fora do muro")
            for o in a["obstaculos"]:
                if math.dist(q, o["c"]) - o["r"] < 2.5:
                    erros.append(f"{a['id']}: largada {k}/{n} em cima da ilha {o['c']}")
    for o in a["obstaculos"]:
        if not dentro(o["c"], a["muro"]):
            erros.append(f"{a['id']}: ilha {o['c']} fora do muro")
    return erros


def main():
    dados = json.loads(ARQ.read_text(encoding="utf-8"))
    raio = float(dados["raio_m"])
    frac = float(dados["largada_raio_frac"])
    novas = [escalar(a, raio) for a in ARENAS]
    erros = [e for a in novas for e in checar(a, raio, frac)]
    if erros:
        print("\n".join(sorted(set(erros))))
        sys.exit(1)
    if "--checar" in sys.argv:
        ids = {a["id"]: a for a in dados["arenas"]}
        dif = [a["id"] for a in novas if ids.get(a["id"]) != a]
        if dif:
            print("arena.json desatualizado:", ", ".join(dif))
            sys.exit(1)
        print("ok")
        return
    por_id = {a["id"]: a for a in novas}
    dados["arenas"] = [por_id.pop(a["id"], a) for a in dados["arenas"]] + list(por_id.values())
    ARQ.write_text(json.dumps(dados, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for a in novas:
        print(f"{a['id']:22s} {a['licenca']:13s} {'grid' if a.get('grid') else 'campeonato':10s} área {area(a['muro']):.0f} m²")


if __name__ == "__main__":
    main()
