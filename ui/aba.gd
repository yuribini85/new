class_name Aba
extends ScrollContainer
## Base das abas: conteúdo rolável, reconstruído inteiro em atualizar().
## Telas provisórias com componentes padrão do Godot e placeholders — sem arte.
##
## Linguagem visual comum a todas as telas: cabeçalho com uma frase do que se
## faz ali, cartões, selos coloridos para estado, barras para atributos, uma
## dica de "como funciona" e um botão de próximo passo.

signal mudou
## Pede à tela principal para abrir outra aba (índices em ABAS).
signal ir_para(indice: int)

enum { GARAGEM, LOJA, OFICINA, EVENTOS, CORRIDA, LICENCAS }

const FONTE_PEQUENA := 23
const FONTE_TITULO := 40
const COR_CARTAO := Color(0.15, 0.16, 0.2)
const COR_SECUNDARIA := Color(0.66, 0.69, 0.76)
const COR_DESTAQUE := Color(0.96, 0.76, 0.16)
const COR_BOM := Color(0.36, 0.82, 0.47)
const COR_RUIM := Color(1.0, 0.46, 0.4)
const COR_INFO := Color(0.45, 0.7, 1.0)
const COR_NEUTRA := Color(0.4, 0.42, 0.48)

var dados: Node
var jogador: Node
var conteudo: VBoxContainer


func _init(dados_: Node, jogador_: Node, titulo_aba: String) -> void:
	dados = dados_
	jogador = jogador_
	name = titulo_aba
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 14)
	add_child(conteudo)


func atualizar() -> void:
	for c in conteudo.get_children():
		c.queue_free()
	construir()


## Implementado por cada aba.
func construir() -> void:
	pass


# --- Blocos de tela ---------------------------------------------------------

## Título da tela e uma frase dizendo o que se faz nela.
func cabecalho(t: String, subtitulo := "") -> void:
	rotulo(t, FONTE_TITULO)
	if subtitulo != "":
		rotulo(subtitulo, FONTE_PEQUENA, COR_SECUNDARIA)


## Cartão com fundo arredondado; `acento` pinta a borda esquerda (estado).
## Retorna o VBox de dentro, onde vai o conteúdo.
func cartao(acento := Color.TRANSPARENT, pai: Control = null) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	if acento.a > 0.0:
		sb.border_width_left = 8
		sb.border_color = acento
		sb.content_margin_left = 22
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_pai(pai).add_child(p)
	return v


## Caixa "como funciona": explica a tela para quem chega nela pela primeira vez.
func dica(t: String, pai: Control = null) -> VBoxContainer:
	var v := cartao(COR_INFO, pai)
	rotulo("COMO FUNCIONA", FONTE_PEQUENA, COR_INFO, v)
	rotulo(t, FONTE_PEQUENA + 3, Color(0.88, 0.9, 0.95), v)
	return v


## Cartão de próximo passo com um botão que leva à aba certa.
func proximo_passo(t: String, botao_texto: String, indice: int, pai: Control = null) -> void:
	var v := cartao(COR_DESTAQUE, pai)
	rotulo("PRÓXIMO PASSO", FONTE_PEQUENA, COR_DESTAQUE, v)
	rotulo(t, FONTE_PEQUENA + 3, Color.WHITE, v)
	botao(botao_texto, func(): ir_para.emit(indice), true, true, v)


func rotulo(t: String, tamanho := 0, cor := Color.WHITE, pai: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tamanho > 0:
		l.add_theme_font_size_override("font_size", tamanho)
	if cor != Color.WHITE:
		l.add_theme_color_override("font_color", cor)
	_pai(pai).add_child(l)
	return l


## Etiqueta pequena colorida ("EM USO", "Chuva", "✓ pode correr").
func selo(t: String, cor: Color, pai: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cor, 0.2)
	sb.border_color = cor
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", FONTE_PEQUENA)
	l.add_theme_color_override("font_color", cor.lightened(0.25))
	p.add_child(l)
	_pai(pai).add_child(p)
	return p


## Fileira de selos que quebra linha: selos = [[texto, cor], ...].
func selos(lista: Array, pai: Control = null) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	for s in lista:
		selo(s[0], s[1], h)
	_pai(pai).add_child(h)
	return h


## Botão que executa a ação e reconstrói as telas. `primario` = cor de destaque.
func botao(t: String, acao: Callable, habilitado := true, primario := false, pai: Control = null) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 72)
	b.disabled = not habilitado
	if primario and habilitado:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_DESTAQUE
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		for estado in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0.1, 0.1, 0.1))
	b.pressed.connect(func():
		acao.call()
		mudou.emit())
	_pai(pai).add_child(b)
	return b


func fileira(pai: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_pai(pai).add_child(h)
	return h


## Barra de atributo: rótulo, preenchimento até valor/maximo e o número.
## `antes` >= 0 mostra a diferença (verde se melhora, vermelho se piora);
## `menor_melhor` inverte as cores (peso).
func barra(nome: String, valor: float, maximo: float, texto_valor: String, cor: Color,
		pai: Control = null, antes := -1.0, menor_melhor := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 40)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.draw.connect(func():
		var fonte := c.get_theme_default_font()
		var y := c.size.y * 0.5 + FONTE_PEQUENA * 0.35
		c.draw_string(fonte, Vector2(0, y), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_PEQUENA, COR_SECUNDARIA)
		var x0 := 150.0
		var largura := c.size.x - x0 - 170.0
		var trilho := Rect2(x0, c.size.y * 0.5 - 7, largura, 14)
		c.draw_rect(trilho, Color(0.25, 0.27, 0.32))
		var f := clampf(valor / maxf(maximo, 1e-6), 0.0, 1.0)
		if antes >= 0.0 and not is_equal_approx(antes, valor):
			var fa := clampf(antes / maxf(maximo, 1e-6), 0.0, 1.0)
			var melhora := (valor > antes) != menor_melhor
			c.draw_rect(Rect2(x0, trilho.position.y, largura * minf(f, fa), 14), cor)
			c.draw_rect(Rect2(x0 + largura * minf(f, fa), trilho.position.y, largura * absf(f - fa), 14),
					COR_BOM if melhora else COR_RUIM)
		else:
			c.draw_rect(Rect2(x0, trilho.position.y, largura * f, 14), cor)
		c.draw_string(fonte, Vector2(c.size.x - 160.0, y), texto_valor, HORIZONTAL_ALIGNMENT_RIGHT, 160.0,
				FONTE_PEQUENA, Color.WHITE))
	_pai(pai).add_child(c)
	return c


## Potência e peso do carro em barras, relativos ao catálogo.
func barras_carro(a: Dictionary, pai: Control = null, antes: Dictionary = {}) -> void:
	var max_cv := 1.0
	var max_kg := 1.0
	for c in dados.lista("carros"):
		max_cv = maxf(max_cv, float(c["potencia"]))
		max_kg = maxf(max_kg, float(c["peso"]))
	barra("Potência", a["potencia"], max_cv * 1.4, "%d cv" % a["potencia"], COR_DESTAQUE, pai,
			antes.get("potencia", -1.0))
	barra("Peso", a["peso"], max_kg * 1.2, "%d kg" % a["peso"], COR_INFO, pai, antes.get("peso", -1.0), true)


func separador(pai: Control = null) -> void:
	_pai(pai).add_child(HSeparator.new())


func _pai(pai: Control) -> Control:
	return pai if pai != null else conteudo


# --- Compatibilidade com as telas antigas ----------------------------------

func titulo(t: String) -> Label:
	return rotulo(t, 36)


func texto(t: String, cor := Color.WHITE) -> Label:
	return rotulo(t, 0, cor)


## Linha com descrição à esquerda e botões à direita. botoes: [[rótulo, Callable, habilitado]].
## `icone` (placeholder de carro ou pista, ver Icones) vai antes do texto.
func linha(descricao: String, botoes: Array = [], icone: Control = null, pai: Control = null) -> HBoxContainer:
	var h := fileira(pai)
	if icone != null:
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(icone)
	if descricao != "":
		rotulo(descricao, 0, Color.WHITE, h)
	else:
		var espaco := Control.new()
		espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(espaco)
	for b in botoes:
		botao(b[0], b[1], b.size() <= 2 or b[2], b.size() > 3 and b[3], h)
	return h


# --- Placeholders e formatação ---------------------------------------------

func icone_carro(base: Dictionary) -> Control:
	return Icones.carro(base.get("categoria", ""), CarroBloco.cor_do_id(base.get("id", "")))


## Pistas montadas uma vez por id (o traçado não muda durante o jogo).
var _pistas_cache := {}


func icone_pista(pista_id: String) -> Control:
	if not _pistas_cache.has(pista_id):
		_pistas_cache[pista_id] = dados.pista(pista_id)
	return Icones.pista(_pistas_cache[pista_id])


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


const NOMES_CATEGORIA_CARRO := {"compacto": "Compacto", "seda": "Sedã", "cupe": "Cupê", "roadster": "Roadster"}
const NOMES_TRACAO := {
	"FF": "Dianteira (FF)", "FR": "Traseira (FR)", "MR": "Motor central (MR)",
	"RR": "Motor traseiro (RR)", "4WD": "Integral (4WD)",
}


## Selos de tração e categoria de um carro.
func selos_carro(base: Dictionary) -> Array:
	return [
		[NOMES_TRACAO.get(base["tracao"], base["tracao"]), COR_NEUTRA.lightened(0.3)],
		[NOMES_CATEGORIA_CARRO.get(base.get("categoria", ""), base.get("categoria", "")), COR_NEUTRA.lightened(0.3)],
	]


## Nome legível de uma pista a partir do id ("serra_alta" -> "Serra Alta").
static func nome_pista(id: String) -> String:
	var palavras := []
	for p in id.split("_"):
		palavras.append(p if p in ["do", "da", "das", "de", "dos"] else p.capitalize())
	return " ".join(palavras)
