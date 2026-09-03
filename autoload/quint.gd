extends Node
## FSM central de Quint. docs/dreadwick_biblia_oficial.md #17.1 (estados) e #6.1
## (necessidades). "Implementar como FSM central. Evitar booleans dispersos que
## permitam estados incompatíveis simultâneos" — todo o estado de Quint vive aqui,
## num enum único, nunca em flags soltas por outros autoloads/cenas.

enum Estado {
	IDLE, WALKING, WORKING, FISHING, ENTERING_BUILDING, EXITING_BUILDING, SLEEPING,
	EATING, USING_LATRINE, TALKING, UPGRADING, MAINTAINING, CARRYING_FUEL, COLLAPSED,
	RECOVERING,
}

signal estado_mudou(novo_estado: Estado)
signal necessidade_critica(estado_alvo: Estado)  ## emitido uma vez quando uma necessidade
                                                   ## bate 100% e ainda não está sendo tratada.

var estado: Estado = Estado.IDLE
var energia: float = 0.0  # 0% resolvido -> 100% emergência (#6.1)
var fome: float = 0.0
var latrina: float = 0.0

var _cfg: Dictionary = {}
var _avisado_critico: Dictionary = {}  # Estado -> bool, evita repetir o sinal a cada tick


func _ready() -> void:
	_cfg = Dados.necessidades()
	Tempo.tick.connect(_on_tick)


func mudar_estado(novo: Estado) -> void:
	if novo == estado:
		return
	estado = novo
	if novo in [Estado.USING_LATRINE, Estado.SLEEPING, Estado.EATING]:
		_avisado_critico[novo] = false
	estado_mudou.emit(novo)


func _on_tick() -> void:
	_processar_energia()
	_processar_fome()
	_processar_latrina()
	_checar_criticas()


func _processar_energia() -> void:
	if estado == Estado.SLEEPING:
		energia = maxf(0.0, energia - _cfg["energia"]["recuperacao_dormindo_pontos_por_seg"])
		return
	var ganho: float = _cfg["energia"]["ganho_idle_pontos_por_seg"]
	if estado == Estado.FISHING:
		ganho = _cfg["energia"]["ganho_pesca_pontos_por_seg"]
	elif estado in [Estado.MAINTAINING, Estado.UPGRADING]:
		ganho = _cfg["energia"]["ganho_trabalho_pesado_pontos_por_seg"]
	energia = clampf(energia + ganho, 0.0, 100.0)


## Fome "cresce com o tempo e rotina" (#6.1) — ao contrário de energia, não pausa fora
## do estado EATING; só a recuperação depende do estado.
func _processar_fome() -> void:
	if estado == Estado.EATING:
		fome = maxf(0.0, fome - _cfg["fome"]["recuperacao_comendo_pontos_por_seg"])
		return
	fome = clampf(fome + _cfg["fome"]["ganho_pontos_por_seg"], 0.0, 100.0)


## Latrina "cresce até 100%" (#6.1); a bíblia não dá taxa de recuperação contínua como
## para energia/fome — usar a latrina é resolvida como conclusão de tarefa (zera ao
## terminar), não como regen por segundo. Ver TaskQueue quando a tarefa existir.
func _processar_latrina() -> void:
	if estado == Estado.USING_LATRINE:
		return
	latrina = clampf(latrina + _cfg["latrina"]["ganho_pontos_por_seg"], 0.0, 100.0)


func resolver_latrina() -> void:
	latrina = 0.0


## #6.1: "Em 100%, Quint termina a animação atual de encerramento e abandona
## temporariamente a tarefa." Aqui só detectamos e avisamos (uma vez por necessidade
## crítica) — quem decide interromper a tarefa atual é o dono da tarefa em execução (a
## FilaTarefas por si só não sabe qual animação está tocando nem quando ela termina);
## até essa integração existir, isso só alimenta HUD/debug e a priorização da fila.
func _checar_criticas() -> void:
	for par in [[Estado.USING_LATRINE, latrina], [Estado.SLEEPING, energia], [Estado.EATING, fome]]:
		var alvo: Estado = par[0]
		var valor: float = par[1]
		if valor >= 100.0 and not _avisado_critico.get(alvo, false):
			_avisado_critico[alvo] = true
			necessidade_critica.emit(alvo)


## Necessidade de maior prioridade entre as que estão em 100%, respeitando o
## desempate Latrina > Energia > Fome (#6.1). null se nenhuma estiver crítica.
func necessidade_mais_critica() -> Variant:
	if latrina >= 100.0:
		return Estado.USING_LATRINE
	if energia >= 100.0:
		return Estado.SLEEPING
	if fome >= 100.0:
		return Estado.EATING
	return null


func get_save_data() -> Dictionary:
	return {
		"estado": estado,
		"energia": energia,
		"fome": fome,
		"latrina": latrina,
	}


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		return
	estado = salvo.get("estado", Estado.IDLE) as Estado
	energia = salvo.get("energia", 0.0)
	fome = salvo.get("fome", 0.0)
	latrina = salvo.get("latrina", 0.0)
