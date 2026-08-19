extends Node
## Módulo 3 — Mapa. Dono do estado dos edifícios da vila. docs/mecanicas_para_godot.md
## #2 (edifícios) e #3 (mapa): lotes fixos, ruínas, construção.
## Cada Edificio é um objeto de dado — nunca uma cena por construção (CLAUDE.md).

signal edificio_iniciou_obra(id: String)
signal edificio_construido(id: String)

var edificios: Dictionary = {}   # id:String -> Edificio


func _ready() -> void:
	_montar_a_partir_do_catalogo()
	Sim.tick.connect(_on_tick)


func _montar_a_partir_do_catalogo() -> void:
	var catalogo := Dados.catalogo_edificios_ato1()
	for id in catalogo:
		edificios[id] = Edificio.from_definicao(catalogo[id])


## Chamado pelo Sim, uma vez, depois de carregar o save.
func restaurar(salvo: Array) -> void:
	for entrada in salvo:
		var id: String = entrada.get("id", "")
		if edificios.has(id):
			edificios[id].aplicar_estado_salvo(entrada)


func get_save_data() -> Array:
	var out := []
	for id in edificios:
		out.append(edificios[id].to_dict())
	return out


signal construcao_recusada(id: String, motivo: String)


## Custo em ouro (+ madeira, 40% do ouro, regra #24) do PRÓXIMO nível deste edifício.
func custo_proximo_nivel(id: String) -> Dictionary:
	var e: Edificio = edificios.get(id)
	if e == null:
		return {}
	var cfg := Dados.economia()
	var curva: float = cfg.get("curva_custo", 1.35)
	var madeira_pct: float = cfg.get("madeira_pct_do_ouro", 0.4)
	var ouro := e.custo_para_nivel(e.nivel + 1, curva)
	return { "ouro": ouro, "madeira": int(round(ouro * madeira_pct)) }


## Inicia a obra para o PRÓXIMO nível (ruína→1, ou nível N→N+1 num prédio já
## construído). Cobra ouro + madeira na hora de começar a obra, não na conclusão —
## padrão comum em city-builder/idle, evita o custo mudar no meio da obra.
func construir(id: String) -> bool:
	if not edificios.has(id):
		return false
	var e: Edificio = edificios[id]
	if e.em_obra:
		construcao_recusada.emit(id, "em_obra")
		return false

	var custo := custo_proximo_nivel(id)
	if not Economia.tem_saldo("ouro", custo["ouro"]) or not Economia.tem_saldo("madeira", custo["madeira"]):
		construcao_recusada.emit(id, "sem_recursos")
		return false

	Economia.debitar("ouro", custo["ouro"])
	Economia.debitar("madeira", custo["madeira"])

	var obra: Dictionary = Dados.economia().get("obra", {})
	var base_seg: float = obra.get("base_seg", 30.0)
	var mult: float = obra.get("multiplicador_por_nivel", 1.6)
	var reducao_por_construtor: float = obra.get("reducao_por_construtor", 0.15)
	# mecanicas_para_godot.md #2: tempo(n) = base_seg * multiplicador^(n-1).
	var tempo := base_seg * pow(mult, e.nivel + 1 - 1)
	var n_construtores: int = edificios["cabana_do_construtor"].n_trabalhadores() if edificios.has("cabana_do_construtor") else 0
	tempo *= clampf(1.0 - reducao_por_construtor * n_construtores, 0.2, 1.0)

	e.em_obra = true
	e.obra_termina_em = int(Time.get_unix_time_from_system() + tempo)
	edificio_iniciou_obra.emit(id)
	SaveManager.request_save(Sim.get_save_data())
	return true


func _on_tick() -> void:
	var agora := int(Time.get_unix_time_from_system())
	for id in edificios:
		var e: Edificio = edificios[id]
		if e.em_obra and agora >= e.obra_termina_em:
			e.em_obra = false
			e.subir_nivel()
			edificio_construido.emit(id)
			SaveManager.request_save(Sim.get_save_data())
