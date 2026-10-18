extends Aba
## Arena (decisão 49): a inscrição, no padrão das Corridas: o seu carro da
## escalação (decisão 68) grande no topo e o cartão da luta com a regra (carro eliminado
## vai para o reparo; 3 carros na garagem; abre com a licença mínima) e o prêmio
## de referência. Entrar pede confirmação com o carro exato; a luta é
## resolvida e aplicada na hora (ArenaCarreira) e a LutaArena só mostra.

signal luta(dados_luta: Dictionary)

var _uid := -1
var _sim_arena := ""  # simulação: "" = sorteio entre as abertas
var _sim_equipes := 2  # simulação de teste: quantas equipes

## Faixa do emblema no cartão da luta (a mesma do traçado nos cartões de prova).
const LARGURA_FAIXA := 210.0
const ALTURA_FAIXA := 200.0


func _init(d: Node, j: Node) -> void:
	super(d, j, "Arena")


func construir() -> void:
	var motivo := ArenaCarreira.bloqueio(dados, jogador)
	if motivo != "":
		cabecalho("Arena", "Destruição: o último de pé vence", "fundo_competicoes")
		cartao_desafio_grid("arena", _confirmar_desafio)
		_cartao_luta(null, motivo)
		_simulacao(jogador.garagem.carro(jogador.carro_ativo))
		_registro()
		return
	# O seu carro (vaga ARENA 1 da escalação) grande no topo; trocar é na Oficina.
	var esc: Carro = Escalacao.carro(jogador, "arena1")
	_uid = esc.uid
	var faixa := topo_carro(esc)
	var trocar := Button.new()
	Tipografia.acao_secundaria(trocar, "Dupla da arena · trocar na Oficina", Color(0.93, 0.91, 0.87), 22, 48)
	sobre_imagem(trocar)
	trocar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	trocar.offset_left = -420
	trocar.offset_right = -16
	trocar.offset_top = 70
	trocar.offset_bottom = 118
	trocar.pressed.connect(func():
		jogador.carro_ativo = esc.uid
		ir_para.emit(GARAGEM))
	faixa.add_child(trocar)
	cartao_desafio_grid("arena", _confirmar_desafio)
	_cartao_luta(esc, "")
	_simulacao(esc)
	_registro()


## O cartão da luta, no padrão dos cartões de prova: o fundo da arena, o
## estado, o título, rivais e prêmio, a regra da perda e o botão. Bloqueada:
## o motivo no lugar do botão.
func _cartao_luta(esc: Carro, motivo: String) -> void:
	var pode := motivo == ""
	# O cenário da arena aberta de licença mais alta (a luta sorteia entre as
	# abertas); sem arte própria, o da arena genérica.
	var ordem := GestaoEquipe.ordem(dados)
	var abertas := ArenaCarreira.arenas_abertas(dados, jogador)
	abertas.sort_custom(func(x, y): return ordem.find(String(x.get("licenca", ""))) < ordem.find(String(y.get("licenca", ""))))
	var fundo: Texture2D = arte("banner_arena_" + String(abertas.back()["id"])) if not abertas.is_empty() else null
	var v := cartao_com_fundo(fundo if fundo != null else arte("banner_arena"), pode)
	# Como os cartões de prova: faixa da esquerda com o estado e o emblema da
	# arena (no lugar do traçado); à direita, o título, rivais e prêmio.
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	v.add_child(corpo)
	var faixa := Control.new()
	faixa.custom_minimum_size = Vector2(LARGURA_FAIXA, ALTURA_FAIXA)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corpo.add_child(faixa)
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
	faixa.add_child(estado)
	var emblema := TextureRect.new()
	emblema.texture = arte("emblema_arena")
	emblema.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblema.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblema.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emblema.offset_top = 36
	emblema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not pode:
		emblema.modulate = Color(0.6, 0.6, 0.62)
	faixa.add_child(emblema)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	corpo.add_child(col)
	var sobre := rotulo("ARENA DE DESTRUIÇÃO", 0, COR_SECUNDARIA, col)
	Tipografia.rotulo(sobre, "medium", 18)
	var titulo := Label.new()
	titulo.text = "ÚLTIMA DUPLA DE PÉ VENCE"
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(titulo, "semibold", 36)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87) if pode else COR_SECUNDARIA)
	col.add_child(titulo)
	# Campeonato em duplas: o nível diz quantas equipes (2×2 … 20 carros).
	var n_eq := ArenaCarreira.equipes_no_nivel(dados, ArenaCarreira.nivel(jogador))
	var nv := rotulo("CAMPEONATO %s · %d CARROS" % [ArenaCarreira.nome_nivel(n_eq), n_eq * 2], 0, COR_DESTAQUE if pode else COR_SECUNDARIA, col)
	Tipografia.rotulo(nv, "semibold", 22)
	var linha := "Em duplas: %d equipes" % n_eq
	if esc != null:
		linha += ", carros de potência parecida (%d cv). Na dupla, %s no segundo carro." % [
				roundi(esc.atributos_efetivos("seco")["potencia"]), ArenaCarreira.parceiro(dados, jogador, esc.uid)["nome"]]
	rotulo(linha, FONTE_PEQUENA, Color(0.86, 0.87, 0.9), col).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Prêmio: o de referência (vitória com uma eliminação), com a moeda.
	var lpr := rotulo("Prêmio (vitória com 1 eliminação)", 0, COR_SECUNDARIA, col)
	Tipografia.rotulo(lpr, "medium", 18)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	col.add_child(pr)
	var lv := rotulo("≈ " + dinheiro(ArenaCarreira.premio_base(dados)), 0, COR_DESTAQUE if pode else COR_SECUNDARIA, pr)
	Tipografia.numero(lv, 30)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF
	icone(ICONE_GIROS, 24, pr).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var regra := rotulo("Se a frente quebrar, o carro vai para o reparo (%s, ou conserto pago na hora)." % ArenaCarreira.texto_tempo(ArenaCarreira.tempo_reparo(dados)), FONTE_PEQUENA,
			COR_RUIM.lightened(0.25), v)
	regra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := Button.new()
	if pode:
		Tipografia.acao_primaria(b, "Entrar na arena   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, Tipografia.ALTURA_SECUNDARIA)
		b.pressed.connect(_confirmar.bind(esc))
		ancora("ARENA_ENTRAR", b)
	else:
		Tipografia.acao_primaria(b, motivo, COR_BLOQUEIO, Color(0.98, 0.95, 0.93), 24, Tipografia.ALTURA_SECUNDARIA)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.icon = icone_reduzido("icone_cadeado", 34)
		b.add_theme_constant_override("h_separation", 12)
		b.pressed.connect(func(): avisar(motivo, false))
	v.add_child(b)


func _confirmar(car: Carro) -> void:
	historia("ARENA_INSCRICAO")
	var par := ArenaCarreira.parceiro(dados, jogador, car.uid)
	painel.emit("Entrar na arena?", func(pv):
		rotulo("Vai o %s." % car.base["nome"], FONTE_PEQUENA + 4, Color.WHITE, pv)
		if par["real"]:
			var cp: Carro = jogador.garagem.carro(int(par["uid"]))
			rotulo("Na dupla, %s no %s." % [par["nome"], cp.base["nome"]], FONTE_PEQUENA + 2, Color.WHITE, pv)
			rotulo("Carro da dupla eliminado vai para o reparo (%s)." % ArenaCarreira.texto_tempo(ArenaCarreira.tempo_reparo(dados)), FONTE_PEQUENA + 2, Color(0.95, 0.6, 0.55), pv)
		else:
			rotulo("Na dupla, %s num carro emprestado." % par["nome"], FONTE_PEQUENA + 2, Color.WHITE, pv)
			rotulo("Se o carro for eliminado, vai para o reparo (%s)." % ArenaCarreira.texto_tempo(ArenaCarreira.tempo_reparo(dados)), FONTE_PEQUENA + 2, Color(0.95, 0.6, 0.55), pv),
		[["Entrar", func(): com_combustivel(_entrar.bind(car.uid))], ["Cancelar", func(): pass]])


## Resolve e aplica a luta agora; a tela da luta só mostra.
func _entrar(uid: int) -> void:
	if jogador.garagem.carro(uid) == null:
		return
	Combustivel.gastar(dados, jogador)
	jogador.contador_sementes += 1
	var semente := hash("arena:%d" % jogador.contador_sementes)
	var montada := ArenaCarreira.montar(dados, jogador, uid, semente)
	var carro: Carro = jogador.garagem.carro(uid)
	var pintura: Dictionary = montada["cores"].duplicate()
	pintura["jogador"] = CarroBloco.cor_do_carro(carro)
	var faixas: Dictionary = montada["faixas"].duplicate()
	faixas["jogador"] = carro.faixas
	var par: Dictionary = montada["parceiro"]
	var resultado := Arena.correr(montada["participantes"], montada["params"], semente, true)
	var final := ArenaCarreira.aplicar(dados, jogador, uid, resultado, int(par["uid"]) if par["real"] else -1,
			montada["modelos"])
	get_node("/root/SaveManager").salvar()
	mudou.emit()
	luta.emit({"resultado": resultado, "modelos": montada["modelos"], "nomes": montada["nomes"],
			"pinturas": pintura, "faixas": faixas, "final": final, "params": montada["params"],
			"blindagens": montada.get("blindagens", {}),
			"equipes": _equipe_de_cada(resultado, montada["equipes"])})


## Desafio do The Grid na arena (decisão 74): 2x2 contra os carros especiais
## da equipe; os dois primeiros carros livres entram (os escalados primeiro).
func _confirmar_desafio(eq: Dictionary) -> void:
	var livres := GridDesafio.carros_arena(jogador)
	var d := GridDesafio.de(dados, eq)
	painel.emit("Desafiar %s?" % eq["nome"], func(pv):
		rotulo(GridDesafio.resumo(dados, eq) + ".", FONTE_PEQUENA + 4, Color.WHITE, pv)
		rotulo("Vão o %s e o %s." % [livres[0].base["nome"], livres[1].base["nome"]], FONTE_PEQUENA + 2, Color.WHITE, pv)
		if int(d["rounds"]) > 1:
			rotulo("Melhor de %d: carro quebrado é trocado pelo próximo da garagem no round seguinte." % int(d["rounds"]),
					FONTE_PEQUENA + 2, Color.WHITE, pv)
		rotulo("Carro eliminado vai para o reparo (%s)." % ArenaCarreira.texto_tempo(ArenaCarreira.tempo_reparo(dados)),
				FONTE_PEQUENA + 2, Color(0.95, 0.6, 0.55), pv),
		[["Desafiar", func(): com_combustivel(_desafiar.bind(eq))], ["Cancelar", func(): pass]])


func _desafiar(eq: Dictionary) -> void:
	Combustivel.gastar(dados, jogador)
	jogador.contador_sementes += 1
	var semente := hash("grid:%d" % jogador.contador_sementes)
	var montada := GridDesafio.montar_arena(dados, jogador, eq, semente)
	var uid := Escalacao.uid(jogador, "arena1")
	var carro: Carro = jogador.garagem.carro(uid)
	var pintura: Dictionary = montada["cores"].duplicate()
	pintura["jogador"] = CarroBloco.cor_do_carro(carro)
	var faixas: Dictionary = montada["faixas"].duplicate()
	faixas["jogador"] = carro.faixas
	var par: Dictionary = montada["parceiro"]
	var resultado := Arena.correr(montada["participantes"], montada["params"], semente, true)
	var final := ArenaCarreira.aplicar(dados, jogador, uid, resultado, int(par["uid"]) if par["real"] else -1,
			montada["modelos"], eq)
	get_node("/root/SaveManager").salvar()
	mudou.emit()
	luta.emit({"resultado": resultado, "modelos": montada["modelos"], "nomes": montada["nomes"],
			"pinturas": pintura, "faixas": faixas, "final": final, "params": montada["params"],
			"blindagens": montada.get("blindagens", {}),
			"equipes": _equipe_de_cada(resultado, montada["equipes"])})


## id -> {nome da equipe, cor} para a lista da luta.
func _equipe_de_cada(resultado: Dictionary, equipes: Dictionary) -> Dictionary:
	var r := {}
	for id in resultado["carros"]:
		var eq: Dictionary = equipes.get(String(resultado["carros"][id].get("equipe", "")), {})
		var cor := Color(String(eq["cores"]["carro"])) if eq.has("cores") else COR_DESTAQUE
		var nome := String(eq.get("nome", ""))
		if String(resultado["carros"][id].get("equipe", "")) == "jogador":
			cor = COR_DESTAQUE
			nome = String(EquipeJogador.dados_equipe(dados, jogador).get("nome", "SUA EQUIPE"))
		r[id] = {"nome": nome, "cor": cor}
	return r


## Só no modo de playtest: uma luta de 2 a 10 equipes com o carro escolhido,
## sem prêmio, sem perda de carro, sem peças e sem contar no campeonato.
func _simulacao(car: Carro) -> void:
	if Preferencias.modo_teste == "" or car == null:
		return
	var c: Dictionary = dados.arena().get("campeonato", {})
	var mn := int(c.get("equipes_min", 2))
	var mx := int(c.get("equipes_max", 10))
	_sim_equipes = clampi(_sim_equipes, mn, mx)
	titulo_secao("SIMULAR LUTA", "teste")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	conteudo.add_child(h)
	var menos := Button.new()
	Tipografia.acao_primaria(menos, "−", COR_CARTAO, Color.WHITE, 34, 68)
	menos.custom_minimum_size.x = 76
	menos.disabled = _sim_equipes <= mn
	h.add_child(menos)
	var n := Label.new()
	n.text = "%d EQUIPES · %d CARROS" % [_sim_equipes, _sim_equipes * 2]
	Tipografia.rotulo(n, "semibold", 26)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var mais := Button.new()
	Tipografia.acao_primaria(mais, "+", COR_CARTAO, Color.WHITE, 34, 68)
	mais.custom_minimum_size.x = 76
	mais.disabled = _sim_equipes >= mx
	h.add_child(mais)
	menos.pressed.connect(func():
		_sim_equipes -= 1
		atualizar())
	# A arena da simulação: sorteio entre as abertas, ou qualquer uma das dez.
	var arenas: Array = [""] + dados.arena().get("arenas", []).map(func(a): return String(a["id"]))
	var i_ar := maxi(arenas.find(_sim_arena), 0)
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", 10)
	var ant := Button.new()
	Tipografia.acao_primaria(ant, "‹", COR_CARTAO, Color.WHITE, 34, 68)
	ant.custom_minimum_size.x = 76
	ha.add_child(ant)
	var na := Label.new()
	na.text = "SORTEIO DAS ABERTAS" if _sim_arena == "" else _nome_arena(_sim_arena).to_upper()
	Tipografia.rotulo(na, "semibold", 24)
	na.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	na.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	na.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	na.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ha.add_child(na)
	var prox := Button.new()
	Tipografia.acao_primaria(prox, "›", COR_CARTAO, Color.WHITE, 34, 68)
	prox.custom_minimum_size.x = 76
	ha.add_child(prox)
	ant.pressed.connect(func():
		_sim_arena = arenas[posmod(i_ar - 1, arenas.size())]
		atualizar())
	prox.pressed.connect(func():
		_sim_arena = arenas[posmod(i_ar + 1, arenas.size())]
		atualizar())
	mais.pressed.connect(func():
		_sim_equipes += 1
		atualizar())
	conteudo.add_child(ha)
	var b := Button.new()
	Tipografia.acao_primaria(b, "Simular com o %s" % car.base["nome"], Color(0.2, 0.21, 0.24), Color.WHITE, 26, 68)
	b.pressed.connect(_simular.bind(car.uid))
	conteudo.add_child(b)
	nota("", "Nada muda no jogo", "Sem prêmio, sem perda de carro, sem peças e sem contar no campeonato.")


## Nome da arena (com a marca das do The Grid).
func _nome_arena(id: String) -> String:
	for a in dados.arena().get("arenas", []):
		if a["id"] == id:
			return String(a["nome"]) + (" · Grid" if a.get("grid", false) else " · " + String(a.get("licenca", "")).capitalize())
	return id


## A luta de teste: monta com o número escolhido de equipes, resolve e mostra;
## não aplica nada.
func _simular(uid: int) -> void:
	var semente := hash("arena_sim:%d:%d" % [Time.get_ticks_usec(), _sim_equipes])
	var montada := ArenaCarreira.montar(dados, jogador, uid, semente, _sim_equipes, {}, _sim_arena)
	var carro: Carro = jogador.garagem.carro(uid)
	var pintura: Dictionary = montada["cores"].duplicate()
	pintura["jogador"] = CarroBloco.cor_do_carro(carro)
	var faixas: Dictionary = montada["faixas"].duplicate()
	faixas["jogador"] = carro.faixas
	var resultado := Arena.correr(montada["participantes"], montada["params"], semente, true)
	var final := {"simulacao": true, "perdeu": false, "carro": String(carro.base["nome"]),
			"posicao": resultado["classificacao"].find("jogador") + 1,
			"venceu_equipe": resultado.get("equipe_vencedora", "") == "jogador",
			"pontos": ArenaCarreira.pontos(resultado, "jogador", montada["params"]), "premio": 0}
	luta.emit({"resultado": resultado, "modelos": montada["modelos"], "nomes": montada["nomes"],
			"pinturas": pintura, "faixas": faixas, "final": final, "params": montada["params"],
			"blindagens": montada.get("blindagens", {}),
			"equipes": _equipe_de_cada(resultado, montada["equipes"])})


func _registro() -> void:
	var r: Dictionary = jogador.arena
	if int(r.get("lutas", 0)) == 0:
		return
	titulo_secao("HISTÓRICO")
	numeros([[str(int(r.get("lutas", 0))), "lutas"], [str(int(r.get("vitorias", 0))), "vitórias"],
			[str(int(r.get("quebrados", 0)) + Array(r.get("perdidos", [])).size()), "carros quebrados"]])
