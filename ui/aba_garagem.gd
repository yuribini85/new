extends Aba

## Primeiro toque em "Recomeçar carreira" só pede confirmação.
var _confirmar_recomeco := false


func _init(d: Node, j: Node) -> void:
	super(d, j, "Garagem")


func construir() -> void:
	titulo("Garagem (%d)" % jogador.garagem.lista().size())
	if jogador.garagem.lista().is_empty():
		if _sem_saida():
			texto("Sem carro e sem saldo para comprar um. Recomece a carreira do zero.",
				Color(1.0, 0.75, 0.4))
			linha("", [["Recomeçar carreira", _recomecar]])
			texto("Versão %s" % versao(), Color(0.5, 0.5, 0.55))
		else:
			texto("Nenhum carro. Compre o primeiro na Loja.")
			_rodape()
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
	_rodape()


## Recomeçar sempre disponível (com confirmação) e versão publicada, para saber
## se o navegador já carregou a atualização.
func _rodape() -> void:
	separador()
	if _confirmar_recomeco:
		linha("Apagar todo o progresso e voltar ao saldo inicial?", [
			["Sim, recomeçar", _recomecar],
			["Cancelar", func(): _confirmar_recomeco = false],
		])
	else:
		linha("", [["Recomeçar carreira", func(): _confirmar_recomeco = true]])
	texto("Versão %s" % versao(), Color(0.5, 0.5, 0.55))


## Commit publicado (versao.txt, gerado pelo workflow do Pages) ou "local".
static func versao() -> String:
	var v := FileAccess.get_file_as_string("res://versao.txt").strip_edges()
	return v if v != "" else "local"


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		return
	jogador.concessionaria.vender_carro(uid)
	if jogador.carro_ativo == uid:
		jogador.carro_ativo = -1


## Garagem vazia e nenhum carro (novo ou usado de hoje) cabe no saldo: saves
## anteriores à regra do último carro podem ter ficado assim.
func _sem_saida() -> bool:
	var precos := []
	for c in dados.lista("carros"):
		if c.get("novo", true):
			precos.append(int(c["preco"]))
	for o in Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos):
		precos.append(int(o["preco"]))
	return precos.all(func(p): return not jogador.economia.pode_pagar(p))


func _recomecar() -> void:
	_confirmar_recomeco = false
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
