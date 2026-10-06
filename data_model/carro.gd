class_name Carro
extends RefCounted
## Carro na garagem (do jogador ou de um adversário). Atributos base vêm de
## data/carros.json; peças de data/pecas.json; pneus de data/pneus.json.
## Aqui só existem as regras de combinação — nenhum número de balanceamento.

const ATRIBUTOS := ["potencia", "peso", "aderencia", "freio", "velocidade_max"]
const TRACOES := ["FF", "FR", "MR", "RR", "4WD"]
const OPS := ["soma", "mult"]

var id: String
## Identificador da unidade na garagem; o jogador pode ter dois do mesmo modelo.
var uid: int = -1
var base: Dictionary
## Peças compradas para este carro (ids). Reinstalar uma peça possuída é grátis.
var pecas_possuidas: Array = []
## categoria -> peça instalada. Uma peça por categoria, como no GT2.
var pecas: Dictionary = {}
## Compostos possuídos. O piloto de IA escolhe sozinho conforme a condição.
var pneus: Array = []
## Pintura escolhida na garagem ("" = de fábrica). Só visual.
var cor: String = ""
## Ajuste do câmbio ajustável (peça "cambio"): "", "curto" ou "longo".
var ajuste_cambio: String = ""
## Configurações salvas pelo jogador: [{nome, pecas: [ids], ajuste_cambio}].
## Só guardam escolhas entre peças já compradas; equipar é grátis.
var configuracoes: Array = []

## Fração do caminho do diferencial de fábrica até o limite do GT2 nos
## ajustes curto/longo. Provisório (decisão de interface, não do GT2).
const PASSO_CAMBIO := 0.5


func _init(dados_carro: Dictionary) -> void:
	id = dados_carro["id"]
	base = dados_carro


## Retorna "" se a peça pode ser instalada, ou o motivo da recusa.
func motivo_recusa(peca: Dictionary) -> String:
	var tracoes: Array = peca.get("tracao_permitida", [])
	if not tracoes.is_empty() and not base["tracao"] in tracoes:
		return "peça %s não serve para tração %s" % [peca["id"], base["tracao"]]
	var carros: Array = peca.get("carros_permitidos", [])
	if not carros.is_empty() and not id in carros:
		return "peça %s não serve para o carro %s" % [peca["id"], id]
	return ""


## Instala substituindo a peça da mesma categoria. Retorna false se recusada.
func instalar(peca: Dictionary) -> bool:
	if motivo_recusa(peca) != "":
		return false
	pecas[peca["categoria"]] = peca
	return true


func remover(categoria: String) -> void:
	pecas.erase(categoria)


## Peças instaladas (ids em ordem) e ajuste do câmbio: o que uma inscrição
## na fila guarda e o que uma configuração salva contém.
func configuracao() -> Dictionary:
	var ids: Array = pecas.values().map(func(p): return p["id"])
	ids.sort()
	return {"pecas": ids, "ajuste_cambio": ajuste_cambio}


## Cópia com a configuração montada. `peca_por_id` resolve ids (Dados.peca);
## id desconhecido ou peça recusada fica de fora. Com "pneus" na configuração
## (cópia da inscrição na fila) e `pneu_por_id`, os pneus também são os dela.
func com_configuracao(cfg: Dictionary, peca_por_id: Callable, pneu_por_id: Callable = Callable()) -> Carro:
	var c := copiar()
	c.pecas = {}
	for pid in cfg.get("pecas", []):
		var p: Dictionary = peca_por_id.call(pid)
		if not p.is_empty():
			c.instalar(p)
	c.ajuste_cambio = String(cfg.get("ajuste_cambio", ""))
	if cfg.has("pneus") and pneu_por_id.is_valid():
		c.pneus = []
		for pid in cfg["pneus"]:
			var pn: Dictionary = pneu_por_id.call(pid)
			if not pn.is_empty():
				c.adicionar_pneu(pn)
	return c


## Equipa uma configuração salva no próprio carro. Só peças já compradas
## para ele entram; retorna as que ficaram de fora (ids).
func equipar(cfg: Dictionary, peca_por_id: Callable) -> Array:
	var fora := []
	pecas = {}
	for pid in cfg.get("pecas", []):
		var p: Dictionary = peca_por_id.call(pid)
		if p.is_empty() or not pid in pecas_possuidas or not instalar(p):
			fora.append(pid)
	ajuste_cambio = String(cfg.get("ajuste_cambio", ""))
	return fora


func adicionar_pneu(pneu: Dictionary) -> void:
	for p in pneus:
		if p["id"] == pneu["id"]:
			return
	pneus.append(pneu)


## O composto possuído com maior aderência na condição. Vazio se não há pneu.
func escolher_pneu(condicao: String) -> Dictionary:
	var melhor := {}
	for p in pneus:
		if melhor.is_empty() or p["aderencia"][condicao] > melhor["aderencia"][condicao]:
			melhor = p
	return melhor


## Atributos usados pela simulação. Efeitos "soma" são aplicados antes dos
## "mult", para que a ordem de instalação não altere o resultado.
func atributos_efetivos(condicao: String) -> Dictionary:
	var attrs := {}
	for a in ATRIBUTOS:
		# velocidade_max é opcional: sem ela, o arrasto da simulação limita.
		attrs[a] = INF if base.get(a) == null else float(base[a])
	for op in OPS:
		for categoria in pecas:
			for efeito in pecas[categoria].get("efeitos", []):
				if efeito["op"] != op:
					continue
				if op == "soma":
					attrs[efeito["atributo"]] += float(efeito["valor"])
				else:
					attrs[efeito["atributo"]] *= float(efeito["valor"])
	var pneu := escolher_pneu(condicao)
	if pneu.is_empty():
		push_error("Carro %s sem pneu para correr" % id)
	else:
		attrs["aderencia"] *= float(pneu["aderencia"][condicao])
	attrs["tracao"] = base["tracao"]
	# Fração do peso no eixo dianteiro (GT2, Chassis); a simulação usa o peso
	# sobre o eixo motriz para a tração. Opcional: sem ela, fator por tração.
	if base.get("peso_dianteiro") != null:
		attrs["peso_dianteiro"] = float(base["peso_dianteiro"])
	attrs["pneu"] = pneu.get("id", "")
	_motor_e_cambio(attrs)
	return attrs


## Curva de torque com as peças e o câmbio, para a simulação por marcha.
## A forma vem das peças (aspirado estica a faixa e o corte; turbo leva o
## ganho para o giro alto); a escala faz o pico de potência ser exatamente a
## potência efetiva acima, para os números da tela e da regra das provas
## baterem com o que a simulação usa.
func _motor_e_cambio(attrs: Dictionary) -> void:
	var motor: Dictionary = base.get("motor", {})
	var cambio: Dictionary = base.get("cambio", {})
	if motor.is_empty() or cambio.is_empty() or base.get("raio_roda") == null:
		return
	var rpm := PackedFloat64Array(motor["rpm"])
	var tq := PackedFloat64Array(motor["torque_nm"])
	var corte := float(motor["corte"])
	var faixa := 0.0
	var turbo_baixa := 1.0
	var turbo_alta := 1.0
	for cat in pecas:
		var forma: Dictionary = pecas[cat].get("motor", {})
		faixa += float(forma.get("faixa_rpm", 0.0))
		corte += float(forma.get("corte", 0.0))
		if forma.has("turbo_alta"):
			turbo_baixa = float(forma["turbo_baixa"])
			turbo_alta = float(forma["turbo_alta"])
	var r0 := rpm[0]
	var r1 := rpm[rpm.size() - 1]
	for i in rpm.size():
		var t := (rpm[i] - r0) / maxf(r1 - r0, 1.0)
		rpm[i] += faixa * t
		tq[i] *= lerpf(turbo_baixa, turbo_alta, smoothstep(0.3, 0.75, t))
	corte = maxf(corte + faixa, rpm[0])
	var pico := 0.0
	for i in rpm.size():
		if rpm[i] <= corte + 1.0:
			pico = maxf(pico, tq[i] * rpm[i])
	var alvo := float(attrs["potencia"]) / CV_POR_NM_RPM
	if pico > 0.0:
		for i in tq.size():
			tq[i] *= alvo / pico
	attrs["curva_rpm"] = rpm
	attrs["curva_nm"] = tq
	attrs["corte"] = corte
	attrs["relacoes"] = PackedFloat64Array(cambio["relacoes"])
	var final := float(cambio["final"])
	var ajustavel: Dictionary = pecas.get("cambio", {}).get("cambio", {})
	if not ajustavel.is_empty() and ajuste_cambio == "curto":
		final += (float(ajustavel["final_max"]) - final) * PASSO_CAMBIO
	elif not ajustavel.is_empty() and ajuste_cambio == "longo":
		final -= (final - float(ajustavel["final_min"])) * PASSO_CAMBIO
	attrs["final"] = final
	attrs["raio_roda"] = float(base["raio_roda"])


## cv = N·m × rpm × este fator (1 cv = 735,5 W; ω = rpm × 2π/60).
const CV_POR_NM_RPM := TAU / 60.0 / 735.49875


## Cópia independente (mesmas peças instaladas e possuídas, mesmos pneus).
func copiar() -> Carro:
	var c := Carro.new(base)
	c.uid = uid
	c.pecas = pecas.duplicate()
	c.pecas_possuidas = pecas_possuidas.duplicate()
	c.pneus = pneus.duplicate()
	c.cor = cor
	c.ajuste_cambio = ajuste_cambio
	c.configuracoes = configuracoes.duplicate(true)
	return c
