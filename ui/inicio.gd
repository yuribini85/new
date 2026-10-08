extends Control
## Tela inicial: o logo com o carregamento de verdade (a cena principal, com as
## telas e a corrida 3D, carregada em segundo plano) e depois as opções:
## "Continuar" grande e "Novo jogo" pequeno embaixo, que pede confirmação
## porque apaga o progresso. Sem save, a opção grande é "Começar".

const PRINCIPAL := "res://scenes/principal.tscn"
## Tempo mínimo do logo na tela (s): apresentação, não balanceamento.
const LOGO_MIN_S := 1.2

var _barra: ProgressBar
var _opcoes: VBoxContainer
var _confirmacao: PanelContainer
var _t := 0.0
var _pronto := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Aba.COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var arte := Aba.arte("fundo_garagem")
	if arte != null:
		var img := TextureRect.new()
		img.texture = arte
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.modulate = Color(0.35, 0.35, 0.38)
		add_child(img)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 48
	v.offset_right = -48
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 40)
	add_child(v)
	var logo := TextureRect.new()
	logo.texture = Aba.arte("logo")
	logo.custom_minimum_size = Vector2(0, 220)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(logo)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(0, 12)
	_barra.show_percentage = false
	_barra.max_value = 1.0
	var sb_f := StyleBoxFlat.new()
	sb_f.bg_color = Color(1, 1, 1, 0.08)
	sb_f.set_corner_radius_all(6)
	var sb_c := StyleBoxFlat.new()
	sb_c.bg_color = Aba.COR_DESTAQUE
	sb_c.set_corner_radius_all(6)
	_barra.add_theme_stylebox_override("background", sb_f)
	_barra.add_theme_stylebox_override("fill", sb_c)
	v.add_child(_barra)
	_opcoes = VBoxContainer.new()
	_opcoes.add_theme_constant_override("separation", 18)
	_opcoes.modulate.a = 0.0
	_opcoes.visible = false
	v.add_child(_opcoes)
	ResourceLoader.load_threaded_request(PRINCIPAL)


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
	continuar.text = "Continuar" if sm.tinha_save else "Começar"
	continuar.custom_minimum_size = Vector2(0, 128)
	continuar.add_theme_font_size_override("font_size", 46)
	_estilo(continuar, Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1))
	continuar.pressed.connect(_entrar)
	_opcoes.add_child(continuar)
	if sm.tinha_save:
		var novo := Button.new()
		novo.text = "Novo jogo"
		novo.flat = true
		novo.custom_minimum_size = Vector2(0, 64)
		novo.add_theme_font_size_override("font_size", 26)
		novo.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
		novo.pressed.connect(_confirmar_novo)
		_opcoes.add_child(novo)
	_opcoes.visible = true
	create_tween().tween_property(_opcoes, "modulate:a", 1.0, 0.4)


func _confirmar_novo() -> void:
	if _confirmacao != null:
		return
	_confirmacao = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	sb.border_color = Aba.COR_RUIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	_confirmacao.add_theme_stylebox_override("panel", sb)
	_confirmacao.custom_minimum_size = Vector2(600, 0)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	centro.add_child(_confirmacao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_confirmacao.add_child(v)
	var t := Label.new()
	t.text = "Começar um novo jogo?"
	t.add_theme_font_size_override("font_size", 34)
	v.add_child(t)
	var d := Label.new()
	d.text = "Isso apaga o progresso salvo neste aparelho: carros, dinheiro, licenças, vitórias e a história. Não dá para desfazer."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 26)
	d.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	v.add_child(d)
	var apagar := Button.new()
	apagar.text = "Apagar e começar"
	apagar.custom_minimum_size = Vector2(0, 88)
	apagar.add_theme_font_size_override("font_size", 30)
	_estilo(apagar, Aba.COR_RUIM, Color.WHITE)
	apagar.pressed.connect(func():
		get_node("/root/SaveManager").novo_jogo()
		_entrar())
	v.add_child(apagar)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.flat = true
	cancelar.custom_minimum_size = Vector2(0, 64)
	cancelar.add_theme_font_size_override("font_size", 26)
	cancelar.pressed.connect(func():
		centro.queue_free()
		_confirmacao = null)
	v.add_child(cancelar)


func _entrar() -> void:
	var cena: PackedScene = ResourceLoader.load_threaded_get(PRINCIPAL)
	get_tree().change_scene_to_packed(cena)


static func _estilo(b: Button, fundo: Color, texto: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.set_corner_radius_all(16)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, texto)
