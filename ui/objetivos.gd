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
			"aba": Aba.LOJA, "botao": "Ir para a Loja"},
		{"texto": "Disputar uma prova", "feito": not jogador.historico.is_empty() or not jogador.vitorias.is_empty(),
			"aba": Aba.EVENTOS, "botao": "Ver eventos"},
		{"texto": "Melhorar o carro (peça ou pneu)", "feito": tem_peca, "aba": Aba.OFICINA, "botao": "Ir para a Oficina"},
		{"texto": "Vencer uma prova", "feito": not jogador.vitorias.is_empty(), "aba": Aba.EVENTOS, "botao": "Ver eventos"},
		{"texto": "Conquistar a licença B", "feito": "B" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver licenças"},
		{"texto": "Vencer uma prova da licença B", "feito": vitorias_b, "aba": Aba.EVENTOS, "botao": "Ver eventos"},
		{"texto": "Conquistar a licença A", "feito": "A" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver licenças"},
	]


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
