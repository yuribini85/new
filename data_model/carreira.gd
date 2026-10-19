class_name Carreira
extends RefCounted
## Disputa de eventos: monta o grid, roda a Simulacao e paga o resultado.
##   - O jogador larga em último, atrás dos adversários na ordem do evento.
##   - Prêmio em dinheiro por posição a cada disputa; carro-prêmio só na
##     primeira vitória do evento.
##   - Cada corrida disputada conta um dia (docs/plano_mvp.md).

var dados: Node
var jogador: Node
## Quantas corridas foram simuladas (para medir custo; ver Fila).
var simulacoes := 0


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


## Disputa e aplica o resultado na hora. Retorna {"erro"} ou o mesmo que aplicar().
## `agora_real` (>= 0): relógio do período das repetições (fator_repeticao);
## o agente de playtest passa o tempo simulado. Padrão: o relógio do sistema.
func disputar(evento_id: String, uid: int, semente: int, agora_real := -1.0) -> Dictionary:
	var corrida := preparar(evento_id, uid, semente)
	if corrida.has("erro"):
		return corrida
	if agora_real >= 0.0:
		corrida["agora_real"] = agora_real
	return aplicar(corrida)


## Simula sem alterar nada no jogador. Mesma semente, mesmo resultado — a fila
## offline depende disso para recalcular a corrida em andamento após o load.
## Retorna {"erro"} ou {"evento_id", "uid", "resultado", "duracao"}.
## com_amostras = false (fila offline) dispensa as posições usadas só pela tela.
## `hipotetico` simula outro carro no lugar do da garagem (Mecanico: "e se eu
## comprasse esta peça?") sem alterar nada.
## `companheiro`: carro do segundo piloto da equipe (fase 9), que larga logo à
## frente do jogador; null = só o jogador.
## `piloto`: o piloto como estava na inscrição (Fila; o nível que ele sobe
## depois não muda a corrida já programada); vazio = o de agora.
func preparar(evento_id: String, uid: int, semente: int, com_amostras: bool = true,
		hipotetico: Carro = null, companheiro: Carro = null, piloto: Dictionary = {}) -> Dictionary:
	var p := iniciar_preparo(evento_id, uid, semente, com_amostras, hipotetico, companheiro, piloto)
	if p.has("erro"):
		return p
	return concluir_preparo(p)


## A preparação em partes, para resolver a corrida aos poucos sem travar a tela
## (decisão 90): monta o grid e devolve {"erro"} ou {"andamento":
## Simulacao.Andamento, ...}. Quem chama avança `p["andamento"].avancar(ms)`
## por quadro e, terminado, `concluir_preparo(p)` dá o mesmo que preparar().
func iniciar_preparo(evento_id: String, uid: int, semente: int, com_amostras: bool = true,
		hipotetico: Carro = null, companheiro: Carro = null, piloto: Dictionary = {}) -> Dictionary:
	var ev: Dictionary = dados.evento(evento_id)
	if ev.is_empty():
		return {"erro": "evento %s não existe" % evento_id}
	var carro: Carro = hipotetico if hipotetico != null else jogador.garagem.carro(uid)
	if carro == null:
		return {"erro": "carro %d não está na garagem" % uid}
	var motivos := Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas)
	if not motivos.is_empty():
		return {"erro": ", ".join(motivos)}

	var condicao: String = ev["condicao"]
	var participantes := []
	var grid := escalacao(evento_id, semente)
	for i in ev["adversarios"].size():
		var p := _adversario(ev["adversarios"][i], i, condicao)
		if i < grid.size():
			p["piloto"] = piloto_na_vaga(p["piloto"], grid[i])
		participantes.append(p)
	if companheiro != null:
		participantes.append({
			"id": EquipeJogador.ID,
			"atributos": companheiro.atributos_efetivos(condicao),
			"piloto": EquipeJogador.piloto_corrida(dados, jogador),
		})
	participantes.append({
		"id": "jogador",
		"atributos": carro.atributos_efetivos(condicao),
		"piloto": piloto if not piloto.is_empty() else EquipeJogador.piloto_do_jogador(dados, jogador),
	})

	simulacoes += 1
	var a := Simulacao.iniciar(dados.pista(ev["pista"]), participantes, int(ev["voltas"]),
			dados.simulacao(), semente, com_amostras, float(ev.get("largada_kmh", 0.0)) / 3.6)
	return {"evento_id": evento_id, "uid": uid, "andamento": a, "semente": semente,
			"companheiro": companheiro != null}


## Termina (de uma vez, se ainda falta) a preparação de iniciar_preparo().
func concluir_preparo(p: Dictionary) -> Dictionary:
	var a: Simulacao.Andamento = p["andamento"]
	a.avancar(INF)
	var r := a.resultado()
	return {"evento_id": p["evento_id"], "uid": p["uid"], "resultado": r, "duracao": r["duracao"],
			"semente": p["semente"], "companheiro": p["companheiro"]}


## Grid de equipes da corrida (decisão 36): uma vaga por equipe, primeiro as do
## nível da prova (licença -> nível em carreira.json), depois as dos níveis
## vizinhos; em cada equipe, o segundo piloto corre com a chance de
## carreira.json, senão o principal. Fixo pela prova e pela semente.
## Lista na ordem dos adversários: {equipe, piloto: {id, nome}, segundo}.
## Piloto de IA de uma vaga do grid: o perfil do piloto (agressivo,
## equilibrado, cauteloso; sem o dele, o da equipe) diz quanto ele tenta
## passar; o piloto que não é o titular (decisão 36) corre com menos consistência,
## e também o de traço com menos consistência (o traço vem do perfil, como no
## mercado: equipe_jogador.mercado.traco_por_perfil; decisão 88).
func piloto_na_vaga(base: Dictionary, vaga: Dictionary) -> Dictionary:
	var p := base.duplicate()
	var pv: Dictionary = vaga.get("piloto", {})
	var id_perfil := String(pv.get("perfil", vaga["equipe"].get("perfil", "")))
	var perfil: Dictionary = dados.carreira().get("perfis_piloto", {}).get(id_perfil, {})
	if perfil.has("agressividade"):
		p["agressividade"] = float(perfil["agressividade"])
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	if vaga["segundo"]:
		p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	if pv.has("id") and bool(EquipeJogador.traco_rival(dados, vaga["equipe"], pv).get("menos_consistencia", false)):
		p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	# A mesma variação por piloto da equipe do jogador (EquipeJogador.variar).
	EquipeJogador.variar(dados, String(pv.get("id", "")), p, float(base.get("consistencia", 0.0)))
	return p


func escalacao(evento_id: String, semente: int) -> Array:
	var ev: Dictionary = dados.evento(evento_id)
	if ev.has("grid_equipe"):
		return GridDesafio.escalacao(dados, jogador, ev)
	var cfg: Dictionary = dados.carreira()
	var niveis: Array = cfg.get("niveis", [])
	var equipes: Array = dados.lista("equipes").filter(func(e): return e.has("nivel"))
	if ev.is_empty() or niveis.is_empty() or equipes.is_empty():
		return []
	var nivel: String = cfg.get("niveis_licenca", {}).get(String(ev["restricoes"].get("licenca", "")), niveis[0])
	var alvo := niveis.find(nivel)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [evento_id, semente])
	var ordem := []
	for d in range(niveis.size()):
		for lado in ([0] if d == 0 else [-1, 1]):
			var k: int = alvo + d * lado
			if k < 0 or k >= niveis.size():
				continue
			var grupo := equipes.filter(func(e): return e["nivel"] == niveis[k])
			grupo.sort_custom(func(a, b): return a["id"] < b["id"])
			for i in range(grupo.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t = grupo[i]
				grupo[i] = grupo[j]
				grupo[j] = t
			ordem.append_array(grupo)
	var chance := float(cfg.get("segundo_piloto", {}).get("chance", 0.0))
	var contratados := _contratados(evento_id, semente)
	var grid := []
	for i in mini(ev["adversarios"].size(), ordem.size()):
		var eq: Dictionary = ordem[i]
		# O titular (o primeiro) corre na maioria; nas outras, um dos outros
		# pilotos da equipe, sorteado (cada equipe tem quatro, decisão 60).
		# Decisão 71: piloto contratado pela sua equipe não corre mais pela dele.
		var pilotos: Array = eq["pilotos"].filter(func(pl): return not String(pl["id"]) in contratados)
		if pilotos.is_empty():
			pilotos = eq["pilotos"]
		var segundo: bool = pilotos.size() > 1 and rng.randf() < chance
		var k := rng.randi_range(1, pilotos.size() - 1) if segundo else 0
		grid.append({"equipe": eq, "piloto": pilotos[k], "segundo": segundo})
	return grid


## Pilotos que a equipe do jogador contratou (não correm pelas equipes deles).
## Para a corrida na fila, os da inscrição (Fila.iniciar guarda): contratar
## alguém no meio dela não troca o rival da corrida já programada.
func _contratados(evento_id: String, semente: int) -> Array:
	var f: Dictionary = jogador.fila
	if not f.is_empty() and f.get("evento_id") == evento_id and int(f.get("semente", -1)) == semente \
			and f.get("contratados") is Array:
		return f["contratados"]
	return EquipeJogador.contratados(jogador)


## Sobrenomes fictícios dos pilotos rivais quando não há equipes (só
## apresentação). Fixos por prova e posição no grid.
const PILOTOS := ["Okada", "Brandt", "Moreau", "Ferraz", "Tanaka", "Kowalski", "Reyes", "Lindqvist",
		"Hale", "Ito", "Novak", "Duarte", "Sato", "Keller", "Varga", "Lacroix", "Mendes", "Harlow"]


## Piloto de um rival ("adv<i>_<carro>") nesta corrida; "" para o jogador.
## Com equipes, o da escalação da corrida (semente); sem, um sobrenome fixo.
func nome_piloto(evento_id: String, id: String, semente: int = -1) -> String:
	if not id.begins_with("adv"):
		return ""
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	var grid := escalacao(evento_id, semente) if semente >= 0 else []
	if i < grid.size():
		return String(grid[i]["piloto"]["nome"])
	return Carreira.sobrenome_fixo(evento_id, i)


## Piloto do rival nesta corrida ({} sem equipes): {id, nome, perfil, personalidade}.
func piloto_de(evento_id: String, id: String, semente: int) -> Dictionary:
	if not id.begins_with("adv") or semente < 0:
		return {}
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	var grid := escalacao(evento_id, semente)
	return grid[i]["piloto"] if i < grid.size() else {}


## Equipe do rival nesta corrida ({} sem equipes).
func equipe_de(evento_id: String, id: String, semente: int) -> Dictionary:
	if not id.begins_with("adv") or semente < 0:
		return {}
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	var grid := escalacao(evento_id, semente)
	return grid[i]["equipe"] if i < grid.size() else {}


## Vaga do piloto de um rival na equipe dele (0 = o titular; -1 sem equipe):
## o número do carro sai dela (PinturaCarro.da_equipe).
func vaga_de(evento_id: String, id: String, semente: int) -> int:
	if not id.begins_with("adv") or semente < 0:
		return -1
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	var grid := escalacao(evento_id, semente)
	if i >= grid.size():
		return -1
	return Array(grid[i]["equipe"]["pilotos"]).find(grid[i]["piloto"])


static func sobrenome_fixo(evento_id: String, i: int) -> String:
	var base := posmod(hash(evento_id), PILOTOS.size())
	# Passo primo com a lista: pilotos diferentes no mesmo grid.
	return PILOTOS[(base + i * 7) % PILOTOS.size()]


## "Piloto (carro)" para listas: distingue rivais com o mesmo modelo.
func rotulo_participante(evento_id: String, id: String, uid: int, semente: int = -1) -> String:
	if id == "jogador":
		return nome_participante(id, uid)
	if id == EquipeJogador.ID:
		return "%s (%s)" % [EquipeJogador.nome_segundo(dados, jogador), Aba.nome_curto(nome_participante(id, uid))]
	return "%s (%s)" % [nome_piloto(evento_id, id, semente), Aba.nome_curto(nome_participante(id, uid))]


## Nome do carro de um participante ("jogador", "companheiro" ou "adv<i>_<carro>").
func nome_participante(id: String, uid: int) -> String:
	if id == EquipeJogador.ID:
		var cc: Carro = jogador.garagem.carro(jogador.carro_companheiro)
		return "Companheiro" if cc == null else cc.base["nome"]
	if id == "jogador":
		var c: Carro = jogador.garagem.carro(uid)
		return "Você" if c == null else "Você (%s)" % c.base["nome"]
	return dados.carro(id.split("_", true, 1)[1]).get("nome", id)


## Atributos efetivos (com peças e pneus) de um participante na condição da
## prova: o jogador pelo carro `uid`, o adversário pela definição do evento.
func atributos_participante(evento_id: String, id: String, uid: int) -> Dictionary:
	var ev: Dictionary = dados.evento(evento_id)
	if id == "jogador" or id == EquipeJogador.ID:
		var c: Carro = jogador.garagem.carro(uid if id == "jogador" else jogador.carro_companheiro)
		return {} if c == null else c.atributos_efetivos(ev["condicao"])
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	if ev.is_empty() or i < 0 or i >= ev["adversarios"].size():
		return {}
	return _adversario(ev["adversarios"][i], i, ev["condicao"])["atributos"]


## Força do carro frente aos rivais da prova: potência por peso dele sobre a
## mediana dos rivais (1 = parelho); -1 sem rivais. A mesma conta do "SEU CARRO"
## dos cartões, da "Próxima prova" e da escolha do primeiro carro.
## `contra_o_melhor`: frente ao rival mais forte (quem precisa ser batido para
## vencer), em vez da mediana; ordena a "Próxima prova".
func forca_relativa(ev: Dictionary, c: Carro, contra_o_melhor := false) -> float:
	var meu := c.atributos_efetivos(ev["condicao"])
	var rivais := []
	for i in ev["adversarios"].size():
		var a := atributos_participante(ev["id"], "adv%d_%s" % [i, ev["adversarios"][i]["carro"]], c.uid)
		if not a.is_empty():
			rivais.append(a["potencia"] / maxf(a["peso"], 1.0))
	if rivais.is_empty():
		return -1.0
	rivais.sort()
	var ref: float = rivais[-1] if contra_o_melhor else rivais[rivais.size() / 2]
	return (meu["potencia"] / maxf(meu["peso"], 1.0)) / maxf(ref, 1e-6)


## Faixas da força relativa (as do "SEU CARRO" dos cartões): abaixo de
## PARELHO, mais fraco; de FORTE para cima, mais forte.
const FORCA_PARELHO := 0.95
const FORCA_FORTE := 1.08
const NOMES_FORCA := ["MAIS FRACO", "PARELHO", "MAIS FORTE"]


## 0 mais fraco, 1 parelho, 2 mais forte (-1 sem rivais).
static func nivel_forca(r: float) -> int:
	if r < 0.0:
		return -1
	return 0 if r < FORCA_PARELHO else (1 if r < FORCA_FORTE else 2)


## Provas que o carro já pode correr (licença, restrições, prêmio) e ainda não
## venceu, da mais favorável para a menos (frente ao rival mais forte: é quem
## decide a vitória): [{ev, forca}], forca frente à mediana, como nos cartões.
## Base da "Próxima prova" em Corridas.
func provas_favoraveis(c: Carro) -> Array:
	var r := []
	for ev in dados.lista("eventos"):
		if jogador.vitorias.has(ev["id"]) or ev["premios"].is_empty():
			continue
		if not Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas).is_empty():
			continue
		var f := forca_relativa(ev, c)
		if f >= 0.0:
			r.append({"ev": ev, "forca": f, "melhor": forca_relativa(ev, c, true)})
	r.sort_custom(func(a, b): return a["melhor"] > b["melhor"])
	return r


## Atributos de fábrica do carro de um adversário ("adv<i>_<carro>").
func carro_participante(id: String) -> Dictionary:
	return dados.carro(id.split("_", true, 1)[1]) if id.begins_with("adv") else {}


## Recompensa ao repetir prova já vencida (2026-10-17, decisão do usuário):
## carreira.json → repeticao {fatores, periodo_h}. A n-ésima repetição no
## período paga fatores[n-1] do prêmio (o último é o piso); o período vira no
## mesmo relógio da renovação do mercado de pilotos. Prova não vencida: 1.
func fator_repeticao(evento_id: String, agora_real: float = Time.get_unix_time_from_system()) -> float:
	if not jogador.vitorias.has(evento_id):
		return 1.0
	var r: Dictionary = dados.carreira().get("repeticao", {})
	# Provas abertas ficam fora da queda só até a primeira licença (decisão 122):
	# o começo precisa delas para tirar a Club; depois, rendiam mais por km que
	# as provas de licença e sem queda (o lugar óbvio de juntar dinheiro).
	if r.get("so_com_licenca", false) and String(dados.evento(evento_id)["restricoes"].get("licenca", "")) == "" \
			and jogador.licencas.is_empty():
		return 1.0
	var fatores: Array = r.get("fatores", [])
	if fatores.is_empty():
		return 1.0
	var n := repeticoes_no_periodo(evento_id, agora_real)
	return float(fatores[mini(n, fatores.size() - 1)])


## Repetições já feitas da prova no período atual.
func repeticoes_no_periodo(evento_id: String, agora_real: float = Time.get_unix_time_from_system()) -> int:
	var rp: Dictionary = jogador.repeticoes
	if rp.is_empty() or int(rp.get("periodo", -1)) != _periodo_repeticao(agora_real):
		return 0
	return int(rp["provas"].get(evento_id, 0))


## Segundos até o prêmio das repetições voltar a 100% (o período virar).
func repeticao_volta_em(agora_real: float = Time.get_unix_time_from_system()) -> float:
	var h := maxf(float(dados.carreira().get("repeticao", {}).get("periodo_h", 24)), 1.0) * 3600.0
	return (_periodo_repeticao(agora_real) + 1) * h - agora_real


func _periodo_repeticao(agora_real: float) -> int:
	var h := maxf(float(dados.carreira().get("repeticao", {}).get("periodo_h", 24)), 1.0)
	return int(floor(agora_real / (h * 3600.0)))


func _contar_repeticao(evento_id: String, agora_real: float) -> void:
	var p := _periodo_repeticao(agora_real)
	if jogador.repeticoes.is_empty() or int(jogador.repeticoes.get("periodo", -1)) != p:
		jogador.repeticoes = {"periodo": p, "provas": {}}
	var provas: Dictionary = jogador.repeticoes["provas"]
	provas[evento_id] = int(provas.get(evento_id, 0)) + 1


## Paga prêmio, entrega carro-prêmio e conta o dia.
## Retorna {"evento_id", "classificacao", "posicao", "premio", "carro_premio_uid", "resultado"}.
func aplicar(corrida: Dictionary) -> Dictionary:
	var evento_id: String = corrida["evento_id"]
	var ev: Dictionary = dados.evento(evento_id)
	var r: Dictionary = corrida["resultado"]
	# Equipe (fase 9): vale quem chegar na frente, o piloto ou o companheiro.
	var posicao_propria: int = r["classificacao"].find("jogador") + 1
	var posicao_companheiro: int = r["classificacao"].find(EquipeJogador.ID) + 1
	var posicao := posicao_propria if posicao_companheiro == 0 else mini(posicao_propria, posicao_companheiro)
	# Meta do dia (decisão 109): corrida, vitória e pódio contam.
	MetaDia.registrar(jogador, "corridas")
	if posicao == 1:
		MetaDia.registrar(jogador, "vitorias")
	if posicao >= 1 and posicao <= 3:
		MetaDia.registrar(jogador, "podios")
	var premio := 0
	if posicao <= ev["premios"].size():
		premio = int(ev["premios"][posicao - 1])
	# Prova já vencida: o prêmio cai a cada repetição no período.
	var agora_real := float(corrida.get("agora_real", Time.get_unix_time_from_system()))
	var fator := fator_repeticao(evento_id, agora_real)
	if jogador.vitorias.has(evento_id):
		_contar_repeticao(evento_id, agora_real)
	premio = roundi(premio * fator)
	jogador.economia.creditar(premio)

	var carro_premio_uid := -1
	var grid := {}
	if posicao == 1:
		# The Grid (decisão 74): só o desafio da equipe a deixa para trás.
		if ev.has("grid_equipe"):
			grid = TheGrid.registrar(dados, jogador, [String(ev["grid_equipe"])])
		var primeira: bool = not jogador.vitorias.has(evento_id)
		jogador.vitorias[evento_id] = jogador.vitorias.get(evento_id, 0) + 1
		if primeira and ev.get("carro_premio") != null:
			var premiado := Carro.new(dados.carro(ev["carro_premio"]))
			premiado.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			premiado.faixas = PinturaCarro.de_premio()
			carro_premio_uid = jogador.garagem.adicionar(premiado)
	jogador.dias += 1
	var campeonato: Dictionary = Campeonatos.registrar(self, evento_id, r["classificacao"], int(corrida.get("semente", -1)))
	var tempo: float = r["carros"]["jogador"]["tempo_total"] if r["carros"]["jogador"]["terminou"] else 0.0
	var anterior: Dictionary = jogador.historico.get(evento_id, {}).duplicate()
	jogador.historico[evento_id] = _historico(anterior, posicao_propria, tempo)
	var patrocinio := GestaoEquipe.bonus_corrida(dados, jogador, ev, posicao, not campeonato.is_empty())
	var subiram := EquipeJogador.apos_prova(dados, jogador, ["corrida"], posicao == 1)

	return {
		"anterior": anterior,
		"recorde": tempo > 0.0 and (anterior.is_empty() or anterior["melhor_tempo"] <= 0.0 or tempo < anterior["melhor_tempo"]),
		"evento_id": evento_id,
		"classificacao": r["classificacao"],
		"posicao": posicao,
		"pilotos_subiram": subiram,
		"posicao_propria": posicao_propria,
		"posicao_companheiro": posicao_companheiro,
		"patrocinio": patrocinio,
		"premio": premio,
		"fator_repeticao": fator,
		"carro_premio_uid": carro_premio_uid,
		"resultado": r,
		"campeonato": campeonato,
		"grid": grid,
	}


static func _historico(h: Dictionary, posicao: int, tempo: float) -> Dictionary:
	if h.is_empty():
		return {"corridas": 1, "melhor_pos": posicao, "melhor_tempo": tempo, "ultima_pos": posicao, "ultimo_tempo": tempo}
	return {
		"corridas": int(h["corridas"]) + 1,
		"melhor_pos": mini(int(h["melhor_pos"]), posicao),
		"melhor_tempo": tempo if h["melhor_tempo"] <= 0.0 or (tempo > 0.0 and tempo < h["melhor_tempo"]) else h["melhor_tempo"],
		"ultima_pos": posicao,
		"ultimo_tempo": tempo,
	}


func _adversario(adv: Dictionary, indice: int, condicao: String) -> Dictionary:
	var c := Carro.new(dados.carro(adv["carro"]))
	for peca_id in adv.get("pecas", []):
		c.instalar(dados.peca(peca_id))
	var pneus: Array = adv.get("pneus", [])
	if pneus.is_empty():
		pneus = [dados.economia()["pneu_de_fabrica"]]
	for pneu_id in pneus:
		c.adicionar_pneu(dados.pneu(pneu_id))
	var a := c.atributos_efetivos(condicao)
	# Preparação do rival (potencia_mult do evento): potência × fator.
	a["potencia"] = float(a["potencia"]) * float(adv.get("potencia_mult", 1.0))
	return {
		"id": "adv%d_%s" % [indice, adv["carro"]],
		"atributos": a,
		"piloto": dados.piloto(adv["piloto"]),
	}
