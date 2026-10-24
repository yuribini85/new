#!/usr/bin/env python3
"""Arenas novas (decisão 75): duas para as licenças sem arena (Club e Sport) e
quatro exclusivas dos desafios do The Grid (arena 1, 2, 3 e o confronto).
Mesmo formato das de data/arena.json (decisão 59): muro em polígono e a borda
que sobe junto ao muro. Cada forma é desenhada em unidades livres e escalada
para a área do círculo de raio_m (como as quatro originais). Confere a largada
(até 20 carros, fração largada_raio_frac) dentro do muro. O chão (relevo e
obstáculos) é de tools/terreno_arenas.py (decisão 78), que roda depois deste;
aqui ele é mantido. Formas são desenho, não balanceamento.

Grava (ou atualiza, pelo id) em data/arena.json → arenas.
Uso: python3 tools/arenas_novas.py [--checar]
"""
import json
import math
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ARQ = RAIZ / "data" / "arena.json"

# grid: só nos desafios do The Grid (o campeonato não sorteia). tema: o cenário
# em volta (visual/temas_arena.gd; só tela).
ARENAS = [
    {   # Club: um pátio de terra cercado (para aprender).
        "id": "varzea_galpao", "nome": "Várzea do Galpão", "licenca": "CLUB", "tema": "galpao",
        "muro": [[10, 0], [8.5, 5.5], [4, 8.5], [-3, 8.8], [-8.5, 5.5], [-10, -0.5], [-8, -6], [-2, -8.6],
                 [5, -7.8]],
        "borda": {"largura": 4.0, "altura": 1.2},
    },
    {   # Sport: curral hexagonal.
        "id": "curral_fardos", "nome": "Curral dos Fardos", "licenca": "SPORT", "tema": "fardos",
        "muro": [[10, 0], [5, 8.66], [-5, 8.66], [-10, 0], [-5, -8.66], [5, -8.66]],
        "borda": {"largura": 5.0, "altura": 1.5},
    },
    {   # Grid arena 1 (#8, Redline Union, sindicato de chão de fábrica): galpão
        # retangular com as docas recortadas.
        "id": "patio_fundicao", "nome": "Pátio da Fundição", "licenca": "SPORT", "grid": True, "tema": "fundicao",
        "muro": [[12, -7], [12, 7], [5, 7], [5, 5], [1, 5], [1, 7], [-12, 7], [-12, -7], [-1, -7], [-1, -5],
                 [-5, -5], [-5, -7]],
        "borda": {"largura": 5.0, "altura": 1.8},
    },
    {   # Grid arena 2 (#5, Last Exit Club): estacionamento de beira de estrada em
        # L.
        "id": "estacionamento_saida", "nome": "Estacionamento da Última Saída", "licenca": "NATIONAL", "grid": True, "tema": "estacionamento",
        "muro": [[11, -9], [11, 2], [6, 2], [3, 5], [3, 10], [-10, 10], [-10, -9]],
        "borda": {"largura": 6.0, "altura": 2.2},
    },
    {   # Grid arena 3 (#3, Blackwater Racing): bacia oval de um reservatório
        # seco.
        "id": "bacia_blackwater", "nome": "Bacia de Blackwater", "licenca": "PRO", "grid": True, "tema": "lago",
        "muro": [[round(13 * math.cos(t), 2), round(8.5 * math.sin(t), 2)]
                 for t in [2 * math.pi * k / 14 for k in range(14)]],
        "borda": {"largura": 7.0, "altura": 3.0},
    },
    {   # Confronto (#1, Hollow Saints): claustro em cruz; o muro mais alto
        # de todas.
        "id": "claustro_vazio", "nome": "Claustro Vazio", "licenca": "PRO", "grid": True, "tema": "claustro",
        "muro": [[11, -4], [11, 4], [4, 4], [4, 11], [-4, 11], [-4, 4], [-11, 4], [-11, -4], [-4, -4],
                 [-4, -11], [4, -11], [4, -4]],
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
    r = {kk: vv for kk, vv in a.items() if kk != "muro"}
    r["muro"] = [[s(x), s(y)] for x, y in a["muro"]]
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
    return erros


def main():
    dados = json.loads(ARQ.read_text(encoding="utf-8"))
    raio = float(dados["raio_m"])
    frac = float(dados["largada_raio_frac"])
    ids = {a["id"]: a for a in dados["arenas"]}
    novas = [escalar(a, raio) for a in ARENAS]
    for a in novas:  # o chão fica com tools/terreno_arenas.py
        a["obstaculos"] = ids.get(a["id"], {}).get("obstaculos", [])
        a["relevo"] = ids.get(a["id"], {}).get("relevo", [])
    erros = [e for a in novas for e in checar(a, raio, frac)]
    if erros:
        print("\n".join(sorted(set(erros))))
        sys.exit(1)
    if "--checar" in sys.argv:
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
