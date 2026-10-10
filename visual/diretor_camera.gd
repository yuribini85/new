class_name DiretorCamera
extends RefCounted
## Câmera AUTO: escolhe o enquadramento conforme o que acontece na corrida,
## só com os planos que já existem (seguir um carro, dois carros no quadro,
## pista toda). O resultado já está decidido pela simulação, então o diretor
## sabe antes quem vai passar quem.
##
## Prioridades (maior ganha): chegada do jogador; ultrapassagem iminente;
## disputa de perto; aproximação do líder; última volta; o seu carro. Planos
## longe do jogador duram pouco e a câmera volta para ele.
##
## Apresentação, não balanceamento: os tempos abaixo são de ritmo de câmera.

const ABERTURA_S := 2.5  # grid de cima no começo da corrida (Corrida3D.enquadrar_grid)
const MIN_PLANO_S := 4.0  # um plano dura pelo menos isto (salvo prioridade maior)
const TROCA_MIN_S := 1.5  # nem prioridade maior corta antes disto
const MAX_FORA_S := 8.0  # longe do jogador, no máximo isto
const SUMIU_S := 1.2  # o motivo do plano sumiu há isto: pode trocar
const NO_JOGADOR_MIN_S := 4.0  # de volta ao jogador, fica pelo menos isto
const DISPUTA_M := 6.0
const ULTRAPASSAGEM_M := 12.0
const ANTECEDENCIA_S := 1.6
const LIDER_S := 1.0
const CHEGADA_M := 150.0

## {"foco", "com", "geral", "motivo", "prio"}
var plano := {"foco": "jogador", "com": "", "geral": false, "motivo": "jogador", "prio": 1}
var _inicio := -INF
var _visto := -INF
var _de_volta := -INF


func reiniciar() -> void:
	plano = {"foco": "jogador", "com": "", "geral": false, "motivo": "jogador", "prio": 1}
	_inicio = -INF
	_visto = -INF
	_de_volta = -INF


## Plano para o tempo atual de `f`. `meta`: distância total da corrida (m);
## `comprimento`: uma volta; `voltas`: total.
func atualizar(f: CorridaVisual, meta: float, comprimento: float, voltas: int) -> Dictionary:
	var t := f.tempo
	var melhor := _candidato(f, t, meta, comprimento, voltas)
	if _inicio == -INF:
		_trocar(melhor, t)
		return plano
	if melhor["foco"] == plano["foco"] and melhor["com"] == plano["com"] and melhor["geral"] == plano["geral"]:
		_visto = t
		plano["motivo"] = melhor["motivo"]
		plano["prio"] = melhor["prio"]
		return plano
	var dur := t - _inicio
	var longe: bool = plano["foco"] != "jogador" or plano["geral"]
	if plano["motivo"] == "abertura":
		_trocar(melhor, t)
	elif longe and dur >= MAX_FORA_S and melhor["prio"] < 8:
		_trocar(_no_jogador(), t)
	elif melhor["prio"] > plano["prio"] and dur >= TROCA_MIN_S:
		_trocar(melhor, t)
	elif dur >= MIN_PLANO_S and t - _visto >= SUMIU_S:
		_trocar(melhor, t)
	return plano


func _trocar(novo: Dictionary, t: float) -> void:
	# Plano longe do jogador logo depois de voltar a ele: espera (sem pingue-pongue).
	if (novo["foco"] != "jogador" or novo["geral"]) and novo["prio"] < 6 and t - _de_volta < NO_JOGADOR_MIN_S \
			and _inicio != -INF:
		novo = _no_jogador()
	if novo["foco"] == "jogador" and not novo["geral"] and (plano["foco"] != "jogador" or plano["geral"]):
		_de_volta = t
	plano = novo
	_inicio = t
	_visto = t


func _no_jogador() -> Dictionary:
	return {"foco": "jogador", "com": "", "geral": false, "motivo": "jogador", "prio": 1}


func _candidato(f: CorridaVisual, t: float, meta: float, comprimento: float, voltas: int) -> Dictionary:
	var ordem := f.ordem()
	if t < ABERTURA_S and _inicio == -INF or (t < ABERTURA_S and plano["motivo"] == "abertura"):
		return {"foco": "jogador", "com": "", "geral": false, "motivo": "abertura", "prio": 9}
	var s := {}
	for id in ordem:
		s[id] = f.distancia(id)
	var pj: float = s.get("jogador", 0.0)
	if pj >= meta - CHEGADA_M:
		return {"foco": "jogador", "com": "", "geral": false, "motivo": "chegada", "prio": 8}
	var melhor := _no_jogador()
	for i in range(1, ordem.size()):
		var a: String = ordem[i - 1]
		var b: String = ordem[i]
		if float(s[a]) >= meta or float(s[b]) >= meta:
			continue
		var gap := float(s[a]) - float(s[b])
		var do_jogador := a == "jogador" or b == "jogador"
		if gap < ULTRAPASSAGEM_M and _vai_passar(f, b, a, t):
			var c := {"foco": b, "com": a, "geral": false, "motivo": "ultrapassagem", "prio": 7 if do_jogador else 5}
			if c["prio"] > melhor["prio"]:
				melhor = c
		elif gap < DISPUTA_M:
			var c := {"foco": b, "com": a, "geral": false, "motivo": "disputa", "prio": 6 if do_jogador else 4}
			if c["prio"] > melhor["prio"]:
				melhor = c
	if melhor["prio"] < 3 and ordem.size() > 1 and ordem[1] != "jogador" and ordem[0] != "jogador":
		var tl := f.tempo_em(ordem[0], float(s[ordem[1]]))
		if tl >= 0.0 and t - tl < LIDER_S:
			melhor = {"foco": ordem[1], "com": ordem[0], "geral": false, "motivo": "lider", "prio": 3}
	if melhor["prio"] < 2 and voltas > 1 and pj >= comprimento * (voltas - 1):
		melhor = {"foco": "jogador", "com": "", "geral": false, "motivo": "ultima_volta", "prio": 2}
	return melhor


## b passa a nos próximos ANTECEDENCIA_S?
static func _vai_passar(f: CorridaVisual, b: String, a: String, t: float) -> bool:
	var k := t
	while k < t + ANTECEDENCIA_S:
		k += 0.1
		if f.distancia_em(b, k) > f.distancia_em(a, k) + 0.5:
			return true
	return false
