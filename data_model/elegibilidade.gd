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
##   carros        lista de ids de carro aceitos (copas de marca do GT2)
##   corrida       true: só versão de corrida (kit "corrida" ou carro de corrida
##                 de fábrica); false: só carro de rua, sem o kit

const NOMES := {"tracao": "tração", "categoria": "categoria", "fabricante": "fabricante"}
const RESTRICOES := ["potencia_max", "tracao", "categoria", "fabricante", "ano_min", "ano_max", "licenca", "carros",
	"corrida"]


## Motivos pelos quais o carro não pode entrar; vazio se pode.
static func motivos(carro: Carro, restricoes: Dictionary, licencas: Array) -> Array:
	var m := []
	var base := carro.base
	if restricoes.has("potencia_max"):
		var potencia: float = carro.atributos_efetivos("seco")["potencia"]
		if potencia > float(restricoes["potencia_max"]):
			m.append("potência máx. %d cv (seu: %d)" % [restricoes["potencia_max"], potencia])
	for chave in NOMES:
		if restricoes.has(chave) and not base[chave] in restricoes[chave]:
			m.append("%s %s não aceita" % [NOMES[chave], base[chave]])
	if restricoes.has("ano_min") and int(base["ano"]) < int(restricoes["ano_min"]):
		m.append("ano %d antes de %d" % [base["ano"], restricoes["ano_min"]])
	if restricoes.has("ano_max") and int(base["ano"]) > int(restricoes["ano_max"]):
		m.append("ano %d depois de %d" % [base["ano"], restricoes["ano_max"]])
	if restricoes.has("licenca") and not restricoes["licenca"] in licencas:
		m.append("licença %s" % restricoes["licenca"])
	if restricoes.has("carros") and not base["id"] in restricoes["carros"]:
		m.append("só os modelos da copa")
	if restricoes.has("corrida") and versao_corrida(carro) != bool(restricoes["corrida"]):
		m.append("só versão de corrida" if restricoes["corrida"] else "só carro de rua (sem kit de corrida)")
	return m


## Carro de corrida de fábrica ou com o kit de corrida instalado.
static func versao_corrida(carro: Carro) -> bool:
	return bool(carro.base.get("corrida", false)) or carro.pecas.has("corrida")


## Prova aberta de entrada (como a Copa de Domingo do GT2): sem licença, sem
## lista de modelos e com prêmio. Referência para o "mais fácil" do Mercado.
static func aberta_sem_licenca(ev: Dictionary) -> bool:
	return not ev["restricoes"].has("licenca") and not ev["restricoes"].has("carros") and not ev["premios"].is_empty()
