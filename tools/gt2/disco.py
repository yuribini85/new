"""Leitura de arquivos de uma imagem de CD de PlayStation (ISO 9660).

Aceita imagem bruta (.bin/.img, setores de 2352 bytes, Mode 2 Form 1) ou ISO
de 2048 bytes por setor.
"""
from __future__ import annotations

import pathlib
import struct

SINCRONIA = b"\x00" + b"\xff" * 10 + b"\x00"


class Disco:
    def __init__(self, caminho: pathlib.Path):
        self.arquivo = open(caminho, "rb")
        inicio = self.arquivo.read(12)
        if inicio == SINCRONIA:
            self.tam_setor, self.desloc_dados = 2352, 24
        else:
            self.tam_setor, self.desloc_dados = 2048, 0
        pvd = self.setor(16)
        if pvd[1:6] != b"CD001":
            raise ValueError(f"{caminho} não parece uma imagem ISO 9660")
        self.raiz = self._registro(pvd[156:156 + 34])

    def fechar(self) -> None:
        self.arquivo.close()

    def setor(self, lba: int) -> bytes:
        self.arquivo.seek(lba * self.tam_setor + self.desloc_dados)
        return self.arquivo.read(2048)

    def ler(self, lba: int, tamanho: int) -> bytes:
        partes = []
        restante = tamanho
        while restante > 0:
            dados = self.setor(lba)
            partes.append(dados[:restante])
            restante -= len(dados)
            lba += 1
        return b"".join(partes)

    @staticmethod
    def _registro(r: bytes) -> dict:
        lba = struct.unpack_from("<I", r, 2)[0]
        tamanho = struct.unpack_from("<I", r, 10)[0]
        flags = r[25]
        nome_len = r[32]
        nome = r[33:33 + nome_len].decode("ascii", "replace")
        return {"lba": lba, "tamanho": tamanho, "diretorio": bool(flags & 2), "nome": nome.split(";")[0]}

    def listar(self, diretorio: dict) -> list[dict]:
        dados = self.ler(diretorio["lba"], diretorio["tamanho"])
        itens, pos = [], 0
        while pos < len(dados):
            tam = dados[pos]
            if tam == 0:
                pos = (pos // 2048 + 1) * 2048  # registros não cruzam setor
                continue
            reg = self._registro(dados[pos:pos + tam])
            if reg["nome"] not in ("\x00", "\x01"):
                itens.append(reg)
            pos += tam
        return itens

    def achar(self, nome: str) -> dict | None:
        """Busca um arquivo pelo nome (sem diferenciar maiúsculas) em todo o disco."""
        pendentes = [self.raiz]
        while pendentes:
            d = pendentes.pop()
            for item in self.listar(d):
                if item["diretorio"]:
                    pendentes.append(item)
                elif item["nome"].lower() == nome.lower():
                    return item
        return None

    def extrair(self, nome: str) -> bytes:
        item = self.achar(nome)
        if item is None:
            raise FileNotFoundError(f"{nome} não está no disco")
        return self.ler(item["lba"], item["tamanho"])
