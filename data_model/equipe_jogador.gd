class_name EquipeJogador
extends RefCounted
## A equipe do jogador (a Wreckage, na campanha do dono): nasce na cena do
## primeiro carro (CW_C01B, ação UNLOCK_TEAM_TAB; a flag guarda o nome antigo,
## SECOND_DRIVER_CREATED, por causa dos saves). Criar
## não reseta dinheiro, carros nem licenças; só muda o contexto (aba Equipe).
## A equipe é a de equipes.json com "jogador": true; nome e pilotos vêm de lá.
##
## Gestão leve (decisão 38, carreira.json → equipe_jogador): caixa único (o
## saldo do jogador); a cada corrida entra o patrocínio e sai o staff. Valores
## null são pendentes do playtest e valem 0.
## Segundo piloto (`segundo_piloto` nos dados): sem contrato nem salário; entra
## na equipe na cena que libera (flag DRIVER_HIRE_UNLOCKED) e só aparece na
## prova, com o carro da garagem escolhido na aba Equipe e o piloto do jogador
## com a perda de consistência de segundo piloto (decisão 36). Os ganhos são
## da equipe: vale quem chegar na frente e os dois pontuam no campeonato.

const FLAG := "SECOND_DRIVER_CREATED"
const FLAG_CONTRATAR := "DRIVER_HIRE_UNLOCKED"
## Decisão 69: o jogador administra; quem pilota é contratado. Vagas de piloto:
## uma de corrida e duas de arena (jogador.pilotos). Os de arena abrem com o
## tutorial da arena (3 carros na garagem).
const VAGAS_PILOTO := ["corrida", "arena1", "arena2"]
const NOMES_VAGA := {"corrida": "PILOTO DE CORRIDA", "arena1": "PILOTO DE ARENA 1", "arena2": "PILOTO DE ARENA 2"}
const FLAG_ARENA := "ARENA_PILOTS_UNLOCKED"
## Id do companheiro na corrida (ao lado de "jogador").
const ID := "companheiro"


static func criada(jogador: Node) -> bool:
	return jogador.flags.has(FLAG)


static func criar(jogador: Node) -> void:
	jogador.flags[FLAG] = true


## Dados da equipe do jogador ({} antes de criada ou sem equipe nos dados). A
## campanha pode trocar nome e logo (historia.json → <personagem>.equipe; logo
## "" = o nome em texto).
static func dados_equipe(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	return identidade(dados, jogador)


## Nome, logo e cores da equipe do jogador mesmo antes de ela ser criada (a
## apresentação do Grid mostra a Wreckage desde o começo).
static func identidade(dados: Node, jogador: Node) -> Dictionary:
	for e in dados.lista("equipes"):
		if e.get("jogador", false):
			var troca: Dictionary = dados.historia().get(String(jogador.personagem), {}).get("equipe", {})
			var r: Dictionary = e.duplicate()
			r.merge(troca, true)
			# A identidade escolhida pelo jogador (nome e logo, independentes).
			if String(jogador.identidade.get("nome", "")) != "":
				r["nome"] = IdentidadeEquipe.nome(dados, jogador)
			if IdentidadeEquipe.logo(jogador) != "":
				r["logo"] = IdentidadeEquipe.arquivo_logo(IdentidadeEquipe.logo(jogador))
				r["subtitulo"] = true  # o emblema não traz o nome
			return r
	return {}


static func config(dados: Node) -> Dictionary:
	return dados.carreira().get("equipe_jogador", {})


## Valor da gestão em G (0 enquanto pendente do playtest).
static func valor(dados: Node, chave: String) -> int:
	var v = config(dados).get(chave)
	return 0 if v == null else int(v)


static func definido(dados: Node, chave: String) -> bool:
	return config(dados).get(chave) != null


## Segundo piloto entra na equipe (ação da cena que libera). Sem custo.
static func liberar_segundo(dados: Node, jogador: Node) -> void:
	jogador.flags[FLAG_CONTRATAR] = true
	if criada(jogador) and jogador.segundo_piloto == "":
		jogador.segundo_piloto = String(config(dados).get("segundo_piloto", {}).get("id", ""))


static func piloto(dados: Node, piloto_id: String) -> Dictionary:
	if piloto_id == "":
		return {}
	for c in candidatos(dados):
		if c.get("id") == piloto_id:
			return c
	for e in TheGrid.equipes(dados):
		for pe in e.get("pilotos", []):
			if pe.get("id") == piloto_id:
				return _do_grid(dados, e, pe)
	var p: Dictionary = config(dados).get("segundo_piloto", {})
	return p if p.get("id") == piloto_id else {}


## Candidatos a segundo piloto (decisão 56): {id, nome, traco, frase}; o retrato
## é um dos genéricos (Assets.retrato_generico).
static func candidatos(dados: Node) -> Array:
	return config(dados).get("candidatos", [])


## Traço do candidato: {nome, treina}.
static func traco(dados: Node, piloto_id: String) -> Dictionary:
	return config(dados).get("tracos", {}).get(String(piloto(dados, piloto_id).get("traco", "")), {})


## Traço de um piloto de equipe ({nome, perfil, menos_consistencia, ...}):
## o do perfil dele (mercado.traco_por_perfil), como no mercado (decisão 88).
static func traco_rival(dados: Node, e: Dictionary, pe: Dictionary) -> Dictionary:
	return config(dados).get("tracos", {}).get(String(_do_grid(dados, e, pe)["traco"]), {})


# ------------------------------------------------------------ Mercado (decisão 71)

static func cfg_mercado(dados: Node) -> Dictionary:
	return config(dados).get("mercado", {})


## Piloto de uma equipe do Grid como candidato: o traço pelo perfil da equipe.
## Serve às duas vagas (tipo "", decisão do usuário de 2026-10-16: o traço não
## decide a vaga, como nos candidatos).
static func _do_grid(dados: Node, e: Dictionary, pe: Dictionary) -> Dictionary:
	# Decisão 72: o traço pelo perfil do próprio piloto (o da equipe, se faltar).
	var perfil := String(pe.get("perfil", e.get("perfil", "")))
	var tr := String(cfg_mercado(dados).get("traco_por_perfil", {}).get(perfil, "constante"))
	return {"id": pe["id"], "nome": pe["nome"], "genero": String(pe.get("genero", "m")), "traco": tr, "tipo": "",
			"frase": String(pe.get("personalidade", "")), "equipe": String(e["nome"])}


## Todos os que podem aparecer no mercado: os candidatos e os quatro pilotos
## de cada equipe do Grid já vencida.
static func pool(dados: Node, jogador: Node, tipo_: String) -> Array:
	var l: Array = candidatos(dados).filter(func(c): return (String(c.get("tipo", "corrida")) == tipo_
			and (not bool(c.get("premium", false)) or tem_pack_premium(jogador))))
	for id in TheGrid.vencidas(jogador):
		var e := TheGrid.equipe(dados, String(id))
		for pe in e.get("pilotos", []):
			var c := _do_grid(dados, e, pe)
			if c["tipo"] in ["", tipo_]:
				l.append(c)
	return l


## Período do mercado (renova a cada `renova_h`).
static func periodo_mercado(dados: Node, agora: float) -> int:
	return int(floor(agora / (maxf(float(cfg_mercado(dados).get("renova_h", 24)), 1.0) * 3600.0)))


## Segundos até o mercado renovar.
static func renova_em(dados: Node, agora: float) -> float:
	var passo := maxf(float(cfg_mercado(dados).get("renova_h", 24)), 1.0) * 3600.0
	return (periodo_mercado(dados, agora) + 1) * passo - agora


## A oferta do período: `por_tipo` do pool, sorteados pelo período (sem
## `por_tipo` nos dados: o pool inteiro). Os já contratados não ocupam lugar.
static func oferta(dados: Node, jogador: Node, tipo_: String, agora: float) -> Array:
	var livres := pool(dados, jogador, tipo_).filter(func(c): return vaga_do_piloto(jogador, String(c["id"])) == "")
	# Os premium do pack ficam sempre (fora do sorteio do período).
	var fixos := livres.filter(func(c): return bool(c.get("premium", false)))
	var l := livres.filter(func(c): return not bool(c.get("premium", false)))
	var n := int(cfg_mercado(dados).get("por_tipo", l.size()))
	if l.size() <= n:
		return fixos + l
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mercado|%s|%d" % [tipo_, periodo_mercado(dados, agora)])
	for i in range(l.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = l[i]
		l[i] = l[j]
		l[j] = t
	return fixos + l.slice(0, n)


## Gênero do piloto ("m" ou "f", dado em equipes.json e carreira.json pela
## arte dele). Sem o dado, "m".
static func genero(dados: Node, piloto_id: String) -> String:
	return "f" if String(piloto(dados, piloto_id).get("genero", "m")) == "f" else "m"


## A forma da palavra para o gênero: flexao("f", "contratado", "contratada").
static func flexao(genero_: String, masculino: String, feminino: String) -> String:
	return feminino if genero_ == "f" else masculino


## "piloto" ou "pilota", para quem é uma pessoa (o cargo segue "piloto").
static func palavra_piloto(dados: Node, piloto_id: String) -> String:
	return flexao(genero(dados, piloto_id), "piloto", "pilota")


## Tipo do candidato: "corrida" ou "arena" (carreira.json → candidatos); ""
## para os do Grid, que servem às duas vagas.
static func tipo(dados: Node, piloto_id: String) -> String:
	return String(piloto(dados, piloto_id).get("tipo", "corrida"))


## Piloto contratado na vaga ("" = vaga vazia).
static func piloto_vaga(jogador: Node, vaga: String) -> String:
	var p: Dictionary = jogador.pilotos
	if vaga == "corrida":
		return String(p.get("corrida", ""))
	var a: Array = p.get("arena", ["", ""])
	return String(a[0 if vaga == "arena1" else 1]) if a.size() == 2 else ""


static func vaga_do_piloto(jogador: Node, piloto_id: String) -> String:
	for v in VAGAS_PILOTO:
		if piloto_id != "" and piloto_vaga(jogador, v) == piloto_id:
			return v
	return ""


## Ids dos pilotos nas vagas da equipe (os vazios fora).
static func contratados(jogador: Node) -> Array:
	return VAGAS_PILOTO.map(func(v): return piloto_vaga(jogador, v)).filter(func(id): return id != "")


## As vagas de arena só abrem com o tutorial da arena (3 carros).
static func vaga_aberta(jogador: Node, vaga: String) -> bool:
	return criada(jogador) and (vaga == "corrida" or jogador.flags.has(FLAG_ARENA))


## Luvas da contratação (decisão do usuário, 2026-10-17): pagas uma vez, ao
## entrar na equipe; sem salário. carreira.json → equipe_jogador → luvas
## {premios}: premios × o prêmio de 1º lugar médio da maior licença do jogador
## (a Club sem licença) × a qualidade do piloto (média das três barras da
## escala do jogo, 35–100%). O primeiro piloto (o do tutorial) sai de graça;
## premium, do pack comprado, também.
const FLAG_PRIMEIRA_CONTRATACAO := "PRIMEIRO_PILOTO_CONTRATADO"


static func luvas(dados: Node, jogador: Node, piloto_id: String) -> int:
	var n := float(config(dados).get("luvas", {}).get("premios", 0.0))
	if n <= 0.0 or piloto_id == "" or bool(piloto(dados, piloto_id).get("premium", false)):
		return 0
	if not jogador.flags.has(FLAG_PRIMEIRA_CONTRATACAO) and VAGAS_PILOTO.all(func(v): return piloto_vaga(jogador, v) == ""):
		return 0
	var ordem := GestaoEquipe.ordem(dados)
	var lic: String = ordem[0] if not ordem.is_empty() else ""
	for l in ordem:
		if l in jogador.licencas:
			lic = l
	var at := atributos(dados, null, piloto_id)
	var q := 0.0
	for k in ["ritmo", "consistencia", "agressividade"]:
		q += barra_atributo(dados, k, float(at.get(k, 0.0)))
	return roundi(n * GestaoEquipe.premio_referencia(dados, lic) * q / 3.0)


## Contrata o candidato para a vaga (o tipo tem de bater). "" ou o motivo.
static func contratar(dados: Node, jogador: Node, piloto_id: String, vaga := "corrida") -> String:
	if not vaga in VAGAS_PILOTO:
		return "vaga desconhecida"
	if not vaga_aberta(jogador, vaga):
		return "a equipe ainda não contrata" if not criada(jogador) else "para disputar a arena, são precisos pelo menos 3 carros na garagem"
	if piloto(dados, piloto_id).is_empty():
		return "candidato desconhecido"
	# Com a corrida em andamento, o piloto de corrida não muda (pedido do usuário).
	if vaga == "corrida" and not jogador.fila.is_empty() and piloto_vaga(jogador, "corrida") != piloto_id:
		return "não dá para trocar o piloto com uma corrida em andamento"
	var de_tipo := "corrida" if vaga == "corrida" else "arena"
	if vaga_do_piloto(jogador, piloto_id) == "" and not oferta(dados, jogador, de_tipo, Time.get_unix_time_from_system()) \
			.any(func(c): return c["id"] == piloto_id) and not pool(dados, jogador, de_tipo).any(func(c): return c["id"] == piloto_id):
		return "fora do mercado"
	var quer := "corrida" if vaga == "corrida" else "arena"
	if tipo(dados, piloto_id) not in ["", quer]:
		return "%s é %s de %s" % [String(piloto(dados, piloto_id).get("nome", piloto_id)),
				palavra_piloto(dados, piloto_id), tipo(dados, piloto_id)]
	var em := vaga_do_piloto(jogador, piloto_id)
	if em != "" and em != vaga:
		return "já está na equipe"
	if em == "":
		var custo := luvas(dados, jogador, piloto_id)
		if custo > 0 and not jogador.economia.debitar(custo):
			return "faltam giros para as luvas (%d)" % custo
	jogador.flags[FLAG_PRIMEIRA_CONTRATACAO] = true
	var p: Dictionary = jogador.pilotos.duplicate(true)
	if vaga == "corrida":
		p["corrida"] = piloto_id
		# O treino da equipe (antes dos pilotos contratados) fica com o primeiro de corrida.
		if jogador.equipe.has("treino") and not jogador.equipe.has("treino_" + piloto_id):
			jogador.equipe["treino_" + piloto_id] = jogador.equipe["treino"]
			jogador.equipe.erase("treino")
	else:
		var a: Array = p.get("arena", ["", ""])
		if a.size() != 2:
			a = ["", ""]
		a[0 if vaga == "arena1" else 1] = piloto_id
		p["arena"] = a
	jogador.pilotos = p
	return ""


## Save antigo: o segundo piloto vai para a vaga do tipo dele; quem já viu a
## arena ou passou da International mantém o que tinha.
static func migrar(dados: Node, jogador: Node) -> void:
	if jogador.flags.has("ARENA_INTRO"):
		jogador.flags[FLAG_ARENA] = true
	if exige_piloto(jogador) and (jogador.flags.has("INTERNATIONAL_COMPLETE") or "INTERNATIONAL" in jogador.licencas):
		jogador.flags["GESTAO_LIBERADA"] = true
	if not jogador.pilotos.is_empty():
		return
	jogador.pilotos = {"corrida": "", "arena": ["", ""]}
	var s := String(jogador.segundo_piloto)
	if s != "" and not piloto(dados, s).is_empty():
		if tipo(dados, s) == "corrida":
			jogador.pilotos["corrida"] = s
		else:
			jogador.pilotos["arena"] = [s, ""]


# ------------------------------------- Experiência e embalo (decisão 71)

## Depois de uma prova: cada piloto das vagas soma experiência (a cada
## `xp_por_nivel` provas, um nível de treino, até o teto da licença) e a
## sequência de vitórias do grupo; `embalo_vitorias` seguidas deixam o próximo
## treino de cada um mais curto. Devolve os ids que subiram de nível.
static func apos_prova(dados: Node, jogador: Node, vagas: Array, venceu: bool) -> Array:
	var cfg := GestaoEquipe.cfg_treino(dados)
	var por_nivel := int(cfg.get("xp_por_nivel", 0))
	var subiram := []
	var ids: Array = vagas.map(func(v): return piloto_vaga(jogador, v)).filter(func(x): return x != "")
	if ids.is_empty():
		return subiram
	var base := float(dados.piloto(dados.carreira()["piloto_jogador"])["ritmo"])
	for id in ids:
		if por_nivel <= 0:
			break
		var xp := int(jogador.equipe.get("xp_" + id, 0)) + 1
		if xp >= por_nivel and GestaoEquipe.pode_treinar(dados, jogador, base, id):
			var t: Dictionary = jogador.equipe.get("treino_" + id, {})
			t["nivel"] = int(t.get("nivel", 0)) + 1
			jogador.equipe["treino_" + id] = t
			xp = 0
			subiram.append(id)
		jogador.equipe["xp_" + id] = mini(xp, maxi(por_nivel - 1, 0)) if xp >= por_nivel else xp
	var grupo := "seq_" + String(vagas[0]).left(5)
	var seq := int(jogador.equipe.get(grupo, 0)) + 1 if venceu else 0
	var precisa := int(cfg.get("embalo_vitorias", 0))
	if precisa > 0 and seq >= precisa:
		for id in ids:
			jogador.equipe["embalo_" + id] = true
		seq = 0
	jogador.equipe[grupo] = seq
	return subiram


static func xp(jogador: Node, piloto_id: String) -> int:
	return int(jogador.equipe.get("xp_" + piloto_id, 0))


static func em_embalo(jogador: Node, piloto_id: String) -> bool:
	return bool(jogador.equipe.get("embalo_" + piloto_id, false))


## Na campanha do dono a equipe precisa do piloto de corrida para correr.
static func exige_piloto(jogador: Node) -> bool:
	return String(jogador.personagem) == "dono"


## Nome de quem pilota nas corridas: o piloto de corrida contratado; sem ele, o
## personagem da história ou "Você" em jogo sem história.
static func nome_jogador(dados: Node, jogador: Node) -> String:
	var contratado := piloto_vaga(jogador, "corrida")
	if contratado != "":
		return String(piloto(dados, contratado).get("nome", contratado))
	if exige_piloto(jogador):
		return "Sem piloto"
	var id := Prologo.piloto(dados, jogador)
	if id == "":
		id = String(jogador.personagem)
	if id != "" and dados.existe("personagens", id):
		return String(dados.item("personagens", id)["nome"])
	return "Você"


## Nome do piloto de arena da vaga ("" se vazia).
static func nome_arena(dados: Node, jogador: Node, vaga: String) -> String:
	var id := piloto_vaga(jogador, vaga)
	return String(piloto(dados, id).get("nome", id)) if id != "" else ""


## Nome do segundo piloto da dupla da arena ("" se ainda não há).
static func nome_segundo(dados: Node, jogador: Node) -> String:
	return nome_arena(dados, jogador, "arena2")


## Carro do companheiro para esta prova (-1 se ele não corre): piloto
## na equipe, carro escolhido na garagem, diferente do do piloto principal e elegível.
static func companheiro_para(dados: Node, jogador: Node, evento_id: String, uid: int) -> int:
	if not criada(jogador) or jogador.segundo_piloto == "":
		return -1
	var cu: int = jogador.carro_companheiro
	var carro: Carro = jogador.garagem.carro(cu)
	if carro == null or cu == uid:
		return -1
	var ev: Dictionary = dados.evento(evento_id)
	if ev.is_empty() or not Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas).is_empty():
		return -1
	return cu


## Atributos de um piloto contratado (decisão 70): o piloto-base de
## carreira.json com o traço (agressividade do perfil; consistência do segundo
## piloto nos mais crus) e o treino dele; cansado, perde consistência
## (equipe.json → treino.cansaco; null = sem efeito).
## Calculadora da variação por piloto (pedido do usuário, 2026-10-16): cada
## piloto tem um ajuste próprio e fixo (sorteado pelo id) em consistência e
## agressividade, que não vêm do estudo. As faixas saem dos dados que já existem,
## sem número novo: agressividade, metade do menor intervalo entre os perfis de
## rival (perfis_piloto); consistência, metade da perda do segundo piloto
## (segundo_piloto.perda_consistencia). `variacao_piloto.fator` (carreira.json)
## escala as duas faixas no playtest (0 desliga). O ritmo segue a regra de sempre.
static func faixas_variacao(dados: Node, consistencia_base: float) -> Dictionary:
	var cfg: Dictionary = dados.carreira().get("variacao_piloto", {})
	var fator := float(cfg.get("fator", 0.0))
	if fator <= 0.0:
		return {"agressividade": 0.0, "consistencia": 0.0}
	var valores := []
	for k in dados.carreira().get("perfis_piloto", {}):
		var pf = dados.carreira()["perfis_piloto"][k]
		if pf is Dictionary and pf.has("agressividade") and not float(pf["agressividade"]) in valores:
			valores.append(float(pf["agressividade"]))
	valores.sort()
	var menor := 0.0
	for i in range(1, valores.size()):
		var gap: float = valores[i] - valores[i - 1]
		menor = gap if menor == 0.0 else minf(menor, gap)
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	return {"agressividade": menor * 0.5 * fator, "consistencia": consistencia_base * perda * 0.5 * fator}


## Aplica a variação do piloto `piloto_id` aos atributos `p` (no lugar).
static func variar(dados: Node, piloto_id: String, p: Dictionary, consistencia_base: float) -> void:
	if piloto_id == "":
		return
	var faixas := faixas_variacao(dados, consistencia_base)
	for attr in ["consistencia", "agressividade"]:
		var d: float = faixas[attr]
		if d <= 0.0 or not p.has(attr):
			continue
		var u := float(absi(hash(piloto_id + "|" + attr)) % 10001) / 10000.0  # 0..1, fixo por piloto
		p[attr] = clampf(float(p[attr]) + d * (2.0 * u - 1.0), 0.0, 1.0)


# ------------------------------------------- Pack premium (decisão do usuário, 2026-10-16)

## Flag do pack premium (os 3 pilotos de elite, compra única e permanente).
const FLAG_PACK_PREMIUM := "PACK_PREMIUM"


static func tem_pack_premium(jogador: Node) -> bool:
	return jogador != null and jogador.flags.has(FLAG_PACK_PREMIUM)


static func premium(dados: Node, piloto_id: String) -> bool:
	return bool(piloto(dados, piloto_id).get("premium", false))


## Os premium de um tipo (corrida/arena), comprados ou não (para a vitrine).
static func premium_do_tipo(dados: Node, tipo_: String) -> Array:
	return candidatos(dados).filter(func(c): return (bool(c.get("premium", false))
			and String(c.get("tipo", "corrida")) == tipo_))


## O maior ritmo que o treino alcança (o teto mais alto das licenças): o dos
## premium e a escala da barra de ritmo na tela.
static func ritmo_maximo(dados: Node) -> float:
	var base := float(dados.piloto(dados.carreira()["piloto_jogador"]).get("ritmo", 1.0))
	var maior := base
	for v in GestaoEquipe.cfg_treino(dados).get("teto", {}).values():
		maior = maxf(maior, float(v))
	return maior


## Ritmo do premium: carreira.json → equipe_jogador.ritmo_premium (medido com
## tools/calibrar_treino.gd, meta 2x a do treino); sem o dado, o teto do treino.
static func ritmo_premium(dados: Node) -> float:
	var r = config(dados).get("ritmo_premium")
	return float(r) if r != null else ritmo_maximo(dados)


## Escala das barras de atributo (tela): do pior piloto do jogo (candidatos e
## equipes do Grid, sem treino) ao premium. PISO_BARRA é só visual: a barra do
## pior nunca aparece vazia.
const PISO_BARRA := 0.35
static var _escala := {}


static func escala_atributos(dados: Node) -> Dictionary:
	if not _escala.is_empty():
		return _escala
	var ids := candidatos(dados).filter(func(c): return not bool(c.get("premium", false))).map(func(c): return String(c["id"]))
	var minimo := {"ritmo": INF, "consistencia": INF, "agressividade": INF}
	for id in ids:
		var at := atributos(dados, null, String(id))
		for k in minimo:
			minimo[k] = minf(minimo[k], float(at[k]))
	var c := Carreira.new(dados, null)
	var base: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"])
	for e in TheGrid.equipes(dados):
		for pe in e.get("pilotos", []):
			var at := c.piloto_na_vaga(base, {"equipe": e, "piloto": pe, "segundo": false})
			for k in minimo:
				minimo[k] = minf(minimo[k], float(at[k]))
	_escala = {"ritmo": [minimo["ritmo"], ritmo_premium(dados)], "consistencia": [minimo["consistencia"], 1.0],
			"agressividade": [minimo["agressividade"], 1.0]}
	return _escala


## Fração da barra (PISO_BARRA a 1) do atributo na escala do jogo.
static func barra_atributo(dados: Node, attr: String, valor: float) -> float:
	var e: Array = escala_atributos(dados)[attr]
	var t := 1.0 if e[1] <= e[0] else clampf((valor - e[0]) / (e[1] - e[0]), 0.0, 1.0)
	return PISO_BARRA + (1.0 - PISO_BARRA) * t


static func atributos(dados: Node, jogador: Node, piloto_id: String, agora := -1.0) -> Dictionary:
	var p: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"]).duplicate()
	if premium(dados, piloto_id):
		# Premium: tudo no máximo, sempre (sem variação, treino ou cansaço).
		p["ritmo"] = ritmo_premium(dados)
		p["consistencia"] = 1.0
		p["agressividade"] = 1.0
		return p
	var tr := traco(dados, piloto_id)
	var perfis: Dictionary = dados.carreira().get("perfis_piloto", {})
	if perfis.has(String(tr.get("perfil", ""))):
		p["agressividade"] = float(perfis[String(tr["perfil"])]["agressividade"])
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	var consistencia_base := float(p["consistencia"])
	if bool(tr.get("menos_consistencia", false)):
		p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	variar(dados, piloto_id, p, consistencia_base)
	if jogador != null:
		p["ritmo"] = GestaoEquipe.ritmo(dados, jogador, float(p["ritmo"]), piloto_id)
		var cansaco = GestaoEquipe.cfg_treino(dados).get("cansaco")
		if cansaco != null:
			var e := GestaoEquipe.energia(jogador, piloto_id, agora if agora >= 0.0 else Time.get_unix_time_from_system())
			p["consistencia"] = float(p["consistencia"]) * (1.0 - float(cansaco) * (1.0 - e))
	return p


## Piloto da vaga (contratado) ou {} se vazia.
static func piloto_da_vaga(dados: Node, jogador: Node, vaga: String) -> Dictionary:
	var id := piloto_vaga(jogador, vaga)
	return {} if id == "" else atributos(dados, jogador, id)


## Piloto nas corridas: o de corrida contratado; sem ele, o de carreira.json
## com o treino da equipe (GestaoEquipe: ritmo até o teto da licença).
static func piloto_do_jogador(dados: Node, jogador: Node) -> Dictionary:
	if jogador != null and piloto_vaga(jogador, "corrida") != "":
		return piloto_da_vaga(dados, jogador, "corrida")
	var p: Dictionary = dados.piloto(dados.carreira()["piloto_jogador"]).duplicate()
	if jogador != null:
		p["ritmo"] = GestaoEquipe.ritmo(dados, jogador, float(p["ritmo"]))
	return p


## Segundo da dupla: o piloto de arena 2; sem ele, o do jogador com a perda de
## consistência do segundo piloto (o treino é do principal, salvo Promessa).
static func piloto_corrida(dados: Node, jogador: Node = null) -> Dictionary:
	if jogador != null and piloto_vaga(jogador, "arena2") != "":
		return piloto_da_vaga(dados, jogador, "arena2")
	var treina: bool = jogador != null and bool(traco(dados, piloto_vaga(jogador, "arena2")).get("treina", false))
	var p: Dictionary = piloto_do_jogador(dados, jogador if treina else null)
	var perda := float(dados.carreira().get("segundo_piloto", {}).get("perda_consistencia", 0.0))
	p["consistencia"] = float(p["consistencia"]) * (1.0 - perda)
	return p


## Folha de uma corrida: {patrocinio, staff, saldo} (saldo = líquido).
static func folha(dados: Node, jogador: Node) -> Dictionary:
	if not criada(jogador):
		return {}
	var f := {
		"patrocinio": valor(dados, "patrocinio"),
		"staff": valor(dados, "custo_staff"),
	}
	f["saldo"] = f["patrocinio"] - f["staff"]
	return f


## Aplica a folha depois de uma corrida. O caixa não fica negativo: o que
## faltar não é cobrado (gestão leve, sem dívida). Retorna a folha aplicada.
static func cobrar_corrida(dados: Node, jogador: Node) -> Dictionary:
	var f := folha(dados, jogador)
	if f.is_empty():
		return {}
	jogador.economia.creditar(int(f["patrocinio"]))
	var custo: int = mini(int(f["staff"]), jogador.economia.saldo)
	jogador.economia.debitar(custo)
	f["cobrado"] = custo
	return f
