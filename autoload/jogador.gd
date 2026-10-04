extends Node
## Estado do jogador: saldo, garagem e a concessionária que opera sobre eles.
## Criado a partir de data/economia.json; sem esses valores o jogo não começa.

var economia: Economia
var garagem: Garagem
var concessionaria: Concessionaria


func _ready() -> void:
	var dados := get_node("/root/Dados")
	var regras: Dictionary = dados.economia()
	if regras.get("saldo_inicial") == null:
		push_warning("Jogador: economia.json pendente, estado não criado")
		return
	novo_jogo(regras, dados.pneu)


func novo_jogo(regras: Dictionary, pneu_por_id: Callable) -> void:
	economia = Economia.new(int(regras["saldo_inicial"]))
	garagem = Garagem.new()
	concessionaria = Concessionaria.new(economia, garagem, regras, pneu_por_id)
