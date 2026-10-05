extends Aba

signal correr_iniciado

var _repeticoes := 1
## Estimativas simuladas sob demanda: chave (prova + carro + peças) -> faixa,
## ou "..." enquanto calcula.
var _estimativas := {}
## Categoria aberta (mantida ao voltar): "voce", "", "B" ou "A".
var _filtro := "voce"

const GRUPOS := [["voce", "Para você"], ["", "Sem licença"], ["B", "Licença B"], ["A", "Licença A"]]
## Cor de fundo da imagem da pista (o tema dela na corrida).
const FUNDO_PISTA := {"anel_do_vale": Color(0.16, 0.3, 0.18), "parque_das_docas": Color(0.22, 0.24, 0.28),
		"serra_alta": Color(0.26, 0.25, 0.17)}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Competições")


func construir() -> void:
	rotulo("Competições", FONTE_TITULO)
	var c := carro_ativo()
	if c == null:
		proximo_passo("Você precisa de um carro para correr.", "Ir para o Mercado", LOJA)
		return
	_carro_em_uso(c)
	if not jogador.fila.is_empty():
		_fila()
	else:
		_repeticoes_ui()
	var abas := HFlowContainer.new()
	abas.add_theme_constant_override("h_separation", 8)
	abas.add_theme_constant_override("v_separation", 8)
	for g in GRUPOS:
		var travada: bool = g[0] in ["B", "A"] and not g[0] in jogador.licencas
		var b := Button.new()
		b.text = g[1]
		b.toggle_mode = true
		b.button_pressed = _filtro == g[0]
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 25)
		if travada:
			b.add_theme_color_override("font_color", COR_SECUNDARIA)
		b.pressed.connect(func():
			_filtro = g[0]
			mudou.emit())
		abas.add_child(b)
	conteudo.add_child(abas)
	var lista := []
	for ev in dados.lista("eventos"):
		var motivos := Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas)
		if _filtro == "voce":
			if motivos.is_empty() and not ev["premios"].is_empty():
				lista.append([ev, motivos])
		elif ev["restricoes"].get("licenca", "") == _filtro:
			lista.append([ev, motivos])
	if _filtro == "voce":
		# Ainda não vencidas primeiro, da de prêmio menor (rivais mais fracos).
		lista.sort_custom(func(a, b):
			var va: bool = jogador.vitorias.has(a[0]["id"])
			var vb: bool = jogador.vitorias.has(b[0]["id"])
			if va != vb:
				return not va
			return a[0]["premios"][0] < b[0]["premios"][0])
	else:
		lista.sort_custom(func(a, b):
			if a[1].is_empty() != b[1].is_empty():
				return a[1].is_empty()
			return a[0]["nome"] < b[0]["nome"])
	if _filtro in ["B", "A"] and not _filtro in jogador.licencas:
		var v := cartao(COR_INFO)
		rotulo("Precisa da licença %s. Os testes ficam em Carreira." % _filtro, FONTE_PEQUENA + 2, Color.WHITE, v)
		botao("Ver licenças", func(): ir_para.emit(LICENCAS), true, false, v)
	if lista.is_empty():
		rotulo("Nenhuma prova aqui aceita o %s. Veja as outras categorias ou troque de carro." % c.base["nome"],
				FONTE_PEQUENA + 2, COR_SECUNDARIA)
	for l in lista:
		_cartao_evento(c, l[0], l[1])


## Carro em uso numa linha: foto, nome e números; trocar leva à Garagem.
func _carro_em_uso(c: Carro) -> void:
	var h := fileira()
	var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
	img.custom_minimum_size = Vector2(130, 72)
	h.add_child(img)
	var a := c.atributos_efetivos("seco")
	var l := rotulo("%s\n%d cv · %d kg · %s" % [c.base["nome"], a["potencia"], a["peso"], c.base["tracao"]],
			FONTE_PEQUENA + 2, Color.WHITE, h)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := botao_texto("Trocar", func(): ir_para.emit(GARAGEM), h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _fila() -> void:
	var f: Dictionary = jogador.fila
	var ev: Dictionary = dados.evento(f["evento_id"])
	var carro: Carro = jogador.garagem.carro(int(f["uid"]))
	var v := cartao(COR_BOM)
	rotulo("CORRENDO AGORA", FONTE_PEQUENA, COR_BOM, v)
	rotulo("%s · faltam %d corrida%s" % [ev["nome"], f["restantes"], "" if f["restantes"] == 1 else "s"], 0, Color.WHITE, v)
	var dur: float = jogador.fila_ctrl.duracao_atual()
	if dur > 0.0:
		var decorrido := clampf(Time.get_unix_time_from_system() - float(f["inicio"]), 0.0, dur)
		var falta := dur * int(f["restantes"]) - decorrido
		rotulo("Cada corrida ≈ %s · a fila termina em ≈ %s" % [_tempo(dur), _tempo(falta)], FONTE_PEQUENA + 2, Color.WHITE, v)
	var ganho := _ganho_estimado(ev, f)
	if ganho != "":
		rotulo(ganho, FONTE_PEQUENA + 2, COR_BOM, v)
	rotulo("Continua com o app fechado (até %s)." % _tempo(float(dados.carreira().get("teto_offline_s", 0.0))),
			FONTE_PEQUENA, COR_SECUNDARIA, v)
	var h := acoes(v)
	botao("Assistir", func(): ir_para.emit(CORRIDA), true, true, h)
	if int(f["restantes"]) > 1:
		botao("Parar após esta", func():
			jogador.fila_ctrl.parar_apos_atual()
			avisar("A fila para quando esta corrida terminar."), true, false, h)
	botao("Parar já", func():
		jogador.fila_ctrl.cancelar()
		avisar("Fila cancelada. A corrida em andamento não conta."), true, false, h)


## Faixa de ganho pelas posições já obtidas nesta fila (ou na última vez nesta
## prova). Estimativa, não promessa.
func _ganho_estimado(ev: Dictionary, f: Dictionary) -> String:
	var pos: Array = f.get("posicoes", [])
	if pos.is_empty() and jogador.historico.has(ev["id"]):
		pos = [jogador.historico[ev["id"]]["ultima_pos"]]
	if pos.is_empty():
		return "Ganho estimado: aparece depois da primeira corrida."
	var premios: Array = ev["premios"]
	var p := func(posicao: int) -> int: return int(premios[posicao - 1]) if posicao >= 1 and posicao <= premios.size() else 0
	var n := int(f["restantes"])
	var melhor: int = p.call(int(pos.min())) * n
	var pior: int = p.call(int(pos.max())) * n
	if melhor == pior:
		return "Ganho estimado no resto da fila: ≈ %s Cr" % dinheiro(melhor)
	return "Ganho estimado no resto da fila: %s a %s Cr (pelas posições até agora)" % [dinheiro(pior), dinheiro(melhor)]


static func _tempo(s: float) -> String:
	if s >= 3600.0:
		return "%d h %02d min" % [int(s) / 3600, (int(s) % 3600) / 60]
	if s >= 60.0:
		return "%d min %02d s" % [int(s) / 60, int(s) % 60]
	return "%d s" % int(s)


func _repeticoes_ui() -> void:
	var h := fileira()
	rotulo("Repetir a prova", FONTE_PEQUENA + 2, COR_SECUNDARIA, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao("−", func(): _repeticoes = maxi(1, _repeticoes - 1), _repeticoes > 1, false, h).custom_minimum_size = Vector2(80, 60)
	var n := Label.new()
	n.text = "×%d" % _repeticoes
	n.add_theme_font_size_override("font_size", 32)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	botao("+", func(): _repeticoes = mini(999, _repeticoes + 1), true, false, h).custom_minimum_size = Vector2(80, 60)
	botao("×10", func(): _repeticoes = mini(999, _repeticoes * 10), true, false, h).custom_minimum_size = Vector2(90, 60)


## Cartão da prova: imagem da pista, nome, requisitos curtos, prêmio e uma ação.
func _cartao_evento(c: Carro, ev: Dictionary, motivos: Array) -> void:
	var pode := motivos.is_empty()
	var vitorias: int = jogador.vitorias.get(ev["id"], 0)
	var tipo := _tipo(ev)
	var v := cartao(tipo[1])
	# Faixa de identidade: tipo da série e dificuldade estimada para o seu carro.
	var faixa := fileira(v)
	var t := rotulo(tipo[0].to_upper(), FONTE_PEQUENA, tipo[1].lightened(0.35), faixa)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var prog := rotulo(_progresso(ev), FONTE_PEQUENA, COR_SECUNDARIA, faixa)
	prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var topo := fileira(v)
	var fundo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = FUNDO_PISTA.get(ev["pista"], COR_NEUTRA)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	fundo.add_theme_stylebox_override("panel", sb)
	var ic := icone_pista(ev["pista"])
	ic.custom_minimum_size = Vector2(130, 96)
	fundo.add_child(ic)
	fundo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(fundo)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	topo.add_child(info)
	rotulo(ev["nome"], 28, Color.WHITE if pode else COR_SECUNDARIA, info)
	rotulo("%s · %d volta%s" % [nome_pista(ev["pista"]), ev["voltas"], "" if ev["voltas"] == 1 else "s"],
			FONTE_PEQUENA, COR_SECUNDARIA, info)
	var premio: int = int(ev["premios"][0]) if not ev["premios"].is_empty() else 0
	rotulo("1º lugar: %s Cr" % dinheiro(premio), 28, COR_BOM if pode else COR_SECUNDARIA, info)
	var etiquetas := []
	if vitorias > 0:
		etiquetas.append(["VENCIDA ×%d" % vitorias, COR_BOM])
	for r in _regras(ev["restricoes"]).slice(0, 3):
		etiquetas.append([r, COR_NEUTRA.lightened(0.3)])
	if pode:
		var pp := _potencia_peso(c, ev)
		if not pp.is_empty():
			etiquetas.append(pp)
	selos(etiquetas, v)
	# Recompensa especial: o carro-prêmio aparece no cartão.
	if ev.get("carro_premio") != null and vitorias == 0:
		var cp: Dictionary = dados.carro(ev["carro_premio"])
		var hp := fileira(v)
		var img := icone_carro(cp)
		img.custom_minimum_size = Vector2(150, 84)
		hp.add_child(img)
		var lp := rotulo("PRÊMIO ESPECIAL\n%s na 1ª vitória" % cp.get("nome", ""), FONTE_PEQUENA, COR_INFO.lightened(0.3), hp)
		lp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := fileira(v)
	if pode:
		var hist: Dictionary = jogador.historico.get(ev["id"], {})
		var l := rotulo("Seu melhor: %dº" % hist["melhor_pos"] if not hist.is_empty() else "", FONTE_PEQUENA,
				COR_SECUNDARIA, h)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var est = _estimativas.get(_chave(ev, c))
		if est == null:
			botao_texto("Estimar desempenho", _estimar.bind(ev, c), h)
		elif est is String:
			rotulo("Estimando…", FONTE_PEQUENA, COR_INFO, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			rotulo("Estimativa: %s\n%d corridas simuladas, preparação atual" % [Mecanico.texto_faixa(est), Mecanico.AMOSTRAS],
					FONTE_PEQUENA, COR_INFO, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao("Correr" if _repeticoes == 1 else "Correr ×%d" % _repeticoes, _correr.bind(ev["id"]),
				jogador.fila.is_empty(), true, h)
	else:
		rotulo("✗ " + "; ".join(motivos), FONTE_PEQUENA, COR_RUIM, h)


## "Etapa 1 de 3 · 1/3 vencidas": onde esta prova fica na série.
func _progresso(ev: Dictionary) -> String:
	var serie := String(ev["nome"]).split(" — ")[0]
	var etapas: Array = dados.lista("eventos").filter(func(e): return String(e["nome"]).split(" — ")[0] == serie)
	if etapas.size() <= 1:
		return ""
	var vencidas := etapas.filter(func(e): return jogador.vitorias.has(e["id"])).size()
	return "Etapa %d de %d · %d/%d vencidas" % [etapas.find(ev) + 1, etapas.size(), vencidas, etapas.size()]


## Tipo da série pelo que ela exige: [nome, cor de identidade].
func _tipo(ev: Dictionary) -> Array:
	var r: Dictionary = ev["restricoes"]
	if r.has("tracao"):
		var t: String = r["tracao"][0]
		return [{"FF": "Tração dianteira", "FR": "Tração traseira", "4WD": "Tração integral", "MR": "Motor central"}.get(t, "Tração " + t),
				{"FF": Color(0.25, 0.6, 0.9), "FR": Color(0.9, 0.35, 0.3), "4WD": Color(0.85, 0.65, 0.2), "MR": Color(0.7, 0.4, 0.9)}.get(t, COR_INFO)]
	if r.has("ano_max"):
		return ["Clássicos", Color(0.8, 0.55, 0.3)]
	if r.has("potencia_max") and float(r["potencia_max"]) <= 200.0:
		return ["Potência limitada", Color(0.35, 0.75, 0.5)]
	if r.has("potencia_max"):
		return ["Até %d cv" % r["potencia_max"], Color(0.3, 0.7, 0.75)]
	return ["Aberta", Color(0.75, 0.75, 0.8)]


## Potência/peso do carro em uso frente à mediana dos rivais da prova
## (atributos efetivos, com peças e pneus): Acima, Próxima ou Abaixo. Leitura
## rápida, não dificuldade: pneus, curvas e frenagem também contam, e para
## isso há "Estimar desempenho". Limites (+8% / −5%) provisórios.
func _potencia_peso(c: Carro, ev: Dictionary) -> Array:
	var meu := c.atributos_efetivos(ev["condicao"])
	var rivais := []
	for i in ev["adversarios"].size():
		var a: Dictionary = jogador.carreira.atributos_participante(ev["id"], "adv%d_%s" % [i, ev["adversarios"][i]["carro"]], c.uid)
		if not a.is_empty():
			rivais.append(a["potencia"] / maxf(a["peso"], 1.0))
	if rivais.is_empty():
		return []
	rivais.sort()
	var razao: float = (meu["potencia"] / maxf(meu["peso"], 1.0)) / maxf(rivais[rivais.size() / 2], 1e-6)
	var nivel := "Acima" if razao >= 1.08 else ("Próxima" if razao >= 0.95 else "Abaixo")
	return ["Potência/peso frente aos rivais: " + nivel,
			{"Acima": COR_BOM, "Próxima": COR_INFO, "Abaixo": COR_RUIM}[nivel]]


## Chave da estimativa: muda se o carro, as peças ou os pneus mudarem.
static func _chave(ev: Dictionary, c: Carro) -> String:
	return "%s|%d|%s|%s" % [ev["id"], c.uid, str(c.pecas.keys().map(func(k): return c.pecas[k]["id"])),
			str(c.pneus.map(func(p): return p["id"]))]


## Simula a prova com o carro em uso (Mecanico.avaliar, mesmas sementes do
## "O que ajuda?") e mostra a faixa típica de posições. Sob demanda: a lista
## abre rápido e só calcula o que o jogador pedir.
func _estimar(ev: Dictionary, c: Carro) -> void:
	var chave := _chave(ev, c)
	_estimativas[chave] = "..."
	await get_tree().process_frame
	await get_tree().process_frame
	var a := Mecanico.avaliar(jogador.carreira, ev["id"], c.uid, c)
	if a.is_empty():
		_estimativas.erase(chave)
	else:
		_estimativas[chave] = a["faixa"]
	mudou.emit()


## Regras da prova em texto curto ("até 150 cv", "tração FF").
func _regras(r: Dictionary) -> Array:
	var t := []
	if r.has("potencia_max"):
		t.append("até %d cv" % r["potencia_max"])
	if r.has("tracao"):
		t.append("tração " + "/".join(r["tracao"]))
	if r.has("categoria"):
		t.append("/".join(r["categoria"].map(func(x): return NOMES_CATEGORIA_CARRO.get(x, x))))
	if r.has("fabricante"):
		t.append("/".join(r["fabricante"].map(func(x): return dados.item("fabricantes", x).get("nome", x))))
	if r.has("ano_min"):
		t.append("de %d em diante" % r["ano_min"])
	if r.has("ano_max"):
		t.append("até %d" % r["ano_max"])
	if r.has("licenca"):
		t.append("licença " + r["licenca"])
	return t


func _correr(evento_id: String) -> void:
	var motivo: String = jogador.fila_ctrl.iniciar(evento_id, jogador.carro_ativo, _repeticoes, Time.get_unix_time_from_system())
	if motivo != "":
		avisar("Não deu para correr: %s." % motivo, false)
		return
	avisar("Largada! %s%s." % [dados.evento(evento_id)["nome"], "" if _repeticoes == 1 else " ×%d" % _repeticoes])
	correr_iniciado.emit()
