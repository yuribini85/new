#!/usr/bin/env python3
"""Testa tools/extrair_gt2.py com um disco sintético no mesmo formato do GT2.

Não usa dados do jogo: monta ISO 9660 -> GT2.VOL (GTFS) -> gtmode_*.dat
(GTDT) com valores inventados e confere que o extrator lê de volta.
"""
import csv
import gzip
import pathlib
import struct
import subprocess
import sys
import tempfile

raiz = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(raiz / "tools" / "gt2"))
from layouts import LAYOUTS, ORDEM_GTMODE_DATA, ORDEM_GTMODE_RACE  # noqa: E402
import tabelas  # noqa: E402

CARS = "-0123456789abcdefghijklmnopqrstuvwxyz"


def id_carro(nome):
    v = 0
    for ch in nome:
        v = (v << 6) | CARS.index(ch)
    return v


def empacotar(nome, valores):
    campos = LAYOUTS[nome]["campos"]
    plano = []
    for campo, _, q in campos:
        v = valores.get(campo, [0] * q if q > 1 else 0)
        plano.extend(v if q > 1 else [v])
    return struct.pack(tabelas._formato(campos), *plano)


def gtdt(ordem, registros, extra=b""):
    cab = bytearray(b"GTDTl\0" + struct.pack("<H", len(ordem) * 2))
    cab += b"\0" * (8 * (len(ordem) + 2) - len(cab))
    corpo = bytearray()
    base = len(cab)
    for i, nome in enumerate(ordem):
        bloco = b"".join(empacotar(nome, r) if LAYOUTS[nome]["campos"] else b"\0" * LAYOUTS[nome]["tamanho"]
                         for r in registros.get(nome, []))
        struct.pack_into("<II", cab, 8 * (i + 1), base + len(corpo), len(bloco))
        corpo += bloco
    if extra:
        struct.pack_into("<II", cab, 8 * (len(ordem) + 1), base + len(corpo), len(extra))
        corpo += extra
    return bytes(cab + corpo)


def ascii_tab(textos):
    r = bytearray(struct.pack("<H", len(textos)))
    for t in textos:
        b = t.encode("latin-1")
        r += bytes([len(b)]) + b + b"\0"
    return bytes(r)


def unistr(textos):
    r = bytearray(b"\0\0\0\0WSDB" + struct.pack("<H", len(textos)))
    for t in textos:
        r += struct.pack("<H", len(t)) + (t + "\0").encode("utf-16-le")
    return bytes(r)


def gtfs(arquivos):
    setor = 0x800
    nomes = list(arquivos)
    n_arq = len(nomes) + 2
    entradas = len(nomes)
    cab_tam = 16 + 4 * n_arq
    toc = setor  # setor 1
    pos = toc + ((entradas * 0x20 + setor - 1) // setor) * setor
    desloc = [0, toc]
    corpo = bytearray()
    for n in nomes:
        d = arquivos[n]
        ocupado = ((len(d) + setor - 1) // setor) * setor
        desloc.append(pos + (ocupado - len(d)))
        corpo += d + b"\0" * (ocupado - len(d))
        pos += ocupado
    out = bytearray(b"GTFS\0\0\0\0" + struct.pack("<HH", n_arq, entradas) + b"\0" * 4)
    out += struct.pack(f"<{n_arq}I", *desloc)
    out += b"\0" * (toc - len(out))
    for k, n in enumerate(nomes):
        flags = 0x80 if k == len(nomes) - 1 else 0
        out += struct.pack("<Ih", 0, k + 2) + bytes([flags]) + n.encode().ljust(25, b"\0")
    out += b"\0" * (toc + ((entradas * 0x20 + setor - 1) // setor) * setor - len(out))
    return bytes(out + corpo)


def iso(nome, dados, bruto):
    setor = 2048
    lba_raiz, lba_arq = 18, 19
    def reg(lba, tam, flags, n):
        nb = n.encode()
        r = bytearray(33 + len(nb) + (len(nb) + 1) % 2)
        r[0] = len(r)
        struct.pack_into("<I", r, 2, lba); struct.pack_into(">I", r, 6, lba)
        struct.pack_into("<I", r, 10, tam); struct.pack_into(">I", r, 14, tam)
        r[25] = flags; r[32] = len(nb); r[33:33 + len(nb)] = nb
        return bytes(r)
    raiz_dir = reg(lba_raiz, setor, 2, "\0") + reg(lba_raiz, setor, 2, "\1") + reg(lba_arq, len(dados), 0, nome + ";1")
    pvd = bytearray(setor)
    pvd[0] = 1; pvd[1:6] = b"CD001"; pvd[6] = 1
    pvd[156:156 + 34] = reg(lba_raiz, setor, 2, "\0")
    setores = [b"\0" * setor] * 16 + [bytes(pvd), b"\xff" + b"CD001" + b"\0" * (setor - 6), raiz_dir.ljust(setor, b"\0")]
    for i in range(0, len(dados), setor):
        setores.append(dados[i:i + setor].ljust(setor, b"\0"))
    if not bruto:
        return b"".join(setores)
    sinc = b"\x00" + b"\xff" * 10 + b"\x00"
    return b"".join(sinc + b"\0" * 12 + s + b"\0" * 280 for s in setores)


def montar():
    nomes = ["Hatch", "Teste '93", "Cupe", "Turbo"]
    data = gtdt(ORDEM_GTMODE_DATA, {
        "Engine": [{"CarId": id_carro("hat93"), "DisplayedPower": 160, "MaxPowerRPM": 760},
                   {"CarId": id_carro("cup95"), "DisplayedPower": 280, "MaxPowerRPM": 650}],
        "Chassis": [{"CarId": id_carro("hat93"), "Weight": 1050, "FrontGrip": 90, "RearGrip": 88},
                    {"CarId": id_carro("cup95"), "Weight": 1300, "FrontGrip": 95, "RearGrip": 99}],
        "Drivetrain": [{"CarId": id_carro("hat93"), "DrivetrainType": 1}, {"CarId": id_carro("cup95"), "DrivetrainType": 2}],
        "Car": [{"CarId": id_carro("hat93"), "Engine": 0, "Chassis": 0, "Drivetrain": 0, "NameFirstPart": 0,
                 "NameSecondPart": 1, "Year": 93, "Price": 17500},
                {"CarId": id_carro("cup95"), "Engine": 1, "Chassis": 1, "Drivetrain": 1, "NameFirstPart": 2,
                 "NameSecondPart": 3, "Year": 95, "Price": 52000}],
    })
    race = gtdt(ORDEM_GTMODE_RACE, {
        "Event": [{"EventName": 0, "TrackName": 1, "Laps": 3, "Licence": 1, "PSRestriction": 200,
                   "DrivetrainRestriction": 1, "PrizeMoney1st": 25, "PrizeMoney2nd": 15,
                   "PrizeCars": [id_carro("cup95"), 0, 0, 0], "Opponent1": 4, "Opponent2": 7}],
        "EnemyCars": [{"CarId": id_carro("hat93")}],
    }, extra=ascii_tab(["Copa Teste", "Pista Teste"]))
    vol = gtfs({"eng_gtmode_data.dat.gz": gzip.compress(data), "eng_gtmode_race.dat": race,
                "eng_unistrdb.dat": unistr(nomes)})
    return vol


def main():
    falhas = []
    vol = montar()
    for bruto in (False, True):
        with tempfile.TemporaryDirectory() as tmp:
            img = pathlib.Path(tmp) / "disco.bin"
            img.write_bytes(iso("GT2.VOL", vol, bruto))
            saida = pathlib.Path(tmp) / "saida"
            r = subprocess.run([sys.executable, str(raiz / "tools/extrair_gt2.py"), "--disco", str(img),
                                "--saida", str(saida)], capture_output=True, text=True)
            if r.returncode:
                falhas.append(f"bruto={bruto}: extrator falhou: {r.stderr.strip()[-400:]}")
                continue
            carros = list(csv.DictReader(open(saida / "carros.csv", encoding="utf-8")))
            esperado = [("hat93", "Hatch Teste '93", "93", "17500", "160", "1050", "1"),
                        ("cup95", "Cupe Turbo", "95", "52000", "280", "1300", "2")]
            obtido = [(c["codigo"], c["nome"], c["ano"], c["preco"], c["potencia_ps"], c["peso_kg"], c["tracao_tipo"])
                      for c in carros]
            if obtido != esperado:
                falhas.append(f"bruto={bruto}: carros {obtido}")
            ev = list(csv.DictReader(open(saida / "eventos.csv", encoding="utf-8")))
            if not ev or (ev[0]["evento"], ev[0]["pista"], ev[0]["voltas"], ev[0]["licenca"], ev[0]["tracao"],
                          ev[0]["premios_x100"], ev[0]["carros_premio"], ev[0]["adversarios"]) != (
                    "Copa Teste", "Pista Teste", "3", "B", "FF", "25 15 0 0 0 0", "cup95", "4 7"):
                falhas.append(f"bruto={bruto}: eventos {ev}")
    for f in falhas:
        print("FAIL extrator GT2: " + f)
    if not falhas:
        print("ok   extrator GT2 (disco sintético ISO e bruto)")
    return 1 if falhas else 0


if __name__ == "__main__":
    raise SystemExit(main())
