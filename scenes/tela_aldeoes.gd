extends CanvasLayer
## Tela de aldeões. especificacao_tecnica_v1.md #37: lista com filtro por estado,
## toque abre um seletor de destino — simplificado aqui para alocar na primeira
## vaga livre (o seletor manual completo é trabalho do módulo de Interface).

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
		_alocar_em_qualquer_vaga(id)
	elif o.estado == Orfao.Estado.ALOCADO:
		Populacao.desalocar(id)
	_atualizar()


func _alocar_em_qualquer_vaga(orfao_id: String) -> void:
	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		if e.vagas_orfaos.find("") != -1 or e.vagas_orfaos.find(null) != -1:
			if Populacao.alocar(orfao_id, id):
				return
