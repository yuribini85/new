class_name Aba
extends ScrollContainer
## Base das abas: conteúdo rolável, reconstruído inteiro em atualizar().
## Telas provisórias com componentes padrão do Godot — sem arte.

signal mudou

var dados: Node
var jogador: Node
var conteudo: VBoxContainer


func _init(dados_: Node, jogador_: Node, titulo: String) -> void:
	dados = dados_
	jogador = jogador_
	name = titulo
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 8)
	add_child(conteudo)


func atualizar() -> void:
	for c in conteudo.get_children():
		c.queue_free()
	construir()


## Implementado por cada aba.
func construir() -> void:
	pass


func titulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 26)
	conteudo.add_child(l)
	return l


func texto(t: String, cor := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	conteudo.add_child(l)
	return l


## Linha com descrição à esquerda e botões à direita. botoes: [[rótulo, Callable, habilitado]].
func linha(descricao: String, botoes: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = descricao
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for b in botoes:
		var bt := Button.new()
		bt.text = b[0]
		bt.custom_minimum_size = Vector2(120, 56)
		bt.disabled = b.size() > 2 and not b[2]
		bt.pressed.connect(func():
			b[1].call()
			mudou.emit())
		h.add_child(bt)
	conteudo.add_child(h)
	return h


func separador() -> void:
	conteudo.add_child(HSeparator.new())


func carro_ativo() -> Carro:
	return jogador.garagem.carro(jogador.carro_ativo)


static func dinheiro(valor: int) -> String:
	var s := str(absi(valor))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if valor < 0 else "") + s + r


func ficha(c: Carro, condicao := "seco") -> String:
	var a := c.atributos_efetivos(condicao)
	var t := "%s · %s · %d cv · %d kg" % [c.base["nome"], c.base["tracao"], a["potencia"], a["peso"]]
	if a["velocidade_max"] != INF:
		t += " · %d km/h" % a["velocidade_max"]
	return t


## Nome legível de uma pista a partir do id ("serra_alta" -> "Serra Alta").
static func nome_pista(id: String) -> String:
	var palavras := []
	for p in id.split("_"):
		palavras.append(p if p in ["do", "da", "das", "de", "dos"] else p.capitalize())
	return " ".join(palavras)
