class_name Elegibilidade
extends RefCounted
## Restrições de entrada dos eventos, no estilo do GT2. Todas opcionais; um
## evento sem restrições aceita qualquer carro.
##   potencia_max  cv efetivos, já com peças (como o GT2 mede)
##   tracao        lista de trações aceitas
##   categoria     lista de categorias aceitas
##   fabricante    lista de fabricantes aceitas
##   ano_min / ano_max
##   licenca       id da licença exigida do jogador

const RESTRICOES := ["potencia_max", "tracao", "categoria", "fabricante", "ano_min", "ano_max", "licenca"]


## Motivos pelos quais o carro não pode entrar; vazio se pode.
static func motivos(carro: Carro, restricoes: Dictionary, licencas: Array) -> Array:
	var m := []
	var base := carro.base
	if restricoes.has("potencia_max"):
		var potencia: float = carro.atributos_efetivos("seco")["potencia"]
		if potencia > float(restricoes["potencia_max"]):
			m.append("potência %d acima de %d cv" % [potencia, restricoes["potencia_max"]])
	for chave in ["tracao", "categoria", "fabricante"]:
		if restricoes.has(chave) and not base[chave] in restricoes[chave]:
			m.append("%s %s não aceita" % [chave, base[chave]])
	if restricoes.has("ano_min") and int(base["ano"]) < int(restricoes["ano_min"]):
		m.append("ano %d antes de %d" % [base["ano"], restricoes["ano_min"]])
	if restricoes.has("ano_max") and int(base["ano"]) > int(restricoes["ano_max"]):
		m.append("ano %d depois de %d" % [base["ano"], restricoes["ano_max"]])
	if restricoes.has("licenca") and not restricoes["licenca"] in licencas:
		m.append("exige licença %s" % restricoes["licenca"])
	return m
