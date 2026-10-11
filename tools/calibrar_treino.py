#!/usr/bin/env python3
"""Roda tools/calibrar_treino.gd para cada licença em que o treino existe (em
paralelo) e grava os tetos em data/equipe.json → treino.teto. O teto nunca
desce de uma licença para a seguinte.

Uso: python3 tools/calibrar_treino.py CAMINHO_DO_GODOT [--eventos=12 --carros=12 --sementes=4 --meta=0.1 --passo=0.0025 --ate=0.05]
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
EQUIPE = RAIZ / "data/equipe.json"


def main(args: list[str]) -> int:
    if not args:
        print(__doc__)
        return 1
    godot, extras = args[0], args[1:]
    equipe = json.loads(EQUIPE.read_text(encoding="utf-8"))
    licencas = list(equipe["treino"]["teto"].keys())
    procs = {lic: subprocess.Popen([godot, "--headless", "--path", str(RAIZ), "--script",
                                    "res://tools/calibrar_treino.gd", "--", f"--licenca={lic}", *extras],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
             for lic in licencas}
    tetos = {}
    for lic, p in procs.items():
        saida, _ = p.communicate()
        for linha in saida.splitlines():
            if linha.startswith("TETO "):
                tetos[lic] = json.loads(linha[5:])
            elif linha.startswith(("licença", "  ritmo")):
                print(linha)
    if set(tetos) != set(licencas):
        print("faltou medir:", sorted(set(licencas) - set(tetos)), file=sys.stderr)
        return 1
    anterior = 0.0
    for lic in licencas:
        t = max(float(tetos[lic]["teto"]), anterior)
        equipe["treino"]["teto"][lic] = round(t, 4)
        anterior = t
    EQUIPE.write_text(json.dumps(equipe, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("tetos gravados:", equipe["treino"]["teto"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
