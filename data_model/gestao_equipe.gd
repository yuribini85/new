class_name GestaoEquipe
extends RefCounted
## Gestão da equipe do jogador (data/equipe.json; abre com a equipe, flag
## SECOND_DRIVER_CREATED): patrocínio, sede e o nível de ritmo dos pilotos.
## Estado em jogador.equipe.
##
## Patrocínio: os patrocinadores (data/patrocinadores.json) de licença até a
## maior do jogador; cada vaga livre assina sozinha o que mais paga por hora
## (renovar). Um contrato dura a capacidade de renda offline do jogador
## (decisão 104) e paga cada hora dela no relógio real, com o app aberto ou
## fechado; mais um bônus a cada corrida que cumpre a condição dele.
## Valores: fatores sobre o prêmio de referência (média do 1º lugar das provas
## da licença do patrocinador); provisórios até o playtest.
## Sede: só o Escritório comercial (mais contratos ao mesmo tempo).

## Licenças na ordem de licencas.json (CLUB → ELITE).
static func ordem(dados: Node) -> Array:
	return dados.lista("licencas").map(func(l): return String(l["id"]))


static func aberta(dados: Node, jogador: Node) -> bool:
	# Decisão 69: na campanha do dono a equipe nasce no começo (para contratar o
	# piloto); caixa, sede e patrocínio abrem com a International.
	return not dados.equipe().is_empty() and EquipeJogador.criada(jogador) \
			and (not EquipeJogador.exige_piloto(jogador) or jogador.flags.has("GESTAO_LIBERADA"))


## Patrocínio (decisão 85): no dono abre antes do resto da gestão, depois da
## primeira corrida com a licença Club (flag PATROCINIO_LIBERADO).
static func patrocinio_aberto(dados: Node, jogador: Node) -> bool:
	return aberta(dados, jogador) or (not dados.equipe().is_empty() and EquipeJogador.criada(jogador)
			and jogador.flags.has(FLAG_PATROCINIO))


const FLAG_PATROCINIO := "PATROCINIO_LIBERADO"


## Capacidade de renda offline (s), decisão 104: equipe.json →
## patrocinio.teto_offline_h_base e + teto_offline_h_por_titulo por série com
## título (jogador.titulos), mais as horas compradas na loja (Turno da Noite,
## decisão 105); é a duração de cada contrato. Sem a base nos dados, `duracao_h`.
static func teto_offline(dados: Node, jogador: Node) -> float:
	var cfg := config(dados)
	if cfg.get("teto_offline_h_base") == null:
		return float(cfg.get("duracao_h", 24)) * 3600.0
	return (float(cfg["teto_offline_h_base"]) + float(cfg.get("teto_offline_h_por_titulo", 0)) * jogador.titulos.size()
			+ LojaReal.horas_offline(dados, jogador)) * 3600.0


## Média do prêmio de 1º lugar das provas da licença (0 sem provas).
static func premio_referencia(dados: Node, licenca: String) -> int:
	var soma := 0
	var n := 0
	for ev in dados.lista("eventos"):
		if String(ev["restricoes"].get("licenca", "")) == licenca and not ev["premios"].is_empty():
			soma += int(ev["premios"][0])
			n += 1
	return soma / n if n > 0 else 0


static func maior_licenca(dados: Node, jogador: Node) -> int:
	var niveis := ordem(dados)
	var k := -1
	for l in jogador.licencas:
		k = maxi(k, niveis.find(String(l)))
	return k


# ------------------------------------------------------------------ Sede

static func nivel(jogador: Node, id: String) -> int:
	return int(jogador.equipe.get("sede", {}).get(id, 0))


static func melhoria(dados: Node, id: String) -> Dictionary:
	for m in dados.equipe().get("sede", []):
		if m["id"] == id:
			return m
	return {}


## Soma do efeito das melhorias compradas (hoje só "contratos").
static func efeito(dados: Node, jogador: Node, tipo: String) -> float:
	var t := 0.0
	for m in dados.equipe().get("sede", []):
		if m["efeito"] == tipo:
			t += float(m["por_nivel"]) * nivel(jogador, m["id"])
	return t


## Preço do próximo nível (0 se já no máximo).
static func preco_melhoria(dados: Node, jogador: Node, id: String) -> int:
	var m := melhoria(dados, id)
	var n := nivel(jogador, id)
	if m.is_empty() or n >= int(m["niveis"]):
		return 0
	var ref := premio_referencia(dados, String(dados.equipe().get("sede_licenca_custo", "INTERNATIONAL")))
	return roundi(ref * float(m["custo_fator"]) * (n + 1))


## Compra o próximo nível. "" ou o motivo.
static func comprar_melhoria(dados: Node, jogador: Node, id: String) -> String:
	var preco := preco_melhoria(dados, jogador, id)
	if preco <= 0:
		return "nível máximo"
	if not jogador.economia.debitar(preco):
		return "saldo insuficiente"
	var sede: Dictionary = jogador.equipe.get("sede", {})
	sede[id] = nivel(jogador, id) + 1
	jogador.equipe["sede"] = sede
	return ""


# ------------------------------------------------------------- Patrocínio

static func config(dados: Node) -> Dictionary:
	return dados.equipe().get("patrocinio", {})


static func patrocinador(dados: Node, id: String) -> Dictionary:
	for p in dados.patrocinadores():
		if p["id"] == id:
			return p
	return {}


static func contratos(jogador: Node) -> Array:
	return jogador.equipe.get("patrocinios", [])


static func vagas(dados: Node, jogador: Node) -> int:
	return int(config(dados).get("contratos_base", 1)) + int(efeito(dados, jogador, "contratos"))


## Renda por hora de um patrocinador.
static func renda_hora(dados: Node, _jogador: Node, p: Dictionary) -> int:
	if p.is_empty():  # patrocinador que saiu de patrocinadores.json
		return 0
	var ref := premio_referencia(dados, String(p["licenca"]))
	return roundi(ref * float(config(dados).get("renda_hora_fator", 0.0)))


## Bônus por corrida que cumpre a condição.
static func bonus(dados: Node, _jogador: Node, p: Dictionary) -> int:
	if p.is_empty():
		return 0
	var ref := premio_referencia(dados, String(p["licenca"]))
	# Decisão 100: condição mais difícil paga mais (equipe.json →
	# bonus_condicao, medido por tools/calibrar_bonus.gd; ausente vale 1).
	var mult := float(config(dados).get("bonus_condicao", {}).get(chave_condicao(p.get("condicao", {})), 1.0))
	return roundi(ref * float(config(dados).get("bonus_fator", 0.0)) * mult)


## Chave da condição em bonus_condicao: "vitoria", "podio", "etapa", "licenca:PRO".
static func chave_condicao(c: Dictionary) -> String:
	return String(c.get("tipo", "")) + (":" + String(c["valor"]) if c.has("valor") else "")


## Texto da condição do bônus.
static func texto_condicao(c: Dictionary) -> String:
	match String(c.get("tipo", "")):
		"vitoria":
			return "vencer uma prova"
		"podio":
			return "terminar no pódio"
		"etapa":
			return "subir ao pódio numa etapa de campeonato"
		"licenca":
			return "subir ao pódio numa prova %s" % String(c.get("valor", "")).capitalize()
	return ""


static func cumpre(c: Dictionary, ev: Dictionary, posicao: int, campeonato: bool) -> bool:
	match String(c.get("tipo", "")):
		"vitoria":
			return posicao == 1
		"podio":
			return posicao >= 1 and posicao <= 3
		"etapa":
			return campeonato and posicao >= 1 and posicao <= 3
		"licenca":
			return posicao >= 1 and posicao <= 3 and String(ev["restricoes"].get("licenca", "")) == String(c.get("valor", ""))
	return false


## Patrocinadores disponíveis (licença até a maior do jogador, sem os já
## contratados), o que mais paga por hora primeiro; no empate, sorteados pela
## semente (troca quando um contrato é assinado ou acaba), para variar a marca
## e a condição do bônus.
static func ofertas(dados: Node, jogador: Node) -> Array:
	var niveis := ordem(dados)
	var maior := maior_licenca(dados, jogador)
	var ativos: Array = contratos(jogador).map(func(c): return c["id"])
	var lista: Array = dados.patrocinadores().filter(func(p):
		return niveis.find(String(p["licenca"])) <= maior and not p["id"] in ativos)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(jogador.equipe.get("semente_ofertas", 0)) + 1
	var sorteio := {}
	var renda := {}
	for p in lista:
		sorteio[p["id"]] = rng.randf()
		renda[p["id"]] = renda_hora(dados, jogador, p)
	lista.sort_custom(func(a, b):
		return renda[a["id"]] > renda[b["id"]] if renda[a["id"]] != renda[b["id"]] else sorteio[a["id"]] < sorteio[b["id"]])
	return lista


## Sem escolha entre ofertas (decisão 124): cada vaga livre assina a primeira
## de ofertas(), a que mais paga por hora. Quem chama passa depois de acumular
## (o contrato vencido sai antes). Retorna os nomes assinados agora.
static func renovar(dados: Node, jogador: Node, agora: float) -> Array:
	var nomes := []
	if not patrocinio_aberto(dados, jogador):
		return nomes
	while contratos(jogador).size() < vagas(dados, jogador):
		var lista := ofertas(dados, jogador)
		if lista.is_empty() or assinar(dados, jogador, String(lista[0]["id"]), agora) != "":
			break
		nomes.append(String(lista[0]["nome"]))
	return nomes


## Assina o contrato (agora: segundos Unix). "" ou o motivo.
static func assinar(dados: Node, jogador: Node, id: String, agora: float) -> String:
	if contratos(jogador).size() >= vagas(dados, jogador):
		return "sem vaga para outro contrato"
	if patrocinador(dados, id).is_empty():
		return "patrocinador desconhecido"
	var dur := teto_offline(dados, jogador)
	var lista: Array = contratos(jogador)
	lista.append({"id": id, "inicio": agora, "fim": agora + dur, "ultimo": agora, "resto": 0.0, "ganho": 0})
	jogador.equipe["patrocinios"] = lista
	jogador.equipe["semente_ofertas"] = int(jogador.equipe.get("semente_ofertas", 0)) + 1
	MetaDia.registrar(jogador, "patrocinio")
	return ""


## Credita a renda por hora desde a última vez (até `agora`, segundos Unix,
## no máximo até o fim do contrato) e encerra os contratos vencidos.
## {ganho, encerrados: [nomes]}.
static func acumular(dados: Node, jogador: Node, agora: float) -> Dictionary:
	# fora_s: tempo desde o último pagamento; pago_s: quanto dele rendeu (o
	# contrato acaba no teto da renda offline). A tela de volta compara os dois.
	var r := {"ganho": 0, "encerrados": [], "fora_s": 0.0, "pago_s": 0.0}
	if not patrocinio_aberto(dados, jogador):
		return r
	var ficam := []
	for c in contratos(jogador):
		var p := patrocinador(dados, c["id"])
		var ate := minf(agora, float(c["fim"]))
		var dt := maxf(ate - float(c["ultimo"]), 0.0)
		r["fora_s"] = maxf(float(r["fora_s"]), agora - float(c["ultimo"]))
		r["pago_s"] = maxf(float(r["pago_s"]), dt)
		var valor := float(c.get("resto", 0.0)) + dt / 3600.0 * renda_hora(dados, jogador, p)
		var inteiro := int(floor(valor))
		c["resto"] = valor - inteiro
		c["ultimo"] = maxf(float(c["ultimo"]), ate)
		c["ganho"] = int(c.get("ganho", 0)) + inteiro
		r["ganho"] += inteiro
		if agora >= float(c["fim"]) or p.is_empty():
			r["encerrados"].append(String(p.get("nome", c["id"])))
		else:
			ficam.append(c)
	jogador.economia.creditar(int(r["ganho"]))
	if not r["encerrados"].is_empty():
		jogador.equipe["semente_ofertas"] = int(jogador.equipe.get("semente_ofertas", 0)) + 1
	jogador.equipe["patrocinios"] = ficam
	return r


## Bônus da corrida: cada contrato cuja condição a corrida cumpre. Credita e
## retorna [{nome, valor}].
static func bonus_corrida(dados: Node, jogador: Node, ev: Dictionary, posicao: int, campeonato: bool) -> Array:
	var pagos := []
	if not patrocinio_aberto(dados, jogador):
		return pagos
	for c in contratos(jogador):
		var p := patrocinador(dados, c["id"])
		if not p.is_empty() and cumpre(p.get("condicao", {}), ev, posicao, campeonato):
			var v := bonus(dados, jogador, p)
			jogador.economia.creditar(v)
			c["ganho"] = int(c.get("ganho", 0)) + v
			pagos.append({"nome": p["nome"], "valor": v})
	return pagos


# ------------------------------------------------------------------ Treino

## Nível de ritmo do piloto (decisão 54; decisão 70: por piloto). Sobe só com
## a experiência (EquipeJogador.apos_prova: um nível a cada xp_por_nivel
## provas), sem custo nem espera (decisão 124: o treino pago saiu). Teto pela
## maior licença (data/equipe.json → treino.teto, gerado por
## tools/calibrar_treino.py). `piloto_id` "" = o nível da equipe (jogo sem
## pilotos contratados). Estado: jogador.equipe[chave] = {nivel}.
static func cfg_treino(dados: Node) -> Dictionary:
	return dados.equipe().get("treino", {})


static func _chave(piloto_id: String) -> String:
	return "treino" if piloto_id == "" else "treino_" + piloto_id


static func nivel_treino(jogador: Node, piloto_id := "") -> int:
	return int(jogador.equipe.get(_chave(piloto_id), {}).get("nivel", 0))


## Ritmo com os níveis (a base sem gestão).
static func ritmo(dados: Node, jogador: Node, base: float, piloto_id := "") -> float:
	var t := cfg_treino(dados)
	if t.is_empty():
		return base
	return minf(base + float(t.get("passo", 0.0)) * nivel_treino(jogador, piloto_id), maxf(teto(dados, jogador), base))


## Teto da maior licença do jogador (sem teto para ela: sem ganho).
static func teto(dados: Node, jogador: Node) -> float:
	var tetos: Dictionary = cfg_treino(dados).get("teto", {})
	var niveis := ordem(dados)
	var k := maior_licenca(dados, jogador)
	while k >= 0:
		if tetos.has(niveis[k]):
			return float(tetos[niveis[k]])
		k -= 1
	return 0.0


## O próximo nível ainda sobe o ritmo (abaixo do teto)?
static func pode_subir(dados: Node, jogador: Node, base: float, piloto_id := "") -> bool:
	return aberta(dados, jogador) and not cfg_treino(dados).is_empty() \
			and base + float(cfg_treino(dados).get("passo", 0.0)) * nivel_treino(jogador, piloto_id) < teto(dados, jogador) - 1e-6
