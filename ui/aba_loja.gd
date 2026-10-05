extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.
var _previsao := {}  # {"dia", "evento", "avaliacoes": {carro_id: Mecanico.avaliar()}}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Loja")


func construir() -> void:
	cabecalho("Loja", "Compre carros. O dinheiro vem dos prêmios das corridas.")
	entenda()
	if jogador.garagem.lista().is_empty():
		dica("Comece por um usado: são mais baratos e alguns já vencem a primeira prova. "
				+ "A ★ marca os que foram bem em corridas simuladas da prova mais fácil, de fábrica, "
				+ "sem nenhuma peça. É uma estimativa, não uma promessa.")
	rotulo("USADOS · dia %d" % jogador.dias, FONTE_PEQUENA, COR_SECUNDARIA)
	rotulo("O estoque muda conforme você corre (cada corrida é um dia), como no GT2.", FONTE_PEQUENA, COR_SECUNDARIA)
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	if ofertas.is_empty():
		rotulo("Nenhum usado hoje. Volte depois de algumas corridas.", 0, COR_SECUNDARIA)
	var prev := _prever(ofertas)
	for o in ofertas:
		var c: Dictionary = dados.carro(o["carro_id"])
		var extra := []
		var a: Dictionary = prev.get("avaliacoes", {}).get(o["carro_id"], {})
		if not a.is_empty():
			var boa: bool = a["media"] <= 1.5
			extra.append(["%s%s nos testes" % ["★ " if boa else "", Mecanico.texto_faixa(a["faixa"])],
					COR_BOM if boa else COR_NEUTRA.lightened(0.3)])
		var restam: int = int(o.get("fim", jogador.dias)) - jogador.dias + 1
		extra.append(["sai em %d corrida%s" % [restam, "" if restam == 1 else "s"], COR_NEUTRA.lightened(0.3)])
		_cartao_carro(c, int(o["preco"]), extra, func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos), c, int(o["preco"])))
	if not prev.is_empty():
		rotulo("Testes: de fábrica em %s." % prev["evento"], FONTE_PEQUENA, COR_SECUNDARIA)
	separador()
	rotulo("NOVOS", FONTE_PEQUENA, COR_SECUNDARIA)
	rotulo("Sempre disponíveis. Modelos antigos só aparecem nos usados.", FONTE_PEQUENA, COR_SECUNDARIA)
	for c in dados.lista("carros"):
		if not c.get("novo", true):
			continue  # como no GT2: modelos antigos só no usado
		var fab: String = dados.item("fabricantes", c["fabricante"]).get("nome", c["fabricante"])
		_cartao_carro(c, int(c["preco"]), [[fab, COR_NEUTRA.lightened(0.3)], [str(c["ano"]), COR_NEUTRA.lightened(0.3)]],
				func(): _escolher(jogador.concessionaria.comprar_carro(c), c, int(c["preco"])))


## Cartão de oferta: ícone, nome, selos, potência e peso, preço.
func _cartao_carro(c: Dictionary, preco: int, extra: Array, comprar: Callable) -> void:
	var pode: bool = jogador.economia.pode_pagar(preco)
	var v := cartao()
	var topo := fileira(v)
	var ic := icone_carro(c, true)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(ic)
	var nome := VBoxContainer.new()
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	rotulo(c["nome"], 32, Color.WHITE, nome)
	var comp := []
	var meu := carro_ativo()
	if meu != null:
		var a := meu.atributos_efetivos("seco")
		var dcv := int(c["potencia"]) - roundi(a["potencia"])
		var dkg := int(c["peso"]) - roundi(a["peso"])
		comp.append(["vs %s: %+d cv, %+d kg" % [meu.base["nome"], dcv, dkg], COR_INFO])
	comp.append(["revenda %s Cr" % dinheiro(revenda(c)), COR_NEUTRA.lightened(0.3)])
	selos(selos_carro(c) + extra + comp, nome)
	barras_carro({"potencia": float(c["potencia"]), "peso": float(c["peso"])}, v)
	if not pode:
		rotulo("Faltam %s Cr" % dinheiro(preco - jogador.economia.saldo), FONTE_PEQUENA, COR_RUIM, v)
	var h := acoes(v)
	botao("Ficha", func(): ficha_modelo(c), true, false, h)
	botao("Comprar · %s Cr" % dinheiro(preco), comprar, pode, true, h)


func _prever(ofertas: Array) -> Dictionary:
	if jogador.carreira == null:
		return {}
	if _previsao.get("dia", -1) == jogador.dias:
		return _previsao
	var sem_licenca: Array = dados.lista("eventos").filter(func(e): return not e["restricoes"].has("licenca") and not e["premios"].is_empty())
	if sem_licenca.is_empty():
		return {}
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0])
	var ev: Dictionary = sem_licenca[0]
	var avaliacoes := {}
	for o in ofertas:
		var c := Carro.new(dados.carro(o["carro_id"]))
		c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		avaliacoes[o["carro_id"]] = Mecanico.avaliar(jogador.carreira, ev["id"], -1, c)
	_previsao = {"dia": jogador.dias, "evento": ev["nome"], "avaliacoes": avaliacoes}
	return _previsao


## O primeiro carro já entra em uso, e a tela vai para a Garagem, que mostra o
## próximo passo.
func _escolher(uid: int, c: Dictionary, preco: int) -> void:
	if uid <= 0:
		avisar("Não deu para comprar %s: %s." % [c["nome"], "saldo insuficiente" if not jogador.economia.pode_pagar(preco)
				else "saiu do estoque"], false)
		return
	avisar("Comprado: %s por %s Cr. Já está na Garagem." % [c["nome"], dinheiro(preco)])
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
		ir_para.emit(GARAGEM)
