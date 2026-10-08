#!/usr/bin/env python3
"""Gera docs/ids.md: os IDs que a história, a interface e os dados usam.

Lê data/*.json e o código (flags gravadas em GDScript, cenários de teste), para a
lista não divergir do jogo. Uso: python3 tools/listar_ids.py [--checar]
(--checar só compara com o arquivo e falha se estiver desatualizado).
"""
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "docs" / "ids.md"


def ler(nome):
    return json.loads((RAIZ / "data" / nome).read_text(encoding="utf-8"))


def flags_do_codigo():
    achadas = {}
    padroes = [re.compile(r'flags\["([A-Z0-9_]+)"\]'), re.compile(r'const FLAG[A-Z_]* := "([A-Z0-9_]+)"')]
    for arq in sorted(RAIZ.glob("**/*.gd")):
        if any(p in arq.parts for p in (".godot", "referencia", "tests")):
            continue
        texto = arq.read_text(encoding="utf-8")
        for p in padroes:
            for f in p.findall(texto):
                achadas.setdefault(f, str(arq.relative_to(RAIZ)))
    return achadas


def cenarios():
    texto = (RAIZ / "data_model" / "cenarios.gd").read_text(encoding="utf-8")
    return re.findall(r'\{"id": "([a-z_]+)", "nome": "([^"]+)"', texto)


def gerar():
    dialogos = ler("dialogos.json")
    l = ["# IDs do jogo", "",
         "Gerado por `tools/listar_ids.py` a partir de `data/` e do código. Não editar à mão.", ""]

    l += ["## Personagens (`data/personagens.json`)", "", "| id | nome |", "|---|---|"]
    for p in ler("personagens.json"):
        l.append(f"| `{p['id']}` | {p.get('nome', '')} |")

    l += ["", "## Cenas (`data/dialogos.json`, de `tools/historia/cenas.txt`)", "",
          "| id | trigger | capítulo | grava |", "|---|---|---|---|"]
    for c in dialogos:
        l.append(f"| `{c['id']}` | `{c['trigger']}` | {c.get('capitulo') or '—'} | "
                 f"{', '.join('`%s`' % f for f in c.get('flags', [])) or '—'} |")

    triggers = sorted({c["trigger"] for c in dialogos})
    l += ["", "## Triggers usados pelas cenas", "", ", ".join(f"`{t}`" for t in triggers)]

    acoes = sorted({f["acao"] for c in dialogos for f in c["falas"] if "acao" in f})
    l += ["", "## Ações de tutorial (TutorialAction)", "", ", ".join(f"`{a}`" for a in acoes)]

    flags = {}
    for c in dialogos:
        for f in c.get("flags", []):
            flags.setdefault(f, "cena " + c["id"])
        for f in c.get("requer", []) + c.get("proibe", []):
            flags.setdefault(f, "condição de " + c["id"])
    for f, onde in flags_do_codigo().items():
        flags.setdefault(f, onde)
    l += ["", "## Flags de história", "", "| flag | primeira origem |", "|---|---|"]
    for f in sorted(flags):
        l.append(f"| `{f}` | {flags[f]} |")

    l += ["", "## Licenças (`data/licencas.json`)", "", "| id | nome | GT2 |", "|---|---|---|"]
    for lic in ler("licencas.json"):
        l.append(f"| `{lic['id']}` | {lic.get('nome', '')} | {lic.get('gt2') or '—'} |")

    l += ["", "## Equipes e pilotos (`data/equipes.json`)", "", "| equipe | nível | pilotos |", "|---|---|---|"]
    for e in ler("equipes.json"):
        pil = ", ".join(f"`{p['id']}`" + (" (provisório)" if p.get("provisorio") else "") for p in e["pilotos"])
        l.append(f"| `{e['id']}` {e['nome']} | {e.get('nivel', 'jogador')} | {pil} |")
    seg = ler("carreira.json").get("equipe_jogador", {}).get("segundo_piloto")
    if seg:
        l.append(f"\nSegundo piloto da equipe do jogador: `{seg['id']}` ({seg['nome']}"
                 + (", provisório" if seg.get("provisorio") else "") + ").")

    l += ["", "## Cenários de teste (`data_model/cenarios.gd`)", "", "| id | nome |", "|---|---|"]
    for cid, nome in cenarios():
        l.append(f"| `{cid}` | {nome} |")
    return "\n".join(l) + "\n"


def main():
    texto = gerar()
    if "--checar" in sys.argv:
        if not SAIDA.exists() or SAIDA.read_text(encoding="utf-8") != texto:
            print("docs/ids.md desatualizado: rode python3 tools/listar_ids.py", file=sys.stderr)
            sys.exit(1)
        return
    SAIDA.write_text(texto, encoding="utf-8")
    print(f"{SAIDA.relative_to(RAIZ)}: {texto.count(chr(10))} linhas")


if __name__ == "__main__":
    main()
