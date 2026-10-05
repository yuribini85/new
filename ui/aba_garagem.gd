extends Aba

## Primeiro toque em "Recomeçar carreira" só pede confirmação.
var _confirmar_recomeco := false


func _init(d: Node, j: Node) -> void:
	super(d, j, "Garagem")


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	cabecalho("Garagem", "Seus carros. O carro EM USO é o que corre, vai à oficina e faz licenças.")
	_resumo()
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
		var ic := icone_carro(c.base)
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
		var acoes := fileira(v)
		if not ativo:
			botao("Usar este", func():
				jogador.carro_ativo = c.uid
				avisar("Em uso: %s." % c.base["nome"]), true, true, acoes)
		botao("Oficina", func():
			jogador.carro_ativo = c.uid
			ir_para.emit(OFICINA), true, false, acoes)
		botao("Vender %s" % dinheiro(venda), _vender.bind(c.uid),
				not em_fila and jogador.concessionaria.pode_vender(c.uid), false, acoes)
	if lista.size() == 1:
		rotulo("O único carro da garagem não pode ser vendido: sem ele a carreira trava.", FONTE_PEQUENA, COR_SECUNDARIA)
	_rodape()


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
	elif jogador.vitorias.is_empty() and jogador.ultima_corrida.is_empty():
		proximo_passo("Escolha uma prova em que seu carro possa correr e dispute o primeiro prêmio.",
				"Ver eventos", EVENTOS)
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
		var h := fileira(v)
		botao("Sim, recomeçar", _recomecar, true, false, h)
		botao("Cancelar", func(): _confirmar_recomeco = false, true, false, h)
	else:
		linha("", [["Recomeçar carreira", func(): _confirmar_recomeco = true]])
	rotulo("Versão %s" % versao(), FONTE_PEQUENA, COR_NEUTRA)


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
