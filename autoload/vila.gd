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


## Inicia a obra de uma ruína para nível 1. O custo em ouro é checado pelo módulo de
## Economia (ainda não existe) — aqui só a máquina de estado obra/nível, por timestamp,
## igual ao resto do jogo (nunca por tick acumulado).
func construir(id: String) -> bool:
	if not edificios.has(id):
		return false
	var e: Edificio = edificios[id]
	if e.em_obra or e.nivel != Edificio.NIVEL_RUINA:
		return false

	var obra: Dictionary = Dados.economia().get("obra", {})
	var base_seg: float = obra.get("base_seg", 30.0)
	# mecanicas_para_godot.md #2: tempo(n) = base_seg * multiplicador^(n-1); indo pra
	# nível 1, expoente é 0, então tempo = base_seg.
	e.em_obra = true
	e.obra_termina_em = int(Time.get_unix_time_from_system() + base_seg)
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
