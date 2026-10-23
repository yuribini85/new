extends Control
## Tela inicial: o logo com o carregamento de verdade (a cena principal, com as
## telas e a corrida 3D, carregada em segundo plano) e depois as opções:
## "Continuar" grande e "Novo jogo" pequeno embaixo (BotaoInicio), que pede confirmação
## porque apaga o progresso. Sem save, a opção grande é "Começar". Abaixo, o
## "Teste completo" (Cenarios: tudo liberado, num save próprio; o seu jogo não
## muda e volta pelas Configurações).

const PRINCIPAL := "res://scenes/principal.tscn"
## Composição (apresentação, não balanceamento): tempo mínimo do logo (s),
## posições em fração da altura e medidas em px da tela de 720.
const LOGO_MIN_S := 1.2
const TOPO_LOGO := 0.17
const ALTURA_LOGO := 198.0
const TOPO_ACOES := 0.44
const LARGURA_BOTAO := 470.0
const ALTURA_BOTAO := 104.0
const LARGURA_SECUNDARIO := 360.0
const ALTURA_SECUNDARIO := 76.0
## Ocre do botão principal um pouco menos saturado que o da interface.
## Amarelo-ouro do botão principal (referência da tela inicial).
const COR_PRINCIPAL := Color("f5b52e")
static var OCRE := Color.from_hsv(Aba.COR_DESTAQUE.h, Aba.COR_DESTAQUE.s * 0.82, Aba.COR_DESTAQUE.v * 0.96)

var _barra: ProgressBar
var _opcoes: VBoxContainer
var _confirmacao: PanelContainer
var _t := 0.0
var _pronto := false


func _ready() -> void:
	# O segundo app do projeto (Chrome Racing Team, docs/idle/plano.md) abre direto no jogo idle.
	if OS.has_feature("idle"):
		get_tree().change_scene_to_file.call_deferred("res://idle/idle.tscn")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color("1b222c")  # o céu da paisagem, enquanto ela carrega
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
	var continuar := BotaoInicio.new("Continuar" if sm.tinha_save else "Começar", true, COR_PRINCIPAL, 56, ALTURA_BOTAO,
			LARGURA_BOTAO)
	continuar.pressed.connect(_entrar)
	_opcoes.add_child(continuar)
	if sm.tinha_save or Preferencias.ferramentas_teste():
		# Linha fina separa a ação principal das outras.
		var sep := ColorRect.new()
		sep.color = Color(0.85, 0.88, 0.94, 0.5)
		sep.custom_minimum_size = Vector2(LARGURA_BOTAO * 1.05, 2)
		sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var caixa := MarginContainer.new()
		caixa.add_theme_constant_override("margin_top", 14)
		caixa.add_theme_constant_override("margin_bottom", 6)
		caixa.add_child(sep)
		_opcoes.add_child(caixa)
	if sm.tinha_save:
		var novo := BotaoInicio.new("Novo jogo", false, Color.WHITE, 36, ALTURA_SECUNDARIO, LARGURA_SECUNDARIO)
		novo.pressed.connect(_confirmar_novo)
		_opcoes.add_child(novo)
	if Preferencias.ferramentas_teste():
		var teste := BotaoInicio.new("Teste completo", false, Color.WHITE, 34, ALTURA_SECUNDARIO, LARGURA_SECUNDARIO)
		teste.add_theme_color_override("font_color", Color(0.75, 0.87, 0.98))
		teste.pressed.connect(_entrar_teste)
		_opcoes.add_child(teste)
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
	d.text = "Isso apaga o progresso salvo neste aparelho: carros, giros, licenças, vitórias e a história. Não dá para desfazer."
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


## Tudo liberado (Cenarios "completo"), num save próprio, e entra no jogo.
func _entrar_teste() -> void:
	var erro: String = get_node("/root/SaveManager").usar_cenario("completo")
	if erro != "":
		push_error("teste completo: " + erro)
		return
	_entrar()


func _entrar() -> void:
	var cena: PackedScene = ResourceLoader.load_threaded_get(PRINCIPAL)
	get_tree().change_scene_to_packed(cena)

