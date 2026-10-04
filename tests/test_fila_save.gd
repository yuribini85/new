extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func _fila(d: Node, j: Node, teto := 3600.0) -> Fila:
	return Fila.new(Carreira.new(d, j), j, teto)


func test_fila_aplica_so_corridas_concluidas() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 3, 1000.0), "", "iniciar")
	var dur: float = f.corrida_atual(1000.0)["duracao"]
	var saldo: int = j.economia.saldo
	var r := f.processar(1000.0 + dur * 2 + 0.5)
	igual(r["corridas"].size(), 2, "duas concluídas (duração %.1f s)" % dur)
	igual(r["premio_total"], 1000, "2 × 500")
	igual(r["carros_premio"].size(), 1, "carro-prêmio só uma vez")
	igual(j.economia.saldo, saldo + 1000, "saldo")
	igual(j.fila["restantes"], 1, "resta uma")
	igual(j.dias, 2, "dias")
	perto(f.corrida_atual(1000.0 + dur * 2 + 0.5)["decorrido"], 0.5, 1e-6, "terceira em andamento")
	f.processar(1000.0 + dur * 3 + 1.0)
	verificar(j.fila.is_empty(), "fila terminou")
	igual(j.dias, 3, "dias")
	j.free()
	d.free()


func test_teto_offline_limita_e_descarta_o_excesso() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j, 600.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	f.iniciar("aberto", uid, 1000, 0.0)
	var dur: float = f.corrida_atual(0.0)["duracao"]
	var r := f.processar(100000.0)
	igual(r["corridas"].size(), int(600.0 / dur), "corridas dentro do teto")
	perto(r["tempo_perdido_s"], 100000.0 - 600.0, 1e-6, "tempo perdido")
	perto(j.ultimo_processamento, 100000.0, 1e-6, "processado até agora")
	perto(f.corrida_atual(100000.0)["decorrido"], fmod(600.0, dur), 1e-3, "fila retoma de onde parou")
	j.free()
	d.free()


func test_carro_vendido_cancela_a_fila() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	f.iniciar("aberto", uid, 5, 0.0)
	j.concessionaria.vender_carro(uid)
	var r := f.processar(3000.0)
	verificar(r["erro"] != "", "erro reportado")
	verificar(j.fila.is_empty(), "fila cancelada")
	verificar(f.iniciar("ff_ate_120", j.concessionaria.comprar_carro(d.carro("forte")), 1, 0.0) != "", "inelegível não inicia")
	j.free()
	d.free()


func test_save_ida_e_volta() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var c: Carro = j.garagem.carro(uid)
	j.concessionaria.comprar_peca(c, d.peca("turbo"))
	j.concessionaria.comprar_peca(c, d.peca("motor_fr"))
	j.concessionaria.comprar_pneu(c, d.pneu("chuva"))
	var oferta: Dictionary = Usados.estoque(d.lista("carros"), 0, j.usados_vendidos)[0]
	j.concessionaria.comprar_usado(oferta, d.carro(oferta["carro_id"]), j.usados_vendidos)
	j.licencas.append("b")
	j.graus_licenca["b1"] = "prata"
	f.iniciar("aberto", uid, 4, 0.0)
	f.processar(f.corrida_atual(0.0)["duracao"] + 1.0)

	var texto := JSON.stringify(Save.serializar(j))
	var k := _jogador(d)
	k.novo_jogo(d.economia(), d.pneu)
	igual(Save.desserializar(JSON.parse_string(texto), k, d), "", "load")
	igual(JSON.stringify(Save.serializar(k)), texto, "estado idêntico")
	var ck: Carro = k.garagem.carro(uid)
	igual(ck.atributos_efetivos("chuva"), c.atributos_efetivos("chuva"), "atributos do carro")
	var fk := _fila(d, k)
	igual(fk.corrida_atual(100.0)["resultado"]["carros"], f.corrida_atual(100.0)["resultado"]["carros"], "corrida em andamento idêntica")
	verificar(k.concessionaria.comprar_carro(d.carro("fraco")) >= j.garagem.proximo_uid, "uid não se repete")
	igual(Save.desserializar({"versao": 99}, k, d) != "", true, "versão desconhecida")
	j.free()
	k.free()
	d.free()
