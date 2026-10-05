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


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	cabecalho("Oficina", "Prepare o carro: peças e pneus deixam ele mais rápido.")
	if lista.is_empty():
		proximo_passo("Você ainda não tem carro para preparar.", "Ir para a Loja", LOJA)
		return
	if carro_ativo() == null:
		jogador.carro_ativo = lista[0].uid
	var c := carro_ativo()
	# Como no GT2: primeiro se escolhe qual carro da garagem vai ser preparado.
	rotulo("CARRO A PREPARAR", FONTE_PEQUENA, COR_SECUNDARIA)
	var escolha := OptionButton.new()
	escolha.custom_minimum_size = Vector2(0, 72)
	for i in lista.size():
		escolha.add_item(lista[i].base["nome"], lista[i].uid)
		if lista[i].uid == c.uid:
			escolha.select(i)
	escolha.item_selected.connect(func(i):
		jogador.carro_ativo = escolha.get_item_id(i)
		mudou.emit())
	conteudo.add_child(escolha)
	_vitrine.mostrar(c.base.get("categoria", ""), CarroBloco.cor_do_id(c.id))
	conteudo.add_child(_vitrine)
	rotulo(c.base["nome"], 34)
	selos(selos_carro(c.base))
	var seco := c.atributos_efetivos("seco")
	var chuva := c.atributos_efetivos("chuva")
	var ficha_v := cartao()
	barras_carro(seco, ficha_v)
	barra("Aderência", seco["aderencia"], 1.6, "%.2f seco" % seco["aderencia"], COR_BOM, ficha_v)
	barra("Na chuva", chuva["aderencia"], 1.6, "%.2f" % chuva["aderencia"], COR_INFO, ficha_v)
	barra("Freio", seco["freio"], 1.6, "%.2f" % seco["freio"], COR_RUIM, ficha_v)
	rotulo("Aderência vem dos pneus: pesa nas curvas e na frenagem.", FONTE_PEQUENA, COR_SECUNDARIA, ficha_v)
	if not c.pecas.is_empty():
		botao("Voltar ao de fábrica", func(): _fabrica(c), not _correndo(c), false, ficha_v)
	if _correndo(c):
		var vf := cartao(COR_BOM)
		rotulo("Este carro está correndo na fila. Para mudar peças, espere a fila acabar ou pare-a em Eventos: "
				+ "assim a corrida em andamento não muda no meio.", FONTE_PEQUENA + 2, Color.WHITE, vf)
		botao("Ir para Eventos", func(): ir_para.emit(EVENTOS), true, false, vf)
	dica("Cada peça mostra o antes → depois. Uma peça por grupo: a nova substitui a "
			+ "instalada, e as já compradas reinstalam de graça. Atenção ao ⚠: mais potência "
			+ "pode tirar o carro de provas com limite de cv.")
	var provas_antes := Mecanico.provas_possiveis(dados, c)
	rotulo("PEÇAS", FONTE_PEQUENA, COR_SECUNDARIA)
	var por_categoria := {}
	for p in dados.lista("pecas"):
		# Peças do GT2 são de um carro só: as dos outros nem aparecem.
		if not p.get("carros_permitidos", []).is_empty() and not c.id in p["carros_permitidos"]:
			continue
		if c.motivo_recusa(p) != "":
			continue
		por_categoria.get_or_add(p["categoria"], []).append(p)
	if por_categoria.is_empty():
		rotulo("Nenhuma peça disponível para este carro.", 0, COR_SECUNDARIA)
	for cat in por_categoria:
		por_categoria[cat].sort_custom(func(a, b): return a["preco"] < b["preco"])
		var v := cartao()
		rotulo(NOMES_CATEGORIA.get(cat, cat.capitalize()), 30, COR_INFO, v)
		if EXPLICA_CATEGORIA.has(cat):
			rotulo(EXPLICA_CATEGORIA[cat], FONTE_PEQUENA, COR_SECUNDARIA, v)
		var attr: String = AFETA_CATEGORIA.get(cat, "potencia")
		selos([["Ajuda em: " + AFETA[attr], COR_INFO]], v)
		for p in por_categoria[cat]:
			_linha_peca(c, p, seco, provas_antes, v)
	rotulo("PNEUS", FONTE_PEQUENA, COR_SECUNDARIA)
	var vp := cartao()
	rotulo("Mais aderência: curvas mais rápidas e frenagem mais curta. O piloto usa sozinho o melhor pneu "
			+ "que você tem para a condição da prova (seco ou chuva).", FONTE_PEQUENA, COR_SECUNDARIA, vp)
	for pn in dados.lista("pneus"):
		var tem: bool = c.pneus.any(func(x): return x["id"] == pn["id"])
		var h := fileira(vp)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		rotulo(pn["nome"], 0, Color.WHITE, info)
		selos([["seco ×%.2f" % pn["aderencia"]["seco"], COR_BOM], ["chuva ×%.2f" % pn["aderencia"]["chuva"], COR_INFO]]
				+ ([["TEM", COR_DESTAQUE]] if tem else []), info)
		if not tem:
			var b := botao("%s Cr" % dinheiro(int(pn["preco"])), _comprar_pneu.bind(c, pn),
					jogador.economia.pode_pagar(int(pn["preco"])), false, h)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	proximo_passo("Com o carro preparado, volte às provas.", "Ver eventos", EVENTOS)


func _correndo(c: Carro) -> bool:
	return not jogador.fila.is_empty() and int(jogador.fila["uid"]) == c.uid


## Uma peça: nome, antes → depois (copia o carro e instala) e o botão.
func _linha_peca(c: Carro, p: Dictionary, antes: Dictionary, provas_antes: Array, pai: Control) -> void:
	var cat: String = p["categoria"]
	var instalada: bool = c.pecas.get(cat, {}).get("id") == p["id"]
	var possuida: bool = p["id"] in c.pecas_possuidas
	var h := fileira(pai)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	rotulo(p["nome"], 0, Color.WHITE, info)
	var efeitos := []
	if instalada:
		efeitos.append(["INSTALADA", COR_DESTAQUE])
	else:
		var teste := c.copiar()
		teste.instalar(p)
		efeitos += _diferencas(antes, teste.atributos_efetivos("seco"))
		if possuida:
			efeitos.append(["já comprada", COR_NEUTRA.lightened(0.3)])
		var depois := Mecanico.provas_possiveis(dados, teste)
		var perde := provas_antes.filter(func(e): return not e in depois)
		if not perde.is_empty():
			efeitos.append(["⚠ deixa de correr: " + ", ".join(perde.map(func(e): return dados.evento(e)["nome"])), COR_RUIM])
	selos(efeitos, info)
	var livre := not _correndo(c)
	var b: Button
	if instalada:
		b = botao("Remover", _remover.bind(c, p), livre, false, h)
	else:
		b = botao("Instalar" if possuida else "%s Cr" % dinheiro(int(p["preco"])), _comprar_peca.bind(c, p, antes),
				livre and (possuida or jogador.economia.pode_pagar(int(p["preco"]))), false, h)
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
