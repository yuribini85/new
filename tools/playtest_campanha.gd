extends SceneTree
## Playtest automático da campanha da história (fase F do documento Chrome &
## Wreckage): o agente (tools/agente.gd) joga o jogo novo pela campanha e cada
## ação dele dispara os mesmos triggers que a interface dispara, na mesma ordem
## (aba_eventos, aba_loja, aba.gd, aba_licencas, principal). As cenas que valem
## são "vistas" na hora (flags gravadas, encadeadas seguidas). Mede: tempo de
## corrida até cada marco, cenas por hora, intervalo entre comentários de
## contexto, cenas repetidas, travas (o agente parou) e o que nunca apareceu.
## Também o caminho até a arena e o The Grid (análise de 2026-10-19): o segundo
## carro (comprado ou de prêmio), a arena aberta e cada desafio de corrida do
## Grid que a licença libera (o agente tenta no máximo um a cada GRID_INTERVALO_S
## de corrida; os de arena só contam como liberados). Ao lado de cada marco, o
## tempo real mínimo jogando sem parar: o combustível (tanque e renovação de
## monetizacao.json) limita as corridas depois do tanque.
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
## Carros na garagem na última conferência (o prêmio entra sem ação de compra).
var _carros := 0
## Corrida (jogador.dias) de cada marco do caminho até a arena e o Grid.
var _dias := {}
var _grid_t := -1.0e9
const GRID_INTERVALO_S := 600.0


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
		_carros = 0
		_dias = {}
		_grid_t = -1.0e9
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
			# Decisão 73: a cena pede o nome; com ele, a Mara segue para o carro.
			j.nome_admin = "Playtest"
			_disparar("NOME_DEFINIDO")
			_disparar("EVOLUCAO")  # a cena manda tocar em Freios
		"peca":
			var falou := _disparar("PECA_COMPRADA", {"peca": ctx["peca"]})
			if ctx["id"] == Prologo.demanda(d, j):
				falou = _disparar("DEMANDA_CONCLUIDA", {"peca": ctx["peca"]}) or falou
				# Decisão 69: a cena abre a Equipe e o jogador contrata o piloto de corrida.
				EquipeJogador.criar(j)
				_disparar("ABA:EQUIPE")
				var corrida: Array = EquipeJogador.candidatos(d).filter(func(c): return c.get("tipo") == "corrida")
				if not corrida.is_empty():
					EquipeJogador.contratar(d, j, String(corrida[0]["id"]), "corrida")
					_disparar("PILOTO_CONTRATADO", {"vaga": "corrida"})
			if not falou and h.caixa_baixo():
				_disparar("CAIXA_BAIXO")
		"carro":
			var nome := String(d.carro(ctx["carro_id"])["nome"])
			var falou := _disparar("COMPRA_CARRO", {"carro": nome})
			if ctx["novo"]:
				falou = _disparar("COMPRA_CARRO_NOVO") or falou
			if j.garagem.lista().size() == 2:
				falou = _disparar("GARAGEM_DOIS_CARROS") or falou
			if j.garagem.lista().size() >= ArenaCarreira.carros_minimos(d):
				falou = _disparar("GARAGEM_TRES_CARROS") or falou
			_carros = j.garagem.lista().size()
			if _carros >= 2:
				_marco("segundo_carro")
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
		"disponivel":
			_disparar("LICENCA_DISPONIVEL:" + String(ctx["licenca"]))
		"corrida":
			var ev_ctx := {"evento": ctx["evento"]}
			# A ordem de Historia.disparar_fim: cena da chegada, marco, comentário.
			var fim := {"posicao": ctx["posicao"], "evento": ctx["evento"]}
			if not _disparar("CORRIDA_FIM", fim, false) and not _marco_vitoria(ctx):
				_disparar("CORRIDA_FIM", fim)
			if ctx["campeao"]:
				_disparar("CAMPEONATO_VENCIDO", ev_ctx)
			if _primeira_prova:
				_primeira_prova = false
			if not _licencas_vistas and j.flags.has("FIRST_RACE_DONE"):
				_licencas_vistas = true
				_disparar("ABA:LICENCAS")  # a cena do resultado manda ir para Carreira
			_depois_da_corrida()
		"treino":
			_disparar("LICENCA_TREINO_INICIO")
		"licenca":
			_disparar("LICENCA_CONCEDIDA:" + String(ctx["licenca"]))


## Como principal.gd depois de uma corrida: o carro-prêmio (a conversa do
## segundo carro e a arena, _carros_de_premio e _checar_arena) e o Grid.
func _depois_da_corrida() -> void:
	var j: Node = ag.j
	var n: int = j.garagem.lista().size()
	if n > _carros:
		if _carros < 2 and n >= 2:
			_disparar("GARAGEM_DOIS_CARROS")
			_marco("segundo_carro")
		_carros = n
	if n >= ArenaCarreira.carros_minimos(d) and not j.flags.has(EquipeJogador.FLAG_ARENA):
		_disparar("GARAGEM_TRES_CARROS")
	if j.flags.has("ARENA_INTRO"):
		_marco("arena")
	_tentar_grid()


## O desafio da equipe da vez, se a licença dela já é do jogador: o de corrida
## é disputado com o carro do agente; o de arena só fica registrado como liberado.
func _tentar_grid() -> void:
	var j: Node = ag.j
	var eq := TheGrid.da_vez(d, j)
	if eq.is_empty() or ag.tempo - _grid_t < GRID_INTERVALO_S:
		return
	var lic := String(eq.get("nivel", ""))
	if lic != "" and not lic in j.licencas:
		return
	var pos := TheGrid.posicao(d, j)
	var des := GridDesafio.de(d, eq)
	_marco("grid_%d_liberado (%s)" % [pos - 1, des.get("modo", "?")])
	if des.get("modo") != "corrida":
		return
	_grid_t = ag.tempo
	var r: Dictionary = ag._correr(GridDesafio.PREFIXO + String(eq["id"]), "grid")
	if r.is_empty() or int(r["posicao"]) != 1:
		return
	_marco("grid_%d_vencido" % (pos - 1))
	var depois := TheGrid.posicao(d, j)
	var ctx := {"equipe": String(eq["nome"]), "posicao_grid": depois, "posicao": depois}
	if not (depois == 1 and _disparar("GRID_TOPO", ctx)):
		_disparar("GRID_SUBIU", ctx)


func _marco(k: String) -> void:
	if not ag.marcos.has(k):
		ag.marcos[k] = ag.tempo
		_dias[k] = ag.j.dias


## Os marcos de vitória de Historia.disparar_fim (sem a CORRIDA_FIM, já tentada).
func _marco_vitoria(ctx: Dictionary) -> bool:
	var j: Node = ag.j
	var ev := String(ctx["evento"])
	if int(ctx["posicao"]) != 1 or int(j.vitorias.get(ev, 0)) != 1:
		return false  # não é vitória inédita
	var lic := String(d.evento(ev)["restricoes"].get("licenca", ""))
	var mesma := func(e) -> bool: return e != ev and String(d.evento(e)["restricoes"].get("licenca", "")) == lic
	var outras: Array = j.vitorias.keys().filter(mesma)
	if lic != "" and outras.is_empty() and _disparar("VITORIA_LICENCA:" + lic, ctx):
		return true
	return _disparar("VITORIA", {"quantidade": j.vitorias.size()})


## Mostra a cena do trigger (e as encadeadas) como se o jogador lesse tudo.
func _disparar(trigger: String, ctx: Dictionary = {}, reativas := true) -> bool:
	var c := h.cena_para(trigger, ctx, reativas)
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
		var demo: bool = c.get("falas", []).any(func(f): return String(f.get("acao", "")) == "ARENA_DEMO")
		c = h.concluir(c)
		if demo and c.is_empty():
			c = h.cena_para("ARENA_DEMO_FIM")  # a luta de demonstração terminou
	return true


func _relatorio(perfil: String, r: Dictionary) -> void:
	print("\n=== perfil %s: %.0f min de corrida, %d corridas, %d/%d provas vencidas, saldo %d, licenças %s"
			% [perfil, r["tempo"] / 60.0, ag.j.dias, r["vencidas"], r["provas"], r["saldo"], r["licencas"]])
	var m: Dictionary = r["marcos"]
	for k in ["primeira_vitoria", "licenca_b", "vitoria_b", "licenca_a"]:
		print("  %-17s %s" % [k, "%.0f min" % (m[k] / 60.0) if m.has(k) else "—"])
	var tanque := Combustivel.tanque(d)
	var renova := float(Combustivel.regras(d).get("renova_s", 0.0))
	for k in ["segundo_carro", "arena"] + _dias.keys().filter(func(x): return String(x).begins_with("grid_")):
		if not m.has(k):
			print("  %-26s —" % k)
			continue
		var real := maxf(float(m[k]), (int(_dias[k]) - tanque) * renova)
		print("  %-26s %.0f min de corrida · corrida %d · real jogando sem parar ≥ %.1f h"
				% [k, m[k] / 60.0, int(_dias[k]), real / 3600.0])
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
