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
	v.tempo = 10.0
	var a: Array = r["amostras"]
	var i := int(10.0 / d.simulacao()["amostra_dt_s"])
	verificar(v.distancia("forte") >= a[i - 1]["s"]["forte"] and v.distancia("forte") <= a[i + 1]["s"]["forte"], "interpolação entre amostras vizinhas")
	igual(Iso.direcao(0.0), 0, "rumo 0")
	igual(Iso.direcao(PI), 8, "rumo π")
	igual(Iso.direcao(-PI / 8.0), 15, "rumo negativo")
	v.free()
	d.free()


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
