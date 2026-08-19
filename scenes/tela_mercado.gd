extends CanvasLayer
## Venda de recursos. design/economia.md regra 1: "Ouro só entra por venda."
## Só madeira por enquanto — preço de comida é por sub-bem (vegetais/carne/pão) e o
## estoque de comida é unificado (módulo 4), então vender comida fica pendente até
## essa modelagem ser resolvida, em vez de estimar um preço.

@onready var _lista: VBoxContainer = $Painel/VBox/Scroll/Lista
@onready var _titulo: Label = $Painel/VBox/Titulo

const RECURSOS_VENDAVEIS := ["madeira"]


func _ready() -> void:
	Economia.recurso_mudou.connect(func(_r, _v): _atualizar())
	_titulo.text = "Mercado"
	_atualizar()


func _atualizar() -> void:
	for c in _lista.get_children():
		c.queue_free()

	var precos: Dictionary = Dados.economia().get("precos_venda", {})
	for recurso in RECURSOS_VENDAVEIS:
		var estoque := int(Economia.recursos.get(recurso, 0.0))
		var preco: float = precos.get(recurso, 0.0)

		var linha := HBoxContainer.new()
		var info := Label.new()
		info.text = "%s: %d (preço %d ouro/un)" % [recurso, estoque, preco]
		linha.add_child(info)

		var botao := Button.new()
		botao.text = "Vender tudo"
		botao.disabled = estoque <= 0
		botao.pressed.connect(_on_vender_pressed.bind(recurso, estoque))
		linha.add_child(botao)

		_lista.add_child(linha)


func _on_vender_pressed(recurso: String, quantidade: int) -> void:
	Economia.vender(recurso, quantidade)
