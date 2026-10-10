extends SceneTree
## Playtest automático da campanha da história (fase F do documento Chrome &
## Wreckage): o agente (tools/agente.gd) joga o jogo novo pela campanha e cada
## ação dele dispara os mesmos triggers que a interface dispara, na mesma ordem
## (aba_eventos, aba_loja, aba.gd, aba_licencas, principal). As cenas que valem
## são "vistas" na hora (flags gravadas, encadeadas seguidas). Mede: tempo de
## corrida até cada marco, cenas por hora, intervalo entre comentários de
## contexto, cenas repetidas, travas (o agente parou) e o que nunca apareceu.
## Só lê o jogo; não muda dados.
##
## Uso: godot --headless --path . --script tools/playtest_campanha.gd -- [minutos] [campanha]
## (padrão: 90 minutos de corrida, a campanha de historia.json → nova_campanha).

const PERFIS := ["sugestoes", "explora", "renda"]

var d: Node
var ag
var h: Historia
var vistas := []  # [{t, id, trigger, reativa}]
var _primeira_prova := true
var _licencas_vistas := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 90.0
	d = preload("res://autoload/dados.gd").new()
	d.carregar("res://data/")
	var campanha := args[1] if args.size() > 1 else Prologo.campanha(d)
	print("PLAYTEST campanha=%s, %.0f min de corrida por perfil" % [campanha, minutos])
	var cenas_ids := {}
	for c in d.lista("dialogos"):
		var quem = c.get("personagem")
		if quem != null and (campanha in quem if quem is Array else quem == campanha):
			cenas_ids[c["id"]] = c["trigger"]
	var nunca := cenas_ids.duplicate()
	for perfil in PERFIS:
		vistas = []
		_primeira_prova = true
		_licencas_vistas = false
		ag = preload("res://tools/agente.gd").new(d, perfil, 7)
		h = Historia.new(d, ag.j)
		ag.j.historia = h
		ag.ouvinte = _acao
		var r: Dictionary = ag.jogar_campanha(campanha, minutos * 60.0)
		if r.has("erro"):
			print("ERRO: ", r["erro"])
			quit(1)
			return
		_relatorio(perfil, r)
		for v in vistas:
			nunca.erase(v["id"])
		ag.liberar()
	print("\nCENAS DA CAMPANHA QUE NENHUM PERFIL VIU (%d de %d):" % [nunca.size(), cenas_ids.size()])
	for id in nunca:
		print("  %s (%s)" % [id, nunca[id]])
	d.free()
	quit()


## Ação do agente → os triggers que a interface dispara para ela.
func _acao(acao: String, ctx: Dictionary) -> void:
	var j: Node = ag.j
	j.carro_ativo = ag.uid
	match acao:
		"inicio":
			_disparar("GAME_START")
			_disparar("EVOLUCAO")  # a cena manda tocar em Freios
		"peca":
			var falou := _disparar("PECA_COMPRADA", {"peca": ctx["peca"]})
			if ctx["id"] == Prologo.demanda(d, j):
				falou = _disparar("DEMANDA_CONCLUIDA", {"peca": ctx["peca"]}) or falou
			if not falou and h.caixa_baixo():
				_disparar("CAIXA_BAIXO")
		"carro":
			var nome := String(d.carro(ctx["carro_id"])["nome"])
			var falou := _disparar("COMPRA_CARRO", {"carro": nome})
			if ctx["novo"]:
				falou = _disparar("COMPRA_CARRO_NOVO") or falou
			if j.garagem.lista().size() == 2:
				falou = _disparar("GARAGEM_DOIS_CARROS") or falou
			if not falou:
				var _f := _disparar("COLECAO", {"quantidade": h.colecao()}) \
						or (h.carro_caro(int(ctx["preco"])) and _disparar("COMPRA_CARRO_CARA", {"carro": nome})) \
						or (h.caixa_baixo() and _disparar("CAIXA_BAIXO"))
		"largada":
			# Inscrição (aba_eventos._correr): a cena da seleção, a do campeonato
			# (etapa na ordem) e a da largada.
			var ev_ctx := {"evento": ctx["evento"]}
			if _primeira_prova:
				_disparar("ABA:EVENTOS")
			_disparar("EVENTO_SELECIONADO", ev_ctx)
			var ev: Dictionary = d.evento(ctx["evento"])
			var etapas := Campeonatos.etapas(d, Campeonatos.serie(ev))
			if not etapas.is_empty() and etapas.find(ev) == int(Campeonatos.estado(j, Campeonatos.serie(ev))["etapa"]):
				_disparar("CAMPEONATO_SELECIONADO", ev_ctx)
			_disparar("CORRIDA_INICIO", ev_ctx)
		"pronta":
			_disparar("LICENCA_DISPONIVEL:" + String(ctx["licenca"]))
			_disparar("LICENCA_PRONTA")
		"corrida":
			var ev_ctx := {"evento": ctx["evento"]}
			_disparar("CORRIDA_FIM", {"posicao": ctx["posicao"], "evento": ctx["evento"]})
			if ctx["campeao"]:
				_disparar("CAMPEONATO_VENCIDO", ev_ctx)
			if _primeira_prova:
				_primeira_prova = false
			if not _licencas_vistas and j.flags.has("FIRST_RACE_DONE"):
				_licencas_vistas = true
				_disparar("ABA:LICENCAS")  # a cena do resultado manda ir para Carreira
		"treino":
			_disparar("LICENCA_TREINO_INICIO")
		"licenca":
			_disparar("LICENCA_CONCEDIDA:" + String(ctx["licenca"]))


## Mostra a cena do trigger (e as encadeadas) como se o jogador lesse tudo.
func _disparar(trigger: String, ctx: Dictionary = {}) -> bool:
	var c := h.cena_para(trigger, ctx)
	if c.is_empty():
		return false
	while not c.is_empty():
		vistas.append({"t": ag.tempo, "id": c["id"], "trigger": trigger, "reativa": c.get("reativa", false),
				"corrida": ag.j.dias})
		for f in c.get("falas", []):
			var a := String(f.get("acao", ""))
			if a == "UNLOCK_TEAM_TAB":
				EquipeJogador.criar(ag.j)
			elif a == "OPEN_DRIVER_HIRE":
				EquipeJogador.liberar_segundo(d, ag.j)
		c = h.concluir(c)
	return true


func _relatorio(perfil: String, r: Dictionary) -> void:
	print("\n=== perfil %s: %.0f min de corrida, %d corridas, %d/%d provas vencidas, saldo %d, licenças %s"
			% [perfil, r["tempo"] / 60.0, ag.j.dias, r["vencidas"], r["provas"], r["saldo"], r["licencas"]])
	var m: Dictionary = r["marcos"]
	for k in ["primeira_vitoria", "licenca_b", "vitoria_b", "licenca_a"]:
		print("  %-17s %s" % [k, "%.0f min" % (m[k] / 60.0) if m.has(k) else "—"])
	for linha in r["log"]:
		if "parou" in linha or "não resolvidos" in linha:
			print("  TRAVA: " + linha)
	print("  cenas: %d (%.1f por hora de corrida)" % [vistas.size(), vistas.size() / maxf(r["tempo"] / 3600.0, 0.01)])
	var vez := {}
	var ultima_reativa := -1000
	for v in vistas:
		vez[v["id"]] = int(vez.get(v["id"], 0)) + 1
		var marca := ""
		if v["reativa"]:
			if v["corrida"] - ultima_reativa < h.intervalo_reativas():
				marca = "  <- REATIVA ANTES DO INTERVALO"
			ultima_reativa = v["corrida"]
		print("    %5.1f min · corrida %3d · %-14s %s%s" % [v["t"] / 60.0, v["corrida"], v["id"], v["trigger"], marca])
	for id in vez:
		if vez[id] > 1:
			var c: Dictionary = d.item("dialogos", id)
			print("  repetida %dx: %s%s" % [vez[id], id, " (repetível)" if not c.get("uma_vez", true) else "  <- NÃO DEVIA"])
