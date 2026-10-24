class_name IdleEstado
extends RefCounted
## Chrome Racing Team (docs/idle/plano.md): o estado do jogo idle e as regras,
## sem tela. A corrida é a Simulacao do Chrome & Wreckage; os números vêm de
## data/idle/idle.json.

const ARQUIVO_CONFIG := "res://data/idle/idle.json"
const ARQUIVO_SAVE := "user://crt.json"

var cfg: Dictionary
var dinheiro := 0.0
var niveis := {}  # melhoria -> nível
var liga := 0
var venceu := false  # já venceu nesta liga (libera PRÓXIMA LIGA)
var corridas := 0
var salvo_em := 0.0  # unix (s), para a renda com o app fechado


static func config() -> Dictionary:
	var f := FileAccess.open(ARQUIVO_CONFIG, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else {}


func _init(config_: Dictionary = {}) -> void:
	cfg = config_ if not config_.is_empty() else IdleEstado.config()
	dinheiro = float(cfg.get("dinheiro_inicial", 0.0))
	for m in cfg["melhorias"]:
		niveis[m["id"]] = 0


func melhoria(id: String) -> Dictionary:
	for m in cfg["melhorias"]:
		if m["id"] == id:
			return m
	return {}


func nivel(id: String) -> int:
	return int(niveis.get(id, 0))


func no_maximo(id: String) -> bool:
	return nivel(id) >= int(melhoria(id)["max"])


## Custo do próximo nível: base × crescimento^nível × multiplicador da liga^expoente_custo_liga
## (um pouco acima de 1: cada liga pede mais tempo que a anterior).
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


## Soma dos efeitos de um tipo ("potencia", "renda"...) nos níveis comprados.
func efeito(tipo: String, niveis_extra := {}) -> float:
	var total := 0.0
	for m in cfg["melhorias"]:
		if m["efeito"] == tipo:
			total += float(m["por_nivel"]) * (nivel(m["id"]) + int(niveis_extra.get(m["id"], 0)))
	return total


func dados_liga() -> Dictionary:
	return cfg["ligas"][liga]


func ultima_liga() -> bool:
	return liga >= cfg["ligas"].size() - 1


## Renda por segundo (patrocínio e arquibancada), no tamanho da liga.
func renda_s() -> float:
	return (float(cfg.get("renda_base", 0.0)) + efeito("renda")) * float(dados_liga()["multiplicador"])


## Prêmio da posição `pos` (1 = vitória) na liga atual.
func premio(pos: int) -> float:
	var n := int(cfg["grid"])
	return roundf(float(cfg["premio_p1"]) * float(dados_liga()["multiplicador"]) * float(n + 1 - pos) / n)


## A corrida terminou em `pos`: o prêmio entra e a vitória libera a próxima liga.
func concluir(pos: int, fator := 1.0) -> float:
	var p := premio(pos) * fator
	dinheiro += p
	corridas += 1
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


## Carros da frota ordenados pela distância em potência de `alvo` (só os que
## têm preço: modelos de loja).
static func _perto_de(dados: Node, alvo: float) -> Array:
	var lista: Array = dados.lista("carros").filter(func(c): return c.get("preco") != null)
	lista.sort_custom(func(a, b):
		var da := absf(log(float(a["potencia"]) / alvo))
		var db := absf(log(float(b["potencia"]) / alvo))
		return da < db if da != db else String(a["id"]) < String(b["id"]))
	return lista


## O carro da equipe nesta liga (decisão: um carro novo a cada liga).
func carro_base(dados: Node) -> Dictionary:
	return IdleEstado._perto_de(dados, float(dados_liga()["potencia"]) * float(cfg["carro_do_jogador"]))[0]


## Força do rival `k` (0 = o mais forte, na frente do grid) em relação ao
## carro da liga: de (1 + espalhar) a (1 - espalhar), para cada melhoria render
## posições aos poucos (no Race Star você sobe um a um), vezes a forca_rivais da
## liga (acerta a pista: com poucas retas é mais difícil passar).
func fator_rival(k: int) -> float:
	var n := int(cfg["grid"]) - 1
	return float(dados_liga().get("forca_rivais", 1.0)) * (1.0 + float(cfg["rivais"].get("espalhar", 0.0))
			* (1.0 - 2.0 * k / maxf(n - 1, 1)))


## Os modelos dos rivais da liga (só a aparência: a ficha de corrida sai do
## carro da equipe, ver participantes).
func rivais(dados: Node) -> Array:
	var usados := {String(carro_base(dados)["id"]): true}
	var n := int(cfg["grid"]) - 1
	var r := []
	for k in n:
		var alvo := float(dados_liga()["potencia"]) * fator_rival(k)
		for c in IdleEstado._perto_de(dados, alvo):
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
## Race Star); as melhorias no seu carro e no seu piloto. A ficha de cada
## rival é a do carro da equipe com a potência × fator_rival (e a aderência
## na proporção aderencia_por_forca, como Pneus × Motor): a dificuldade
## de cada liga fica igual, sem depender do peso e da aderência de cada
## modelo da frota. `niveis_extra` simula níveis a mais (calibrador).
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
	var pj: Dictionary = cfg["piloto"]
	r.append({"id": "jogador", "carro": carro_base(dados)["id"], "atributos": IdleEstado._atributos(dados, base),
			"piloto": {"ritmo": pj["ritmo"], "consistencia": pj["consistencia"],
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


## A corrida da liga, resolvida inteira (a tela mostra as amostras).
func correr(dados: Node, semente: int, com_amostras := true, niveis_extra := {}) -> Dictionary:
	return Simulacao.correr(pista(dados), participantes(dados, niveis_extra), int(dados_liga()["voltas"]),
			dados.simulacao(), semente, com_amostras)


static func posicao(resultado: Dictionary) -> int:
	return Array(resultado["classificacao"]).find("jogador") + 1


func para_save() -> Dictionary:
	return {"dinheiro": dinheiro, "niveis": niveis, "liga": liga, "venceu": venceu, "corridas": corridas,
			"salvo_em": salvo_em}


func de_save(s: Dictionary) -> void:
	dinheiro = float(s.get("dinheiro", dinheiro))
	for id in s.get("niveis", {}):
		if niveis.has(id):
			niveis[id] = int(s["niveis"][id])
	liga = clampi(int(s.get("liga", 0)), 0, cfg["ligas"].size() - 1)
	venceu = bool(s.get("venceu", false))
	corridas = int(s.get("corridas", 0))
	salvo_em = float(s.get("salvo_em", 0.0))


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
