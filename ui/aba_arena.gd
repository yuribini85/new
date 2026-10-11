extends Aba
## Arena (decisão 49): a inscrição, no padrão das Corridas: o carro escolhido
## grande no topo (setas trocam) e o cartão da luta com a regra (carro eliminado
## não volta; só com 2 carros na garagem; abre com a licença mínima) e o prêmio
## de referência. Entrar pede confirmação com o carro exato; a luta é
## resolvida e aplicada na hora (ArenaCarreira) e a LutaArena só mostra.

signal luta(dados_luta: Dictionary)

var _uid := -1


func _init(d: Node, j: Node) -> void:
	super(d, j, "Arena")


func construir() -> void:
	var motivo := ArenaCarreira.bloqueio(dados, jogador)
	if motivo != "":
		cabecalho("Arena", "Destruição: o último de pé vence", "fundo_competicoes")
		_cartao_luta(null, motivo)
		_registro()
		return
	var aptos := ArenaCarreira.aptos(jogador)
	if not aptos.any(func(x): return x.uid == _uid):
		_uid = jogador.carro_ativo if aptos.any(func(x): return x.uid == jogador.carro_ativo) else aptos[0].uid
	var esc: Carro = jogador.garagem.carro(_uid)
	# O carro inscrito grande no topo, como nas Corridas; setas trocam entre os aptos.
	var faixa := topo_carro(esc)
	var i := aptos.find(esc)
	setas_troca(faixa, aptos.size(), func(lado: int):
		_uid = aptos[posmod(i + lado, aptos.size())].uid
		atualizar())
	_cartao_luta(esc, "")
	_registro()


## O cartão da luta, no padrão dos cartões de prova: o fundo da arena, o
## estado, o título, rivais e prêmio, a regra da perda e o botão. Bloqueada:
## o motivo no lugar do botão.
func _cartao_luta(esc: Carro, motivo: String) -> void:
	var pode := motivo == ""
	var v := cartao_com_fundo(arte("banner_arena"), pode)
	var estado := Label.new()
	estado.text = "ABERTA" if pode else "BLOQUEADA"
	Tipografia.rotulo(estado, "semibold", 18)
	estado.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_DESTAQUE if pode else COR_NEUTRA
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	estado.add_theme_stylebox_override("normal", sb)
	estado.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(estado)
	var sobre := rotulo("ARENA DE DESTRUIÇÃO", 0, COR_SECUNDARIA, v)
	Tipografia.rotulo(sobre, "medium", 18)
	var titulo := Label.new()
	titulo.text = "ÚLTIMO DE PÉ VENCE"
	Tipografia.rotulo(titulo, "semibold", 40)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87) if pode else COR_SECUNDARIA)
	v.add_child(titulo)
	var p: Dictionary = dados.arena()
	var linha := "%d rivais" % int(p.get("rivais", 3))
	if esc != null:
		linha += " de potência parecida (%d cv)" % roundi(esc.atributos_efetivos("seco")["potencia"])
	rotulo(linha, FONTE_PEQUENA, Color(0.86, 0.87, 0.9), v).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Prêmio: o de referência (vitória com uma eliminação), com a moeda.
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	v.add_child(pr)
	var lpr := rotulo("Vitória com 1 eliminação ≈", 0, COR_SECUNDARIA, pr)
	Tipografia.rotulo(lpr, "medium", 20)
	lpr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lpr.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lpr.autowrap_mode = TextServer.AUTOWRAP_OFF
	var lv := rotulo(dinheiro(ArenaCarreira.premio_base(dados)), 0, COR_DESTAQUE if pode else COR_SECUNDARIA, pr)
	Tipografia.numero(lv, 30)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF
	icone(ICONE_GIROS, 24, pr).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var regra := rotulo("Se a frente quebrar, o carro sai da garagem para sempre.", FONTE_PEQUENA,
			COR_RUIM.lightened(0.25), v)
	regra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := Button.new()
	if pode:
		Tipografia.acao_primaria(b, "Entrar na arena   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, 72)
		b.pressed.connect(_confirmar.bind(esc))
		ancora("ARENA_ENTRAR", b)
	else:
		Tipografia.acao_primaria(b, motivo, COR_BLOQUEIO, Color(0.98, 0.95, 0.93), 24, 72)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.icon = icone_reduzido("icone_cadeado", 34)
		b.add_theme_constant_override("h_separation", 12)
		b.pressed.connect(func(): avisar(motivo, false))
	v.add_child(b)


func _confirmar(car: Carro) -> void:
	historia("ARENA_INSCRICAO")
	painel.emit("Entrar na arena?", func(pv):
		rotulo("Vai o %s." % car.base["nome"], FONTE_PEQUENA + 4, Color.WHITE, pv)
		rotulo("Se ele for eliminado, sai da garagem para sempre.", FONTE_PEQUENA + 2, Color(0.95, 0.6, 0.55), pv),
		[["Entrar", func(): _entrar(car.uid)], ["Cancelar", func(): pass]])


## Resolve e aplica a luta agora; a tela da luta só mostra.
func _entrar(uid: int) -> void:
	jogador.contador_sementes += 1
	var semente := hash("arena:%d" % jogador.contador_sementes)
	var montada := ArenaCarreira.montar(dados, jogador, uid, semente)
	var carro: Carro = jogador.garagem.carro(uid)
	var pintura := {"jogador": Color(carro.cor)} if String(carro.cor) != "" else {}
	var resultado := Arena.correr(montada["participantes"], dados.arena(), semente, true)
	var final := ArenaCarreira.aplicar(dados, jogador, uid, resultado)
	get_node("/root/SaveManager").salvar()
	mudou.emit()
	luta.emit({"resultado": resultado, "modelos": montada["modelos"], "nomes": montada["nomes"],
			"pinturas": pintura, "final": final})


func _registro() -> void:
	var r: Dictionary = jogador.arena
	if int(r.get("lutas", 0)) == 0:
		return
	titulo_secao("HISTÓRICO")
	numeros([[str(int(r.get("lutas", 0))), "lutas"], [str(int(r.get("vitorias", 0))), "vitórias"],
			[str(Array(r.get("perdidos", [])).size()), "carros perdidos"]])
