extends Aba

var _aviso := ""

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
	if lista.is_empty():
		titulo("Oficina")
		texto("Nenhum carro. Compre o primeiro na Loja.")
		return
	if carro_ativo() == null:
		jogador.carro_ativo = lista[0].uid
	var c := carro_ativo()
	# Como no GT2: primeiro se escolhe qual carro da garagem vai ser preparado.
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
	titulo(c.base["nome"])
	texto("Seco: " + ficha(c, "seco"))
	var chuva := c.atributos_efetivos("chuva")
	texto("Aderência seco %.2f · chuva %.2f" % [c.atributos_efetivos("seco")["aderencia"], chuva["aderencia"]])
	if _aviso != "":
		texto(_aviso, Color(1, 0.6, 0.4))
		_aviso = ""
	separador()
	titulo("Peças")
	var por_categoria := {}
	for p in dados.lista("pecas"):
		# Peças do GT2 são de um carro só: as dos outros nem aparecem.
		if not p.get("carros_permitidos", []).is_empty() and not c.id in p["carros_permitidos"]:
			continue
		por_categoria.get_or_add(p["categoria"], []).append(p)
	for cat in por_categoria:
		por_categoria[cat].sort_custom(func(a, b): return a["preco"] < b["preco"])
		texto(NOMES_CATEGORIA.get(cat, cat.capitalize()), Color(0.7, 0.8, 1.0))
		for p in por_categoria[cat]:
			var instalada: bool = c.pecas.get(cat, {}).get("id") == p["id"]
			var possuida: bool = p["id"] in c.pecas_possuidas
			var recusa := c.motivo_recusa(p)
			var rotulo := "Instalada" if instalada else ("Instalar" if possuida else dinheiro(int(p["preco"])))
			linha(p["nome"] + ("" if recusa == "" else " (não serve)"), [
				[rotulo, func(): _aviso = jogador.concessionaria.comprar_peca(c, p),
					not instalada and recusa == "" and (possuida or jogador.economia.pode_pagar(int(p["preco"])))],
			])
	separador()
	titulo("Pneus")
	for pn in dados.lista("pneus"):
		var tem: bool = c.pneus.any(func(x): return x["id"] == pn["id"])
		linha("%s · seco %.2f · chuva %.2f" % [pn["nome"], pn["aderencia"]["seco"], pn["aderencia"]["chuva"]], [
			["Possui" if tem else dinheiro(int(pn["preco"])), func(): _aviso = jogador.concessionaria.comprar_pneu(c, pn),
				not tem and jogador.economia.pode_pagar(int(pn["preco"]))],
		])
	texto("O piloto usa sozinho o melhor pneu para a condição da prova.", Color(0.7, 0.7, 0.7))
