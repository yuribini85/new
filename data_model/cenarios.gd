class_name Cenarios
extends RefCounted
## Saves de teste (documento de implementação, seção 36): pontos da história
## montados em código a partir de um jogo novo, para o playtest começar onde
## precisa. As cenas dos capítulos já vividos ficam vistas e as flags delas
## gravadas, como se o jogador tivesse passado por elas. Montar não toca o
## save do jogador: o SaveManager troca para um arquivo próprio do cenário.

const LISTA := [
	{"id": "adrian_inicio", "nome": "Adrian: começo", "detalhe": "Jogo novo, prólogo do Adrian."},
	{"id": "adrian_ultima", "nome": "Adrian: antes da última corrida",
		"detalhe": "Primeiro campeonato feito: a próxima largada é a última dele."},
	{"id": "elena_inicio", "nome": "Elena: depois do acidente", "detalhe": "Garagem vazia, Second Chance Motors."},
	{"id": "elena_primeira_compra", "nome": "Elena: primeiro carro", "detalhe": "Depois da primeira compra."},
	{"id": "second_driver", "nome": "Second Driver criada",
		"detalhe": "Licenças até a INTERNATIONAL, equipe recém-criada (aba Equipe)."},
	{"id": "segundo_piloto", "nome": "Segundo piloto na equipe",
		"detalhe": "Licenças até a PRO, segundo piloto e dois carros."},
]

const ROMANOS := {"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6, "VII": 7, "VIII": 8, "IX": 9, "X": 10,
		"XI": 11, "XII": 12, "XIII": 13, "XIV": 14, "XV": 15, "XVI": 16}
## Cenas da última corrida do Adrian: ficam por ver em "adrian_ultima".
const TRIGGERS_ULTIMA := ["ULTIMA_CORRIDA_ADRIAN", "RADIO_ULTIMA_CORRIDA", "ACIDENTE", "ENCADEADA"]


## Monta o cenário no jogador. "" ou o motivo de não dar.
static func montar(dados: Node, jogador: Node, id: String) -> String:
	var erro := Prologo.iniciar(dados, jogador)
	if erro != "":
		return erro
	match id:
		"adrian_inicio":
			pass
		"adrian_ultima":
			_cenas_ate(dados, jogador, 1, TRIGGERS_ULTIMA)
			jogador.flags[String(dados.historia().get("ultima_corrida_apos", ""))] = true
		"elena_inicio", "elena_primeira_compra", "second_driver", "segundo_piloto":
			_elena(dados, jogador)
			if id != "elena_inicio":
				_comprar_usado(dados, jogador)
				_cenas_ate(dados, jogador, 3)
			if id == "second_driver":
				_licencas_ate(dados, jogador, "INTERNATIONAL")
				_cenas_ate(dados, jogador, 11)
			elif id == "segundo_piloto":
				_licencas_ate(dados, jogador, "PRO")
				_cenas_ate(dados, jogador, 14)
				EquipeJogador.liberar_segundo(dados, jogador)
				jogador.carro_companheiro = _comprar_usado(dados, jogador)
		_:
			return "cenário %s não existe" % id
	return ""


## Acidente e salto temporal, com as cenas do prólogo vistas.
static func _elena(dados: Node, jogador: Node) -> void:
	_cenas_ate(dados, jogador, 1)
	Prologo.acidente(jogador)
	Prologo.salto_temporal(dados, jogador)
	_cenas_ate(dados, jogador, 2)


## Marca como vistas as cenas até o capítulo `n` (exceto as dos triggers em
## `menos`) e grava as flags delas.
static func _cenas_ate(dados: Node, jogador: Node, n: int, menos: Array = []) -> void:
	for c in dados.lista("dialogos"):
		var cap: int = ROMANOS.get(String(c.get("capitulo", "")), 0)
		if cap == 0 or cap > n or c["trigger"] in menos:
			continue
		jogador.dialogos_vistos[c["id"]] = true
		for f in c.get("flags", []):
			jogador.flags[f] = true


static func _licencas_ate(dados: Node, jogador: Node, ultima: String) -> void:
	for lic in dados.lista("licencas"):
		if not lic["id"] in jogador.licencas:
			jogador.licencas.append(lic["id"])
		if lic["id"] == ultima:
			break


## O usado mais barato da Second Chance que o saldo paga, de um modelo que
## ainda não está na garagem; sem nenhum, o modelo mais barato do catálogo, de
## graça (é cenário de teste, não economia). Retorna o uid.
static func _comprar_usado(dados: Node, jogador: Node) -> int:
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	var lista := Prologo.second_chance(dados, jogador, ofertas)
	lista = lista.filter(func(o): return jogador.garagem.lista().all(func(c): return c.id != o["carro_id"]))
	var uid := -1
	if not lista.is_empty():
		var o: Dictionary = lista[0]
		uid = jogador.concessionaria.comprar_usado(o, dados.carro(o["carro_id"]), jogador.usados_vendidos)
	if uid < 0:
		var tem: Array = jogador.garagem.lista().map(func(c): return c.id)
		var modelos: Array = dados.lista("carros").filter(func(m): return not m["id"] in tem)
		modelos.sort_custom(func(a, b): return int(a["preco"]) < int(b["preco"]))
		var carro := Carro.new(modelos[0])
		carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		uid = jogador.garagem.adicionar(carro)
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	return uid
