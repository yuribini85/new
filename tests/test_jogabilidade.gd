extends "res://tests/base_teste.gd"
## O que atrapalha jogar: telas que alargam além do celular, fila com relógio
## voltando ou com prova que deixa de aceitar o carro, histórico no save.

const JogadorScript := preload("res://autoload/jogador.gd")
const ABAS := [
	preload("res://ui/aba_garagem.gd"), preload("res://ui/aba_loja.gd"),
	preload("res://ui/aba_oficina.gd"), preload("res://ui/aba_eventos.gd"),
	preload("res://ui/aba_corrida.gd"), preload("res://ui/aba_licencas.gd"),
]
## Largura útil do celular: 720 menos as margens da tela principal e a barra
## de rolagem (com folga para fontes um pouco mais largas no aparelho).
const LARGURA := 720.0 - 32.0 - 40.0


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.carreira = Carreira.new(d, j)
	j.fila_ctrl = Fila.new(j.carreira, j, 3600.0)
	return j


func _raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Com os dados reais, carro comprado, uma derrota e a análise feita (textos
## longos de "deixa de correr"), nenhuma tela pede mais largura que o celular.
func test_telas_cabem_na_largura_do_celular() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j := _jogador(d)
	j.economia.creditar(200000)
	# Estado de meio de carreira: três carros (botão "Usar este" nos outros),
	# licenças, vitórias, peça instalada e fila correndo.
	var ofertas := Usados.estoque(d.lista("carros"), 0, j.usados_vendidos)
	var uid := -1
	for o in ofertas.slice(0, 3):
		var u: int = j.concessionaria.comprar_usado(o, d.carro(o["carro_id"]), j.usados_vendidos)
		if uid < 0:
			uid = u
	j.carro_ativo = uid
	j.licencas = ["B", "A"]
	for p in d.lista("pecas"):
		if j.garagem.carro(uid).motivo_recusa(p) == "":
			j.concessionaria.comprar_peca(j.garagem.carro(uid), p)
			break
	for ev in d.lista("eventos"):
		if j.fila_ctrl.iniciar(ev["id"], uid, 1, 0.0) == "":
			break
	j.fila_ctrl.adiantar(10.0)
	j.fila_ctrl.processar(10.0)
	verificar(not j.ultima_corrida.is_empty(), "uma corrida disputada")
	j.vitorias[j.ultima_corrida["evento_id"]] = 1
	j.fila_ctrl.iniciar(j.ultima_corrida["evento_id"], uid, 3, Time.get_unix_time_from_system())
	var abas := []
	for script in ABAS:
		var a: Control = script.new(d, j)
		a.size = Vector2(LARGURA, 1100)
		_raiz().add_child(a)
		abas.append(a)
	var corrida: Control = abas[4]
	var u: Dictionary = j.ultima_corrida
	# Análise com uma opção de nome e lista de provas bem longos.
	corrida._analise = {"chave": corrida._chave_analise(u, j.garagem.carro(uid)), "ms": 100,
		"base": {"faixa": [3, 5]}, "opcoes": [{"tipo": "peca", "item": d.lista("pecas")[0], "preco": 1000,
		"nome": "Kit turbo de competição com nome muito comprido para testar quebra",
		"faixa": [1, 2], "perde": d.lista("eventos").slice(0, 8).map(func(e): return e["nome"])}]}
	for a in abas:
		a.atualizar()
	for a in abas:
		var largura: float = a.conteudo.get_combined_minimum_size().x
		verificar(largura <= LARGURA, "%s pede %.0f px (máx. %.0f)" % [a.name, largura, LARGURA])
	# Agenda dos usados, com um modelo acompanhado.
	j.desejos = [d.lista("carros")[0]["id"], d.lista("carros")[1]["id"]]
	abas[1]._secao = "agenda"
	abas[1].atualizar()
	var la: float = abas[1].conteudo.get_combined_minimum_size().x
	verificar(la <= LARGURA, "agenda pede %.0f px (máx. %.0f)" % [la, LARGURA])
	# Bancada de cada contrato, com câmbio montado e relatório.
	var carreira: Control = abas[5]
	for ct in d.lista("contratos"):
		carreira._abrir_bancada(ct)
		var pecas: Array = Contratos.pecas_escola(d, ct).map(func(p): return p["id"])
		carreira._montagem = {"pecas": pecas.filter(func(x): return d.peca(x)["categoria"] == "cambio"),
				"ajuste_cambio": "curto"}
		carreira._enviar(ct)
		carreira.atualizar()
		var lb: float = carreira.conteudo.get_combined_minimum_size().x
		verificar(lb <= LARGURA, "bancada %s pede %.0f px (máx. %.0f)" % [ct["id"], lb, LARGURA])
	for a in abas:
		a.free()
	j.free()
	d.free()


func test_relogio_voltando_nao_aplica_nem_estraga_a_fila() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.economia.creditar(10000)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	igual(j.fila_ctrl.iniciar("aberto", uid, 2, 5000.0), "", "iniciar")
	var r: Dictionary = j.fila_ctrl.processar(1000.0)  # relógio atrasado
	igual(r["corridas"].size(), 0, "nada aplicado")
	igual(r["tempo_perdido_s"], 0.0, "nada descontado")
	igual(j.fila["restantes"], 2, "fila intacta")
	var dur: float = j.fila_ctrl.duracao_atual()
	r = j.fila_ctrl.processar(5000.0 + dur + 1.0)
	igual(r["corridas"].size(), 1, "relógio de volta ao normal: a corrida conta")
	j.free()
	d.free()


func test_peca_depois_da_inscricao_nao_tira_o_carro_da_prova() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.vitorias["ff_ate_120"] = 1  # repetir exige a prova já vencida
	igual(j.fila_ctrl.iniciar("ff_ate_120", uid, 3, 0.0), "", "fraco cabe na Copa FF")
	j.economia.creditar(1000)
	igual(j.concessionaria.comprar_peca(j.garagem.carro(uid), d.peca("turbo")), "", "turbo")
	var r: Dictionary = j.fila_ctrl.processar(100000.0)
	igual(r["erro"], "", "a inscrição guardou a preparação de antes do turbo")
	igual(r["corridas"].size(), 3, "três corridas")
	# A próxima inscrição usa a preparação nova e é recusada com o motivo.
	verificar(j.fila_ctrl.iniciar("ff_ate_120", uid, 1, 100000.0).contains("potência"), "nova inscrição recusada")
	j.free()
	d.free()


func test_parar_apos_a_atual() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	j.fila_ctrl.iniciar("aberto", uid, 5, 0.0)
	j.fila_ctrl.parar_apos_atual()
	var r: Dictionary = j.fila_ctrl.processar(100000.0)
	igual(r["corridas"].size(), 1, "só a corrida em andamento")
	verificar(j.fila.is_empty(), "fila acabou")
	j.free()
	d.free()


func test_historico_registra_evolucao_e_vai_para_o_save() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	j.fila_ctrl.iniciar("aberto", uid, 2, 0.0)
	j.fila_ctrl.processar(100000.0)
	var h: Dictionary = j.historico["aberto"]
	igual(h["corridas"], 2, "duas corridas")
	verificar(h["melhor_tempo"] > 0.0 and h["melhor_tempo"] <= h["ultimo_tempo"], "melhor tempo")
	verificar(j.ultima_corrida.has("anterior") and not j.ultima_corrida["anterior"].is_empty(), "a segunda conhece a primeira")
	igual(j.ultima_corrida["tabela"].size(), j.ultima_corrida["total"], "classificação completa")
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.historico.keys(), j.historico.keys(), "histórico volta")
	for campo in ["corridas", "melhor_pos", "ultima_pos"]:
		igual(k.historico["aberto"][campo], j.historico["aberto"][campo], campo)
	perto(k.historico["aberto"]["melhor_tempo"], j.historico["aberto"]["melhor_tempo"], 1e-3, "melhor tempo")
	# Save antigo, sem histórico, continua carregando.
	estado.erase("historico")
	igual(Save.desserializar(estado, k, d), "", "save sem histórico")
	igual(k.historico, {}, "histórico vazio")
	j.free()
	k.free()
	d.free()
