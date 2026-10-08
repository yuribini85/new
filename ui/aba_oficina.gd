extends Aba

## Em que parte da corrida cada atributo pesa.
const AFETA := {
	"potencia": "aceleração e velocidade nas retas",
	"peso": "aceleração, curvas e frenagem",
	"freio": "frenagem antes das curvas",
}
const AFETA_CATEGORIA := {"lightweight": "peso", "brake": "freio", "cambio": "cambio", "corrida": "peso"}

## O que cada grupo de peças faz, numa linha curta com o ícone do atributo;
## EXPLICA_CATEGORIA é o detalhe, atrás do ⓘ.
const CURTA_CATEGORIA := {
	"aspiracao": "Turbo ou aspirado", "lightweight": "Mais leve: tudo melhora", "brake": "Freia mais tarde",
	"muffler": "Escapamento esportivo", "portpolish": "Fluxo melhor no motor", "enginebalance": "Motor balanceado",
	"displacement": "Motor maior", "computer": "Central eletrônica", "intercooler": "Ar do turbo mais frio",
	"cambio": "Arrancada ou velocidade final",
	"corrida": "Copas Corrida; sai das de rua",
}
const ICONE_ATRIBUTO := {"potencia": "icone_potencia", "peso": "icone_peso", "freio": "icone_freios",
	"cambio": "icone_cambio"}
const EXPLICA_CATEGORIA := {
	"aspiracao": "Mais potência pela admissão (turbo ou preparação aspirada).",
	"lightweight": "Tira peso: o carro acelera, freia e contorna melhor.",
	"brake": "Freia mais forte e mais tarde antes das curvas.",
	"muffler": "Escapamento esportivo: um pouco mais de potência.",
	"portpolish": "Melhora o fluxo no motor: mais potência.",
	"enginebalance": "Motor balanceado: mais potência.",
	"displacement": "Motor maior: mais potência.",
	"computer": "Nova central eletrônica: mais potência.",
	"intercooler": "Resfria o ar do turbo: mais potência.",
	"cambio": "Permite escolher entre arrancada e velocidade final.",
	"corrida": "Carroceria de corrida: mais leve e aceita nas copas de marca \"Corrida\". O carro deixa de entrar nas copas só de carro de rua.",
}
const NOMES_CATEGORIA := {
	"aspiracao": "Aspiração", "lightweight": "Peso", "brake": "Freios", "muffler": "Escapamento",
	"portpolish": "Polimento de dutos", "enginebalance": "Balanceamento", "displacement": "Cilindrada",
	"computer": "Computador", "intercooler": "Intercooler", "cambio": "Câmbio", "corrida": "Kit de corrida",
}


## Carro girando no topo (placeholder do GT2). Criada uma vez e reaproveitada
## a cada reconstrução da tela.
var _vitrine: VitrineCarro


func _init(d: Node, j: Node) -> void:
	super(d, j, "Oficina")
	_vitrine = VitrineCarro.new()
	_vitrine.fundo_imagem(Aba.arte("fundo_garagem"))


func atualizar() -> void:
	if _vitrine.get_parent() != null:
		_vitrine.get_parent().remove_child(_vitrine)
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_vitrine) and _vitrine.get_parent() == null:
		_vitrine.free()


## Grupo aberto: "motor", "chassi" ou "pneus" (mantido ao voltar).
var _grupo := "motor"
const GRUPOS := [["motor", "Motor", "categoria_motor"], ["chassi", "Chassi", "categoria_chassi"],
	["pneus", "Pneus", "categoria_pneus"]]
## Miniatura (arte da interface) de cada categoria de peça e de cada pneu.
const MINIATURA_PECA := {"aspiracao": "peca_aspiracao", "lightweight": "peca_peso", "brake": "peca_freios",
	"muffler": "peca_escapamento", "portpolish": "peca_dutos", "enginebalance": "peca_balanceamento",
	"displacement": "peca_cilindrada", "computer": "peca_computador", "intercooler": "peca_intercooler",
	"cambio": "peca_cambio"}
const MINIATURA_PNEU := {"pneu_0": "pneu_fabrica", "pneu_1": "pneu_esportivo", "pneu_2": "pneu_corrida_duro",
	"pneu_3": "pneu_corrida_medio", "pneu_4": "pneu_corrida_macio", "pneu_5": "pneu_corrida_supermacio",
	"pneu_6": "pneu_simulacao"}
const CHASSI := ["lightweight", "brake", "cambio", "corrida"]
## O que a melhoria faz na pista, dito pela função.
const FUNCAO := {
	"potencia": "acelera mais forte e chega mais rápido no fim da reta",
	"peso": "acelera, contorna e freia melhor",
	"freio": "permite frear mais tarde antes das curvas",
	"pneu": "contorna mais rápido e freia mais curto",
	"cambio": "Arrancada acelera mais forte; Velocidade final vai mais rápido no fim das retas",
}

## Ajustes do câmbio ajustável: [valor em Carro.ajuste_cambio, rótulo].
const AJUSTES_CAMBIO := [["curto", "Arrancada"], ["", "Equilibrado"], ["longo", "Velocidade final"]]


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	if lista.is_empty():
		rotulo("Oficina", FONTE_TITULO)
		proximo_passo("Você ainda não tem carro para melhorar.", "Ir para o Mercado", LOJA)
		return
	if carro_ativo() == null:
		jogador.carro_ativo = lista[0].uid
	var c := carro_ativo()
	_vitrine.mostrar_modelo(c.base, CarroBloco.cor_do_carro(c))
	_vitrine.custom_minimum_size.y = 260
	conteudo.add_child(_vitrine)
	var topo := fileira()
	rotulo("Oficina · " + c.base["nome"], 34, Color.WHITE, topo)
	if lista.size() > 1:
		var escolha := OptionButton.new()
		escolha.custom_minimum_size = Vector2(150, 60)
		for k in lista.size():
			escolha.add_item(lista[k].base["nome"], lista[k].uid)
			if lista[k].uid == c.uid:
				escolha.select(k)
		escolha.item_selected.connect(func(k):
			jogador.carro_ativo = escolha.get_item_id(k)
			mudou.emit())
		topo.add_child(escolha)
	var seco := c.atributos_efetivos("seco")
	atributos_carro(seco)
	if _correndo(c):
		nota("icone_ao_vivo", "Correndo: muda só as próximas", "As corridas já marcadas usam a montagem do "
				+ "início. O que mudar aqui vale para as próximas.", null, COR_INFO)
	_configuracoes(c)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	for g in GRUPOS:
		var b := Button.new()
		b.text = g[1]
		b.toggle_mode = true
		b.button_pressed = _grupo == g[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 76)
		com_icone(b, g[2], 96)
		b.pressed.connect(func():
			_grupo = g[0]
			mudou.emit())
		abas.add_child(b)
	conteudo.add_child(abas)
	if _grupo == "pneus":
		_pneus(c)
	else:
		_pecas(c, seco)
	if not c.pecas.is_empty():
		botao_texto("Voltar ao carro de fábrica", func(): _fabrica(c), null)
	botao("Escolher uma corrida", func(): ir_para.emit(EVENTOS), true, false)


## Preparações salvas: o jogador constrói opções ("até 150 cv", "retas") e
## troca entre elas de graça. Só peças já compradas para o carro.
func _configuracoes(c: Carro) -> void:
	var v := cartao()
	titulo_secao("MONTAGENS SALVAS", "Guarde a montagem atual (peças e pneus) para voltar a ela depois, sem custo. "
			+ "Ex.: \"até 150 cv\", \"pista de retas\".", v)
	var atual := c.configuracao()
	for i in c.configuracoes.size():
		var cfg: Dictionary = c.configuracoes[i]
		var em_uso: bool = cfg["pecas"] == atual["pecas"] and cfg["ajuste_cambio"] == atual["ajuste_cambio"]
		var a := c.com_configuracao(cfg, dados.peca).atributos_efetivos("seco")
		var h := fileira(v)
		var l := rotulo("%s\n%d cv · %d kg · %d peça%s%s" % [cfg["nome"], a["potencia"], a["peso"], cfg["pecas"].size(),
				"" if cfg["pecas"].size() == 1 else "s", " · em uso" if em_uso else ""],
				FONTE_PEQUENA + 1, COR_BOM if em_uso else Color.WHITE, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao("Usar", func():
			var fora: Array = c.equipar(cfg, dados.peca)
			avisar("Em uso: %s%s." % [cfg["nome"], "" if fora.is_empty() else " (faltam %d peça%s não compradas)" % [
					fora.size(), "" if fora.size() == 1 else "s"]], fora.is_empty())
			mudou.emit(), not em_uso, false, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao_texto("Apagar", func():
			c.configuracoes.remove_at(i)
			mudou.emit(), h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao_texto("Salvar a montagem atual", _salvar_configuracao.bind(c), v)


func _salvar_configuracao(c: Carro) -> void:
	var nome := LineEdit.new()
	nome.text = "%d cv" % roundi(c.atributos_efetivos("seco")["potencia"])
	nome.max_length = 24
	nome.custom_minimum_size = Vector2(0, 64)
	nome.select_all_on_focus = true
	painel.emit("Salvar montagem", func(v):
		rotulo("Nome (ex.: \"até 150 cv\"):", FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		v.add_child(nome), [["Salvar", func():
			var cfg := c.configuracao()
			cfg["nome"] = nome.text.strip_edges() if nome.text.strip_edges() != "" else "Montagem %d" % (c.configuracoes.size() + 1)
			c.configuracoes.append(cfg)
			avisar("Montagem salva: %s." % cfg["nome"])
			mudou.emit()], ["Cancelar", func(): pass]])


func _correndo(c: Carro) -> bool:
	return not jogador.fila.is_empty() and int(jogador.fila["uid"]) == c.uid


## Destaque dos freios (tutorial): abre o grupo do chassi, onde eles ficam.
func preparar_destaque(nome: String) -> void:
	if nome == "BRAKES":
		_grupo = "chassi"


func _pecas(c: Carro, seco: Dictionary) -> void:
	var por_categoria := {}
	for p in dados.lista("pecas"):
		if not p.get("carros_permitidos", []).is_empty() and not c.id in p["carros_permitidos"]:
			continue
		if c.motivo_recusa(p) != "":
			continue
		if (p["categoria"] in CHASSI) != (_grupo == "chassi"):
			continue
		por_categoria.get_or_add(p["categoria"], []).append(p)
	if por_categoria.is_empty():
		rotulo("Nenhuma peça deste grupo para este carro.", 0, COR_SECUNDARIA)
	var provas_antes := Mecanico.provas_possiveis(dados, c)
	# A função vale para o grupo inteiro: dita uma vez, no topo.
	var attr_grupo: String = "potencia" if _grupo == "motor" else ""
	if attr_grupo != "":
		nota("icone_potencia", "Motor: mais potência", "Peças de motor: " + FUNCAO["potencia"] + ".")
	for cat in por_categoria:
		por_categoria[cat].sort_custom(func(a, b): return a["preco"] < b["preco"])
		var v := cartao()
		if cat == "brake":
			ancora("BRAKES", v)
		var attr: String = AFETA_CATEGORIA.get(cat, "potencia")
		var cab := fileira(v)
		if arte(MINIATURA_PECA.get(cat, "")) != null:
			var mini := ilustracao(MINIATURA_PECA[cat], 96, cab, 0.0)
			mini.custom_minimum_size = Vector2(144, 96)
			mini.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var tc := VBoxContainer.new()
		tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tc.alignment = BoxContainer.ALIGNMENT_CENTER
		tc.add_theme_constant_override("separation", 0)
		cab.add_child(tc)
		var ht := HBoxContainer.new()
		tc.add_child(ht)
		rotulo(NOMES_CATEGORIA.get(cat, cat.capitalize()), 30, Color.WHITE, ht).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var detalhe: String = EXPLICA_CATEGORIA.get(cat, "")
		if attr != "potencia":
			detalhe += " Na pista: " + FUNCAO[attr] + "."
		botao_info(NOMES_CATEGORIA.get(cat, cat), detalhe, ht)
		nota(ICONE_ATRIBUTO.get(attr, ""), CURTA_CATEGORIA.get(cat, ""), "", tc)
		for p in por_categoria[cat]:
			_linha(v, c, p, seco, provas_antes)
		if cat == "cambio" and c.pecas.has("cambio"):
			_ajuste_cambio(v, c)


## Curto / equilibrado / longo, com o câmbio ajustável instalado. Grátis e
## reversível: a peça é a compra; o ajuste é escolha de cada prova.
func _ajuste_cambio(pai: Control, c: Carro) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for aj in AJUSTES_CAMBIO:
		var b := Button.new()
		b.text = aj[1]
		b.toggle_mode = true
		b.button_pressed = c.ajuste_cambio == aj[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func():
			c.ajuste_cambio = aj[0]
			mudou.emit())
		h.add_child(b)
	pai.add_child(h)


## Uma linha por peça: nome, ganho principal e estado; tocar abre a decisão.
func _linha(pai: Control, c: Carro, p: Dictionary, antes: Dictionary, provas_antes: Array) -> void:
	var instalada: bool = c.pecas.get(p["categoria"], {}).get("id") == p["id"]
	var possuida: bool = p["id"] in c.pecas_possuidas
	var teste := c.copiar()
	teste.instalar(p)
	var depois := teste.atributos_efetivos("seco")
	var perde := provas_antes.filter(func(e): return not e in Mecanico.provas_possiveis(dados, teste))
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	var pode_pagar: bool = possuida or jogador.economia.pode_pagar(int(p["preco"]))
	var direita := "INSTALADA" if instalada else ("já sua" if possuida else ("%s Cr" % dinheiro(int(p["preco"]))
			if pode_pagar else "faltam %s Cr" % dinheiro(int(p["preco"]) - jogador.economia.saldo)))
	if not perde.is_empty() and not instalada:
		direita = "⚠ " + direita
	# Nome e ganho à esquerda (quebram linha), estado/preço à direita.
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var esq := VBoxContainer.new()
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.alignment = BoxContainer.ALIGNMENT_CENTER
	esq.add_theme_constant_override("separation", -2)
	esq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nome := Label.new()
	nome.text = p["nome"]
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esq.add_child(nome)
	var g := Label.new()
	g.text = "em uso" if instalada else ("arrancada · equilibrado · velocidade final" if p["categoria"] == "cambio"
			else _ganho(antes, depois) + _forma_curta(antes, depois))
	g.add_theme_font_size_override("font_size", FONTE_PEQUENA)
	g.add_theme_color_override("font_color", COR_BOM)
	esq.add_child(g)
	h.add_child(esq)
	var l := Label.new()
	l.text = direita
	l.add_theme_color_override("font_color", COR_RUIM if direita.begins_with("⚠") or not pode_pagar
			else (COR_BOM if instalada else Color.WHITE))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.add_child(h)
	# O botão não mede os filhos: cresce quando o nome quebra em duas linhas.
	esq.minimum_size_changed.connect(func():
		b.custom_minimum_size.y = maxf(96.0, esq.get_combined_minimum_size().y + 20.0))
	if instalada:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COR_BOM, 0.18)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(_decidir.bind(c, p, antes, depois, perde, instalada, possuida))
	pai.add_child(b)


## " · giro alto", " · corte +500" etc.: a identidade da peça de motor na lista.
static func _forma_curta(antes: Dictionary, depois: Dictionary) -> String:
	var f := GraficoMotor.forma_do_ganho(antes, depois)
	var partes := []
	if f.contains("giro alto"):
		partes.append("giro alto")
	elif f.contains("giro baixo"):
		partes.append("giro baixo")
	var dc := float(depois.get("corte", 0.0)) - float(antes.get("corte", 0.0))
	if dc >= 50.0:
		partes.append("corte +%d" % roundi(dc))
	return "" if partes.is_empty() else " · " + ", ".join(partes)


static func _ganho(antes: Dictionary, depois: Dictionary) -> String:
	var dcv: float = depois["potencia"] - antes["potencia"]
	if absf(dcv) >= 0.5:
		return "%+d cv" % roundi(dcv)
	var dkg: float = depois["peso"] - antes["peso"]
	if absf(dkg) >= 0.5:
		return "%+d kg" % roundi(dkg)
	var df: float = depois["freio"] / maxf(antes["freio"], 1e-6) - 1.0
	return "freio %+d%%" % roundi(df * 100.0) if absf(df) >= 0.005 else ""


## Decisão da peça: antes → depois em números grandes, o que muda na pista,
## provas afetadas e custo; confirmar instala (ou remove a instalada).
func _decidir(c: Carro, p: Dictionary, antes: Dictionary, depois: Dictionary, perde: Array, instalada: bool,
		possuida: bool) -> void:
	var attr: String = AFETA_CATEGORIA.get(p["categoria"], "potencia")
	var livre := true
	var botoes := []
	if instalada:
		botoes = [["Remover", func():
			_remover(c, p)
			mudou.emit()], ["Fechar", func(): pass]]
	elif livre and (possuida or jogador.economia.pode_pagar(int(p["preco"]))):
		botoes = [["Usar" if possuida else "Comprar e usar · %s Cr" % dinheiro(int(p["preco"])), func():
			_comprar_peca(c, p, antes)
			mudou.emit()], ["Cancelar", func(): pass]]
	painel.emit(p["nome"], func(v):
		rotulo("Na pista: " + FUNCAO[attr] + ".", FONTE_PEQUENA + 3, Color.WHITE, v)
		# Peça de motor: a forma do ganho na curva de potência (a que a corrida usa).
		var forma := GraficoMotor.forma_do_ganho(antes, depois)
		if not instalada and forma != "":
			rotulo(forma + ".", FONTE_PEQUENA + 2, COR_INFO, v)
			v.add_child(GraficoMotor.new([{"rotulo": "Agora", "cor": COR_SECUNDARIA, "attrs": antes},
					{"rotulo": "Com a peça", "cor": COR_DESTAQUE, "attrs": depois}]))
		if not instalada:
			var muda := []
			if absf(depois["potencia"] - antes["potencia"]) >= 0.5:
				muda.append(["%d → %d" % [roundi(antes["potencia"]), roundi(depois["potencia"])],
						"cv  (%+d)" % roundi(depois["potencia"] - antes["potencia"])])
			if absf(depois["peso"] - antes["peso"]) >= 0.5:
				muda.append(["%d → %d" % [roundi(antes["peso"]), roundi(depois["peso"])],
						"kg  (%+d)" % roundi(depois["peso"] - antes["peso"])])
			if absf(depois["freio"] - antes["freio"]) >= 0.005:
				muda.append(["%.2f → %.2f" % [antes["freio"], depois["freio"]], "freio"])
			numeros(muda, v)
			if not possuida:
				var custo := int(p["preco"])
				rotulo("Custa %s Cr · saldo depois: %s Cr" % [dinheiro(custo), dinheiro(jogador.economia.saldo - custo)]
						if jogador.economia.pode_pagar(custo) else "", FONTE_PEQUENA + 2, Color.WHITE, v)
		if not perde.is_empty():
			var vp := cartao(COR_RUIM, v)
			rotulo("⚠ Deixa de poder correr:", FONTE_PEQUENA + 2, COR_RUIM, vp)
			rotulo(", ".join(perde.map(func(e): return dados.evento(e)["nome"])), FONTE_PEQUENA + 2, Color.WHITE, vp)
		if instalada:
			rotulo("Remover não devolve o dinheiro; reinstalar é grátis.",
					FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		elif possuida:
			rotulo("Já é sua: usar de novo é grátis.", FONTE_PEQUENA + 2, COR_BOM, v)
		elif not jogador.economia.pode_pagar(int(p["preco"])):
			rotulo("Custa %s Cr; faltam %s Cr." % [dinheiro(int(p["preco"])), dinheiro(int(p["preco"]) - jogador.economia.saldo)],
					FONTE_PEQUENA + 2, COR_RUIM, v)
		pass, botoes)


func _pneus(c: Carro) -> void:
	var v := cartao()
	rotulo("Pneus", 30, Color.WHITE, v)
	nota("icone_pneus", "Segura mais: curvas e frenagem", "Pneu que segura mais: " + FUNCAO["pneu"]
			+ ". O piloto usa sozinho o melhor que você tiver.", v)
	for pn in dados.lista("pneus"):
		var tem: bool = c.pneus.any(func(x): return x["id"] == pn["id"])
		var h := fileira(v)
		if arte(MINIATURA_PNEU.get(pn["id"], "")) != null:
			var mini := ilustracao(MINIATURA_PNEU[pn["id"]], 84, h, 0.0)
			mini.custom_minimum_size = Vector2(84, 84)
			mini.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(info)
		rotulo(pn["nome"], 0, Color.WHITE, info)
		rotulo("aderência %d (curvas e frenagem)" % roundi(pn["aderencia"]["seco"] * 100.0), FONTE_PEQUENA, COR_SECUNDARIA, info)
		if tem:
			var l := rotulo("SEU", FONTE_PEQUENA, COR_BOM, h)
			l.size_flags_horizontal = Control.SIZE_SHRINK_END
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			var b := botao("%s Cr" % dinheiro(int(pn["preco"])), _comprar_pneu.bind(c, pn),
					jogador.economia.pode_pagar(int(pn["preco"])), false, h)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Selos "antes → depois" dos atributos que mudam.
static func _diferencas(antes: Dictionary, depois: Dictionary) -> Array:
	var r := []
	if absf(depois["potencia"] - antes["potencia"]) >= 0.5:
		r.append(["%d → %d cv" % [roundi(antes["potencia"]), roundi(depois["potencia"])],
				COR_BOM if depois["potencia"] > antes["potencia"] else COR_RUIM])
	if absf(depois["peso"] - antes["peso"]) >= 0.5:
		r.append(["%d → %d kg" % [roundi(antes["peso"]), roundi(depois["peso"])],
				COR_BOM if depois["peso"] < antes["peso"] else COR_RUIM])
	if absf(depois["freio"] - antes["freio"]) >= 0.005:
		r.append(["freio %.2f → %.2f" % [antes["freio"], depois["freio"]],
				COR_BOM if depois["freio"] > antes["freio"] else COR_RUIM])
	return r


func _comprar_peca(c: Carro, p: Dictionary, antes: Dictionary) -> void:
	var possuida: bool = p["id"] in c.pecas_possuidas
	var motivo: String = jogador.concessionaria.comprar_peca(c, p)
	if motivo != "":
		avisar("Não deu para usar %s: %s." % [p["nome"], motivo], false)
		if not jogador.economia.pode_pagar(int(p["preco"])):
			historia("SEM_DINHEIRO")
		return
	historia("PECA_COMPRADA")
	var mudancas := _diferencas(antes, c.atributos_efetivos("seco")).map(func(x): return x[0])
	avisar("%s %s%s." % ["Em uso de novo:" if possuida else "Em uso:", p["nome"],
			" (" + ", ".join(mudancas) + ")" if not mudancas.is_empty() else ""])


func _remover(c: Carro, p: Dictionary) -> void:
	c.remover(p["categoria"])
	avisar("Removida: %s. Continua sua; use de novo de graça quando quiser." % p["nome"])


func _fabrica(c: Carro) -> void:
	for cat in c.pecas.keys():
		c.remover(cat)
	avisar("%s voltou a ser de fábrica. As peças continuam suas." % c.base["nome"])


func _comprar_pneu(c: Carro, pn: Dictionary) -> void:
	var motivo: String = jogador.concessionaria.comprar_pneu(c, pn)
	if motivo != "":
		avisar("Não comprou %s: %s." % [pn["nome"], motivo], false)
	else:
		avisar("Pneu comprado: %s" % pn["nome"])
		historia("PECA_COMPRADA")
