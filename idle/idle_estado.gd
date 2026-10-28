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
var trofeus: Array = []  # pistas com troféu (cfg "trofeus")
var cidade := 0  # prestígio Nova Cidade (cfg "cidades"): 0 = Brooklyn
## Presente do chefão (cfg "presente_diario"): o último dia coletado (AAAA-MM-DD)
## e em que dia da sequência de 7 ele estava.
var presente := {"dia": "", "seq": 0}
## Desafio de fim de semana (cfg "fim_de_semana"): {semana, vitorias, coletado}.
var desafio := {}
var tacas: Array = []  # famílias rivais vencidas no desafio (uma taça cada)
## Fiscal comprado (cfg "fiscal"): um vídeo liga o bônus até `fiscal_ate`.
var fiscal_ate := 0.0
var fiscal_dia := ""
var fiscal_usos := 0
var fundadora := false  # pacote Família Fundadora (compra única)
var agora_fixo := -1.0  # testes e ferramentas: o relógio do jogo (unix); < 0 = o do aparelho
var trofeu_novo := ""  # o último troféu ganho, até a tela mostrar
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
			* pow(float(dados_liga()["multiplicador"]), float(cfg.get("expoente_custo_liga", 1.0)))
			/ (1.0 + bonus_capangas("oficina")) / (1.0 + bonus_carros("oficina")) / (1.0 + bonus_do_momento("oficina")) / (1.0 + bonus_trofeus("oficina")))


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
			var n := nivel(m["id"], mod) + int(niveis_extra.get(m["id"], 0))
			total += float(m["por_nivel"]) * n * multiplicador_marcos(m, n)
	return total


# --- marcos por melhoria (cfg "marcos") ----------------------------------------
# Como nos idles de referência (AdVenture Capitalist): níveis-marco em que o
# efeito da melhoria multiplica. Só nos efeitos listados em "efeitos"; nos
# outros o marco é só a fase nova da estação.

func cfg_marcos() -> Dictionary:
	return cfg.get("marcos", {})


## Marcos já alcançados com `n` níveis.
func marcos_alcancados(n: int) -> int:
	var k := 0
	for alvo in cfg_marcos().get("niveis", []):
		if n >= int(alvo):
			k += 1
	return k


## O próximo nível-marco depois de `n` (0: não há mais) e o anterior (0 no começo).
func proximo_marco(n: int) -> Vector2i:
	var antes := 0
	for alvo in cfg_marcos().get("niveis", []):
		if n < int(alvo):
			return Vector2i(antes, int(alvo))
		antes = int(alvo)
	return Vector2i(antes, 0)


func marco_multiplica(m: Dictionary) -> bool:
	return String(m["efeito"]) in cfg_marcos().get("efeitos", [])


func multiplicador_marcos(m: Dictionary, n: int) -> float:
	if not marco_multiplica(m):
		return 1.0
	return pow(float(cfg_marcos().get("multiplicador", 1.0)), marcos_alcancados(n))


# --- o menino jornaleiro (cfg "jornaleiro") ---------------------------------------

func cfg_jornaleiro() -> Dictionary:
	return cfg.get("jornaleiro", {})


## A gorjeta do jornaleiro: tempo de lucro ou parte do prêmio de 1º, o maior.
func gorjeta_jornaleiro() -> float:
	var j := cfg_jornaleiro()
	return roundf(maxf(renda_s() * float(j.get("segundos_de_lucro", 0.0)),
			premio(1) * float(j.get("fracao_premio", 0.0))) * (1.0 + bonus_gorjeta())
			* (1.0 + bonus_carros("gorjeta")) * (1.0 + bonus_do_momento("gorjeta")))


## O que a gorjeta cresce para sempre: os capangas da gorjeta e cada troféu
## da coleção ("por_trofeu").
func bonus_gorjeta() -> float:
	return bonus_capangas("gorjeta") + float(cfg_jornaleiro().get("por_trofeu", 0.0)) * trofeus.size() \
			+ bonus_trofeus("gorjeta")


## Quantas vezes a gorjeta vale com o anúncio.
func multiplicador_anuncio_gorjeta() -> float:
	return multiplicador_anuncio(float(cfg_jornaleiro().get("anuncio_mult", 2)))


## Quantas vezes vale uma recompensa em dinheiro com o anúncio (gorjeta, coletar):
## a base de cada uma ou, com o troféu de efeito "anuncio", o multiplicador dele
## (o maior entre os dois; o terceiro troféu dá ×2,5, pedido do usuário 2026-10-28).
func multiplicador_anuncio(base := 2.0) -> float:
	var m := maxf(base, 1.0)
	for t in lista_trofeus():  # o maior dos troféus do anúncio (não somam)
		if String(t["efeito"]) == "anuncio" and String(t["pista"]) in trofeus:
			m = maxf(m, float(t["bonus"]))
	return m


# --- prestígio Nova Cidade (cfg "cidades") -----------------------------------------
# Ao vencer o Grande Campeonato de qualquer categoria, a família muda de cidade:
# dinheiro, melhorias e ligas recomeçam; troféus, capangas e carros ficam; renda
# e prêmios multiplicam por cidade.

func cfg_cidades() -> Dictionary:
	return cfg.get("cidades", {})


func multiplicador_cidade() -> float:
	return pow(float(cfg_cidades().get("multiplicador", 1.0)), cidade)


func pode_mudar_de_cidade() -> bool:
	var alvo := String(cfg_cidades().get("libera_liga", ""))
	if alvo == "":
		return false
	for m in cfg["modalidades"]:
		var id := String(m["id"])
		if not mods.has(id):
			continue
		var ligas: Array = m["ligas"]
		for k in ligas.size():
			if String(ligas[k]["nome"]).ends_with(alvo):
				var liga_m := int(mods[id]["liga"])
				if liga_m > k or (liga_m == k and bool(mods[id]["venceu"])):
					return true
				break
	return false


func mudar_de_cidade() -> bool:
	if not pode_mudar_de_cidade():
		return false
	cidade += 1
	dinheiro = float(cfg.get("dinheiro_inicial", 0.0))
	mods = {}
	modalidade = String(cfg["modalidades"][0]["id"])
	_m()
	escalados = {}
	return true


# --- especialidades dos capangas (cfg "capangas") ----------------------------------

func especialidade(p: Dictionary) -> String:
	var lista: Array = cfg.get("capangas", {}).get("especialidades", [])
	if p.is_empty() or lista.is_empty():
		return ""
	return String(lista[(int(p["uid"]) - 1) % lista.size()])


## O bônus da especialidade: só o capanga de nível mais alto dela conta.
func bonus_capangas(tipo: String) -> float:
	var melhor := 0
	for p in pilotos:
		if especialidade(p) == tipo:
			melhor = maxi(melhor, int(p["nivel"]))
	return float(cfg.get("capangas", {}).get("por_nivel", 0.0)) * melhor


# --- troféus (cfg "trofeus") ------------------------------------------------------
# Um por pista, ganho na primeira vitória numa liga dela; cada um soma um bônus.

func lista_trofeus() -> Array:
	return cfg.get("trofeus", {}).get("lista", [])


## O troféu da pista da liga atual, se ainda não ganho (vira `trofeu_novo`).
func ganhar_trofeu() -> void:
	var pista_id := String(dados_liga().get("pista", ""))
	if pista_id in trofeus:
		return
	for t in lista_trofeus():
		if String(t["pista"]) == pista_id:
			trofeus.append(pista_id)
			trofeu_novo = pista_id
			return


func bonus_trofeus(tipo: String) -> float:
	var total := 0.0
	for t in lista_trofeus():
		if String(t["efeito"]) == tipo and String(t["pista"]) in trofeus:
			total += float(t["bonus"])
	return total


## Save sem troféus: as pistas das ligas já vencidas.
func _trofeus_do_progresso() -> void:
	for m in cfg["modalidades"]:
		var id := String(m["id"])
		if not mods.has(id):
			continue
		var ligas: Array = m["ligas"]
		var ate := int(mods[id]["liga"]) + (1 if bool(mods[id]["venceu"]) else 0)
		for k in mini(ate, ligas.size()):
			var p := String(ligas[k]["pista"])
			if not p in trofeus and lista_trofeus().any(func(t): return String(t["pista"]) == p):
				trofeus.append(p)


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
	return (base + efeito("renda", {}, id)) * float(dados_liga(id)["multiplicador"]) * (1.0 + bonus_trofeus("renda")) \
			* (1.0 + bonus_capangas("renda")) * (1.0 + bonus_carros("renda")) * (1.0 + bonus_do_momento("renda")) \
			* multiplicador_cidade()


## Prêmio da posição `pos` (1 = vitória) na liga atual.
func premio(pos: int) -> float:
	var n := int(cfg["grid"])
	return roundf(float(cfg["premio_p1"]) * float(dados_liga()["multiplicador"]) * float(n + 1 - pos) / n
			* (1.0 + bonus_trofeus("premio") + bonus_tacas()) * (1.0 + bonus_capangas("premio"))
			* (1.0 + bonus_carros("premio")) * (1.0 + bonus_do_momento("premio")) * multiplicador_cidade())


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
		ganhar_trofeu()
	registrar_meta("corridas")
	if pos == 1:
		registrar_meta("vitorias")
		vitoria_no_desafio()
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


## Teto do lucro com o app fechado (s): offline_max_h mais as horas dos troféus
## de efeito "offline" (o primeiro troféu, pedido do usuário 2026-10-28).
func offline_max_s() -> float:
	return (float(cfg["offline_max_h"]) + bonus_trofeus("offline")) * 3600.0


## Renda acumulada com o app fechado desde `salvo_em` (até offline_max_s).
func ganho_offline(agora: float) -> float:
	if salvo_em <= 0.0:
		return 0.0
	var dt := clampf(agora - salvo_em, 0.0, offline_max_s())
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
	contrato_em = agora + float(cfg_pilotos().get("contrato_gratis_h", 4.0)) * 3600.0 / (1.0 + bonus_trofeus("contrato"))
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
	return maxi(combustivel_usos_dia() - usados, 0)


## Usos por dia e duração (s) do combustível, com os troféus que os aumentam.
func combustivel_usos_dia() -> int:
	return int(cfg_combustivel().get("usos_dia", 0)) + roundi(bonus_trofeus("combustivel_usos"))


func combustivel_duracao_s() -> float:
	return float(cfg_combustivel().get("duracao_s", 0.0)) * (1.0 + bonus_trofeus("combustivel_duracao"))


## Depois do vídeo: liga o bônus por "duracao_s" (somando ao que ainda resta).
func usar_combustivel(agora: float, dia: String) -> bool:
	if combustivel_restantes(dia) <= 0:
		return false
	if combustivel_dia != dia:
		combustivel_dia = dia
		combustivel_usos = 0
	combustivel_usos += 1
	combustivel_ate = maxf(combustivel_ate, agora) + combustivel_duracao_s()
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
	base["potencia"] = float(base["potencia"]) * (1.0 + efeito("potencia", niveis_extra) + bonus_trofeus("potencia")
			+ bonus_carros("potencia") + bonus_do_momento("potencia")
			+ (bonus_combustivel() if combustivel_ativo(relogio()) else 0.0))
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
	# A linha de largada no meio da primeira reta, não no começo dela: o grid
	# (atrás da linha) e a arquibancada ficam na reta, não na curva de antes.
	# Só muda onde a volta começa; o traçado e o comprimento são os mesmos.
	var tr: Array = d["trechos"]
	var i := tr.find_custom(func(t): return not t["tipo"] in Pista.FORA_DA_VOLTA)
	if i >= 0 and tr[i]["tipo"] == "reta":
		var compr := float(tr[i]["comprimento_m"])
		var antes := minf(compr * 0.5, LARGADA_NA_RETA_M)
		var fim: Dictionary = tr[i].duplicate()
		fim["comprimento_m"] = antes
		tr[i]["comprimento_m"] = compr - antes
		tr.append(fim)
	return Pista.new(d)


## Metros da primeira reta que ficam antes da linha de largada (apresentação).
const LARGADA_NA_RETA_M := 150.0


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
		if pos == 1:
			ganhar_trofeu()
		return p))


# --- o relógio do jogo -----------------------------------------------------------

func relogio() -> float:
	return agora_fixo if agora_fixo >= 0.0 else Time.get_unix_time_from_system()


## Segundos Unix na hora do aparelho (com o fuso).
static func _local(t: float) -> float:
	return t + float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0


## Bônus que valem agora: a manchete do dia, o fiscal comprado e o fim de semana.
func bonus_do_momento(tipo: String) -> float:
	var t := relogio()
	# Chamado a cada prêmio e a cada quadro: o resultado vale pelo segundo.
	var chave := "%d|%s|%f|%d" % [int(t), tipo, fiscal_ate, cfg.size()]
	if _momento_cache.has(chave):
		return _momento_cache[chave]
	if _momento_cache.size() > 32:
		_momento_cache.clear()
	var b := _bonus_do_momento(tipo, t)
	_momento_cache[chave] = b
	return b


var _momento_cache := {}


func _bonus_do_momento(tipo: String, t: float) -> float:
	var b := 0.0
	var m := manchete_do_dia(t)
	if String(m.get("efeito", "")) == tipo:
		b += float(m.get("bonus", 0.0))
	if fiscal_ativo(t) and String(cfg_fiscal().get("efeito", "")) == tipo:
		b += float(cfg_fiscal().get("bonus", 0.0))
	if tipo == "premio" and fim_de_semana(t):
		b += float(cfg_fim_de_semana().get("premio", 0.0))
	return b


# --- manchete do dia (cfg "jornal_dia") -------------------------------------------
# A Gazeta do Cais de hoje: uma manchete por dia, sorteada pela data, com um
# bônus que vale o dia inteiro.

func manchete_do_dia(t: float = -1.0) -> Dictionary:
	var lista: Array = cfg.get("jornal_dia", {}).get("lista", [])
	if lista.is_empty():
		return {}
	var d := MetaDia.dia(relogio() if t < 0.0 else t)
	return lista[absi(hash("manchete|" + d)) % lista.size()]


# --- presente do chefão (cfg "presente_diario") -----------------------------------
# Um presente por dia, numa sequência de 7: dias seguidos avançam, um dia sem
# entrar volta ao 1º. Dias 1 a 6 pagam minutos da renda (no mínimo um prêmio de
# vitória); o 7º traz um capanga de nível alto.

func cfg_presente() -> Dictionary:
	return cfg.get("presente_diario", {})


## O dia da sequência (1 a 7) do presente de hoje ou do próximo.
func dia_do_presente(t: float = -1.0) -> int:
	var tt := relogio() if t < 0.0 else t
	var hoje := MetaDia.dia(tt)
	var seq := int(presente.get("seq", 0))
	if String(presente.get("dia", "")) == hoje:
		return seq
	if String(presente.get("dia", "")) == MetaDia.dia(tt - 86400.0):
		return seq % 7 + 1
	return 1


func presente_pronto(t: float = -1.0) -> bool:
	return not cfg_presente().is_empty() and String(presente.get("dia", "")) != MetaDia.dia(relogio() if t < 0.0 else t)


func valor_presente(n: int) -> float:
	var mins: Array = cfg_presente().get("minutos", [])
	if n < 1 or n > mins.size():
		return 0.0
	return roundf(maxf(renda_s() * float(mins[n - 1]) * 60.0, premio(1)))


## Coleta o presente de hoje. {dia, dinheiro} ou {dia, capanga}; vazio: não deu.
func coletar_presente(dados: Node, t: float = -1.0) -> Dictionary:
	var tt := relogio() if t < 0.0 else t
	if not presente_pronto(tt):
		return {}
	var n := dia_do_presente(tt)
	presente = {"dia": MetaDia.dia(tt), "seq": n}
	if n >= 7:
		return {"dia": n, "capanga": dar_capanga(dados, int(cfg_presente().get("capanga_nivel", 1)), int(tt))}
	var v := valor_presente(n)
	dinheiro += v
	return {"dia": n, "dinheiro": v}


## Um capanga já no nível `nivel` (presente, pacote): entra como os contratados.
func dar_capanga(dados: Node, nivel: int, semente: int) -> Dictionary:
	var p := contratar(dados, semente)
	if not p.is_empty():
		p["nivel"] = maxi(nivel, 1)
	return p


# --- desafio de fim de semana (cfg "fim_de_semana") ---------------------------------
# Sábado e domingo uma família rival desafia os Bellucci: os prêmios sobem e
# quem vence `vitorias` corridas no fim de semana leva a taça da família (um
# bônus de prêmio para sempre) e uma bolada.

func cfg_fim_de_semana() -> Dictionary:
	return cfg.get("fim_de_semana", {})


func fim_de_semana(t: float = -1.0) -> bool:
	if cfg_fim_de_semana().is_empty():
		return false
	var wd := int(Time.get_datetime_dict_from_unix_time(int(_local(relogio() if t < 0.0 else t)))["weekday"])
	return wd in cfg_fim_de_semana().get("dias", [6, 0]).map(func(x): return int(x))


## O sábado do fim de semana de `t` (AAAA-MM-DD): a chave do desafio.
func _semana(t: float) -> String:
	var l := _local(t)
	var wd := int(Time.get_datetime_dict_from_unix_time(int(l))["weekday"])
	var desde_sabado := (wd + 1) % 7  # sábado 0, domingo 1, ...
	return Time.get_date_string_from_unix_time(int(l) - desde_sabado * 86400)


## A família rival do fim de semana (gira pela lista de cenas.json "familias").
func familia_do_desafio(familias: Array, t: float = -1.0) -> String:
	if familias.is_empty():
		return ""
	var dias := int(Time.get_unix_time_from_datetime_string(_semana(relogio() if t < 0.0 else t)) / 86400)
	return String(familias[(dias / 7) % familias.size()])


func estado_desafio(t: float = -1.0) -> Dictionary:
	var k := _semana(relogio() if t < 0.0 else t)
	if String(desafio.get("semana", "")) != k:
		desafio = {"semana": k, "vitorias": 0, "coletado": false}
	return desafio


func vitoria_no_desafio() -> void:
	if fim_de_semana():
		var d := estado_desafio()
		d["vitorias"] = int(d["vitorias"]) + 1


func desafio_pronto() -> bool:
	var d := estado_desafio()
	return fim_de_semana() and not bool(d["coletado"]) \
			and int(d["vitorias"]) >= int(cfg_fim_de_semana().get("vitorias", 1))


func recompensa_desafio() -> float:
	return roundf(maxf(renda_s() * float(cfg_fim_de_semana().get("recompensa_min", 0.0)) * 60.0, premio(1)))


## Coleta a taça da `familia` e a bolada; devolve a bolada (0: não deu).
func coletar_desafio(familia: String) -> float:
	if not desafio_pronto():
		return 0.0
	desafio["coletado"] = true
	if familia != "" and not familia in tacas:
		tacas.append(familia)
	var v := recompensa_desafio()
	dinheiro += v
	return v


func bonus_tacas() -> float:
	return float(cfg_fim_de_semana().get("taca_bonus", 0.0)) * tacas.size()


# --- coleção de carros (cfg "garagem" → "colecao") --------------------------------
# Cada carro da época na garagem dá um bônus pequeno para sempre (fica na Nova
# Cidade, como os carros).

func bonus_carros(tipo: String) -> float:
	var b := 0.0
	for c in cfg.get("garagem", []):
		var col: Dictionary = c.get("colecao", {})
		if String(col.get("efeito", "")) == tipo and String(c["id"]) in garagem:
			b += float(col.get("bonus", 0.0))
	return b


# --- fiscal comprado (cfg "fiscal") -------------------------------------------------
# Um vídeo compra o fiscal: o bônus vale por "duracao_s", com usos por dia.

func cfg_fiscal() -> Dictionary:
	return cfg.get("fiscal", {})


func fiscal_ativo(t: float = -1.0) -> bool:
	return (relogio() if t < 0.0 else t) < fiscal_ate


func fiscal_restantes(dia: String) -> int:
	var usados := fiscal_usos if fiscal_dia == dia else 0
	return maxi(fiscal_usos_dia() - usados, 0)


func fiscal_usos_dia() -> int:
	return int(cfg_fiscal().get("usos_dia", 0)) + roundi(bonus_trofeus("fiscal_usos"))


func usar_fiscal(t: float, dia: String) -> bool:
	if fiscal_restantes(dia) <= 0:
		return false
	if fiscal_dia != dia:
		fiscal_dia = dia
		fiscal_usos = 0
	fiscal_usos += 1
	fiscal_ate = maxf(fiscal_ate, t) + float(cfg_fiscal().get("duracao_s", 0.0))
	return true


# --- Família Fundadora (compra única, cfg "fundadora") ------------------------------
# Sem anúncio entre as ligas, o carro dourado e um capanga de nível alto.

func conceder_fundadora(dados: Node) -> bool:
	if fundadora:
		return false
	fundadora = true
	dar_capanga(dados, int(cfg.get("fundadora", {}).get("capanga_nivel", 1)), 1937)
	return true


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
			"combustivel_dia": combustivel_dia, "combustivel_usos": combustivel_usos, "trofeus": trofeus,
			"cidade": cidade, "presente": presente, "desafio": desafio, "tacas": tacas, "fiscal_ate": fiscal_ate,
			"fiscal_dia": fiscal_dia, "fiscal_usos": fiscal_usos, "fundadora": fundadora}


## Quão adiantado o jogo está, para escolher entre o save do aparelho e o da
## nuvem: cidade, depois ligas vencidas, depois corridas.
func progresso() -> int:
	return IdleEstado.progresso_de({"cidade": cidade, "mods": mods, "corridas": corridas})


## O mesmo, direto de um save (o da nuvem, antes de carregar).
static func progresso_de(s: Dictionary) -> int:
	var ligas := 0
	var ms = s.get("mods", {})
	if ms is Dictionary:
		for id in ms:
			if ms[id] is Dictionary:
				ligas += int(ms[id].get("liga", 0)) + (1 if bool(ms[id].get("venceu", false)) else 0)
	return int(s.get("cidade", 0)) * 10000000 + ligas * 10000 + mini(int(s.get("corridas", 0)), 9999)


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
	trofeus = Array(s.get("trofeus", [])).map(func(x): return String(x))
	cidade = int(s.get("cidade", 0))
	var pr = s.get("presente", {})
	if pr is Dictionary:
		presente = {"dia": String(pr.get("dia", "")), "seq": int(pr.get("seq", 0))}
	var de = s.get("desafio", {})
	if de is Dictionary and de.has("semana"):
		desafio = {"semana": String(de["semana"]), "vitorias": int(de.get("vitorias", 0)), "coletado": bool(de.get("coletado", false))}
	tacas = Array(s.get("tacas", [])).map(func(x): return String(x))
	fiscal_ate = float(s.get("fiscal_ate", 0.0))
	fiscal_dia = String(s.get("fiscal_dia", ""))
	fiscal_usos = int(s.get("fiscal_usos", 0))
	fundadora = bool(s.get("fundadora", false))
	if not s.has("trofeus"):
		_trofeus_do_progresso()
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
