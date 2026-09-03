class_name Tarefa
extends RefCounted
## Estrutura de tarefa. docs/dreadwick_biblia_oficial.md #17.2.

enum Fonte { MANUAL, AUTOMATION, SYSTEM }

var task_id: String
var task_type: String
var target: String  # id do alvo (edificação, hotspot, NPC...), depende do task_type
var progress: float = 0.0  # 0.0 a 1.0
var duration: float = 0.0  # segundos
var can_pause: bool = true
var can_cancel: bool = true
var source: Fonte = Fonte.MANUAL
var resume_after_interrupt: bool = true
var requirements: Dictionary = {}  # recurso -> quantidade já consumida ao iniciar


func concluida() -> bool:
	return progress >= 1.0


func to_dict() -> Dictionary:
	return {
		"task_id": task_id,
		"task_type": task_type,
		"target": target,
		"progress": progress,
		"duration": duration,
		"can_pause": can_pause,
		"can_cancel": can_cancel,
		"source": source,
		"resume_after_interrupt": resume_after_interrupt,
		"requirements": requirements,
	}


static func from_dict(d: Dictionary) -> Tarefa:
	var t := Tarefa.new()
	t.task_id = d.get("task_id", "")
	t.task_type = d.get("task_type", "")
	t.target = d.get("target", "")
	t.progress = d.get("progress", 0.0)
	t.duration = d.get("duration", 0.0)
	t.can_pause = d.get("can_pause", true)
	t.can_cancel = d.get("can_cancel", true)
	t.source = d.get("source", Fonte.MANUAL) as Fonte
	t.resume_after_interrupt = d.get("resume_after_interrupt", true)
	t.requirements = d.get("requirements", {})
	return t
