extends SceneTree
## Jogador robô do Chrome Racing Team: começa um save novo e joga como uma pessoa
## atenta (lê a conversa, larga no toque, compra a melhoria mais barata, aceita a
## oferta quando tem o dinheiro, sobe de liga). Registra a linha do tempo (o que
## aconteceu e quando, em tempo de jogo) e tira fotos a cada marco e a cada
## minuto. Serve para analisar a experiência dos primeiros minutos.
## Uso (precisa de tela): xvfb-run -a godot --resolution 540x960 --fixed-fps 30
##   --script res://tools/jogar_idle.gd -- --saida=/pasta/ [--minutos=20] [--leitura_s=3]
## Apaga o save do idle em user:// (como a ferramenta de fotos, que o reescreve).

var _saida := "user://jogar_idle/"
var _minutos := 20.0
var _leitura_s := 3.0  # tempo que a pessoa leva lendo uma conversa
var _t := 0.0
var _linhas: Array = []
var _foto := 0
var _proxima_foto := 0.0
var _espera := {}  # ação -> desde quando está disponível


func _initialize() -> void:
	_rodar.call_deferred()


func _log(texto: String) -> void:
	var linha := "%5.0fs  %s" % [_t, texto]
	_linhas.append(linha)
	print(linha)


func _fotografar(nome: String) -> void:
	_foto += 1
	root.get_texture().get_image().save_png(_saida.path_join("%03d_%s.png" % [_foto, nome]))


## A ação fica disponível por `atraso` segundos antes do robô agir (tempo humano).
func _pronto(acao: String, disponivel: bool, atraso: float) -> bool:
	if not disponivel:
		_espera.erase(acao)
		return false
	if not _espera.has(acao):
		_espera[acao] = _t
	if _t - float(_espera[acao]) >= atraso:
		_espera.erase(acao)
		return true
	return false


func _rodar() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"saida": _saida = kv[1]
			"minutos": _minutos = float(kv[1])
			"leitura_s": _leitura_s = float(kv[1])
	DirAccess.make_dir_recursive_absolute(_saida)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IdleEstado.ARQUIVO_SAVE))
	root.size = Vector2i(720, 1280)
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	tela.pular_titulo()
	var e: IdleEstado = tela.estado
	var corridas := e.corridas
	var liga := e.liga_total()
	var conversa_vista: Object = null
	var compras := 0
	var gasto := 0.0
	var sem_acao_desde := 0.0
	var maior_espera := 0.0
	_log("início: $%s" % IdleUI.curto(e.dinheiro))
	_fotografar("inicio")
	while _t < _minutos * 60.0:
		await process_frame
		_t += tela.get_process_delta_time()
		var agiu := false
		# Conversa: lê e responde (compra se tem o dinheiro).
		var c: ConversaIdle = tela._conversa
		if c != null and c != conversa_vista:
			conversa_vista = c
			_log("CONVERSA %s: \"%s\"" % [String(c._d.get("id")), String(c._d.get("fala", ""))])
			_espera.erase("conversa")
		if c != null and _pronto("conversa", true, _leitura_s):
			if c.get("_pagar") != null and not c._pagar.disabled:
				_log("  compra a oferta por $%s" % IdleUI.curto(float(c._d.get("custo", 0))))
				_fotografar("conversa_" + String(c._d.get("id")))
				c._fechar(true)
			else:
				_fotografar("conversa_" + String(c._d.get("id")))
				c._fechar(c.get("_pagar") == null)
				if c.get("_pagar") != null:
					_log("  AGORA NÃO (faltam $%s)" % IdleUI.curto(float(c._d.get("custo", 0)) - e.dinheiro))
			agiu = true
		elif tela._guia.ativo():
			if _pronto("guia", true, 1.5):
				_fotografar("dica")
				_log("  dica: \"%s\"" % tela._guia._texto.text)
				tela._guia.limpar()
		elif tela._janela_aberta:
			if _pronto("janela", true, 2.0):
				_fotografar("liga_nova")
				for n in tela.find_children("*", "BotaoInicio", true, false):
					n.pressed.emit()
				agiu = true
		elif c == null:
			if _pronto("largar", tela._aguardando and tela._largar.visible, 1.0):
				tela._largar.pressed.emit()
				agiu = true
			if _pronto("subir", tela._subir.visible, 1.0):
				_log("SOBE DE LIGA")
				tela._subir.pressed.emit()
				agiu = true
			# Oferta guardada que já dá para pagar.
			for b in tela._ofertas.get_children():
				var d: Dictionary = e.desbloqueio(String(b.get_meta("id", "")))
				if _pronto("oferta", e.dinheiro >= float(d.get("custo", INF)), 1.5):
					_log("toca na oferta guardada %s" % String(d["id"]))
					b.pressed.emit()
					agiu = true
			# A melhoria mais barata que dá para comprar.
			var barata := ""
			for m in e.cfg["melhorias"]:
				var id := String(m["id"])
				var card: Dictionary = tela._cartoes[id]
				if card["cartao"].is_visible_in_tree() and not card["botao"].disabled \
						and (barata == "" or e.custo(id) < e.custo(barata)):
					barata = id
			if _pronto("comprar", barata != "", 0.8):
				gasto += e.custo(barata)
				tela._cartoes[barata]["botao"].pressed.emit()
				compras += 1
				_log("compra %s → Nv. %d" % [barata, e.nivel(barata)])
				agiu = true
		if e.corridas != corridas:
			corridas = e.corridas
			_log("corrida %d: %dº, +$%s (caixa $%s, renda +$%s/s)" % [corridas, IdleEstado.posicao(tela._resultado),
					IdleUI.curto(tela._ganho_corrida), IdleUI.curto(e.dinheiro), IdleUI.curto(e.renda_s())])
		if e.liga_total() != liga:
			liga = e.liga_total()
			_log("LIGA %d (%s)" % [liga, String(e.dados_liga()["nome"])])
		if agiu:
			maior_espera = maxf(maior_espera, _t - sem_acao_desde)
			sem_acao_desde = _t
		if _t >= _proxima_foto:
			_fotografar("min%02d" % int(_t / 60.0))
			_proxima_foto += 60.0
	maior_espera = maxf(maior_espera, _t - sem_acao_desde)
	_log("FIM: %d corridas, liga %d, %d compras ($%s), caixa $%s, maior tempo sem nada para tocar %.0fs" % [
			e.corridas, e.liga_total(), compras, IdleUI.curto(gasto), IdleUI.curto(e.dinheiro), maior_espera])
	var f := FileAccess.open(_saida.path_join("linha_do_tempo.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_linhas) + "\n")
	f.close()
	quit()
