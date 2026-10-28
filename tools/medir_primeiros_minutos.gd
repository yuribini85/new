extends SceneTree
## Ritmo do começo do The Fastfather (análise de engajamento, 2026-10-28): um
## jogador que compra sempre a melhoria aberta mais barata, segue a escada de
## desbloqueios (paga as ofertas quando dá), recebe o prêmio pingando como na
## tela e nunca segura a corrida. Mede o
## tempo até a primeira compra e quantas compras cabem no primeiro minuto e
## depois. Critério dos idles de referência: primeira compra em menos de 10 s
## e umas cinco no primeiro minuto (não é número do jogo, é o alvo a medir).
## Uso: godot --headless --path . --script res://tools/medir_primeiros_minutos.gd

const MARCAS_S := [10.0, 30.0, 60.0, 120.0, 300.0, 600.0]
const PAUSA_S := 6.0  # semáforo e chegada, como no calibrador


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var d := root.get_node("Dados")
	var e := IdleEstado.new()
	var primeiro := e.carro_da_modalidade()
	if not primeiro.is_empty():
		e.comprar_carro(String(primeiro["id"]))
	var t := 0.0
	var compras := 0
	var primeira := -1.0
	var marca := 0
	var semente := 1
	var linhas := []
	while marca < MARCAS_S.size():
		# Escada: a conversa da vez abre (de graça) ou é paga quando der.
		var c := e.proxima_conversa()
		if not c.is_empty():
			e.oferecer(String(c["id"]))
		for o in e.ofertas_abertas():
			e.comprar_desbloqueio(String(o["id"]))
		var r := e.correr(d, semente, false)
		semente += 1
		var dur := float(r["carros"]["jogador"]["tempo_total"]) + PAUSA_S
		if semente <= 4:
			print("corrida %d: %.0f s, %dº, prêmio $%s" % [semente - 1, dur, IdleEstado.posicao(r), IdleUI.curto(e.premio(IdleEstado.posicao(r)))])
		# Compras durante a corrida: a renda entra aos poucos; o prêmio no fim.
		var passo := 1.0
		var dentro := 0.0
		# O prêmio pinga durante a corrida (a tela paga assim); a pausa não paga.
		var premio := e.premio(IdleEstado.posicao(r))
		var correndo := dur - PAUSA_S
		var pago := 0.0
		while dentro < dur:
			var dt := minf(passo, dur - dentro)
			e.dinheiro += e.renda_s() * dt
			var parte := premio * clampf((dentro + dt) / correndo, 0.0, 1.0) - pago
			e.dinheiro += parte
			pago += parte
			dentro += dt
			t += dt
			while true:
				var barata := ""
				var custo := INF
				for m in e.cfg["melhorias"]:
					var id := String(m["id"])
					if e.tem("melhoria:" + id) and e.pode_comprar(id) and e.custo(id) < custo:
						custo = e.custo(id)
						barata = id
				if barata == "":
					break
				e.comprar_varios(barata, 1)
				compras += 1
				if primeira < 0.0:
					primeira = t
			while marca < MARCAS_S.size() and t >= MARCAS_S[marca]:
				linhas.append("%4d s: %2d compras, %d corridas, $%s" % [int(MARCAS_S[marca]), compras, e.corridas,
						IdleUI.curto(e.dinheiro)])
				marca += 1
		e.concluir(IdleEstado.posicao(r))
		e.dinheiro -= pago
	print("primeira compra: %.0f s" % primeira)
	for l in linhas:
		print(l)
	quit()
