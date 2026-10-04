"""Leitura das tabelas de dados do GT2 (contêiner "GTDT").

Formato (pez2k/gt2tools, DataFile.cs): para o bloco i, o cabeçalho guarda em
8*(i+1) o início e o tamanho do bloco; o bloco é um vetor de estruturas de
tamanho fixo (layouts.py).
"""
from __future__ import annotations

import struct

from layouts import LAYOUTS, ORDEM_GTMODE_DATA, ORDEM_GTMODE_RACE

CARACTERES_ID = "-0123456789abcdefghijklmnopqrstuvwxyz"


def id_para_nome(car_id: int) -> str:
    """Id numérico de carro do GT2 para o código de 5 letras (ex.: 'cv93s')."""
    return "".join(CARACTERES_ID[(car_id >> (i * 6)) & 0x3F] for i in range(4, -1, -1))


def _formato(layout) -> str:
    return "<" + "".join(f"{q}{t}" if q > 1 else t for _, t, q in layout)


def ler_estrutura(nome: str, dados: bytes, inicio: int) -> dict:
    lay = LAYOUTS[nome]
    if lay["campos"] is None:
        return {"_bruto": dados[inicio:inicio + lay["tamanho"]].hex()}
    valores = list(struct.unpack_from(_formato(lay["campos"]), dados, inicio))
    r = {}
    for campo, _, qtd in lay["campos"]:
        if qtd > 1:
            r[campo] = valores[:qtd]
            del valores[:qtd]
        else:
            r[campo] = valores.pop(0)
    return r


def ler_blocos(dados: bytes, ordem: list[str]) -> dict[str, list[dict]]:
    if dados[:4] != b"GTDT":
        raise ValueError("não é um arquivo de dados GTDT")
    tabelas = {}
    for i, nome in enumerate(ordem):
        inicio, tamanho = struct.unpack_from("<II", dados, 8 * (i + 1))
        tam = LAYOUTS[nome]["tamanho"]
        if tamanho % tam:
            raise ValueError(f"bloco {nome}: tamanho {tamanho} não é múltiplo de {tam}")
        tabelas[nome] = [ler_estrutura(nome, dados, inicio + k * tam) for k in range(tamanho // tam)]
    return tabelas


def ler_gtmode_data(dados: bytes) -> dict[str, list[dict]]:
    return ler_blocos(dados, ORDEM_GTMODE_DATA)


def ler_gtmode_race(dados: bytes) -> tuple[dict[str, list[dict]], list[str]]:
    tabelas = ler_blocos(dados, ORDEM_GTMODE_RACE)
    pos_indice = 8 * (len(ORDEM_GTMODE_RACE) + 1)
    inicio_textos = struct.unpack_from("<I", dados, pos_indice)[0]
    return tabelas, ler_textos_ascii(dados, inicio_textos)


def ler_textos_ascii(dados: bytes, inicio: int) -> list[str]:
    n = struct.unpack_from("<H", dados, inicio)[0]
    pos = inicio + 2
    textos = []
    for _ in range(n):
        tam = dados[pos]
        textos.append(dados[pos + 1:pos + 2 + tam].split(b"\0", 1)[0].decode("latin-1"))
        pos += tam + 2
    return textos


def ler_unistrdb(dados: bytes) -> list[str]:
    """Tabela de textos UTF-16 (nomes de carros e peças)."""
    n = struct.unpack_from("<H", dados, 8)[0]
    pos = 10
    textos = []
    for _ in range(n):
        tam = (struct.unpack_from("<H", dados, pos)[0] + 1) * 2
        pos += 2
        textos.append(dados[pos:pos + tam].decode("utf-16-le", "replace").rstrip("\0"))
        pos += tam
    return textos


FABRICANTES_USADOS = [
    "Acura", "Alfa Romeo", "Aston Martin", "Audi", "BMW", "Chevrolet", "Citroen", "Daihatsu", "Dodge", "Fiat",
    "Ford", "Honda", "Fabricante12", "Jaguar", "Lancia", "Fabricante15", "Lister", "Lotus", "Mazda",
    "Mercedes-Benz", "Fabricante20", "Mini MG", "Mitsubishi", "Nissan", "Opel", "Peugeot", "Plymouth",
    "Renault", "RUF", "Shelby", "Subaru", "Suzuki", "Tommykaira", "Toyota", "TVR", "Vauxhall", "Vector",
    "Venturi", "Volkswagen",
]
PERIODOS_USADOS = 60
DIAS_POR_PERIODO = 10


def ler_usados(dados: bytes) -> list[dict]:
    """Concessionárias de usados (".usedcar_usa", cabeçalho "UCAR").

    Formato (pez2k/gt2tools, GT2UsedCarEditor): 60 períodos de 10 dias; cada
    um com 39 fabricantes (deslocamento u16 relativo ao período, contagem
    u16); cada carro tem 8 bytes: id u32, preço u24, paleta u8.
    """
    if dados[:4] != b"UCAR":
        raise ValueError("não é uma lista de usados (UCAR)")
    linhas = []
    for p in range(PERIODOS_USADOS):
        inicio = struct.unpack_from("<I", dados, 8 + 4 * p)[0]
        for f, fabricante in enumerate(FABRICANTES_USADOS):
            desloc, qtd = struct.unpack_from("<HH", dados, inicio + 4 * f)
            for k in range(qtd):
                pos = inicio + desloc + 8 * k
                car_id = struct.unpack_from("<I", dados, pos)[0]
                preco = dados[pos + 4] | (dados[pos + 5] << 8) | (dados[pos + 6] << 16)
                linhas.append({"periodo": p, "dia_inicio": p * DIAS_POR_PERIODO, "fabricante": fabricante,
                               "codigo": id_para_nome(car_id), "preco": preco, "paleta": dados[pos + 7]})
    return linhas
