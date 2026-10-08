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
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	igual(f.iniciar("aberto", uid, 3, 1000.0), "", "iniciar")
	var dur: float = f.corrida_atual(1000.0)["duracao"]
	var saldo: int = j.economia.saldo
	var r := f.processar(1000.0 + dur * 2 + 0.5)
	igual(r["corridas"].size(), 2, "duas concluídas (duração %.1f s)" % dur)
	igual(r["premio_total"], 1000, "2 × 500")
	igual(r["carros_premio"].size(), 0, "prova já vencida: carro-prêmio não volta")
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
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
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
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	f.iniciar("aberto", uid, 5, 0.0)
	j.economia.creditar(1000)
	j.concessionaria.comprar_carro(d.carro("fraco"))  # o último carro não se vende
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
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
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


const SaveManagerScript := preload("res://autoload/save_manager.gd")
const PASTA_TESTE := "user://teste_saves/"


func _limpar_pasta() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA_TESTE)
	for f in DirAccess.get_files_at(PASTA_TESTE):
		DirAccess.remove_absolute(PASTA_TESTE + f)


func _escrever(caminho: String, texto: String) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func test_save_corrompido_usa_bak_e_preserva_o_original() -> void:
	_limpar_pasta()
	var d := dados_fixture()
	var j := _jogador(d)
	j.concessionaria.comprar_carro(d.carro("forte"))
	var arq := PASTA_TESTE + "save.json"
	SaveManagerScript.gravar(arq, Save.serializar(j))
	j.concessionaria.comprar_carro(d.carro("fraco"))
	SaveManagerScript.gravar(arq, Save.serializar(j))
	verificar(FileAccess.file_exists(arq + ".bak"), "gravar guarda o anterior em .bak")
	_escrever(arq, "{corrompido")
	var k := _jogador(d)
	var r: Dictionary = SaveManagerScript.carregar_protegido(arq, k, d)
	igual(r["origem"], "bak", "recuperou do .bak")
	igual(k.garagem.lista().size(), 1, "estado do save anterior (um carro)")
	verificar(r["aviso"] != "", "avisa o jogador")
	var erros := Array(DirAccess.get_files_at(PASTA_TESTE)).filter(func(f): return ".erro-" in f)
	igual(erros.size(), 1, "o corrompido foi guardado, não apagado")
	j.free()
	k.free()
	d.free()


func test_save_e_bak_invalidos_comecam_do_zero_sem_apagar_nada() -> void:
	_limpar_pasta()
	var d := dados_fixture()
	var arq := PASTA_TESTE + "save.json"
	_escrever(arq, JSON.stringify({"versao": 99}))
	_escrever(arq + ".bak", "lixo")
	var k := _jogador(d)
	var saldo: int = k.economia.saldo
	var r: Dictionary = SaveManagerScript.carregar_protegido(arq, k, d)
	igual(r["carregou"], false, "não carregou")
	igual(k.economia.saldo, saldo, "estado intacto")
	verificar("versão" in r["aviso"] or "campo" in r["aviso"], "aviso explica: " + r["aviso"])
	igual(Array(DirAccess.get_files_at(PASTA_TESTE)).filter(func(f): return ".erro-" in f).size(), 2, "os dois guardados")
	verificar(not FileAccess.file_exists(arq), "nada no lugar para ser sobrescrito por engano")
	k.free()
	d.free()


func test_save_com_carro_que_saiu_de_data_nao_altera_estado() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.concessionaria.comprar_carro(d.carro("forte"))
	var s := Save.serializar(j)
	s = JSON.parse_string(JSON.stringify(s))
	s["carros"][0]["id"] = "carro_removido"
	var k := _jogador(d)
	var saldo: int = k.economia.saldo
	verificar("carro_removido" in Save.desserializar(s, k, d), "erro cita o carro")
	igual(k.economia.saldo, saldo, "nada foi aplicado pela metade")
	igual(k.garagem.lista().size(), 0, "garagem intacta")
	j.free()
	k.free()
	d.free()


func test_processar_antes_do_fim_nao_simula_de_novo() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	j.vitorias["aberto"] = 1  # repetir exige a prova já vencida
	f.iniciar("aberto", uid, 2, 0.0)
	var dur: float = f.corrida_atual(0.0)["duracao"]
	var antes: int = f.carreira.simulacoes
	for s in range(1, 60):
		f.processar(float(s))  # um "segundo" de cada vez, longe do fim
		f.corrida_atual(float(s))
	igual(f.carreira.simulacoes, antes, "nenhuma simulação nova durante a corrida")
	j.concessionaria.comprar_peca(j.garagem.carro(uid), d.peca("turbo"))
	f.processar(61.0)
	igual(f.carreira.simulacoes, antes, "peça nova depois da inscrição não muda a corrida programada")
	f.processar(dur + 100.0)
	igual(j.dias, 1, "a corrida é aplicada quando termina")
	j.free()
	d.free()


func test_repetir_so_prova_vencida() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(f.iniciar("aberto", uid, 3, 0.0) != "", "desafio não repete")
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "desafio: uma inscrição")
	j.free()
	d.free()


func test_fila_guarda_copia_da_preparacao() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var c: Carro = j.garagem.carro(uid)
	igual(j.concessionaria.comprar_peca(c, d.peca("turbo")), "", "turbo")
	c.configuracoes.append({"nome": "turbo", "pecas": ["turbo"], "ajuste_cambio": ""})
	c.remover(d.peca("turbo")["categoria"])
	j.vitorias["aberto"] = 1
	igual(f.iniciar("aberto", uid, 2, 0.0, c.configuracoes[0]), "", "inscrição com a preparação salva")
	var antes: Dictionary = f.carro_inscrito(j.fila).atributos_efetivos("seco")
	verificar(antes["potencia"] > c.atributos_efetivos("seco")["potencia"], "inscrito com turbo, garagem sem")
	c.configuracoes[0]["pecas"] = []
	c.instalar(d.peca("turbo"))
	c.remover(d.peca("turbo")["categoria"])
	igual(f.carro_inscrito(j.fila).atributos_efetivos("seco"), antes, "editar a configuração salva não muda a inscrição")
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.garagem.carro(uid).configuracoes.size(), 1, "configuração salva volta")
	var fk := _fila(d, k)
	igual(fk.carro_inscrito(k.fila).atributos_efetivos("seco"), antes, "inscrição volta do save")
	j.free()
	k.free()
	d.free()


func test_prova_inedita_nao_corre_offline() -> void:
	# Decisão 34: prova não vencida não termina com o app fechado; recomeça ao vivo.
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var fila := _fila(d, j)
	igual(fila.iniciar("aberto", uid, 1, 1000.0), "", "inscrição")
	var dur := fila.duracao_atual()
	var rel: Dictionary = fila.processar(1000.0 + dur + 600.0)
	igual(rel["corridas"].size(), 0, "nada aplicado na volta")
	igual(rel.get("recomecou", ""), "aberto", "corrida recomeça")
	perto(float(j.fila["inicio"]), 1000.0 + dur + 600.0, 0.01, "recomeça agora")
	# Com o app aberto (processamento a cada segundo) ela termina.
	var t := 1000.0 + dur + 600.0
	while t < 1000.0 + 2.0 * dur + 601.0 and fila.processar(t)["corridas"].is_empty():
		t += 1.0
	verificar(j.fila.is_empty(), "termina online")
	# Repetição de prova vencida corre offline.
	j.vitorias["aberto"] = 1
	igual(fila.iniciar("aberto", uid, 2, 5000.0), "", "repetição")
	igual(fila.processar(5000.0 + 3.0 * dur)["corridas"].size(), 2, "repetições offline")
	j.free()
	d.free()
