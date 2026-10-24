class_name IdleEstado
extends RefCounted
## Chrome Racing Team (docs/idle/plano.md): o estado do jogo idle e as regras,
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
var salvo_em := 0.0  # unix (s), para a renda com o app fechado

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
		mods[k] = {"liga": 0, "venceu": false, "niveis": n, "corridas": 0}
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
	if not liberada(id):
		return false
	modalidade = id
	_m()
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
	var m := melhoria(id)
	return roundf(float(m["base"]) * pow(float(m["crescimento"]), nivel(id))
			* pow(float(dados_liga()["multiplicador"]), float(cfg.get("expoente_custo_liga", 1.0))))


func pode_comprar(id: String) -> bool:
	return not no_maximo(id) and dinheiro >= custo(id)


func comprar(id: String) -> bool:
	if not pode_comprar(id):
		return false
	dinheiro -= custo(id)
	niveis[id] = nivel(id) + 1
	return true


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


func renda_modalidade(id: String) -> float:
	return (float(cfg.get("renda_base", 0.0)) + efeito("renda", {}, id)) * float(dados_liga(id)["multiplicador"])


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
	if pos == 1:
		venceu = true
	return p


func pode_subir() -> bool:
	return venceu and not ultima_liga()


func subir_liga() -> bool:
	if not pode_subir():
		return false
	liga += 1
	venceu = false
	# Carro novo: as melhorias do carro (motor, pneus) recomeçam; as da equipe ficam.
	for m in cfg["melhorias"]:
		if m.get("do_carro", false):
			niveis[m["id"]] = 0
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
	return p


## Contrato grátis pronto agora (`agora`, unix)?
func contrato_gratis_pronto(agora: float) -> bool:
	return agora >= contrato_em


func usar_contrato_gratis(dados: Node, agora: float) -> Dictionary:
	if not contrato_gratis_pronto(agora):
		return {}
	contrato_em = agora + float(cfg_pilotos().get("contrato_gratis_h", 4.0)) * 3600.0
	return contratar(dados, int(agora))


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
					"consistencia": pr["consistencia"], "agressividade": pr["agressividade"]}})
	var base: Dictionary = carro_base(dados).duplicate(true)
	base["potencia"] = float(base["potencia"]) * (1.0 + efeito("potencia", niveis_extra))
	base["aderencia"] = float(base["aderencia"]) * (1.0 + efeito("aderencia", niveis_extra))
	var pj := atributos_piloto(dados, piloto_escalado())
	r.append({"id": "jogador", "carro": carro_base(dados)["id"], "atributos": IdleEstado._atributos(dados, base),
			"piloto": {"ritmo": pj["ritmo"], "consistencia": clampf(pj["consistencia"], 0.0, 1.0),
				"agressividade": clampf(float(pj["agressividade"]) + efeito("agressividade", niveis_extra), 0.0, 1.0),
				"vacuo": efeito("vacuo", niveis_extra)}})
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


static func posicao(resultado: Dictionary) -> int:
	return Array(resultado["classificacao"]).find("jogador") + 1


# --- salvar ---------------------------------------------------------------------

func para_save() -> Dictionary:
	return {"versao": 2, "dinheiro": dinheiro, "modalidade": modalidade, "mods": mods, "corridas": corridas,
			"pilotos": pilotos, "escalados": escalados, "proximo_uid": proximo_uid, "contrato_em": contrato_em,
			"videos_dia": videos_dia, "videos_usados": videos_usados, "salvo_em": salvo_em}


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
		for k in sm.get("niveis", {}):
			if m["niveis"].has(k):
				m["niveis"][k] = int(sm["niveis"][k])
	var mod := String(s.get("modalidade", modalidade))
	if liberada(mod):
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
