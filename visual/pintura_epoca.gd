class_name PinturaEpoca
extends RefCounted
## Pinturas de época dos carros (briefing de pinturas 1930–1950 do usuário,
## docs/idle/conversao_mafia.md, 11): a identidade vem da cor da carroceria e do
## número pintado, como nas corridas de bairro, nos hot rods e nos primeiros
## stock cars. Quatro famílias, uma por divisão (e a "Copa das Famílias" nas
## ligas de cima):
## - "bairro": cor única, número opcional pintado à mão, rodas escuras;
## - "hot_rod": contraste, número sempre, filete ou capô em segunda cor;
## - "stock": cor sólida, número grande nas portas e no teto, teto ou capô em
##   segunda cor às vezes;
## - "familias": acabamento brilhante, teto em segunda cor, número discreto
##   serifado num círculo.
## Regras: a cor principal cobre quase toda a lataria; no máximo uma segunda
## cor (teto, capô ou um filete); nada de degradê, zigue-zague nem padrão
## moderno. Mesma equipe, mesma cor (reconhecível de uma corrida para outra).
## Cores são aproximações para a tela do celular, não tintas históricas.

## Apresentação, não balanceamento.
const FAMILIAS := {
	"bairro": {
		"cores": ["#1c1b1b", "#5e1a1f", "#e3d8bc", "#2f4a35", "#2a3f5f"],
		"segunda": [],  # cor única
		"chance_segunda": 0.0,
		"chance_numero": 0.6, "fontes": ["pincel"], "locais": 1, "escala": 1.0, "suporte": false,
		"rodas": ["roda_preta", "roda_creme", "roda_vinho"], "acabamento": "",
	},
	"hot_rod": {
		"cores": ["#a3241f", "#161515", "#24448a", "#ece8dc", "#e0b42a"],
		"segunda": ["lateral"],  # sem capô: o hot rod não tem (pintaria meia carroceria)
		"chance_segunda": 0.6,
		"chance_numero": 1.0, "fontes": ["bloco", "pincel"], "locais": 1, "escala": 1.1, "suporte": false,
		"rodas": ["roda_vermelha", "roda_preta", ""], "acabamento": "brilhante",
	},
	"stock": {
		"cores": ["#1f4f9c", "#b52a22", "#efece2", "#2c6b45", "#e3b52c"],
		"segunda": ["teto", "capo"],
		"chance_segunda": 0.45,
		"chance_numero": 1.0, "fontes": ["bloco", "condensado"], "locais": 5, "escala": 1.25, "suporte": false,
		"rodas": ["roda_preta", "roda_marfim", ""], "acabamento": "",
	},
	"familias": {
		"cores": ["#121212", "#4d1220", "#1d5a44", "#ece3cc", "#b9bcc0"],
		"segunda": ["teto"],
		"chance_segunda": 0.7,
		"chance_numero": 1.0, "fontes": ["serifa"], "locais": 1, "escala": 0.8, "suporte": true,
		"rodas": ["", "roda_marfim", "roda_preta"], "acabamento": "brilhante",
	},
}
## Família por divisão (as ligas de LIGA_FAMILIAS em diante viram "familias").
const POR_DIVISAO := {"compactos": "bairro", "turismo": "hot_rod", "gt": "hot_rod", "terra": "stock"}
const LIGA_FAMILIAS := 5  # Copa das Famílias, Grande Campeonato, Lendas
## O carro do jogador (o sobrinho, família Bellucci): o número 7 em todas
## (pedido do usuário, 2026-10-27).
const NUMERO_JOGADOR := 7
const JOGADOR := {
	"bairro": {"cor": "#151414", "numero": "#efe9da", "contorno": "#151414", "roda": "roda_vinho"},
	"hot_rod": {"cor": "#151414", "segunda": "lateral", "segunda_cor": "#6e1a1d", "numero": "#efe9da",
		"contorno": "#6e1a1d", "roda": "roda_vinho"},
	"stock": {"cor": "#e6dcc2", "segunda": "teto", "segunda_cor": "#22407a", "numero": "#22407a",
		"contorno": "#e6dcc2", "roda": "roda_azul"},
	"familias": {"cor": "#151414", "segunda": "teto", "segunda_cor": "#ece3cc", "numero": "#151414",
		"contorno": "#ece3cc", "roda": "roda_marfim"},
}


## Padrões que a época admite (cor única, filete lateral, capô ou teto).
const PADROES_EPOCA := ["", "lateral", "capo", "teto"]


static func _perto(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12


## A família da divisão e liga ("" para a arena e divisões sem carro de época).
static func familia(modalidade: String, liga: int) -> String:
	if not POR_DIVISAO.has(modalidade):
		return ""
	return "familias" if liga >= LIGA_FAMILIAS else String(POR_DIVISAO[modalidade])


## Cor e pintura do carro do jogador: [cor, faixas].
static func do_jogador(fam: String) -> Array:
	var j: Dictionary = JOGADOR.get(fam, JOGADOR["bairro"])
	var fm: Dictionary = FAMILIAS.get(fam, FAMILIAS["bairro"])
	var f := {"numero": NUMERO_JOGADOR, "locais_numero": int(fm["locais"]), "cor_numero": j["numero"],
			"cor_contorno": j["contorno"], "fonte_numero": String(fm["fontes"][0]), "escala_numero": float(fm["escala"]),
			"suporte_numero": bool(fm["suporte"]), "roda_epoca": String(j["roda"])}
	if j.has("segunda"):
		f["padrao"] = j["segunda"]
		f["faixa"] = j["segunda_cor"]
		f["filete"] = j["segunda_cor"]
	if String(fm["acabamento"]) != "":
		f["acabamento"] = fm["acabamento"]
	return [Color(String(j["cor"])), f]


## Cor e pintura de um rival: a cor sai da equipe (`chave`, fixa por equipe),
## o resto do sorteio por `semente`; `numero` < 0 sorteia.
static func do_rival(fam: String, chave: String, semente: String, numero := -1) -> Array:
	var fm: Dictionary = FAMILIAS.get(fam, FAMILIAS["bairro"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fam + "|" + semente)
	var cores: Array = fm["cores"]
	var i := posmod(hash(fam + "|" + chave), cores.size())
	# A cor do carro do jogador fica só com ele.
	var minha := Color(String(JOGADOR.get(fam, JOGADOR["bairro"])["cor"]))
	if Color(String(cores[i])).is_equal_approx(minha) or _perto(Color(String(cores[i])), minha):
		i = (i + 1) % cores.size()
	var cor := Color(String(cores[i]))
	var f := {}
	var escuro := cor.get_luminance() < 0.45
	if rng.randf() < float(fm["chance_numero"]):
		# Sorteio de 1 a 99 sem o número do sobrinho.
		var n := rng.randi_range(1, 98)
		f["numero"] = numero if numero > 0 else (n + 1 if n >= NUMERO_JOGADOR else n)
		f["locais_numero"] = int(fm["locais"])
		f["fonte_numero"] = String(fm["fontes"][rng.randi() % fm["fontes"].size()])
		f["escala_numero"] = float(fm["escala"])
		f["suporte_numero"] = bool(fm["suporte"])
		f["cor_numero"] = "#efe9da" if escuro else "#151414"
		f["cor_contorno"] = "#151414" if escuro else "#efe9da"
	var segundas: Array = fm["segunda"]
	if not segundas.is_empty() and rng.randf() < float(fm["chance_segunda"]):
		var outra := Color(String(cores[(i + 1 + rng.randi() % (cores.size() - 1)) % cores.size()]))
		# segunda cor contrastante: clara num carro escuro e vice-versa
		if (outra.get_luminance() < 0.45) == escuro:
			outra = Color("#efe9da") if escuro else Color("#151414")
		f["padrao"] = String(segundas[rng.randi() % segundas.size()])
		f["faixa"] = "#" + outra.to_html(false)
		f["filete"] = "#" + outra.to_html(false)
	var rodas: Array = fm["rodas"]
	f["roda_epoca"] = String(rodas[rng.randi() % rodas.size()])
	if String(fm["acabamento"]) != "":
		f["acabamento"] = fm["acabamento"]
	return [cor, f]


## O carro do ferro-velho (o primeiro da loja, até o Tony pintar depois da
## primeira vitória): tinta verde queimada de sol, ferrugem, poeira e riscos;
## depois de comprado, o 7 do sobrinho pintado à mão em giz.
const FERRO_VELHO := {"cor": "#56604f", "ferrugem": 0.85, "poeira": 0.45, "arranhoes": 0.55, "numero": "#e9e2cf"}


static func ferro_velho(com_numero: bool) -> Array:
	var f := {"ferrugem": FERRO_VELHO["ferrugem"], "poeira": FERRO_VELHO["poeira"], "arranhoes": FERRO_VELHO["arranhoes"],
			"acabamento": "fosco", "roda_epoca": "roda_preta"}
	if com_numero:
		f.merge({"numero": NUMERO_JOGADOR, "locais_numero": 1, "fonte_numero": "pincel", "escala_numero": 0.9,
				"cor_numero": FERRO_VELHO["numero"], "cor_contorno": FERRO_VELHO["cor"]})
	return [Color(String(FERRO_VELHO["cor"])), f]
