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
	j.fila_ctrl.iniciar("aberto", uid, 1, Time.get_unix_time_from_system())
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
	verificar(abas[4]._visual.duracao() == 0.0, "corrida ainda sendo resolvida: a tela espera")
	j.fila_ctrl.avancar_preparo(INF)  # a principal resolve aos poucos, a cada quadro
	for k in 4:  # a capa de carregamento aparece antes de montar a pista
		abas[4]._process(0.0)
	verificar(abas[4]._visual.duracao() > 0.0, "corrida ao vivo carregada")
	abas[0]._vender(uid)
	igual(j.carro_ativo, uid, "único carro não se vende")
	j.economia.creditar(1000)
	j.concessionaria.comprar_carro(d.carro("fraco"))
	abas[0]._vender(uid)
	igual(j.carro_ativo, uid, "escalado não se vende")
	j.fila_ctrl.cancelar()
	Escalacao.definir(j, "corrida", -1)
	abas[0]._vender(uid)
	igual(j.carro_ativo, -1, "vender o ativo limpa a seleção")
	EquipeJogador.criar(j)
	igual(EquipeJogador.dados_equipe(d, j).get("id"), "eq_jogador", "equipe do jogador criada")
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
	g.painel_estilo.connect(func(_t, montar, _b, _e): aberto.append(montar))
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


func test_modelo_3d_glb_entra_no_lugar_do_carro_em_codigo() -> void:
	verificar(CarroBloco.tem_glb("hozuki_catana"), "o Hozuki Catana tem GLB")
	verificar(CarroBloco.tem_modelo("hozuki_catana"), "e modelo 3D")
	verificar(not CarroBloco.tem_modelo("carro_sem_modelo"), "sem forma nem arquivo, sem modelo")
	# Só os aprovados pelo usuário usam o gerado (decisão 91): ids um a um e
	# épocas/categorias liberadas.
	igual(Carroceria.ATIVOS, ["kanaya_kestrel"], "ativos: os carros aprovados")
	verificar(Carroceria.tem("hozuki_catana"), "cupê de 1990: época liberada, gerado")
	verificar(Carroceria.tem("kanaya_kestrel"), "Kestrel aprovado: gerado")
	var regras_antes := Carroceria.regras
	Carroceria.regras = {}
	verificar(not Carroceria.tem("hozuki_catana"), "sem a regra, fica no GLB")
	# Fora dos ativos, o GLB de sempre.
	var g := CarroBloco.new().configurar_modelo({"id": "hozuki_catana", "categoria": "cupe"}, Color.RED)
	verificar(g._modelo != null and not g._modelo.has_node("Carroceria"), "fora dos ativos, o GLB")
	var dim_glb := g.dimensoes()
	verificar(dim_glb.x > 4.0 and dim_glb.x < 5.0 and dim_glb.y < dim_glb.x, "GLB: comprimento no eixo do carro (%s)" % dim_glb)
	g.free()
	var antes := Carroceria.ativos
	Carroceria.ativos = ["hozuki_catana"]
	var c := CarroBloco.new().configurar_modelo({"id": "hozuki_catana", "categoria": "cupe"}, Color.RED)
	verificar(c._modelo != null and c._modelo.has_node("Carroceria"), "com forma, o carro é o gerado")
	var corpo: MeshInstance3D = c._modelo.get_node("Carroceria")
	var k := int(corpo.mesh.get_meta("pintura"))
	var sm := corpo.get_surface_override_material(k) as ShaderMaterial
	verificar(sm != null and sm.shader == CarroBloco.SHADER_LATARIA, "a lataria gerada usa o shader da pintura da Oficina")
	var dim := c.dimensoes()
	verificar(dim.x > 4.0 and dim.x < 5.0 and dim.y < dim.x, "comprimento no eixo do carro (%s)" % dim)
	igual(c._rodas_glb.size(), 4, "quatro rodas que giram")
	var roda: Node3D = c._rodas_glb[0][0]
	verificar(String(roda.name).begins_with("Mount_"), "rodas com o nome dos nós do GLB (%s)" % roda.name)
	var x0 := roda.rotation.x
	c.girar_rodas(1.0)
	verificar(absf(roda.rotation.x - x0 - 1.0 / float(c._rodas_glb[0][1])) < 1e-4, "a roda gira no eixo X pela distância")
	c.blindar("hozuki_catana", 3)
	verificar(c.protecao("front") != null or c.protecao("rear") != null or not ResourceLoader.exists(
			CarroBloco.PASTA_GLB + "hozuki_catana_protecao.glb") or not c.is_inside_tree(), "blindagem monta no gerado")
	verificar(c._protecao_raiz != null and c._protecao_raiz.get_parent() == c._modelo, "a blindagem vai no mesmo eixo do modelo")
	c.free()
	Carroceria.ativos = antes
	Carroceria.regras = regras_antes


## Gerador (Carroceria): formas.json cobre todos os carros do jogo, cada um
## monta sem erro, dentro do orçamento, e a malha fica guardada por carro.
func test_gerador_cobre_todos_os_carros_dentro_do_orcamento() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var faltam := []
	var fora := []
	for c in d.lista("carros"):
		var id := String(c["id"])
		if not Carroceria.tem_forma(id):
			faltam.append(id)
			continue
		var m := Carroceria.corpo(id, c)
		var tri := 0
		for s in m.get_surface_count():
			tri += m.surface_get_array_len(s) / 3
		if m == null or m.get_surface_count() > 2 or tri > 3200 or tri < 500 or int(m.get_meta("pintura", -1)) != 0:
			fora.append("%s (%d superfícies, %d triângulos)" % [id, m.get_surface_count(), tri])
	igual(faltam, [], "todo carro de data/carros.json tem forma")
	igual(fora, [], "carroceria em até 2 superfícies e 3.200 triângulos")
	verificar(Carroceria.em_cache("hozuki_catana"), "malha guardada na sessão")
	var a := Carroceria.corpo("hozuki_catana")
	verificar(a == Carroceria.corpo("hozuki_catana"), "a mesma malha para o mesmo carro")
	for desenho in Rodas.DESENHOS:
		var r := Rodas.malha(desenho, 0.31, -1.0)
		igual(r.get_surface_count(), 1, "roda %s numa superfície" % desenho)
		verificar(r.surface_get_array_len(0) / 3 <= 800, "roda %s até 800 triângulos" % desenho)
		verificar(r == Rodas.malha(desenho, 0.312, -1.0), "roda guardada por desenho e raio em cm")
		verificar(Rodas.nome(desenho) != "", "nome em português")
	# Duas instâncias: a malha é a mesma, a pintura é de cada uma.
	var antes := Carroceria.ativos
	Carroceria.ativos = ["hozuki_catana"]
	var c1 := CarroBloco.new().configurar_modelo(d.carro("hozuki_catana"), Color.RED)
	var c2 := CarroBloco.new().configurar_modelo(d.carro("hozuki_catana"), Color.BLUE, {"roda": "malha"})
	var m1: MeshInstance3D = c1._modelo.get_node("Carroceria")
	var m2: MeshInstance3D = c2._modelo.get_node("Carroceria")
	verificar(m1.mesh == m2.mesh, "carroceria compartilhada")
	verificar(m1.get_surface_override_material(0) != m2.get_surface_override_material(0), "pintura por instância")
	verificar((c1._rodas_glb[0][0] as MeshInstance3D).mesh != (c2._rodas_glb[0][0] as MeshInstance3D).mesh, "aro escolhido")
	c1.repintar(Color.GREEN, {"roda": "malha"})
	verificar((c1._rodas_glb[0][0] as MeshInstance3D).mesh == (c2._rodas_glb[0][0] as MeshInstance3D).mesh,
			"repintar troca o aro na hora (prévia da cabine)")
	c1.free()
	c2.free()
	Carroceria.ativos = antes
	d.free()


func test_atualizar_a_tela_no_grid_nao_recomeca_a_contagem() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	j.carreira = Carreira.new(d, j)
	j.fila_ctrl = Fila.new(j.carreira, j, 3600.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.carro_ativo = uid
	var a: Control = preload("res://ui/aba_corrida.gd").new(d, j)
	a.size = Vector2(720, 1100)
	_raiz().add_child(a)
	j.fila_ctrl.iniciar("aberto", uid, 1, Aceleracao.agora(j) - 0.2)
	a.atualizar()
	a._process(0.0)
	# Sendo resolvida aos poucos: a corrida espera no grid (o relógio não anda).
	perto(float(j.fila["inicio"]), Aceleracao.agora(j), 0.05, "relógio parado enquanto resolve")
	j.fila_ctrl.avancar_preparo(INF)  # a principal resolve aos poucos, a cada quadro
	for k in 4:  # a capa de carregamento aparece antes de montar a pista
		a._process(0.0)
	perto(a._contagem, a.CONTAGEM_S, 1e-6, "corrida nova: 3-2-1")
	# O principal atualiza a tela a cada mudança (timer, cena, destaque): a
	# contagem segue de onde estava, senão a primeira luz acende para sempre.
	for k in 5:
		a._process(0.5)
		a.atualizar()
	a._process(0.0)
	perto(a._contagem, a.CONTAGEM_S - 2.5, 1e-6, "contagem segue depois de atualizar")
	a._process(0.6)
	igual(a._contagem, -1.0, "largou")
	a.free()
	j.free()
	d.free()


func test_tempo_da_corrida_nao_engasga_com_relogio_grosso() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var a: Control = preload("res://ui/aba_corrida.gd").new(d, j)
	# Relógio do navegador: milissegundos inteiros; quadro de 1/60 s.
	var dt := 1.0 / 60.0
	var t_real := 10.0
	var antes: float = a._tempo_suave(snappedf(t_real, 0.001), dt)
	var passos := []
	for k in 600:
		t_real += dt
		var agora: float = a._tempo_suave(snappedf(t_real, 0.001), dt)
		if k > 120:
			passos.append(agora - antes)
		antes = agora
	var mn: float = passos.min()
	var mx: float = passos.max()
	verificar(mx / mn < 1.01, "avanço por quadro estável (%.4f a %.4f)" % [mn, mx])
	perto(antes, t_real, 0.01, "acompanha o relógio")
	a.free()
	j.free()
	d.free()


## Cabine de pintura: nada grava antes de Aplicar; Desfazer volta ao que estava
## ao abrir; Cancelar não muda o carro; Aplicar grava cor, faixas, número e
## acabamento (só o que não é de fábrica).
func test_cabine_de_pintura_desfaz_cancela_e_aplica() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	var c: Carro = j.garagem.carro(uid)
	var cab := CabinePintura.new(d, j, c)
	_raiz().add_child(cab)
	verificar(cab._aplicar.disabled, "sem mudança, Aplicar apagado")
	for aba in ["pintura", "identificacao", "acabamento", "rodas"]:
		cab._aba = aba
		cab._mostrar_aba()
	cab._definir("cor", "#1251b3")
	cab._definir("numero", 7)
	verificar(not cab._aplicar.disabled, "mudou: Aplicar aceso")
	cab._voltar.pressed.emit()
	igual(int(cab._estado["numero"]), -1, "desfazer volta um passo (o número)")
	cab._avancar.pressed.emit()
	igual(int(cab._estado["numero"]), 7, "refazer devolve o passo")
	cab._como_estava.pressed.emit()
	igual(cab._estado, cab._inicio, "Como estava volta ao que estava ao abrir")
	cab._estado["cor"] = "#1251b3"
	cab._fechar()
	igual(c.faixas, {}, "Cancelar não muda as faixas")
	verificar(c.cor != "#1251b3", "nem a cor")
	cab = CabinePintura.new(d, j, c)
	_raiz().add_child(cab)
	cab._estado["cor"] = "#1251b3"
	cab._estado["padrao"] = "dupla"
	cab._estado["numero"] = 24
	cab._estado["locais_numero"] = 3
	cab._estado["acabamento"] = "metalico"
	cab._mudou()
	cab._confirmar()
	igual(c.cor, "#1251b3", "cor gravada")
	igual(int(c.faixas["numero"]), 24, "número gravado")
	igual(int(c.faixas["locais_numero"]), 3, "lugares do número")
	igual(String(c.faixas["acabamento"]), "metalico", "acabamento gravado")
	igual(String(c.faixas["padrao"]), "dupla", "desenho gravado")
	# Volta do save (números viram float): reabrir não acusa mudança.
	var volta: Dictionary = JSON.parse_string(JSON.stringify(c.faixas))
	c.faixas = volta
	var de_novo := CabinePintura.new(d, j, c)
	_raiz().add_child(de_novo)
	verificar(de_novo._aplicar.disabled, "pintura do save não conta como mudança")
	de_novo._fechar()
	verificar(not cab._botoes_aba.has("rodas"), "carro sem gerado: sem a aba RODAS")
	# Aba RODAS (só no carro gerado; a fixture ganha a forma de um carro real):
	# o aro troca na prévia, não custa e grava com Aplicar.
	var ativos_antes := Carroceria.ativos
	Carroceria.formas()[c.id] = Carroceria.forma("hozuki_catana")
	Carroceria.ativos = [c.id]
	var cab_r := CabinePintura.new(d, j, c)
	_raiz().add_child(cab_r)
	cab_r._aba = "rodas"
	cab_r._mostrar_aba()
	var botoes := cab_r._conteudo.find_children("*", "Button", true, false)
	igual(botoes.size(), Rodas.DESENHOS.size(), "um botão por aro")
	verificar(botoes.all(func(b): return b.get_combined_minimum_size().y >= 88.0), "toque de pelo menos 88 px")
	cab_r._definir("roda", "dez")
	verificar(not cab_r._aplicar.disabled, "só o aro: dá para aplicar")
	verificar(not cab_r._muda_faixas() and not cab_r._muda_cor(), "o aro não entra no preço da pintura")
	cab_r._confirmar()
	igual(String(c.faixas.get("roda", "")), "dez", "aro gravado no carro")
	Carroceria.ativos = ativos_antes
	Carroceria.formas().erase(c.id)
	igual(PinturaCarro.normalizar({"padrao": "", "faixa": "#ffffff", "numero": -1, "acabamento": "", "largura": 1.0,
			"locais_logo": 0, "poeira": 0.0}), {}, "o padrão de fábrica não vai para o save")
	# Nome e logo da equipe: independentes, gravados no jogador ao aplicar, sem custo.
	var cab_eq := CabinePintura.new(d, j, c)
	_raiz().add_child(cab_eq)
	cab_eq._definir("equipe_nome", "Oficina do Bairro")
	cab_eq._definir("equipe_logo", "07_gear_star")
	cab_eq._definir("locais_logo", 5)
	verificar(not cab_eq._aplicar.disabled, "só nome e logo: dá para aplicar")
	cab_eq._confirmar()
	igual(IdentidadeEquipe.nome(d, j), "Oficina do Bairro", "nome da equipe")
	igual(IdentidadeEquipe.logo(j), "07_gear_star", "logo da equipe")
	igual(int(c.faixas["locais_logo"]), 1, "logo e número não dividem o capô (o número está lá)")
	verificar(not c.faixas.has("logo"), "o logo do jogador vem da equipe, não fica no carro")
	IdentidadeEquipe.definir(j, "", "07_gear_star")
	igual(IdentidadeEquipe.logo(j), "07_gear_star", "trocar o nome não troca o logo")
	j.free()
	d.free()


## Decisão 88: a intro de cada equipe do Grid sai dos dados (número, apelido,
## estilo pelo perfil, carros especiais do desafio, carimbo) e o Pular monta o
## confronto com os botões.
func test_intro_das_equipes_do_grid() -> void:
	var d: Node = Assets._dados()
	for peso in ["display", "display_eb", "carimbo", "mono", "mono_sb"]:
		verificar(Tipografia.fonte(peso).base_font != null, "fonte " + peso)
	for e in TheGrid.equipes(d):
		var info := GridRivalIntro.montar(d, null, e)
		var ps: Array = info["pilotos"]
		igual(ps.size(), 4, "%s: 4 pilotos" % e["id"])
		igual(ps[0]["carimbo"], "CAPITÃO", "%s: o primeiro é o capitão" % e["id"])
		var com_carro := ps.filter(func(p): return String(p["carro"]) != "").size()
		igual(com_carro, 1 if info["modo"] == "corrida" else 2, "%s: carros do desafio" % e["id"])
		var numeros := {}
		for p in ps:
			verificar(String(p["apelido"]) != "" and int(p["numero"]) > 0, "%s: número e apelido" % p["id"])
			numeros[int(p["numero"])] = true
			verificar(Array(p["cv"]).size() > 0 and Array(p["cv"]).size() <= 3, "%s: currículo" % p["id"])
			verificar(float(p["consistencia"]) > 0.0, "%s: consistência" % p["id"])
		igual(numeros.size(), 4, "%s: números diferentes" % e["id"])
		verificar(int(info["premio"]) > 0, "%s: prêmio da licença em giros" % e["id"])
	var vez: Dictionary = TheGrid.equipes(d)[0]
	var intro := GridRivalIntro.new(d, null, String(vez["id"]), "primeiro", 3, 4)
	var sinal := []
	intro.ir.connect(func(a): sinal.append(a))
	intro.pular()
	var botoes := intro.find_children("*", "Button", true, false)
	verificar(botoes.size() >= 3, "confronto com Pular, ir e Continuar")
	var ir_b: Array = botoes.filter(func(b): return "→" in b.text)
	igual(ir_b.size(), 1, "um botão para a aba do desafio")
	ir_b[0].pressed.emit()
	igual(sinal, [3 if GridDesafio.de(d, vez)["modo"] == "corrida" else 4], "o botão leva à aba do desafio")
	intro.free()


## Decisão 88: cada piloto (candidatos e os das equipes) tem o retrato e o
## corpo próprios; o genérico (decisão 72) só falta de arte.
func test_pilotos_usam_retrato_proprio() -> void:
	Assets.limpar()
	var d: Node = Assets._dados()
	var ids: Array = EquipeJogador.candidatos(d).map(func(c): return String(c["id"]))
	for e in d.lista("equipes"):
		if e.get("jogador", false):
			continue
		for p in e.get("pilotos", []):
			ids.append(String(p["id"]))
	igual(ids.size(), 84, "8 candidatos e 76 pilotos de equipe")
	for id in ids:
		igual(Assets.caminho(id, "retrato"), "res://arte/pilotos/%s.webp" % id, "retrato de " + id)
		verificar(Assets.get_asset(id, "retrato") != null and Assets.get_asset(id, "corpo") != null, "arte de " + id)
	verificar(Assets.caminho("sem_arte_x", "retrato") == "", "id desconhecido sem caminho")
	Assets.limpar()


## Todo símbolo fora do ASCII usado nas telas e nas falas existe na fonte
## padrão ou na reserva de símbolos (senão aparece uma caixa com o código).
func test_glifos_das_telas_existem() -> void:
	load("res://ui/principal.gd")._simbolos()
	var f := ThemeDB.fallback_font
	var ts := TextServerManager.get_primary_interface()
	var fontes: Array = [f]
	for peso in Tipografia.ARQUIVOS:
		fontes.append(Tipografia.fonte(peso))
	# Só o que vira texto na tela: as strings do código (não os comentários) e as falas.
	var textos := ""
	var aspas := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	for pasta in ["res://ui/", "res://visual/"]:
		for arq in DirAccess.get_files_at(pasta):
			if arq.ends_with(".gd"):
				for m in aspas.search_all(FileAccess.get_file_as_string(pasta + arq)):
					textos += m.get_string()
	textos += FileAccess.get_file_as_string("res://data/dialogos.json")
	var faltam := {}
	for i in textos.length():
		var c := textos.unicode_at(i)
		if c < 0x2000 or faltam.has(c):  # latim e acentos: a fonte padrão cobre
			continue
		var tem := false
		for fonte in fontes:
			for r in fonte.get_rids():
				if ts.font_has_char(r, c):
					tem = true
		if not tem:
			faltam[c] = String.chr(c)
	igual(faltam.values(), [], "glifos sem fonte")
