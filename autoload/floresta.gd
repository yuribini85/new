extends Node
## Módulo 6 — Floresta. docs/mecanicas_para_godot.md #5. Geração seedada em anel
## ao redor da Cabana do Lenhador, corte pela árvore mais próxima da cabana
## (não do trabalhador — o desmatamento cresce em anel), regeneração só à noite.

const CENTRO_ID := "cabana_do_lenhador"

var arvores: Array = []  # Array[Arvore]
var _seed: int = 0
var _corte_acumulado_seg: float = 0.0


func _ready() -> void:
	Sim.tick.connect(_on_tick)


func gerar_se_vazio() -> void:
	if not arvores.is_empty():
		return
	_seed = randi()
	_gerar(_seed)


func _gerar(semente: int) -> void:
	arvores.clear()
	if not Vila.edificios.has(CENTRO_ID):
		return
	var centro: Vector2i = Vila.edificios[CENTRO_ID].celula

	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var cfg: Dictionary = Dados.get_dados("floresta")
	var raio: int = cfg.get("raio_trabalho_celulas", 10)
	var passo: int = maxi(1, cfg.get("distancia_minima_celulas", 2))
	var chance_base: float = cfg.get("arvores_por_celula_pct", 0.35)
	var n_variantes: int = cfg.get("variantes", 4)

	var x := -raio
	while x <= raio:
		var y := -raio
		while y <= raio:
			var dist := Vector2(x, y).length()
			if dist <= raio and dist > 1.0:
				# "mais densa longe da vila" (mecanicas_para_godot.md #5)
				var chance := chance_base * clampf(dist / float(raio), 0.2, 1.0)
				if rng.randf() < chance:
					var a := Arvore.new()
					a.celula = centro + Vector2i(x, y)
					a.offset = Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-20.0, 20.0))
					a.estado = Arvore.Estado.DE_PE
					a.variante = rng.randi() % n_variantes
					arvores.append(a)
			y += passo
		x += passo


func _on_tick() -> void:
	_processar_corte()
	if Sim.fase_dia == Sim.FaseDia.NOITE:
		_processar_regeneracao()


func _n_trabalhadores_lenhador() -> int:
	if not Vila.edificios.has(CENTRO_ID):
		return 0
	var e: Edificio = Vila.edificios[CENTRO_ID]
	if e.nivel <= 0:
		return 0
	var n := 1  # líder
	for v in e.vagas_orfaos:
		if v != null and v != "":
			n += 1
	return n


## O ritmo do corte é só apresentação (mecanicas_para_godot.md #4: "a produção
## acontece por tempo fixo no edifício; o trajeto é apresentação e não influencia
## número nenhum") — não altera a produção real de madeira, calculada pela Economia.
func _processar_corte() -> void:
	var n := _n_trabalhadores_lenhador()
	if n <= 0:
		return
	_corte_acumulado_seg += 1.0
	var cfg: Dictionary = Dados.get_dados("floresta")
	var tempo_corte: float = cfg.get("tempo_corte_seg", 8.0) / float(n)
	if _corte_acumulado_seg < tempo_corte:
		return
	_corte_acumulado_seg = 0.0

	var centro: Vector2i = Vila.edificios[CENTRO_ID].celula
	var alvo: Arvore = null
	var menor_dist := INF
	for a in arvores:
		if a.estado != Arvore.Estado.DE_PE:
			continue
		var d: float = (a.celula - centro).length_squared()
		if d < menor_dist:
			menor_dist = d
			alvo = a
	if alvo != null:
		alvo.estado = Arvore.Estado.TOCO


func _processar_regeneracao() -> void:
	if arvores.is_empty() or not Vila.edificios.has(CENTRO_ID):
		return
	var em_pe := 0
	for a in arvores:
		if a.estado == Arvore.Estado.DE_PE:
			em_pe += 1
	var fracao_de_pe := float(em_pe) / float(arvores.size())
	var cfg: Dictionary = Dados.get_dados("floresta")
	var taxa_base: float = cfg.get("taxa_reposicao_base_por_seg", 0.02)
	var taxa: float = taxa_base * pow(1.0 - fracao_de_pe, 2)
	if randf() >= taxa:
		return

	var centro: Vector2i = Vila.edificios[CENTRO_ID].celula
	var alvo: Arvore = null
	var menor_dist := INF
	for a in arvores:
		if a.estado != Arvore.Estado.TOCO:
			continue
		var d: float = (a.celula - centro).length_squared()
		if d < menor_dist:
			menor_dist = d
			alvo = a
	if alvo != null:
		alvo.estado = Arvore.Estado.DE_PE


func get_save_data() -> Dictionary:
	var lista := []
	for a in arvores:
		lista.append(a.to_dict())
	return { "seed": _seed, "arvores": lista }


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		gerar_se_vazio()
		return
	_seed = salvo.get("seed", 0)
	arvores.clear()
	for d in salvo.get("arvores", []):
		arvores.append(Arvore.from_dict(d))
