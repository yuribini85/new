extends Node
## Módulo 7 — Expedição. docs/mecanicas_para_godot.md #6, modelo Melvor. Uma
## expedição por vez, corre por timestamp (funciona com o app fechado).
##
## Fora do escopo por enquanto, documentado em vez de estimado:
## - Mochilas (GLoot/grid, peso por peça): não há definição de itens em nenhum
##   dado do projeto ainda, então não há o que pesar.
## - As 12 falas por região na voz da Maria: texto narrativo que não está em
##   nenhum documento lido — o relatório usa só a linha fixa de dados.
## - Botão de anúncio para recuperar 1 morto: CLAUDE.md exclui monetização do
##   primeiro build.
## - Só a região tier 0 (Orla da mata) é alcançável sem a mina (módulo 8).

signal expedicao_iniciada(regiao_id: String)
signal expedicao_concluida(relatorio: Dictionary)

var atual: Expedicao = null
var ultimo_relatorio: Dictionary = {}


func _ready() -> void:
	Sim.tick.connect(_on_tick)


func regioes() -> Array:
	return Dados.get_dados("expedicoes").get("regioes", [])


func regiao(id: String) -> Dictionary:
	for r in regioes():
		if r["id"] == id:
			return r
	return {}


func tier_maximo_liberado() -> int:
	return 0  # sem mina ainda; só regiões tier 0


func pode_iniciar(regiao_id: String, equipe: Array) -> bool:
	if atual != null:
		return false
	var r := regiao(regiao_id)
	if r.is_empty() or int(r["tier"]) > tier_maximo_liberado():
		return false
	if equipe.size() != int(r["aldeoes"]):
		return false
	for id in equipe:
		if not Populacao.orfaos.has(id) or Populacao.orfaos[id].estado != Orfao.Estado.ADULTO_OCIOSO:
			return false
	return true


func iniciar(regiao_id: String, equipe: Array) -> bool:
	if not pode_iniciar(regiao_id, equipe):
		return false
	var r := regiao(regiao_id)

	var e := Expedicao.new()
	e.regiao_id = regiao_id
	e.equipe = equipe.duplicate()
	e.inicio_unix = int(Time.get_unix_time_from_system())
	e.duracao_seg = int(r["duracao_seg"])
	e.estado = Expedicao.Estado.EM_CURSO
	atual = e

	for id in equipe:
		Populacao.orfaos[id].estado = Orfao.Estado.EM_EXPEDICAO

	expedicao_iniciada.emit(regiao_id)
	SaveManager.request_save(Sim.get_save_data())
	return true


func _on_tick() -> void:
	_verificar_conclusao()


func _verificar_conclusao() -> void:
	if atual == null or atual.estado != Expedicao.Estado.EM_CURSO:
		return
	var agora := int(Time.get_unix_time_from_system())
	if agora - atual.inicio_unix < atual.duracao_seg:
		return
	_resolver(atual)


## mecanicas_para_godot.md #6: risco por indivíduo, ponderado por cicatriz; nunca
## mais da metade da equipe morre; nunca o primeiro da lista; "imortais" nomeados
## (Maria, Pele-de-Urso) não existem como Orfao neste modelo — a checagem por id
## nunca combina com nada ainda, sem efeito prático, mas pronta para quando existirem.
func _resolver(exp: Expedicao) -> void:
	var r := regiao(exp.regiao_id)
	var travas: Dictionary = Dados.get_dados("expedicoes").get("travas", {})
	var imortais: Array = travas.get("imortais", [])
	var max_fracao: float = travas.get("max_mortes_fracao", 0.5)
	var nunca_primeiro: bool = travas.get("nunca_primeiro", true)
	var risco_base: float = r.get("risco", 0.0)

	var protetor_presente := false
	for id in exp.equipe:
		if Populacao.orfaos.has(id) and Populacao.orfaos[id].cicatriz_id == "nao_deixa_ninguem_para_tras":
			protetor_presente = true
			break

	var mortos: Array = []
	var max_mortes := int(floor(exp.equipe.size() * max_fracao))

	for i in range(exp.equipe.size()):
		if mortos.size() >= max_mortes:
			break
		var id: String = exp.equipe[i]
		if id in imortais or (i == 0 and nunca_primeiro):
			continue

		var risco := risco_base
		var o: Orfao = Populacao.orfaos.get(id)
		if o != null:
			if o.cicatriz_id == "ossos_frageis":
				risco *= 2.0
			elif o.cicatriz_id == "passos_leves":
				risco *= 0.6
			if protetor_presente and o.cicatriz_id != "nao_deixa_ninguem_para_tras":
				risco *= 0.3  # -70% de risco para os outros

		if randf() < clampf(risco, 0.0, 1.0):
			mortos.append(id)

	for id in exp.equipe:
		if not Populacao.orfaos.has(id):
			continue
		Populacao.orfaos[id].estado = Orfao.Estado.MORTO if id in mortos else Orfao.Estado.ADULTO_OCIOSO

	Economia.creditar("folego", float(r.get("folego", 0)))

	exp.estado = Expedicao.Estado.CONCLUIDA
	ultimo_relatorio = {
		"regiao_id": exp.regiao_id,
		"regiao_nome": r.get("nome", exp.regiao_id),
		"equipe": exp.equipe,
		"mortos": mortos,
		"folego_ganho": r.get("folego", 0),
		"duracao_seg": exp.duracao_seg,
	}
	atual = null
	expedicao_concluida.emit(ultimo_relatorio)
	SaveManager.request_save(Sim.get_save_data())


func get_save_data() -> Dictionary:
	return {
		"atual": atual.to_dict() if atual != null else {},
		"ultimo_relatorio": ultimo_relatorio,
	}


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		return
	var a: Dictionary = salvo.get("atual", {})
	if not a.is_empty():
		atual = Expedicao.from_dict(a)
		_verificar_conclusao()  # já pode ter passado do tempo enquanto o app estava fechado
	ultimo_relatorio = salvo.get("ultimo_relatorio", {})
