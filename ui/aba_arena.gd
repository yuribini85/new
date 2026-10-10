extends Aba
## Arena (decisão 49): a inscrição. Mostra a regra (carro eliminado não volta;
## só com 2 carros na garagem; abre com a licença mínima), o carro escolhido e
## o prêmio de referência. Entrar pede confirmação com o carro exato; a luta é
## resolvida e aplicada na hora (ArenaCarreira) e a LutaArena só mostra.

signal luta(dados_luta: Dictionary)

var _uid := -1


func _init(d: Node, j: Node) -> void:
	super(d, j, "Arena")


func construir() -> void:
	cabecalho("Arena", "Destruição: o último de pé vence", "fundo_competicoes")
	var motivo := ArenaCarreira.bloqueio(dados, jogador)
	var c := cartao(COR_RUIM if motivo != "" else Color.TRANSPARENT)
	nota("icone_info", "Carro eliminado não volta",
			"Se a frente do seu carro quebrar, ele sai da garagem para sempre. O prêmio vem dos pontos: giros que você provoca, carros que elimina e ficar de pé no fim.",
			c, COR_RUIM)
	if motivo != "":
		rotulo(motivo, FONTE_PEQUENA + 2, Color(0.95, 0.75, 0.7), c)
		_registro()
		return
	var aptos := ArenaCarreira.aptos(jogador)
	if not aptos.any(func(x): return x.uid == _uid):
		_uid = jogador.carro_ativo if aptos.any(func(x): return x.uid == jogador.carro_ativo) else aptos[0].uid
	titulo_secao("SEU CARRO", "toque para trocar")
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	conteudo.add_child(grade)
	for car in aptos:
		_opcao(grade, car)
	var esc: Carro = jogador.garagem.carro(_uid)
	var a := esc.atributos_efetivos("seco")
	titulo_secao("A LUTA")
	var info := cartao()
	rotulo("%d rivais com carros de potência parecida (%d cv)." % [int(dados.arena().get("rivais", 3)), roundi(a["potencia"])],
			FONTE_PEQUENA + 2, Color.WHITE, info)
	rotulo("Vencer com uma eliminação paga cerca de %s giros (o 1º lugar médio das corridas da %s)." % [
			dinheiro(ArenaCarreira.premio_base(dados)), String(dados.arena().get("licenca_minima", "")).capitalize()],
			FONTE_PEQUENA + 2, COR_SECUNDARIA, info)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Entrar na arena   →", COR_RUIM, Color.WHITE, 34, 84)
	b.pressed.connect(_confirmar.bind(esc))
	conteudo.add_child(b)
	ancora("ARENA_ENTRAR", b)
	_registro()


func _opcao(grade: GridContainer, car: Carro) -> void:
	var v := cartao(COR_DESTAQUE if car.uid == _uid else Color.TRANSPARENT, grade)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var img := icone_carro(car.base, false, Color(car.cor) if String(car.cor) != "" else Color(0, 0, 0, 0))
	v.add_child(img)
	var a := car.atributos_efetivos("seco")
	var n := rotulo(nome_curto(car.base["nome"]), FONTE_PEQUENA + 2, Color.WHITE if car.uid == _uid else COR_SECUNDARIA, v)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo("%d cv · %d kg" % [roundi(a["potencia"]), roundi(a["peso"])], FONTE_PEQUENA - 2, COR_SECUNDARIA, v)
	var toque := Button.new()
	toque.flat = true
	toque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toque.pressed.connect(func():
		_uid = car.uid
		atualizar())
	v.get_parent().add_child(toque)


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
