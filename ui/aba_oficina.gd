extends Aba

var _aviso := ""

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
	if _aviso != "":
		var v := cartao(COR_RUIM)
		rotulo(_aviso, 0, COR_RUIM, v)
		_aviso = ""
	dica("Cada peça mostra o efeito antes da compra. Uma peça por grupo: a nova substitui a "
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
		for p in por_categoria[cat]:
			_linha_peca(c, p, seco, provas_antes, v)
	rotulo("PNEUS", FONTE_PEQUENA, COR_SECUNDARIA)
	var vp := cartao()
	rotulo("O piloto usa sozinho o melhor pneu que você tem para a condição da prova (seco ou chuva).",
			FONTE_PEQUENA, COR_SECUNDARIA, vp)
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
			var b := botao("%s Cr" % dinheiro(int(pn["preco"])), func(): _aviso = jogador.concessionaria.comprar_pneu(c, pn),
					jogador.economia.pode_pagar(int(pn["preco"])), false, h)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	proximo_passo("Com o carro preparado, volte às provas.", "Ver eventos", EVENTOS)


## Uma peça: nome, efeito calculado (copia o carro e instala) e o botão.
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
		var depois := teste.atributos_efetivos("seco")
		var dcv: float = depois["potencia"] - antes["potencia"]
		var dkg: float = depois["peso"] - antes["peso"]
		var dfreio: float = depois["freio"] / maxf(antes["freio"], 1e-6) - 1.0
		if absf(dcv) >= 0.5:
			efeitos.append(["%+d cv" % roundi(dcv), COR_BOM if dcv > 0 else COR_RUIM])
		if absf(dkg) >= 0.5:
			efeitos.append(["%+d kg" % roundi(dkg), COR_BOM if dkg < 0 else COR_RUIM])
		if absf(dfreio) >= 0.005:
			efeitos.append(["freio %+d%%" % roundi(dfreio * 100.0), COR_BOM if dfreio > 0 else COR_RUIM])
		if possuida:
			efeitos.append(["já comprada", COR_NEUTRA.lightened(0.3)])
		var perde := provas_antes.filter(func(e): return not e in Mecanico.provas_possiveis(dados, teste))
		if not perde.is_empty():
			efeitos.append(["⚠ sai de %d prova%s" % [perde.size(), "" if perde.size() == 1 else "s"], COR_RUIM])
	selos(efeitos, info)
	if not instalada:
		var b := botao("Instalar" if possuida else "%s Cr" % dinheiro(int(p["preco"])),
				func(): _aviso = jogador.concessionaria.comprar_peca(c, p),
				possuida or jogador.economia.pode_pagar(int(p["preco"])), false, h)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
