class_name Campeonatos
extends RefCounted
## Campeonatos por pontos (decisão 35). Uma série com duas ou mais etapas
## ("<série> — etapa N" em eventos.json) é um campeonato. A temporada pontua
## quando o jogador corre as etapas em ordem; correr outra etapa fora da vez é
## uma corrida comum. Pontos por posição: prêmio da posição ÷ prêmio do 1º × 10,
## arredondado (escala de prêmios da própria série do GT2). Rivais pontuam por
## equipe (escalação da corrida). No fim da última etapa sai a classificação;
## o campeão recebe o bônus da série quando o GT2 tem (bonus_campeonato).
## Estado em jogador.campeonatos: {série: {"etapa": próxima (0..), "pontos": {quem: pts}}};
## títulos em jogador.titulos: {série: quantidade}.

const ESCALA := 10.0


static func serie(ev: Dictionary) -> String:
	return String(ev.get("nome", "")).split(" — ")[0]


## Etapas da série em ordem; vazio se a série tem uma prova só.
static func etapas(dados: Node, nome_serie: String) -> Array:
	var r: Array = dados.lista("eventos").filter(func(e): return _da_serie(e, nome_serie))
	r.sort_custom(func(a, b): return _numero(a) < _numero(b))
	return r if r.size() >= 2 else []


static func _da_serie(ev: Dictionary, nome_serie: String) -> bool:
	return serie(ev) == nome_serie and String(ev["nome"]).contains(" — etapa ")


static func _numero(ev: Dictionary) -> int:
	return int(String(ev["nome"]).get_slice(" — etapa ", 1))


static func pontos(ev: Dictionary, posicao: int) -> int:
	var p: Array = ev.get("premios", [])
	if posicao < 1 or posicao > p.size() or float(p[0]) <= 0.0:
		return 0
	return roundi(float(p[posicao - 1]) / float(p[0]) * ESCALA)


## Estado da temporada da série (sem temporada: etapa 0, sem pontos).
static func estado(jogador: Node, nome_serie: String) -> Dictionary:
	return jogador.campeonatos.get(nome_serie, {"etapa": 0, "pontos": {}})


## Classificação [[quem, pontos], ...] do maior para o menor ("jogador" ou id da equipe).
static func tabela(est: Dictionary) -> Array:
	var t := []
	for k in est.get("pontos", {}):
		t.append([k, int(est["pontos"][k])])
	t.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] == "jogador"))
	return t


## Registra uma corrida. Retorna {} se não conta para a temporada; senão
## {serie, etapa, total, pontos, final, posicao_final, campeao, bonus}.
static func registrar(carreira: Object, evento_id: String, classificacao: Array, semente: int) -> Dictionary:
	var dados: Node = carreira.dados
	var jogador: Node = carreira.jogador
	var ev: Dictionary = dados.evento(evento_id)
	var nome_serie := serie(ev)
	var lista := etapas(dados, nome_serie)
	if lista.is_empty():
		return {}
	var est: Dictionary = estado(jogador, nome_serie).duplicate(true)
	var k := lista.find(ev)
	if k != int(est["etapa"]):
		return {}
	for pos in classificacao.size():
		var id: String = classificacao[pos]
		var quem := "jogador"  # o companheiro pontua para a equipe do jogador
		if id != "jogador" and id != EquipeJogador.ID:
			var eq: Dictionary = carreira.equipe_de(evento_id, id, semente)
			quem = String(eq.get("id", id.split("_", true, 1)[1]))
		est["pontos"][quem] = int(est["pontos"].get(quem, 0)) + pontos(ev, pos + 1)
	est["etapa"] = k + 1
	var r := {"serie": nome_serie, "etapa": k + 1, "total": lista.size(),
			"pontos": pontos(ev, classificacao.find("jogador") + 1) + pontos(ev, classificacao.find(EquipeJogador.ID) + 1),
			"final": false}
	if k + 1 < lista.size():
		jogador.campeonatos[nome_serie] = est
		return r
	# Última etapa: classificação final, título e bônus; a temporada recomeça.
	var t := tabela(est)
	var pos_final := 1 + t.map(func(x): return x[0]).find("jogador")
	r["final"] = true
	r["posicao_final"] = pos_final
	r["classificacao_final"] = t
	r["campeao"] = pos_final == 1
	r["bonus"] = 0
	if pos_final == 1:
		jogador.titulos[nome_serie] = int(jogador.titulos.get(nome_serie, 0)) + 1
		for e in lista:
			r["bonus"] = maxi(int(r["bonus"]), int(e.get("bonus_campeonato", 0)))
		jogador.economia.creditar(int(r["bonus"]))
	jogador.campeonatos.erase(nome_serie)
	return r
