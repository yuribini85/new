#!/usr/bin/env python3
"""Converte a tabela de referência (CSV) em data/carros.json.

A tabela é de uso interno e NÃO vai para o repositório: pode ter a coluna
`ref_real` (nome do carro do GT2 que serviu de referência), que é descartada.
Só o equivalente fictício e o arquétipo entram no jogo.

Colunas obrigatórias:
  id, nome, fabricante, arquetipo, categoria, tracao, potencia_cv, peso_kg,
  velocidade_max_kmh, preco, ano
Opcionais (vazias viram pendência no jogo):
  aderencia, freio, usado_inicio, usado_fim, usado_preco (uma janela de usado),
  ref_real (descartada)

Uso: tools/converter_carros.py referencia.csv > data/carros.json
"""
import csv
import json
import sys

TRACOES = {"FF", "FR", "MR", "RR", "4WD"}
OBRIGATORIAS = ["id", "nome", "fabricante", "arquetipo", "categoria", "tracao", "potencia_cv",
                "peso_kg", "velocidade_max_kmh", "preco", "ano"]


def numero(valor, tipo):
    valor = (valor or "").strip().replace(",", ".")
    return tipo(float(valor)) if valor else None


def converter(linhas, fabricantes):
    carros, erros, ids = [], [], set()
    for n, l in enumerate(linhas, start=2):
        faltando = [c for c in OBRIGATORIAS if not (l.get(c) or "").strip()]
        if faltando:
            erros.append(f"linha {n}: faltam {', '.join(faltando)}")
            continue
        if l["tracao"] not in TRACOES:
            erros.append(f"linha {n}: tração {l['tracao']} inválida")
        if l["fabricante"] not in fabricantes:
            erros.append(f"linha {n}: fabricante {l['fabricante']} não está em data/fabricantes.json")
        if l["id"] in ids:
            erros.append(f"linha {n}: id {l['id']} repetido")
        ids.add(l["id"])
        carro = {
            "id": l["id"].strip(),
            "nome": l["nome"].strip(),
            "fabricante": l["fabricante"].strip(),
            "arquetipo_ref": l["arquetipo"].strip(),
            "categoria": l["categoria"].strip(),
            "tracao": l["tracao"].strip(),
            "potencia": numero(l["potencia_cv"], int),
            "peso": numero(l["peso_kg"], int),
            "aderencia": numero(l.get("aderencia"), float),
            "freio": numero(l.get("freio"), float),
            "velocidade_max": numero(l["velocidade_max_kmh"], int),
            "preco": numero(l["preco"], int),
            "ano": numero(l["ano"], int),
        }
        inicio, fim = numero(l.get("usado_inicio"), int), numero(l.get("usado_fim"), int)
        preco_usado = numero(l.get("usado_preco"), int)
        if inicio is not None and fim is not None and preco_usado:
            carro["usados"] = [[inicio, fim, preco_usado]]
        carros.append(carro)
    return carros, erros


def main():
    fabricantes = {f["id"] for f in json.load(open("data/fabricantes.json", encoding="utf-8"))}
    with open(sys.argv[1], newline="", encoding="utf-8") as f:
        carros, erros = converter(csv.DictReader(f), fabricantes)
    if erros:
        sys.exit("\n".join(erros))
    print(json.dumps(carros, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
