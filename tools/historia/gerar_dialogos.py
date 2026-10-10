#!/usr/bin/env python3
"""Converte tools/historia/cenas.txt (transcrição da Bíblia de Diálogos do Drive)
em data/dialogos.json. Não editar o JSON à mão: editar cenas.txt e rodar de novo.

Cena: {id, trigger, falas: [{quem, texto} | {acao}], requer, proibe, flags,
personagem?, condicao?, bloqueia, uma_vez, proxima?, capitulo?, cenario?,
lembrete?, segura_largada?, reativa?}
personagem=a,b: a cena vale para qualquer um deles (lista). reativa=sim:
comentário de contexto, no máximo um a cada `reativa_intervalo_corridas`
corridas (data/historia.json).
lembrete=ID: se o jogador não fizer o que a cena pede em alguns segundos, a cena
ID (trigger LEMBRETE) aparece, enquanto ainda valer. segura_largada=sim: a
corrida fica parada no grid até a cena acabar.
Ações com argumento: [CENARIO:id] e [ILUSTRACAO:id] (data/historia.json → cenarios,
ilustracoes); o id tem que existir lá.
Uso: python3 tools/historia/gerar_dialogos.py
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
FONTE = RAIZ / "tools/historia/cenas.txt"
SAIDA = RAIZ / "data/dialogos.json"
QUEM = {"Mara": "mara", "Piloto": "piloto_casa", "Adrian": "adrian", "Elena": "elena", "Marcus": "marcus", "Victor": "victor", "Lucas": "lucas",
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
                elif k == "reativa":
                    c["reativa"] = v == "sim"
                elif k == "segura_largada":
                    c["segura_largada"] = v == "sim"
                elif k == "repetivel":
                    c["uma_vez"] = v != "sim"
                elif k == "condicao":
                    ck, cv = v.split(":")
                    c["condicao"] = {ck: int(cv)}
                elif k == "personagem":
                    ps = [x.strip() for x in v.split(",") if x.strip()]
                    c[k] = ps[0] if len(ps) == 1 else ps
                elif k in ("proxima", "capitulo", "cenario", "lembrete"):
                    c[k] = v
                else:
                    sys.exit(f"{FONTE.name}:{n}: opção desconhecida {k}")
            cenas.append(c)
            continue
        m = re.fullmatch(r"\[([A-Z0-9_]+)(?::([a-z0-9_]+))?\]", linha)
        if m:
            cenas[-1]["falas"].append({"acao": m.group(1) + (":" + m.group(2) if m.group(2) else "")})
            continue
        quem, texto = linha.split(":", 1)
        if quem not in QUEM:
            sys.exit(f"{FONTE.name}:{n}: personagem desconhecido {quem}")
        cenas[-1]["falas"].append({"quem": QUEM[quem], "texto": texto.strip()})
    ids = {c["id"] for c in cenas}
    historia = json.loads((RAIZ / "data/historia.json").read_text(encoding="utf-8"))
    for c in cenas:
        if c.get("proxima") and c["proxima"] not in ids:
            sys.exit(f"{c['id']}: próxima {c['proxima']} não existe")
        if c.get("lembrete") and c["lembrete"] not in ids:
            sys.exit(f"{c['id']}: lembrete {c['lembrete']} não existe")
        usados = [("cenarios", c["cenario"])] if c.get("cenario") else []
        for f in c["falas"]:
            for tipo, chave in (("CENARIO:", "cenarios"), ("ILUSTRACAO:", "ilustracoes")):
                if f.get("acao", "").startswith(tipo):
                    usados.append((chave, f["acao"][len(tipo):]))
        for chave, ident in usados:
            if ident not in historia.get(chave, {}):
                sys.exit(f"{c['id']}: {ident} não está em data/historia.json → {chave}")
    SAIDA.write_text(json.dumps(cenas, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(cenas)} cenas, {sum(len(c['falas']) for c in cenas)} falas/ações")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
