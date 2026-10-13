class_name NomeAdmin
extends Control
## Nome do administrador (decisão 73): o painel que vem depois de a Mara
## perguntar "como devo chamar você?". Só o nome (sem rosto nem passado); não
## fecha sem um nome. Fica no alto da tela, longe do teclado do celular.

signal confirmado(nome: String)

const NOME_MAX := 20

var _campo: LineEdit
var _ok: Button


func _init(atual := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.09, 0.09, 0.1, 0.96)
	estilo.border_color = Aba.COR_DESTAQUE
	estilo.border_width_left = 4
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(28)
	cartao.add_theme_stylebox_override("panel", estilo)
	cartao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cartao.offset_left = -310
	cartao.offset_right = 310
	cartao.offset_top = 220
	cartao.grow_vertical = Control.GROW_DIRECTION_END
	add_child(cartao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	cartao.add_child(v)
	var titulo := Label.new()
	titulo.text = "COMO VOCÊ SE CHAMA?"
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(titulo, "semibold", 24)
	titulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(titulo)
	_campo = LineEdit.new()
	_campo.text = atual
	_campo.placeholder_text = "Seu nome"
	_campo.max_length = NOME_MAX
	_campo.custom_minimum_size.y = 72
	_campo.add_theme_font_size_override("font_size", 30)
	_campo.text_changed.connect(func(_t): _atualizar())
	_campo.text_submitted.connect(func(_t): _confirmar())
	v.add_child(_campo)
	_ok = Button.new()
	Tipografia.acao_primaria(_ok, "Confirmar", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, 72)
	_ok.pressed.connect(_confirmar)
	v.add_child(_ok)
	_atualizar()


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_campo.grab_focus()


func nome() -> String:
	return _campo.text.strip_edges()


func _atualizar() -> void:
	_ok.disabled = nome() == ""


func _confirmar() -> void:
	if nome() == "":
		return
	confirmado.emit(nome())
	queue_free()
