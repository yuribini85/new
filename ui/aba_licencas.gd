extends Aba

## Resultado do último teste: {"teste", "tempo", "grau", "tempos", "concedida", "licenca"} ou erro.
var _resultado := {}

const CORES_GRAU := {
	"ouro": Color(0.98, 0.8, 0.2), "prata": Color(0.8, 0.83, 0.88), "bronze": Color(0.85, 0.55, 0.3),
}


## Licenças com a lista de séries liberadas aberta.
var _expandida := {}
## Bancada de contrato aberta ("" = lista), a montagem em edição e o último
## relatório dela.
var _bancada := ""
var _montagem := {}
var _avaliacao := {}

const NOMES_CATEGORIA := preload("res://ui/aba_oficina.gd").NOMES_CATEGORIA
## Brasão da licença atual no topo (altura, px) e o da próxima no cartão.
const ALTURA_BRASAO := 230.0
const BRASAO_CARTAO := 190.0


func _init(d: Node, j: Node) -> void:
	super(d, j, "Carreira")


## Carreira: o brasão da licença atual, os objetivos, o cartão da próxima
## licença (só ela) e a coleção por workshop. Recomeçar e a versão ficam nas
## Configurações.
func construir() -> void:
	if _bancada != "" and dados.existe("contratos", _bancada):
		_tela_bancada(dados.item("contratos", _bancada))
		return
	_bancada = ""
	var l := Licencas.new(dados, jogador)
	var agora := Time.get_unix_time_from_system()
	_brasao()
	_mostrar_resultado()
	_objetivos()
	var c := carro_ativo()
	var proxima := {}
	for lic in dados.lista("licencas"):
		if l.estado(lic["id"], agora) != Licencas.COMPLETE:
			proxima = lic
			break
	if not proxima.is_empty():
		var st := l.estado(proxima["id"], agora)
		var v := _cartao_proxima(l, proxima, st, agora)
		if st in [Licencas.READY]:
			# A avaliação entra no mesmo cartão (sem repetir o cabeçalho).
			if not Contratos.da_licenca(dados, proxima["id"]).is_empty():
				_cartao_contratos(proxima, v)
			elif proxima["testes"].is_empty():
				nota("icone_alerta", "Avaliação da %s em preparação" % proxima["nome"], "", v, COR_INFO)
			elif c == null:
				nota("icone_cadeado", "%s: compre um carro primeiro" % proxima["nome"],
						"Os testes da %s são feitos com o carro em uso." % proxima["nome"], v)
			else:
				_cartao_licenca(c, proxima, v)
		if st == Licencas.TRAINING:
			# Relógio do treino na tela: reconstrói a cada segundo enquanto treina.
			var t := Timer.new()
			t.wait_time = 1.0
			t.autostart = true
			t.timeout.connect(func(): mudou.emit())
			conteudo.add_child(t)
	_colecao()


## Licença mais alta conquistada (vazio sem nenhuma).
func _licenca_atual() -> Dictionary:
	var atual := {}
	for lic in dados.lista("licencas"):
		if lic["id"] in jogador.licencas:
			atual = lic
	return atual


## Topo: o brasão da licença atual sobre o cenário, com o nome embaixo. Sem
## licença, o brasão da primeira, apagado.
func _brasao() -> void:
	var atual := _licenca_atual()
	var mostrar: Dictionary = atual if not atual.is_empty() else (dados.lista("licencas")[0] if not dados.lista("licencas").is_empty() else {})
	var faixa := ilustracao("fundo_carreira", ALTURA_BRASAO + 140.0)
	cenario_topo(faixa)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 70  # abaixo das abas penduradas do cabeçalho
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(v)
	var tex := selo_licenca(String(mostrar.get("id", "")))
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(0, ALTURA_BRASAO)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if atual.is_empty():
			t.modulate = Color(0.35, 0.35, 0.38)
		v.add_child(t)
		if not atual.is_empty():
			ancora("LIC_" + String(atual["id"]), t)
	var nome := Label.new()
	nome.text = String(atual.get("nome", "Sem licença")).to_upper()
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(nome, "semibold", 40)
	nome.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87) if not atual.is_empty() else COR_SECUNDARIA)
	nome.add_theme_constant_override("outline_size", 6)
	nome.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	v.add_child(nome)


func _objetivos() -> void:
	var lista := Objetivos.lista(jogador, dados)
	var atual := Objetivos.atual(lista)
	var v := cartao()
	titulo_secao("OBJETIVOS", "", v)
	for i in lista.size():
		var o: Dictionary = lista[i]
		var h := fileira(v)
		var l := rotulo(("✓ " if o["feito"] else ("→ " if i == atual else "· ")) + o["texto"], FONTE_PEQUENA + 3,
				COR_BOM if o["feito"] else (Color.WHITE if i == atual else COR_SECUNDARIA), h)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i == atual:
			var b := botao("Ir", func(): ir_para.emit(o["aba"]), true, true, h)
			b.custom_minimum_size = Vector2(110, 60)


## Coleção por workshop, em lista (a mesma linha das Lojas) com a barra de
## quanto da frota dela você tem; tocar abre os carros (os que faltam, em
## silhueta preta com "descobrir").
func _colecao() -> void:
	var tenho := {}
	for c in jogador.garagem.lista():
		tenho[c.id] = true
	var titulo := rotulo("COLEÇÃO · %d de %d" % [tenho.size(), dados.lista("carros").size()], 0, COR_SECUNDARIA)
	Tipografia.rotulo(titulo, "medium", 22)
	for w in dados.workshops():
		var carros: Array = dados.lista("carros").filter(func(c): return c["fabricante"] in w.get("fabricantes", []))
		if carros.is_empty():
			continue
		var meus := carros.filter(func(c): return tenho.has(c["id"])).size()
		linha_workshop(w, "%d/%d" % [meus, carros.size()], _abrir_workshop.bind(w, carros, tenho),
				float(meus) / carros.size())


## Os carros da workshop em grade: os seus com foto e nome (tocar abre a
## ficha); os que faltam em silhueta preta, com "descobrir".
func _abrir_workshop(w: Dictionary, carros: Array, tenho: Dictionary) -> void:
	painel.emit(String(w.get("nome", "")), func(pv):
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		pv.add_child(g)
		for c in carros:
			var meu: bool = tenho.has(c["id"])
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 140)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not meu
			var sb := StyleBoxFlat.new()
			sb.bg_color = COR_CARTAO.lightened(0.04)
			sb.set_corner_radius_all(10)
			for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(estado, sb)
			var v := VBoxContainer.new()
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(v)
			var img := icone_carro(c)
			img.custom_minimum_size = Vector2(0, 96)
			if not meu:
				img.modulate = Color(0, 0, 0)  # silhueta 100% preta
			v.add_child(img)
			var l := Label.new()
			l.text = nome_curto(c["nome"]) if meu else "DESCOBRIR"
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Tipografia.rotulo(l, "medium" if meu else "semibold", 20)
			l.add_theme_color_override("font_color", Color.WHITE if meu else COR_SECUNDARIA)
			l.add_theme_color_override("font_disabled_color", COR_SECUNDARIA)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.clip_text = true
			v.add_child(l)
			if meu:
				b.pressed.connect(func(): ficha_modelo(c))
			g.add_child(b), [["Fechar", func(): pass]])


## Renda por nível de licença, somando as sessões registradas: base medida
## para decidir patrocínio e staff (decisão 38), sem estimar.
func _renda(v: VBoxContainer, sessoes: Array) -> void:
	var r := RegistroSessao.renda_por_nivel(sessoes)
	if r.is_empty():
		return
	rotulo("Renda por nível (todas as sessões)", FONTE_PEQUENA + 2, Color.WHITE, v)
	var ordem: Array = dados.carreira().get("niveis", [])
	var niveis: Array = r.keys()
	niveis.sort_custom(func(a, b): return ordem.find(a) < ordem.find(b))
	for n in niveis:
		var x: Dictionary = r[n]
		var ganho: int = int(x["premio"]) + int(x["bonus"])
		var minutos: float = float(x["duracao_s"]) / 60.0
		rotulo("%s: %d corrida%s · %d%% vitórias · %s G por corrida · %s G por minuto de corrida%s%s" % [
				n, x["corridas"], "" if x["corridas"] == 1 else "s", roundi(100.0 * x["vitorias"] / x["corridas"]),
				dinheiro(roundi(float(ganho) / x["corridas"])),
				dinheiro(roundi(ganho / minutos)) if minutos > 0.0 else "—",
				" · %d com o app fechado" % x["offline"] if int(x["offline"]) > 0 else "",
				" · folha da equipe %s G" % dinheiro(int(x["folha"])) if int(x["folha"]) != 0 else ""],
				FONTE_PEQUENA, COR_SECUNDARIA, v)


## Saves de teste (Cenarios): cada um num arquivo próprio; o seu jogo não muda.
func _cenarios(v: VBoxContainer) -> void:
	var sm := get_node("/root/SaveManager")
	rotulo("Cenários de teste", FONTE_PEQUENA + 2, Color.WHITE, v)
	if sm.cenario != "":
		rotulo("Em uso: %s" % _nome_cenario(sm.cenario), FONTE_PEQUENA, COR_INFO, v)
		botao("Voltar ao meu jogo", func():
			sm.voltar_ao_jogo()
			avisar("De volta ao seu jogo.")
			ir_para.emit(GARAGEM), true, true, v)
	for c in Cenarios.LISTA:
		linha(String(c["nome"]), [["Abrir", _abrir_cenario.bind(c)]], null, v)
		rotulo(String(c["detalhe"]), FONTE_PEQUENA - 2, COR_SECUNDARIA, v)


func _abrir_cenario(c: Dictionary) -> void:
	var erro: String = get_node("/root/SaveManager").usar_cenario(String(c["id"]))
	if erro != "":
		avisar("Não deu: %s." % erro, false)
		return
	avisar("Cenário: %s. Seu jogo ficou salvo." % c["nome"])
	ir_para.emit(GARAGEM)


static func _nome_cenario(id: String) -> String:
	for c in Cenarios.LISTA:
		if c["id"] == id:
			return String(c["nome"])
	return id


## Playtest (docs/playtest_percurso.md): modo e resumo do registro local. Fica
## na tela de Configurações (engrenagem do cabeçalho).
func _modo_teste(v: VBoxContainer) -> void:
	separador(v)
	rotulo("Modo de playtest", FONTE_PEQUENA + 2, Color.WHITE, v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for m in [["", "Desligado"], ["clareza", "Clareza"], ["ritmo", "Ritmo"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_pressed = Preferencias.modo_teste == m[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func():
			if Preferencias.modo_teste != "":
				RegistroSessao.fim(jogador)
			Preferencias.modo_teste = m[0]
			Preferencias.salvar()
			RegistroSessao.inicio(jogador)
			mudou.emit())
		h.add_child(b)
	v.add_child(h)
	nota("", "Só para testes", "Clareza: pode pular a corrida. Ritmo: sem pular, para medir sessão e renda. "
			+ "Ligado, o aparelho registra as sessões (só local).", v)
	if Preferencias.modo_teste != "":
		_cenarios(v)
	var sessoes := RegistroSessao.sessoes()
	if sessoes.is_empty():
		return
	for i in sessoes.size():
		var s: Dictionary = sessoes[i]
		var dur: float = float(s["fim"]) - float(s["inicio"])
		var corrida: float = float(s["telas"].get("Corrida", 0.0))
		var minutos_fila := 0.0
		for f in s["filas"]:
			minutos_fila += float(f["duracao_s"]) * int(f["repeticoes"]) / 60.0
		var aus: float = float(s["ausencia_antes_s"])
		rotulo("Sessão %d (%s): %.0f min · assistindo %.0f min · %d fila%s (%.0f min) · %d pulo%s · %s→%s · %s→%s G%s" % [
				i + 1, s["modo"], dur / 60.0, corrida / 60.0, s["filas"].size(), "" if s["filas"].size() == 1 else "s",
				minutos_fila, s["pulos"], "" if s["pulos"] == 1 else "s", s["fase_inicio"], s["fase_fim"],
				dinheiro(int(s["saldo_inicio"])), dinheiro(int(s["saldo_fim"])),
				" · ausente %.0f min antes" % (aus / 60.0) if aus >= 0.0 else ""], FONTE_PEQUENA, COR_SECUNDARIA, v)
		var fc: Array = s.get("fps_corrida", [])
		if not fc.is_empty():
			var o := fc.duplicate()
			o.sort()
			rotulo("    corrida: %d fps (mediana) · %d fps (pior 5%%)" % [o[o.size() / 2], o[int(o.size() * 0.05)]],
					FONTE_PEQUENA, COR_SECUNDARIA, v)
	_renda(v, sessoes)
	rotulo("Arquivo: %s" % ProjectSettings.globalize_path(RegistroSessao.CAMINHO), FONTE_PEQUENA - 2, COR_NEUTRA, v)
	botao_texto("Apagar registro", func():
		RegistroSessao.limpar()
		RegistroSessao.inicio(jogador)
		mudou.emit(), v)


func _recomecar() -> void:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	if not dados.historia().is_empty():
		Prologo.iniciar(dados, jogador)  # recomeça pelo prólogo (decisão 32)
	avisar("Carreira recomeçada com %s G." % dinheiro(jogador.economia.saldo))
	ir_para.emit(GARAGEM)
	historia("GAME_START")


func _mostrar_resultado() -> void:
	if _resultado.is_empty():
		return
	if _resultado.has("erro"):
		rotulo(_resultado["erro"], 0, COR_RUIM, cartao(COR_RUIM))
		_resultado = {}
		return
	var grau: String = _resultado["grau"]
	var v := cartao(CORES_GRAU.get(grau, COR_RUIM))
	rotulo("TESTE %s" % String(_resultado["teste"]).to_upper(), FONTE_PEQUENA, COR_SECUNDARIA, v)
	rotulo("%.2f s · %s" % [_resultado["tempo"], grau.to_upper() if grau != "" else "REPROVADO"], 36,
			CORES_GRAU.get(grau, COR_RUIM), v)
	var tempos: Dictionary = _resultado["tempos"]
	var proximo := ""
	for g in ["bronze", "prata", "ouro"]:
		if _resultado["tempo"] > float(tempos[g]):
			proximo = g
			break
	if proximo != "":
		rotulo("Faltaram %.2f s para o %s." % [_resultado["tempo"] - float(tempos[proximo]), proximo],
				FONTE_PEQUENA + 2, Color.WHITE, v)
	if _resultado["concedida"]:
		nota("icone_licenca", "Licença %s conquistada!" % _resultado["licenca"], "Novas corridas liberadas em Correr.",
				v, COR_BOM)
		botao("Ver corridas", func(): ir_para.emit(EVENTOS), true, true, v)
	_resultado = {}


const TEXTO_ESTADO := {
	Licencas.LOCKED: "BLOQUEADA", Licencas.AVAILABLE: "PRONTA PARA TREINAR", Licencas.TRAINING: "EM TREINO",
	Licencas.READY: "AVALIAÇÃO ABERTA", Licencas.COMPLETE: "CONQUISTADA",
}


## Cartão da próxima licença (decisão 33), no formato do cartão de corrida:
## o brasão à esquerda; à direita o nome, o que libera, os requisitos e o
## treino; embaixo, a ação (iniciar o treino) ou o andamento. A avaliação
## entra em seguida, no mesmo cartão. Retorna a coluna do cartão.
func _cartao_proxima(l: Licencas, lic: Dictionary, st: String, agora: float) -> VBoxContainer:
	var v := cartao_com_fundo(arte("fundo_carreira"), st != Licencas.LOCKED)
	ancora("LICENSE_REQUIREMENTS", v)
	ancora("LIC_" + String(lic["id"]), v)
	if st == Licencas.AVAILABLE:
		historia("LICENCA_DISPONIVEL:" + String(lic["id"]))
	elif st == Licencas.READY:
		historia("LICENCA_PRONTA")
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 14)
	v.add_child(corpo)
	var esq := VBoxContainer.new()
	esq.custom_minimum_size = Vector2(170, 0)
	esq.alignment = BoxContainer.ALIGNMENT_CENTER
	corpo.add_child(esq)
	var tex := selo_licenca(String(lic["id"]))
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(170, BRASAO_CARTAO)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if st == Licencas.LOCKED:
			t.modulate = Color(0.45, 0.45, 0.48)
		esq.add_child(t)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	corpo.add_child(col)
	var sobre := rotulo("PRÓXIMA LICENÇA · " + TEXTO_ESTADO[st], 0, COR_SECUNDARIA, col)
	Tipografia.rotulo(sobre, "medium", 18)
	sobre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var titulo := Label.new()
	titulo.text = String(lic["nome"]).to_upper()
	Tipografia.rotulo(titulo, "semibold", 40)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	col.add_child(titulo)
	var provas: int = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"]).size()
	var dur := l.treino_s(lic["id"])
	rotulo("Libera %d corrida%s · treino de %s" % [provas, "" if provas == 1 else "s", _duracao(dur)], FONTE_PEQUENA,
			Color(0.86, 0.87, 0.9), col).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for r in l.requisitos(lic["id"]):
		var lr := rotulo("%s %s" % ["✓" if r["ok"] else "✗", r["texto"]], FONTE_PEQUENA - 2, COR_BOM if r["ok"] else COR_RUIM, col)
		lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match st:
		Licencas.AVAILABLE:
			rotulo("Grátis · continua com o app fechado", FONTE_PEQUENA - 2, COR_SECUNDARIA, col)
			var b := Button.new()
			Tipografia.acao_primaria(b, "Iniciar treino   →", COR_DESTAQUE, Color(0.1, 0.1, 0.1), 34, 72)
			b.pressed.connect(func():
				var erro := l.iniciar_treino(lic["id"], Time.get_unix_time_from_system())
				if erro != "":
					avisar(erro, false)
				else:
					historia("LICENCA_TREINO_INICIO")
				mudou.emit())
			v.add_child(b)
		Licencas.TRAINING:
			var falta := l.restante(lic["id"], agora)
			var barra := BarraDentes.new(roundi(10.0 * (1.0 - falta / maxf(dur, 1.0))), 10, 10.0)
			col.add_child(barra)
			rotulo("Treino: faltam %s" % _duracao(falta), FONTE_PEQUENA, COR_INFO, col)
		Licencas.READY:
			rotulo("Treino concluído: faça a avaliação abaixo.", FONTE_PEQUENA, COR_BOM, col)
	return v


static func _duracao(s: float) -> String:
	var t := ceili(s)
	if t >= 3600:
		return "%d h %02d min" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%d min %02d s" % [t / 60, t % 60]
	return "%d s" % t


## `v`: o cartão da situação, onde os testes entram (sem cabeçalho próprio).
func _cartao_licenca(c: Carro, lic: Dictionary, v: VBoxContainer) -> void:
	var tem: bool = lic["id"] in jogador.licencas
	var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
	var feitos: int = lic["testes"].filter(func(t): return jogador.graus_licenca.has(t["id"])).size()
	separador(v)
	var ht := HBoxContainer.new()
	v.add_child(ht)
	var lt := rotulo("Testes" if tem else "Testes: %d de %d" % [feitos, lic["testes"].size()], FONTE_PEQUENA + 2,
			COR_SECUNDARIA, ht)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao_info(lic["nome"], "Uma volta sozinho na pista com o %s. Bronze ou melhor em todos os testes dá a licença."
			% c.base["nome"], ht)
	var series := {}
	for e in dados.lista("eventos"):
		if e["restricoes"].get("licenca") == lic["id"]:
			series[String(e["nome"]).split(" — ")[0]] = true
	if not series.is_empty():
		if _expandida.get(lic["id"], false):
			rotulo("Libera: " + ", ".join(series.keys()), FONTE_PEQUENA, COR_SECUNDARIA, v)
			botao_texto("Mostrar menos", func(): _expandida[lic["id"]] = false, v)
		else:
			botao_texto("Libera %d série%s · ver quais" % [series.size(), "" if series.size() == 1 else "s"],
					func(): _expandida[lic["id"]] = true, v)
	for t in lic["testes"]:
		separador(v)
		var topo := fileira(v)
		var ic := icone_pista(t["pista"])
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		topo.add_child(ic)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topo.add_child(info)
		var grau: String = jogador.graus_licenca.get(t["id"], "")
		rotulo("Teste %s · %s" % [String(t["id"]).to_upper(), nome_pista(t["pista"])], 0, Color.WHITE, info)
		var metas := []
		for g in ["ouro", "prata", "bronze"]:
			metas.append(["%s %.1f s" % [g, t["tempos"][g]], CORES_GRAU[g]])
		selos(metas, info)
		var regras := []
		if t.get("restricoes", {}).has("potencia_max"):
			regras.append("até %d cv" % t["restricoes"]["potencia_max"])
		if t.get("condicao", "seco") == "chuva":
			regras.append("chuva")
		var motivos := Elegibilidade.motivos(c, t.get("restricoes", {}), jogador.licencas)
		var h := fileira(v)
		var status := "Seu melhor: %s" % (grau.to_upper() if grau != "" else "—")
		if not regras.is_empty():
			status += " · regras: " + ", ".join(regras)
		if not motivos.is_empty():
			status += "\n✗ " + "; ".join(motivos)
		var l := rotulo(status, FONTE_PEQUENA, CORES_GRAU.get(grau, COR_RUIM if not motivos.is_empty() else COR_SECUNDARIA), h)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao("Fazer" if grau == "" else "Tentar de novo", _fazer.bind(lic, t),
				not bloqueada and motivos.is_empty(), grau == "", h)


func _fazer(lic: Dictionary, t: Dictionary) -> void:
	var r := Licencas.new(dados, jogador).fazer_teste(lic["id"], t["id"], jogador.carro_ativo, randi())
	if r.has("erro"):
		_resultado = {"erro": r["erro"]}
		return
	set_deferred("scroll_vertical", 0)  # o resultado aparece no topo
	_resultado = {"teste": t["id"], "tempo": r["tempo"], "grau": r["grau"], "tempos": t["tempos"],
			"concedida": r["licenca_concedida"], "licenca": lic["nome"]}
	avisar("Teste %s: %.2f s · %s" % [String(t["id"]).to_upper(), r["tempo"],
			String(r["grau"]).to_upper() if r["grau"] != "" else "reprovado"], r["grau"] != "")
	if r["licenca_concedida"]:
		historia("LICENCA_CONCEDIDA:" + String(lic["id"]))
		var liberadas: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"])
		painel.emit("%s conquistada!" % lic["nome"], func(v):
			rotulo("Agora você pode correr %d corridas novas:" % liberadas.size(), 0, Color.WHITE, v)
			var series := {}
			for e in liberadas:
				series[String(e["nome"]).split(" — ")[0]] = true
			for nome in series:
				rotulo("• " + nome, FONTE_PEQUENA + 2, COR_DESTAQUE, v)
			nota("icone_pista", "Em Correr › %s" % lic["nome"], "", v),
			[["Ver corridas", func(): ir_para.emit(EVENTOS)], ["Fechar", func(): pass]])



# --- Contratos (decisão 4) --------------------------------------------------

## Licença por contratos: cada contrato numa linha, com o melhor grau e a
## entrada da bancada.
## `v`: o cartão da situação, onde as missões entram (sem cabeçalho próprio).
func _cartao_contratos(lic: Dictionary, v: VBoxContainer) -> void:
	var tem: bool = lic["id"] in jogador.licencas
	var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
	var lista := Contratos.da_licenca(dados, lic["id"])
	var feitos: int = lista.filter(func(ct): return jogador.graus_licenca.has(ct["id"])).size()
	separador(v)
	var ht := HBoxContainer.new()
	v.add_child(ht)
	var lt := rotulo("Missões" if tem else "Missões: %d de %d" % [feitos, lista.size()], FONTE_PEQUENA + 2,
			COR_SECUNDARIA, ht)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao_info(lic["nome"], "A escola empresta o carro e as peças, sem custo. Monte o carro e teste a montagem; "
			+ "bronze em todas as missões dá a licença.", ht)
	nota("icone_licenca", "Carro e peças da escola, grátis", "", v)
	for ct in lista:
		separador(v)
		var h := fileira(v)
		var img := icone_carro(dados.carro(ct["carro"]))
		img.custom_minimum_size = Vector2(120, 68)
		h.add_child(img)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var grau: String = jogador.graus_licenca.get(ct["id"], "")
		rotulo(ct["nome"], 0, Color.WHITE, info)
		rotulo("Seu melhor: %s" % (grau.to_upper() if grau != "" else "—"), FONTE_PEQUENA,
				CORES_GRAU.get(grau, COR_SECUNDARIA), info)
		var b := botao("Montar" if grau == "" else "Rever", _abrir_bancada.bind(ct), not bloqueada, grau == "", h)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _abrir_bancada(ct: Dictionary) -> void:
	_bancada = ct["id"]
	var m: Dictionary = jogador.montagens.get(ct["id"], {})
	_montagem = {"pecas": Array(m.get("pecas", [])).duplicate(), "ajuste_cambio": String(m.get("ajuste_cambio", ""))}
	_avaliacao = {}
	set_deferred("scroll_vertical", 0)
	mudou.emit()


## Bancada: o pedido, as medalhas, o carro da escola com a montagem, as peças
## da escola por categoria e o relatório da última avaliação.
func _tela_bancada(ct: Dictionary) -> void:
	botao_texto("‹ Missões", func():
		_bancada = ""
		mudou.emit())
	rotulo(ct["nome"], FONTE_TITULO)
	rotulo(ct.get("descricao", ""), FONTE_PEQUENA + 2, COR_SECUNDARIA)
	var grau: String = jogador.graus_licenca.get(ct["id"], "")
	var vm := cartao()
	titulo_secao("MEDALHAS", "Prata e ouro exigem também a condição do bronze.", vm)
	var cond: Dictionary = ct["condicoes"]
	for g in ["bronze", "prata", "ouro"]:
		var partes := []
		for chave in cond.get(g, {}):
			partes.append(Contratos.texto_condicao(chave, cond[g][chave]))
		var ganho: bool = grau != "" and Contratos.GRAUS.find(grau) <= Contratos.GRAUS.find(g)
		nota("icone_medalha_" + g, "%s%s" % ["✓ " if ganho else "", "; ".join(partes)], "", vm, CORES_GRAU[g])
	for prova in ct["provas"]:
		var h := fileira()
		var ic := icone_pista(prova["pista"])
		ic.custom_minimum_size = Vector2(110, 80)
		h.add_child(ic)
		var nomes: Array = prova["rivais"].map(func(r):
			var b: Dictionary = dados.carro(r["carro"])
			return "%s (%d cv, %d kg)" % [b["nome"], b["potencia"], b["peso"]])
		var l := rotulo("%s · %d volta%s\nRival: %s" % [nome_pista(prova["pista"]), prova["voltas"],
				"" if int(prova["voltas"]) == 1 else "s", ", ".join(nomes)], FONTE_PEQUENA + 1, Color.WHITE, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var carro := Contratos.carro_montado(dados, ct, _montagem)
	var foto := icone_carro(carro.base, true)
	foto.custom_minimum_size = Vector2(0, 170)
	conteudo.add_child(foto)
	rotulo("%s da escola" % carro.base["nome"], 30, Color.WHITE)
	var a := carro.atributos_efetivos("seco")
	atributos_carro(a)
	var custo := 0
	for pid in carro.configuracao()["pecas"]:
		custo += int(dados.peca(pid)["preco"])
	nota("icone_montagem", "%d peça%s · a escola paga" % [carro.pecas.size(), "" if carro.pecas.size() == 1 else "s"],
			"Preço de tabela da montagem: %s G. A escola empresta o carro e as peças." % dinheiro(custo))
	_pecas_da_escola(ct, carro)
	botao("Testar montagem", _enviar.bind(ct), true, true)
	if not _avaliacao.is_empty():
		_relatorio(ct, _avaliacao)


func _pecas_da_escola(ct: Dictionary, carro: Carro) -> void:
	var por_cat := {}
	for p in Contratos.pecas_escola(dados, ct):
		por_cat.get_or_add(p["categoria"], []).append(p)
	var v := cartao()
	titulo_secao("PEÇAS DA ESCOLA", "Escolha no máximo uma peça por categoria.", v)
	for cat in por_cat:
		por_cat[cat].sort_custom(func(x, y): return x["preco"] < y["preco"])
		rotulo(NOMES_CATEGORIA.get(cat, cat.capitalize()), FONTE_PEQUENA + 2, Color.WHITE, v)
		var f := HFlowContainer.new()
		f.add_theme_constant_override("h_separation", 8)
		f.add_theme_constant_override("v_separation", 8)
		v.add_child(f)
		var atual: String = carro.pecas.get(cat, {}).get("id", "")
		var opcoes: Array = [{}] + por_cat[cat]
		for p in opcoes:
			var b := Button.new()
			b.text = "Nenhuma" if p.is_empty() else "%s · %s G" % [p["nome"], dinheiro(int(p["preco"]))]
			b.toggle_mode = true
			b.button_pressed = (p.is_empty() and atual == "") or (not p.is_empty() and p["id"] == atual)
			b.custom_minimum_size = Vector2(0, 58)
			b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
			b.pressed.connect(func():
				var ids: Array = _montagem["pecas"].filter(func(x): return dados.peca(x)["categoria"] != cat)
				if not p.is_empty():
					ids.append(p["id"])
				_montagem["pecas"] = ids
				if cat == "cambio" and p.is_empty():
					_montagem["ajuste_cambio"] = ""
				mudou.emit())
			f.add_child(b)
		if cat == "cambio" and atual != "":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			for aj in [["curto", "Arrancada"], ["", "Equilibrado"], ["longo", "Velocidade final"]]:
				var b := Button.new()
				b.text = aj[1]
				b.toggle_mode = true
				b.button_pressed = _montagem.get("ajuste_cambio", "") == aj[0]
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.custom_minimum_size = Vector2(0, 58)
				b.pressed.connect(func():
					_montagem["ajuste_cambio"] = aj[0]
					mudou.emit())
				h.add_child(b)
			v.add_child(h)


func _enviar(ct: Dictionary) -> void:
	var r := Contratos.new(dados, jogador).enviar(ct["id"], _montagem, Time.get_unix_time_from_system())
	if r.has("erro"):
		avisar(r["erro"], false)
		return
	_avaliacao = r
	avisar("%s: %s" % [ct["nome"], String(r["grau"]).to_upper() if r["grau"] != "" else "não cumpriu"], r["grau"] != "")
	if r["licenca_concedida"]:
		historia("LICENCA_CONCEDIDA:" + String(ct["licenca"]))
		var lic: Dictionary = dados.item("licencas", ct["licenca"])
		var liberadas: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"])
		painel.emit("%s conquistada!" % lic["nome"], func(v):
			rotulo("Todas as missões cumpridas. Agora você pode correr %d corridas novas:" % liberadas.size(), 0, Color.WHITE, v)
			var series := {}
			for e in liberadas:
				series[String(e["nome"]).split(" — ")[0]] = true
			for nome in series:
				rotulo("• " + nome, FONTE_PEQUENA + 2, COR_DESTAQUE, v)
			rotulo("Elas aparecem em Correr, no grupo %s." % lic["nome"], FONTE_PEQUENA, COR_SECUNDARIA, v),
			[["Ver corridas", func(): ir_para.emit(EVENTOS)], ["Fechar", func(): pass]])


## Relatório: grau, tempo contra cada rival, onde o tempo foi perdido (curvas
## ou retas) e o que falta para o próximo grau.
func _relatorio(ct: Dictionary, r: Dictionary) -> void:
	var grau: String = r["grau"]
	var v := cartao(CORES_GRAU.get(grau, COR_RUIM))
	rotulo("RESULTADO DO TESTE", FONTE_PEQUENA, COR_SECUNDARIA, v)
	rotulo(grau.to_upper() if grau != "" else "NÃO CUMPRIU", 38, CORES_GRAU.get(grau, COR_RUIM), v)
	for p in r["provas"]:
		separador(v)
		var melhor: Dictionary = p["rivais"][0]
		for rv in p["rivais"]:
			if rv["tempo"] < melhor["tempo"]:
				melhor = rv
		rotulo("%s: você %.2f s · %s %.2f s" % [nome_pista(p["pista"]), p["tempo"], nome_curto(melhor["nome"]), melhor["tempo"]],
				FONTE_PEQUENA + 2, Color.WHITE, v)
		var folga: float = p["folga"]
		rotulo("%s %.2f s" % ["À frente por" if folga > 0.0 else "Atrás por", absf(folga)], FONTE_PEQUENA + 2,
				COR_BOM if folga > 0.0 else COR_RUIM, v)
		if p.has("diagnostico"):
			var dg: Dictionary = p["diagnostico"]
			rotulo("Contra o %s: curvas %s · retas %s" % [nome_curto(melhor["nome"]), _dif(dg["curvas"]), _dif(dg["retas"])],
					FONTE_PEQUENA + 1, COR_SECUNDARIA, v)
			if folga <= 0.0:
				rotulo(_gargalo(dg), FONTE_PEQUENA + 1, COR_INFO, v)
	var proximo := ""
	for g in ["bronze", "prata", "ouro"]:
		if grau == "" or Contratos.GRAUS.find(g) < Contratos.GRAUS.find(grau):
			proximo = g
			break
	if proximo != "" and not r["graus"][proximo].is_empty():
		rotulo("Para o %s falta: %s." % [proximo, "; ".join(r["graus"][proximo])], FONTE_PEQUENA + 2, Color.WHITE, v)


## "+0,8 s" (mais lento) ou "−0,3 s" (mais rápido) que o rival.
static func _dif(x: float) -> String:
	return "%s%.1f s" % ["+" if x >= 0.0 else "−", absf(x)]


## O gargalo pelo lado em que mais se perdeu tempo.
static func _gargalo(dg: Dictionary) -> String:
	if dg["curvas"] >= dg["retas"]:
		return "Perde nas curvas: peso, freios e pneus ajudam."
	return "Perde nas retas: potência, câmbio e peso ajudam."
