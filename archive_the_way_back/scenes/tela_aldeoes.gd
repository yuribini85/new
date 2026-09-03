extends CanvasLayer
## Tela de aldeões. especificacao_tecnica_v1.md #37: lista com filtro por estado,
## toque abre um seletor de destino com todos os prédios com vaga livre.

enum Filtro { TODOS, OCIOSOS, ALOCADOS, CRIANCAS }
var _filtro := Filtro.TODOS

@onready var _titulo: Label = $Painel/VBox/Titulo
@onready var _filtros_box: HBoxContainer = $Painel/VBox/Filtros
@onready var _lista: VBoxContainer = $Painel/VBox/Scroll/Lista

const NOMES_ESTADO := {
	Orfao.Estado.CRIANCA: "criança",
	Orfao.Estado.ADULTO_OCIOSO: "ocioso",
	Orfao.Estado.ALOCADO: "alocado",
	Orfao.Estado.EM_EXPEDICAO: "expedição",
	Orfao.Estado.MORTO: "morto",
}


func _ready() -> void:
	for texto in ["Todos", "Ociosos", "Alocados", "Crianças"]:
		var b := Button.new()
		b.text = texto
		b.pressed.connect(_on_filtro_pressed.bind(texto))
		_filtros_box.add_child(b)

	Populacao.orfao_chegou.connect(func(_id): _atualizar())
	Populacao.orfao_virou_adulto.connect(func(_id): _atualizar())
	Populacao.orfao_alocado.connect(func(_id, _e): _atualizar())
	Populacao.orfao_desalocado.connect(func(_id): _atualizar())
	_atualizar()


func _on_filtro_pressed(texto: String) -> void:
	_filtro = { "Todos": Filtro.TODOS, "Ociosos": Filtro.OCIOSOS, "Alocados": Filtro.ALOCADOS, "Crianças": Filtro.CRIANCAS }[texto]
	_atualizar()


func _atualizar() -> void:
	for c in _lista.get_children():
		c.queue_free()

	var itens: Array = []
	for id in Populacao.orfaos:
		var o: Orfao = Populacao.orfaos[id]
		if _passa_filtro(o):
			itens.append(o)

	_titulo.text = "Aldeões (%d)" % itens.size()
	for o in itens:
		_lista.add_child(_criar_linha(o))


func _passa_filtro(o: Orfao) -> bool:
	match _filtro:
		Filtro.OCIOSOS:
			return o.estado == Orfao.Estado.ADULTO_OCIOSO
		Filtro.ALOCADOS:
			return o.estado == Orfao.Estado.ALOCADO
		Filtro.CRIANCAS:
			return o.estado == Orfao.Estado.CRIANCA
		_:
			return true


func _criar_linha(o: Orfao) -> Button:
	var cicatriz_texto := "—"
	if o.cicatriz_id != "":
		cicatriz_texto = o.cicatriz_id if o.cicatriz_visivel else "??"

	var local := " (%s)" % o.local_id if o.estado == Orfao.Estado.ALOCADO else ""
	var linha := Button.new()
	linha.text = "%s · %s%s · apt %s · cicatriz %s" % [
		o.nome, NOMES_ESTADO[o.estado], local, o.aptidao, cicatriz_texto,
	]
	linha.pressed.connect(_on_linha_pressed.bind(o.id))
	return linha


func _on_linha_pressed(id: String) -> void:
	var o: Orfao = Populacao.orfaos[id]
	if o.estado == Orfao.Estado.ADULTO_OCIOSO:
		_abrir_seletor_destino(id)
	elif o.estado == Orfao.Estado.ALOCADO:
		Populacao.desalocar(id)
		_atualizar()


func _vagas_livres(e: Edificio) -> int:
	var n := 0
	for v in e.vagas_orfaos:
		if v == null or v == "":
			n += 1
	return n


## Lista todo prédio construído com vaga livre, pra escolher onde o aldeão vai
## trabalhar — ex.: escolher a Cabana do Construtor de propósito pra acelerar obras,
## em vez de cair sempre no primeiro prédio com vaga (especificacao_tecnica_v1.md #37).
func _abrir_seletor_destino(orfao_id: String) -> void:
	var o: Orfao = Populacao.orfaos[orfao_id]
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.75)
	fundo.anchor_right = 1.0
	fundo.anchor_bottom = 1.0
	add_child(fundo)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 60.0
	vbox.offset_top = 60.0
	vbox.offset_right = -60.0
	vbox.offset_bottom = -60.0
	fundo.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "Alocar %s em:" % o.nome
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9, 1))
	vbox.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	var encontrou_vaga := false
	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		if e.nivel <= 0:
			continue
		var livres := _vagas_livres(e)
		if livres <= 0:
			continue
		encontrou_vaga = true
		var combina := Populacao.aptidao_do_edificio(id) == o.aptidao and o.aptidao != ""
		var botao := Button.new()
		botao.text = "%s%s — %d vaga(s) livre(s)" % [("★ " if combina else ""), e.nome, livres]
		botao.pressed.connect(func():
			Populacao.alocar(orfao_id, id)
			fundo.queue_free()
			_atualizar()
		)
		lista.add_child(botao)

	if not encontrou_vaga:
		var aviso := Label.new()
		aviso.text = "Nenhum prédio com vaga livre no momento."
		aviso.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6, 1))
		lista.add_child(aviso)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): fundo.queue_free())
	vbox.add_child(cancelar)
