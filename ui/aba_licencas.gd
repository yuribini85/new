extends Aba

## Resultado do último teste: {"teste", "tempo", "grau", "tempos", "concedida", "licenca"} ou erro.
var _resultado := {}

const CORES_GRAU := {
	"ouro": Color(0.98, 0.8, 0.2), "prata": Color(0.8, 0.83, 0.88), "bronze": Color(0.85, 0.55, 0.3),
}


## Licenças com a lista de séries liberadas aberta.
var _expandida := {}
## Primeiro toque em "Recomeçar carreira" só pede confirmação.
var _confirmar_recomeco := false
## Bancada de contrato aberta ("" = lista), a montagem em edição e o último
## relatório dela.
var _bancada := ""
var _montagem := {}
var _avaliacao := {}

const NOMES_CATEGORIA := preload("res://ui/aba_oficina.gd").NOMES_CATEGORIA


func _init(d: Node, j: Node) -> void:
	super(d, j, "Carreira")


## Carreira: objetivos, licenças, coleção e preferências num lugar só.
func construir() -> void:
	if _bancada != "" and dados.existe("contratos", _bancada):
		_tela_bancada(dados.item("contratos", _bancada))
		return
	_bancada = ""
	_resumo()
	_objetivos()
	rotulo("LICENÇAS", FONTE_PEQUENA, COR_SECUNDARIA)
	var c := carro_ativo()
	_mostrar_resultado()
	for lic in dados.lista("licencas"):
		if not Contratos.da_licenca(dados, lic["id"]).is_empty():
			_cartao_contratos(lic)
		elif c == null:
			rotulo("Os testes da %s são feitos com o carro em uso. Compre um carro primeiro." % lic["nome"],
					FONTE_PEQUENA + 2, COR_SECUNDARIA)
		else:
			rotulo("%s: uma volta sozinho na pista com o %s. Bronze ou melhor em todos os testes dá a licença." % [
					lic["nome"], c.base["nome"]], FONTE_PEQUENA, COR_SECUNDARIA)
			_cartao_licenca(c, lic)
	_colecao()
	var h := acoes()
	entenda(h)
	_preferencias()
	if _confirmar_recomeco:
		var v := cartao(COR_RUIM)
		rotulo("Apagar todo o progresso e voltar ao saldo inicial?", 0, Color.WHITE, v)
		var hb := acoes(v)
		botao("Sim, recomeçar", _recomecar, true, false, hb)
		botao("Cancelar", func(): _confirmar_recomeco = false, true, false, hb)
	else:
		botao_texto("Recomeçar carreira", func(): _confirmar_recomeco = true)
	rotulo("Versão %s" % versao(), FONTE_PEQUENA, COR_NEUTRA)


func _resumo() -> void:
	var vitorias := 0
	for ev in jogador.vitorias:
		vitorias += int(jogador.vitorias[ev])
	numeros([["%d" % jogador.garagem.lista().size(), "carros"], ["%d" % vitorias, "vitórias"],
			[", ".join(jogador.licencas) if not jogador.licencas.is_empty() else "—", "licenças"],
			["%d" % jogador.dias, "dias"]])


func _objetivos() -> void:
	var lista := Objetivos.lista(jogador, dados)
	var atual := Objetivos.atual(lista)
	var v := cartao()
	rotulo("OBJETIVOS", FONTE_PEQUENA, COR_SECUNDARIA, v)
	for i in lista.size():
		var o: Dictionary = lista[i]
		var h := fileira(v)
		var l := rotulo(("✓ " if o["feito"] else ("→ " if i == atual else "· ")) + o["texto"], FONTE_PEQUENA + 3,
				COR_BOM if o["feito"] else (Color.WHITE if i == atual else COR_SECUNDARIA), h)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if i == atual:
			var b := botao("Ir", func(): ir_para.emit(o["aba"]), true, true, h)
			b.custom_minimum_size = Vector2(110, 60)


## Coleção em fotos: os que você tem e os que ainda faltam (escurecidos);
## tocar abre a ficha.
func _colecao() -> void:
	var tenho := {}
	for c in jogador.garagem.lista():
		tenho[c.id] = true
	rotulo("COLEÇÃO · %d de %d modelos obtidos" % [tenho.size(), dados.lista("carros").size()], FONTE_PEQUENA, COR_SECUNDARIA)
	rotulo("Todos os carros do jogo. Os escuros você ainda não tem; toque para ver como conseguir.",
			FONTE_PEQUENA, COR_SECUNDARIA)
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	for c in dados.lista("carros"):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.set_corner_radius_all(10)
		for estado in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var img := icone_carro(c)
		img.custom_minimum_size = Vector2(0, 100)
		if not tenho.has(c["id"]):
			img.modulate = Color(0.25, 0.25, 0.3)
		v.add_child(img)
		var l := Label.new()
		l.text = ("✓ " if tenho.has(c["id"]) else "") + nome_curto(c["nome"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", Color.WHITE if tenho.has(c["id"]) else COR_SECUNDARIA)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
		b.pressed.connect(func(): ficha_modelo(c))
		grade.add_child(b)
	conteudo.add_child(grade)


func _preferencias() -> void:
	var v := cartao()
	rotulo("PREFERÊNCIAS", FONTE_PEQUENA, COR_SECUNDARIA, v)
	var h := fileira(v)
	var lv := rotulo("Volume", FONTE_PEQUENA + 2, Color.WHITE, h)
	lv.size_flags_horizontal = Control.SIZE_FILL
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF  # com quebra, saía uma letra por linha
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


func _recomecar() -> void:
	_confirmar_recomeco = false
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	avisar("Carreira recomeçada com %s Cr." % dinheiro(jogador.economia.saldo))
	ir_para.emit(GARAGEM)


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
		rotulo("Licença %s conquistada! Novas provas liberadas em Eventos." % _resultado["licenca"], 0, COR_BOM, v)
		botao("Ver eventos", func(): ir_para.emit(EVENTOS), true, true, v)
	_resultado = {}


func _cartao_licenca(c: Carro, lic: Dictionary) -> void:
	var tem: bool = lic["id"] in jogador.licencas
	var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
	var feitos: int = lic["testes"].filter(func(t): return jogador.graus_licenca.has(t["id"])).size()
	var provas: int = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"]).size()
	var v := cartao(COR_BOM if tem else (COR_NEUTRA if bloqueada else COR_INFO))
	rotulo(lic["nome"], 34, Color.WHITE, v)
	var estado := ["CONQUISTADA", COR_BOM] if tem else (["exige a licença %s" % lic["requisito"], COR_RUIM] if bloqueada
			else ["%d de %d testes" % [feitos, lic["testes"].size()], COR_INFO])
	selos([estado, ["libera %d prova%s" % [provas, "" if provas == 1 else "s"], COR_NEUTRA.lightened(0.3)]], v)
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
		var liberadas: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"])
		painel.emit("%s conquistada!" % lic["nome"], func(v):
			rotulo("Agora você pode correr %d provas novas:" % liberadas.size(), 0, Color.WHITE, v)
			var series := {}
			for e in liberadas:
				series[String(e["nome"]).split(" — ")[0]] = true
			for nome in series:
				rotulo("• " + nome, FONTE_PEQUENA + 2, COR_DESTAQUE, v)
			rotulo("Elas aparecem em Eventos, no grupo %s." % lic["nome"], FONTE_PEQUENA, COR_SECUNDARIA, v),
			[["Ver eventos", func(): ir_para.emit(EVENTOS)], ["Fechar", func(): pass]])



# --- Contratos (decisão 4) --------------------------------------------------

## Licença por contratos: cada contrato numa linha, com o melhor grau e a
## entrada da bancada.
func _cartao_contratos(lic: Dictionary) -> void:
	var tem: bool = lic["id"] in jogador.licencas
	var bloqueada: bool = lic.get("requisito") != null and not lic["requisito"] in jogador.licencas
	var lista := Contratos.da_licenca(dados, lic["id"])
	var feitos: int = lista.filter(func(ct): return jogador.graus_licenca.has(ct["id"])).size()
	var provas: int = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"]).size()
	var v := cartao(COR_BOM if tem else (COR_NEUTRA if bloqueada else COR_INFO))
	rotulo(lic["nome"], 34, Color.WHITE, v)
	var estado := ["CONQUISTADA", COR_BOM] if tem else (["exige a licença %s" % lic["requisito"], COR_RUIM] if bloqueada
			else ["%d de %d contratos" % [feitos, lista.size()], COR_INFO])
	selos([estado, ["libera %d prova%s" % [provas, "" if provas == 1 else "s"], COR_NEUTRA.lightened(0.3)]], v)
	rotulo("A escola empresta o carro e as peças, sem custo. Monte a solução e envie para avaliação; bronze em todos os contratos dá a licença.",
			FONTE_PEQUENA, COR_SECUNDARIA, v)
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
	botao_texto("‹ Contratos", func():
		_bancada = ""
		mudou.emit())
	rotulo(ct["nome"], FONTE_TITULO)
	rotulo(ct.get("descricao", ""), FONTE_PEQUENA + 2, COR_SECUNDARIA)
	var grau: String = jogador.graus_licenca.get(ct["id"], "")
	var vm := cartao()
	rotulo("MEDALHAS", FONTE_PEQUENA, COR_SECUNDARIA, vm)
	var cond: Dictionary = ct["condicoes"]
	for g in ["bronze", "prata", "ouro"]:
		var partes := []
		for chave in cond.get(g, {}):
			partes.append(Contratos.texto_condicao(chave, cond[g][chave]))
		var ganho: bool = grau != "" and Contratos.GRAUS.find(grau) <= Contratos.GRAUS.find(g)
		rotulo("%s%s: %s%s" % ["✓ " if ganho else "", g.to_upper(), "cumprir o bronze e " if g != "bronze" else "",
				"; ".join(partes)], FONTE_PEQUENA + 1, CORES_GRAU[g], vm)
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
	numeros([["%d" % a["potencia"], "cv"], ["%d" % a["peso"], "kg"], ["%.2f" % a["aderencia"], "aderência"],
			["%.2f" % a["freio"], "freio"]])
	var custo := 0
	for pid in carro.configuracao()["pecas"]:
		custo += int(dados.peca(pid)["preco"])
	rotulo("%d peça%s · preço de tabela %s Cr (a escola paga)" % [carro.pecas.size(), "" if carro.pecas.size() == 1 else "s",
			dinheiro(custo)], FONTE_PEQUENA + 1, COR_SECUNDARIA)
	_pecas_da_escola(ct, carro)
	botao("Enviar para avaliação", _enviar.bind(ct), true, true)
	if not _avaliacao.is_empty():
		_relatorio(ct, _avaliacao)


func _pecas_da_escola(ct: Dictionary, carro: Carro) -> void:
	var por_cat := {}
	for p in Contratos.pecas_escola(dados, ct):
		por_cat.get_or_add(p["categoria"], []).append(p)
	var v := cartao()
	rotulo("PEÇAS DA ESCOLA · uma por categoria", FONTE_PEQUENA, COR_SECUNDARIA, v)
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
			b.text = "Nenhuma" if p.is_empty() else "%s · %s Cr" % [p["nome"], dinheiro(int(p["preco"]))]
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
			for aj in [["curto", "Curto"], ["", "Equilibrado"], ["longo", "Longo"]]:
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
	var r := Contratos.new(dados, jogador).enviar(ct["id"], _montagem)
	if r.has("erro"):
		avisar(r["erro"], false)
		return
	_avaliacao = r
	avisar("%s: %s" % [ct["nome"], String(r["grau"]).to_upper() if r["grau"] != "" else "não cumpriu"], r["grau"] != "")
	if r["licenca_concedida"]:
		var lic: Dictionary = dados.item("licencas", ct["licenca"])
		var liberadas: Array = dados.lista("eventos").filter(func(e): return e["restricoes"].get("licenca") == lic["id"])
		painel.emit("%s conquistada!" % lic["nome"], func(v):
			rotulo("Todos os contratos cumpridos. Agora você pode correr %d provas novas:" % liberadas.size(), 0, Color.WHITE, v)
			var series := {}
			for e in liberadas:
				series[String(e["nome"]).split(" — ")[0]] = true
			for nome in series:
				rotulo("• " + nome, FONTE_PEQUENA + 2, COR_DESTAQUE, v)
			rotulo("Elas aparecem em Competições, no grupo %s." % lic["nome"], FONTE_PEQUENA, COR_SECUNDARIA, v),
			[["Ver competições", func(): ir_para.emit(EVENTOS)], ["Fechar", func(): pass]])


## Relatório: grau, tempo contra cada rival, onde o tempo foi perdido (curvas
## ou retas) e o que falta para o próximo grau.
func _relatorio(ct: Dictionary, r: Dictionary) -> void:
	var grau: String = r["grau"]
	var v := cartao(CORES_GRAU.get(grau, COR_RUIM))
	rotulo("RELATÓRIO DA AVALIAÇÃO", FONTE_PEQUENA, COR_SECUNDARIA, v)
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
		return "Gargalo nas curvas: menos peso, freios e aderência ajudam mais que potência."
	return "Gargalo nas retas: potência, câmbio e menos peso ajudam."
