extends Aba

## Primeiro toque em "Recomeçar carreira" só pede confirmação.
var _confirmar_recomeco := false


func _init(d: Node, j: Node) -> void:
	super(d, j, "Garagem")


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	cabecalho("Garagem", "Seus carros. O carro EM USO é o que corre, vai à oficina e faz licenças.")
	_resumo()
	_objetivos()
	if lista.is_empty():
		if _sem_saida():
			var v := cartao(COR_RUIM)
			rotulo("Sem carro e sem dinheiro para comprar um.", 0, COR_RUIM, v)
			rotulo("Recomece a carreira do zero com o saldo inicial.", FONTE_PEQUENA + 3, Color.WHITE, v)
			botao("Recomeçar carreira", _recomecar, true, true, v)
			rotulo("Versão %s" % versao(), FONTE_PEQUENA, COR_NEUTRA)
			return
		dica("Aqui ficam os carros que você compra ou ganha. Você corre com um de cada vez; "
				+ "melhore-o na Oficina e use os prêmios para comprar outros.")
		proximo_passo("Compre seu primeiro carro. Na Loja, os usados com ★ foram bem nos testes da primeira prova.",
				"Ir para a Loja", LOJA)
		_rodape()
		return
	_sugestao()
	var regras: Dictionary = dados.economia()
	for c in lista:
		var ativo: bool = c.uid == jogador.carro_ativo
		var em_fila: bool = not jogador.fila.is_empty() and jogador.fila["uid"] == c.uid
		var v := cartao(COR_DESTAQUE if ativo else Color.TRANSPARENT)
		var topo := fileira(v)
		var ic := icone_carro(c.base, true)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		topo.add_child(ic)
		var nome := VBoxContainer.new()
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topo.add_child(nome)
		rotulo(c.base["nome"], 32, Color.WHITE, nome)
		var etiquetas := selos_carro(c.base)
		if ativo:
			etiquetas.push_front(["EM USO", COR_DESTAQUE])
		if em_fila:
			etiquetas.push_front(["CORRENDO", COR_BOM])
		if not c.pecas.is_empty():
			etiquetas.append(["%d peça%s" % [c.pecas.size(), "s" if c.pecas.size() > 1 else ""], COR_INFO])
		selos(etiquetas, nome)
		barras_carro(c.atributos_efetivos("seco"), v)
		var venda := int(floor(float(c.base["preco"]) * float(regras["fracao_revenda"])))
		var linha_acoes := acoes(v)
		if not ativo:
			botao("Usar este", func():
				jogador.carro_ativo = c.uid
				avisar("Em uso: %s." % c.base["nome"]), true, true, linha_acoes)
		botao("Oficina", func():
			jogador.carro_ativo = c.uid
			ir_para.emit(OFICINA), true, false, linha_acoes)
		botao("Ficha", func(): ficha_modelo(c.base), true, false, linha_acoes)
		botao("Vender %s" % dinheiro(venda), _vender.bind(c.uid),
				not em_fila and jogador.concessionaria.pode_vender(c.uid), false, linha_acoes)
	if lista.size() == 1:
		rotulo("O único carro da garagem não pode ser vendido: sem ele a carreira trava.", FONTE_PEQUENA, COR_SECUNDARIA)
	var h := acoes()
	botao("Coleção", _colecao, true, false, h)
	entenda(h)
	_rodape()


## Objetivo atual da carreira com botão, e a lista com o que já foi feito.
func _objetivos() -> void:
	var lista := Objetivos.lista(jogador, dados)
	var i := Objetivos.atual(lista)
	if i >= lista.size():
		return
	var v := cartao(COR_DESTAQUE)
	rotulo("OBJETIVO %d DE %d" % [i + 1, lista.size()], FONTE_PEQUENA, COR_DESTAQUE, v)
	rotulo(lista[i]["texto"], 32, Color.WHITE, v)
	var feitos := []
	for k in lista.size():
		if lista[k]["feito"]:
			feitos.append(["✓ " + lista[k]["texto"], COR_BOM])
	if not feitos.is_empty():
		selos(feitos, v)
	botao(lista[i]["botao"], func(): ir_para.emit(lista[i]["aba"]), true, true, v)


## Coleção: todos os modelos por fabricante, com os que você tem, e as contas
## por categoria e por época.
func _colecao() -> void:
	var tenho := {}
	for c in jogador.garagem.lista():
		tenho[c.id] = true
	painel.emit("Coleção · %d de %d modelos" % [tenho.size(), dados.lista("carros").size()], func(v):
		var por_cat := {}
		var por_decada := {}
		for c in dados.lista("carros"):
			var cat: String = NOMES_CATEGORIA_CARRO.get(c.get("categoria", ""), c.get("categoria", ""))
			var dec := "anos %d" % (int(c["ano"]) / 10 * 10 % 100)
			for par in [[por_cat, cat], [por_decada, dec]]:
				var d: Dictionary = par[0]
				var k: Array = d.get(par[1], [0, 0])
				d[par[1]] = [k[0] + (1 if tenho.has(c["id"]) else 0), k[1] + 1]
		var resumo := []
		for d in [por_cat, por_decada]:
			for k in d:
				resumo.append(["%s %d/%d" % [k, d[k][0], d[k][1]], COR_BOM if d[k][0] == d[k][1] else COR_NEUTRA.lightened(0.3)])
		selos(resumo, v)
		for fab in dados.lista("fabricantes"):
			var vc := cartao(Color.TRANSPARENT, v)
			var modelos: Array = dados.lista("carros").filter(func(c): return c["fabricante"] == fab["id"])
			var tem: int = modelos.filter(func(c): return tenho.has(c["id"])).size()
			rotulo("%s · %d/%d" % [fab["nome"], tem, modelos.size()], 30, COR_DESTAQUE, vc)
			for c in modelos:
				var h := fileira(vc)
				var ic := icone_carro(c)
				if not tenho.has(c["id"]):
					ic.modulate = Color(0.35, 0.35, 0.4)
				h.add_child(ic)
				var l := rotulo("%s%s · %d" % ["✓ " if tenho.has(c["id"]) else "", c["nome"], c["ano"]], FONTE_PEQUENA + 2,
						Color.WHITE if tenho.has(c["id"]) else COR_SECUNDARIA, h)
				l.size_flags_vertical = Control.SIZE_SHRINK_CENTER, [])


## Números da carreira no topo: vitórias e licenças.
func _resumo() -> void:
	var vitorias := 0
	for ev in jogador.vitorias:
		vitorias += int(jogador.vitorias[ev])
	var lic: String = ", ".join(jogador.licencas) if not jogador.licencas.is_empty() else "nenhuma"
	selos([
		["%d carro%s" % [jogador.garagem.lista().size(), "" if jogador.garagem.lista().size() == 1 else "s"], COR_NEUTRA.lightened(0.3)],
		["%d vitória%s" % [vitorias, "" if vitorias == 1 else "s"], COR_BOM],
		["Licenças: %s" % lic, COR_INFO],
	])


## O que fazer agora, conforme o momento da carreira.
func _sugestao() -> void:
	if not jogador.fila.is_empty():
		proximo_passo("Há uma corrida em andamento.", "Acompanhar corrida", CORRIDA)
	elif not jogador.ultima_corrida.is_empty() and int(jogador.ultima_corrida.get("posicao", 1)) > 1:
		proximo_passo("Você não venceu a última. Veja na Corrida o que ajuda (peças, pneus) ou prepare o carro.",
				"Ver o que ajuda", CORRIDA)


## Recomeçar sempre disponível (com confirmação) e versão publicada, para saber
## se o navegador já carregou a atualização.
func _rodape() -> void:
	separador()
	if _confirmar_recomeco:
		var v := cartao(COR_RUIM)
		rotulo("Apagar todo o progresso e voltar ao saldo inicial?", 0, Color.WHITE, v)
		var h := acoes(v)
		botao("Sim, recomeçar", _recomecar, true, false, h)
		botao("Cancelar", func(): _confirmar_recomeco = false, true, false, h)
	else:
		linha("", [["Recomeçar carreira", func(): _confirmar_recomeco = true]])
	_preferencias()
	rotulo("Versão %s" % versao(), FONTE_PEQUENA, COR_NEUTRA)


func _preferencias() -> void:
	var v := cartao()
	rotulo("PREFERÊNCIAS", FONTE_PEQUENA, COR_SECUNDARIA, v)
	var h := fileira(v)
	rotulo("Volume", FONTE_PEQUENA + 2, Color.WHITE, h).size_flags_horizontal = Control.SIZE_FILL
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Preferencias.volume
	vol.custom_minimum_size = Vector2(0, 48)
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.drag_ended.connect(func(_mudou):
		Preferencias.volume = vol.value
		Preferencias.salvar())
	h.add_child(vol)
	var anim := CheckButton.new()
	anim.text = "Reduzir animações"
	anim.button_pressed = Preferencias.reduzir_animacoes
	anim.add_theme_font_size_override("font_size", FONTE_PEQUENA + 2)
	anim.toggled.connect(func(ligado):
		Preferencias.reduzir_animacoes = ligado
		Preferencias.salvar())
	v.add_child(anim)


## Commit publicado (versao.txt, gerado pelo workflow do Pages) ou "local".
static func versao() -> String:
	var v := FileAccess.get_file_as_string("res://versao.txt").strip_edges()
	return v if v != "" else "local"


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		avisar("O único carro da garagem não pode ser vendido.", false)
		return
	var nome: String = jogador.garagem.carro(uid).base["nome"]
	avisar("Vendido: %s por %s Cr." % [nome, dinheiro(jogador.concessionaria.vender_carro(uid))])
	if jogador.carro_ativo == uid:
		jogador.carro_ativo = -1


## Garagem vazia e nenhum carro (novo ou usado de hoje) cabe no saldo: saves
## anteriores à regra do último carro podem ter ficado assim.
func _sem_saida() -> bool:
	var precos := []
	for c in dados.lista("carros"):
		if c.get("novo", true):
			precos.append(int(c["preco"]))
	for o in Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos):
		precos.append(int(o["preco"]))
	return precos.all(func(p): return not jogador.economia.pode_pagar(p))


func _recomecar() -> void:
	_confirmar_recomeco = false
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	avisar("Carreira recomeçada com %s Cr." % dinheiro(jogador.economia.saldo))
