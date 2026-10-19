#!/usr/bin/env python3
"""Termos internos de desenvolvimento não chegam ao jogador (docs/vocabulario.md).

Procura nas falas (tools/historia/cenas.txt) e nos textos de tela (frases entre aspas,
com espaço, no código de ui/ e data_model/) os termos da seção "Nunca na tela".
Comentários e chaves de dicionário (sem espaço) ficam de fora.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Sem distinção de maiúsculas.
TERMOS = [r"\bfila\b", r"simulad", r"nos testes", r"\bsemente", r"triagem", r"\bamostra", r"\bflags?\b",
          r"\btriggers?\b", r"gatilho", r"playtest", r"decisão \d", r"provas abertas", r"\bfator\b",
          r"\bteto\b", r"\buid\b"]
# Com distinção: "grid" minúsculo é a largada (o jogo só usa "Grid" para o The Grid); XP é sigla interna.
TERMOS_CASO = [r"\bgrid\b", r"\bXP\b"]

# Arquivos que só existem no modo de teste ou no desenvolvimento (não chegam à versão de loja).
ARQUIVOS_FORA = {"ui/registro_sessao.gd", "ui/preferencias.gd", "data_model/cenarios.gd", "data_model/save.gd"}
# Frases permitidas, com o motivo.
PERMITIDO = {
	# Ferramentas de teste (Configurações, só com Preferencias.ferramentas_teste()).
	"Modo de playtest",
	"Sessão %d (%s): %.0f min · assistindo %.0f min · %d fila%s (%.0f min) · %d pulo%s · %s→%s · %s→%s giros%s",
}

ASPAS = re.compile(r'"((?:[^"\\]|\\.)*)"')


def achados(texto: str) -> list:
    r = [t for t in TERMOS if re.search(t, texto, re.IGNORECASE)]
    r += [t for t in TERMOS_CASO if re.search(t, texto)]
    return r


def falas():
    for n, linha in enumerate((RAIZ / "tools/historia/cenas.txt").read_text(encoding="utf-8").splitlines(), 1):
        s = linha.strip()
        if not s or s[0] in "#=[" or ":" not in s:
            continue
        yield "tools/historia/cenas.txt", n, s.split(":", 1)[1].strip()


def textos_de_tela():
    for pasta in ("ui", "data_model"):
        for arq in sorted((RAIZ / pasta).glob("*.gd")):
            rel = f"{pasta}/{arq.name}"
            if rel in ARQUIVOS_FORA:
                continue
            for n, linha in enumerate(arq.read_text(encoding="utf-8").splitlines(), 1):
                codigo = linha.split("#", 1)[0] if '"' not in linha.split("#", 1)[0] or linha.strip().startswith("#") else linha
                if linha.strip().startswith("#"):
                    continue
                for m in ASPAS.finditer(codigo):
                    t = m.group(1)
                    if " " in t.strip():
                        yield rel, n, t


def main() -> int:
    erros = []
    for origem in (falas(), textos_de_tela()):
        for arq, n, texto in origem:
            if texto in PERMITIDO:
                continue
            a = achados(texto)
            if "{posicao}º" in texto:
                a.append("{posicao} já traz o º")
            if a:
                erros.append(f"{arq}:{n}: {texto!r} ({', '.join(a)})")
    if erros:
        print("Termos internos em texto do jogador (docs/vocabulario.md):")
        for e in erros:
            print("  " + e)
        return 1
    print("ok   vocabulário do jogador")
    return 0


if __name__ == "__main__":
    sys.exit(main())
