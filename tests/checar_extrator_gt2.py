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
import os

# Saída em UTF-8 também no Windows (o console padrão lá é cp1252).
for _fluxo in (sys.stdout, sys.stderr):
    if hasattr(_fluxo, "reconfigure"):
        _fluxo.reconfigure(encoding="utf-8", errors="replace")

AMBIENTE = {**os.environ, "PYTHONUTF8": "1"}
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
        bloco = b"".join(empacotar(nome, r) if LAYOUTS[nome]["campos"] else r.get("_bruto", b"\0" * LAYOUTS[nome]["tamanho"])
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


def ucar(ofertas):
    """ofertas: {periodo: [(indice_fabricante, codigo, preco)]}"""
    out = bytearray(b"UCAR\0\0\0\0" + b"\0" * (4 * 61))
    for p in range(60):
        inicio = len(out)
        struct.pack_into("<I", out, 8 + 4 * p, inicio)
        por_fab = {}
        for f, cod, preco in ofertas.get(p, []):
            por_fab.setdefault(f, []).append((cod, preco))
        indice = bytearray(4 * 39)
        corpo = bytearray()
        for f in range(39):
            carros = por_fab.get(f, [])
            struct.pack_into("<HH", indice, 4 * f, 4 * 39 + len(corpo), len(carros))
            for cod, preco in carros:
                corpo += struct.pack("<I", id_carro(cod)) + preco.to_bytes(3, "little") + b"\x07"
        out += indice + corpo
    struct.pack_into("<I", out, 8 + 4 * 60, len(out))
    return bytes(out)


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
        # Curva de torque de um ponto: 15,27 kgf·m a 7500 rpm = 160 ps; 33,42 a 6000 = 280 ps.
        "Engine": [{"CarId": id_carro("hat93"), "DisplayedPower": 160, "MaxPowerRPM": 760, "PowerMultiplier": 100,
                    "TorqueCurve1": 1527, "TorqueCurveRPM1": 75},
                   {"CarId": id_carro("cup95"), "DisplayedPower": 280, "MaxPowerRPM": 650, "PowerMultiplier": 100,
                    "TorqueCurve1": 3342, "TorqueCurveRPM1": 60}],
        "Chassis": [{"CarId": id_carro("hat93"), "Weight": 1050, "FrontGrip": 90, "RearGrip": 88},
                    {"CarId": id_carro("cup95"), "Weight": 1300, "FrontGrip": 95, "RearGrip": 99}],
        "Drivetrain": [{"CarId": id_carro("hat93"), "DrivetrainType": 1}, {"CarId": id_carro("cup95"), "DrivetrainType": 2}],
        "Brake": [{"CarId": id_carro("hat93"), "Stage": 0, "BrakingPower": 40},
                  {"CarId": id_carro("cup95"), "Stage": 0, "BrakingPower": 60},
                  {"CarId": id_carro("hat93"), "Stage": 1, "BrakingPower": 50, "Price": 3500}],
        "NATune": [{"CarId": id_carro("hat93"), "Stage": 1, "PowerMultiplier": 10, "Price": 4000}],
        "TurbineKit": [{"CarId": id_carro("cup95"), "Stage": 2, "HighRPMPowerMultiplier": 40, "Price": 20000}],
        "Lightweight": [{"CarId": id_carro("hat93"), "Stage": 1, "Weight": 900, "Price": 2500}],
        "TiresFront": [{"CarId": id_carro("hat93"), "Stage": 0, "TireCompound": 0},
                       {"CarId": id_carro("hat93"), "Stage": 1, "TireCompound": 1, "Price": 1000},
                       {"CarId": id_carro("cup95"), "Stage": 0, "TireCompound": 0},
                       {"CarId": id_carro("cup95"), "Stage": 1, "TireCompound": 1, "Price": 3000}],
        # Grip do composto no 1º byte: 145 (fábrica) e 150 (esportivo).
        "TireCompound": [{"_bruto": bytes([145]) + b"\0" * 63}, {"_bruto": bytes([150]) + b"\0" * 63}],
        "Car": [{"CarId": id_carro("hat93"), "Engine": 0, "Chassis": 0, "Drivetrain": 0, "Brake": 0, "NameFirstPart": 0,
                 "NameSecondPart": 1, "Year": 93, "Price": 17500},
                {"CarId": id_carro("cup95"), "Engine": 1, "Chassis": 1, "Drivetrain": 1, "Brake": 1, "NameFirstPart": 2,
                 "NameSecondPart": 3, "Year": 95, "Price": 52000}],
    })
    race = gtdt(ORDEM_GTMODE_RACE, {
        "Event": [{"EventName": 0, "TrackName": 1, "Laps": 3, "Licence": 1, "PSRestriction": 200,
                   "DrivetrainRestriction": 1, "PrizeMoney1st": 25, "PrizeMoney2nd": 15,
                   "PrizeCars": [id_carro("cup95"), 0, 0, 0], "Opponent1": 4, "Opponent2": 7}],
        "EnemyCars": [{"CarId": id_carro("hat93")}],
    }, extra=ascii_tab(["SND0001", "mountain"]))
    # Cópias de outra região com lixo: o extrator deve preferir usa_.
    vol = gtfs({"eng_gtmode_data.dat.gz": b"lixo", "usa_gtmode_data.dat.gz": gzip.compress(data),
                "usa_gtmode_race.dat": race, "eng_unistrdb.dat": b"lixo", "usa_unistrdb.dat.gz": gzip.compress(unistr(nomes)),
                ".usedcar_jpn": b"lixo",
                ".usedcar_usa": gzip.compress(ucar({0: [(11, "hat93", 9000)], 1: [(11, "hat93", 9000)],
                                                    2: [(11, "hat93", 8800)], 5: [(23, "cup95", 30000)]}))})
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
                                "--saida", str(saida)], capture_output=True, encoding="utf-8", env=AMBIENTE)
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
            us = [(u["periodo"], u["dia_inicio"], u["fabricante"], u["codigo"], u["preco"])
                  for u in csv.DictReader(open(saida / "usados.csv", encoding="utf-8"))]
            if us != [("0", "0", "Honda", "hat93", "9000"), ("1", "10", "Honda", "hat93", "9000"),
                      ("2", "20", "Honda", "hat93", "8800"), ("5", "50", "Nissan", "cup95", "30000")]:
                falhas.append(f"bruto={bruto}: usados {us}")
            ev = list(csv.DictReader(open(saida / "eventos.csv", encoding="utf-8")))
            if not ev or (ev[0]["evento"], ev[0]["pista"], ev[0]["voltas"], ev[0]["licenca"], ev[0]["tracao"],
                          ev[0]["premios_x100"], ev[0]["carros_premio"], ev[0]["adversarios"]) != (
                    "SND0001", "mountain", "3", "B", "FF", "25 15 0 0 0 0", "cup95", "4 7"):
                falhas.append(f"bruto={bruto}: eventos {ev}")
    # Importador sobre a saída do extrator.
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        img = tmp / "disco.iso"
        img.write_bytes(iso("GT2.VOL", vol, False))
        subprocess.run([sys.executable, str(raiz / "tools/extrair_gt2.py"), "--disco", str(img), "--saida", str(tmp / "gt2")],
                       capture_output=True, check=True, env=AMBIENTE)
        (tmp / "ref.csv").write_text(
            "id,nome,fabricante,arquetipo,categoria,tracao,ref_real,codigo_gt2\n"
            "hayase_x,Hayase X,hayase,hatch,compacto,FF,Hatch Teste,hat93\n"
            "hartwig_y,Hartwig Y,hartwig,cupe,cupe,FR,Cupe Turbo,cup95\n", encoding="utf-8")
        dados = tmp / "data"
        dados.mkdir()
        for arq in ("economia", "carreira"):
            (dados / f"{arq}.json").write_text((raiz / "data" / f"{arq}.json").read_text(encoding="utf-8"))
        r = subprocess.run([sys.executable, str(raiz / "tools/importar_gt2.py"), "--gt2", str(tmp / "gt2"),
                            "--ref", str(tmp / "ref.csv"), "--data", str(dados)], capture_output=True, encoding="utf-8", env=AMBIENTE)
        if r.returncode:
            falhas.append(f"importador falhou: {r.stderr.strip()[-500:]}")
        else:
            import json
            carregar = lambda n: json.loads((dados / f"{n}.json").read_text(encoding="utf-8"))
            carros = {c["id"]: c for c in carregar("carros")}
            x, y = carros["hayase_x"], carros["hartwig_y"]
            if x.get("usados") != [[0, 19, 9000], [20, 29, 8800]] or y.get("usados") != [[50, 59, 30000]]:
                falhas.append(f"importador usados: {x.get('usados')} {y.get('usados')}")
            if (x["potencia"], x["peso"], x["preco"], x["ano"], x["tracao"], y["tracao"]) != (160, 1050, 17500, 1993, "FF", "FR"):
                falhas.append(f"importador carros: {x} {y}")
            # aderência: médias 89 e 97, mediana 93; freio: 40 e 60, mediana 50
            if (x["aderencia"], y["aderencia"], x["freio"], y["freio"]) != (round(89 / 93, 3), round(97 / 93, 3), 0.8, 1.0):
                falhas.append(f"importador normalização: {x} {y}")
            pecas = {p["id"]: p for p in carregar("pecas")}
            esperado = {"hayase_x_natune_1": ("aspiracao", "potencia", 16.0, 4000),
                        "hartwig_y_turbinekit_2": ("aspiracao", "potencia", 112.0, 20000),
                        "hayase_x_lightweight_1": ("lightweight", "peso", 0.9, 2500),
                        "hayase_x_brake_1": ("brake", "freio", 1.25, 3500)}
            for pid, (cat, attr, val, preco) in esperado.items():
                p = pecas.get(pid)
                if not p or (p["categoria"], p["efeitos"][0]["atributo"], p["efeitos"][0]["valor"], p["preco"]) != (cat, attr, val, preco):
                    falhas.append(f"importador peça {pid}: {p}")
            pneus = {p["id"]: p for p in carregar("pneus")}
            if pneus.get("pneu_1", {}).get("aderencia") != {"seco": 1.034, "chuva": 1.034} or pneus["pneu_1"]["preco"] != 2000:
                falhas.append(f"importador pneus: {pneus}")
            ev = carregar("eventos")
            if len(ev) != 1 or ev[0]["restricoes"] != {"potencia_max": 200, "tracao": ["FF"], "licenca": "B"} \
                    or (ev[0]["nome"], ev[0]["pista"]) != ("Copa de Domingo — etapa 1", "serra_alta") \
                    or ev[0]["premios"] != [2500, 1500] or ev[0]["carro_premio"] != "hartwig_y" \
                    or [a["carro"] for a in ev[0]["adversarios"]] != ["hayase_x", "hayase_x"]:
                falhas.append(f"importador eventos: {ev}")
            lic = carregar("licencas")
            if [l["id"] for l in lic] != ["B", "A", "IC", "IB", "IA"] \
                    or [l["requisito"] for l in lic] != [None, "B", "A", "IC", "IB"] \
                    or lic[0]["testes"][0]["restricoes"] != {"potencia_max": 200}:
                falhas.append(f"importador licenças: {lic}")
    # Modo --pasta com arquivos soltos (como sai de uma ferramenta de VOL).
    with tempfile.TemporaryDirectory() as tmp:
        pasta = pathlib.Path(tmp) / "vol"
        (pasta / "carparam").mkdir(parents=True)
        import vol as gtvol
        indice = gtvol.ler_indice(vol)
        for nome, (ini, tam) in indice.items():
            (pasta / "carparam" / nome).write_bytes(vol[ini:ini + tam])
        saida = pathlib.Path(tmp) / "saida"
        r = subprocess.run([sys.executable, str(raiz / "tools/extrair_gt2.py"), "--pasta", str(pasta),
                            "--saida", str(saida)], capture_output=True, encoding="utf-8", env=AMBIENTE)
        if r.returncode or not (saida / "carros.csv").exists():
            falhas.append(f"pasta: {r.stderr.strip()[-400:]}")
    for f in falhas:
        print("FAIL extrator GT2: " + f)
    if not falhas:
        print("ok   extrator GT2 (disco sintético ISO, bruto e pasta)")
    return 1 if falhas else 0


if __name__ == "__main__":
    raise SystemExit(main())
