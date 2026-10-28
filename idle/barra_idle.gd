class_name BarraIdle
extends Control
## Menu de baixo do The Fastfather (docs/idle/plano.md): uma aba por tela,
## ícone grande e nome curto. A aba ativa sobe em ocre com um brilho e a faixa
## quadriculada de bandeirada embaixo; um ponto vermelho avisa que há o que
## fazer ali (contrato pronto, liga nova aberta). Só desenho e toque.

signal escolheu(id: String)

const ALTURA := 112.0
const ICONE := 48
const ICONE_ATIVO := 58
const COR_FAIXA := Color("141819")
const COR_TEXTO := IdleUI.COR_ACO_CLARO
const FUNDO := IdleUI.COR_CARVAO  # o da faixa do alto

var abas: Array = []  # [{id, nome, icone}]
var ativa := ""
var avisos := {}  # id -> true: ponto vermelho
var _t_troca := 0.0
var _texturas := {}


func _init(abas_: Array) -> void:
	custom_minimum_size = Vector2(0, ALTURA + AreaSegura.base(720.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	definir_abas(abas_)


## Troca as abas (o menu cresce conforme o jogo abre telas novas).
func definir_abas(abas_: Array) -> void:
	abas = abas_
	if abas.filter(func(a): return String(a["id"]) == ativa).is_empty():
		ativa = String(abas[0]["id"]) if not abas.is_empty() else ""
	for a in abas:
		if not _texturas.has(a["icone"]):
			# Os ícones do HUD da arte do usuário; sem eles, os antigos de arte/ui.
			var hud := IdleUI.icone_hud(String(a["icone"]))
			_texturas[a["icone"]] = hud if hud != null else Aba.icone_reduzido(String(a["icone"]), ICONE_ATIVO)
	queue_redraw()


func escolher(id: String) -> void:
	if id == ativa:
		return
	ativa = id
	_t_troca = 0.0
	set_process(true)
	queue_redraw()


func avisar(id: String, ligado: bool) -> void:
	if bool(avisos.get(id, false)) != ligado:
		avisos[id] = ligado
		set_process(true)
		queue_redraw()


func _process(delta: float) -> void:
	_t_troca += delta
	queue_redraw()
	if _t_troca > 0.3 and avisos.values().count(true) == 0:
		set_process(false)


## Retângulo global da aba `id` (o tutorial leve aponta para ela); vazio se não há.
func retangulo_aba(id: String) -> Rect2:
	for i in abas.size():
		if String(abas[i]["id"]) == id:
			var w := size.x / abas.size()
			return Rect2(get_global_rect().position + Vector2(i * w, 0), Vector2(w, ALTURA))
	return Rect2()


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque or abas.is_empty():
		return
	var i := clampi(int(e.position.x / (size.x / abas.size())), 0, abas.size() - 1)
	var id := String(abas[i]["id"])
	escolher(id)
	escolheu.emit(id)
	accept_event()


func _draw() -> void:
	# O mesmo fundo da faixa do alto (layout do usuário, 2026-10-27), com o
	# filete fino de latão em cima.
	draw_rect(Rect2(Vector2.ZERO, size), FUNDO)
	draw_rect(Rect2(0, 0, size.x, 1), IdleUI.COR_BORDA)
	if abas.is_empty():
		return
	var w := size.x / abas.size()
	var f := Tipografia.fonte("semibold")
	var entrada := clampf(_t_troca / 0.25, 0.0, 1.0)
	for i in abas.size():
		var a: Dictionary = abas[i]
		var x0 := i * w
		var ativo := String(a["id"]) == ativa
		var centro := Vector2(x0 + w * 0.5, 44.0)
		if ativo:
			# Só um traço dourado no pé da aba (sem fundo atrás do ícone).
			var tw := (w - 48.0) * entrada
			draw_rect(Rect2(x0 + (w - tw) * 0.5, ALTURA - 8.0, tw, 4.0), IdleUI.COR_OURO)
		var tex: Texture2D = _texturas.get(a["icone"])
		if tex != null:
			var lado := lerpf(ICONE, ICONE_ATIVO, entrada) if ativo else float(ICONE)
			var cor := Color.WHITE if ativo else Color(0.62, 0.62, 0.62, 0.8)  # apagado, sem perder a cor
			draw_texture_rect(tex, Rect2(centro - Vector2(lado, lado) * 0.5 - Vector2(0, 4.0 * entrada if ativo else 0.0),
					Vector2(lado, lado)), false, cor)
		var nome := String(a["nome"])
		var tam := IdleUI.legivel(20)
		var largura := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(f, Vector2(x0 + (w - largura) * 0.5, 92.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
				IdleUI.COR_OURO if ativo else COR_TEXTO)
		if avisos.get(a["id"], false):
			var pulso := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.2)
			draw_circle(centro + Vector2(26, -22), 9.0, Color(IdleUI.COR_RUIM, pulso))
			draw_arc(centro + Vector2(26, -22), 9.0, 0, TAU, 20, Color(0, 0, 0, 0.6), 2.0)
