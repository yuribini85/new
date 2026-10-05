extends "res://tests/base_teste.gd"
## Fumaça das telas: monta cada aba com dados de teste, aperta os caminhos
## principais e confere que nada quebra. Erros de script derrubam o rodar.sh.

const JogadorScript := preload("res://autoload/jogador.gd")
const ABAS := [
	preload("res://ui/aba_garagem.gd"), preload("res://ui/aba_loja.gd"),
	preload("res://ui/aba_oficina.gd"), preload("res://ui/aba_eventos.gd"),
	preload("res://ui/aba_corrida.gd"), preload("res://ui/aba_licencas.gd"),
]


func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_abas_constroem_com_e_sem_carro() -> void:
	var d := dados_fixture()
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
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
	j.fila_ctrl.iniciar("aberto", uid, 2, Time.get_unix_time_from_system())
	for a in abas:
		a.atualizar()
	abas[3]._correr("aberto")  # recusado: fila ocupada
	abas[5]._fazer(d.item("licencas", "b"), d.item("licencas", "b")["testes"][1])
	verificar(j.graus_licenca.has("b2"), "teste de licença pela tela")
	abas[4]._process(0.0)
	verificar(abas[4]._visual.duracao() > 0.0, "corrida ao vivo carregada")
	abas[0]._vender(uid)
	igual(j.carro_ativo, uid, "único carro não se vende")
	j.economia.creditar(1000)
	j.concessionaria.comprar_carro(d.carro("fraco"))
	abas[0]._vender(uid)
	igual(j.carro_ativo, -1, "vender o ativo limpa a seleção")
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
	# A câmera da Corrida3D olha de (70, 57.15, 70); o plano (x, y) vai para
	# (x, 0, -y). A projeção Iso do minimapa deve ser a mesma, sem espelhar.
	var b := Basis.looking_at(-Vector3(70, 57.15, 70), Vector3.UP)
	for p in [Vector2(10, 0), Vector2(0, 10), Vector2(7, -3)]:
		var w := Vector3(p.x, 0.0, -p.y)
		var tela := Vector2(w.dot(b.x), -w.dot(b.y))
		var iso := Iso.para_tela(p, 1.0)
		perto(tela.angle(), iso.angle(), 1e-3, "direção de %s" % p)
		perto(tela.length() / iso.length(), 1.0 / sqrt(2.0), 1e-3, "escala de %s" % p)


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
