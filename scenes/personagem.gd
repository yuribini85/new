extends Node2D
## Token placeholder de personagem (líder ou órfão) no mapa. Sem arte — quando os
## sprites de docs/NOMENCLATURA_ASSETS.md existirem, o Corpo vira um Sprite2D
## twb_chr_<slug>_idle.png. A "ação" por enquanto é só um balanço idle contínuo,
## para diferenciar de um objeto estático (rotas/caminhada real ficam a cargo do
## sistema de andarilhos do Módulo 6, para quem está de fato produzindo).

@onready var _corpo: Polygon2D = $Corpo


func configurar(cor: Color) -> void:
	_corpo.color = cor
	var atraso := randf() * 0.6  # dessincroniza o balanço entre personagens
	var tween := create_tween().set_loops()
	tween.tween_interval(atraso)
	tween.tween_property(_corpo, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_corpo, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
