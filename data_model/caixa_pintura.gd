class_name CaixaPintura
extends RefCounted
## Caixa de pintura (decisão 130, E4; segundo teste com pessoas: "grafismos em
## caixas nas corridas mais difíceis, sem tempo para abrir"). Ganha na vitória
## de prova difícil e abre na hora: um item da cabine de pintura ainda trancado.
## Só cosmético, só ganha correndo, nunca à venda. Repetido (nada mais a
## liberar) vira giros. Configuração em data/equipe.json → caixas.
##
## Prova difícil: a primeira vitória numa prova da licença `licenca_minima` para
## cima, ou qualquer vitória com o carro mais fraco do grid (menor potência por
## peso, com as peças).
##
## Itens: os desenhos e logos que o Grid ainda não liberou (PinturaCarro.liberados)
## e os exclusivos de caixa (rodas, acabamentos e famílias de número em
## `exclusivos`). O jogador guarda os ganhos em Jogador.caixa ("tipo:id").

const TIPOS := ["padroes", "logos", "rodas", "acabamentos", "fontes"]
## Nome de cada tipo na tela.
const NOMES_TIPO := {"padroes": "Desenho", "logos": "Logo", "rodas": "Aro", "acabamentos": "Acabamento",
		"fontes": "Número"}


static func cfg(dados: Node) -> Dictionary:
	return dados.equipe().get("caixas", {})


## O item vem trancado na cabine até sair na caixa (exclusivo) ou o Grid liberar.
static func exclusivo(dados: Node, tipo: String, id: String) -> bool:
	return id in cfg(dados).get("exclusivos", {}).get(tipo, [])


## Já liberado pela caixa.
static func ganho(jogador: Node, tipo: String, id: String) -> bool:
	return "%s:%s" % [tipo, id] in jogador.caixa


## O item pode ser usado na cabine: desenhos e logos pelo Grid ou pela caixa;
## rodas, acabamentos e números, se não forem exclusivos ou se já saíram.
static func liberado(dados: Node, jogador: Node, tipo: String, id: String) -> bool:
	if ganho(jogador, tipo, id):
		return true
	match tipo:
		"padroes":
			var k := PinturaCarro.indice_padrao(id)
			return k < PinturaCarro.liberados(dados, jogador, "padroes", PinturaCarro.PADROES.size())
		"logos":
			var ids: Array = IdentidadeEquipe.opcoes().map(func(o): return String(o["id"]))
			return ids.find(id) < PinturaCarro.liberados(dados, jogador, "logos", ids.size())
	return not exclusivo(dados, tipo, id)


## Os itens que a caixa ainda pode dar: [tipo, id, nome].
static func trancados(dados: Node, jogador: Node) -> Array:
	var r := []
	for pd in PinturaCarro.PADROES:
		if not liberado(dados, jogador, "padroes", String(pd[0])):
			r.append(["padroes", String(pd[0]), String(pd[1])])
	for o in IdentidadeEquipe.opcoes():
		if not liberado(dados, jogador, "logos", String(o["id"])):
			r.append(["logos", String(o["id"]), String(o["nome"])])
	for id in Rodas.DESENHOS:
		if not liberado(dados, jogador, "rodas", id):
			r.append(["rodas", id, Rodas.nome(id)])
	for par in PinturaCarro.ACABAMENTOS:
		if not liberado(dados, jogador, "acabamentos", String(par[0])):
			r.append(["acabamentos", String(par[0]), String(par[1])])
	for par in PinturaCarro.FONTES:
		if not liberado(dados, jogador, "fontes", String(par[0])):
			r.append(["fontes", String(par[0]), String(par[1])])
	return r


## A vitória dá caixa? `primeira`: a primeira vitória nesta prova.
static func ganha(dados: Node, jogador: Node, ev: Dictionary, carro: Carro, primeira: bool) -> bool:
	var c := cfg(dados)
	if c.is_empty() or ev.get("grid_equipe") != null:
		return false
	var niveis := GestaoEquipe.ordem(dados)
	var lic := String(ev.get("restricoes", {}).get("licenca", ""))
	if primeira and lic != "" and niveis.find(lic) >= niveis.find(String(c.get("licenca_minima", ""))):
		return true
	return carro != null and mais_fraco(dados, ev, carro)


## O carro do jogador tem a menor potência por peso do grid (com as peças).
static func mais_fraco(dados: Node, ev: Dictionary, carro: Carro) -> bool:
	var condicao := String(ev.get("condicao", "seco"))
	var meu := _pp(carro.atributos_efetivos(condicao))
	if ev.get("adversarios", []).is_empty():
		return false
	for adv in ev["adversarios"]:
		var c := Carro.new(dados.carro(adv["carro"]))
		for peca_id in adv.get("pecas", []):
			c.instalar(dados.peca(peca_id))
		if _pp(c.atributos_efetivos(condicao)) <= meu:
			return false
	return true


static func _pp(a: Dictionary) -> float:
	return float(a.get("potencia", 0.0)) / maxf(float(a.get("peso", 1.0)), 1.0)


## Abre a caixa (na hora): libera um item trancado, sorteado pela semente, ou,
## sem nada a liberar, credita os giros de um prêmio de 1º lugar da licença.
## {"tipo", "id", "nome"} ou {"giros"}.
static func abrir(dados: Node, jogador: Node, ev: Dictionary, semente: int) -> Dictionary:
	var lista := trancados(dados, jogador)
	if lista.is_empty():
		var lic := String(ev.get("restricoes", {}).get("licenca", ""))
		var niveis := GestaoEquipe.ordem(dados)
		if lic == "":
			var k := GestaoEquipe.maior_licenca(dados, jogador)
			lic = niveis[maxi(k, 0)] if not niveis.is_empty() else ""
		var giros := GestaoEquipe.premio_referencia(dados, lic) if lic != "" else 0
		jogador.economia.creditar(giros)
		return {"giros": giros}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("caixa:%d" % semente)
	var item: Array = lista[rng.randi_range(0, lista.size() - 1)]
	jogador.caixa.append("%s:%s" % [item[0], item[1]])
	return {"tipo": item[0], "id": item[1], "nome": item[2]}


## Texto da caixa aberta na janela do resultado.
static func texto(aberta: Dictionary) -> String:
	if aberta.has("giros"):
		return "CAIXA DE PINTURA: nada novo, +%s giros" % Aba.dinheiro(int(aberta["giros"]))
	return "CAIXA DE PINTURA: %s %s" % [String(NOMES_TIPO.get(aberta["tipo"], "")).to_lower(), String(aberta["nome"])]
