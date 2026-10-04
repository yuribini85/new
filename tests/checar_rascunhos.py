#!/usr/bin/env python3
"""Confere que data/pistas.json bate com data/rascunhos_pistas/ fechados."""
import json
import pathlib
import sys

raiz = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(raiz / "tools"))
from fechar_pista import fechar  # noqa: E402

pistas = {p["id"]: p for p in json.loads((raiz / "data/pistas.json").read_text())}
falhas = 0
for arq in sorted((raiz / "data/rascunhos_pistas").glob("*.json")):
    gerada = fechar(json.loads(arq.read_text()))
    atual = pistas.get(gerada["id"])
    if atual != gerada:
        print(f"FAIL {arq.name}: data/pistas.json difere do rascunho fechado")
        falhas += 1
    else:
        print(f"ok   rascunho {arq.name}")
sys.exit(1 if falhas else 0)
