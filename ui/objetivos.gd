class_name Objetivos
extends RefCounted
## Objetivos do começo da carreira, em ordem: cada um diz o que fazer e qual
## tela abre. Só lê o estado do jogador; não dá prêmio nem muda nada.


## [{texto, feito, aba, botao}] na ordem em que devem ser cumpridos. Com a
## história, os objetivos seguem o que a Mara pede: o
## jogador novo nunca recebe duas ordens diferentes.
static func lista(jogador: Node, dados: Node) -> Array:
	if jogador.personagem == "dono":
		return _dono(jogador, dados) + _renomear_licenca(_carreira(jogador, dados).slice(1))
	return _carreira(jogador, dados)


## Dono da oficina (Chrome & Wreckage, decisão 85): o primeiro carro, o
## piloto, a primeira prova, mais provas e a peça que a Mara pede depois.
static func _dono(jogador: Node, dados: Node) -> Array:
	var l := [
		{"texto": "Comprar o primeiro carro", "feito": not jogador.garagem.lista().is_empty(), "aba": Aba.LOJA,
			"botao": "Ir para as Lojas"},
		{"texto": "Contratar o piloto de corrida", "feito": jogador.flags.has("PILOT_HIRED"), "aba": Aba.EQUIPE,
			"botao": "Ir para a Equipe"},
		{"texto": "Disputar a primeira prova", "feito": jogador.flags.has("FIRST_RACE_DONE"), "aba": Aba.EVENTOS,
			"botao": "Ver corridas"},
	]
	# A Oficina só entra depois de apresentada (CW_P06D: da segunda prova em
	# diante, com o caixa pagando a peça).
	l.append({"texto": "Correr de novo e juntar giros", "feito": jogador.flags.has("GARAGE_TUTORIAL_SEEN"),
		"aba": Aba.EVENTOS, "botao": "Ver corridas"})
	var peca := Prologo.demanda(dados, jogador)
	if dados.existe("pecas", peca) and jogador.flags.has("GARAGE_TUTORIAL_SEEN"):
		l.append({"texto": "Comprar %s na Oficina" % dados.peca(peca)["nome"], "feito": jogador.flags.has("FIRST_TUNE_DONE"),
			"aba": Aba.GARAGEM, "botao": "Ir para a Oficina"})
	return l


## De volta às pistas (decisão 73): no dono, a licença Club é a licença que a
## equipe precisa renovar (sem prazo; sai com o treino, decisão 99).
static func _renomear_licenca(l: Array) -> Array:
	for o in l:
		if o["texto"] == "Conquistar a licença Club":
			o["texto"] = "De volta às pistas: renovar a licença (Club)"
	return l


static func _carreira(jogador: Node, dados: Node) -> Array:
	var tem_peca := false
	for c in jogador.garagem.lista():
		if not c.pecas.is_empty() or c.pneus.size() > 1:
			tem_peca = true
	var vitorias_b := false
	for ev in dados.lista("eventos"):
		if ev["restricoes"].get("licenca") == "CLUB" and jogador.vitorias.has(ev["id"]):
			vitorias_b = true
	return [
		{"texto": "Comprar o primeiro carro", "feito": not jogador.garagem.lista().is_empty(),
			"aba": Aba.LOJA, "botao": "Ir para as Lojas"},
		{"texto": "Disputar uma corrida", "feito": not jogador.historico.is_empty() or not jogador.vitorias.is_empty(),
			"aba": Aba.EVENTOS, "botao": "Ver corridas"},
		{"texto": "Melhorar o carro (peça ou pneu)", "feito": tem_peca, "aba": Aba.GARAGEM, "botao": "Ir para a Oficina"},
		{"texto": "Vencer uma corrida", "feito": not jogador.vitorias.is_empty(), "aba": Aba.EVENTOS, "botao": "Ver corridas"},
		{"texto": "Conquistar a licença Club", "feito": "CLUB" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver licenças"},
		{"texto": "Vencer uma corrida da licença Club", "feito": vitorias_b, "aba": Aba.EVENTOS, "botao": "Ver corridas"},
		{"texto": "Conquistar a licença Sport", "feito": "SPORT" in jogador.licencas, "aba": Aba.LICENCAS, "botao": "Ver licenças"},
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
		# Licença por treino no relógio (decisão 99): diz onde está o treino.
		var lic_id := texto.get_slice(" ", texto.get_slice_count(" ") - 1).to_upper()
		var lic := Licencas.new(dados, jogador)
		var agora := Time.get_unix_time_from_system()
		match lic.estado(lic_id, agora):
			Licencas.AVAILABLE:
				return "Licença %s: requisitos cumpridos, falta iniciar o treino." % lic_id.capitalize()
			Licencas.TRAINING:
				return "Licença %s em treino: faltam %d min." % [lic_id.capitalize(), ceili(lic.restante(lic_id, agora) / 60.0)]
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
	return "Próxima corrida a vencer com o %s: %s%s." % [carro.base["nome"], alvo["nome"],
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
		["Potência (cv)", "Força do motor. Mais potência: acelera mais e chega a mais velocidade nas retas. Algumas corridas têm limite de cv, contado já com as peças."],
		["Peso (kg)", "Carro mais leve acelera, freia e contorna melhor com a mesma potência. O que conta é a potência por kg."],
		["Tração", "Quanto da aderência vira aceleração na largada e na saída das curvas: " + ", ".join(partes)
				+ ". Nas retas rápidas pesa mais a potência."],
		["Aderência e pneus", "Quanto o pneu segura: curvas mais rápidas e frenagem mais curta. O piloto usa o melhor pneu que você tiver."],
		["Freio", "Freios melhores deixam frear mais tarde antes das curvas."],
		["Câmbio", "O motor tem uma faixa de giro: cada marcha leva o carro até o limite dela antes da próxima."],
		["Disputar de novo e giros", "Depois de largar, a corrida termina mesmo com o jogo fechado. Numa prova já vencida dá para montar uma sequência de corridas. Prova já vencida paga menos a cada repetição: 50%, 25% e depois 10%, voltando a 100% em 24 h."],
		["Combustível", "Cada corrida ou luta da arena gasta 1. O tanque renova sozinho com o tempo, também com o jogo fechado, e um vídeo o enche de uma vez."],
		["Peças", "Peças compradas ficam com o carro. Dá para tirar e pôr de volta de graça na Oficina."],
		["Treino da licença", "Cumpridos os requisitos, comece o treino. Ele corre no relógio, com o jogo aberto ou fechado; quando termina, a licença sai sozinha."],
		["Previsão", "MAIS FRACO, PARELHO e MAIS FORTE são uma previsão contra os rivais da prova: a corrida de verdade varia."],
	]
