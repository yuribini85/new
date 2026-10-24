class_name MetaDia
extends RefCounted
## Meta do dia (decisão 109): a cada dia (meia-noite do aparelho) saem
## `por_dia` tarefas de carreira.json → meta_dia.tarefas, sorteadas pela data
## entre as que o jogador pode fazer (arena aberta, patrocínio aberto). Cada uma
## conta um tipo de ação (corridas, vitórias, pódios, lutas da arena, peças,
## contratos) e, cumprida, paga `recompensa_premios` × o prêmio de referência
## da maior licença do jogador (média do 1º lugar das provas dela) ao coletar.
## Estado em jogador.meta_dia: {dia, tarefas: [ids], contagem: {tipo: n},
## coletadas: [ids]}.

static func config(dados: Node) -> Dictionary:
	return dados.carreira().get("meta_dia", {})


## Data local do aparelho ("2026-10-17").
static func dia(agora: float) -> String:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	return Time.get_date_string_from_unix_time(int(agora + bias))


## O estado do dia (novo dia: tarefas sorteadas, contagem zerada).
static func estado(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> Dictionary:
	var d := dia(agora)
	if String(jogador.meta_dia.get("dia", "")) != d:
		jogador.meta_dia = {"dia": d, "contagem": {}, "coletadas": []}
	if not jogador.meta_dia.has("tarefas"):
		jogador.meta_dia["tarefas"] = _sortear(dados, jogador, d)
	return jogador.meta_dia


static func _sortear(dados: Node, jogador: Node, d: String) -> Array:
	var pool: Array = config(dados).get("tarefas", []).filter(func(t): return _disponivel(dados, jogador, t))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("meta_dia|" + d)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = pool[i]
		pool[i] = pool[j]
		pool[j] = x
	return pool.slice(0, int(config(dados).get("por_dia", 3))).map(func(t): return String(t["id"]))


static func _disponivel(dados: Node, jogador: Node, t: Dictionary) -> bool:
	match String(t.get("tipo", "")):
		"arena":
			return jogador.flags.has(EquipeJogador.FLAG_ARENA)
		"patrocinio":
			return GestaoEquipe.patrocinio_aberto(dados, jogador)
	return true


static func tarefa(dados: Node, id: String) -> Dictionary:
	for t in config(dados).get("tarefas", []):
		if String(t["id"]) == id:
			return t
	return {}


## Conta uma ação do tipo (as de outro dia zeram antes).
static func registrar(jogador: Node, tipo: String, n := 1, agora: float = Time.get_unix_time_from_system()) -> void:
	var d := dia(agora)
	if String(jogador.meta_dia.get("dia", "")) != d:
		jogador.meta_dia = {"dia": d, "contagem": {}, "coletadas": []}
	var c: Dictionary = jogador.meta_dia["contagem"]
	c[tipo] = int(c.get(tipo, 0)) + n


## [feito, meta] da tarefa no dia.
static func progresso(dados: Node, jogador: Node, id: String, agora: float = Time.get_unix_time_from_system()) -> Array:
	var t := tarefa(dados, id)
	var est := estado(dados, jogador, agora)
	var meta := int(t.get("quantidade", 1))
	return [mini(int(est["contagem"].get(String(t.get("tipo", "")), 0)), meta), meta]


static func recompensa(dados: Node, jogador: Node) -> int:
	var niveis := GestaoEquipe.ordem(dados)
	var k := maxi(GestaoEquipe.maior_licenca(dados, jogador), 0)
	var ref := GestaoEquipe.premio_referencia(dados, niveis[k]) if not niveis.is_empty() else 0
	return roundi(ref * float(config(dados).get("recompensa_premios", 0)))


## Coleta a recompensa da tarefa cumprida; devolve o valor (0: não deu).
static func coletar(dados: Node, jogador: Node, id: String, agora: float = Time.get_unix_time_from_system()) -> int:
	var est := estado(dados, jogador, agora)
	if not id in est["tarefas"] or id in est["coletadas"]:
		return 0
	var p := progresso(dados, jogador, id, agora)
	if p[0] < p[1]:
		return 0
	var v := recompensa(dados, jogador)
	est["coletadas"].append(id)
	jogador.economia.creditar(v)
	return v
