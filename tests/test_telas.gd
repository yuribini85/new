extends "res://tests/base_teste.gd"
## Fumaça das telas: monta cada aba com dados de teste, aperta os caminhos
## principais e confere que nada quebra. Erros de script derrubam o rodar.sh.

const JogadorScript := preload("res://autoload/jogador.gd")
const ABAS := [
	preload("res://ui/aba_garagem.gd"), preload("res://ui/aba_loja.gd"),
	preload("res://ui/aba_garagem.gd"), preload("res://ui/aba_eventos.gd"),  # índice 2: a Oficina antiga saiu
	preload("res://ui/aba_corrida.gd"), preload("res://ui/aba_licencas.gd"),
	preload("res://ui/aba_equipe.gd"),
]


func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_abas_constroem_com_e_sem_carro() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	j.treinos = {"a": -1.0e12, "b": -1.0e12}  # treinos feitos: o teste cobre a avaliação pela tela
	j.carreira = Carreira.new(d, j)
	j.fila_ctrl = Fila.new(j.carreira, j, 3600.0)
	var abas := []
	for script in ABAS:
		var a: Control = script.new(d, j)
		a.size = Vector2(720, 1100)
		_raiz().add_child(a)
		a.atualizar()
		abas.append(a)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.carro_ativo = uid
	abas[0].atualizar()
	verificar(abas[0].ancoras.has("CAR_STATS"), "âncora do destaque da ficha")
	abas[3].atualizar()
	verificar(abas[3].ancoras.has("EVENT_CARD"), "âncora do destaque do evento")
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	j.fila_ctrl.iniciar("aberto", uid, 2, Time.get_unix_time_from_system())
	for a in abas:
		a.atualizar()
	abas[3]._correr("aberto")  # recusado: fila ocupada
	abas[5]._fazer(d.item("licencas", "b"), d.item("licencas", "b")["testes"][1])
	verificar(j.graus_licenca.has("b2"), "teste de licença pela tela")
	j.licencas.append("b")
	abas[5]._abrir_bancada(d.item("contratos", "c_teste"))
	abas[5].atualizar()
	abas[5]._montagem = {"pecas": ["alivio"], "ajuste_cambio": ""}
	abas[5]._enviar(d.item("contratos", "c_teste"))
	abas[5].atualizar()
	igual(j.graus_licenca.get("c_teste", ""), "ouro", "contrato pela tela")
	abas[5]._bancada = ""
	abas[4]._process(0.0)
	verificar(abas[4]._visual.duracao() > 0.0, "corrida ao vivo carregada")
	abas[0]._vender(uid)
	igual(j.carro_ativo, uid, "único carro não se vende")
	j.economia.creditar(1000)
	j.concessionaria.comprar_carro(d.carro("fraco"))
	abas[0]._vender(uid)
	igual(j.carro_ativo, -1, "vender o ativo limpa a seleção")
	EquipeJogador.criar(j)
	igual(EquipeJogador.dados_equipe(d, j).get("id"), "eq_jogador", "equipe do jogador criada")
	j.flags["SECOND_CHANCE_UNLOCKED"] = true  # seção Second Chance no mercado
	EquipeJogador.liberar_segundo(d, j)
	igual(j.segundo_piloto, "livre_1", "segundo piloto na equipe")
	for a in abas:
		a.atualizar()
		a.free()
	j.free()
	d.free()


func test_garagem_vazia_sem_saldo_oferece_recomecar() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var g: Control = ABAS[0].new(d, j)
	verificar(not g._sem_saida(), "saldo inicial compra carro")
	j.economia.debitar(j.economia.saldo)
	j.dias = 7
	verificar(g._sem_saida(), "sem carro e sem saldo")
	g._recomecar()
	igual(j.economia.saldo, int(d.economia()["saldo_inicial"]), "saldo inicial de volta")
	igual(j.dias, 0, "dia zero")
	verificar(not g._sem_saida(), "volta a poder comprar")
	g.free()
	j.free()
	d.free()


func test_corrida_3d_carros_lado_a_lado_nao_se_atravessam() -> void:
	var ordem := ["a", "b", "c", "d"]
	# b emparelhado com a (ultrapassagem), c a 3 m, d longe; a e d com uma
	# volta de diferença no mesmo ponto também contam como vizinhos.
	var s := {"a": 100.0, "b": 100.0, "c": 97.0, "d": 1100.0}
	var f := Corrida3D.faixas(ordem, s, {}, 1000.0)
	igual(f["a"], 0.0, "líder no traçado ideal")
	for par in [["a", "b"], ["a", "c"], ["b", "c"], ["a", "d"]]:
		verificar(absf(f[par[0]] - f[par[1]]) >= 2.0, "%s e %s em faixas diferentes: %s" % [par[0], par[1], f])
	for id in f:
		verificar(absf(f[id]) + 0.9 <= Corrida3D.LARGURA_PISTA_M * 0.5, "%s dentro da pista" % id)
	igual(Corrida3D.contatos(ordem, s, f, 1000.0), [], "nas faixas finais, nenhum toque")
	igual(Corrida3D.contatos(["a", "b"], {"a": 50.0, "b": 48.0}, {"a": 0.0, "b": 1.0}, 1000.0), [["a", "b"]], "toque na troca de faixa")
	var sozinho := Corrida3D.faixas(["b"], {"b": 500.0}, {"b": 2.1}, 1000.0)
	igual(sozinho["b"], 0.0, "sem vizinho volta ao traçado ideal")


func test_visual_posiciona_carros_na_pista() -> void:
	var d := dados_fixture()
	var p: Pista = d.pista("oval")
	var ps := []
	for id in ["fraco", "forte"]:
		var c := Carro.new(d.carro(id))
		c.adicionar_pneu(d.pneu("seco"))
		ps.append({"id": id, "atributos": c.atributos_efetivos("seco"), "piloto": d.piloto("perfeito")})
	var r := Simulacao.correr(p, ps, 2, d.simulacao(), 1)
	var v := CorridaVisual.new()
	v.size = Vector2(720, 600)
	_raiz().add_child(v)
	v.mostrar(p, r)
	v.tempo = v.duracao()
	igual(v.ordem(), r["classificacao"], "ordem no fim = classificação")
	var venc: String = r["classificacao"][0]
	var chegada: float = r["carros"][venc]["tempo_total"]
	verificar(chegada < v.duracao() - 1.0, "vencedor chega antes do fim")
	var t_cheg := v.tempo
	v.tempo = chegada + 0.01
	var na_linha := v.distancia(venc)
	v.tempo = minf(chegada + 2.0, v.duracao())
	verificar(v.distancia(venc) > na_linha + 5.0, "depois da chegada o carro segue rodando: %.1f -> %.1f" % [na_linha, v.distancia(venc)])
	v.tempo = t_cheg
	v.tempo = 10.0
	var a: Array = r["amostras"]
	var i := int(10.0 / d.simulacao()["amostra_dt_s"])
	verificar(v.distancia("forte") >= a[i - 1]["s"]["forte"] and v.distancia("forte") <= a[i + 1]["s"]["forte"], "interpolação entre amostras vizinhas")
	igual(Iso.direcao(0.0), 0, "rumo 0")
	igual(Iso.direcao(PI), 8, "rumo π")
	igual(Iso.direcao(-PI / 8.0), 15, "rumo negativo")
	v.free()
	d.free()


func test_minimapa_na_mesma_orientacao_da_vista_3d() -> void:
	# A vista normal da Corrida3D olha de cima, com o alto da tela para (-1, 0, -1);
	# o plano (x, y) vai para (x, 0, -y). O minimapa deve ser a mesma, sem espelhar.
	var b := Basis.looking_at(Vector3.DOWN, Vector3(-1, 0, -1).normalized())
	for p in [Vector2(10, 0), Vector2(0, 10), Vector2(7, -3)]:
		var w := Vector3(p.x, 0.0, -p.y)
		var tela := Vector2(w.dot(b.x), -w.dot(b.y))
		var iso := Iso.para_tela(p, 1.0)
		perto(tela.angle(), iso.angle(), 1e-3, "direção de %s" % p)
		perto(tela.length() / iso.length(), 1.0 / sqrt(2.0), 1e-3, "escala de %s" % p)


func test_simbolos_da_interface_tem_glifo() -> void:
	preload("res://ui/principal.gd")._simbolos()
	var f := ThemeDB.fallback_font
	for ch in ["✓", "✗", "★", "→", "⚠", "■", "−", "×", "º", "—"]:
		var tem := f.has_char(ch.unicode_at(0))
		for r in f.fallbacks:
			tem = tem or r.has_char(ch.unicode_at(0))
		verificar(tem, "glifo %s" % ch)


func test_principal_sem_dados_mostra_pendencias() -> void:
	var tela: Control = preload("res://scenes/principal.tscn").instantiate()
	_raiz().add_child(tela)
	verificar(tela.get_child_count() > 0, "tela montada")
	tela.free()


func test_editor_de_pista_abre() -> void:
	var editor: Control = preload("res://tools/editor_pista.tscn").instantiate()
	editor.size = Vector2(720, 1280)
	_raiz().add_child(editor)
	verificar(editor.get_child_count() > 0, "editor montado")
	editor.free()


func test_relatorio_de_retorno_comeca_pelo_plano() -> void:
	var tela: Control = preload("res://scenes/principal.tscn").instantiate()
	_raiz().add_child(tela)
	if tela._sobre == null:
		tela.free()
		return  # dados reais pendentes: a tela de pendências já é testada acima
	var rel := {"corridas": [{"evento_id": tela.dados.lista("eventos")[0]["id"], "posicao": 2, "premio": 100}],
			"premio_total": 100, "carros_premio": [], "erro": "", "tempo_perdido_s": 0.0}
	tela._mostrar_relatorio(rel, "Enquanto você esteve fora")
	verificar(tela._sobre.aberto(), "relatório aberto")
	var textos := []
	var pilha: Array = [tela._sobre]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n is Label:
			textos.append(n.text)
		pilha.append_array(n.get_children())
	verificar(textos.any(func(t): return t.begins_with("OBJETIVO")), "objetivo no relatório")
	verificar(textos.any(func(t): return t.begins_with("Saldo:")), "saldo no relatório")
	tela.free()


func test_registro_de_sessao_do_playtest() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var modo := Preferencias.modo_teste
	Preferencias.modo_teste = ""
	RegistroSessao.inicio(j)
	var antes := RegistroSessao.sessoes().size()
	RegistroSessao.fim(j)
	igual(RegistroSessao.sessoes().size(), antes, "desligado não grava")
	Preferencias.modo_teste = "ritmo"
	verificar(not Preferencias.permite_pular(), "teste de ritmo não pula")
	RegistroSessao.inicio(j)
	RegistroSessao.tela(4)
	RegistroSessao.fila({"evento_id": "aberto", "restantes": 3}, 120.0, true)
	RegistroSessao.pulo()
	var rel := {"corridas": [
		{"evento_id": "aberto", "posicao": 1, "total": 4, "premio": 300, "duracao": 60.0, "offline": false},
		{"evento_id": "aberto", "posicao": 3, "total": 4, "premio": 100, "duracao": 60.0, "offline": true,
			"folha": {"patrocinio": 50, "cobrado": 20}},
	]}
	RegistroSessao.corridas(rel, d)
	j.licencas.append("CLUB")
	RegistroSessao.fim(j)
	var s: Dictionary = RegistroSessao.sessoes().back()
	igual(s["modo"], "ritmo", "modo")
	igual(s["filas"].size(), 1, "fila registrada")
	igual(s["pulos"], 1, "pulo registrado")
	igual([s["fase_inicio"], s["fase_fim"]], ["sem licença", "CLUB"], "fase no início e no fim")
	verificar(s["telas"].has("Corrida"), "tempo acompanhando a corrida")
	igual(s["corridas"].size(), 2, "corridas registradas")
	var r := RegistroSessao.renda_por_nivel([s])
	igual(r.keys(), ["N1"], "nível pela licença da prova")
	igual([r["N1"]["corridas"], r["N1"]["vitorias"], r["N1"]["premio"], r["N1"]["offline"], r["N1"]["folha"]],
			[2, 1, 400, 1, 30], "renda somada por nível")
	RegistroSessao.limpar()
	Preferencias.modo_teste = modo
	j.free()
	d.free()


func test_camera_isometrica_so_na_ultrapassagem_e_desligada_por_reduzir_animacoes() -> void:
	var d := dados_fixture()
	var pista: Pista = d.pista("oval")
	# O jogador sai 10 m atrás do rival e mais rápido: passa em t = 2 s. Sozinho
	# (sem rival por perto), nada de câmera inclinada.
	var amostras := []
	for k in 121:
		var t := k * 0.1
		amostras.append({"t": t, "s": {"jogador": 90.0 + 25.0 * t, "rival": 100.0 + 20.0 * t, "longe": 600.0 + 20.0 * t}})
	var resultado := {"amostras": amostras, "voltas": 3, "carros": {}}
	var reduzir := Preferencias.reduzir_animacoes
	for desligado in [false, true]:
		Preferencias.reduzir_animacoes = desligado
		var fonte := CorridaVisual.new()
		var v3 := Corrida3D.new()
		v3.size = Vector2(720, 900)
		_raiz().add_child(v3)
		fonte.mostrar(pista, resultado)
		v3.mostrar(pista, fonte, {})
		var viu_antes := false
		var viu_longe := false
		for k in 240:
			fonte.tempo += 1.0 / 20.0
			v3.atualizar(1.0 / 20.0)
			if v3.modo == "velocidade":
				viu_antes = viu_antes or fonte.tempo < 2.0
				viu_longe = viu_longe or fonte.tempo > 2.0 + Corrida3D.DEPOIS_S + 0.5
		verificar(viu_antes != desligado, "câmera da ultrapassagem %s" % ("desligada" if desligado else "entra antes da passagem"))
		verificar(not viu_longe, "sai depois da ultrapassagem")
		v3.free()
		fonte.free()
	Preferencias.reduzir_animacoes = reduzir
	d.free()


func test_assets_devolve_arte_ou_null_para_placeholder() -> void:
	Assets.limpar()
	igual(Assets.caminho("x", "ui"), "res://arte/ui/x.png", "caminho da interface")
	igual(Assets.get_asset("nao_existe", "retrato"), null, "sem arquivo: placeholder")
	verificar(Assets.get_asset("icone_creditos", "ui") != null, "arte da interface existente")
	# Arquivo novo, ainda não importado: lido direto do disco.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png("user://teste_asset.png")
	var tex := Assets._carregar("user://teste_asset.png")
	verificar(tex != null and tex.get_width() == 4, "png novo lido do disco")
	DirAccess.remove_absolute("user://teste_asset.png")
	Assets.limpar()


## Configurações (engrenagem) e o vídeo de teste montam sem erro; o vídeo só
## dá a recompensa no fim.
func test_configuracoes_e_video_montam() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var aba: Control = ABAS[5].new(d, j)
	_raiz().add_child(aba)
	var v := VBoxContainer.new()
	aba.add_child(v)
	var abriu := [false]
	Configuracoes.montar(aba, v, j, func(): abriu[0] = true, func(): pass, func(vv): aba._modo_teste(vv))
	verificar(v.get_child_count() > 10, "seções montadas")
	var video := VideoRecompensa.new()
	_raiz().add_child(video)
	var r := []
	video.terminou.connect(func(x): r.append(x))
	video._process(1.0)
	igual(r.size(), 0, "antes do fim, nada")
	video._process(VideoRecompensa.DURACAO_TESTE_S)
	igual(r, [true], "no fim, recompensa")
	var cab := Cabecalho.new()
	_raiz().add_child(cab)
	cab.definir_aceleracao(1799.0, 2.0)
	igual(cab._texto_marcador.text, "2×", "marcador aceso")
	igual(cab._tempo_marcador.text, "29:59", "tempo que falta")
	cab.definir_aceleracao(0.0, 2.0)
	igual(cab._texto_marcador.text, "ACELERAR", "marcador parado")
	cab.free()
	aba.free()
	j.free()
	d.free()


## Classificação relativa do HUD: líder, à frente, você, atrás; pulo quando o
## líder não é vizinho; sem repetir.
func test_classificacao_relativa() -> void:
	var l := func(eu: int, n: int) -> Array:
		var a := []
		for i in n:
			a.append({"voce": i == eu})
		return a
	igual(HudCorrida.linhas_relativas(l.call(0, 6)), [0, 1], "líder: você e o de trás")
	igual(HudCorrida.linhas_relativas(l.call(1, 6)), [0, 1, 2], "segundo: líder é o da frente")
	igual(HudCorrida.linhas_relativas(l.call(2, 6)), [0, 1, 2, 3], "terceiro: sem pulo")
	igual(HudCorrida.linhas_relativas(l.call(4, 6)), [0, -1, 3, 4, 5], "quinto: pulo depois do líder")
	igual(HudCorrida.linhas_relativas(l.call(5, 6)), [0, -1, 4, 5], "último: sem ninguém atrás")


## Depois da linha, quem chega atrás para atrás de quem chegou antes (sem
## empilhar os carros): cada um com ESPACO_PARADO_M de folga.
func test_chegada_para_em_fila() -> void:
	var d := dados_fixture()
	var pista: Pista = d.pista(d.lista("pistas")[0]["id"])
	var amostras := []
	for k in 201:
		var t := k * 0.1
		# Os três a 40 m/s, separados por 2 m: chegam quase juntos.
		amostras.append({"t": t, "s": {"a": 40.0 * t, "b": 40.0 * t - 2.0, "c": 40.0 * t - 4.0}})
	var fim := 600.0
	var r := {"amostras": amostras, "voltas": 1, "comprimento": fim, "carros": {
		"a": {"terminou": true, "tempo_total": fim / 40.0},
		"b": {"terminou": true, "tempo_total": (fim + 2.0) / 40.0},
		"c": {"terminou": true, "tempo_total": (fim + 4.0) / 40.0}}}
	var v := CorridaVisual.new()
	v.mostrar(pista, r)
	v.tempo = 60.0
	verificar(v.distancia("a") - v.distancia("b") >= CorridaVisual.ESPACO_PARADO_M - 0.01, "b para atrás de a")
	verificar(v.distancia("b") - v.distancia("c") >= CorridaVisual.ESPACO_PARADO_M - 0.01, "c para atrás de b")
	v.free()
	d.free()


func test_evolucao_da_garagem_abre_a_compra_da_categoria() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	var g: Control = ABAS[0].new(d, j)
	g.size = Vector2(720, 1100)
	_raiz().add_child(g)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.carro_ativo = uid
	var c: Carro = j.garagem.carro(uid)
	var p: Dictionary = d.lista("pecas").filter(func(x): return c.motivo_recusa(x).is_empty())[0]
	var aberto := []
	g.painel_estilo.connect(func(titulo, montar, _botoes, _estilo): aberto.append([titulo, montar]))
	g._abrir_categoria = String(p["categoria"])
	g.atualizar()
	igual(aberto.size(), 1, "a categoria abre a janela de compra")
	var v := VBoxContainer.new()
	_raiz().add_child(v)
	aberto[0][1].call(v)
	# A ação da janela (INSTALAR · preço) é o botão do painel: dispara a compra.
	var acao: Array = g._acao_evolucao(c, String(p["categoria"]))
	verificar(String(acao[0]).begins_with("INSTALAR") and acao[3], "instalar com o preço, habilitado")
	acao[1].call()
	verificar(c.pecas.has(p["categoria"]), "comprar pela janela instala a peça")
	v.free()
	g.free()
	j.free()
	d.free()


func test_janela_garagem_escolhe_e_vende() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	var g: Control = ABAS[0].new(d, j)
	_raiz().add_child(g)
	var a: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var b: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.carro_ativo = a
	g.atualizar()
	var aberto := []
	g.painel.connect(func(_t, montar, _b): aberto.append(montar))
	g.abrir_garagem()
	var v := VBoxContainer.new()
	_raiz().add_child(v)
	aberto[-1].call(v)
	var vender := v.find_children("*", "Button", true, false).filter(func(x): return x.text.begins_with("VENDER") \
			or x.text.begins_with("Vender"))
	igual(vender.size(), 2, "cada carro tem o seu vender")
	g._escolher(j.garagem.carro(b))
	igual(j.carro_ativo, b, "escolher na janela leva o carro para a Oficina")
	g._vender(a)
	verificar(j.garagem.carro(a) == null, "vendido pela janela")
	v.free()
	g.free()
	j.free()
	d.free()
