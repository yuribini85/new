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
## Aviso curto no topo: confirmação (ok) ou motivo de uma falha.
signal aviso(texto: String, ok: bool)
## Painel modal com rolagem (Sobreposicao.abrir).
signal painel(titulo: String, montar: Callable, botoes: Array)

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
## Acima disto, o selo quebra linha em faixa própria.
const LIMITE_SELO := 26

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


## Reconstrói a tela mantendo a posição da lista (voltar não perde o lugar).
func atualizar() -> void:
	var posicao := scroll_vertical
	for c in conteudo.get_children():
		conteudo.remove_child(c)
		c.queue_free()
	construir()
	if posicao > 0:
		set_deferred("scroll_vertical", posicao)


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


## Painel com a ficha de um modelo: vitrine 3D, fabricante, números e como
## conseguir (novo, usado, prêmio de qual prova).
## Ficha do modelo: vitrine grande, números, comparação com o carro em uso,
## como conseguir e fabricante. `extras`: selos a mais ([[texto, cor]]);
## `compra`: [texto, Callable, habilitado] vira o botão principal do painel.
func ficha_modelo(base: Dictionary, extras: Array = [], compra: Array = []) -> void:
	var botoes := [] if compra.is_empty() or not compra[2] else [[compra[0], func():
		compra[1].call()
		mudou.emit()], ["Fechar", func(): pass]]
	painel.emit(base["nome"], func(v):
		var vit := VitrineCarro.new(320.0)
		vit.mostrar_modelo(base, CarroBloco.cor_do_id(base["id"]))
		v.add_child(vit)
		var fab: Dictionary = dados.item("fabricantes", base["fabricante"])
		rotulo("%s · %d · %s" % [fab.get("nome", ""), base["ano"], NOMES_CATEGORIA_CARRO.get(base.get("categoria", ""), "")],
				FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		numeros([["%d" % base["potencia"], "cv"], ["%d" % base["peso"], "kg"], [base["tracao"], "tração"]], v)
		var meu := carro_ativo()
		var comp := []
		if meu != null and meu.id != base["id"]:
			var a := meu.atributos_efetivos("seco")
			comp.append(["vs seu %s: %+d cv, %+d kg" % [meu.base["nome"], int(base["potencia"]) - roundi(a["potencia"]),
					int(base["peso"]) - roundi(a["peso"])], COR_INFO])
		selos(extras + comp, v)
		if not compra.is_empty() and not compra[2]:
			rotulo(compra[0], FONTE_PEQUENA + 2, COR_RUIM, v)
		var como := []
		if base.get("novo", true):
			como.append("novo no Mercado por %s Cr" % dinheiro(int(base["preco"])))
		if not base.get("usados", []).is_empty():
			como.append("usado em alguns períodos")
		for ev in dados.lista("eventos"):
			if ev.get("carro_premio") == base["id"]:
				como.append("prêmio da 1ª vitória em %s" % ev["nome"])
		if como.is_empty():
			como.append("ainda não disponível")
		var raro: bool = not base.get("novo", true) and base.get("usados", []).is_empty()
		var vc := cartao(COR_DESTAQUE if raro else Color.TRANSPARENT, v)
		rotulo("COMO CONSEGUIR" + (" · RARO" if raro else ""), FONTE_PEQUENA, COR_DESTAQUE if raro else COR_SECUNDARIA, vc)
		rotulo("; ".join(como).capitalize().left(1) + "; ".join(como).substr(1) + ".", FONTE_PEQUENA + 2, Color.WHITE, vc)
		rotulo("Revenda depois: %s Cr" % dinheiro(revenda(base)), FONTE_PEQUENA, COR_SECUNDARIA, vc)
		if not fab.is_empty():
			var vf := cartao(Color.TRANSPARENT, v)
			rotulo("%s · %s" % [fab.get("nome", ""), fab.get("pais", "")], 0, Color.WHITE, vf)
			rotulo(fab.get("historia", ""), FONTE_PEQUENA + 2, COR_SECUNDARIA, vf), botoes)


## Entrega de um carro novo: o carro girando e o próximo passo.
func entrega(carro: Carro) -> void:
	painel.emit("Seu novo carro", func(v):
		var vit := VitrineCarro.new(380.0)
		vit.mostrar_modelo(carro.base, CarroBloco.cor_do_carro(carro))
		v.add_child(vit)
		var n := rotulo(carro.base["nome"], 44, Color.WHITE, v)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var a := carro.atributos_efetivos("seco")
		numeros([["%d" % a["potencia"], "cv"], ["%d" % a["peso"], "kg"], [carro.base["tracao"], "tração"]], v),
		[["Ir para a garagem", func():
			jogador.carro_ativo = carro.uid
			ir_para.emit(GARAGEM)
			mudou.emit()], ["Continuar comprando", func(): pass]])


## Quanto a Loja paga por este modelo na venda (preço de tabela × fração).
func revenda(base: Dictionary) -> int:
	return int(floor(float(base["preco"]) * float(dados.economia()["fracao_revenda"])))


## Botão pequeno que abre o painel "Entenda os números" (glossário).
func entenda(pai: Control = null) -> void:
	var b := botao("Entenda os números", func():
		painel.emit("Entenda os números", func(v):
			for g in Objetivos.glossario(dados):
				var c := cartao(Color.TRANSPARENT, v)
				rotulo(g[0], 30, COR_DESTAQUE, c)
				rotulo(g[1], FONTE_PEQUENA + 3, Color.WHITE, c), []),
			true, false, pai)
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END


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


## Fileira de selos que quebra linha: selos = [[texto, cor], ...]. Textos
## longos viram uma faixa própria com quebra de linha, para nunca alargar a tela.
func selos(lista: Array, pai: Control = null) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	v.add_child(h)
	for s in lista:
		if String(s[0]).length() > LIMITE_SELO:
			var p := selo(s[0], s[1], v)
			var l: Label = p.get_child(0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			selo(s[0], s[1], h)
	_pai(pai).add_child(v)
	return v


## Avisa a tela principal (aviso no topo).
func avisar(t: String, ok := true) -> void:
	aviso.emit(t, ok)


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


## Fileira de botões que quebra linha quando não cabe (nunca alarga a tela).
## Os botões dentro dela se esticam para ocupar a linha.
func acoes(pai: Control = null) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 12)
	h.add_theme_constant_override("v_separation", 10)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.child_entered_tree.connect(func(n):
		if n is Button:
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	_pai(pai).add_child(h)
	return h


## Números grandes com a unidade embaixo: [[valor, unidade], ...].
func numeros(lista: Array, pai: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for n in lista:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", -6)
		var a := Label.new()
		a.text = n[0]
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.add_theme_font_size_override("font_size", 40)
		v.add_child(a)
		var b := Label.new()
		b.text = n[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
		b.add_theme_color_override("font_color", COR_SECUNDARIA)
		v.add_child(b)
		h.add_child(v)
	_pai(pai).add_child(h)
	return h


## Botão discreto, só texto (ação secundária).
func botao_texto(t: String, acao: Callable, pai: Control = null, habilitado := true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.disabled = not habilitado
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", FONTE_PEQUENA + 2)
	b.add_theme_color_override("font_color", COR_INFO.lightened(0.2))
	b.pressed.connect(func():
		acao.call()
		mudou.emit())
	_pai(pai).add_child(b)
	return b


## Commit publicado (versao.txt, gerado pelo workflow do Pages) ou "local".
static func versao() -> String:
	var v := FileAccess.get_file_as_string("res://versao.txt").strip_edges()
	return v if v != "" else "local"


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

## Foto do modelo (Estudio). `cor` vazia: pintura de fábrica.
func icone_carro(base: Dictionary, grande := false, cor := Color(0, 0, 0, 0)) -> Control:
	return Estudio.imagem(base, cor if cor.a > 0.0 else CarroBloco.cor_do_id(base.get("id", "")),
			Vector2(200, 110) if grande else Vector2(140, 78))


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
