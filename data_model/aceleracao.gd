class_name Aceleracao
extends RefCounted
## Corridas aceleradas (decisão 39): enquanto ativa, o relógio das corridas anda
## `fator` vezes mais rápido. Prêmios iguais; só o tempo encolhe. Vale com o app
## fechado (a janela é em tempo absoluto). Cada ativação soma `duracao_s`.
##
## Relógio do jogo = tempo real + o que as janelas já adiantaram. Tudo que mede
## a fila (início, fim, processamento) usa este relógio, nunca o real direto.
## Estado no jogador: {ganho, inicio, fim, fator} ({} = nunca ativada).


## Relógio das corridas no instante `real` (segundos Unix).
static func agora(jogador: Node, real: float = Time.get_unix_time_from_system()) -> float:
	var a: Dictionary = jogador.aceleracao
	if a.is_empty():
		return real
	var dentro := clampf(real - float(a["inicio"]), 0.0, float(a["fim"]) - float(a["inicio"]))
	return real + float(a["ganho"]) + (float(a["fator"]) - 1.0) * dentro


static func ativa(jogador: Node, real: float = Time.get_unix_time_from_system()) -> bool:
	return restante_s(jogador, real) > 0.0


## Segundos reais que faltam de aceleração.
static func restante_s(jogador: Node, real: float = Time.get_unix_time_from_system()) -> float:
	var a: Dictionary = jogador.aceleracao
	return 0.0 if a.is_empty() else maxf(float(a["fim"]) - maxf(real, float(a["inicio"])), 0.0)


static func fator(jogador: Node, regras: Dictionary) -> float:
	return float(jogador.aceleracao["fator"]) if ativa(jogador) else float(regras.get("fator", 1.0))


## Soma `duracao_s` (até `teto_s`, se houver). "" ou o motivo de não poder.
static func ativar(jogador: Node, regras: Dictionary, real: float = Time.get_unix_time_from_system()) -> String:
	if regras.is_empty() or regras.get("fator") == null or regras.get("duracao_s") == null:
		return "aceleração indisponível"
	var dur := float(regras["duracao_s"])
	var teto = regras.get("teto_s")
	var a: Dictionary = jogador.aceleracao
	if ativa(jogador, real):
		if teto != null and restante_s(jogador, real) >= float(teto):
			return "o tempo de aceleração já está no máximo"
		var fim := float(a["fim"]) + dur
		if teto != null:
			fim = minf(fim, real + float(teto))
		a["fim"] = fim
		return ""
	# Janela anterior encerrada: o que ela adiantou fica no ganho.
	var ganho := 0.0
	if not a.is_empty():
		ganho = float(a["ganho"]) + (float(a["fator"]) - 1.0) * (float(a["fim"]) - float(a["inicio"]))
	var d := dur if teto == null else minf(dur, float(teto))
	jogador.aceleracao = {"ganho": ganho, "inicio": real, "fim": real + d, "fator": float(regras["fator"])}
	return ""


## "29:41" ou "1:05:00".
static func texto_tempo(segundos: float) -> String:
	var s := ceili(segundos)
	return "%d:%02d:%02d" % [s / 3600, s / 60 % 60, s % 60] if s >= 3600 else "%d:%02d" % [s / 60, s % 60]
