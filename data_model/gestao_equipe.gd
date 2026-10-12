class_name GestaoEquipe
extends RefCounted
## Gestão da equipe do jogador (data/equipe.json; abre com a equipe, flag
## SECOND_DRIVER_CREATED): patrocínio, desmanche e sede. Estado em
## jogador.equipe; o crédito de peças fica na Economia.
##
## Patrocínio: ofertas dos patrocinadores (data/patrocinadores.json) de licença
## até a maior do jogador; um contrato rende por hora no relógio real, também
## com o app fechado (até teto_offline_s de ausência, como as corridas), por
## `duracao_h`, e paga um bônus a cada corrida que cumpre a condição dele.
## Valores: fatores sobre o prêmio de referência (média do 1º lugar das provas
## da licença do patrocinador); provisórios até o playtest.
## Desmanche: desmontar um carro (como vender: não o único, nem o da fila) vira
## crédito de peças pela soma das peças compradas para ele.
## Sede: melhorias com níveis (contratos, renda, bônus, desmanche).

## Licenças na ordem de licencas.json (CLUB → ELITE).
static func ordem(dados: Node) -> Array:
	return dados.lista("licencas").map(func(l): return String(l["id"]))


static func aberta(dados: Node, jogador: Node) -> bool:
	# Decisão 69: na campanha do dono a equipe nasce no começo (para contratar o
	# piloto); caixa, sede e patrocínio abrem com a International.
	return not dados.equipe().is_empty() and EquipeJogador.criada(jogador) \
			and (not EquipeJogador.exige_piloto(jogador) or jogador.flags.has("GESTAO_LIBERADA"))


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


## Soma do efeito das melhorias compradas ("contratos", "renda", "bonus", "desmanche").
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


## Renda por hora de um patrocinador, com o Marketing.
static func renda_hora(dados: Node, jogador: Node, p: Dictionary) -> int:
	var ref := premio_referencia(dados, String(p["licenca"]))
	return roundi(ref * float(config(dados).get("renda_hora_fator", 0.0)) * (1.0 + efeito(dados, jogador, "renda")))


## Bônus por corrida que cumpre a condição, com a Hospitalidade.
static func bonus(dados: Node, jogador: Node, p: Dictionary) -> int:
	var ref := premio_referencia(dados, String(p["licenca"]))
	return roundi(ref * float(config(dados).get("bonus_fator", 0.0)) * (1.0 + efeito(dados, jogador, "bonus")))


## Texto da condição do bônus.
static func texto_condicao(c: Dictionary) -> String:
	match String(c.get("tipo", "")):
		"vitoria":
			return "vencer uma prova"
		"podio":
			return "terminar no pódio"
		"etapa":
			return "pódio numa etapa de campeonato"
		"licenca":
			return "pódio numa prova %s" % String(c.get("valor", "")).capitalize()
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


## Ofertas abertas: patrocinadores de licença até a maior do jogador, sem os
## já contratados; os de licença mais alta primeiro, sorteados pela semente
## (troca quando um contrato é assinado ou acaba).
static func ofertas(dados: Node, jogador: Node) -> Array:
	var niveis := ordem(dados)
	var maior := maior_licenca(dados, jogador)
	var ativos: Array = contratos(jogador).map(func(c): return c["id"])
	var lista: Array = dados.patrocinadores().filter(func(p):
		return niveis.find(String(p["licenca"])) <= maior and not p["id"] in ativos)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(jogador.equipe.get("semente_ofertas", 0)) + 1
	var sorteio := {}
	for p in lista:
		sorteio[p["id"]] = rng.randf()
	lista.sort_custom(func(a, b):
		var ka := niveis.find(String(a["licenca"]))
		var kb := niveis.find(String(b["licenca"]))
		return ka > kb if ka != kb else sorteio[a["id"]] < sorteio[b["id"]])
	return lista.slice(0, int(config(dados).get("ofertas", 3)))


## Assina o contrato (agora: segundos Unix). "" ou o motivo.
static func assinar(dados: Node, jogador: Node, id: String, agora: float) -> String:
	if contratos(jogador).size() >= vagas(dados, jogador):
		return "sem vaga para outro contrato"
	if patrocinador(dados, id).is_empty():
		return "patrocinador desconhecido"
	var dur := float(config(dados).get("duracao_h", 24)) * 3600.0
	var lista: Array = contratos(jogador)
	lista.append({"id": id, "inicio": agora, "fim": agora + dur, "ultimo": agora, "resto": 0.0, "ganho": 0})
	jogador.equipe["patrocinios"] = lista
	jogador.equipe["semente_ofertas"] = int(jogador.equipe.get("semente_ofertas", 0)) + 1
	return ""


## Credita a renda por hora desde a última vez (até `agora`, segundos Unix),
## com o teto de ausência das corridas, e encerra os contratos vencidos.
## {ganho, encerrados: [nomes]}.
static func acumular(dados: Node, jogador: Node, agora: float) -> Dictionary:
	var r := {"ganho": 0, "encerrados": []}
	if not aberta(dados, jogador):
		return r
	var teto := float(dados.carreira().get("teto_offline_s", 28800))
	var ficam := []
	for c in contratos(jogador):
		var p := patrocinador(dados, c["id"])
		var ate := minf(agora, float(c["fim"]))
		var dt := clampf(ate - float(c["ultimo"]), 0.0, teto)
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
	if not aberta(dados, jogador):
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

## Treino do piloto (decisão 54; decisão 70: por piloto, como energia): níveis
## de ritmo, um por vez, no relógio real; teto pela maior licença
## (data/equipe.json → treino.teto, gerado por tools/calibrar_treino.gd).
## Começar o treino gasta a energia do piloto; ela volta enchendo durante o
## treino e o nível entra quando enche. `piloto_id` "" = o treino da equipe
## (jogo sem pilotos contratados). Estado: jogador.equipe[chave] = {nivel, fim
## (segundos Unix; 0 = parado), inicio}.
static func cfg_treino(dados: Node) -> Dictionary:
	return dados.equipe().get("treino", {})


static func _chave(piloto_id: String) -> String:
	return "treino" if piloto_id == "" else "treino_" + piloto_id


static func nivel_treino(jogador: Node, piloto_id := "") -> int:
	return int(jogador.equipe.get(_chave(piloto_id), {}).get("nivel", 0))


## Ritmo com o treino (a base sem gestão).
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
static func pode_treinar(dados: Node, jogador: Node, base: float, piloto_id := "") -> bool:
	return aberta(dados, jogador) and not cfg_treino(dados).is_empty() \
			and base + float(cfg_treino(dados).get("passo", 0.0)) * nivel_treino(jogador, piloto_id) < teto(dados, jogador) - 1e-6


static func treinando(jogador: Node, piloto_id := "") -> bool:
	return float(jogador.equipe.get(_chave(piloto_id), {}).get("fim", 0.0)) > 0.0


static func duracao_treino(dados: Node, jogador: Node, piloto_id := "") -> float:
	var d := float(cfg_treino(dados).get("tempo_base_h", 1.0)) * 3600.0 * (nivel_treino(jogador, piloto_id) + 1)
	if piloto_id != "" and EquipeJogador.em_embalo(jogador, piloto_id):
		d *= float(cfg_treino(dados).get("embalo_fator_tempo", 1.0))  # decisão 71: embalo
	return d


static func preco_treino(dados: Node, jogador: Node, piloto_id := "") -> int:
	var niveis := ordem(dados)
	var k := maior_licenca(dados, jogador)
	var ref := premio_referencia(dados, niveis[k]) if k >= 0 else 0
	return roundi(ref * float(cfg_treino(dados).get("custo_fator", 0.0)) * (nivel_treino(jogador, piloto_id) + 1))


## Começa o próximo nível (agora: segundos Unix). "" ou o motivo.
static func treinar(dados: Node, jogador: Node, base: float, agora: float, piloto_id := "") -> String:
	if treinando(jogador, piloto_id):
		return "já está treinando"
	if not pode_treinar(dados, jogador, base, piloto_id):
		return "no teto da licença"
	if not jogador.economia.debitar(preco_treino(dados, jogador, piloto_id)):
		return "saldo insuficiente"
	var t: Dictionary = jogador.equipe.get(_chave(piloto_id), {})
	t["nivel"] = nivel_treino(jogador, piloto_id)
	t["inicio"] = agora
	t["fim"] = agora + duracao_treino(dados, jogador, piloto_id)
	jogador.equipe[_chave(piloto_id)] = t
	jogador.equipe.erase("embalo_" + piloto_id)  # o embalo vale um treino
	return ""


## Energia do piloto (0..1): gasta ao começar o treino, volta enchendo até o
## fim dele. 1 = descansado.
static func energia(jogador: Node, piloto_id: String, agora: float) -> float:
	if not treinando(jogador, piloto_id):
		return 1.0
	var t: Dictionary = jogador.equipe[_chave(piloto_id)]
	var dur := maxf(float(t["fim"]) - float(t.get("inicio", t["fim"])), 1.0)
	return clampf(1.0 - (float(t["fim"]) - agora) / dur, 0.0, 1.0)


## Conclui os treinos que já terminaram (equipe e pilotos). true se algum subiu.
static func concluir_treino(jogador: Node, agora: float) -> bool:
	var subiu := false
	for k in jogador.equipe.keys():
		if not String(k).begins_with("treino"):
			continue
		var t = jogador.equipe[k]
		if not t is Dictionary or float(t.get("fim", 0.0)) <= 0.0 or agora < float(t["fim"]):
			continue
		t["nivel"] = int(t.get("nivel", 0)) + 1
		t["fim"] = 0.0
		subiu = true
	return subiu


# -------------------------------------------------------------- Desmanche

## Crédito de peças por desmontar o carro: as peças compradas para ele vezes
## o fator, com o Pátio de desmanche.
## Peças que um carro rende (desmontado, perdido ou destruído na arena):
## fator_pecas × (o que ele vale na revenda + as peças compradas para ele), com
## o bônus de desmanche da Sede. Sem número novo: o fator do desmanche e a
## fração de revenda já existem (equipe.json, economia.json).
static func pecas_do_carro(dados: Node, jogador: Node, carro: Carro) -> int:
	var soma := float(carro.base.get("preco", 0)) * float(dados.economia().get("fracao_revenda", 0.0))
	for pid in carro.pecas_possuidas:
		if dados.existe("pecas", pid):
			soma += int(dados.item("pecas", pid)["preco"])
	var f := float(dados.equipe().get("desmanche", {}).get("fator_pecas", 0.0))
	return roundi(soma * f * (1.0 + efeito(dados, jogador, "desmanche")))


static func credito_desmanche(dados: Node, jogador: Node, carro: Carro) -> int:
	return pecas_do_carro(dados, jogador, carro)


static func pode_desmontar(jogador: Node, uid: int) -> bool:
	var na_fila := int(jogador.fila.get("uid", -1)) if not jogador.fila.is_empty() else -1
	return jogador.concessionaria.pode_vender(uid) and uid != na_fila


## Desmonta: o carro sai da garagem e o crédito entra. Retorna o crédito (-1 se não pode).
static func desmontar(dados: Node, jogador: Node, uid: int) -> int:
	if not pode_desmontar(jogador, uid):
		return -1
	var carro: Carro = jogador.garagem.carro(uid)
	var credito := credito_desmanche(dados, jogador, carro)
	jogador.garagem.remover(uid)
	jogador.economia.ganhar_pecas(credito)
	jogador.equipe["desmontados"] = int(jogador.equipe.get("desmontados", 0)) + 1
	if jogador.carro_ativo == uid:
		var resto: Array = jogador.garagem.lista()
		jogador.carro_ativo = resto[0].uid if not resto.is_empty() else -1
	if jogador.carro_companheiro == uid:
		jogador.carro_companheiro = -1
	return credito
