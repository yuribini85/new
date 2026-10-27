extends SceneTree
## The Fastfather (docs/idle/interface.md): abre as telas com tudo aberto e
## confere o texto que o jogador lê: tamanho mínimo (IdleUI.TEXTO_MIN), texto que
## cabe na própria caixa (nem cortado nem vazando), nada saindo da tela pela
## lateral e nenhum texto por cima de outro. Sai com código 1 se achar algo.
## Uso: godot --headless --script res://tools/checar_tela_idle.gd
## (Grava um save novo do idle em user://, como a ferramenta de fotos.)

var _erros: Array = []
var _tela: Control


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	root.size = Vector2i(720, 1280)
	# Save limpo: um save antigo abriria o BEM-VINDO DE VOLTA! por cima.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IdleEstado.ARQUIVO_SAVE))
	var tela: Control = load("res://idle/idle.tscn").instantiate()
	_tela = tela
	root.add_child(tela)
	await process_frame
	tela.pular_titulo()
	await process_frame
	tela._guia.limpar()  # a dica do LARGAR (tutorial) não entra na conferência
	var e: IdleEstado = tela.estado
	# Tudo aberto, pilotos para encher a grade, as cinco modalidades abertas.
	for d in e.cfg_desbloqueios():
		e.oferecidos.append(String(d["id"]))
		e.desbloqueados.append(String(d["id"]))
	for i in 5:
		e.contratar(tela.dados, 300 + i)
	for m in e.cfg["modalidades"]:
		var lib: Dictionary = m.get("libera", {})
		if not lib.is_empty():
			e._m(String(lib["modalidade"]))["liga"] = int(lib["liga"])
	e.dinheiro = 1.0e7
	tela._aplicar_desbloqueios()
	for aba in ["corrida", "pistas", "pilotos", "metas", "config"]:
		if aba == "config":
			tela._abrir("corrida")
			tela._abrir_config()
		else:
			tela._abrir(aba)
		for i in 8:
			await process_frame
		_checar(tela, aba)
	for linha in _erros:
		print(linha)
	print(("ok   tela do idle (%s)" % "texto legível, sem cortes nem sobreposições") if _erros.is_empty()
			else "FAIL tela do idle: %d problema(s)" % _erros.size())
	quit(0 if _erros.is_empty() else 1)


## Largura da linha mais longa do texto.
func _largura(c: Control, t: String, tam: int) -> float:
	var f := c.get_theme_font("font")
	var w := 0.0
	for linha in t.split("\n"):
		w = maxf(w, f.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
	return w


func _texto(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	return ""


func _visivel(c: Control) -> bool:
	return c.is_visible_in_tree() and c.modulate.a > 0.05 and c.get_global_rect().has_area()


func _checar(tela: Control, aba: String) -> void:
	var textos: Array[Control] = []
	_coletar(tela, textos)
	var largura := float(root.size.x)
	for c in textos:
		var t := _texto(c).strip_edges()
		var tam := c.get_theme_font_size("font_size")
		var nome := "%s: %s \"%s\"" % [aba, c.get_class(), t.left(30)]
		if tam < IdleUI.TEXTO_MIN:
			_erros.append("%s com %d px (mínimo %d)" % [nome, tam, IdleUI.TEXTO_MIN])
		var r := c.get_global_rect()
		if r.end.x > largura + 1.0 or r.position.x < -1.0:
			_erros.append("%s sai da tela pela lateral" % nome)
		if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w := _largura(c, t, tam)
			if w > r.size.x + 2.0:
				_erros.append("%s não cabe (%d px de texto em %d px)" % [nome, w, r.size.x])
		elif c is Button:
			var w := _largura(c, t, tam)
			if w > r.size.x - 8.0:
				_erros.append("%s não cabe no botão (%d px de texto em %d px)" % [nome, w, r.size.x])
	# Texto por cima de texto (fora da mesma linhagem: rótulo dentro de botão é normal).
	for i in textos.size():
		for j in range(i + 1, textos.size()):
			var a := textos[i]
			var b := textos[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if not _mesma_camada(a, b):
				continue
			var x := a.get_global_rect().grow(-2.0).intersection(b.get_global_rect().grow(-2.0))
			if x.has_area():
				_erros.append("%s: \"%s\" por cima de \"%s\"" % [aba, _texto(a).left(24), _texto(b).left(24)])


## Janelas por cima (configurações, BEM-VINDO DE VOLTA!, conversa) cobrem a
## tela: só compara textos do mesmo lado (dentro ou fora da janela).
func _mesma_camada(a: Control, b: Control) -> bool:
	for nome in ["_config", "_coleta", "_conversa"]:
		var j: Node = _tela.get(nome)
		if j != null and j.is_ancestor_of(a) != j.is_ancestor_of(b):
			return false
	return true


func _coletar(n: Node, saida: Array[Control]) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is ScrollContainer:
			_coletar_rolagem(c, c, saida)
			continue
		if (c is Label or c is Button) and _texto(c).strip_edges() != "" and _visivel(c):
			saida.append(c)
		_coletar(c, saida)


## Dentro de uma rolagem, só o que está na parte visível na vertical (o que
## passa pela lateral conta: é o que vaza da tela).
func _na_vertical(area: Rect2, r: Rect2) -> bool:
	return r.position.y >= area.position.y - 1.0 and r.end.y <= area.end.y + 1.0


## Dentro de uma rolagem, só o que está na parte visível.
func _coletar_rolagem(n: Node, sc: ScrollContainer, saida: Array[Control]) -> void:
	for c in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if (c is Label or c is Button) and _texto(c).strip_edges() != "" and _visivel(c) \
				and _na_vertical(sc.get_global_rect(), c.get_global_rect()):
			saida.append(c)
		_coletar_rolagem(c, sc, saida)
