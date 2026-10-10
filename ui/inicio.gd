extends Control
## Tela inicial: o logo com o carregamento de verdade (a cena principal, com as
## telas e a corrida 3D, carregada em segundo plano) e depois as opções:
## "Continuar" grande e "Novo jogo" pequeno embaixo, que pede confirmação
## porque apaga o progresso. Sem save, a opção grande é "Começar".

const PRINCIPAL := "res://scenes/principal.tscn"
## Composição (apresentação, não balanceamento): tempo mínimo do logo (s),
## posições em fração da altura e medidas em px da tela de 720.
const LOGO_MIN_S := 1.2
const TOPO_LOGO := 0.17
const ALTURA_LOGO := 198.0
const TOPO_ACOES := 0.44
const LARGURA_BOTAO := 460.0
const ALTURA_BOTAO := 96.0
## Ocre do botão principal um pouco menos saturado que o da interface.
static var OCRE := Color.from_hsv(Aba.COR_DESTAQUE.h, Aba.COR_DESTAQUE.s * 0.82, Aba.COR_DESTAQUE.v * 0.96)

var _barra: ProgressBar
var _opcoes: VBoxContainer
var _confirmacao: PanelContainer
var _t := 0.0
var _pronto := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color("1a2d49")  # o céu da paisagem, enquanto ela carrega
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	# Paisagem em camadas com parallax (logo, botões e versão ficam parados).
	add_child(PaisagemParallax.new())
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	_margens(ui)
	# Logo ~10% menor que antes, no terço de cima: a paisagem respira embaixo.
	var logo := TextureRect.new()
	logo.texture = Aba.arte("logo")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.0
	logo.anchor_right = 1.0
	logo.anchor_top = TOPO_LOGO
	logo.anchor_bottom = TOPO_LOGO
	logo.offset_bottom = ALTURA_LOGO
	ui.add_child(logo)
	# Ações mais abaixo, com mais ar entre elas e o logo; o pé fica livre.
	var acoes := VBoxContainer.new()
	acoes.anchor_left = 0.0
	acoes.anchor_right = 1.0
	acoes.anchor_top = TOPO_ACOES
	acoes.anchor_bottom = TOPO_ACOES
	acoes.add_theme_constant_override("separation", 0)
	ui.add_child(acoes)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(LARGURA_BOTAO, 10)
	_barra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_barra.show_percentage = false
	_barra.max_value = 1.0
	var sb_f := StyleBoxFlat.new()
	sb_f.bg_color = Color(1, 1, 1, 0.12)
	sb_f.set_corner_radius_all(5)
	var sb_c := StyleBoxFlat.new()
	sb_c.bg_color = OCRE
	sb_c.set_corner_radius_all(5)
	_barra.add_theme_stylebox_override("background", sb_f)
	_barra.add_theme_stylebox_override("fill", sb_c)
	acoes.add_child(_barra)
	_opcoes = VBoxContainer.new()
	_opcoes.add_theme_constant_override("separation", 14)
	_opcoes.modulate.a = 0.0
	_opcoes.visible = false
	acoes.add_child(_opcoes)
	_versao()
	ResourceLoader.load_threaded_request(PRINCIPAL)


## Versão no canto de baixo, discreta e parada (application/config/version).
func _versao() -> void:
	var v := String(ProjectSettings.get_setting("application/config/version", ""))
	if v == "":
		return
	var l := Label.new()
	l.text = "v" + v
	Tipografia.rotulo(l, "regular", 20)
	l.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84, 0.55))
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var base := AreaSegura.base(get_viewport_rect().size.x)
	l.offset_left = 20.0
	l.offset_bottom = -(20.0 + base)
	l.offset_top = l.offset_bottom - 28.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


## Margens laterais e áreas seguras do aparelho (entalhe, barra de gestos),
## medidas em relação à janela e convertidas para a escala da tela. Fora do
## celular a área segura é a do monitor e não conta.
func _margens(c: Control) -> void:
	var lateral := 56.0
	var cima := AreaSegura.topo(get_viewport_rect().size.x)
	var baixo := AreaSegura.base(get_viewport_rect().size.x)
	if OS.has_feature("mobile"):
		var seguro := Rect2(DisplayServer.get_display_safe_area())
		var janela := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		if janela.size.x > 0 and seguro.size.x > 0:
			var esc := get_viewport_rect().size.x / janela.size.x
			lateral = maxf(lateral, maxf(seguro.position.x - janela.position.x, janela.end.x - seguro.end.x) * esc)
	c.offset_left = lateral
	c.offset_right = -lateral
	c.offset_top = cima
	c.offset_bottom = -baixo


func _process(delta: float) -> void:
	if _pronto:
		return
	_t += delta
	var progresso := []
	var st := ResourceLoader.load_threaded_get_status(PRINCIPAL, progresso)
	if st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Inicio: falha ao carregar " + PRINCIPAL)
		_pronto = true
		return
	var p: float = 1.0 if st == ResourceLoader.THREAD_LOAD_LOADED else float(progresso[0]) if not progresso.is_empty() else 0.0
	_barra.value = maxf(_barra.value, p)
	if st == ResourceLoader.THREAD_LOAD_LOADED and _t >= LOGO_MIN_S:
		_pronto = true
		_mostrar_opcoes()


func _mostrar_opcoes() -> void:
	_barra.visible = false
	var sm := get_node("/root/SaveManager")
	var continuar := Button.new()
	Tipografia.acao_primaria(continuar, "Continuar" if sm.tinha_save else "Começar", OCRE, Color(0.1, 0.1, 0.1),
			46, ALTURA_BOTAO)
	# Mais sóbrio: largura contida e cantos menos arredondados.
	continuar.custom_minimum_size.x = LARGURA_BOTAO
	continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = (continuar.get_theme_stylebox(estado) as StyleBoxFlat).duplicate()
		sb.set_corner_radius_all(4)
		continuar.add_theme_stylebox_override(estado, sb)
	continuar.pressed.connect(_entrar)
	_opcoes.add_child(continuar)
	if sm.tinha_save:
		var novo := Button.new()
		Tipografia.acao_secundaria(novo, "Novo jogo", Color(0.95, 0.93, 0.89), 30, 88)
		novo.custom_minimum_size.x = LARGURA_BOTAO
		novo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Contraste sobre a paisagem sem caixa: uma sombra curta no texto.
		novo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		novo.add_theme_constant_override("shadow_offset_y", 2)
		novo.pressed.connect(_confirmar_novo)
		_opcoes.add_child(novo)
	_opcoes.visible = true
	create_tween().tween_property(_opcoes, "modulate:a", 1.0, 0.4)


func _confirmar_novo() -> void:
	if _confirmacao != null:
		return
	_confirmacao = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09)
	sb.border_color = Aba.COR_RUIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	_confirmacao.add_theme_stylebox_override("panel", sb)
	_confirmacao.custom_minimum_size = Vector2(600, 0)
	# O menu some atrás do aviso: a decisão fica sozinha na tela.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.72)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(escuro)
	centro.tree_exited.connect(escuro.queue_free)
	add_child(centro)
	centro.add_child(_confirmacao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_confirmacao.add_child(v)
	var t := Label.new()
	t.text = "Começar um novo jogo?"
	t.add_theme_font_override("font", Tipografia.fonte("semibold"))
	t.add_theme_font_size_override("font_size", 40)
	v.add_child(t)
	var d := Label.new()
	d.text = "Isso apaga o progresso salvo neste aparelho: carros, dinheiro, licenças, vitórias e a história. Não dá para desfazer."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 26)
	d.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	v.add_child(d)
	var apagar := Button.new()
	# Vermelho mais fundo que o COR_RUIM: o branco precisa de contraste.
	Tipografia.acao_primaria(apagar, "Apagar e começar", Aba.COR_RUIM.darkened(0.35), Color.WHITE,
			Tipografia.TAMANHO_SECUNDARIA + 4, Tipografia.ALTURA_SECUNDARIA)
	apagar.pressed.connect(func():
		get_node("/root/SaveManager").novo_jogo()
		_entrar())
	v.add_child(apagar)
	var cancelar := Button.new()
	Tipografia.acao_secundaria(cancelar, "Cancelar")
	cancelar.pressed.connect(func():
		centro.queue_free()
		_confirmacao = null)
	v.add_child(cancelar)


func _entrar() -> void:
	var cena: PackedScene = ResourceLoader.load_threaded_get(PRINCIPAL)
	get_tree().change_scene_to_packed(cena)

