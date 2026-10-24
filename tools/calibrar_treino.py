#!/usr/bin/env python3
"""Roda tools/calibrar_treino.gd para cada licença em que o treino existe (em
paralelo) e grava os tetos em data/equipe.json → treino.teto. O treino não se
perde ao subir de licença, então o teto de cada licença é o menor entre o dela e
o das seguintes: a meta vale em todas.

Uso: python3 tools/calibrar_treino.py CAMINHO_DO_GODOT [--eventos=12 --carros=24 --sementes=1 --meta=0.1 --passo=0.001 --ate=0.05 --delta=0.02]
"""
from __future__ import annotations

import json
import math
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
    # Medida só vale com vitórias suficientes na base para resolver a meta (uma
    # vitória a mais não pode passar dela): sem isso, a licença herda o teto da
    # anterior (decisão do usuário: o ELITE, onde carro de fábrica quase não vence).
    medidas = [lic for lic in licencas
               if tetos[lic]["vitorias_base"] * tetos[lic]["corridas"] >= 1.0 / tetos[lic]["meta"] - 1e-9]
    for lic in licencas:
        if lic not in medidas:
            v = tetos[lic]["vitorias_base"] * tetos[lic]["corridas"]
            print(f"{lic}: {v:.0f} vitórias na base, poucas para medir; herda o teto da licença anterior")
    seguinte = float("inf")
    for lic in reversed(medidas):
        seguinte = min(float(tetos[lic]["teto"]), seguinte)
        equipe["treino"]["teto"][lic] = round(seguinte, 4)
    base = float(tetos[licencas[0]]["base"])
    anterior = base
    for lic in licencas:
        if lic in medidas:
            anterior = equipe["treino"]["teto"][lic]
        else:
            equipe["treino"]["teto"][lic] = anterior
    # Passo de cada nível: o maior teto dividido em `niveis` (decisão do usuário: 3).
    niveis = int(equipe["treino"].get("niveis", 3))
    # Arredondado para cima: `niveis` passos alcançam o teto (um a mais não cabe).
    equipe["treino"]["passo"] = math.ceil((max(equipe["treino"]["teto"].values()) - base) / niveis * 1e5) / 1e5
    EQUIPE.write_text(json.dumps(equipe, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("tetos gravados:", equipe["treino"]["teto"], "passo:", equipe["treino"]["passo"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
