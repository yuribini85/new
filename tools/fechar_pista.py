#!/usr/bin/env python3
"""Fecha o traçado de uma pista ajustando o comprimento de duas retas.

Entrada: JSON com {"id", "funcao", "trechos"}, onde cada trecho é como em
data/pistas.json, mas curvas usam "angulo_graus" (positivo; o lado vem de
"sentido") em vez de "comprimento_m", e exatamente duas retas têm
"comprimento_m": null. A soma dos giros precisa dar +360° (volta anti-horária)
ou -360° (horária). Saída: a pista com todos os comprimentos, pronta para
data/pistas.json.

Uso: tools/fechar_pista.py rascunho.json > pista.json
"""
import json
import math
import sys


def fechar(pista):
    trechos = pista["trechos"]
    giro_total = 0.0
    for t in trechos:
        if "angulo_graus" in t:
            lado = -1 if t.get("sentido", "esquerda") == "direita" else 1
            giro_total += lado * t["angulo_graus"]
    if abs(abs(giro_total) - 360.0) > 1e-6:
        raise SystemExit(f"{pista['id']}: giros somam {giro_total}°, precisam somar ±360°")

    # Percorre acumulando posição; as duas retas livres viram colunas do sistema.
    x = y = rumo = 0.0
    livres = []
    for i, t in enumerate(trechos):
        if "angulo_graus" in t:
            lado = -1 if t.get("sentido", "esquerda") == "direita" else 1
            r = t["raio_m"]
            giro = lado * math.radians(t["angulo_graus"])
            cx = x + r * math.cos(rumo + lado * math.pi / 2)
            cy = y + r * math.sin(rumo + lado * math.pi / 2)
            dx, dy = x - cx, y - cy
            x = cx + dx * math.cos(giro) - dy * math.sin(giro)
            y = cy + dx * math.sin(giro) + dy * math.cos(giro)
            rumo += giro
            t["comprimento_m"] = round(r * abs(giro), 4)
        elif t.get("comprimento_m") is None:
            livres.append((i, math.cos(rumo), math.sin(rumo)))
        else:
            x += t["comprimento_m"] * math.cos(rumo)
            y += t["comprimento_m"] * math.sin(rumo)
    if len(livres) != 2:
        raise SystemExit(f"{pista['id']}: precisa de exatamente 2 retas com comprimento null")
    (i1, a1, b1), (i2, a2, b2) = livres
    det = a1 * b2 - a2 * b1
    if abs(det) < 1e-6:
        raise SystemExit(f"{pista['id']}: as duas retas livres são paralelas")
    l1 = (-x * b2 + y * a2) / det
    l2 = (-a1 * y + b1 * x) / det
    if l1 <= 0 or l2 <= 0:
        raise SystemExit(f"{pista['id']}: solução com reta negativa ({l1:.1f}, {l2:.1f}); ajuste o rascunho")
    trechos[i1]["comprimento_m"] = round(l1, 4)
    trechos[i2]["comprimento_m"] = round(l2, 4)
    for t in trechos:
        t.pop("angulo_graus", None)
    return pista


if __name__ == "__main__":
    print(json.dumps(fechar(json.load(open(sys.argv[1]))), ensure_ascii=False, indent=1))
