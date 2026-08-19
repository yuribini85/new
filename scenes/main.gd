extends Node2D
## Tela de debug do Módulo 1 — sem arte, só para inspecionar o relógio da simulação
## enquanto os módulos de mapa/economia não existem. Será substituída pelo mapa (bloco 3).

@onready var _label: Label = $Label

const NOMES_FASE := ["MANHA", "TARDE", "NOITE"]


func _ready() -> void:
	Sim.fase_mudou.connect(func(_f): _atualizar())
	Sim.dia_mudou.connect(func(_d): _atualizar())
	_atualizar()
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_atualizar)
	add_child(t)
	t.start()


func _atualizar() -> void:
	_label.text = "THE WAY BACK — Módulo 1\n\ndia_vila: %d\nfase_dia: %s\nato: %d\ntempo_jogo_seg: %d\nnivel_casa_fiandeiras: %d" % [
		Sim.dia_vila,
		NOMES_FASE[Sim.fase_dia],
		Sim.ato,
		Sim.tempo_jogo_seg,
		Sim.nivel_casa_fiandeiras,
	]
