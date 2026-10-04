extends Node
## Estado do jogador: saldo, garagem e a concessionária que opera sobre eles.
## Criado a partir de data/economia.json; sem esses valores o jogo não começa.

var economia: Economia
var garagem: Garagem
var concessionaria: Concessionaria
## Ids de licença conquistadas.
var licencas: Array = []
## evento_id -> número de vitórias.
var vitorias: Dictionary = {}
## Corridas disputadas; cada uma conta um dia (rotação de usados).
var dias: int = 0


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
	licencas = []
	vitorias = {}
	dias = 0
