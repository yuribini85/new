#!/usr/bin/env python3
"""Converte tools/historia/cenas.txt (transcrição da Bíblia de Diálogos do Drive)
em data/dialogos.json. Não editar o JSON à mão: editar cenas.txt e rodar de novo.

Cena: {id, trigger, falas: [{quem, texto} | {acao}], requer, proibe, flags,
personagem?, condicao?, bloqueia, uma_vez, proxima?, capitulo?}
Uso: python3 tools/historia/gerar_dialogos.py
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
FONTE = RAIZ / "tools/historia/cenas.txt"
SAIDA = RAIZ / "data/dialogos.json"
QUEM = {"Adrian": "adrian", "Elena": "elena", "Marcus": "marcus", "Victor": "victor", "Lucas": "lucas",
        "Sophie": "sophie", "Vendedor": "vendedor", "Responsável": "responsavel", "Jornalista": "jornalista",
        "Sistema": "sistema"}


def main() -> int:
    cenas = []
    for n, linha in enumerate(FONTE.read_text(encoding="utf-8").splitlines(), 1):
        linha = linha.strip()
        if not linha or linha.startswith("#"):
            continue
        if linha.startswith("= "):
            partes = [p.strip() for p in linha[2:].split("|")]
            c = {"id": partes[0], "trigger": partes[1], "falas": [], "requer": [], "proibe": [], "flags": [],
                 "bloqueia": False, "uma_vez": True}
            for op in (partes[2].split(";") if len(partes) > 2 else []):
                if not op.strip():
                    continue
                k, v = [x.strip() for x in op.split("=", 1)]
                if k in ("requer", "proibe", "flags"):
                    c[k] = [x.strip() for x in v.split(",") if x.strip()]
                elif k == "bloqueia":
                    c["bloqueia"] = v == "sim"
                elif k == "repetivel":
                    c["uma_vez"] = v != "sim"
                elif k == "condicao":
                    ck, cv = v.split(":")
                    c["condicao"] = {ck: int(cv)}
                elif k in ("personagem", "proxima", "capitulo"):
                    c[k] = v
                else:
                    sys.exit(f"{FONTE.name}:{n}: opção desconhecida {k}")
            cenas.append(c)
            continue
        m = re.fullmatch(r"\[([A-Z0-9_]+)\]", linha)
        if m:
            cenas[-1]["falas"].append({"acao": m.group(1)})
            continue
        quem, texto = linha.split(":", 1)
        if quem not in QUEM:
            sys.exit(f"{FONTE.name}:{n}: personagem desconhecido {quem}")
        cenas[-1]["falas"].append({"quem": QUEM[quem], "texto": texto.strip()})
    ids = {c["id"] for c in cenas}
    for c in cenas:
        if c.get("proxima") and c["proxima"] not in ids:
            sys.exit(f"{c['id']}: próxima {c['proxima']} não existe")
    SAIDA.write_text(json.dumps(cenas, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(cenas)} cenas, {sum(len(c['falas']) for c in cenas)} falas/ações")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
