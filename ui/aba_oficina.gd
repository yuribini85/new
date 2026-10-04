extends Aba

var _aviso := ""

const NOMES_CATEGORIA := {
	"aspiracao": "Aspiração", "lightweight": "Peso", "brake": "Freios", "muffler": "Escapamento",
	"portpolish": "Polimento de dutos", "enginebalance": "Balanceamento", "displacement": "Cilindrada",
	"computer": "Computador", "intercooler": "Intercooler",
}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Oficina")


func construir() -> void:
	var c := carro_ativo()
	if c == null:
		titulo("Oficina")
		texto("Escolha um carro na Garagem.")
		return
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
