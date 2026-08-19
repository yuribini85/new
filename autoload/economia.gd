extends Node
## Módulo 4 — Economia. docs/mecanicas_para_godot.md #1 (recursos) e #2 (edifícios,
## fórmula de produção). Recursos, teto do depósito, índice de fome, venda.

signal recurso_mudou(recurso: String, valor: int)
signal indice_fome_mudou(valor: float)

var recursos: Dictionary = {
	"comida": 0.0, "madeira": 0.0, "tecido": 0.0, "ouro": 0.0, "folego": 0.0, "diamante": 0.0,
}
var indice_fome: float = 100.0

const RECURSOS_COM_TETO_DEPOSITO := ["comida", "madeira", "tecido"]

# ato1.json usa "produz" com o bem específico; economia.json#recursos agrupa vários
# bens sob o mesmo estoque de "comida" (curral/horta/padaria/taberna/pesca).
const MAPA_PRODUTO_PARA_RECURSO := {
	"madeira": "madeira",
	"vegetais": "comida",
	"carne": "comida",
	"pao": "comida",
}


func _ready() -> void:
	Sim.tick.connect(_on_tick)


func _on_tick() -> void:
	var penalidade := penalidade_fome()
	var comida_produzida := _produzir(penalidade)
	var comida_consumida := _consumir()
	_atualizar_indice_fome(comida_produzida - comida_consumida)


## especificacao_tecnica_v1.md #24 / mecanicas_para_godot.md #1: 200 no nível 1,
## +200 por nível; 0 se o Depósito ainda não foi construído (mesmo padrão do teto
## de offline sem a Casa das Fiandeiras).
func teto_deposito() -> int:
	if not Vila.edificios.has("deposito"):
		return 0
	var nivel: int = Vila.edificios["deposito"].nivel
	if nivel <= 0:
		return 0
	var cfg: Dictionary = Dados.economia().get("deposito", {})
	var base: int = cfg.get("base", 200)
	var por_nivel: int = cfg.get("por_nivel", 200)
	return base + por_nivel * (nivel - 1)


func penalidade_fome() -> float:
	var cfg: Dictionary = Dados.economia().get("indice_fome", {})
	var perda_por_ponto: float = cfg.get("perda_por_ponto", 0.008)
	var piso: float = cfg.get("piso", 0.3)
	return clampf(1.0 - (100.0 - indice_fome) * perda_por_ponto, piso, 1.0)


## Soma por pessoa (líder + órfãos alocados), cada um com seu bônus de aptidão.
## design/economia.md #4: "nível 1 é o personagem-líder, sozinho" — o líder em si
## ainda não é um Orfao (é conteúdo narrativo fixo, fora deste módulo), então conta
## como 1 pessoa neutra (sem bônus de aptidão/cicatriz).
func _produzir(penalidade: float) -> float:
	var por_pessoa: float = Dados.economia().get("producao", {}).get("por_pessoa_por_seg", 0.2)
	var bonus_aptidao_pct: float = Dados.ciclo().get("bonus_aptidao", 0.25)
	var catalogo := Dados.catalogo_edificios_ato1()
	var comida_produzida := 0.0

	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		if e.nivel <= 0:
			continue
		var produto: String = catalogo.get(id, {}).get("produz", "")
		var recurso: String = MAPA_PRODUTO_PARA_RECURSO.get(produto, "")
		if recurso == "":
			continue

		var grupo_aptidao := Populacao.aptidao_do_edificio(id)
		var producao := por_pessoa * penalidade  # o líder: sempre 1 pessoa, sem bônus
		for vaga in e.vagas_orfaos:
			if vaga == null or vaga == "" or not Populacao.orfaos.has(vaga):
				continue
			var o: Orfao = Populacao.orfaos[vaga]
			var bonus := (1.0 + bonus_aptidao_pct) if (grupo_aptidao != "" and o.aptidao == grupo_aptidao) else 1.0
			producao += por_pessoa * bonus * penalidade

		_adicionar(recurso, producao)
		if recurso == "comida":
			comida_produzida += producao

	return comida_produzida


func _consumir() -> float:
	var cfg: Dictionary = Dados.economia().get("consumo_por_min", {})
	var lider_por_min: float = cfg.get("lider", 1.5)
	var crianca_por_min: float = cfg.get("crianca", 1.0)
	var adulto_por_min: float = cfg.get("adulto", 1.5)
	var fator_noite: float = cfg.get("noite_fator", 0.5)

	var n_lideres := 0
	for id in Vila.edificios:
		if Vila.edificios[id].nivel > 0:
			n_lideres += 1

	var consumo_por_min := lider_por_min * n_lideres
	for id in Populacao.orfaos:
		var o: Orfao = Populacao.orfaos[id]
		match o.estado:
			Orfao.Estado.CRIANCA:
				consumo_por_min += crianca_por_min
			Orfao.Estado.ADULTO_OCIOSO, Orfao.Estado.ALOCADO:
				consumo_por_min += adulto_por_min

	var consumo_por_seg: float = consumo_por_min / 60.0
	if Sim.fase_dia == Sim.FaseDia.NOITE:
		consumo_por_seg *= fator_noite

	_remover("comida", consumo_por_seg)
	return consumo_por_seg


func _atualizar_indice_fome(saldo_comida_por_seg: float) -> void:
	var fator: float = Dados.economia().get("indice_fome", {}).get("fator_variacao_por_seg", 1.0)
	indice_fome = clampf(indice_fome + saldo_comida_por_seg * fator, 0.0, 100.0)
	indice_fome_mudou.emit(indice_fome)


func _adicionar(recurso: String, quantidade: float) -> void:
	if quantidade <= 0.0:
		return
	var novo: float = recursos[recurso] + quantidade
	if recurso in RECURSOS_COM_TETO_DEPOSITO:
		var teto := teto_deposito()
		if novo > teto:
			push_warning("Economia: %s excedeu o depósito (%.1f/%d), descartando excedente" % [recurso, novo, teto])
			novo = teto
	recursos[recurso] = novo
	recurso_mudou.emit(recurso, int(novo))


func _remover(recurso: String, quantidade: float) -> void:
	if quantidade <= 0.0:
		return
	recursos[recurso] = maxf(0.0, recursos[recurso] - quantidade)
	recurso_mudou.emit(recurso, int(recursos[recurso]))


## Vende ao preço de economia.json#precos_venda. Só cobre bens sem ambiguidade de
## sub-tipo (madeira por enquanto): comida tem preço por sub-bem (vegetais/carne/pão)
## que ainda não é rastreado separadamente do estoque unificado de "comida" — vender
## comida fica para quando essa modelagem for resolvida, em vez de estimar um preço.
func vender(recurso: String, quantidade: int) -> int:
	if quantidade <= 0 or recursos.get(recurso, 0.0) < quantidade:
		return 0
	var precos: Dictionary = Dados.economia().get("precos_venda", {})
	if not precos.has(recurso):
		push_warning("Economia: sem preço de venda definido para '%s'" % recurso)
		return 0
	var preco: float = precos[recurso]
	recursos[recurso] -= quantidade
	var ganho := int(quantidade * preco)
	recursos["ouro"] += ganho
	recurso_mudou.emit(recurso, int(recursos[recurso]))
	recurso_mudou.emit("ouro", int(recursos["ouro"]))
	return ganho


func get_save_data() -> Dictionary:
	return {
		"recursos": recursos,
		"indice_fome": indice_fome,
	}


func restaurar(salvo: Dictionary) -> void:
	if salvo.is_empty():
		return
	var r: Dictionary = salvo.get("recursos", {})
	for k in recursos:
		recursos[k] = r.get(k, recursos[k])
	indice_fome = salvo.get("indice_fome", indice_fome)
