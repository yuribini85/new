#!/usr/bin/env python3
"""Gera referencia/carros.csv com todos os carros do GT2, cada um com fabricante e
nome fictícios (o nome real fica só em ref_real, fora do Git).

Uso: python3 tools/gerar_referencia_carros.py [--gt2 referencia/gt2] [--ref referencia/carros.csv]

Regras (CLAUDE.md: nada do GT2 entra no build):
  fabricante  um fictício por fabricante do GT2 (FABRICANTES, pelo número interno);
              os três do primeiro build ficam com uma marca cada.
  modelo      um nome por família (o primeiro nome do modelo no GT2, sem a marca),
              palavra inventada no idioma da escola do fabricante; nunca um nome de
              modelo real (PROIBIDOS) nem repetido.
  versão      dentro da família, por potência: base, S, GT, GTS, R, SR, GX, SX; versões de
              corrida (código terminado em "r") são "Corrida". O ano entra no nome
              quando a família tem mais de um ano.
  categoria   compacto, sedã, cupê ou roadster (as silhuetas que o jogo desenha),
              pelo tipo de carroceria do nome e pelo peso.
Os carros que já existem em referencia/carros.csv (os 17 do primeiro build)
mantêm id, nome, fabricante, arquétipo e categoria.
Também escreve data/fabricantes.json com os fabricantes novos (os existentes
mantêm nome e história).
"""
from __future__ import annotations

import argparse
import collections
import csv
import json
import pathlib
import random
import re
import unicodedata

RAIZ = pathlib.Path(__file__).resolve().parent.parent

# Número interno do fabricante no GT2 -> (id, nome, escola, país). Nomes inventados;
# busca de marca pendente antes do lançamento (data/README.md).
FABRICANTES = {
    "0": ("arvelle", "Arvelle", "us", "Estados Unidos"),
    "1": ("varenna", "Varenna", "it", "Itália"),
    "2": ("wexmoor", "Wexmoor", "uk", "Reino Unido"),
    "3": ("vorhaus", "Vorhaus", "de", "Alemanha"),
    "4": ("ostwerk", "Ostwerk", "de", "Alemanha"),
    "5": ("bancroft", "Bancroft", "us", "Estados Unidos"),
    "6": ("morel", "Morel", "fr", "França"),
    "7": ("tomoe", "Tomoe", "jp", "Japão"),
    "8": ("garrison", "Garrison Motors", "us", "Estados Unidos"),
    "9": ("ottavo", "Ottavo", "it", "Itália"),
    "10": ("whitlock", "Whitlock", "us", "Estados Unidos"),
    "11": ("hozuki", "Hozuki", "jp", "Japão"),
    "13": ("calderwood", "Calderwood", "uk", "Reino Unido"),
    "14": ("castellani", "Castellani", "it", "Itália"),
    "16": ("thornby", "Thornby", "uk", "Reino Unido"),
    "17": ("pemberly", "Pemberly", "uk", "Reino Unido"),
    "18": ("mizuchi", "Mizuchi", "jp", "Japão"),
    "19": ("keldorf", "Keldorf", "de", "Alemanha"),
    "21": ("dunmere", "Dunmere", "uk", "Reino Unido"),
    "22": ("sanga", "Sanga Motors", "jp", "Japão"),
    "23": ("hayase", "Hayase Motor", "jp", "Japão"),
    "24": ("lindauer", "Lindauer", "de", "Alemanha"),
    "25": ("saulieu", "Saulieu", "fr", "França"),
    "26": ("ashby", "Ashby", "us", "Estados Unidos"),
    "27": ("vallon", "Vallon", "fr", "França"),
    "28": ("rauhe", "Rauhe", "de", "Alemanha"),
    "29": ("cutler", "Cutler", "us", "Estados Unidos"),
    "30": ("hoshino", "Hoshino", "jp", "Japão"),
    "31": ("kosame", "Kosame", "jp", "Japão"),
    "32": ("tokiwa", "Tokiwa Works", "jp", "Japão"),
    "33": ("kanaya", "Kanaya", "jp", "Japão"),
    "34": ("ashcombe", "Ashcombe Cars", "uk", "Reino Unido"),
    "35": ("brayford", "Brayford", "uk", "Reino Unido"),
    "36": ("kestrin", "Kestrin", "us", "Estados Unidos"),
    "37": ("aubrac", "Aubrac", "fr", "França"),
    "38": ("hartwig", "Hartwig", "de", "Alemanha"),
}

# Palavras por escola (substantivos comuns: aves, vento, paisagem), no estilo dos
# modelos do primeiro build. Acabando a lista, gera por sílabas.
PALAVRAS = {
    "jp": ["Akatsuki", "Arashi", "Fubuki", "Hayate", "Hibari", "Hotaru", "Inazuma", "Kagero", "Kamome", "Kasumi",
           "Kogarashi", "Kohaku", "Mizore", "Momiji", "Nagi", "Nowaki", "Oboro", "Ryusei", "Samidare", "Sazanami",
           "Seiran", "Shigure", "Shinonome", "Shiranui", "Sora", "Suzaku", "Tsubasa", "Tsukikage", "Uzushio",
           "Wakaba", "Yamabiko", "Yoake", "Yukikaze", "Hagane", "Kagura", "Kaminari", "Kikyo", "Komorebi",
           "Mikazuki", "Nishiki", "Shirasagi", "Tobi", "Tsumuji", "Yugure", "Akane", "Aoi", "Botan", "Chidori",
           "Fuyu", "Hanabi", "Hiiragi", "Ibuki", "Kairo", "Kazahana", "Kirameki", "Kurenai", "Madoka", "Matsuri",
           "Minamo", "Murasame", "Rindo", "Sawarabi", "Senko", "Shiokaze", "Suzukaze", "Takane", "Tsurara",
           "Umikaze", "Yuzuki", "Asagiri", "Awayuki", "Benibana", "Enju", "Gekko", "Harusame", "Hiryu", "Homura",
           "Jinrai", "Kaede", "Kagaribi", "Kamui", "Kasasagi", "Kiri", "Kogane", "Kujaku", "Kurogane", "Mizuho",
           "Nadeshiko", "Natsuzora", "Niji", "Oborozuki", "Raijin", "Reimei", "Sekirei", "Shirakumo", "Shizuku",
           "Suisei", "Tatsumaki", "Tenku", "Tokage", "Tomoshibi", "Tsubaki", "Tsuyu", "Unabara", "Urara", "Usagi",
           "Wadachi", "Yaiba", "Yamakaze", "Yanagi", "Yozora", "Yukihana", "Zakuro", "Hakucho", "Kawasemi", "Mozu",
           "Shijima", "Tobiuo", "Uguisu", "Ginga", "Seiryu", "Byakko", "Hiten", "Tenma", "Kazaguruma", "Nagare",
           "Isaribi", "Hatsukaze", "Asakaze", "Yukimi", "Kagami", "Amagumo", "Murakumo", "Akebono", "Kogetsu",
           "Sekka", "Gunjo", "Ruri", "Sango", "Hisui", "Shinku", "Hokuto", "Kazane", "Mikage", "Tsukishiro"],
    "uk": ["Bramble", "Cinder", "Drover", "Ember", "Fen", "Fletcher", "Gale", "Gannet", "Heron", "Linnet",
           "Merlin", "Moorland", "Plover", "Quarry", "Rook", "Saltire", "Shrike", "Skerry", "Sloe", "Swale",
           "Tarn", "Thistle", "Tor", "Wold", "Yarrow", "Bittern", "Curlew", "Dunlin", "Fieldfare", "Heath",
           "Keel", "Nettle", "Quill", "Rowan", "Sedge", "Sorrel", "Teal", "Thrush", "Wherry", "Brook"],
    "us": ["Canyon", "Coyote", "Drifter", "Flint", "Gulch", "Hatchet", "Ironwood", "Juniper", "Mesa", "Outlaw",
           "Rattler", "Sagebrush", "Sidewinder", "Tumbleweed", "Badlands", "Bison", "Cutbank", "Longhorn",
           "Palomino", "Pecos", "Redrock", "Saddle", "Stockade", "Thunderhead", "Wildfire", "Yucca", "Boxcar",
           "Cottonwood", "Highline", "Ozark", "Shamrock", "Bluff", "Arroyo", "Granite", "Kingfisher", "Caliche",
           "Switchback", "Tailwind", "Driftwood", "Prairie Hawk", "Bootleg", "Cinderblock", "Dustbowl"],
    "it": ["Corvo", "Falco", "Grillo", "Lampo", "Nebbia", "Onda", "Passo", "Sasso", "Tufo", "Volpe", "Zefiro",
           "Allodola", "Brina", "Faro", "Gabbiano", "Lucciola", "Merlo", "Picchio", "Rondine", "Tempesta",
           "Torrente", "Airone", "Fiume", "Ghiaia", "Bora"],
    "fr": ["Alouette", "Brume", "Caillou", "Ecume", "Faucon", "Grive", "Hirondelle", "Loriot", "Orage",
           "Perdrix", "Sillage", "Tramontane", "Vague", "Givre", "Bruyere", "Cigale", "Galet", "Rafale d'Est"],
    "de": ["Amsel", "Bergfink", "Bussard", "Dohle", "Eisvogel", "Falke", "Fink", "Graupel", "Habicht", "Hagel",
           "Kranich", "Kiebitz", "Lerche", "Milan", "Nebel", "Pirol", "Rabe", "Reiher", "Sperber", "Sturm",
           "Taucher", "Uhu", "Wachtel", "Wiesel", "Zeisig", "Dachs", "Fuchs", "Luchs", "Marder", "Otter",
           "Biber", "Igel", "Steinbock", "Elster", "Specht", "Schwalbe", "Gischt", "Rauhreif", "Kauz", "Kolkrabe"],
}
SILABAS_JP = ["ka", "ki", "ku", "ke", "ko", "sa", "shi", "su", "se", "so", "ta", "chi", "tsu", "te", "to",
              "na", "ni", "no", "ha", "hi", "fu", "ho", "ma", "mi", "mu", "me", "mo", "ya", "yu", "yo",
              "ra", "ri", "ru", "re", "ro", "wa", "ga", "gi", "go", "za", "ji", "zu", "da", "de", "do", "ba", "bi", "be"]

# Nunca usar: modelos reais conhecidos (lista de checagem, não exaustiva) e os
# nomes já em uso. Comparação sem acento e sem caixa.
PROIBIDOS = set("""
mustang viper cobra corvette camaro charger challenger stratus neon intrepid avenger taurus escort focus
mondeo puma cougar fiesta ka probe thunderbird maverick pinto ranger bronco explorer
civic accord prelude integra legend beat life logo today insight stream jazz fit city odyssey
skyline silvia march cube primera sunny bluebird laurel cedric gloria fairlady leopard cefiro presea
celica supra corolla corona camry chaser cresta mark soarer aristo altezza starlet vitz levin trueno
sera tercel cynos caldina windom crown century estima sprinter carina
demio familia capella cosmo eunos roadster savanna luce persona lantis
lancer galant eclipse mirage minica legnum pajero delica sigma starion colt carisma
impreza legacy forester vivio pleo alcyone justy rex leone
alto cervo cultus swift escudo capuccino cappuccino kei wagon jimny vitara
mira move opti storia terios charade copen sonica cuore
astra corsa tigra vectra calibra kadett manta omega
golf polo lupo jetta passat scirocco corrado beetle vento bora
clio megane espace laguna twingo alpine safrane
saxo xsara xantia
delta stratos thema prisma ypsilon
punto barchetta uno tipo panda bravo brava marea coupe seicento cinquecento
spider brera giulia giulietta alfasud
elise elan esprit europa exige excel eclat
cerbera chimaera griffith tuscan sagaris
cooper mini metro maestro montego
storm phaeton concept
superbird cuda gtx barracuda roadrunner fury
kestrel wren brute kobo pika tsubame kaze rin soryu raikou shiden tenrai kumo ryujin lauf strecke gleiter
hayabusa kirin asahi yamaha kawasaki
""".split())

TRIMS = ["", "S", "GT", "GTS", "R", "SR", "GX", "SX"]
CORPO = {
    "roadster": r"\b(spider|spyder|roadster|barchetta|cabrio\w*|convertible|speedster|mx-5|miata|elise|elan|s2000|"
                r"beat|capp?u?cino|cobra|europa|slk|tt roadster|mgf|midget|chimaera|griffith|cerbera|z3)\b",
    "seda": r"\b(sedan|4 ?door|saloon|wagon|estate|touring wagon|legacy|galant|accord|mondeo|laguna|vectra|taurus|"
            r"intrepid|stratus|chaser|aristo|altezza|xantia|corona|caldina|forester|espace|pajero|escudo|terios|"
            r"406|156|155|166|a4|s4|328i|528i|740i|xj\b|lancer|impreza|legnum|cube|storia|move)",
    "compacto": r"\b(civic|march|demio|mira|alto|vivio|pleo|mini|punto|106|206|306|clio|saxo|corsa|lupo|golf|"
                r"ka\b|y 1|kei|wagon r|logo|life|cultus|opti|minica|mirage|starlet|vitz|a3|s3|a160|500|600|"
                r"tigra|astra|neon|xsara|cr-x|az-1|move)",
}


def sem_acento(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").lower()


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", sem_acento(s)).strip("_")


def limpar(nome: str) -> list[str]:
    s = re.sub(r"\(.*?\)", " ", nome)
    s = re.sub(r"'\d\d", " ", s)
    return s.split()


def marcas_por_fabricante(carros: list[dict]) -> dict[str, set[str]]:
    """Primeira palavra que é marca: vem antes de palavras que, em outros nomes do
    mesmo fabricante, abrem o nome (ex.: "<marca> <modelo>" e "<modelo> ..."), ou abre
    a maioria dos nomes e vem antes de pelo menos dois modelos frequentes."""
    por = collections.defaultdict(list)
    for c in carros:
        por[c["fabricante_id"]].append(limpar(c["nome"]))
    marcas = {}
    for fab, nomes in por.items():
        primeiras = collections.Counter(t[0] for t in nomes if t)
        seguintes = collections.defaultdict(set)
        for t in nomes:
            if len(t) > 1:
                seguintes[t[0]].add(t[1])
        segundas = collections.Counter(t[1] for t in nomes if len(t) > 1)
        marcas[fab] = {p for p, segs in seguintes.items() if primeiras[p] >= 3
                       and (sum(1 for s in segs if primeiras.get(s, 0) > 0) >= 1
                            # ou abre a maioria dos nomes e vem antes de dois modelos frequentes
                            or (primeiras[p] >= 0.6 * len(nomes) and sum(1 for s in segs if segundas[s] >= 3) >= 2))}
    return marcas


def familia(nome: str, marcas: set[str]) -> str:
    t = limpar(nome)
    while t and t[0] in marcas and len(t) > 1:
        t = t[1:]
    return t[0] if t else nome


def ano_de(c: dict) -> int:
    a = int(c["ano"] or 0)
    if a > 0:
        return a + 1900 if a < 100 else a
    m = re.search(r"'(\d\d)", c["nome"])
    if m:
        a = int(m.group(1))
        return 1900 + a if a > 30 else 2000 + a
    return 0


def categoria(c: dict) -> str:
    nome = sem_acento(c["nome"])
    for cat in ("roadster", "seda", "compacto"):
        if re.search(CORPO[cat], nome):
            return cat
    peso = int(c["peso_kg"] or 0)
    return "compacto" if 0 < peso < 950 else "cupe"


TRACAO = {"0": "FR", "1": "FF", "2": "4WD", "3": "MR", "4": "RR"}
NOME_CAT = {"compacto": "compacto", "seda": "sedã", "cupe": "cupê", "roadster": "roadster"}


def arquetipo(c: dict, cat: str, corrida: bool) -> str:
    ps = int(c["potencia_ps"] or 0)
    faixa = "até 100 cv" if ps <= 100 else ("até 200 cv" if ps <= 200 else ("até 300 cv" if ps <= 300 else
            ("até 450 cv" if ps <= 450 else "acima de 450 cv")))
    return f'{"carro de corrida " if corrida else ""}{NOME_CAT[cat]} {TRACAO.get(c["tracao_tipo"], "FR")} {faixa}'


class Nomes:
    """Sorteia nomes de modelo por escola, sem repetir nem cair em PROIBIDOS."""

    def __init__(self, usados: set[str]):
        self.rng = random.Random(2)
        self.usados = {sem_acento(u) for u in usados}
        self.filas = {k: self.rng.sample(v, len(v)) for k, v in PALAVRAS.items()}

    def novo(self, escola: str) -> str:
        fila = self.filas.get(escola, [])
        while fila:
            p = fila.pop()
            if self._livre(p):
                return self._usar(p)
        for _ in range(10000):
            p = "".join(self.rng.choice(SILABAS_JP) for _ in range(self.rng.choice([2, 3, 3]))).capitalize()
            if escola != "jp":
                p = p + self.rng.choice(["en", "er", "ar", "o", "a"]) if escola in ("de", "it") else p
            if 4 <= len(p) <= 9 and self._livre(p):
                return self._usar(p)
        raise SystemExit("sem nomes livres")

    def _livre(self, p: str) -> bool:
        s = sem_acento(p)
        return s not in self.usados and s not in PROIBIDOS and not any(s == q for q in PROIBIDOS)

    def _usar(self, p: str) -> str:
        self.usados.add(sem_acento(p))
        return p


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--gt2", default=str(RAIZ / "referencia" / "gt2"))
    ap.add_argument("--ref", default=str(RAIZ / "referencia" / "carros.csv"))
    ap.add_argument("--fabricantes", default=str(RAIZ / "data" / "fabricantes.json"))
    args = ap.parse_args()
    gt2 = list(csv.DictReader(open(pathlib.Path(args.gt2) / "carros.csv", encoding="utf-8")))
    ref_path = pathlib.Path(args.ref)
    antigos = list(csv.DictReader(open(ref_path, encoding="utf-8"))) if ref_path.exists() else []
    campos = list(antigos[0].keys()) if antigos else ["id", "nome", "fabricante", "arquetipo", "categoria", "tracao",
                                                      "ano", "ref_real", "codigo_gt2"]
    for extra in ("ano", "ref_real", "codigo_gt2"):
        if extra not in campos:
            campos.append(extra)
    por_codigo = {l["codigo_gt2"]: l for l in antigos if l.get("codigo_gt2")}
    marcas = marcas_por_fabricante(gt2)
    # Família -> nome do modelo. Os modelos atuais reservam o nome da família deles.
    fam_nome: dict[tuple[str, str], str] = {}
    usados = {l["nome"].split()[-1] for l in antigos}
    for l in antigos:
        c = next((x for x in gt2 if x["codigo"] == l["codigo_gt2"]), None)
        if c:
            usados.add(l["nome"].split()[-1])
    nomes = Nomes(usados)
    familias = collections.defaultdict(list)
    for c in gt2:
        familias[(c["fabricante_id"], familia(c["nome"], marcas.get(c["fabricante_id"], set())))].append(c)
    linhas = []
    ids = {l["id"] for l in antigos}
    nomes_completos = {l["nome"] for l in antigos}
    for (fab, fam), membros in sorted(familias.items(), key=lambda kv: (int(kv[0][0]), kv[0][1])):
        f_id, f_nome, escola, _ = FABRICANTES[fab]
        rua = sorted([c for c in membros if not c["codigo"].endswith("r")], key=lambda c: (int(c["potencia_ps"] or 0), ano_de(c)))
        corrida = sorted([c for c in membros if c["codigo"].endswith("r")], key=lambda c: (int(c["potencia_ps"] or 0), ano_de(c)))
        modelo = None
        anos = {ano_de(c) for c in membros if ano_de(c) > 0}
        # Versão pela posição de potência na família (5 degraus).
        potencias = sorted({int(c["potencia_ps"] or 0) for c in rua})
        for c in rua + corrida:
            if c["codigo"] in por_codigo:
                linhas.append(por_codigo[c["codigo"]])
                continue
            if modelo is None:
                modelo = nomes.novo(escola)
            eh_corrida = c["codigo"].endswith("r")
            if eh_corrida:
                trim = "Corrida"
            else:
                i = potencias.index(int(c["potencia_ps"] or 0))
                passos = min(len(TRIMS), len(potencias))
                trim = TRIMS[round(i * (passos - 1) / max(1, len(potencias) - 1))] if len(potencias) > 1 else ""
            ano = ano_de(c)
            base = " ".join(x for x in [f_nome.split()[0], modelo, trim] if x)
            nome = base
            if nome in nomes_completos and ano > 0 and len(anos) > 1:
                nome = f"{base} '{ano % 100:02d}"
            k = 2
            while nome in nomes_completos:
                nome = f"{base} {['', '', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'][k] if k <= 10 else k}"
                k += 1
            nomes_completos.add(nome)
            cid = slug(nome)
            while cid in ids:
                cid += "_b"
            ids.add(cid)
            cat = categoria(c)
            linha = {k2: "" for k2 in campos}
            linha.update({"id": cid, "nome": nome, "fabricante": f_id, "arquetipo": arquetipo(c, cat, eh_corrida),
                          "categoria": cat, "tracao": TRACAO.get(c["tracao_tipo"], "FR"), "ano": str(ano or ""),
                          "ref_real": c["nome"], "codigo_gt2": c["codigo"]})
            linhas.append(linha)
    with open(ref_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=campos)
        w.writeheader()
        w.writerows(linhas)
    # Fabricantes: os existentes como estão; os novos com nome, escola e país.
    fab_path = pathlib.Path(args.fabricantes)
    existentes = json.load(open(fab_path, encoding="utf-8")) if fab_path.exists() else []
    vistos = {f["id"] for f in existentes}
    usados_fab = {l["fabricante"] for l in linhas}
    for f_id, f_nome, escola, pais in FABRICANTES.values():
        if f_id in usados_fab and f_id not in vistos:
            existentes.append({"id": f_id, "nome": f_nome, "escola": escola, "pais": pais})
            vistos.add(f_id)
    fab_path.write_text(json.dumps(existentes, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(linhas)} carros em {ref_path} ({len(antigos)} mantidos) · {len(existentes)} fabricantes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
