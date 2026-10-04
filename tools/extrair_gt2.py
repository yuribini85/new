#!/usr/bin/env python3
"""Extrai as tabelas do Gran Turismo 2 de uma cópia legítima do disco.

Uso (qualquer uma das entradas):
  tools/extrair_gt2.py --disco "Gran Turismo 2 (Simulation).bin"
  tools/extrair_gt2.py --vol GT2.VOL
  tools/extrair_gt2.py --pasta pasta_com_os_dat/

Saída em referencia/gt2/ (no .gitignore, nunca versionar):
  <Tabela>.csv      uma linha por estrutura, todos os campos
  carros.csv        resumo por carro: código, nome, ano, preço, potência,
                    peso, tração e índices das peças de fábrica
  eventos.csv       resumo por evento: nome, pista, voltas, licença,
                    restrições, prêmios, carros-prêmio, adversários
  usados.csv        ofertas de usados: período (10 dias), fabricante, código, preço
"""
from __future__ import annotations

import argparse
import csv
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "gt2"))
import tabelas  # noqa: E402
import vol as gtvol  # noqa: E402

# Saída em UTF-8 também no Windows (o console padrão lá é cp1252).
for _fluxo in (sys.stdout, sys.stderr):
    if hasattr(_fluxo, "reconfigure"):
        _fluxo.reconfigure(encoding="utf-8", errors="replace")


LICENCAS = {0: "", 1: "B", 2: "A", 3: "IC", 4: "IB", 5: "IA", 6: "S"}
TRACOES_EVENTO = {0: "", 1: "FF", 2: "FR", 3: "MR", 4: "RR", 5: "4WD"}


def carregar_arquivos(args) -> dict[str, bytes]:
    """Retorna {'gtmode_data', 'gtmode_race', 'unistrdb'} em bytes, descompactados."""
    if args.pasta:
        pasta = pathlib.Path(args.pasta)
        arquivos = {p.relative_to(pasta).as_posix(): p for p in pasta.rglob("*") if p.is_file()}
        def achar(sufixo):
            # Mesmo critério de região do VOL; aqui o "VOL" é a pasta.
            indice = {nome: (0, 0) for nome in arquivos}
            nome = gtvol.escolher(indice, sufixo, args.regiao)
            d = arquivos[nome].read_bytes()
            return nome, gtvol.descompactar(d) if d[:2] == b"\x1f\x8b" else d
    else:
        if args.disco:
            import disco as gtdisco
            d = gtdisco.Disco(pathlib.Path(args.disco))
            try:
                dados_vol = d.extrair("GT2.VOL")
            finally:
                d.fechar()
        else:
            dados_vol = pathlib.Path(args.vol).read_bytes()
        indice = gtvol.ler_indice(dados_vol)
        def achar(sufixo):
            return gtvol.extrair(dados_vol, indice, sufixo, args.regiao)

    lidos = {}
    for chave, sufixo in (("gtmode_data", "gtmode_data.dat"), ("gtmode_race", "gtmode_race.dat"),
                          ("unistrdb", "unistrdb.dat"), ("usados", ".usedcar")):
        try:
            nome, lidos[chave] = achar(sufixo)
        except FileNotFoundError:
            if chave == "usados":
                print("aviso: lista de usados (.usedcar) não encontrada", file=sys.stderr)
                continue
            raise
        print(f"{chave}: {nome} ({len(lidos[chave])} bytes)", file=sys.stderr)
    return lidos


def gravar_csv(caminho: pathlib.Path, linhas: list[dict]) -> None:
    if not linhas:
        return
    colunas = list(linhas[0].keys())
    with open(caminho, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=colunas)
        w.writeheader()
        for l in linhas:
            w.writerow({k: (" ".join(map(str, v)) if isinstance(v, list) else v) for k, v in l.items()})


def texto(lista: list[str], i: int) -> str:
    return lista[i] if 0 <= i < len(lista) else f"#{i}"


def resumir_carros(t: dict, nomes: list[str]) -> list[dict]:
    r = []
    for c in t["Car"]:
        motor = t["Engine"][c["Engine"]] if c["Engine"] < len(t["Engine"]) else {}
        chassi = t["Chassis"][c["Chassis"]] if c["Chassis"] < len(t["Chassis"]) else {}
        trans = t["Drivetrain"][c["Drivetrain"]] if c["Drivetrain"] < len(t["Drivetrain"]) else {}
        r.append({
            "codigo": tabelas.id_para_nome(c["CarId"]),
            "nome": (texto(nomes, c["NameFirstPart"]) + " " + texto(nomes, c["NameSecondPart"])).strip(),
            "ano": c["Year"],
            "preco": c["Price"],
            "potencia_ps": motor.get("DisplayedPower"),
            "rpm_potencia": motor.get("MaxPowerRPM", 0) * 10,
            "peso_kg": chassi.get("Weight"),
            "aderencia_dianteira": chassi.get("FrontGrip"),
            "aderencia_traseira": chassi.get("RearGrip"),
            "tracao_tipo": trans.get("DrivetrainType"),
            "fabricante_id": c["ManufacturerID"],
        })
    return r


def resumir_eventos(t: dict, textos: list[str]) -> list[dict]:
    r = []
    for e in t["Event"]:
        r.append({
            "evento": texto(textos, e["EventName"]),
            "pista": texto(textos, e["TrackName"]),
            "voltas": e["Laps"],
            "licenca": LICENCAS.get(e["Licence"], e["Licence"]),
            "limite_ps": e["PSRestriction"],
            "tracao": TRACOES_EVENTO.get(e["DrivetrainRestriction"], e["DrivetrainRestriction"]),
            "restricao_carros": e["EligibleCarsRestriction"],
            "rally": e["IsRally"],
            "premios_x100": " ".join(str(e[f"PrizeMoney{p}"]) for p in ("1st", "2nd", "3rd", "4th", "5th", "6th")),
            "bonus_campeonato_x100": e["SeriesChampBonus"],
            "carros_premio": " ".join(tabelas.id_para_nome(i) for i in e["PrizeCars"] if i),
            "adversarios": " ".join(str(e[f"Opponent{k}"]) for k in range(1, 17) if e[f"Opponent{k}"]),
        })
    return r


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--disco")
    g.add_argument("--vol")
    g.add_argument("--pasta")
    ap.add_argument("--saida", default="referencia/gt2")
    ap.add_argument("--regiao", default="usa", help="prefixo preferido (usa, eng, jpn...)")
    args = ap.parse_args()

    arquivos = carregar_arquivos(args)
    data = tabelas.ler_gtmode_data(arquivos["gtmode_data"])
    race, textos_race = tabelas.ler_gtmode_race(arquivos["gtmode_race"])
    nomes = tabelas.ler_unistrdb(arquivos["unistrdb"])

    usados = tabelas.ler_usados(arquivos["usados"]) if "usados" in arquivos else []
    resumo_carros = resumir_carros(data, nomes)
    resumo_eventos = resumir_eventos(race, textos_race)
    saida = pathlib.Path(args.saida)
    saida.mkdir(parents=True, exist_ok=True)
    (saida / ".gdignore").touch()
    for nome, linhas in {**data, **race}.items():
        if linhas and "CarId" in linhas[0]:
            for l in linhas:
                l["CarId"] = tabelas.id_para_nome(l["CarId"])
        gravar_csv(saida / f"{nome}.csv", linhas)
    gravar_csv(saida / "carros.csv", resumo_carros)
    gravar_csv(saida / "eventos.csv", resumo_eventos)
    gravar_csv(saida / "usados.csv", usados)
    for nome, linhas in {**data, **race}.items():
        print(f"{nome:24s} {len(linhas):5d}", file=sys.stderr)
    print(f"Tabelas gravadas em {saida}/", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
