extends Aba
## Corrida ao vivo: mostra a corrida em andamento da fila no tempo real.
## O resultado já está decidido pela simulação; a tela só o reproduz.
## A vista 3D, o placar e a classificação são fixos; só o painel de baixo
## (resultado da última corrida e "O que ajuda?") é reconstruído.

## Pede para encerrar a corrida em andamento agora (fase de testes da demo).
signal pular

## Botão "Ver resultado" (Preferencias.permite_pular): testar a demo sem
## esperar a corrida em tempo real. Desligado no teste de ritmo; desligar
## antes de publicar: o jogo é idle, a espera é parte dele.
## Distância (m) para o placar chamar de disputa.
const DISPUTA_M := 10.0
const DURACAO_DESTAQUE := 2.5

## Minimapa (pista inteira) e fonte das posições da vista 3D.
var _visual: CorridaVisual
var _visual3d: Corrida3D
var _area: Control
var _info: Label
var _relogio: Label
var _placar: Label
var _hud: Label
var _hud_volta: Label
var _destaque: Label
var _destaque_t := 0.0
var _cameras: HBoxContainer
var _classificacao: RichTextLabel
var _semente_mostrada := 0
var _nomes := {}  # id do participante -> nome do carro
var _pista: Pista
var _voltas := 1
var _posicao_antes := 0
var _ordem_antes: Array = []
var _painel: VBoxContainer
var _analise := {}  # {"chave", "base", "opcoes", "ms"}
var _analisando := false
var _em_andamento := false
var _sons: Sons
var _s_jogador := 0.0
var _chegou := false


func _init(d: Node, j: Node) -> void:
	super(d, j, "Corrida")
	_info = rotulo("", 30)
	_relogio = rotulo("", FONTE_PEQUENA, COR_SECUNDARIA)
	var area := Control.new()
	_area = area
	area.custom_minimum_size = Vector2(0, 640)
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
	# Placar compacto sobre a pista: posição grande, volta e tempo; embaixo, a
	# perseguição (diferença em segundos para o carro da frente, o ALVO).
	var hud := VBoxContainer.new()
	hud.position = Vector2(14, 10)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_constant_override("separation", -8)
	area.add_child(hud)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 68)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 12)
	hud.add_child(_hud)
	_hud_volta = Label.new()
	_hud_volta.add_theme_font_size_override("font_size", 26)
	_hud_volta.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_volta.add_theme_constant_override("outline_size", 8)
	hud.add_child(_hud_volta)
	_placar = _sobre_area(area, Control.PRESET_BOTTOM_WIDE, Color(0.05, 0.06, 0.08, 0.82), 30)
	# Destaque: largada, ultrapassagem, chegada. Aparece e some.
	_destaque = _sobre_area(area, Control.PRESET_CENTER_TOP, Color(0.1, 0.3, 0.16, 0.92), 32)
	_destaque.get_parent().visible = false
	_cameras = fileira()
	for modo in [["Meu carro", "jogador"], ["Líder", "lider"], ["À frente", "frente"], ["Pista toda", "geral"]]:
		var b := Button.new()
		b.text = modo[0]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
		b.pressed.connect(_camera.bind(modo[1]))
		_cameras.add_child(b)
	_classificacao = RichTextLabel.new()
	_classificacao.bbcode_enabled = true
	_classificacao.fit_content = true
	_classificacao.scroll_active = false
	_classificacao.meta_underlined = false
	_classificacao.add_theme_font_size_override("normal_font_size", 24)
	_classificacao.add_theme_font_size_override("bold_font_size", 24)
	_classificacao.meta_clicked.connect(func(id): _camera(str(id)))
	conteudo.add_child(_classificacao)
	_painel = VBoxContainer.new()
	_painel.add_theme_constant_override("separation", 14)
	conteudo.add_child(_painel)
	_camera_modo = "jogador"
	_sons = Sons.new()
	add_child(_sons)


var _camera_modo := "jogador":
	set(v):
		_camera_modo = v
		if _cameras != null:
			for i in _cameras.get_child_count():
				var b: Button = _cameras.get_child(i)
				b.button_pressed = ["jogador", "lider", "frente", "geral"][i] == v


func _sobre_area(area: Control, preset: int, cor: Color, fonte: int) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_BOTTOM_WIDE:
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		p.grow_horizontal = Control.GROW_DIRECTION_BOTH
		p.offset_top = 150
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fonte)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	area.add_child(p)
	return l


## "jogador", "lider", "frente", "geral" ou o id de um participante.
func _camera(modo: String) -> void:
	_camera_modo = modo
	_visual3d.visao_geral = modo == "geral"
	if modo != "geral":
		_visual3d.foco = _alvo_camera()


func _alvo_camera() -> String:
	var ordem := _visual.ordem()
	match _camera_modo:
		"jogador", "geral":
			return "jogador"
		"lider":
			return ordem[0] if not ordem.is_empty() else "jogador"
		"frente":
			var i := ordem.find("jogador")
			return ordem[i - 1] if i > 0 else "jogador"
	return _camera_modo


func atualizar() -> void:
	_semente_mostrada = 0
	_construir_painel()


## Painel de baixo: ações durante a corrida e o relatório da última.
func _construir_painel() -> void:
	for c in _painel.get_children():
		c.queue_free()
	_em_andamento = not jogador.fila.is_empty()
	_cameras.visible = _em_andamento
	if _em_andamento:
		var h := acoes(_painel)
		if Preferencias.permite_pular():
			botao("Ver resultado (teste)", func(): pular.emit(), true, false, h)
		botao("Voltar à garagem", func(): ir_para.emit(GARAGEM), true, false, h)
		rotulo("A fila continua mesmo fora desta tela ou com o app fechado. Toque num carro da lista para segui-lo.",
				FONTE_PEQUENA, COR_SECUNDARIA, _painel)
	var u: Dictionary = jogador.ultima_corrida
	if u.is_empty():
		if not _em_andamento:
			proximo_passo("Nenhuma corrida agora. Escolha uma prova; ela aparece aqui ao vivo.",
					"Escolher prova", EVENTOS, _painel)
		return
	_resultado(u)


func _resultado(u: Dictionary) -> void:
	var ev: Dictionary = dados.evento(u["evento_id"])
	var carreira: Carreira = jogador.carreira
	var seu: Carro = jogador.garagem.carro(u["uid"])
	var venceu: bool = u["posicao"] == 1
	var anterior: Dictionary = u.get("anterior", {})
	var v := cartao(COR_BOM if venceu else COR_RUIM, _painel)
	rotulo("ÚLTIMA CORRIDA · " + ev.get("nome", ""), FONTE_PEQUENA, COR_SECUNDARIA, v)
	rotulo("%dº de %d%s" % [u["posicao"], u["total"], "  · VITÓRIA!" if venceu else ""], 44,
			COR_DESTAQUE if venceu else Color.WHITE, v)
	var marcos := []
	if venceu and (anterior.is_empty() or int(anterior.get("melhor_pos", 0)) > 1):
		marcos.append(["PRIMEIRA VITÓRIA NESTA PROVA", COR_DESTAQUE])
	if u.get("recorde", false) and not anterior.is_empty():
		marcos.append(["RECORDE PESSOAL", COR_BOM])
	if u["premio"] > 0:
		marcos.append(["+%s Cr" % dinheiro(u["premio"]), COR_BOM])
	selos(marcos, v)
	if not anterior.is_empty():
		var dp: int = int(anterior["ultima_pos"]) - int(u["posicao"])
		var txt := "Antes: %dº%s. Agora: %dº" % [anterior["ultima_pos"],
				" (melhor %dº)" % anterior["melhor_pos"] if anterior["melhor_pos"] != anterior["ultima_pos"] else "", u["posicao"]]
		if dp != 0:
			txt += " (%s%d)" % ["subiu " if dp > 0 else "caiu ", absi(dp)]
		if anterior["ultimo_tempo"] > 0.0 and u["tempo_jogador"] > 0.0:
			txt += " · %+.1f s na volta à prova" % (u["tempo_jogador"] - anterior["ultimo_tempo"])
		rotulo(txt, FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
	if u.get("carro_premio_uid", -1) > 0:
		var cp: Carro = jogador.garagem.carro(u["carro_premio_uid"])
		if cp != null:
			var h := fileira(v)
			h.add_child(icone_carro(cp.base))
			rotulo("Carro-prêmio: %s. Já está na sua garagem." % cp.base["nome"], FONTE_PEQUENA + 2, COR_DESTAQUE, h)
	_tabela(u, v)
	if not venceu and seu != null:
		_por_que(u, ev, seu)
		_o_que_ajuda(u, seu)
	var fim := cartao(Color.TRANSPARENT, _painel)
	rotulo("E AGORA?", FONTE_PEQUENA, COR_SECUNDARIA, fim)
	var h := acoes(fim)
	if not _em_andamento and seu != null:
		botao("Repetir", _correr_de_novo, true, true, h)
	botao("Preparar", func():
		if seu != null:
			jogador.carro_ativo = seu.uid
		ir_para.emit(OFICINA), true, false, h)
	botao("Outra prova", func(): ir_para.emit(EVENTOS), true, false, h)


## Classificação completa: posição, carro, tempo e diferença para o vencedor.
func _tabela(u: Dictionary, pai: Control) -> void:
	var tabela: Array = u.get("tabela", [])
	if tabela.is_empty():
		return
	rotulo("CLASSIFICAÇÃO", FONTE_PEQUENA, COR_SECUNDARIA, pai)
	var t0: float = tabela[0]["tempo"]
	for i in tabela.size():
		var lin: Dictionary = tabela[i]
		var nome: String = jogador.carreira.rotulo_participante(u["evento_id"], lin["id"], u["uid"])
		var tempo := _mmss_dec(lin["tempo"]) if lin["terminou"] else "não terminou"
		var dif := "" if i == 0 or not lin["terminou"] else "  +%.1f s" % (lin["tempo"] - t0)
		var cor := COR_DESTAQUE if lin["id"] == "jogador" else Color.WHITE
		rotulo("%dº  %s  ·  %s%s" % [i + 1, nome, tempo, dif], FONTE_PEQUENA + 2, cor, pai)


## Por que perdeu: compara o seu carro com o vencedor e com o carro logo à
## frente, atributo a atributo (números do próprio jogo).
func _por_que(u: Dictionary, ev: Dictionary, seu: Carro) -> void:
	var carreira: Carreira = jogador.carreira
	var meu := carreira.atributos_participante(u["evento_id"], "jogador", u["uid"])
	var tabela: Array = u.get("tabela", [])
	var rivais := [u["vencedor"]]
	var i_meu := tabela.map(func(x): return x["id"]).find("jogador")
	if i_meu > 1:
		rivais.append(tabela[i_meu - 1]["id"])
	var v := cartao(COR_RUIM, _painel)
	rotulo("POR QUE PERDEU?", FONTE_PEQUENA, COR_RUIM, v)
	for id in rivais:
		var a := carreira.atributos_participante(u["evento_id"], id, u["uid"])
		if a.is_empty() or meu.is_empty():
			continue
		var quem := "Vencedor" if id == u["vencedor"] else "Logo à frente"
		rotulo("%s: %s" % [quem, carreira.rotulo_participante(u["evento_id"], id, u["uid"])], 0, Color.WHITE, v)
		selos(fatores(meu, a), v)
	rotulo("Potência por peso pesa na aceleração e nas retas; aderência nas curvas e na frenagem; freio na "
			+ "frenagem. Mais aderência vem de pneus; menos peso, de redução de peso.", FONTE_PEQUENA, COR_SECUNDARIA, v)


## Selos de comparação: o que o rival tem a mais (vermelho) e você (verde).
static func fatores(meu: Dictionary, rival: Dictionary) -> Array:
	var r := []
	var pp_meu: float = meu["potencia"] / maxf(meu["peso"], 1.0)
	var pp_rival: float = rival["potencia"] / maxf(rival["peso"], 1.0)
	var d := pp_rival / maxf(pp_meu, 1e-6) - 1.0
	if absf(d) >= 0.02:
		r.append(["%s %d%% mais potência por kg" % ["ele tem" if d > 0 else "você tem", roundi(absf(d) * 100.0 if d > 0
				else (pp_meu / pp_rival - 1.0) * 100.0)], COR_RUIM if d > 0 else COR_BOM])
	var da: float = rival["aderencia"] / maxf(meu["aderencia"], 1e-6) - 1.0
	if absf(da) >= 0.01:
		r.append(["aderência: %s" % ("ele +%d%%" % roundi(da * 100.0) if da > 0 else "você +%d%%" % roundi(
				(meu["aderencia"] / rival["aderencia"] - 1.0) * 100.0)), COR_RUIM if da > 0 else COR_BOM])
	var df: float = rival["freio"] / maxf(meu["freio"], 1e-6) - 1.0
	if absf(df) >= 0.01:
		r.append(["freio: %s" % ("ele +%d%%" % roundi(df * 100.0) if df > 0 else "você +%d%%" % roundi(
				(meu["freio"] / rival["freio"] - 1.0) * 100.0)), COR_RUIM if df > 0 else COR_BOM])
	r.append(["ele %d cv · %d kg · %s" % [rival["potencia"], rival["peso"], rival["tracao"]], COR_NEUTRA.lightened(0.3)])
	r.append(["você %d cv · %d kg · %s" % [meu["potencia"], meu["peso"], meu["tracao"]], COR_DESTAQUE])
	return r


## "O que ajuda?": simula esta prova com cada peça ou pneu que cabe no saldo.
## A análise vale enquanto carro, saldo e dia forem os mesmos.
func _o_que_ajuda(u: Dictionary, seu: Carro) -> void:
	var va := cartao(COR_INFO, _painel)
	rotulo("O QUE AJUDA?", FONTE_PEQUENA, COR_INFO, va)
	if _analisando:
		rotulo("Analisando…", 0, COR_INFO, va)
		return
	if _analise.get("chave", "") != _chave_analise(u, seu):
		rotulo("Simula esta prova várias vezes com cada peça ou pneu que cabe no seu saldo e mostra em que "
				+ "posição você tende a chegar. É uma estimativa, não uma promessa.", FONTE_PEQUENA + 2, Color.WHITE, va)
		botao("Analisar", _analisar, not _em_andamento or int(jogador.fila.get("uid", -1)) != seu.uid, true, va)
		return
	var hoje := Mecanico.texto_faixa(_analise["base"]["faixa"])
	rotulo("Hoje, sem mudar nada: %s nos testes." % hoje, 0, Color.WHITE, va)
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
		var etiquetas := [["%s → %s nos testes" % [hoje, Mecanico.texto_faixa(o["faixa"])],
				COR_BOM if o["faixa"][0] == 1 else COR_INFO],
				["custa %s Cr" % dinheiro(o["preco"]) if o["preco"] > 0 else "já é sua: reinstalar", COR_NEUTRA.lightened(0.3)]]
		if not o["perde"].is_empty():
			etiquetas.append(["⚠ deixa de correr: %s" % ", ".join(o["perde"]), COR_RUIM])
		selos(etiquetas, info)
		var b := botao("Instalar" if o["preco"] == 0 else "%s Cr" % dinheiro(o["preco"]),
				_comprar.bind(o, seu), not _em_andamento or int(jogador.fila.get("uid", -1)) != seu.uid, false, h)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rotulo("%d corridas simuladas por opção · calculado em %.1f s" % [Mecanico.AMOSTRAS, _analise["ms"] / 1000.0],
			FONTE_PEQUENA, COR_SECUNDARIA, va)


func _chave_analise(u: Dictionary, seu: Carro) -> String:
	return "%s|%d|%d|%s|%s" % [u["evento_id"], u["dia"], jogador.economia.saldo, str(seu.pecas.keys().map(func(k): return seu.pecas[k]["id"])),
			str(seu.pneus.map(func(p): return p["id"]))]


## Análise opção por opção, devolvendo o controle à tela entre elas para
## mostrar o progresso (no celular pode levar alguns segundos).
func _analisar() -> void:
	var u: Dictionary = jogador.ultima_corrida
	var carro: Carro = jogador.garagem.carro(u["uid"])
	if carro == null or _analisando:
		return
	_analisando = true
	var inicio := Time.get_ticks_msec()
	for c in _painel.get_children():
		c.queue_free()
	var v := cartao(COR_INFO, _painel)
	rotulo("O QUE AJUDA?", FONTE_PEQUENA, COR_INFO, v)
	var progresso := rotulo("Preparando…", 0, Color.WHITE, v)
	var barra_p := ProgressBar.new()
	barra_p.custom_minimum_size = Vector2(0, 24)
	barra_p.show_percentage = false
	v.add_child(barra_p)
	await get_tree().process_frame
	var carreira: Carreira = jogador.carreira
	var base := Mecanico.avaliar(carreira, u["evento_id"], u["uid"], carro)
	var pode_antes := Mecanico.provas_possiveis(dados, carro)
	var cands := Mecanico.candidatas(dados, jogador, carro)
	var boas := []
	for i in cands.size():
		if not is_instance_valid(progresso):
			break
		progresso.text = "Testando %d de %d: %s" % [i + 1, cands.size(), cands[i]["nome"]]
		barra_p.value = 100.0 * i / maxf(cands.size(), 1.0)
		await get_tree().process_frame
		var o: Dictionary = cands[i]
		if Mecanico.considerar(o, Mecanico.avaliar(carreira, u["evento_id"], u["uid"], o["carro"]), base, pode_antes, dados):
			boas.append(o)
	_analise = {"chave": _chave_analise(u, carro), "base": base, "opcoes": Mecanico.ordenar(boas, 3),
			"ms": Time.get_ticks_msec() - inicio}
	_analisando = false
	_construir_painel()


func _comprar(o: Dictionary, carro: Carro) -> void:
	var motivo := ""
	if o["tipo"] == "peca":
		motivo = jogador.concessionaria.comprar_peca(carro, o["item"])
	else:
		motivo = jogador.concessionaria.comprar_pneu(carro, o["item"])
	if motivo != "":
		avisar("Não deu: %s." % motivo, false)
	else:
		avisar("%s instalado em %s. Corra de novo para conferir." % [o["nome"], carro.base["nome"]])


func _correr_de_novo() -> void:
	var u: Dictionary = jogador.ultima_corrida
	var motivo: String = jogador.fila_ctrl.iniciar(u["evento_id"], u["uid"], 1, Time.get_unix_time_from_system())
	if motivo != "":
		avisar("Não deu para correr: %s." % motivo, false)
	else:
		avisar("Largada! %s." % dados.evento(u["evento_id"])["nome"])


func _process(delta: float) -> void:
	if not is_visible_in_tree() or jogador.fila_ctrl == null:
		if _sons != null:
			_sons.motor(false)
		return
	var f: Dictionary = jogador.fila
	if f.is_empty() != not _em_andamento:
		_construir_painel()
	if f.is_empty():
		_visual.limpar()
		_visual3d.limpar()
		_area.visible = false
		_semente_mostrada = 0
		_sons.motor(false)
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
		_pista = dados.pista(ev["pista"])
		_voltas = int(ev["voltas"])
		var meu: Carro = jogador.garagem.carro(f["uid"])
		_visual.mostrar(_pista, c["resultado"], {"jogador": CarroBloco.cor_do_carro(meu)})
		var categorias := {"jogador": meu.base}
		for i in ev["adversarios"].size():
			var adv_id: String = ev["adversarios"][i]["carro"]
			categorias["adv%d_%s" % [i, adv_id]] = dados.carro(adv_id)
		_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
		_visual3d.mostrar(_pista, _visual, categorias)
		_area.visible = true
		_semente_mostrada = f["semente"]
		_posicao_antes = 0
		_ordem_antes = []
		_nomes = {"jogador": "VOCÊ · " + jogador.garagem.carro(f["uid"]).base["nome"]}
		for i in ev["adversarios"].size():
			var adv: Dictionary = ev["adversarios"][i]
			var pid := "adv%d_%s" % [i, adv["carro"]]
			_nomes[pid] = "%s (%s)" % [Carreira.nome_piloto(ev["id"], pid), Aba.nome_curto(dados.carro(adv["carro"])["nome"])]
		_info.text = ev["nome"]
		_camera(_camera_modo)
		_chegou = false
		_s_jogador = _visual.distancia("jogador")
		if _visual.tempo < 2.0:
			_sons.largada(true)
			_mostrar_destaque("LARGADA!", true)
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	if _camera_modo in ["lider", "frente"]:
		_visual3d.foco = _alvo_camera()
	_visual3d.atualizar(delta)
	var ev_atual: Dictionary = dados.evento(f["evento_id"])
	_relogio.text = "%s · %d volta%s%s" % [nome_pista(ev_atual["pista"]), _voltas, "" if _voltas == 1 else "s",
			" · faltam %d corridas" % f["restantes"] if f["restantes"] > 1 else ""]
	var s_agora := _visual.distancia("jogador")
	var meta := _pista.comprimento * _voltas if _pista != null else INF
	if s_agora >= meta and not _chegou:
		_chegou = true
		_sons.chegada()
		_mostrar_destaque("CHEGADA · %dº" % (_visual.ordem().find("jogador") + 1), true)
	_sons.motor(not _chegou, (s_agora - _s_jogador) / maxf(delta, 1e-3) if delta > 0.0 else 0.0)
	_s_jogador = s_agora
	var ordem := _visual.ordem()
	_atualizar_placar(ordem)
	_atualizar_destaque(ordem, delta)
	var linhas := []
	for i in ordem.size():
		var id: String = ordem[i]
		var nome: String = _nomes.get(id, id)
		if id == "jogador":
			nome = "[b]%s[/b]" % nome
		var seguido := "  · câmera" if id == _visual3d.foco and not _visual3d.visao_geral else ""
		linhas.append("[url=%s]%d [color=#%s]■[/color] %s%s[/url]" % [id, i + 1, _visual.cor_de(id).to_html(false), nome, seguido])
	_classificacao.text = "\n".join(linhas)


func _atualizar_placar(ordem: Array) -> void:
	var i := ordem.find("jogador")
	if i < 0 or _pista == null:
		return
	var s := _visual.distancia("jogador")
	var volta := clampi(floori(maxf(s, 0.0) / _pista.comprimento) + 1, 1, _voltas)
	_hud.text = "%dº/%d" % [i + 1, ordem.size()]
	_hud.add_theme_color_override("font_color", COR_DESTAQUE if i == 0 else Color.WHITE)
	_hud_volta.text = "VOLTA %d/%d · %s" % [volta, _voltas, _mmss(maxf(_visual.duracao() - _visual.tempo, 0.0))]
	# A pergunta da corrida: consigo alcançar o carro da frente?
	if _chegou:
		_placar.text = "Você terminou em %dº" % (i + 1)
		_visual3d.alvo = ""
	elif i > 0:
		var frente: String = ordem[i - 1]
		_visual3d.alvo = frente
		var t := _visual.tempo_em(frente, s)
		var gap := _visual.tempo - t if t >= 0.0 else -1.0
		var dist := _visual.distancia(frente) - s
		_placar.text = "ALVO: %s · %s" % [_nomes.get(frente, ""), "%.1f s à frente" % gap if gap >= 0.0 else "%d m" % roundi(dist)]
		if dist < DISPUTA_M:
			_placar.text += " · DISPUTA!"
	elif ordem.size() > 1:
		_visual3d.alvo = ""
		var t := _visual.tempo_em("jogador", _visual.distancia(ordem[1]))
		_placar.text = "LIDERANDO · %s" % ("%.1f s de vantagem" % (_visual.tempo - t) if t >= 0.0 else "")


## Ultrapassagens do jogador: destaque por alguns segundos.
func _atualizar_destaque(ordem: Array, delta: float) -> void:
	var pos := ordem.find("jogador") + 1
	if _posicao_antes > 0 and pos != _posicao_antes and _visual.tempo > 1.0:
		var ganhou := pos < _posicao_antes
		# Ganhou: o ultrapassado está logo atrás. Perdeu: quem passou está logo à frente.
		var outro: String = (ordem[pos] if pos < ordem.size() else "") if ganhou else (ordem[pos - 2] if pos >= 2 else "")
		_mostrar_destaque(("PASSOU %s! %dº" if ganhou else "Passado por %s · %dº") % [_nomes.get(outro, "um rival"), pos], ganhou)
		_sons.ultrapassagem(ganhou)
	_posicao_antes = pos
	_ordem_antes = ordem
	if _destaque_t > 0.0:
		_destaque_t -= delta
		if _destaque_t <= 0.0:
			_destaque.get_parent().visible = false


func _mostrar_destaque(texto: String, bom: bool) -> void:
	_destaque.text = texto
	var sb: StyleBoxFlat = _destaque.get_parent().get_theme_stylebox("panel")
	sb.bg_color = Color(0.1, 0.32, 0.18, 0.92) if bom else Color(0.42, 0.12, 0.1, 0.92)
	_destaque.get_parent().visible = true
	_destaque_t = DURACAO_DESTAQUE


static func _mmss(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


static func _mmss_dec(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
