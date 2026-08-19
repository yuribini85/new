extends Node2D
## Tela de debug — sem arte, só para inspecionar o estado da simulação e dos
## dados carregados enquanto o módulo de Mapa (bloco 3) não existe.

@onready var _label: Label = $Label

const NOMES_FASE := ["MANHA", "TARDE", "NOITE"]

var _catalogo: Dictionary = {}


func _ready() -> void:
	_catalogo = Dados.catalogo_edificios_ato1()
	Sim.fase_mudou.connect(func(_f): _atualizar())
	Sim.dia_mudou.connect(func(_d): _atualizar())
	_atualizar()
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_atualizar)
	add_child(t)
	t.start()


func _atualizar() -> void:
	var linhas_catalogo := ""
	for id in _catalogo.keys():
		var def: Dictionary = _catalogo[id]
		linhas_catalogo += "  · %s (custo %d, cel %s)\n" % [def["nome"], def["custo_n1"], def["celula"]]

	_label.text = "THE WAY BACK — Módulo 2\n\ndia_vila: %d\nfase_dia: %s\nato: %d\ntempo_jogo_seg: %d\n\ncatálogo Ato I (%d edifícios):\n%s" % [
		Sim.dia_vila,
		NOMES_FASE[Sim.fase_dia],
		Sim.ato,
		Sim.tempo_jogo_seg,
		_catalogo.size(),
		linhas_catalogo,
	]
