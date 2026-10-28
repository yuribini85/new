class_name RinhaIdle
extends Control
## Aba RINHA do The Fastfather (pedido do usuário, 2026-10-27): a arena do
## Chrome & Wreckage com outro nome, rodando o tempo todo ao lado da corrida —
## a corrida é o idle, assistir à Rinha de vez em quando é o tempero. Uma luta
## atrás da outra (IdleEstado.lutar_rinha), com o rapaz mais forte da família
## num carro de época; o prêmio entra pela posição. Fora desta aba a luta segue
## sem desenhar; aqui a arena 3D mostra o ponto em que ela está.

signal terminou(pos: int, premio: float)

## Apresentação, não balanceamento.
const VELOCIDADE := 2.0  # como a arena da corrida (VELOCIDADE_ARENA)
const PAUSA_S := 5.0  # entre uma luta e outra
const FEED := 5
## Carros de época na Rinha: o dos rapazes e os das famílias rivais.
const MODELO_RAPAZES := "cupe_1940"
const MODELOS := ["cupe_1928", "cupe_1940", "hotrod_1932", "seda_1951"]
## Antes de cada luta, o seu capanga de corpo inteiro contra o da família rival
## (em sombra), com o VS no meio (sugestão aprovada, 2026-10-28).
const APRESENTACAO_S := 2.4

var tela: Node  # tela_idle.gd: estado, dados
var _arena: Arena3D
var _res := {}
var _t := 0.0
var _pausa := 0.0
var _semente := 0
var _liga: Label
var _quem: Label
var _feed: VBoxContainer
var _vista: Control
var _vs: Control
var _vs_eu: TextureRect
var _vs_rival: TextureRect
var _vs_nome_eu: Label
var _vs_nome_rival: Label
var _apres := 0.0


func _init(tela_: Node) -> void:
	tela = tela_
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var cab := IdleUI.painel(IdleUI.COR_CARTAO, 12, 14, v)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 2)
	cab.add_child(c)
	var t := IdleUI.rotulo("RINHA DAS FAMÍLIAS", 34, IdleUI.COR_OURO_CLARO, c, "deco")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_liga = IdleUI.rotulo("", 20, IdleUI.COR_CROMO, c)
	_liga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quem = IdleUI.rotulo("", 20, IdleUI.COR_TEXTO, c)
	_quem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cab.add_child(MolduraDeco.new(4.0))
	_vista = Control.new()
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vista.custom_minimum_size = Vector2(0, 420)
	_vista.clip_contents = true
	v.add_child(_vista)
	_arena = Arena3D.new()
	_arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vista.add_child(_arena)
	_montar_vs()
	var caixa := IdleUI.painel(IdleUI.COR_CARTAO, 12, 14, v)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 2)
	caixa.add_child(_feed)
	IdleUI.rotulo("ÚLTIMAS LUTAS", 20, IdleUI.COR_OURO, _feed)
	caixa.add_child(MolduraDeco.new(4.0))


func _montar_vs() -> void:
	_vs = Control.new()
	_vs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs.visible = false
	_vista.add_child(_vs)
	var fundo := ColorRect.new()
	fundo.color = Color(IdleUI.COR_CARVAO, 0.78)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs.add_child(fundo)
	_vs_eu = _figura(Control.PRESET_LEFT_WIDE)
	_vs_rival = _figura(Control.PRESET_RIGHT_WIDE)
	_vs_rival.flip_h = true
	_vs_rival.self_modulate = Color(0.05, 0.05, 0.06)  # o rival em sombra
	var vs := IdleUI.rotulo("VS", 72, IdleUI.COR_OURO_CLARO, _vs, "deco")
	vs.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vs.grow_vertical = Control.GROW_DIRECTION_BOTH
	_vs_nome_eu = _nome_vs(HORIZONTAL_ALIGNMENT_LEFT, IdleUI.COR_TEXTO)
	_vs_nome_rival = _nome_vs(HORIZONTAL_ALIGNMENT_RIGHT, IdleUI.COR_VINHO_CLARO)


func _figura(lado: int) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	t.set_anchors_and_offsets_preset(lado)
	t.anchor_right = 0.45 if lado == Control.PRESET_LEFT_WIDE else 1.0
	t.anchor_left = 0.55 if lado == Control.PRESET_RIGHT_WIDE else 0.0
	t.offset_top = 16
	t.offset_bottom = -64
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vs.add_child(t)
	return t


func _nome_vs(alin: int, cor: Color) -> Label:
	var l := IdleUI.rotulo("", 24, cor, _vs, "display")
	l.horizontal_alignment = alin
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_left = 16
	l.offset_right = -16
	l.offset_top = -58
	l.offset_bottom = -14
	return l


## O seu capanga contra o da família rival antes da luta: entram dos lados.
func _apresentar() -> void:
	var e: IdleEstado = tela.estado
	var rapaz := e.melhor_rapaz()
	var elenco: Array = CenaQuadrinho.carregar("rapazes").get("elenco", [])
	var familias: Array = CenaQuadrinho.carregar("familias").get("nomes", ["Rival"])
	if rapaz.is_empty() or elenco.is_empty() or not is_visible_in_tree() or Preferencias.reduzir_animacoes:
		_apres = 0.0
		_vs.visible = false
		return
	_vs_eu.texture = load(PilotosIdle.arte_rapaz(rapaz))
	var meu := (int(rapaz["uid"]) - 1) % elenco.size()
	var outro := (meu + 1 + _semente % (elenco.size() - 1)) % elenco.size()
	_vs_rival.texture = load("res://arte/fastfather/rapazes/%s.png" % elenco[outro]["arte"])
	_vs_nome_eu.text = "%s · %s" % [PilotosIdle.nome_rapaz(rapaz).to_upper(), IdleUI.nv(int(rapaz["nivel"])).to_upper()]
	_vs_nome_rival.text = "FAMÍLIA %s" % String(familias[_semente % familias.size()]).to_upper()
	_apres = APRESENTACAO_S
	_vs.visible = true
	_vs.modulate.a = 1.0
	var tw := create_tween().set_parallel()
	_vs_eu.position.x -= 260.0
	_vs_rival.position.x += 260.0
	tw.tween_property(_vs_eu, "position:x", _vs_eu.position.x + 260.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_vs_rival, "position:x", _vs_rival.position.x - 260.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sons.tocar_ui(self, "passagem", -6.0)


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	var r := e.id_rinha()
	if r == "":
		return
	var ligas: Array = e.dados_modalidade(r)["ligas"]
	_liga.text = String(ligas[e.liga_rinha()]["nome"]).to_upper()
	var rapaz := e.melhor_rapaz()
	_quem.text = ("Na Rinha: %s · %s" % [PilotosIdle.nome_rapaz(rapaz), IdleUI.nv(int(rapaz["nivel"]))]) if not rapaz.is_empty() \
			else "Sem capangas: luta o motorista do Tony. Contrate na aba CAPANGAS."


func _process(delta: float) -> void:
	var e: IdleEstado = tela.estado if tela != null else null
	if e == null or not e.rinha_aberta():
		return
	if _res.is_empty():
		_pausa -= delta
		if _pausa <= 0.0:
			_nova()
		return
	if _apres > 0.0:
		# A apresentação segura a luta parada no começo e some no fim.
		_apres -= delta
		_vs.modulate.a = clampf(_apres / 0.35, 0.0, 1.0)
		if _apres <= 0.0:
			_vs.visible = false
		return
	_t += delta * VELOCIDADE
	if is_visible_in_tree():
		_arena.tempo = minf(_t, _arena.duracao())
		_arena.atualizar(delta)
	if _t >= float(_res.get("duracao", 0.0)):
		_fim()


## Uma luta nova: a simulação inteira de uma vez; a arena 3D mostra as amostras.
func _nova() -> void:
	var e: IdleEstado = tela.estado
	_semente += 1
	_res = e.lutar_rinha(tela.dados, _semente * 7919 + e.corridas)
	_t = 0.0
	if _res.is_empty():
		return
	var parts: Array = e._na_rinha(func(): return e.participantes(tela.dados))
	var categorias := {}
	var pinturas := {}
	var faixas := {}
	for p in parts:
		var id := String(p["id"])
		var base: Dictionary = tela.dados.carro(p["carro"]).duplicate()
		base["epoca"] = MODELO_RAPAZES if id == "jogador" else String(MODELOS[posmod(hash(id + str(_semente)), MODELOS.size())])
		categorias[id] = base
		var pe: Array = PinturaEpoca.do_jogador("hot_rod") if id == "jogador" \
				else PinturaEpoca.do_rival("hot_rod", id, "%d|%s" % [_semente, id])
		pinturas[id] = pe[0]
		faixas[id] = pe[1]
	_arena.faixas_pintura = faixas
	_arena.mostrar(_res, e._na_rinha(func(): return e.params_arena(tela.dados)), categorias, pinturas)
	_arena.tempo = 0.0
	atualizar()
	_apresentar()


func _fim() -> void:
	var e: IdleEstado = tela.estado
	var pos := IdleEstado.posicao(_res)
	var premio := e.pagar_rinha(pos)
	_res = {}
	_pausa = PAUSA_S
	var l := IdleUI.rotulo("%s · %dº lugar · +$%s" % [_liga.text, pos, IdleUI.curto(premio)], 18,
			IdleUI.COR_OURO_CLARO if pos == 1 else IdleUI.COR_TEXTO, null, "regular")
	_feed.add_child(l)
	_feed.move_child(l, 1)
	if e.trofeu_novo != "":  # troféu da arena ganho na luta
		e.trofeu_novo = ""
		var t := IdleUI.rotulo("TROFÉU NOVO!", 18, IdleUI.COR_OURO, null, "display")
		_feed.add_child(t)
		_feed.move_child(t, 1)
	while _feed.get_child_count() > FEED + 1:
		_feed.get_child(_feed.get_child_count() - 1).free()
	terminou.emit(pos, premio)
