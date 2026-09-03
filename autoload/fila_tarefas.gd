extends Node
## TaskQueue. docs/dreadwick_biblia_oficial.md #7.3. HUD mostra 1 tarefa atual + 3
## futuras; a fila inteira aqui pode ter mais — a UI que corta em 4.
##
## Prioridade (da mais urgente pra menos): colapso/necessidade crítica > emergência
## crítica do farol > comando manual > retomada de tarefa pausada > automação > idle.
## "farol_em_emergencia" é um hook para quando o autoload do Farol existir — até lá
## fica sempre false, então essa faixa de prioridade nunca dispara na prática.

signal fila_mudou
signal tarefa_cancelada(tarefa: Tarefa, recursos_perdidos: Dictionary)

var farol_em_emergencia: bool = false  # setado por fora quando o Farol existir

var _fila: Array = []  # Array[Tarefa], sempre mantida ordenada por prioridade


func adicionar(tarefa: Tarefa) -> void:
	_fila.append(tarefa)
	_reordenar()


func atual() -> Tarefa:
	return _fila[0] if not _fila.is_empty() else null


## Até 3 tarefas depois da atual, pra alimentar o HUD (1 atual + 3 futuras, #7.3).
func proximas(n: int = 3) -> Array:
	return _fila.slice(1, 1 + n)


## Interrupção sistêmica (uma necessidade crítica furou a fila, por exemplo): a tarefa
## atual só perde o lugar, progresso preservado — reordena e ela volta a ser pega
## quando a prioridade permitir (#7.3: "interrupção sistêmica pausa e preserva
## progresso").
func reordenar_por_interrupcao() -> void:
	_reordenar()


## Cancelamento manual: pode destruir a tarefa e não devolve os recursos já
## consumidos ao iniciar — quem chama deve ter avisado o jogador antes (#7.3).
func cancelar_atual() -> void:
	if _fila.is_empty():
		return
	var t: Tarefa = _fila.pop_front()
	if not t.can_cancel:
		_fila.push_front(t)
		return
	tarefa_cancelada.emit(t, t.requirements)
	fila_mudou.emit()


## Chamada pelo autoload dono da tarefa (Quint, Farol, Oficina...) quando ela termina
## naturalmente (progress >= 1.0). Não devolve requisitos: eles já foram consumidos.
func concluir_atual() -> void:
	if _fila.is_empty():
		return
	_fila.pop_front()
	fila_mudou.emit()


func _reordenar() -> void:
	_fila.sort_custom(func(a: Tarefa, b: Tarefa): return _prioridade(a) < _prioridade(b))
	fila_mudou.emit()


## Menor valor = mais urgente. Dentro da mesma faixa, mantém a ordem de chegada
## (sort_custom do Godot não é estável entre chamadas, mas como cada tarefa só entra
## na fila uma vez, a ordem relativa dentro da faixa não afeta o resultado prático).
func _prioridade(t: Tarefa) -> int:
	if t.task_type in ["dormir", "comer", "latrina"] and _necessidade_associada_critica(t.task_type):
		return 0
	if t.task_type == "farol_emergencia" and farol_em_emergencia:
		return 1
	if t.source == Tarefa.Fonte.MANUAL:
		return 2
	if t.progress > 0.0 and t.source != Tarefa.Fonte.AUTOMATION:
		return 3  # retomada de tarefa pausada
	if t.source == Tarefa.Fonte.AUTOMATION:
		return 4
	return 5  # idle / sem categoria


func _necessidade_associada_critica(task_type: String) -> bool:
	var alvo := Quint.necessidade_mais_critica()
	if alvo == null:
		return false
	match task_type:
		"dormir":
			return alvo == Quint.Estado.SLEEPING
		"comer":
			return alvo == Quint.Estado.EATING
		"latrina":
			return alvo == Quint.Estado.USING_LATRINE
	return false


func get_save_data() -> Array:
	var out := []
	for t in _fila:
		out.append(t.to_dict())
	return out


func restaurar(salvo: Array) -> void:
	_fila.clear()
	for d in salvo:
		_fila.append(Tarefa.from_dict(d))
	_reordenar()
