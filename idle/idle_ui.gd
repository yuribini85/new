class_name IdleUI
extends RefCounted
## Peças de interface do Chrome Racing Team (docs/idle/plano.md), com a
## identidade do Chrome & Wreckage: cores da interface (Aba), fontes
## (Tipografia) e a arte de res://arte/ui/.

const COR_FUNDO := Aba.COR_FUNDO
const COR_CARTAO := Aba.COR_CARTAO
const COR_CARTAO_CLARO := Color(0.16, 0.18, 0.21)
const COR_DINHEIRO := Color(0.45, 0.9, 0.5)
const COR_OURO := Aba.COR_DESTAQUE
const COR_SECUNDARIA := Aba.COR_SECUNDARIA
const COR_BLOQUEADO := Color(0.42, 0.44, 0.5)
const COR_RUIM := Aba.COR_RUIM
const COR_BOTAO := Color("f5b52e")  # o amarelo-ouro do botão da tela inicial do C&W (ui/inicio.gd)


static func rotulo(texto: String, tamanho: int, cor: Color, pai: Node = null, peso := "semibold") -> Label:
	var l := Label.new()
	l.text = texto
	Tipografia.rotulo(l, peso, tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(l)
	return l


static func caixa(cor: Color, raio: int, margem := 12, borda := Color.TRANSPARENT, largura_borda := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(margem)
	if largura_borda > 0:
		sb.border_color = borda
		sb.set_border_width_all(largura_borda)
	return sb


static func painel(cor := COR_CARTAO, raio := 14, margem := 12, pai: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", caixa(cor, raio, margem))
	if pai != null:
		pai.add_child(p)
	return p


static func icone(nome: String, tamanho: int, pai: Node = null, cor := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Aba.icone_reduzido(nome, tamanho)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(tamanho, tamanho)
	t.modulate = cor
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(t)
	return t


## Imagem que cobre a área sem esticar (escala uniforme, corta as bordas).
static func imagem_cobrindo(tex: Texture2D, altura: float, pai: Node = null, escurecer := 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(0, altura)
	t.clip_contents = true
	t.modulate = Color(escurecer, escurecer, escurecer)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(t)
	return t


static func botao(texto: String, cor: Color, tamanho := 24, altura := 64, pai: Node = null) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, texto, cor, Color(0.07, 0.07, 0.06), tamanho, altura)
	if pai != null:
		pai.add_child(b)
	return b


## Banner da pista (arte/ui/banner_*), com o tema da pista longa quando a
## curta não tem o dela.
static func banner_pista(pista_id: String) -> Texture2D:
	var tex := Aba.arte("banner_" + String(Corrida3D.TEMA_DE.get(pista_id, pista_id)))
	if tex == null:
		tex = Aba.arte("banner_arena_" + pista_id)
	return tex if tex != null else Aba.arte("fundo_competicoes")


static func retrato_piloto(id: String) -> Texture2D:
	var caminho := "res://arte/pilotos/%s.webp" % id
	return load(caminho) if ResourceLoader.exists(caminho) else null


## 1234 -> "1,2 mil"; 3 400 000 -> "3,4 mi" (o jogador lê rápido).
static func curto(v: float) -> String:
	var sufixos := ["", " mil", " mi", " bi", " tri", " qua", " qui", " sx"]
	var k := 0
	while absf(v) >= 1000.0 and k < sufixos.size() - 1:
		v /= 1000.0
		k += 1
	if k == 0:
		return ("%.1f" % v).replace(".", ",").trim_suffix(",0") if absf(v) < 10.0 else str(int(v))
	return ("%.1f" % v).replace(".", ",") + sufixos[k]


## "3:12:05" / "12:05".
static func relogio(s: float) -> String:
	var t := maxi(ceili(s), 0)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60] if t >= 3600 else "%d:%02d" % [t / 60, t % 60]
