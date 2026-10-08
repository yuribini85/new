extends Aba
## Equipe do jogador (Second Driver Motorsport), visível depois de criada.
## Placeholders (documento, seção 4): logo = texto da equipe. Gestão leve
## (fase 9): caixa, folha por corrida, segundo piloto e o carro dele.


func _init(d: Node, j: Node) -> void:
	super(d, j, "Equipe")


func construir() -> void:
	var eq := EquipeJogador.dados_equipe(dados, jogador)
	if eq.is_empty():
		cabecalho("Equipe")
		rotulo("A equipe ainda não existe.", 0, COR_SECUNDARIA)
		return
	cabecalho(String(eq["nome"]) + " Motorsport", "Sua equipe")
	var logo := cartao(COR_DESTAQUE)
	var nome := rotulo(String(eq["nome"]).to_upper(), 44, COR_DESTAQUE, logo)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caixa()
	_pilotos(eq)
	titulo_secao("Conquistas")
	var vit := 0
	for k in jogador.vitorias:
		vit += int(jogador.vitorias[k])
	var tit := 0
	for k in jogador.titulos:
		tit += int(jogador.titulos[k])
	numeros([[str(vit), "vitórias"], [str(tit), "títulos"], [str(jogador.garagem.lista().size()), "carros"],
			[str(jogador.licencas.size()), "licenças"]])


## Caixa único (o saldo) e a folha de cada corrida.
func _caixa() -> void:
	titulo_secao("Caixa", "por corrida")
	var c := cartao()
	rotulo("Caixa: %s Cr" % dinheiro(jogador.economia.saldo), 0, Color.WHITE, c)
	var f := EquipeJogador.folha(dados, jogador)
	_linha_folha(c, "Patrocínio", "patrocinio", int(f["patrocinio"]), "+")
	_linha_folha(c, "Staff", "custo_staff", int(f["staff"]), "−")
	if jogador.segundo_piloto != "":
		_linha_folha(c, "Salário do segundo piloto", "salario_segundo_piloto", int(f["salario"]), "−")
	rotulo("Prêmios entram no mesmo caixa.", FONTE_PEQUENA, COR_SECUNDARIA, c)


func _linha_folha(pai: Control, texto: String, chave: String, v: int, sinal: String) -> void:
	var t := "%s %s Cr" % [sinal, dinheiro(v)] if EquipeJogador.definido(dados, chave) else "a definir no playtest"
	rotulo("%s: %s" % [texto, t], FONTE_PEQUENA + 2, COR_SECUNDARIA if not EquipeJogador.definido(dados, chave) else Color.WHITE, pai)


func _pilotos(eq: Dictionary) -> void:
	titulo_secao("Pilotos")
	for p in eq.get("pilotos", []):
		if String(p["id"]).begins_with(String(jogador.personagem) + "_"):
			linha("%s · piloto principal" % p["nome"])
	if jogador.segundo_piloto != "":
		linha("%s · segundo piloto" % EquipeJogador.nome_segundo(dados, jogador))
		_carro_companheiro()
	elif EquipeJogador.pode_contratar(jogador):
		_contratar()
	else:
		nota("icone_info", "Segundo piloto", "Contratar um segundo piloto vem mais adiante na carreira.")


## Contratação: os pilotos disponíveis e o custo (pendente do playtest = 0).
func _contratar() -> void:
	var custo := EquipeJogador.valor(dados, "contratacao_segundo_piloto")
	nota("icone_piloto", "Contratar segundo piloto", "Ele corre a mesma prova que você, com outro carro da garagem. "
			+ "Vale para a equipe quem chegar na frente; os dois pontuam no campeonato.")
	for p in EquipeJogador.config(dados).get("contrataveis", []):
		var preco := " · %s Cr" % dinheiro(custo) if custo > 0 else ""
		linha(String(p["nome"]) + preco, [["Contratar", func(): _fazer_contratacao(String(p["id"]))]])


func _fazer_contratacao(id: String) -> void:
	var m := EquipeJogador.contratar(dados, jogador, id)
	if m != "":
		if m == "saldo insuficiente":
			historia("SEM_DINHEIRO")
		avisar("Não deu para contratar: %s." % m, false)
		return
	avisar("%s contratado." % EquipeJogador.nome_segundo(dados, jogador))
	historia("PILOTO_CONTRATADO")
	mudou.emit()


## Carro do segundo piloto: qualquer carro da garagem; corre se for elegível
## e diferente do seu na prova.
func _carro_companheiro() -> void:
	var carros: Array = jogador.garagem.lista()
	if carros.size() < 2:
		nota("icone_alerta", "Falta um segundo carro", "Compre outro carro para o segundo piloto correr com você.")
		return
	rotulo("Carro do segundo piloto:", FONTE_PEQUENA + 2, COR_SECUNDARIA)
	var grupo := ButtonGroup.new()
	var fluxo := acoes()
	for car in carros:
		var b := Button.new()
		b.text = nome_curto(car.base["nome"])
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = car.uid == jogador.carro_companheiro
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func():
			jogador.carro_companheiro = car.uid
			mudou.emit())
		fluxo.add_child(b)
	if jogador.garagem.carro(jogador.carro_companheiro) == null:
		rotulo("Escolha um carro para ele correr.", FONTE_PEQUENA, COR_RUIM)
