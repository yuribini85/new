extends "res://tests/base_teste.gd"

const JogadorScript := preload("res://autoload/jogador.gd")


func _jogador(d: Node) -> Node:
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.economia.creditar(10000)
	return j


func _fila(d: Node, j: Node, teto := 3600.0) -> Fila:
	return Fila.new(Carreira.new(d, j), j, teto)


func test_uma_corrida_por_vez_aplicada_ao_terminar() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(f.iniciar("aberto", uid, 3, 1000.0) != "", "prova não vencida: sem fila (decisão 120)")
	j.vitorias["aberto"] = 1
	igual(f.iniciar("aberto", uid, 1, 1000.0), "", "iniciar")
	var dur: float = f.corrida_atual(1000.0)["duracao"]
	var saldo: int = j.economia.saldo
	igual(f.processar(1000.0 + dur * 0.5)["corridas"].size(), 0, "no meio, nada aplicado")
	var r := f.processar(1000.0 + dur + 0.5)
	igual(r["corridas"].size(), 1, "aplicada ao terminar (duração %.1f s)" % dur)
	igual(r["premio_total"], 500, "prêmio")
	igual(r["carros_premio"].size(), 0, "prova já vencida: carro-prêmio não volta")
	igual(j.economia.saldo, saldo + 500, "saldo")
	verificar(j.fila.is_empty(), "acabou: nada se repete")
	igual(j.dias, 1, "dias")
	j.free()
	d.free()


func test_teto_offline_limita_e_descarta_o_excesso() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j, 1.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	f.iniciar("aberto", uid, 1, 0.0)
	var dur: float = f.corrida_atual(0.0)["duracao"]
	var r := f.processar(100000.0)
	igual(r["corridas"].size(), 0, "ausência acima do teto não corre a prova inteira")
	perto(r["tempo_perdido_s"], 100000.0 - 1.0, 1e-6, "tempo perdido")
	perto(f.corrida_atual(100000.0)["decorrido"], 1.0, 1e-3, "retoma de onde parou")
	verificar(dur > 1.0, "a prova dura mais que o teto do teste")
	j.free()
	d.free()


func test_carro_vendido_cancela_a_fila() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	f.iniciar("aberto", uid, 1, 0.0)
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
	j.concessionaria.comprar_carro(d.carro("fraco"))
	j.licencas.append("b")
	j.graus_licenca["b1"] = "prata"
	j.vitorias["aberto"] = 1
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "iniciar")
	f.processar(f.corrida_atual(0.0)["duracao"] * 0.5)  # salva no meio da corrida

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


## Código do progresso (SaveManager.codigo / usar_codigo): ida e volta e
## código estragado não muda nada.
func test_codigo_do_progresso() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var texto := JSON.stringify(Save.serializar(j))
	var bruto := texto.to_utf8_buffer()
	var codigo := SaveManagerScript.PREFIXO_CODIGO + Marshalls.raw_to_base64(bruto.compress(FileAccess.COMPRESSION_GZIP))
	verificar(codigo.length() < texto.length(), "o código é menor que o save")
	var raw := Marshalls.base64_to_raw(codigo.substr(SaveManagerScript.PREFIXO_CODIGO.length()))
	igual(raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8(), texto, "volta igual")
	verificar(j.garagem.carro(uid) != null, "carro no jogo")
	# Selo: o código e o save adulterados são reconhecidos.
	var comprimido := bruto.compress(FileAccess.COMPRESSION_GZIP)
	verificar(Selo.confere(comprimido, Selo.de(comprimido)), "selo confere")
	var mexido := comprimido.duplicate()
	mexido[mexido.size() / 2] = mexido[mexido.size() / 2] ^ 1
	verificar(not Selo.confere(mexido, Selo.de(comprimido)), "um byte mudado: o selo não confere")
	# Compras: com os dados reais (as fixtures não têm loja).
	var dr: Node = DadosScript.new()
	dr.carregar("res://data/")
	var jr := _jogador(dr)
	jr.flags["PACK_PREMIUM"] = true
	var arq := "user://teste_selo.json"
	SaveManagerScript.gravar(arq, Save.serializar(jr))
	var k := _jogador(dr)
	igual(SaveManagerScript.carregar_protegido(arq, k, dr)["carregou"], true, "save com selo abre")
	verificar(k.flags.has("PACK_PREMIUM"), "selo certo: a compra fica")
	var texto_arq := FileAccess.get_file_as_string(arq).replace("\"saldo\":", "\"saldo\":9")
	var f := FileAccess.open(arq, FileAccess.WRITE)
	f.store_string(texto_arq)
	f.close()
	var m := _jogador(dr)
	igual(SaveManagerScript.carregar_protegido(arq, m, dr)["carregou"], true, "save mexido ainda abre")
	verificar(not m.flags.has("PACK_PREMIUM"), "save mexido: as compras saem")
	for x in [arq, arq + ".bak"]:
		DirAccess.remove_absolute(x)
	j.free()
	jr.free()
	k.free()
	m.free()
	d.free()
	dr.free()


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
	f.iniciar("aberto", uid, 1, 0.0)
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


## Decisão 90: a inscrição não resolve a corrida no mesmo quadro; ela anda aos
## poucos (avancar_preparo, a cada quadro da principal) e uma só vez.
func test_inscricao_resolve_a_corrida_aos_poucos() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "iniciar")
	verificar(not f.pronta(), "recém-inscrita: ainda não resolvida")
	verificar(not f.pronta(false), "nem sem as amostras")
	var fatias := 0
	while not f.avancar_preparo(0.0):
		fatias += 1
	verificar(fatias > 0, "orçamento zero não resolve tudo num quadro")
	verificar(f.pronta() and f.pronta(false), "resolvida")
	var antes: int = f.carreira.simulacoes
	var c := f.corrida_atual(0.0)
	igual(f.carreira.simulacoes, antes, "a tela reusa a corrida resolvida aos poucos")
	# A mesma corrida de uma vez, noutra fila com o mesmo estado: igual.
	var outra := _fila(d, j)
	igual(outra.corrida_atual(0.0)["resultado"], c["resultado"], "aos poucos = de uma vez")
	# Pedida antes de terminar (processar, adiantar): termina a que está em
	# andamento, sem simular de novo do zero.
	f.cancelar()
	j.vitorias["aberto"] = 1
	f.iniciar("aberto", uid, 1, 0.0)
	f.avancar_preparo(0.0)
	antes = f.carreira.simulacoes
	verificar(f.duracao_atual() > 0.0, "duração pedida no meio")
	igual(f.carreira.simulacoes, antes, "terminou a pendente em vez de simular outra")
	verificar(f.avancar_preparo(0.0), "nada mais pendente")
	j.free()
	d.free()


func test_fila_guarda_copia_da_preparacao() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var c: Carro = j.garagem.carro(uid)
	igual(j.concessionaria.comprar_peca(c, d.peca("turbo")), "", "turbo")
	var cfg := c.configuracao()
	c.remover(d.peca("turbo")["categoria"])
	j.vitorias["aberto"] = 1
	igual(f.iniciar("aberto", uid, 1, 0.0, cfg), "", "inscrição com a preparação dada")
	var antes: Dictionary = f.carro_inscrito(j.fila).atributos_efetivos("seco")
	verificar(antes["potencia"] > c.atributos_efetivos("seco")["potencia"], "inscrito com turbo, garagem sem")
	cfg["pecas"] = []
	c.instalar(d.peca("turbo"))
	c.remover(d.peca("turbo")["categoria"])
	igual(f.carro_inscrito(j.fila).atributos_efetivos("seco"), antes, "mexer na preparação depois não muda a inscrição")
	var estado: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	# Save antigo: preparações salvas e ajuste do câmbio saíram (ficam de fora no load).
	estado["carros"][0]["configuracoes"] = [{"nome": "turbo", "pecas": ["turbo"], "ajuste_cambio": "curto"}]
	estado["carros"][0]["ajuste_cambio"] = "curto"
	var k := _jogador(d)
	igual(Save.desserializar(estado, k, d), "", "load")
	igual(k.garagem.carro(uid).ajuste_cambio, "", "câmbio no equilibrado")
	var fk := _fila(d, k)
	igual(fk.carro_inscrito(k.fila).atributos_efetivos("seco"), antes, "inscrição volta do save")
	j.free()
	k.free()
	d.free()


func test_corrida_iniciada_termina_offline() -> void:
	# Decisão 68: a corrida iniciada termina com o app fechado, inédita ou não.
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	var fila := _fila(d, j)
	igual(fila.iniciar("aberto", uid, 1, 1000.0), "", "inscrição")
	var dur := fila.duracao_atual()
	var rel: Dictionary = fila.processar(1000.0 + dur + 600.0)
	igual(rel["corridas"].size(), 1, "terminou enquanto o app estava fechado")
	verificar(bool(rel["corridas"][0]["offline"]), "marcada como offline")
	verificar(j.fila.is_empty(), "nada continua depois")
	j.free()
	d.free()


## Decisão 39: com a aceleração, o relógio das corridas anda `fator` vezes mais
## rápido só dentro da janela; o adiantado fica; vídeo novo soma tempo.
func test_aceleracao_relogio_e_soma() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var regras := {"fator": 2.0, "duracao_s": 1800.0, "teto_s": null}
	perto(Aceleracao.agora(j, 5000.0), 5000.0, 1e-6, "sem aceleração: relógio real")
	igual(Aceleracao.ativar(j, regras, 1000.0), "", "ativar")
	perto(Aceleracao.agora(j, 1000.0), 1000.0, 1e-6, "no início, sem salto")
	perto(Aceleracao.agora(j, 1600.0), 2200.0, 1e-6, "600 s reais = 1200 s de corrida")
	perto(Aceleracao.restante_s(j, 1600.0), 1200.0, 1e-6, "faltam 1200 s")
	igual(Aceleracao.ativar(j, regras, 1600.0), "", "vídeo durante: soma")
	perto(Aceleracao.restante_s(j, 1600.0), 3000.0, 1e-6, "1200 + 1800")
	perto(Aceleracao.agora(j, 4600.0), 4600.0 + 3600.0, 1e-6, "fim da janela: 3600 s adiantados")
	perto(Aceleracao.agora(j, 9000.0), 9000.0 + 3600.0, 1e-6, "depois: adiantado fica, anda 1×")
	verificar(not Aceleracao.ativa(j, 9000.0), "terminou")
	igual(Aceleracao.ativar(j, regras, 10000.0), "", "nova janela")
	perto(Aceleracao.agora(j, 10000.0), 10000.0 + 3600.0, 1e-6, "nova janela não volta o relógio")
	perto(Aceleracao.agora(j, 10100.0), 10100.0 + 3700.0, 1e-6, "e anda 2×")
	var teto := {"fator": 2.0, "duracao_s": 1800.0, "teto_s": 2400.0}
	var k := _jogador(d)
	Aceleracao.ativar(k, teto, 0.0)
	Aceleracao.ativar(k, teto, 0.0)
	perto(Aceleracao.restante_s(k, 0.0), 2400.0, 1e-6, "teto limita a soma")
	verificar(Aceleracao.ativar(k, teto, 0.0) != "", "no teto, recusa")
	verificar(Aceleracao.ativar(k, {}, 0.0) != "", "sem regras, indisponível")
	j.free()
	k.free()
	d.free()


## A fila medida pelo relógio do jogo termina na metade do tempo real; o prêmio
## é o mesmo; o estado da aceleração volta igual do save.
func test_aceleracao_na_fila_e_no_save() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	j.vitorias["aberto"] = 1
	Aceleracao.ativar(j, {"fator": 2.0, "duracao_s": 100000.0}, 0.0)
	igual(f.iniciar("aberto", uid, 1, Aceleracao.agora(j, 0.0)), "", "iniciar")
	var dur: float = f.duracao_atual()
	var saldo: int = j.economia.saldo
	var r := f.processar(Aceleracao.agora(j, dur * 0.5 + 0.1))
	igual(r["corridas"].size(), 1, "uma corrida em metade do tempo real (duração %.1f s)" % dur)
	igual(j.economia.saldo, saldo + 500, "prêmio igual")
	var texto := JSON.stringify(Save.serializar(j))
	var k := _jogador(d)
	igual(Save.desserializar(JSON.parse_string(texto), k, d), "", "load")
	igual(k.aceleracao, j.aceleracao, "aceleração no save")
	var antigo: Dictionary = JSON.parse_string(texto)
	antigo.erase("aceleracao")
	igual(Save.desserializar(antigo, k, d), "", "save antigo sem aceleração")
	verificar(k.aceleracao.is_empty(), "sem aceleração")
	j.free()
	k.free()
	d.free()


## Decisão 40: carro que saiu da frota vira o substituto no save; peças que o
## carro novo não tem saem; o resto do save carrega igual.
func test_save_com_carro_removido_migra_para_o_substituto() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	j.concessionaria.comprar_peca(j.garagem.carro(uid), d.peca("turbo"))
	var s: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))
	s["carros"][0]["id"] = "antigo"
	s["carros"][0]["pecas_possuidas"].append("antigo_motor_1")
	s["desejos"] = ["antigo", "forte", "sumiu"]
	var k := _jogador(d)
	igual(Save.desserializar(s, k, d), "", "carrega")
	var c: Carro = k.garagem.carro(uid)
	igual(c.id, "forte", "substituto")
	verificar(c.pecas_possuidas.has("turbo") and not c.pecas_possuidas.has("antigo_motor_1"), "peças")
	igual(k.desejos, ["forte"], "desejos sem repetir nem sumidos")
	j.free()
	k.free()
	d.free()


## O save com a fila num desafio do Grid ("grid_<equipe>", prova montada) é
## válido: antes ele era recusado e o jogo recomeçava do zero.
func test_save_com_desafio_do_grid_na_fila() -> void:
	var d: Node = DadosScript.new()
	d.carregar(d.DATA_DIR)
	var j := _jogador(d)
	var uid: int = j.concessionaria.comprar_carro(d.lista("carros")[0])
	var eq: Dictionary = TheGrid.equipes(d).filter(func(e): return GridDesafio.de(d, e).get("modo") == "corrida")[0]
	var s: Dictionary = JSON.parse_string(JSON.stringify(Save.serializar(j)))  # como no disco
	s["fila"] = {"evento_id": GridDesafio.PREFIXO + String(eq["id"]), "uid": uid, "restantes": 1, "inicio": 0.0, "semente": 1}
	igual(Save.validar(s, d), "", "desafio do Grid na fila")
	s["fila"]["evento_id"] = GridDesafio.PREFIXO + "nao_existe"
	verificar(Save.validar(s, d) != "", "equipe que não existe é recusada")
	j.free()
	d.free()


## Decisão 117: a escolha de um momento entra no piloto da fila, a corrida é
## refeita com ela e, enquanto isso, a tela segue com o resultado anterior.
func test_ordem_refaz_a_corrida_e_fica_na_fila() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "iniciar")
	var antes := f.corrida_atual(0.0)
	var versao := f.versao
	f.ordenar({"escolha": "atacar", "de": 5.0, "ate": 40.0, "ritmo": 1.05, "agressividade": 1.0})
	igual(j.fila["piloto"]["ordens"].size(), 1, "ordem gravada na fila (vale offline)")
	igual(f.corrida_atual(1.0)["resultado"], antes["resultado"], "enquanto refaz, a tela usa a anterior")
	while not f.avancar_preparo(0.0):
		pass
	verificar(f.versao > versao, "resultado novo no cache")
	var depois := f.corrida_atual(1.0)
	verificar(float(depois["resultado"]["carros"]["jogador"]["tempo_total"])
			< float(antes["resultado"]["carros"]["jogador"]["tempo_total"]), "com a ordem, o jogador anda mais")
	j.free()
	d.free()


## Pilotagem por toques (decisão 127): os toques no meio da corrida ao vivo
## ficam na fila; a tela emenda a corrida refeita enquanto ela termina, e a
## corrida aplicada (como com o jogo fechado) é a mesma que sairia do zero com
## as ordens gravadas.
func test_pilotar_no_meio_vale_como_do_zero() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "iniciar")
	f.corrida_atual(0.0)
	igual(f.pilotar({"de": 5.0, "ate": 9.0, "ritmo": 1.04}, 5.0), {}, "sem a corrida ao vivo no instante, o toque não conta")
	f.acompanhar(5.0, INF)
	verificar(f.ao_vivo(5.0), "corrida ao vivo chegou à tela")
	var a1 := f.pilotar({"de": 5.0, "ate": 9.0, "ritmo": 1.04}, 5.0)
	verificar(not a1.is_empty(), "toque valeu")
	var parcial := f.parcial()
	verificar(not parcial.is_empty() and float(parcial["desde"]) >= 5.0, "a tela recebe a parte já refeita")
	f.acompanhar(12.0, INF)
	verificar(not f.pilotar({"de": 12.0, "ate": 14.0, "acel": 1.08}, 12.0).is_empty(), "segundo toque")
	igual(j.fila["piloto"]["ordens"].size(), 2, "as ordens ficam na fila (valem com o jogo fechado)")
	while not f.avancar_preparo(1.0):
		pass
	var vivo: Dictionary = f.corrida_atual(20.0)["resultado"]
	# Do zero, com as ordens gravadas: a mesma corrida.
	var k := f._chave(j.fila)
	var zero: Dictionary = f.carreira.preparar("aberto", uid, int(j.fila["semente"]), true, k["carro"], k["comp"],
			k["piloto"])["resultado"]
	igual(vivo["classificacao"], zero["classificacao"], "mesma classificação")
	perto(float(vivo["carros"]["jogador"]["tempo_total"]), float(zero["carros"]["jogador"]["tempo_total"]), 1e-9,
			"mesmo tempo")
	j.free()
	d.free()


## Momento previsto (Fila.prever): a corrida refeita com cada escolha sai aos
## poucos; escolhida, vale na hora e é a mesma que a fila faria do zero.
func test_ordem_prevista_vale_na_hora() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	igual(f.iniciar("aberto", uid, 1, 0.0), "", "iniciar")
	var antes := f.corrida_atual(0.0)
	var ordens := {
		"atacar": {"escolha": "atacar", "de": 5.0, "ate": 40.0, "ritmo": 1.05, "agressividade": 1.0},
		"esperar": {"escolha": "esperar", "de": 20.0, "ate": 40.0, "ritmo": 1.02, "agressividade": 1.0},
	}
	f.prever(ordens)
	igual(f.previsao("atacar"), {}, "ainda sendo resolvida")
	for i in 1000:
		f.avancar_preparo(1.0)
		if not f.previsao("atacar").is_empty() and not f.previsao("esperar").is_empty():
			break
	verificar(not f.previsao("atacar").is_empty() and not f.previsao("esperar").is_empty(), "as duas previstas")
	var prevista := f.previsao("atacar")
	var versao := f.versao
	f.ordenar(ordens["atacar"])
	verificar(f.versao > versao, "trocou na hora, sem refazer")
	verificar(f.pronta(), "nada pendente")
	igual(f.corrida_atual(1.0)["resultado"], prevista, "a corrida mostrada é a prevista")
	verificar(f.previsao("esperar").is_empty(), "previsões descartadas")
	var g := _fila(d, j)  # do zero, com a mesma ordem gravada
	igual(g.corrida_atual(1.0)["resultado"]["carros"], prevista["carros"], "igual à refeita do zero")
	verificar(prevista != antes["resultado"], "a ordem mudou a corrida")
	j.free()
	d.free()


## Decisão 120: a fila repete só prova vencida e roda inteira com o jogo
## fechado; as ordens dos momentos não passam para a corrida seguinte.
func test_fila_de_prova_vencida_roda_offline() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j, 100000.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("forte"))
	verificar(f.iniciar("aberto", uid, 3, 0.0) != "", "prova não vencida: sem fila")
	j.vitorias["aberto"] = 1
	igual(f.iniciar("aberto", uid, 3, 0.0), "", "vencida: fila de 3")
	f.ordenar({"escolha": "atacar", "de": 5.0, "ate": 40.0, "ritmo": 1.05, "agressividade": 1.0})
	var dur: float = f.corrida_atual(0.0)["duracao"]
	var rel := f.processar(dur * 1.5)
	igual(rel["corridas"].size(), 1, "a primeira terminou")
	igual(int(j.fila["restantes"]), 2, "faltam duas")
	verificar(not j.fila["piloto"].has("ordens"), "a ordem era só da primeira")
	rel = f.processar(dur * 10.0)
	igual(rel["corridas"].size(), 2, "as outras duas com o jogo fechado")
	verificar(j.fila.is_empty(), "fila acabou")
	verificar(f.cabem("aberto", uid) > 1, "cabe mais de uma na capacidade offline")
	j.free()
	d.free()


func test_fila_troca_para_a_vencida_que_paga_mais_por_km() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	var f := _fila(d, j, 100000.0)
	var uid: int = j.concessionaria.comprar_carro(d.carro("fraco"))
	j.vitorias["serie_1"] = 1  # 100 por 1 volta
	igual(f.iniciar("serie_1", uid, 3, 0.0), "", "fila na série")
	igual(f.melhor_renda(j.fila, 0.0), "serie_1", "só ela vencida: fica nela")
	j.vitorias["aberto"] = 1  # 500 por 3 voltas na mesma pista
	j.vitorias["licenciado"] = 1  # pede licença que o jogador não tem
	igual(f.melhor_renda(j.fila, 0.0), "aberto", "o Aberto paga mais por km")
	var dur: float = f.corrida_atual(0.0)["duracao"]
	var rel := f.processar(dur * 1.5)
	igual(String(rel["corridas"][0]["evento_id"]), "serie_1", "a primeira é a escolhida")
	igual(String(j.fila["evento_id"]), "aberto", "a próxima vai para a que paga mais")
	j.free()
	d.free()


func test_aviso_de_garagem_acima_do_limite() -> void:
	var d := dados_fixture()
	var j := _jogador(d)
	j.garagem.vagas = 1
	j.concessionaria.comprar_carro(d.carro("fraco"))
	igual(VagasGaragem.aviso_excesso(j), "", "dentro do limite")
	j.garagem.adicionar(Carro.new(d.carro("forte")))  # carro-prêmio entra mesmo cheia
	verificar("2 carros em 1 vagas" in VagasGaragem.aviso_excesso(j), "acima do limite: o aviso")
	j.free()
	d.free()
