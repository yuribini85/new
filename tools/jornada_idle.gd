extends SceneTree
## The Fastfather: um jogador passa pelo jogo inteiro e anota quando cada coisa
## acontece (conversas e cenas da escada de desbloqueios, ligas vencidas,
## troféus, categorias e a Rinha abrindo, carros, cidades). Mesmo jogador da
## calibração (tools/calibrar_idle.gd): abre o app `sessoes_dia` vezes por dia
## por `sessao_min` minutos, corre na categoria aberta mais nova com liga por
## vencer, compra a melhoria aberta mais barata, usa o capanga grátis, funde e
## escala o melhor; mas aqui a escada de desbloqueios segue a ordem do jogo (uma
## conversa por vez, quando a condição dela se cumpre; ofertas pagas compradas
## quando o caixa dá).
## Uso: godot --headless --path . -s tools/jornada_idle.gd [-- sessoes_dia=4 sessao_min=8
##        primeira_min=15 limite_dias=45 cidades=2 saida=user://jornada.tsv]

var e: IdleEstado
var d: Node
var esperando_carro := ""
var relogio := 0.0  # calendário (s)
var ativo := 0.0  # app aberto (s)
var linhas: Array = []


func _initialize() -> void:
	_rodar.call_deferred()


func _ev(tipo: String, texto: String) -> void:
	var l := "%6.2f\t%6.1f\t%5d\t%s\t%s\t%s\t%s" % [relogio / 86400.0, ativo / 60.0, e.corridas, IdleUI.curto(e.dinheiro),
			IdleUI.curto(e.renda_s()), tipo, texto]
	linhas.append(l)
	print(l)


## A escada: mostra (e aceita) toda conversa que já pode aparecer; compra as
## ofertas pagas quando o caixa dá.
func _escada() -> void:
	var c := e.proxima_conversa()
	while not c.is_empty():
		var id := String(c["id"])
		e.oferecer(id)
		var extra := ""
		if c.has("cena"):
			extra += " [cena %s]" % c["cena"]
		if c.has("capitulo"):
			extra += " [capítulo %s]" % c["capitulo"]
		if float(c.get("custo", 0.0)) > 0.0:
			extra += " [oferta $%s]" % IdleUI.curto(float(c["custo"]))
		var quem := String(c.get("quem", {}).get("nome", "?"))
		_ev("conversa", "%s (%s): %s → libera %s%s" % [id, quem, String(c.get("fala", "")).left(60), str(c.get("libera", [])),
				extra])
		c = e.proxima_conversa()
	for o in e.ofertas_abertas():
		if e.comprar_desbloqueio(String(o["id"])):
			_ev("compra", "oferta %s por $%s" % [o["id"], IdleUI.curto(float(o["custo"]))])


func _comprar_tudo() -> void:
	if esperando_carro != "":
		var c := e.carro_da_modalidade(esperando_carro)
		if e.comprar_carro(String(c["id"])):
			_ev("carro", "comprou %s para %s" % [c["id"], esperando_carro])
			esperando_carro = ""
			_escolher_modalidade()
		return
	while true:
		var mais_barata := ""
		for m in e.cfg["melhorias"]:
			if not e.tem("melhoria:" + String(m["id"])) or e.no_maximo(m["id"]):
				continue
			if mais_barata == "" or e.custo(m["id"]) < e.custo(mais_barata):
				mais_barata = m["id"]
		if mais_barata == "" or not e.comprar(mais_barata):
			break


func _escolher_modalidade() -> void:
	var alvo := ""
	for id in e.liberadas():
		if e.e_arena(id):
			continue
		var m := e._m(id)
		var fim: bool = int(m["liga"]) >= e.dados_modalidade(id)["ligas"].size() - 1 and bool(m["venceu"])
		if not fim:
			alvo = id
	if alvo != "" and alvo != e.modalidade:
		var c := e.carro_da_modalidade(alvo)
		if not c.is_empty() and not e.tem_carro(String(c["id"])):
			if not e.comprar_carro(String(c["id"])):
				esperando_carro = alvo
				return
			_ev("carro", "comprou %s para %s" % [c["id"], alvo])
		esperando_carro = ""
		e.trocar_modalidade(alvo)
		_ev("categoria", "passa a correr em %s" % e.dados_modalidade(alvo)["nome"])


func _pilotos(agora: float, dia: String) -> void:
	if not e.tem("aba:pilotos"):
		return
	var p := e.usar_contrato_gratis(d, agora)
	if not p.is_empty() and e.pilotos.size() == 1:
		_ev("capanga", "primeiro capanga: %s" % p.get("nome", "?"))
	var fundiu := true
	while fundiu:
		fundiu = false
		for a in e.pilotos:
			for b in e.pilotos:
				if e.pode_fundir(int(a["uid"]), int(b["uid"])):
					e.fundir(int(a["uid"]), int(b["uid"]))
					fundiu = true
					break
			if fundiu:
				break
	var melhor := {}
	for q in e.pilotos:
		if melhor.is_empty() or int(q["nivel"]) > int(melhor["nivel"]):
			melhor = q
	if not melhor.is_empty():
		e.escalar(e.modalidade, int(melhor["uid"]))


func _rodar() -> void:
	var args := {"sessoes_dia": "4", "sessao_min": "8", "primeira_min": "15", "limite_dias": "45", "cidades": "2",
			"saida": "user://jornada.tsv"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	d = root.get_node("Dados")
	e = IdleEstado.new()
	var primeiro := e.carro_da_modalidade()
	if not primeiro.is_empty():
		e.comprar_carro(String(primeiro["id"]))
	print("dia\tapp_min\tcorr\tcaixa\trenda/s\ttipo\tevento")
	_ev("início", "comprou %s; caixa inicial" % primeiro.get("id", "?"))
	var sessoes := int(args["sessoes_dia"])
	var intervalo := 86400.0 / maxf(sessoes, 1)
	var duracao_sessao := float(args["primeira_min"]) * 60.0
	var inicio := 1.8e9
	var na_sessao := 0.0
	var semente := 1
	var corridas_liga := 0
	var rinha_t := 0.0
	var abertas := e.liberadas()
	var rinha := e.rinha_aberta()
	var trapacas := false
	var cj := e.cfg_jornaleiro()
	var jorn_cada := (float(cj["intervalo_s"][0]) + float(cj["intervalo_s"][1])) * 0.5
	var jorn_t := 0.0
	var jorn_n := 0
	var sem_evento := 0.0  # app aberto desde o último acontecimento
	var maior_seca := 0.0
	_escada()
	while relogio < float(args["limite_dias"]) * 86400.0:
		var n_antes := linhas.size()
		if na_sessao >= duracao_sessao:
			var fora := intervalo - na_sessao
			e.dinheiro += e.renda_s() * minf(fora, e.offline_max_s())
			relogio += fora
			na_sessao = 0.0
			duracao_sessao = float(args["sessao_min"]) * 60.0
			_escolher_modalidade()
			_pilotos(inicio + relogio, "d%d" % int(relogio / 86400.0))
			_comprar_tudo()
		var r := e.correr(d, semente, false)
		semente += 1
		var dur: float = float(r["carros"]["jogador"]["tempo_total"]) + 2.2
		ativo += dur
		relogio += dur
		na_sessao += dur
		e.dinheiro += e.renda_s() * dur
		var pos := IdleEstado.posicao(r)
		var trofeus_antes := e.trofeus.size()
		e.concluir(pos)
		corridas_liga += 1
		if e.trofeus.size() > trofeus_antes:
			var t: Dictionary = {}
			for x in e.lista_trofeus():
				if String(x["pista"]) == e.trofeus.back():
					t = x
			_ev("troféu", "%s (%s +%s)" % [IdleUI.nome_pista(String(e.trofeus.back())), t.get("efeito", "?"), str(t.get("bonus", "?"))])
		if e.corridas >= int(cj["a_partir_corridas"]):
			if jorn_n == 0 and jorn_t == 0.0:
				_ev("jornaleiro", "o menino começa a aparecer")
			jorn_t += dur
			if jorn_t >= jorn_cada:
				jorn_t -= jorn_cada
				e.dinheiro += e.gorjeta_jornaleiro()
				jorn_n += 1
		if not rinha and e.rinha_aberta():
			rinha = true
			_ev("rinha", "a Rinha das Famílias abre (luta ao lado da corrida)")
		if e.rinha_aberta() and e.tem("aba:rinha"):
			rinha_t += dur
			var l := e.lutar_rinha(d, semente * 31 + 7, false)
			var cada := float(l["duracao"]) / 2.0 + 5.0
			var n := int(rinha_t / cada)
			if n > 0:
				rinha_t -= n * cada
				var antes := e.dinheiro
				e.pagar_rinha(IdleEstado.posicao(l))
				e.dinheiro += (e.dinheiro - antes) * (n - 1)
		if not trapacas and e.cfg["melhorias"].any(func(m): return m.has("trapaca") and e.tem("melhoria:" + String(m["id"]))):
			trapacas = true
			_ev("trapaças", "a seção Trapaças da família aparece")
		_escada()
		_comprar_tudo()
		if e.venceu and esperando_carro != "" and not e.subir_liga():
			continue
		if e.venceu:
			_ev("liga", "venceu %s em %d corridas (motor nv %d)" % [e.dados_liga()["nome"], corridas_liga, e.nivel("motor")])
			corridas_liga = 0
			if e.subir_liga():
				_ev("subiu", "agora em %s" % e.dados_liga()["nome"])
			else:
				var antes := e.modalidade
				_escolher_modalidade()
				if e.modalidade == antes and esperando_carro == "":
					if e.cidade + 1 >= int(args["cidades"]) or not e.mudar_de_cidade():
						_ev("fim", "nada mais para vencer nesta cidade")
						break
					_ev("cidade", "NOVA CIDADE %d (×%.0f)" % [e.cidade + 1, e.multiplicador_cidade()])
					abertas = e.liberadas()
					_escolher_modalidade()
			_pilotos(inicio + relogio, "d%d" % int(relogio / 86400.0))
			if e.liberadas().size() > abertas.size():
				for id in e.liberadas():
					if not id in abertas:
						_ev("abriu", "categoria %s" % e.dados_modalidade(id)["nome"])
				abertas = e.liberadas()
				_escolher_modalidade()
		if linhas.size() > n_antes:
			maior_seca = maxf(maior_seca, sem_evento)
			sem_evento = 0.0
		else:
			sem_evento += dur
	_ev("resumo", "%.1f dias, %.0f min de app, %d corridas, %d troféus, %d gorjetas, maior seca sem novidade: %.1f min de app" % [
			relogio / 86400.0, ativo / 60.0, e.corridas, e.trofeus.size(), jorn_n, maior_seca / 60.0])
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(linhas) + "\n")
	quit()
