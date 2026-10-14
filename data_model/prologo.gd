class_name Prologo
extends RefCounted
## Começo da campanha Chrome & Wreckage (decisão 85; data/historia.json →
## dono): o jogador é o novo dono da oficina e a Mara o guia. Garagem vazia;
## o primeiro carro é a primeira compra, com o saldo inicial da economia. A
## campanha do Adrian e da Elena saiu (decisão 87).
const CAMPANHA := "dono"


## Campanha de um jogo novo (id em historia.json e em jogador.personagem).
static func campanha(_dados: Node) -> String:
	return CAMPANHA


## Começa um jogo novo pela campanha. "" ou o motivo de não poder (dados faltando).
static func iniciar(dados: Node, jogador: Node, id := "") -> String:
	if id == "":
		id = CAMPANHA
	var cfg: Dictionary = dados.historia().get(id, {})
	if cfg.is_empty():
		return "historia.json sem a campanha " + id
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.personagem = id
	jogador.licencas = Array(cfg.get("licencas", [])).duplicate()
	return ""


## Peça da primeira demanda do personagem ("" se ele não tem). "mais_barata"
## (dono, decisão 85): a peça mais barata do carro em uso, a primeira melhoria
## que o prêmio da primeira corrida paga.
static func demanda(dados: Node, jogador: Node) -> String:
	if String(jogador.personagem) == "":
		return ""
	var d := String(dados.historia().get(String(jogador.personagem), {}).get("peca_demanda", ""))
	if d != "mais_barata":
		return d
	var c: Carro = jogador.garagem.carro(jogador.carro_ativo) if jogador.carro_ativo >= 0 else null
	if c == null:
		return ""
	var melhor := {}
	for p in dados.lista("pecas"):
		if c.motivo_recusa(p) == "" and Array(p.get("carros_permitidos", [])).has(c.id) \
				and (melhor.is_empty() or int(p["preco"]) < int(melhor["preco"])):
			melhor = p
	return String(melhor.get("id", ""))


## O carro da Mara (decisão 85): o carro dos cavaletes volta preparado por ela
## quando a equipe conquista a licença de historia.json → <campanha>.carro_mara.
## Vem com a peça mais forte de cada categoria do catálogo dele. "" ou o nome.
static func ao_conceder(dados: Node, jogador: Node, licenca_id: String) -> String:
	var cfg: Dictionary = dados.historia().get(String(jogador.personagem), {}).get("carro_mara", {})
	if cfg.is_empty() or String(cfg.get("licenca", "")) != licenca_id or not dados.existe("carros", cfg.get("carro", "")):
		return ""
	var carro := Carro.new(dados.carro(cfg["carro"]))
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	if dados.existe("pneus", String(cfg.get("pneu", ""))):
		carro.adicionar_pneu(dados.pneu(cfg["pneu"]))
	if String(cfg.get("cor", "")) != "":
		carro.cor = "#" + Cores.cor(cfg["cor"]).to_html(false)
	var forte := {}
	for p in dados.lista("pecas"):
		if Array(p.get("carros_permitidos", [])).has(carro.id) and carro.motivo_recusa(p) == "":
			var cat := String(p["categoria"])
			if not forte.has(cat) or int(p["preco"]) > int(forte[cat]["preco"]):
				forte[cat] = p
	for cat in forte:
		carro.instalar(forte[cat])
		carro.pecas_possuidas.append(forte[cat]["id"])
	if jogador.garagem.adicionar(carro) < 0:
		return ""
	jogador.flags["CARRO_MARA"] = true
	return String(carro.base["nome"])


## Piloto que dirige pelo jogador na campanha (id em personagens.json; "" se
## quem dirige é o próprio personagem).
static func piloto(dados: Node, jogador: Node) -> String:
	if String(jogador.personagem) == "":
		return ""
	return String(dados.historia().get(String(jogador.personagem), {}).get("piloto", ""))
