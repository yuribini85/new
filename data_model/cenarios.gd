class_name Cenarios
extends RefCounted
## Saves de teste (documento de implementação, seção 36): pontos da história
## montados em código a partir de um jogo novo, para o playtest começar onde
## precisa. As cenas já vividas ficam vistas e as flags delas gravadas, como
## se o jogador tivesse passado por elas. Montar não toca o
## save do jogador: o SaveManager troca para um arquivo próprio do cenário.

const LISTA := [
	{"id": "dono_inicio", "nome": "Oficina: começo", "detalhe": "Jogo novo, campanha do dono com a Mara."},
	{"id": "dono_arena", "nome": "Oficina: arena aberta",
		"detalhe": "Licenças até a National e 3 carros na garagem: a Arena já abre (com a dupla completa)."},
	{"id": "carro_3d", "nome": "Carro 3D: Hozuki Catana",
		"detalhe": "Como a arena aberta, com o Hozuki Catana (modelo 3D) como carro ativo: garagem, corrida e arena."},
	{"id": "completo", "nome": "Teste completo",
		"detalhe": "Tudo liberado: todas as licenças, história e tutoriais vistos, saldo e peças de sobra, "
			+ "garagem ampliada com vários carros (o resgate com canhão incluso), pilotos de corrida e de arena "
			+ "contratados e escalados. Para testar a arena e o resto sem jogar o começo."},
]

## Teste completo: dinheiro e peças de sobra (cenário de teste, não economia),
## ampliações da garagem e os carros além dos dois usados.
const COMPLETO_SALDO := 50_000_000
const COMPLETO_PECAS := 100_000
const COMPLETO_AMPLIACOES := 4
const COMPLETO_CARROS := ["hozuki_catana", "brakhaus_sentinela", "brakhaus_colosso", "kanaya_kestrel"]
## Flags de história que o teste não liga: o topo do Grid encerraria os desafios.
const COMPLETO_SEM_FLAGS := ["GRID_TOP"]

## O primeiro carro com modelo 3D (arte/carros3d/).
const CARRO_3D := "hozuki_catana"


## Monta o cenário no jogador. "" ou o motivo de não dar.
static func montar(dados: Node, jogador: Node, id: String) -> String:
	var erro := Prologo.iniciar(dados, jogador)
	if erro != "":
		return erro
	match id:
		"dono_inicio":
			pass
		"dono_arena", "carro_3d":
			# O prólogo e as licenças vistos; a Mara apresenta a Arena na 1ª visita.
			for c in dados.lista("dialogos"):
				if c.get("personagem") is String and c["personagem"] == "dono" and not String(c["id"]).begins_with("CW_P07") \
						and c["trigger"] != "ABA:ARENA" and not String(c["trigger"]).begins_with("ARENA") \
						and not String(c["id"]).begins_with("CW_T"):  # equipe e Pro/Elite ainda não
					jogador.dialogos_vistos[c["id"]] = true
					for f in c.get("flags", []):
						jogador.flags[f] = true
			_licencas_ate(dados, jogador, "NATIONAL")
			jogador.flags["NATIONAL_COMPLETE"] = true
			# Decisão 85: a garagem do dono começa vazia; o carro da Mara chega na National.
			Prologo.ao_conceder(dados, jogador, "NATIONAL")
			_comprar_usado(dados, jogador)
			_comprar_usado(dados, jogador)
			# A equipe e o piloto de corrida (no jogo vêm com o primeiro carro).
			EquipeJogador.criar(jogador)
			var oferta := EquipeJogador.oferta(dados, jogador, "corrida", Time.get_unix_time_from_system())
			if not oferta.is_empty():
				EquipeJogador.contratar(dados, jogador, String(oferta[0]["id"]))
			if jogador.carro_ativo < 0 and not jogador.garagem.lista().is_empty():
				jogador.carro_ativo = jogador.garagem.lista()[0].uid
			if id == "carro_3d" and dados.existe("carros", CARRO_3D):
				var carro := Carro.new(dados.carro(CARRO_3D))
				carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
				jogador.carro_ativo = jogador.garagem.adicionar(carro)
		"completo":
			_completo(dados, jogador)
		_:
			return "cenário %s não existe" % id
	return ""


## Teste completo: tudo visto e liberado, a equipe montada e escalada.
static func _completo(dados: Node, jogador: Node) -> void:
	for c in dados.lista("dialogos"):
		jogador.dialogos_vistos[c["id"]] = true
		for f in c.get("flags", []):
			if not f in COMPLETO_SEM_FLAGS:
				jogador.flags[f] = true
	jogador.flags["ABERTURA_DONO"] = true
	jogador.nome_admin = "Teste"
	var todas: Array = dados.lista("licencas")
	_licencas_ate(dados, jogador, String(todas.back()["id"]))
	Prologo.ao_conceder(dados, jogador, "NATIONAL")
	jogador.economia.creditar(COMPLETO_SALDO)
	jogador.economia.ganhar_pecas(COMPLETO_PECAS)
	jogador.ampliacoes_garagem = COMPLETO_AMPLIACOES
	jogador.garagem.vagas = VagasGaragem.capacidade(dados, COMPLETO_AMPLIACOES)
	_comprar_usado(dados, jogador)
	_comprar_usado(dados, jogador)
	var uids := {}
	for mid in COMPLETO_CARROS:
		if dados.existe("carros", mid) and not jogador.garagem.cheia():
			var carro := Carro.new(dados.carro(mid))
			carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			uids[mid] = jogador.garagem.adicionar(carro)
	# Equipe: um piloto de corrida e a dupla da arena, do mercado de agora.
	EquipeJogador.criar(jogador)
	jogador.flags[EquipeJogador.FLAG_ARENA] = true
	var agora := Time.get_unix_time_from_system()
	for v in [["corrida", "corrida"], ["arena1", "arena"], ["arena2", "arena"]]:
		for o in EquipeJogador.oferta(dados, jogador, v[1], agora) + EquipeJogador.pool(dados, jogador, v[1]):
			if EquipeJogador.contratar(dados, jogador, String(o["id"]), v[0]) == "":
				break
	var carros: Array = jogador.garagem.lista()
	var corrida: int = uids.get(CARRO_3D, carros[0].uid)
	jogador.carro_ativo = corrida
	Escalacao.definir(jogador, "corrida", corrida)
	var arena := carros.filter(func(c): return c.uid != corrida)
	if uids.has("brakhaus_sentinela"):  # o resgate com o canhão vai para a arena
		arena.sort_custom(func(a, b): return a.uid == uids["brakhaus_sentinela"] and b.uid != uids["brakhaus_sentinela"])
	for k in mini(2, arena.size()):
		Escalacao.definir(jogador, "arena%d" % (k + 1), arena[k].uid)


static func _licencas_ate(dados: Node, jogador: Node, ultima: String) -> void:
	for lic in dados.lista("licencas"):
		if not lic["id"] in jogador.licencas:
			jogador.licencas.append(lic["id"])
		if lic["id"] == ultima:
			break


## O usado mais barato do dia que o saldo paga, de um modelo que
## ainda não está na garagem; sem nenhum, o modelo mais barato do catálogo, de
## graça (é cenário de teste, não economia). Retorna o uid.
static func _comprar_usado(dados: Node, jogador: Node) -> int:
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	var lista := ofertas.filter(func(o): return jogador.economia.pode_pagar(int(o["preco"])))
	lista.sort_custom(func(a, b): return int(a["preco"]) < int(b["preco"]))
	lista = lista.filter(func(o): return jogador.garagem.lista().all(func(c): return c.id != o["carro_id"]))
	var uid := -1
	if not lista.is_empty():
		var o: Dictionary = lista[0]
		uid = jogador.concessionaria.comprar_usado(o, dados.carro(o["carro_id"]), jogador.usados_vendidos)
	if uid < 0:
		var tem: Array = jogador.garagem.lista().map(func(c): return c.id)
		var modelos: Array = dados.lista("carros").filter(func(m): return not m["id"] in tem)
		modelos.sort_custom(func(a, b): return int(a["preco"]) < int(b["preco"]))
		if modelos.is_empty():
			return jogador.carro_ativo  # todos os modelos já na garagem (dados de teste)
		var carro := Carro.new(modelos[0])
		carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		uid = jogador.garagem.adicionar(carro)
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	return uid
