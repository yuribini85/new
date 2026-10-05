extends Aba

## Em que parte da corrida cada atributo pesa.
const AFETA := {
	"potencia": "aceleração e velocidade nas retas",
	"peso": "aceleração, curvas e frenagem",
	"freio": "frenagem antes das curvas",
}
const AFETA_CATEGORIA := {"lightweight": "peso", "brake": "freio"}

## O que cada grupo de peças faz, para a tela explicar antes do preço.
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
}
const NOMES_CATEGORIA := {
	"aspiracao": "Aspiração", "lightweight": "Peso", "brake": "Freios", "muffler": "Escapamento",
	"portpolish": "Polimento de dutos", "enginebalance": "Balanceamento", "displacement": "Cilindrada",
	"computer": "Computador", "intercooler": "Intercooler",
}


## Carro girando no topo (placeholder do GT2). Criada uma vez e reaproveitada
## a cada reconstrução da tela.
var _vitrine: VitrineCarro


func _init(d: Node, j: Node) -> void:
	super(d, j, "Oficina")
	_vitrine = VitrineCarro.new()


func atualizar() -> void:
	if _vitrine.get_parent() != null:
		_vitrine.get_parent().remove_child(_vitrine)
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_vitrine) and _vitrine.get_parent() == null:
		_vitrine.free()


## Grupo aberto: "motor", "chassi" ou "pneus" (mantido ao voltar).
var _grupo := "motor"
const GRUPOS := [["motor", "Motor"], ["chassi", "Chassi"], ["pneus", "Pneus"]]
const CHASSI := ["lightweight", "brake"]
## O que a melhoria faz na pista, dito pela função.
const FUNCAO := {
	"potencia": "acelera mais forte e chega mais rápido no fim da reta",
	"peso": "acelera, contorna e freia melhor",
	"freio": "permite frear mais tarde antes das curvas",
	"pneu": "contorna mais rápido e freia mais curto",
}


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	if lista.is_empty():
		rotulo("Oficina", FONTE_TITULO)
		proximo_passo("Você ainda não tem carro para preparar.", "Ir para o Mercado", LOJA)
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
	numeros([["%d" % seco["potencia"], "cv"], ["%d" % seco["peso"], "kg"], ["%.2f" % seco["aderencia"], "aderência"],
			["%.2f" % seco["freio"], "freio"]])
	if _correndo(c):
		var vf := cartao(COR_BOM)
		rotulo("Este carro está na fila de corrida. Peças só depois que a fila acabar (ou pare-a em Competições).",
				FONTE_PEQUENA + 2, Color.WHITE, vf)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	for g in GRUPOS:
		var b := Button.new()
		b.text = g[1]
		b.toggle_mode = true
		b.button_pressed = _grupo == g[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
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
		botao_texto("Voltar à configuração de fábrica", func(): _fabrica(c), null, not _correndo(c))
	botao("Escolher uma prova", func(): ir_para.emit(EVENTOS), true, false)


func _correndo(c: Carro) -> bool:
	return not jogador.fila.is_empty() and int(jogador.fila["uid"]) == c.uid


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
		rotulo("Peças de motor: " + FUNCAO["potencia"] + ".", FONTE_PEQUENA + 2, COR_SECUNDARIA)
	for cat in por_categoria:
		por_categoria[cat].sort_custom(func(a, b): return a["preco"] < b["preco"])
		var v := cartao()
		var attr: String = AFETA_CATEGORIA.get(cat, "potencia")
		rotulo(NOMES_CATEGORIA.get(cat, cat.capitalize()), 30, Color.WHITE, v)
		if attr != "potencia":
			rotulo(FUNCAO[attr].capitalize().left(1) + FUNCAO[attr].substr(1) + ".", FONTE_PEQUENA, COR_SECUNDARIA, v)
		for p in por_categoria[cat]:
			_linha(v, c, p, seco, provas_antes)


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
	g.text = _ganho(antes, depois) if not instalada else "em uso"
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
	if instalada:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COR_BOM, 0.18)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(_decidir.bind(c, p, antes, depois, perde, instalada, possuida))
	pai.add_child(b)


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
	var livre := not _correndo(c)
	var botoes := []
	if instalada:
		botoes = [["Remover", func():
			_remover(c, p)
			mudou.emit()], ["Fechar", func(): pass]]
	elif livre and (possuida or jogador.economia.pode_pagar(int(p["preco"]))):
		botoes = [["Instalar" if possuida else "Comprar · %s Cr" % dinheiro(int(p["preco"])), func():
			_comprar_peca(c, p, antes)
			mudou.emit()], ["Cancelar", func(): pass]]
	painel.emit(p["nome"], func(v):
		rotulo("Na pista: " + FUNCAO[attr] + ".", FONTE_PEQUENA + 3, Color.WHITE, v)
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
			rotulo("Instalada. Remover não devolve o dinheiro, mas a peça continua sua para reinstalar de graça.",
					FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		elif possuida:
			rotulo("Já é sua: reinstalar é grátis.", FONTE_PEQUENA + 2, COR_BOM, v)
		elif not jogador.economia.pode_pagar(int(p["preco"])):
			rotulo("Custa %s Cr; faltam %s Cr." % [dinheiro(int(p["preco"])), dinheiro(int(p["preco"]) - jogador.economia.saldo)],
					FONTE_PEQUENA + 2, COR_RUIM, v)
		if not livre:
			rotulo("O carro está na fila de corrida: espere a fila acabar.", FONTE_PEQUENA + 2, COR_RUIM, v), botoes)


func _pneus(c: Carro) -> void:
	var v := cartao()
	rotulo("Pneus", 30, Color.WHITE, v)
	rotulo("Mais aderência: " + FUNCAO["pneu"] + ". O piloto usa sozinho o melhor que você tiver.",
			FONTE_PEQUENA, COR_SECUNDARIA, v)
	for pn in dados.lista("pneus"):
		var tem: bool = c.pneus.any(func(x): return x["id"] == pn["id"])
		var h := fileira(v)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		rotulo(pn["nome"], 0, Color.WHITE, info)
		rotulo("aderência ×%.2f" % pn["aderencia"]["seco"], FONTE_PEQUENA, COR_SECUNDARIA, info)
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
		avisar("Não instalou %s: %s." % [p["nome"], motivo], false)
		return
	var mudancas := _diferencas(antes, c.atributos_efetivos("seco")).map(func(x): return x[0])
	avisar("%s %s%s." % ["Reinstalada:" if possuida else "Instalada:", p["nome"],
			" (" + ", ".join(mudancas) + ")" if not mudancas.is_empty() else ""])


func _remover(c: Carro, p: Dictionary) -> void:
	c.remover(p["categoria"])
	avisar("Removida: %s. Continua sua; reinstale de graça quando quiser." % p["nome"])


func _fabrica(c: Carro) -> void:
	for cat in c.pecas.keys():
		c.remover(cat)
	avisar("%s voltou à configuração de fábrica. As peças continuam suas." % c.base["nome"])


func _comprar_pneu(c: Carro, pn: Dictionary) -> void:
	var motivo: String = jogador.concessionaria.comprar_pneu(c, pn)
	if motivo != "":
		avisar("Não comprou %s: %s." % [pn["nome"], motivo], false)
	else:
		avisar("Pneu comprado: %s. O piloto usa quando for o melhor para a prova." % pn["nome"])
