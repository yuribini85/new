extends Aba
## Corrida ao vivo: mostra a corrida em andamento da fila no tempo real.
## O resultado já está decidido pela simulação; a tela só o reproduz.
## A vista 3D e a classificação são fixas; só o painel de baixo é reconstruído.

## Pede para encerrar a corrida em andamento agora (fase de testes da demo).
signal pular

## Botão "Ver resultado" para testar a demo sem esperar a corrida em tempo
## real. Desligar antes de publicar: o jogo é idle, a espera é parte dele.
const PERMITIR_PULAR := true

## Minimapa (pista inteira) e fonte das posições da vista 3D.
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _area: Control
var _info: Label
var _relogio: Label
var _classificacao: RichTextLabel
var _semente_mostrada := 0
var _nomes := {}  # id do participante -> nome do carro
var _painel: VBoxContainer
var _analise := {}  # {"dia": int, "base": float, "opcoes": [...]}
var _em_andamento := false


func _init(d: Node, j: Node) -> void:
	super(d, j, "Corrida")
	_info = rotulo("", 30)
	_relogio = rotulo("", FONTE_PEQUENA, COR_SECUNDARIA)
	var area := Control.new()
	_area = area
	area.custom_minimum_size = Vector2(0, 480)
	area.clip_contents = true
	conteudo.add_child(area)
	_visual3d = Corrida3D.new()
	_visual3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_visual3d)
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.06, 0.08, 0.88)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fundo.offset_left = -230
	fundo.offset_bottom = 200
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(fundo)
	_visual = CorridaVisual.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.escala_carro = 2.5
	_visual.largura_min_px = 6.0
	_visual.com_rotulos = false
	_visual.girar = false
	fundo.add_child(_visual)
	_classificacao = RichTextLabel.new()
	_classificacao.bbcode_enabled = true
	_classificacao.fit_content = true
	_classificacao.scroll_active = false
	conteudo.add_child(_classificacao)
	_painel = VBoxContainer.new()
	_painel.add_theme_constant_override("separation", 14)
	conteudo.add_child(_painel)


func atualizar() -> void:
	_semente_mostrada = 0
	_construir_painel()


## Painel de baixo: "Ver resultado" durante a corrida e o relatório da última.
func _construir_painel() -> void:
	for c in _painel.get_children():
		c.queue_free()
	_em_andamento = not jogador.fila.is_empty()
	if _em_andamento and PERMITIR_PULAR:
		botao("Ver resultado (teste)", func(): pular.emit(), true, false, _painel)
	var u: Dictionary = jogador.ultima_corrida
	if not _em_andamento:
		if u.is_empty():
			proximo_passo("Nenhuma corrida agora. Escolha uma prova; ela aparece aqui ao vivo.",
					"Escolher prova", EVENTOS, _painel)
			return
	if u.is_empty():
		return
	var ev: Dictionary = dados.evento(u["evento_id"])
	var carreira: Carreira = jogador.carreira
	var seu: Carro = jogador.garagem.carro(u["uid"])
	var venceu: bool = u["posicao"] == 1
	var v := cartao(COR_BOM if venceu else COR_RUIM, _painel)
	rotulo("ÚLTIMA CORRIDA · " + ev.get("nome", ""), FONTE_PEQUENA, COR_SECUNDARIA, v)
	rotulo("%dº de %d%s" % [u["posicao"], u["total"], "  · VITÓRIA!" if venceu else ""], 44,
			COR_DESTAQUE if venceu else Color.WHITE, v)
	if u["premio"] > 0:
		rotulo("Prêmio: +%s Cr" % dinheiro(u["premio"]), 0, COR_BOM, v)
	if not venceu:
		var venc := carreira.carro_participante(u["vencedor"])
		rotulo("%.1f s atrás do vencedor, %s." % [u["tempo_jogador"] - u["tempo_vencedor"],
				carreira.nome_participante(u["vencedor"], u["uid"])], FONTE_PEQUENA + 3, Color.WHITE, v)
		if not venc.is_empty() and seu != null:
			var a := seu.atributos_efetivos(ev.get("condicao", "seco"))
			rotulo("COMPARAÇÃO", FONTE_PEQUENA, COR_SECUNDARIA, v)
			var maximo := maxf(float(venc["potencia"]), a["potencia"]) * 1.15
			barra("Ele", venc["potencia"], maximo, "%d cv" % venc["potencia"], COR_RUIM, v)
			barra("Você", a["potencia"], maximo, "%d cv" % a["potencia"], COR_DESTAQUE, v)
			var max_kg := maxf(float(venc["peso"]), a["peso"]) * 1.15
			barra("Ele", venc["peso"], max_kg, "%d kg" % venc["peso"], COR_RUIM, v)
			barra("Você", a["peso"], max_kg, "%d kg" % a["peso"], COR_DESTAQUE, v)
	if not venceu and seu != null:
		var va := cartao(COR_INFO, _painel)
		if _analise.get("dia", -1) != u["dia"]:
			rotulo("O QUE AJUDA?", FONTE_PEQUENA, COR_INFO, va)
			rotulo("Simula esta prova várias vezes com cada peça ou pneu que cabe no seu saldo e mostra "
					+ "em que posição você tende a chegar.", FONTE_PEQUENA + 2, Color.WHITE, va)
			botao("Analisar", _analisar, true, true, va)
		else:
			var hoje := Mecanico.texto_faixa(_analise["base"]["faixa"])
			rotulo("O QUE AJUDA? · estimativa em %d corridas simuladas" % Mecanico.AMOSTRAS, FONTE_PEQUENA, COR_INFO, va)
			rotulo("Hoje: %s nos testes." % hoje, 0, Color.WHITE, va)
			if _analise["opcoes"].is_empty():
				rotulo("Nada que caiba no seu saldo melhora isso. Tente outra prova ou junte prêmios.",
						FONTE_PEQUENA + 2, COR_SECUNDARIA, va)
			for o in _analise["opcoes"]:
				separador(va)
				var h := fileira(va)
				var info := VBoxContainer.new()
				info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(info)
				rotulo(o["nome"], 0, Color.WHITE, info)
				var etiquetas := [["→ %s nos testes" % Mecanico.texto_faixa(o["faixa"]),
						COR_BOM if o["faixa"][0] == 1 else COR_INFO]]
				if not o["perde"].is_empty():
					etiquetas.append(["⚠ deixa de correr: %s" % ", ".join(o["perde"]), COR_RUIM])
				selos(etiquetas, info)
				var b := botao("Instalar" if o["preco"] == 0 else "%s Cr" % dinheiro(o["preco"]),
						_comprar.bind(o, seu), true, false, h)
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not _em_andamento and seu != null:
		botao("Correr de novo", _correr_de_novo, true, venceu, _painel)


func _analisar() -> void:
	for c in _painel.get_children():
		c.queue_free()
	rotulo("Analisando…", 0, COR_INFO, _painel)
	# Deixa a tela mostrar o aviso antes das simulações.
	await get_tree().process_frame
	await get_tree().process_frame
	var u: Dictionary = jogador.ultima_corrida
	_analise = Mecanico.analisar(jogador.carreira, u["evento_id"], u["uid"])
	_analise["dia"] = u["dia"]
	_construir_painel()


func _comprar(o: Dictionary, carro: Carro) -> void:
	if o["tipo"] == "peca":
		jogador.concessionaria.comprar_peca(carro, o["item"])
	else:
		jogador.concessionaria.comprar_pneu(carro, o["item"])
	_analise = {}
	mudou.emit()


func _correr_de_novo() -> void:
	var u: Dictionary = jogador.ultima_corrida
	jogador.fila_ctrl.iniciar(u["evento_id"], u["uid"], 1, Time.get_unix_time_from_system())
	mudou.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or jogador.fila_ctrl == null:
		return
	var f: Dictionary = jogador.fila
	if f.is_empty() != not _em_andamento:
		_construir_painel()
	if f.is_empty():
		_visual.limpar()
		_visual3d.limpar()
		_area.visible = false
		_semente_mostrada = 0
		_info.text = "Nenhuma corrida na fila."
		_relogio.text = ""
		_classificacao.text = ""
		return
	var agora := Time.get_unix_time_from_system()
	if f["semente"] != _semente_mostrada:
		var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
		if c.is_empty():
			return
		var ev: Dictionary = dados.evento(f["evento_id"])
		var pista: Pista = dados.pista(ev["pista"])
		_visual.mostrar(pista, c["resultado"], {"jogador": Color(1.0, 0.85, 0.2)})
		var categorias := {"jogador": jogador.garagem.carro(f["uid"]).base.get("categoria", "")}
		for i in ev["adversarios"].size():
			var adv_id: String = ev["adversarios"][i]["carro"]
			categorias["adv%d_%s" % [i, adv_id]] = dados.carro(adv_id).get("categoria", "")
		_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
		_visual3d.mostrar(pista, _visual, categorias)
		_area.visible = true
		_semente_mostrada = f["semente"]
		_nomes = {"jogador": "VOCÊ · " + jogador.garagem.carro(f["uid"]).base["nome"]}
		for i in ev["adversarios"].size():
			var adv: Dictionary = ev["adversarios"][i]
			_nomes["adv%d_%s" % [i, adv["carro"]]] = dados.carro(adv["carro"])["nome"]
		_info.text = ev["nome"]
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	_visual3d.atualizar(delta)
	var ev_atual: Dictionary = dados.evento(f["evento_id"])
	_relogio.text = "%s · %d voltas · %s / %s · faltam %d corrida%s" % [nome_pista(ev_atual["pista"]), ev_atual["voltas"],
			_mmss(_visual.tempo), _mmss(_visual.duracao()), f["restantes"], "" if f["restantes"] == 1 else "s"]
	var linhas := []
	var ordem := _visual.ordem()
	for i in ordem.size():
		var id: String = ordem[i]
		var nome: String = _nomes.get(id, id)
		if id == "jogador":
			nome = "[b]%s[/b]" % nome
		linhas.append("%d [color=#%s]■[/color] %s" % [i + 1, _visual.cor_de(id).to_html(false), nome])
	_classificacao.text = "\n".join(linhas)


static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
