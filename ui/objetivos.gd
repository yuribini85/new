class_name Objetivos
extends RefCounted
## Objetivos do começo da carreira, em ordem: cada um diz o que fazer e qual
## tela abre. Só lê o estado do jogador; não dá prêmio nem muda nada.


## [{texto, feito, aba, botao}] na ordem em que devem ser cumpridos.
static func lista(jogador: Node, dados: Node) -> Array:
	var tem_peca := false
	for c in jogador.garagem.lista():
		if not c.pecas.is_empty() or c.pneus.size() > 1:
			tem_peca = true
	var vitorias_b := false
	for ev in dados.lista("eventos"):
		if ev["restricoes"].get("licenca") == "B" and jogador.vitorias.has(ev["id"]):
			vitorias_b = true
	return [
		{"texto": "Comprar o primeiro carro", "feito": not jogador.garagem.lista().is_empty(),
			"aba": Aba.LOJA, "botao": "Ir para o Mercado"},
		{"texto": "Disputar uma prova", "feito": not jogador.historico.is_empty() or not jogador.vitorias.is_empty(),
			"aba": Aba.EVENTOS, "botao": "Ver competições"},
		{"texto": "Melhorar o carro (peça ou pneu)", "feito": tem_peca, "aba": Aba.OFICINA, "botao": "Ir para a Oficina"},
		{"texto": "Vencer uma prova", "feito": not jogador.vitorias.is_empty(), "aba": Aba.EVENTOS, "botao": "Ver competições"},
		{"texto": "Conquistar a licença B", "feito": "B" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver contratos"},
		{"texto": "Vencer uma prova da licença B", "feito": vitorias_b, "aba": Aba.EVENTOS, "botao": "Ver competições"},
		{"texto": "Conquistar a licença A", "feito": "A" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver contratos"},
	]


## O que está entre o jogador e o objetivo atual, numa frase (relatório de
## retorno). Só lê o estado; "" se não há nada a dizer.
static func proximo_obstaculo(jogador: Node, dados: Node) -> String:
	var l := lista(jogador, dados)
	var i := atual(l)
	if i >= l.size():
		return ""
	var texto: String = l[i]["texto"]
	if texto.begins_with("Conquistar a licença"):
		var lic_id := texto.right(1)
		var contratos := Contratos.da_licenca(dados, lic_id)
		var faltam := contratos.filter(func(c): return not jogador.graus_licenca.has(c["id"]))
		if not faltam.is_empty():
			return "Contrato a cumprir: %s (%d de %d na licença %s)." % [faltam[0]["nome"],
					contratos.size() - faltam.size(), contratos.size(), lic_id]
	var carro: Carro = jogador.garagem.carro(jogador.carro_ativo)
	if carro == null and not jogador.garagem.lista().is_empty():
		carro = jogador.garagem.lista()[0]
	if carro == null:
		return ""
	# A prova ainda não vencida de menor prêmio que o carro pode correr.
	var alvo := {}
	for ev in dados.lista("eventos"):
		if jogador.vitorias.has(ev["id"]) or ev["premios"].is_empty():
			continue
		if not Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas).is_empty():
			continue
		if alvo.is_empty() or int(ev["premios"][0]) < int(alvo["premios"][0]):
			alvo = ev
	if alvo.is_empty():
		return ""
	var h: Dictionary = jogador.historico.get(alvo["id"], {})
	return "Próxima prova a vencer com o %s: %s%s." % [carro.base["nome"], alvo["nome"],
			" (seu melhor: %dº)" % h["melhor_pos"] if not h.is_empty() else ""]


## Índice do primeiro objetivo não cumprido (lista.size() se todos).
static func atual(lista_: Array) -> int:
	for i in lista_.size():
		if not lista_[i]["feito"]:
			return i
	return lista_.size()


## [[termo, explicação]] para o painel "Entenda os números". A tração usa os
## fatores de data/simulacao.json, para o texto nunca contradizer a corrida.
static func glossario(dados: Node) -> Array:
	var f: Dictionary = dados.simulacao().get("fator_tracao", {})
	var nomes := {"4WD": "integral (4WD)", "FF": "dianteira (FF)", "FR": "traseira (FR)", "MR": "motor central (MR)", "RR": "motor traseiro (RR)"}
	var partes := []
	for t in ["4WD", "FF", "RR", "MR", "FR"]:
		if f.has(t):
			partes.append("%s %d%%" % [nomes[t], roundi(float(f[t]) * 100.0)])
	return [
		["Potência (cv)", "Força do motor. Mais potência: acelera mais e chega a mais velocidade nas retas. Provas podem ter limite de cv, contado já com as peças."],
		["Peso (kg)", "Carro mais leve acelera, freia e contorna melhor com a mesma potência. O que conta é a potência por kg."],
		["Tração", "Quanto da aderência vira aceleração na largada e na saída das curvas: " + ", ".join(partes)
				+ ". Nas retas rápidas pesa mais a potência."],
		["Aderência e pneus", "Quanto o pneu segura: curvas mais rápidas e frenagem mais curta. Há pneus para seco e para chuva; o piloto usa o melhor que você tiver."],
		["Freio", "Freios melhores deixam frear mais tarde antes das curvas."],
		["Câmbio", "O motor tem uma faixa de giro. Com o câmbio ajustável, curto acelera mais forte e chega antes ao limite; longo vai mais longe nas retas."],
		["Desafio e renda", "Prova ainda não vencida: cada inscrição é um desafio de uma corrida. Depois de vencer, dá para repeti-la em fila para render créditos, inclusive com o app fechado."],
		["Preparações", "Peças compradas ficam com o carro. Salve preparações com nome na Oficina e escolha qual usar ao se inscrever; a fila guarda a escolhida."],
		["Contratos de licença", "A escola empresta o carro e as peças. Você monta, envia para avaliação e lê o relatório: onde perdeu tempo e o que falta para cada medalha."],
		["Nos testes", "Faixas como \"1º–3º nos testes\" vêm de corridas simuladas com os rivais e a pista da prova. São estimativas: a corrida de verdade varia."],
	]
