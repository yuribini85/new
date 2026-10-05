extends Aba


func _init(d: Node, j: Node) -> void:
	super(d, j, "Garagem")


func construir() -> void:
	titulo("Garagem (%d)" % jogador.garagem.lista().size())
	if jogador.garagem.lista().is_empty():
		texto("Nenhum carro. Compre o primeiro na Loja.")
		return
	var regras: Dictionary = dados.economia()
	for c in jogador.garagem.lista():
		var ativo: bool = c.uid == jogador.carro_ativo
		var venda := int(floor(float(c.base["preco"]) * float(regras["fracao_revenda"])))
		var desc := ("▶ " if ativo else "") + ficha(c)
		var em_fila: bool = not jogador.fila.is_empty() and jogador.fila["uid"] == c.uid
		linha(desc, [
			["Usar", func(): jogador.carro_ativo = c.uid, not ativo],
			["Vender %s" % dinheiro(venda), _vender.bind(c.uid),
				not em_fila and jogador.concessionaria.pode_vender(c.uid)],
		])
	if jogador.garagem.lista().size() == 1:
		texto("O único carro da garagem não pode ser vendido.", Color(0.7, 0.8, 1.0))


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		return
	jogador.concessionaria.vender_carro(uid)
	if jogador.carro_ativo == uid:
		jogador.carro_ativo = -1
