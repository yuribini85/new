class_name IdleEstado
extends RefCounted
## The Fastfather (docs/idle/plano.md): o estado do jogo idle e as regras,
## sem tela. A corrida é a Simulacao do Chrome & Wreckage; os números vêm de
## data/idle/idle.json.
##
## Cinco modalidades (Compactos, Turismo, GT, Terra, Arena), cada uma com a
## categoria de carro, as pistas e a escada de ligas dela, liberadas uma a uma
## e rendendo ao mesmo tempo. O dinheiro é um só; a liga e os níveis das
## melhorias são de cada modalidade. `liga`, `venceu` e `niveis` são os da
## modalidade na tela (`modalidade`). Pilotos do Chrome & Wreckage chegam por
## contrato; dois do mesmo nível fundem num nível acima; cada modalidade escala
## um.

const ARQUIVO_CONFIG := "res://data/idle/idle.json"
const ARQUIVO_SAVE := "user://crt.json"

var cfg: Dictionary
var dinheiro := 0.0
var modalidade := ""  # a modalidade na tela
var mods := {}  # modalidade -> {liga, venceu, niveis: {melhoria: nível}, corridas}
var corridas := 0  # total, todas as modalidades
var pilotos: Array = []  # [{uid, id, nivel}]; id = piloto de data/equipes.json
var escalados := {}  # modalidade -> uid do piloto
var proximo_uid := 1
var contrato_em := 0.0  # unix (s): quando o próximo contrato grátis fica pronto
var videos_dia := ""  # dia (AAAA-MM-DD) dos contratos por vídeo contados
var videos_usados := 0
## Combustível adulterado (cfg "combustivel"): um vídeo dá potência a mais até
## `combustivel_ate` (unix, s), com usos contados por dia.
var combustivel_ate := 0.0
var combustivel_dia := ""
var combustivel_usos := 0
var salvo_em := 0.0  # unix (s), para a renda com o app fechado
## Metas do dia: {dia, tarefas: [ids], contagem: {tipo: n}, coletadas: [ids]}.
var metas := {}
var avisos_oferecidos := false  # a primeira liga nova já ligou os avisos
## O jogo que cresce com o jogador (idle.json → desbloqueios): o que já abriu e
## as conversas que já apareceram (oferta recusada fica no canto da corrida).
var desbloqueados: Array = []
var oferecidos: Array = []
var guias: Array = []  # dicas avulsas do tutorial leve já mostradas ("subir", "oferta")
var garagem: Array = []  # ids dos carros comprados (cfg "garagem")
## O primeiro carro saiu do ferro-velho (cfg "garagem" → "ferro_velho") e ainda
## não foi pintado: o Tony pinta depois da primeira vitória.
var ferro_velho := false

var liga: int:
	get:
		return int(_m()["liga"])
	set(v):
		_m()["liga"] = v
var venceu: bool:
	get:
		return bool(_m()["venceu"])
	set(v):
		_m()["venceu"] = v
var niveis: Dictionary:
	get:
		return _m()["niveis"]


static func config() -> Dictionary:
	var f := FileAccess.open(ARQUIVO_CONFIG, FileAccess.READ)
	return IdleEstado._normalizar(JSON.parse_string(f.get_as_text()) if f != null else {})


## Configuração antiga (uma escada de "ligas" só) vira uma modalidade única.
static func _normalizar(c: Dictionary) -> Dictionary:
	if c.has("ligas") and not c.has("modalidades"):
		c = c.duplicate(true)
		c["modalidades"] = [{"id": "unica", "nome": "", "ligas": c["ligas"]}]
		c.erase("ligas")
	return c


func _init(config_: Dictionary = {}) -> void:
	cfg = IdleEstado._normalizar(config_) if not config_.is_empty() else IdleEstado.config()
	dinheiro = float(cfg.get("dinheiro_inicial", 0.0))
	modalidade = String(cfg["modalidades"][0]["id"])
	_m()


## Estado da modalidade `id` (a da tela sem `id`), criado na primeira vez.
func _m(id := "") -> Dictionary:
	var k := id if id != "" else modalidade
	if not mods.has(k):
		var n := {}
		for m in cfg["melhorias"]:
			n[m["id"]] = 0
		mods[k] = {"liga": 0, "venceu": false, "niveis": n, "corridas": 0, "melhor": 0}
	return mods[k]


# --- modalidades ----------------------------------------------------------------

func dados_modalidade(id := "") -> Dictionary:
	var k := id if id != "" else modalidade
	for m in cfg["modalidades"]:
		if m["id"] == k:
			return m
	return {}


## A modalidade já abriu? A primeira sempre; as outras quando a anterior chega
## à liga de "libera".
func liberada(id: String) -> bool:
	var m := dados_modalidade(id)
	if m.is_empty():
		return false
	var lib: Dictionary = m.get("libera", {})
	if lib.is_empty():
		return true
	var antes := String(lib["modalidade"])
	return liberada(antes) and mods.has(antes) and int(mods[antes]["liga"]) >= int(lib["liga"])


func liberadas() -> Array:
	var r := []
	for m in cfg["modalidades"]:
		if liberada(String(m["id"])):
			r.append(String(m["id"]))
	return r


func trocar_modalidade(id: String) -> bool:
	if not liberada(id) or e_arena(id):
		return false  # a Rinha roda em paralelo, nunca no lugar da corrida
	modalidade = id
	_m()
	return true


# --- garagem --------------------------------------------------------------------

## Os carros à venda (um de época por divisão), na ordem das divisões.
func carros_garagem() -> Array:
	return cfg.get("garagem", [])


func carro_garagem(id: String) -> Dictionary:
	for c in carros_garagem():
		if String(c["id"]) == id:
			return c
	return {}


## O carro que a divisão pede ({} se a divisão corre sem comprar carro).
func carro_da_modalidade(mod := "") -> Dictionary:
	var m := modalidade if mod == "" else mod
	for c in carros_garagem():
		if String(c["modalidade"]) == m:
			return c
	return {}


func tem_carro(id: String) -> bool:
	return id in garagem


## A divisão na tela pode correr (tem o carro dela, ou não pede carro).
func pode_correr() -> bool:
	var c := carro_da_modalidade()
	return c.is_empty() or tem_carro(String(c["id"]))


## Preço na loja: o carro do ferro-velho sai pelo preço de sucata.
func preco_carro(c: Dictionary) -> float:
	if c.has("ferro_velho"):
		return float(c["ferro_velho"]["preco"])
	return float(c["preco"])


## Carro bloqueado na loja: a divisão dele ainda não abriu (vira silhueta).
func carro_bloqueado(c: Dictionary) -> bool:
	return not tem_carro(String(c["id"])) and not liberada(String(c["modalidade"]))


func comprar_carro(id: String) -> bool:
	var c := carro_garagem(id)
	if c.is_empty() or tem_carro(id) or dinheiro < preco_carro(c):
		return false
	dinheiro -= preco_carro(c)
	garagem.append(id)
	if c.has("ferro_velho"):
		ferro_velho = true
	return true


# --- melhorias ------------------------------------------------------------------

func melhoria(id: String) -> Dictionary:
	for m in cfg["melhorias"]:
		if m["id"] == id:
			return m
	return {}


func nivel(id: String, mod := "") -> int:
	return int(_m(mod)["niveis"].get(id, 0))


func no_maximo(id: String) -> bool:
	return nivel(id) >= int(melhoria(id)["max"])


## Custo do próximo nível: base × crescimento^nível × multiplicador da liga^expoente_custo_liga
## (acima de 1: cada liga pede mais tempo que a anterior).
func custo(id: String) -> float:
	return custo_no_nivel(id, nivel(id))


func pode_comprar(id: String) -> bool:
	return not no_maximo(id) and dinheiro >= custo(id)


func comprar(id: String) -> bool:
	if not pode_comprar(id):
		return false
	dinheiro -= custo(id)
	niveis[id] = nivel(id) + 1
	registrar_meta("melhorias")
	return true


## Custo do nível `k` (o que se paga para ir de k a k+1).
func custo_no_nivel(id: String, k: int) -> float:
	var m := melhoria(id)
	return roundf(float(m["base"]) * pow(float(m["crescimento"]), k)
			* pow(float(dados_liga()["multiplicador"]), float(cfg.get("expoente_custo_liga", 1.0))))


## Custo de `n` níveis seguidos a partir do atual (para +10). Passa do máximo: INF.
func custo_varios(id: String, n: int) -> float:
	if nivel(id) + n > int(melhoria(id)["max"]):
		return INF
	var total := 0.0
	for k in n:
		total += custo_no_nivel(id, nivel(id) + k)
	return total


## Quantos níveis o dinheiro paga agora, até o máximo (para MÁX.).
func niveis_pagaveis(id: String) -> int:
	var maximo := int(melhoria(id)["max"])
	var resto := dinheiro
	var n := 0
	while nivel(id) + n < maximo:
		var c := custo_no_nivel(id, nivel(id) + n)
		if c > resto:
			break
		resto -= c
		n += 1
	return n


## Compra `n` níveis de uma vez (só se pagar todos); devolve quantos comprou.
func comprar_varios(id: String, n: int) -> int:
	if n <= 0 or dinheiro < custo_varios(id, n):
		return 0
	for k in n:
		comprar(id)
	return n


## Soma dos efeitos de um tipo ("potencia", "renda"...) nos níveis comprados da
## modalidade `mod` (a da tela sem `mod`).
func efeito(tipo: String, niveis_extra := {}, mod := "") -> float:
	var total := 0.0
	for m in cfg["melhorias"]:
		if m["efeito"] == tipo:
			total += float(m["por_nivel"]) * (nivel(m["id"], mod) + int(niveis_extra.get(m["id"], 0)))
	return total


# --- ligas, prêmios e renda -----------------------------------------------------

func dados_liga(mod := "") -> Dictionary:
	return dados_modalidade(mod)["ligas"][int(_m(mod)["liga"])]


func ultima_liga() -> bool:
	return liga >= dados_modalidade()["ligas"].size() - 1


## Renda por segundo: patrocínio e arquibancada de cada modalidade aberta, no
## tamanho da liga dela.
func renda_s() -> float:
	var total := 0.0
	for id in liberadas():
		total += renda_modalidade(id)
	return total


## A renda base só corre depois que o jogador conhece a renda (o patrocínio da
## escada): antes disso o dinheiro vem só das corridas.
func renda_modalidade(id: String) -> float:
	var base := float(cfg.get("renda_base", 0.0)) if tem("renda") else 0.0
	return (base + efeito("renda", {}, id)) * float(dados_liga(id)["multiplicador"])


## Prêmio da posição `pos` (1 = vitória) na liga atual.
func premio(pos: int) -> float:
	var n := int(cfg["grid"])
	return roundf(float(cfg["premio_p1"]) * float(dados_liga()["multiplicador"]) * float(n + 1 - pos) / n)


## A corrida terminou em `pos`: o prêmio entra e a vitória libera a próxima liga.
func concluir(pos: int, fator := 1.0) -> float:
	var p := premio(pos) * fator
	dinheiro += p
	corridas += 1
	_m()["corridas"] = int(_m()["corridas"]) + 1
	if melhor_posicao() == 0 or pos < melhor_posicao():
		_m()["melhor"] = pos
	if pos == 1:
		venceu = true
	registrar_meta("corridas")
	if pos == 1:
		registrar_meta("vitorias")
	return p


## A melhor chegada na liga atual da modalidade (0: ainda não correu nela).
func melhor_posicao() -> int:
	return int(_m().get("melhor", 0))


func pode_subir() -> bool:
	return venceu and not ultima_liga()


func subir_liga() -> bool:
	if not pode_subir():
		return false
	liga += 1
	venceu = false
	_m()["melhor"] = 0
	# Carro novo: as melhorias do carro (motor, pneus) recomeçam; as da equipe ficam.
	for m in cfg["melhorias"]:
		if m.get("do_carro", false):
			niveis[m["id"]] = 0
	registrar_meta("ligas")
	return true


## Renda acumulada com o app fechado desde `salvo_em` (até offline_max_h).
func ganho_offline(agora: float) -> float:
	if salvo_em <= 0.0:
		return 0.0
	var dt := clampf(agora - salvo_em, 0.0, float(cfg["offline_max_h"]) * 3600.0)
	return renda_s() * dt


# --- pilotos --------------------------------------------------------------------

func cfg_pilotos() -> Dictionary:
	return cfg.get("pilotos", {})


## Pilotos que um contrato pode trazer: os das equipes do Chrome & Wreckage.
static func pilotos_disponiveis(dados: Node) -> Array:
	var r := []
	for e in dados.lista("equipes"):
		for p in e.get("pilotos", []):
			r.append(p)
	return r


static func dados_piloto(dados: Node, id: String) -> Dictionary:
	for p in IdleEstado.pilotos_disponiveis(dados):
		if String(p["id"]) == id:
			return p
	return {}


func piloto(uid: int) -> Dictionary:
	for p in pilotos:
		if int(p["uid"]) == uid:
			return p
	return {}


## O piloto escalado na modalidade ({} sem piloto).
func piloto_escalado(mod := "") -> Dictionary:
	return piloto(int(escalados.get(mod if mod != "" else modalidade, -1)))


func escalar(mod: String, uid: int) -> void:
	for k in escalados.keys():
		if int(escalados[k]) == uid:
			escalados.erase(k)
	escalados[mod] = uid


## Um contrato: um piloto no nível 1, sorteado com `semente`. Sem piloto na
## modalidade da tela, ele já entra nela.
func contratar(dados: Node, semente: int) -> Dictionary:
	var todos := IdleEstado.pilotos_disponiveis(dados)
	if todos.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var p := {"uid": proximo_uid, "id": String(todos[rng.randi() % todos.size()]["id"]), "nivel": 1}
	proximo_uid += 1
	pilotos.append(p)
	if piloto_escalado().is_empty():
		escalar(modalidade, int(p["uid"]))
	registrar_meta("contratos")
	return p


## Contrato grátis pronto agora (`agora`, unix)?
func contrato_gratis_pronto(agora: float) -> bool:
	return agora >= contrato_em


func usar_contrato_gratis(dados: Node, agora: float) -> Dictionary:
	if not contrato_gratis_pronto(agora):
		return {}
	contrato_em = agora + float(cfg_pilotos().get("contrato_gratis_h", 4.0)) * 3600.0
	return contratar(dados, int(agora))


# --- combustível adulterado (bônus por vídeo) -----------------------------------

func cfg_combustivel() -> Dictionary:
	return cfg.get("combustivel", {})


func bonus_combustivel() -> float:
	return float(cfg_combustivel().get("potencia", 0.0))


func combustivel_ativo(agora: float) -> bool:
	return agora < combustivel_ate


## Usos que ainda restam hoje (`dia`: AAAA-MM-DD).
func combustivel_restantes(dia: String) -> int:
	var usados := combustivel_usos if combustivel_dia == dia else 0
	return maxi(int(cfg_combustivel().get("usos_dia", 0)) - usados, 0)


## Depois do vídeo: liga o bônus por "duracao_s" (somando ao que ainda resta).
func usar_combustivel(agora: float, dia: String) -> bool:
	if combustivel_restantes(dia) <= 0:
		return false
	if combustivel_dia != dia:
		combustivel_dia = dia
		combustivel_usos = 0
	combustivel_usos += 1
	combustivel_ate = maxf(combustivel_ate, agora) + float(cfg_combustivel().get("duracao_s", 0.0))
	return true


## Contratos por vídeo que ainda restam hoje (`dia`: AAAA-MM-DD).
func contratos_video_restantes(dia: String) -> int:
	var usados := videos_usados if videos_dia == dia else 0
	return maxi(int(cfg_pilotos().get("contratos_video_dia", 0)) - usados, 0)


func usar_contrato_video(dados: Node, dia: String, semente: int) -> Dictionary:
	if contratos_video_restantes(dia) <= 0:
		return {}
	if videos_dia != dia:
		videos_dia = dia
		videos_usados = 0
	videos_usados += 1
	return contratar(dados, semente)


## Dois pilotos do mesmo nível fundem: `fica` sobe um nível e `sai` deixa a
## equipe (a escalação de `sai` passa para `fica`, se ele estava livre).
func pode_fundir(fica: int, sai: int) -> bool:
	var a := piloto(fica)
	var b := piloto(sai)
	return fica != sai and not a.is_empty() and not b.is_empty() and int(a["nivel"]) == int(b["nivel"]) \
			and int(a["nivel"]) < int(cfg_pilotos().get("nivel_max", 1))


func fundir(fica: int, sai: int) -> bool:
	if not pode_fundir(fica, sai):
		return false
	var a := piloto(fica)
	a["nivel"] = int(a["nivel"]) + 1
	var mod_sai := ""
	for k in escalados.keys():
		if int(escalados[k]) == sai:
			mod_sai = k
	pilotos.erase(piloto(sai))
	if mod_sai != "":
		escalados.erase(mod_sai)
		if not escalados.values().has(fica):
			escalados[mod_sai] = fica
	registrar_meta("fusoes")
	return true


## Atributos de corrida do piloto: a base, o perfil dele (agressivo,
## equilibrado, cauteloso, como no Chrome & Wreckage) e o ritmo do nível.
func atributos_piloto(dados: Node, p: Dictionary) -> Dictionary:
	var cp := cfg_pilotos()
	var base: Dictionary = cp.get("base", cfg.get("piloto", {"ritmo": 1.0, "consistencia": 0.9, "agressividade": 0.5}))
	var r := {"ritmo": float(base["ritmo"]), "consistencia": float(base["consistencia"]),
			"agressividade": float(base["agressividade"])}
	if p.is_empty():
		return r
	var perfil: Dictionary = cp.get("perfis", {}).get(String(IdleEstado.dados_piloto(dados, String(p["id"])).get("perfil", "")), {})
	r["agressividade"] += float(perfil.get("agressividade", 0.0))
	r["consistencia"] += float(perfil.get("consistencia", 0.0))
	r["ritmo"] += float(cp.get("ritmo_por_nivel", 0.0)) * (int(p["nivel"]) - 1)
	return r


# --- grid e corrida -------------------------------------------------------------

## Carros da frota das `categorias` (todas sem lista), ordenados pela distância
## em potência de `alvo` (só os que têm preço: modelos de loja).
static func _perto_de(dados: Node, alvo: float, categorias: Array = []) -> Array:
	var lista: Array = dados.lista("carros").filter(func(c): return c.get("preco") != null \
			and (categorias.is_empty() or categorias.has(c.get("categoria"))))
	lista.sort_custom(func(a, b):
		var da := absf(log(float(a["potencia"]) / alvo))
		var db := absf(log(float(b["potencia"]) / alvo))
		return da < db if da != db else String(a["id"]) < String(b["id"]))
	return lista


func _categorias() -> Array:
	return dados_modalidade().get("categorias", [])


## O carro da equipe nesta liga (decisão: um carro novo a cada liga), da
## categoria da modalidade.
func carro_base(dados: Node) -> Dictionary:
	return IdleEstado._perto_de(dados, float(dados_liga()["potencia"]) * float(cfg["carro_do_jogador"]), _categorias())[0]


## Pilotos e equipes dos rivais da liga (as equipes rivais do Chrome &
## Wreckage, data/equipes.json): [{nome, equipe, vaga}] na ordem de rivais(),
## fixos por modalidade e liga (no Race Star você enfrenta os mesmos rivais até
## subir).
func escalacao(dados: Node) -> Array:
	var equipes := []
	for e in dados.lista("equipes"):
		if not e.get("jogador", false) and not Array(e.get("pilotos", [])).is_empty():
			equipes.append(e)
	var r := []
	if equipes.is_empty():
		return r
	var k_mod := 0
	for i in cfg["modalidades"].size():
		if cfg["modalidades"][i]["id"] == modalidade:
			k_mod = i
	var l := liga + k_mod * 3
	for k in int(cfg["grid"]) - 1:
		# Passo primo com a lista: equipes diferentes no mesmo grid.
		var eq: Dictionary = equipes[(l * 5 + k * 7) % equipes.size()]
		var lista: Array = eq["pilotos"]
		var vaga := (l + k) % lista.size()
		r.append({"nome": String(lista[vaga]["nome"]), "equipe": eq, "vaga": vaga})
	return r


## Força do rival `k` (0 = o mais forte, na frente do grid) em relação ao
## carro da liga: de (1 + espalhar) a (1 - espalhar), para cada melhoria render
## posições aos poucos (no Race Star você sobe um a um), vezes a forca_rivais da
## pista na modalidade (acerta a pista: com poucas retas é mais difícil passar).
func fator_rival(k: int) -> float:
	var n := int(cfg["grid"]) - 1
	var forca := float(dados_liga().get("forca_rivais",
			dados_modalidade().get("forca_rivais", {}).get(String(dados_liga()["pista"]), 1.0)))
	return forca * (1.0 + float(cfg["rivais"].get("espalhar", 0.0)) * (1.0 - 2.0 * k / maxf(n - 1, 1)))


## Os modelos dos rivais da liga (só a aparência: a ficha de corrida sai do
## carro da equipe, ver participantes).
func rivais(dados: Node) -> Array:
	var usados := {String(carro_base(dados)["id"]): true}
	var n := int(cfg["grid"]) - 1
	var r := []
	for k in n:
		var alvo := float(dados_liga()["potencia"]) * fator_rival(k)
		for c in IdleEstado._perto_de(dados, alvo, _categorias()):
			if not usados.has(String(c["id"])):
				usados[String(c["id"])] = true
				r.append(c)
				break
	return r


static func _atributos(dados: Node, base: Dictionary) -> Dictionary:
	var c := Carro.new(base)
	c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	return c.atributos_efetivos("seco")


## Participantes da Simulacao: os rivais na frente, você em último (como no
## Race Star); as melhorias no seu carro e o seu piloto escalado. A ficha de
## cada rival é a do carro da equipe com a potência × fator_rival (e a aderência
## na proporção aderencia_por_forca, como Pneus × Motor): a dificuldade de cada
## liga fica igual, sem depender do peso e da aderência de cada modelo da
## frota. `niveis_extra` simula níveis a mais (calibrador).
func participantes(dados: Node, niveis_extra := {}) -> Array:
	var r := []
	var pr: Dictionary = cfg["rivais"]
	var modelos := rivais(dados)
	for k in modelos.size():
		var ficha: Dictionary = carro_base(dados).duplicate(true)
		ficha["potencia"] = float(ficha["potencia"]) * fator_rival(k)
		ficha["aderencia"] = float(ficha["aderencia"]) * (1.0 + float(pr.get("aderencia_por_forca", 0.0)) * (fator_rival(k) - 1.0))
		r.append({"id": "r%d" % k, "carro": modelos[k]["id"], "atributos": IdleEstado._atributos(dados, ficha),
				"piloto": {"ritmo": float(pr["ritmo"]) + float(pr.get("ritmo_por_liga", 0.0)) * liga,
					"consistencia": pr["consistencia"], "agressividade": pr["agressividade"], "regular": true}})
	var base: Dictionary = carro_base(dados).duplicate(true)
	base["potencia"] = float(base["potencia"]) * (1.0 + efeito("potencia", niveis_extra)
			+ (bonus_combustivel() if combustivel_ativo(Time.get_unix_time_from_system()) else 0.0))
	base["aderencia"] = float(base["aderencia"]) * (1.0 + efeito("aderencia", niveis_extra))
	# The Fastfather: quem corre é sempre o sobrinho (o piloto base); os rapazes
	# contratados lutam na Rinha.
	var pj := atributos_piloto(dados, piloto_escalado() if e_arena() else {})
	r.append({"id": "jogador", "carro": carro_base(dados)["id"], "atributos": IdleEstado._atributos(dados, base),
			"piloto": {"ritmo": pj["ritmo"], "consistencia": clampf(pj["consistencia"], 0.0, 1.0),
				"agressividade": clampf(float(pj["agressividade"]) + efeito("agressividade", niveis_extra), 0.0, 1.0),
				"vacuo": efeito("vacuo", niveis_extra), "regular": true,
				"fase": 0.5}})
	return r


## A pista da liga com toda reta como zona de ultrapassagem: no idle a
## ultrapassagem é o centro do jogo (com as zonas do Chrome & Wreckage, numa
## volta, nem o carro muito mais forte passava os 9 rivais).
func pista(dados: Node) -> Pista:
	var d: Dictionary = dados.item("pistas", dados_liga()["pista"]).duplicate(true)
	for t in d["trechos"]:
		if float(t.get("raio_m", 0.0)) <= 0.0:
			t["ultrapassagem"] = true
	return Pista.new(d)


## A corrida da liga, resolvida inteira (a tela mostra as amostras). Na
## Arena, a luta da simulação de arena do Chrome & Wreckage.
func correr(dados: Node, semente: int, com_amostras := true, niveis_extra := {}) -> Dictionary:
	if e_arena():
		return correr_arena(dados, semente, com_amostras, niveis_extra)
	return Simulacao.correr(pista(dados), participantes(dados, niveis_extra), int(dados_liga()["voltas"]),
			dados.simulacao(), semente, com_amostras)


func e_arena(mod := "") -> bool:
	return String(dados_modalidade(mod).get("tipo", "")) == "arena"


## Parâmetros da arena do Chrome & Wreckage (data/arena.json) com a forma da
## arena da liga.
func params_arena(dados: Node) -> Dictionary:
	var p: Dictionary = dados.arena().duplicate(true)
	for a in p.get("arenas", []):
		if String(a["id"]) == String(dados_liga()["pista"]):
			p["forma"] = a
	return p


## A luta da liga: todos contra todos (cada carro é a própria equipe); a
## classificação é a ordem de quem ficou de pé. Na Arena, o Vácuo vira
## blindagem: o carro mais pesado aguenta mais (Arena: resistência pela massa);
## o rival mais forte ganha peso na mesma proporção da aderência.
func correr_arena(dados: Node, semente: int, com_amostras := true, niveis_extra := {}) -> Dictionary:
	var parts := participantes(dados, niveis_extra)
	var blindagem := float(dados_modalidade().get("blindagem_por_vacuo", 0.0))
	var peso_forca := float(cfg["rivais"].get("aderencia_por_forca", 0.0))
	for k in parts.size():
		var p: Dictionary = parts[k]
		p["equipe"] = p["id"]
		if p["id"] == "jogador":
			p["atributos"]["peso"] = float(p["atributos"]["peso"]) * (1.0 + blindagem * efeito("vacuo", niveis_extra))
		else:
			# Rival mais forte também é mais pesado: na arena o peso é a resistência.
			p["atributos"]["peso"] = float(p["atributos"]["peso"]) * (1.0 + peso_forca * (fator_rival(k) - 1.0))
	return Arena.correr(parts, params_arena(dados), semente, com_amostras)


# --- Rinha das Famílias (a arena, em paralelo com a corrida) ----------------------
# The Fastfather (pedido do usuário, 2026-10-27): quem corre é sempre o
# sobrinho; os rapazes contratados lutam na Rinha, que roda o tempo todo ao lado
# da corrida (a corrida é o idle, assistir à Rinha é o tempero). Sem compras
# próprias: o carro dos rapazes leva as melhorias da corrida, a liga da Rinha
# acompanha a liga mais alta das corridas e luta o rapaz de nível mais alto.

## A modalidade da Rinha ("" se não houver).
func id_rinha() -> String:
	for m in cfg["modalidades"]:
		if String(m.get("tipo", "")) == "arena":
			return String(m["id"])
	return ""


func rinha_aberta() -> bool:
	var r := id_rinha()
	return r != "" and liberada(r)


## A liga da Rinha: a mais alta entre as corridas abertas.
func liga_rinha() -> int:
	var r := id_rinha()
	var maior := 0
	for id in liberadas():
		if id != r:
			maior = maxi(maior, int(_m(id)["liga"]))
	return mini(maior, dados_modalidade(r)["ligas"].size() - 1)


## O rapaz de nível mais alto (o que vai para a Rinha).
func melhor_rapaz() -> Dictionary:
	var melhor := {}
	for p in pilotos:
		if melhor.is_empty() or int(p["nivel"]) > int(melhor["nivel"]):
			melhor = p
	return melhor


## Roda `f` com a Rinha no lugar da corrida (liga, melhorias e rapaz arrumados)
## e volta tudo como estava.
func _na_rinha(f: Callable) -> Variant:
	var r := id_rinha()
	var corrida := modalidade
	var niveis_corrida: Dictionary = _m()["niveis"].duplicate()
	modalidade = r
	_m()["liga"] = liga_rinha()
	_m()["niveis"] = niveis_corrida
	var rapaz := melhor_rapaz()
	if not rapaz.is_empty():
		escalados[r] = int(rapaz["uid"])
	var v = f.call()
	modalidade = corrida
	return v


## Uma luta da Rinha, resolvida inteira (a aba RINHA mostra as amostras).
func lutar_rinha(dados: Node, semente: int, com_amostras := true) -> Dictionary:
	if not rinha_aberta():
		return {}
	return _na_rinha(func(): return correr_arena(dados, semente, com_amostras))


## O prêmio da luta pela posição (não conta como corrida do sobrinho).
func pagar_rinha(pos: int) -> float:
	if not rinha_aberta():
		return 0.0
	return float(_na_rinha(func():
		var p := premio(pos)
		dinheiro += p
		_m()["corridas"] = int(_m()["corridas"]) + 1
		if melhor_posicao() == 0 or pos < melhor_posicao():
			_m()["melhor"] = pos
		return p))


# --- metas do dia ---------------------------------------------------------------
# A cada dia (meia-noite do aparelho, como a Meta do dia do Chrome & Wreckage)
# saem meta_dia.por_dia tarefas de data/idle/idle.json, sorteadas pela data.
# Cada uma conta um tipo de ação (corridas, vitórias, melhorias, contratos,
# fusões, ligas) e, cumprida, paga meta_dia.recompensa_min minutos da renda.

func cfg_metas() -> Dictionary:
	return cfg.get("meta_dia", {})


## As metas de hoje (dia novo: tarefas sorteadas, contagem zerada).
func metas_do_dia(agora: float = Time.get_unix_time_from_system()) -> Dictionary:
	var d := MetaDia.dia(agora)
	if String(metas.get("dia", "")) != d:
		metas = {"dia": d, "tarefas": _sortear_metas(d), "contagem": {}, "coletadas": []}
	return metas


func _sortear_metas(d: String) -> Array:
	var pool: Array = cfg_metas().get("tarefas", []).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("metas|" + d)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = pool[i]
		pool[i] = pool[j]
		pool[j] = x
	return pool.slice(0, int(cfg_metas().get("por_dia", 3))).map(func(t): return String(t["id"]))


func tarefa_meta(id: String) -> Dictionary:
	for t in cfg_metas().get("tarefas", []):
		if String(t["id"]) == id:
			return t
	return {}


## Conta uma ação do tipo no dia de `agora`.
func registrar_meta(tipo: String, n := 1, agora: float = Time.get_unix_time_from_system()) -> void:
	if cfg_metas().is_empty():
		return
	var c: Dictionary = metas_do_dia(agora)["contagem"]
	c[tipo] = int(c.get(tipo, 0)) + n


## [feito, meta] da tarefa hoje.
func progresso_meta(id: String, agora: float = Time.get_unix_time_from_system()) -> Array:
	var t := tarefa_meta(id)
	var meta := int(t.get("quantidade", 1))
	return [mini(int(metas_do_dia(agora)["contagem"].get(String(t.get("tipo", "")), 0)), meta), meta]


func recompensa_meta() -> float:
	return roundf(renda_s() * float(cfg_metas().get("recompensa_min", 0.0)) * 60.0)


func meta_pronta(id: String, agora: float = Time.get_unix_time_from_system()) -> bool:
	var est := metas_do_dia(agora)
	var p := progresso_meta(id, agora)
	return id in est["tarefas"] and not id in est["coletadas"] and p[0] >= p[1]


## Quantas metas cumpridas esperam a coleta.
func metas_prontas(agora: float = Time.get_unix_time_from_system()) -> int:
	var n := 0
	for id in metas_do_dia(agora)["tarefas"]:
		if meta_pronta(String(id), agora):
			n += 1
	return n


## Coleta a recompensa da meta cumprida; devolve o valor (0: não deu).
func coletar_meta(id: String, agora: float = Time.get_unix_time_from_system()) -> float:
	if not meta_pronta(id, agora):
		return 0.0
	var v := recompensa_meta()
	metas["coletadas"].append(id)
	dinheiro += v
	return v


# --- desbloqueios ----------------------------------------------------------------
# O jogo começa quase vazio (vista de cima, só o Motor, largada no toque) e cada
# passo abre com a conversa de um personagem quando a condição se cumpre, na
# ordem da lista. Sem "desbloqueios" na configuração, tudo está aberto.

func cfg_desbloqueios() -> Array:
	return cfg.get("desbloqueios", [])


func desbloqueio(id: String) -> Dictionary:
	for d in cfg_desbloqueios():
		if String(d["id"]) == id:
			return d
	return {}


## O jogo já tem `coisa` ("melhoria:pneus", "aba:pilotos", "renda",
## "largada_auto", "camera_tv", "cameras", "previsao")?
func tem(coisa: String) -> bool:
	if cfg_desbloqueios().is_empty() or coisa in cfg.get("desbloqueio_inicial", []):
		return true
	for d in cfg_desbloqueios():
		if String(d["id"]) in desbloqueados and coisa in d.get("libera", []):
			return true
	return false


## Soma das ligas (índice) das modalidades abertas: quanto a equipe já subiu.
func liga_total() -> int:
	var n := 0
	for id in liberadas():
		n += int(_m(id)["liga"])
	return n


func condicao_ok(d: Dictionary) -> bool:
	var q: Dictionary = d.get("quando", {})
	if corridas < int(q.get("corridas", 0)) or liga_total() < int(q.get("liga_total", 0)):
		return false
	if garagem.size() < int(q.get("carros", 0)):
		return false
	if q.has("modalidade") and not liberada(String(q["modalidade"])):
		return false
	if bool(q.get("vitoria", false)):
		var ganhou := liga_total() > 0
		for id in liberadas():
			ganhou = ganhou or bool(_m(id)["venceu"])
		if not ganhou:
			return false
	return true


## A próxima conversa a mostrar: o primeiro item ainda não oferecido, se a
## condição dele já se cumpriu (um de cada vez, na ordem da lista; as avulsas
## passam na frente).
func proxima_conversa() -> Dictionary:
	# As avulsas ("avulsa": true) não esperam a fila: aparecem quando a condição
	# delas se cumpre (a cena da primeira vitória).
	for d in cfg_desbloqueios():
		if bool(d.get("avulsa", false)) and not String(d["id"]) in oferecidos and condicao_ok(d):
			return d
	for d in cfg_desbloqueios():
		if bool(d.get("avulsa", false)):
			continue
		if String(d["id"]) in oferecidos:
			continue
		return d if condicao_ok(d) else {}
	return {}


## A conversa apareceu: o que é de graça abre na hora; o que tem custo vira
## oferta até o jogador comprar.
func oferecer(id: String) -> void:
	if not id in oferecidos:
		oferecidos.append(id)
	if float(desbloqueio(id).get("custo", 0.0)) <= 0.0 and not id in desbloqueados:
		desbloqueados.append(id)


## Ofertas recusadas (DEPOIS), que esperam no canto da corrida.
func ofertas_abertas() -> Array:
	return cfg_desbloqueios().filter(func(d): return String(d["id"]) in oferecidos and not String(d["id"]) in desbloqueados)


func comprar_desbloqueio(id: String) -> bool:
	var d := desbloqueio(id)
	var custo := float(d.get("custo", 0.0))
	if d.is_empty() or id in desbloqueados or dinheiro < custo:
		return false
	dinheiro -= custo
	desbloqueados.append(id)
	if not id in oferecidos:
		oferecidos.append(id)
	return true


static func posicao(resultado: Dictionary) -> int:
	return Array(resultado["classificacao"]).find("jogador") + 1


# --- salvar ---------------------------------------------------------------------

func para_save() -> Dictionary:
	return {"versao": 2, "dinheiro": dinheiro, "modalidade": modalidade, "mods": mods, "corridas": corridas,
			"pilotos": pilotos, "escalados": escalados, "proximo_uid": proximo_uid, "contrato_em": contrato_em,
			"videos_dia": videos_dia, "videos_usados": videos_usados, "salvo_em": salvo_em, "metas": metas,
			"avisos_oferecidos": avisos_oferecidos, "desbloqueados": desbloqueados, "oferecidos": oferecidos,
			"guias": guias, "garagem": garagem, "ferro_velho": ferro_velho, "combustivel_ate": combustivel_ate,
			"combustivel_dia": combustivel_dia, "combustivel_usos": combustivel_usos}


func de_save(s: Dictionary) -> void:
	dinheiro = float(s.get("dinheiro", dinheiro))
	corridas = int(s.get("corridas", 0))
	salvo_em = float(s.get("salvo_em", 0.0))
	var salvos: Dictionary = s.get("mods", {})
	if not s.has("mods"):
		# Save da versão de uma modalidade só: vira a primeira.
		salvos = {String(cfg["modalidades"][0]["id"]): {"liga": s.get("liga", 0), "venceu": s.get("venceu", false),
				"niveis": s.get("niveis", {}), "corridas": s.get("corridas", 0)}}
	for id in salvos:
		if dados_modalidade(String(id)).is_empty():
			continue
		var m := _m(String(id))
		var sm: Dictionary = salvos[id]
		m["liga"] = clampi(int(sm.get("liga", 0)), 0, dados_modalidade(String(id))["ligas"].size() - 1)
		m["venceu"] = bool(sm.get("venceu", false))
		m["corridas"] = int(sm.get("corridas", 0))
		m["melhor"] = int(sm.get("melhor", 1 if m["venceu"] else 0))
		for k in sm.get("niveis", {}):
			if m["niveis"].has(k):
				m["niveis"][k] = int(sm["niveis"][k])
	var mod := String(s.get("modalidade", modalidade))
	if liberada(mod) and not e_arena(mod):  # quem estava na arena volta para a corrida
		modalidade = mod
	pilotos = []
	for p in s.get("pilotos", []):
		pilotos.append({"uid": int(p["uid"]), "id": String(p["id"]), "nivel": int(p["nivel"])})
	escalados = {}
	for k in s.get("escalados", {}):
		escalados[String(k)] = int(s["escalados"][k])
	proximo_uid = int(s.get("proximo_uid", 1))
	contrato_em = float(s.get("contrato_em", 0.0))
	videos_dia = String(s.get("videos_dia", ""))
	videos_usados = int(s.get("videos_usados", 0))
	combustivel_ate = float(s.get("combustivel_ate", 0.0))
	combustivel_dia = String(s.get("combustivel_dia", ""))
	combustivel_usos = int(s.get("combustivel_usos", 0))
	avisos_oferecidos = bool(s.get("avisos_oferecidos", false))
	desbloqueados = Array(s.get("desbloqueados", [])).map(func(x): return String(x))
	oferecidos = Array(s.get("oferecidos", [])).map(func(x): return String(x))
	if not s.has("ferro_velho") and corridas > 0:
		# Save de antes do The Fastfather: as cenas do Tony do começo já passaram.
		for id in ["tony_ultimo", "tony_vitoria"]:
			if not id in oferecidos:
				oferecidos.append(id)
	guias = Array(s.get("guias", [])).map(func(x): return String(x))
	ferro_velho = bool(s.get("ferro_velho", false))
	garagem = Array(s.get("garagem", [])).map(func(x): return String(x)).filter(func(x): return not carro_garagem(x).is_empty())
	if not s.has("garagem") and corridas > 0:
		# Save de antes da garagem: as divisões em que a equipe já correu vêm com o carro.
		for c in carros_garagem():
			if mods.has(String(c["modalidade"])) and int(mods[String(c["modalidade"])].get("corridas", 0)) > 0:
				garagem.append(String(c["id"]))
	if not s.has("desbloqueados") and corridas > 0:
		# Save de antes da escada: o que a equipe já alcançou vem aberto.
		for d in cfg_desbloqueios():
			if condicao_ok(d):
				oferecidos.append(String(d["id"]))
				desbloqueados.append(String(d["id"]))
	var sm = s.get("metas", {})
	metas = {}
	if sm is Dictionary and sm.has("dia"):
		metas = {"dia": String(sm["dia"]), "tarefas": Array(sm.get("tarefas", [])).map(func(x): return String(x)),
				"contagem": {}, "coletadas": Array(sm.get("coletadas", [])).map(func(x): return String(x))}
		for k in sm.get("contagem", {}):
			metas["contagem"][String(k)] = int(sm["contagem"][k])
	# Save de antes da abertura com o Sal: quem já correu não a vê.
	if corridas > 0 and not "rival" in oferecidos and not desbloqueio("rival").is_empty():
		oferecidos.append("rival")
		desbloqueados.append("rival")


func salvar(agora: float) -> void:
	salvo_em = agora
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(para_save()))


static func carregar() -> IdleEstado:
	var e := IdleEstado.new()
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.READ)
	if f != null:
		var s = JSON.parse_string(f.get_as_text())
		if s is Dictionary:
			e.de_save(s)
	return e
