extends Node
## Autoload único de simulação. docs/mecanicas_para_godot.md#0-fundacao.
## Um Timer de 1s dispara tudo; nenhuma lógica de jogo em _process.

enum FaseDia { MANHA, TARDE, NOITE }
const NOMES_FASE := ["MANHA", "TARDE", "NOITE"]

signal fase_mudou(nova_fase: FaseDia)
signal dia_mudou(novo_dia: int)
signal offline_delta_calculado(delta_seg: int)
signal tick  ## emitido a cada 1s, depois do relógio já atualizado — outros módulos penduram lógica aqui, nunca em _process.

var tempo_jogo_seg: int = 0
var tempo_unix_ultimo: int = 0
var max_time_seen: int = 0
var dia_vila: int = 1
var fase_dia: FaseDia = FaseDia.MANHA
var ato: int = 1

## Nível da Casa das Fiandeiras (0 = não construída). Atualizado pelo módulo de Economia;
## enquanto não existir, o teto de offline é 0h, como manda a especificação.
var nivel_casa_fiandeiras: int = 0

var _ciclo: Dictionary = {}
var _dia_seg: int = 1200
var _noite_seg: int = 240
var _teto_offline_horas := [0, 2, 4, 6, 9, 12, 16, 20, 24]
var _fator_noite := 0.8
var _fator_consumo := 0.85
var _teto_dias := 30

var _tick_timer: Timer


func _ready() -> void:
	_carregar_ciclo()
	_aplicar_save_ou_iniciar()
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func _carregar_ciclo() -> void:
	_ciclo = Dados.ciclo()
	_dia_seg = _ciclo.get("dia_seg", _dia_seg)
	_noite_seg = _ciclo.get("noite_seg", _noite_seg)
	var offline: Dictionary = _ciclo.get("offline", {})
	_fator_noite = offline.get("fator_noite", _fator_noite)
	_fator_consumo = offline.get("fator_consumo", _fator_consumo)
	_teto_dias = offline.get("teto_dias", _teto_dias)
	var tetos = offline.get("teto_horas_por_nivel_fiandeiras", null)
	if tetos != null:
		_teto_offline_horas = tetos


func _aplicar_save_ou_iniciar() -> void:
	var save := SaveManager.load_game()
	var agora := int(Time.get_unix_time_from_system())
	if save.is_empty():
		tempo_jogo_seg = 0
		tempo_unix_ultimo = agora
		max_time_seen = agora
		dia_vila = 1
		fase_dia = FaseDia.MANHA
		ato = 1
		return

	tempo_jogo_seg = save.get("tempo_jogo_seg", 0)
	tempo_unix_ultimo = save.get("tempo_unix_ultimo", agora)
	max_time_seen = save.get("max_time_seen", agora)
	dia_vila = save.get("dia_vila", 1)
	fase_dia = save.get("fase_dia", FaseDia.MANHA) as FaseDia
	ato = save.get("ato", 1)
	nivel_casa_fiandeiras = save.get("nivel_casa_fiandeiras", 0)
	Vila.restaurar(save.get("edificios", []))
	Populacao.restaurar(save.get("populacao", {}))
	Economia.restaurar(save.get("economia", {}))

	_calcular_offline(agora)


func nome_fase(f: FaseDia) -> String:
	return NOMES_FASE[f]


## especificacao_tecnica_v1.md #16-17 e #22 · mecanicas_para_godot.md#0-fundacao.
## Fórmula fechada, nunca simulação retroativa; protegida contra relógio adiantado.
func _calcular_offline(agora: int) -> void:
	if agora < max_time_seen:
		# Relógio do sistema voltou/foi manipulado: não credita nada.
		tempo_unix_ultimo = max_time_seen
		return

	max_time_seen = agora
	var bruto := agora - tempo_unix_ultimo
	if bruto > _teto_dias * 86400:
		bruto = _teto_dias * 86400

	var teto_seg := 0
	if nivel_casa_fiandeiras > 0 and nivel_casa_fiandeiras < _teto_offline_horas.size():
		teto_seg = int(_teto_offline_horas[nivel_casa_fiandeiras] * 3600)
	elif nivel_casa_fiandeiras >= _teto_offline_horas.size():
		teto_seg = int(_teto_offline_horas[-1] * 3600)

	var delta: int = clampi(bruto, 0, teto_seg)
	tempo_unix_ultimo = agora
	if delta > 0:
		# Produção e consumo em si ficam a cargo do módulo de Economia (ainda não existe);
		# aqui só calculamos e anunciamos o delta credível, com os fatores de #16 aplicados.
		offline_delta_calculado.emit(delta)


func _on_tick() -> void:
	tempo_jogo_seg += 1
	tempo_unix_ultimo = int(Time.get_unix_time_from_system())

	var fase_anterior := fase_dia
	var t := tempo_jogo_seg % _dia_seg
	var dia_claro := _dia_seg - _noite_seg
	if t < dia_claro / 2:
		fase_dia = FaseDia.MANHA
	elif t < dia_claro:
		fase_dia = FaseDia.TARDE
	else:
		fase_dia = FaseDia.NOITE

	if fase_dia != fase_anterior:
		fase_mudou.emit(fase_dia)

	if t == 0 and tempo_jogo_seg > 0:
		dia_vila += 1
		dia_mudou.emit(dia_vila)
		SaveManager.request_save(get_save_data())

	tick.emit()


func get_save_data() -> Dictionary:
	return {
		"tempo_jogo_seg": tempo_jogo_seg,
		"tempo_unix_ultimo": tempo_unix_ultimo,
		"max_time_seen": max_time_seen,
		"dia_vila": dia_vila,
		"fase_dia": fase_dia,
		"ato": ato,
		"nivel_casa_fiandeiras": nivel_casa_fiandeiras,
		"edificios": Vila.get_save_data(),
		"populacao": Populacao.get_save_data(),
		"economia": Economia.get_save_data(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.force_save(get_save_data())
