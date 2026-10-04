"""Leitura do arquivo GT2.VOL (formato GTFS).

Layout documentado em adeyblue/GTVolTools (MIT,
https://github.com/adeyblue/GTVolTools): cabeçalho "GTFS\\0\\0\\0\\0", contagem
de arquivos e de entradas, tabela de deslocamentos e índice de entradas de
0x20 bytes começando no setor do primeiro arquivo.
"""
from __future__ import annotations

import struct
import zlib

SETOR = 0x800
ENTRADA = 0x20


def _alinhar(valor: int) -> int:
    return valor & ~(SETOR - 1)


def ler_indice(vol: bytes) -> dict[str, tuple[int, int]]:
    """Retorna {caminho: (início, tamanho)} de cada arquivo do VOL."""
    if vol[:8] != b"GTFS\0\0\0\0":
        raise ValueError("não é um arquivo GTFS (GT2.VOL)")
    n_arquivos, n_entradas = struct.unpack_from("<HH", vol, 8)
    desloc = list(struct.unpack_from(f"<{n_arquivos}I", vol, 16))
    desloc.append(len(vol))
    toc = _alinhar(desloc[1])

    diretorios: list[str] = []
    atual = ""
    i_dir = 0
    i_ins = 0
    pendentes = []
    for i in range(n_entradas):
        r = vol[toc + i * ENTRADA: toc + (i + 1) * ENTRADA]
        i_desloc = struct.unpack_from("<h", r, 4)[0]
        flags = r[6]
        folha = r[7:32].split(b"\0", 1)[0].decode("ascii")
        nome = f"{atual}/{folha}" if atual else folha
        if flags & 1:
            if folha != "..":
                if atual:
                    diretorios.insert(i_ins, nome)
                    i_ins += 1
                else:
                    diretorios.append(nome)
        elif i_desloc:
            bruto = desloc[i_desloc]
            pendentes.append((nome, _alinhar(bruto), bruto & (SETOR - 1)))
        if flags & 0x80:
            atual = diretorios[i_dir] if i_dir < len(diretorios) else ""
            i_dir += 1
            i_ins = i_dir

    indice = {}
    for k, (nome, inicio, cauda) in enumerate(pendentes):
        proximo = pendentes[k + 1][1] if k + 1 < len(pendentes) else len(vol)
        tamanho = max(0, proximo - inicio - cauda) or SETOR
        indice[nome] = (inicio, tamanho)
    return indice


def extrair(vol: bytes, indice: dict, sufixo: str) -> tuple[str, bytes]:
    """Primeiro arquivo cujo caminho termina em `sufixo` (com ou sem .gz), já descompactado."""
    for nome, (inicio, tamanho) in sorted(indice.items()):
        base = nome[:-3] if nome.lower().endswith(".gz") else nome
        if base.lower().endswith(sufixo.lower()):
            dados = vol[inicio:inicio + tamanho]
            if dados[:2] == b"\x1f\x8b":
                dados = descompactar(dados)
            return nome, dados
    raise FileNotFoundError(f"nenhum arquivo terminado em {sufixo} no VOL")


def descompactar(dados: bytes) -> bytes:
    """Descompacta gzip ignorando o preenchimento de setor depois do fim."""
    return zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(dados)
