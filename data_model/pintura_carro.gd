class_name PinturaCarro
extends RefCounted
## Pintura personalizada (Oficina → PINTURA, pedido do usuário): a cor da
## carroceria, livre na paleta (arte/carros/cores.json), e um padrão de faixas
## com a cor da faixa e a do filete. Fica no carro (Carro.cor, Carro.faixas) e
## aparece onde o modelo 3D aparece. Preço: data/equipe.json → pintura (fator
## sobre o prêmio de referência da maior licença; null = a definir, vale 0).

## [id, nome] dos padrões, na ordem da tela (o índice é o do shader carro_faixas).
const PADROES := [["", "Sem faixas"], ["dupla", "Dupla central"], ["larga", "Larga central"],
		["lateral", "Lateral"], ["dois_tons", "Dois tons"], ["tripla", "Tripla fina"], ["assimetrica", "Assimétrica"],
		["capo", "Capô"], ["diagonal", "Diagonal"], ["chevron", "Chevron"], ["xadrez", "Xadrez"],
		["degrade", "Degradê"], ["ziguezague", "Zigue-zague"], ["serrilha", "Serrilha"], ["circulo", "Círculo"],
		["tres_tons", "Três tons"]]

## Acabamentos da lataria [id, nome] (índice = o do shader; "" = acetinado, o de fábrica).
const ACABAMENTOS := [["fosco", "Fosco"], ["", "Acetinado"], ["brilhante", "Brilhante"], ["metalico", "Metálico"]]
## Número de corrida: 1 a 99; onde vai (soma): portas 1, capô 2, teto 4.
const NUMERO_MAX := 99
const LOCAIS := [[1, "Portas"], [2, "Capô"], [4, "Teto"]]
const LOCAIS_PADRAO := 1
## Famílias do número [id, nome] (texturas arte/ui/pintura/digitos_<id>.png).
const FONTES := [["condensado", "Condensado"], ["bloco", "Bloco"], ["estencil", "Estêncil"],
		["pincel", "Pintado à mão"], ["serifa", "Serifado"]]
const ESCALAS := [[0.8, "Pequeno"], [1.0, "Médio"], [1.2, "Grande"]]
## Logo da equipe: onde vai (soma) e tamanhos.
const LOCAIS_LOGO := [[1, "Paralamas"], [2, "Lateral traseira"], [4, "Capô"], [8, "Traseira"]]
## Largura das faixas [fator, nome].
const LARGURAS := [[0.7, "Estreita"], [1.0, "Média"], [1.35, "Larga"]]

## A paleta da pintura é a de fábrica mais saturada (pedido do usuário): mesmas
## famílias e o mesmo brilho relativo, tons mais vivos. Cinzas, brancos, preto
## e creme (pouca saturação) ficam como estão.
const SATURACAO_MIN := 0.2
const SATURACAO_GANHO := 0.45  # fração do que falta até 1
const SATURACAO_TETO := 0.97
const BRILHO_GANHO := 1.15


static func indice_padrao(id: String) -> int:
	for i in PADROES.size():
		if PADROES[i][0] == id:
			return i
	return 0


static func indice_acabamento(id: String) -> int:
	for i in ACABAMENTOS.size():
		if ACABAMENTOS[i][0] == id:
			return i
	return 1


## A pintura sem o que está no padrão de fábrica ({} = nada além da cor):
## faixas só com desenho; número só com valor; acabamento só se não for o acetinado.
static func normalizar(f: Dictionary) -> Dictionary:
	var r := {}
	if String(f.get("padrao", "")) != "":
		for k in ["padrao", "faixa", "filete"]:
			if f.has(k):
				r[k] = f[k]
	if int(f.get("numero", -1)) >= 0:
		for k in ["numero", "locais_numero", "cor_numero", "cor_contorno"]:
			if f.has(k):
				r[k] = f[k]
		r["numero"] = clampi(int(f["numero"]), 0, NUMERO_MAX)  # do save vem float
		r["locais_numero"] = int(f.get("locais_numero", LOCAIS_PADRAO))
	if String(f.get("acabamento", "")) != "":
		r["acabamento"] = String(f["acabamento"])
	if r.has("padrao"):
		if not is_equal_approx(float(f.get("largura", 1.0)), 1.0):
			r["largura"] = float(f["largura"])
		if bool(f.get("espelhar", false)):
			r["espelhar"] = true
	if r.has("numero"):
		if String(f.get("fonte_numero", "condensado")) != "condensado":
			r["fonte_numero"] = String(f["fonte_numero"])
		if not is_equal_approx(float(f.get("escala_numero", 1.0)), 1.0):
			r["escala_numero"] = float(f["escala_numero"])
		if bool(f.get("suporte_numero", false)):
			r["suporte_numero"] = true
	var ll := int(f.get("locais_logo", 0))
	# Logo e número não dividem o capô: o número fica, o logo sai de lá.
	if r.has("numero") and int(r["locais_numero"]) & 2:
		ll &= ~4
	if ll > 0:
		r["locais_logo"] = ll
		if not is_equal_approx(float(f.get("escala_logo", 1.0)), 1.0):
			r["escala_logo"] = float(f["escala_logo"])
		if String(f.get("logo", "")) != "":
			r["logo"] = String(f["logo"])
	for k in ["poeira", "arranhoes"]:
		if float(f.get(k, 0.0)) > 0.0:
			r[k] = clampf(float(f[k]), 0.0, 1.0)
	# Aro das rodas (Rodas; pedido do usuário): só fica se não for o padrão.
	if Rodas.desenho_de(f) != Rodas.PADRAO:
		r["roda"] = Rodas.desenho_de(f)
	return r


## A pintura sem o aro das rodas (o aro não entra no preço da pintura).
static func sem_roda(f: Dictionary) -> Dictionary:
	var r := normalizar(f)
	r.erase("roda")
	return r


static func nome_padrao(id: String) -> String:
	return String(PADROES[indice_padrao(id)][1])


## Cores da paleta da pintura: [{chave, nome, cor}].
static func cores() -> Array:
	var l := []
	for k in Cores._ler()["paleta"]:
		l.append({"chave": k, "nome": Cores.nome(k), "cor": saturada(Cores.cor(k))})
	return l


static func saturada(c: Color) -> Color:
	if c.s < SATURACAO_MIN:
		return c
	return Color.from_hsv(c.h, minf(SATURACAO_TETO, c.s + (1.0 - c.s) * SATURACAO_GANHO), minf(1.0, c.v * BRILHO_GANHO))


## Pintura de um carro de equipe rival (decisão 60): um desenho sorteado por
## `semente` (fixo por prova e vaga), nas cores da equipe (faixa e filete).
## Com `vaga` (o piloto na equipe, 0..3), o carro leva o número dele
## (numero da equipe × 4 − 3 + vaga) na família da equipe, nas portas; com
## logo, o emblema nos paralamas dianteiros.
static func da_equipe(equipe: Dictionary, semente: String, vaga := -1) -> Dictionary:
	var cores: Dictionary = equipe.get("cores", {})
	if cores.is_empty():
		return {}
	var k := 1 + posmod(semente.hash(), PADROES.size() - 1)
	var r := {"padrao": PADROES[k][0], "faixa": String(cores.get("faixa", "#ffffff")),
			"filete": String(cores.get("filete", "#1a1a1a"))}
	if vaga >= 0 and equipe.get("numero") != null:
		r["numero"] = clampi(int(equipe["numero"]) * 4 - 3 + vaga, 1, NUMERO_MAX)
		r["locais_numero"] = 1
		r["cor_numero"] = String(cores.get("filete", "#141518"))
		r["cor_contorno"] = String(cores.get("faixa", "#f2f2ee"))
		r["fonte_numero"] = String(equipe.get("fonte_numero", "condensado"))
	var logo := String(equipe.get("logo", ""))
	if logo != "" and ResourceLoader.exists(logo):
		r["logo"] = logo
		r["locais_logo"] = 1
	return r


static func cfg(dados: Node) -> Dictionary:
	return dados.equipe().get("pintura", {})


## Preço de mudar a cor e/ou as faixas ("" ou -1 = a definir: vale 0).
static func preco(dados: Node, jogador: Node, muda_cor: bool, muda_faixas: bool) -> int:
	var niveis := GestaoEquipe.ordem(dados)
	var k := GestaoEquipe.maior_licenca(dados, jogador)
	var ref := GestaoEquipe.premio_referencia(dados, niveis[k]) if k >= 0 else 0
	var total := 0.0
	if muda_cor and cfg(dados).get("fator_cor") != null:
		total += ref * float(cfg(dados)["fator_cor"])
	if muda_faixas and cfg(dados).get("fator_faixas") != null:
		total += ref * float(cfg(dados)["fator_faixas"])
	return roundi(total)


## O preço ainda não foi definido pelo usuário (os fatores estão null).
static func preco_definido(dados: Node) -> bool:
	return cfg(dados).get("fator_cor") != null and cfg(dados).get("fator_faixas") != null


## Aplica a pintura no carro (cor "#rrggbb", faixas {padrao, faixa, filete}).
## "" ou o motivo. O aro das rodas ("roda") vai junto e não custa: o preço é
## só o da cor e das faixas (não há preço de rodas definido).
static func aplicar(dados: Node, jogador: Node, carro: Carro, cor: String, faixas: Dictionary) -> String:
	var muda_cor := cor != carro.cor and not (carro.cor == "" and Color(cor) == Cores.fabrica(carro.id))
	faixas = normalizar(faixas)
	var muda_faixas := sem_roda(faixas) != sem_roda(carro.faixas)
	var muda_roda := Rodas.desenho_de(faixas) != Rodas.desenho_de(carro.faixas)
	if not muda_cor and not muda_faixas and not muda_roda:
		return "nada mudou"
	if not jogador.economia.debitar(preco(dados, jogador, muda_cor, muda_faixas)):
		return "saldo insuficiente"
	carro.cor = cor
	carro.faixas = faixas.duplicate()
	return ""


## Decisão 74: quantos desenhos ("padroes") ou logos ("logos") o jogador já
## liberou subindo no The Grid (grid_desafios.json → pinturas). Sem a
## configuração, todos.
static func liberados(dados: Node, jogador: Node, tipo: String, total: int) -> int:
	var c: Dictionary = dados.grid_desafios().get("pinturas", {})
	if not c.has(tipo + "_inicio"):
		return total
	var n := int(c[tipo + "_inicio"]) + int(c.get(tipo + "_por_posicao", 0)) * TheGrid.vencidas(jogador).size()
	return clampi(n, 0, total)


## Posição do Grid que libera o item de índice `i` (0 se já vem liberado).
static func posicao_que_libera(dados: Node, tipo: String, i: int) -> int:
	var c: Dictionary = dados.grid_desafios().get("pinturas", {})
	var ini := int(c.get(tipo + "_inicio", 0))
	var passo := maxi(int(c.get(tipo + "_por_posicao", 1)), 1)
	if not c.has(tipo + "_inicio") or i < ini:
		return 0
	return 10 - (i - ini) / passo  # a 1ª equipe vencida é a #10

