#!/usr/bin/env python3
"""Gera arte/carros/cores.json: as cores de fábrica de cada modelo (como no GT2, a
escolha é na compra; sem pintura livre depois).

As cores do GT2 ficam nas paletas do modelo 3D de cada carro (não há tabela no
disco que o extrator leia), então a paleta é própria, por época e categoria:
  - a primeira cor de cada modelo é a de fábrica do manifesto (arte/carros/manifesto.json);
  - as outras saem da lista da época (ano do carro; sem ano, anos 90) e da
    categoria, embaralhadas pela família (fabricante + modelo): versões da mesma
    família têm as mesmas opções;
  - quantidade: a de cores diferentes do modelo nos usados do GT2
    (referencia/gt2/usados.csv), entre MIN_CORES e MAX_CORES; sem dado, PADRAO_CORES;
  - versão de corrida: cores fortes de equipe, até MAX_CORRIDA.
Toda paleta tem ao menos um neutro (branco, prata ou preto).

Uso: python3 tools/gerar_cores.py
"""
from __future__ import annotations

import collections
import csv
import hashlib
import json
import pathlib
import random

RAIZ = pathlib.Path(__file__).resolve().parent.parent
MANIFESTO = RAIZ / "arte/carros/manifesto.json"
CARROS = RAIZ / "data/carros.json"
REF = RAIZ / "referencia/carros.csv"
USADOS = RAIZ / "referencia/gt2/usados.csv"
SAIDA = RAIZ / "arte/carros/cores.json"

MIN_CORES, MAX_CORES, PADRAO_CORES, MAX_CORRIDA = 4, 7, 5, 4

PALETA = {
    "branco": "#f2f2ee", "branco_perola": "#ece8dc", "prata": "#b8bcc2", "cinza_claro": "#9aa0a6",
    "chumbo": "#5a5f66", "grafite": "#4a4f57", "preto": "#141518",
    "vermelho": "#c8102e", "vermelho_classico": "#b3261e", "vinho": "#6e1423", "bordo": "#5a1a24",
    "azul_escuro": "#1d2f5c", "azul_meia_noite": "#18223f", "azul": "#1d4f9c", "azul_perolado": "#2f5f9e",
    "celeste": "#7fb2dd", "turquesa": "#1f7a7a",
    "verde_ingles": "#1f4d34", "verde_escuro": "#1f6b3a", "verde_claro": "#7bb26a",
    "amarelo": "#f2c300", "mostarda": "#c9a227", "laranja": "#e8601c", "creme": "#e9dfc4",
    "champanhe": "#c9b48a", "marrom": "#5e4030", "roxo": "#5b2a86",
}
NOMES = {
    "branco": "Branco", "branco_perola": "Branco pérola", "prata": "Prata", "cinza_claro": "Cinza-claro",
    "chumbo": "Chumbo", "grafite": "Grafite", "preto": "Preto", "vermelho": "Vermelho",
    "vermelho_classico": "Vermelho clássico", "vinho": "Vinho", "bordo": "Bordô", "azul_escuro": "Azul-escuro",
    "azul_meia_noite": "Azul meia-noite", "azul": "Azul", "azul_perolado": "Azul perolado", "celeste": "Celeste",
    "turquesa": "Turquesa", "verde_ingles": "Verde inglês", "verde_escuro": "Verde-escuro",
    "verde_claro": "Verde-claro", "amarelo": "Amarelo", "mostarda": "Mostarda", "laranja": "Laranja",
    "creme": "Creme", "champanhe": "Champanhe", "marrom": "Marrom", "roxo": "Roxo",
}
NEUTROS = ["branco", "prata", "preto"]
# Cor do manifesto (em inglês, para o agente de imagem) -> cor da paleta.
DO_MANIFESTO = {
    "dark blue": "azul_escuro", "teal": "turquesa", "silver grey": "prata", "pale sky blue": "celeste",
    "white": "branco", "deep red": "vermelho", "orange": "laranja", "black": "preto", "dark green": "verde_escuro",
    "cream": "creme", "pearl white": "branco_perola", "racing green": "verde_ingles", "champagne gold": "champanhe",
    "burgundy": "vinho", "midnight blue": "azul_meia_noite", "maroon": "bordo", "bright yellow": "amarelo",
    "light grey": "cinza_claro", "graphite": "grafite", "metallic gunmetal": "chumbo",
    "green and white (no text)": "verde_escuro", "silver with orange panels (no text)": "prata",
    "red and black blocks (no text)": "vermelho", "yellow with black accents (no text)": "amarelo",
    "two-tone blue and white (no text)": "azul", "white with a single bold colour band (no text)": "branco",
    "bright red": "vermelho", "deep green": "verde_escuro", "dark grey metallic": "grafite", "yellow": "amarelo",
    "silver": "prata", "dark green metallic": "verde_ingles", "gunmetal grey": "chumbo", "medium blue": "azul",
    "silver blue": "azul_perolado", "light green": "verde_claro", "purple": "roxo",
}
EPOCA = {
    1960: ["branco", "creme", "vermelho_classico", "verde_ingles", "celeste", "mostarda", "prata", "preto", "marrom"],
    1970: ["branco", "laranja", "mostarda", "marrom", "verde_escuro", "vermelho_classico", "celeste", "preto", "prata"],
    1980: ["branco", "prata", "grafite", "preto", "vermelho", "azul_escuro", "vinho", "champanhe", "cinza_claro"],
    1990: ["branco", "branco_perola", "prata", "preto", "vermelho", "azul_perolado", "amarelo", "verde_escuro",
           "roxo", "celeste", "vinho", "azul_meia_noite", "turquesa", "grafite"],
}
CATEGORIA = {
    "compacto": ["amarelo", "celeste", "vermelho", "verde_claro"],
    "seda": ["azul_meia_noite", "vinho", "chumbo", "champanhe"],
    "cupe": ["vermelho", "amarelo", "azul", "preto"],
    "roadster": ["vermelho_classico", "verde_ingles", "azul", "creme"],
}
CORRIDA = ["branco", "vermelho", "azul", "amarelo", "laranja", "verde_escuro"]


def semente(texto: str) -> int:
    return int(hashlib.md5(texto.encode("utf-8")).hexdigest()[:8], 16)


def main() -> int:
    manifesto = {i["id"]: i["cor"] for i in json.loads(MANIFESTO.read_text(encoding="utf-8"))}
    carros = json.loads(CARROS.read_text(encoding="utf-8"))
    codigo = {l["id"]: l["codigo_gt2"] for l in csv.DictReader(open(REF, encoding="utf-8"))} if REF.exists() else {}
    paletas_gt2: dict[str, set] = collections.defaultdict(set)
    if USADOS.exists():
        for l in csv.DictReader(open(USADOS, encoding="utf-8")):
            paletas_gt2[l["codigo"]].add(l["paleta"])
    modelos = {}
    for c in carros:
        corrida = bool(c.get("corrida")) or c["nome"].endswith("Corrida")
        familia = " ".join(c["nome"].replace(" Corrida", "").split()[:2]) + (" corrida" if corrida else "")
        fabrica = DO_MANIFESTO.get(manifesto.get(c["id"], ""), "branco")
        if corrida:
            candidatos = list(CORRIDA)
            n = MAX_CORRIDA
        else:
            ano = int(c.get("ano") or 0)
            epoca = EPOCA[max(k for k in EPOCA if k <= ano)] if ano >= 1960 else EPOCA[1990]
            candidatos = list(dict.fromkeys(CATEGORIA.get(c["categoria"], []) + epoca))
            k = len(paletas_gt2.get(codigo.get(c["id"], ""), ()))
            n = min(MAX_CORES, max(MIN_CORES, k)) if k else PADRAO_CORES
        random.Random(semente(familia)).shuffle(candidatos)
        cores = [fabrica] + [x for x in candidatos if x != fabrica]
        cores = cores[:n]
        if not any(x in NEUTROS for x in cores):
            cores[-1] = next(x for x in candidatos if x in NEUTROS) if any(x in NEUTROS for x in candidatos) else "branco"
        modelos[c["id"]] = cores
    saida = {"paleta": {k: {"nome": NOMES[k], "cor": v} for k, v in PALETA.items()}, "modelos": modelos}
    SAIDA.write_text(json.dumps(saida, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    contagem = collections.Counter(len(v) for v in modelos.values())
    print(f"{len(modelos)} modelos; cores por modelo: {dict(sorted(contagem.items()))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
