extends Node
## TimeSystem (docs/dreadwick_biblia_oficial.md #22 — primeiro da ordem de arquitetura).
## Um Timer de 1s dispara tudo; nenhuma lógica de jogo em _process. #7.1: um dia dura
## 8 min reais (480s), em quatro fases. #7.2: agenda semanal de visitantes.

enum Fase { DIA_PLENO, ENTARDECER, NOITE_PLENA, AMANHECER }

const DIAS_SEMANA := ["segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo"]

signal fase_mudou(nova_fase: Fase)
signal dia_mudou(novo_dia: int)
signal offline_delta_calculado(delta_seg: int)
signal tick  ## emitido a cada 1s, depois do relógio já atualizado.

var tempo_jogo_seg: int = 0
var tempo_unix_ultimo: int = 0
var max_time_seen: int = 0
var dia_geral: int = 1  # 1, 2, 3... desde o início do save; dia 1 começa numa segunda.
var fase_atual: Fase = Fase.DIA_PLENO

var _dia_seg: int = 480
var _fases: Array = []  # [{nome, duracao_seg}], soma == _dia_seg
var _capacidade_offline_seg: int = 7200
var _teto_dias_offline: int = 3  # sem simulação retroativa: 3 dias reais é folga generosa
                                   # sobre o teto tardio de 24h (biblia #7.4) sem risco de
                                   # travar num open-after-months — não é número da bíblia.

var _tick_timer: Timer


func _ready() -> void:
	_carregar_tempo()
	_aplicar_save_ou_iniciar()
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func _carregar_tempo() -> void:
	var cfg := Dados.tempo()
	_dia_seg = cfg.get("dia_seg", _dia_seg)
	_fases = cfg.get("fases", _fases)
	var offline: Dictionary = cfg.get("offline", {})
	_capacidade_offline_seg = offline.get("capacidade_inicial_seg", _capacidade_offline_seg)


func _aplicar_save_ou_iniciar() -> void:
	var save := SaveManager.load_game()
	var agora := int(Time.get_unix_time_from_system())
	if save.is_empty():
		tempo_jogo_seg = 0
		tempo_unix_ultimo = agora
		max_time_seen = agora
		dia_geral = 1
		fase_atual = Fase.DIA_PLENO
		return

	tempo_jogo_seg = save.get("tempo_jogo_seg", 0)
	tempo_unix_ultimo = save.get("tempo_unix_ultimo", agora)
	max_time_seen = save.get("max_time_seen", agora)
	dia_geral = save.get("dia_geral", 1)
	fase_atual = save.get("fase_atual", Fase.DIA_PLENO) as Fase
	Quint.restaurar(save.get("quint", {}))
	Economia.restaurar(save.get("economia", {}))
	FilaTarefas.restaurar(save.get("tarefas", []))

	_calcular_offline(agora)


func dia_semana() -> String:
	return DIAS_SEMANA[(dia_geral - 1) % 7]


func visitante_de_hoje() -> Variant:
	var agenda: Dictionary = Dados.tempo().get("agenda_visitantes", {})
	return agenda.get(dia_semana(), null)


## docs/dreadwick_biblia_oficial.md #7.4: fórmula fechada / simulação econômica resumida,
## nunca literal (cada caminhada, refeição, uso de latrina). Aqui só calculamos e
## anunciamos o delta credível; a resolução econômica fica a cargo de cada sistema
## (Economia, Pesca, Farol...) que escutar este sinal — nenhum ainda existe, então por
## enquanto isso só define o relógio corretamente ao reabrir.
func _calcular_offline(agora: int) -> void:
	if agora < max_time_seen:
		# Relógio do sistema voltou/foi manipulado: não credita nada.
		tempo_unix_ultimo = max_time_seen
		return

	max_time_seen = agora
	var bruto := agora - tempo_unix_ultimo
	if bruto > _teto_dias_offline * 86400:
		bruto = _teto_dias_offline * 86400

	var delta: int = clampi(bruto, 0, _capacidade_offline_seg)
	tempo_unix_ultimo = agora
	if delta > 0:
		offline_delta_calculado.emit(delta)


func _on_tick() -> void:
	tempo_jogo_seg += 1
	tempo_unix_ultimo = int(Time.get_unix_time_from_system())

	var fase_anterior := fase_atual
	var t := tempo_jogo_seg % _dia_seg
	var acumulado := 0
	for i in range(_fases.size()):
		var duracao: int = _fases[i]["duracao_seg"]
		if t < acumulado + duracao:
			fase_atual = i as Fase
			break
		acumulado += duracao

	if fase_atual != fase_anterior:
		fase_mudou.emit(fase_atual)

	if t == 0 and tempo_jogo_seg > 0:
		dia_geral += 1
		dia_mudou.emit(dia_geral)
		SaveManager.request_save(get_save_data())

	tick.emit()


func nome_fase(f: Fase) -> String:
	return _fases[f]["nome"] if f < _fases.size() else "?"


## Ponto único de agregação do save — cada autoload de sistema entra aqui conforme
## passa a existir (mesmo padrão do módulo de fundação do projeto anterior deste
## repositório: um Sim/TimeSystem central, nunca save espalhado por save() soltos).
func get_save_data() -> Dictionary:
	return {
		"tempo_jogo_seg": tempo_jogo_seg,
		"tempo_unix_ultimo": tempo_unix_ultimo,
		"max_time_seen": max_time_seen,
		"dia_geral": dia_geral,
		"fase_atual": fase_atual,
		"quint": Quint.get_save_data(),
		"economia": Economia.get_save_data(),
		"tarefas": FilaTarefas.get_save_data(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.force_save(get_save_data())
