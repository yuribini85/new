extends Aba
## Equipe do jogador (Second Driver Motorsport), visível depois de criada.
## Placeholders (documento, seção 4): logo = texto da equipe. Finanças leves e
## segundo piloto chegam na fase 9.


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
	titulo_secao("Pilotos")
	for p in eq.get("pilotos", []):
		if String(p["id"]).begins_with(String(jogador.personagem) + "_"):
			linha("%s · piloto principal" % p["nome"])
	nota("icone_info", "Segundo piloto", "Contratar um segundo piloto e um segundo carro vem mais adiante na carreira.")
	titulo_secao("Conquistas")
	var vit := 0
	for k in jogador.vitorias:
		vit += int(jogador.vitorias[k])
	var tit := 0
	for k in jogador.titulos:
		tit += int(jogador.titulos[k])
	numeros([[str(vit), "vitórias"], [str(tit), "títulos"], [str(jogador.garagem.lista().size()), "carros"],
			[str(jogador.licencas.size()), "licenças"]])
