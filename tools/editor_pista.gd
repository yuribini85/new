extends Control
## Visualizador das pistas de data/pistas.json (ou da pasta de --dados=).
## O traçado é derivado dos trechos, igual à simulação; aqui se confere se a
## volta fecha e onde estão as zonas de ultrapassagem antes de editar o JSON.
## Abrir: godot res://tools/editor_pista.tscn [-- --dados=res://tests/fixtures/]

const CORES := {
	"reta": Color(0.6, 0.6, 0.65), "curva_lenta": Color(0.95, 0.4, 0.35),
	"curva_media": Color(0.95, 0.7, 0.3), "curva_rapida": Color(0.5, 0.85, 0.4),
	"frenagem": Color(0.9, 0.3, 0.8), "aceleracao": Color(0.3, 0.7, 0.95),
}

var _pistas: Array = []
var _pista: Pista
var _info: Label
var _escolha: OptionButton
var _iso := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dados := get_node("/root/Dados")
	_pistas = dados.lista("pistas")
	var topo := HBoxContainer.new()
	add_child(topo)
	_escolha = OptionButton.new()
	for p in _pistas:
		_escolha.add_item(p["id"])
	_escolha.item_selected.connect(_selecionar)
	topo.add_child(_escolha)
	var iso := CheckButton.new()
	iso.text = "Isométrico"
	iso.toggled.connect(func(v): _iso = v; queue_redraw())
	topo.add_child(iso)
	_info = Label.new()
	_info.position = Vector2(8, 48)
	add_child(_info)
	if _pistas.is_empty():
		_info.text = "Nenhuma pista em %spistas.json" % dados.pasta
	else:
		_selecionar(0)


func _selecionar(i: int) -> void:
	_escolha.select(i)
	_pista = Pista.new(_pistas[i])
	var linhas := ["%s · %s · %.1f m" % [_pista.id, _pista.funcao, _pista.comprimento]]
	linhas.append("Fechamento: %.2f m · rumo %.2f°  %s" % [_pista.erro_fechamento(), rad_to_deg(_pista.erro_rumo()),
		"OK" if _pista.erro_fechamento() <= 1.0 and _pista.erro_rumo() <= 0.01 else "NÃO FECHA"])
	for k in _pista.trechos.size():
		var t: Dictionary = _pista.trechos[k]
		linhas.append("%d. %s %.1f m%s%s" % [k, t["tipo"], t["comprimento_m"],
			" r=%.0f %s" % [t["raio_m"], t.get("sentido", "esquerda")] if float(t.get("raio_m", 0)) > 0 else "",
			" · ultrapassagem" if t.get("ultrapassagem", false) else ""])
	_info.text = "\n".join(linhas)
	queue_redraw()


func _draw() -> void:
	if _pista == null:
		return
	var area := Rect2(Vector2(0, size.y * 0.35), Vector2(size.x, size.y * 0.65)).grow(-24)
	var pts := []
	for k in _pista.trechos.size():
		var seg := PackedVector2Array()
		var ini: float = _pista.inicios[k]
		var fim: float = ini + float(_pista.trechos[k]["comprimento_m"])
		var n := maxi(int((fim - ini) / 2.0), 1)
		for j in n + 1:
			seg.append(_proj(_pista.posicao_em(lerpf(ini, fim, float(j) / n) - (0.001 if j == n else 0.0))))
		pts.append(seg)
	var caixa := Rect2(pts[0][0], Vector2.ZERO)
	for seg in pts:
		for p in seg:
			caixa = caixa.expand(p)
	var escala := minf(area.size.x / maxf(caixa.size.x, 1.0), area.size.y / maxf(caixa.size.y, 1.0))
	var desloc := area.get_center() - caixa.get_center() * escala
	for k in pts.size():
		var t: Dictionary = _pista.trechos[k]
		var tela := PackedVector2Array()
		for p in pts[k]:
			tela.append(desloc + p * escala)
		var largura := 10.0 if t.get("ultrapassagem", false) else 5.0
		draw_polyline(tela, CORES.get(t["tipo"], Color.WHITE), largura, true)
		draw_string(get_theme_default_font(), tela[tela.size() / 2] + Vector2(6, -6), str(k))
	var fim_volta := desloc + _proj(_pista.posicao_em(_pista.comprimento - 0.001)) * escala
	draw_circle(desloc + _proj(_pista.posicao_em(0.0)) * escala, 7.0, Color.WHITE)
	draw_circle(fim_volta, 4.0, Color.RED)


func _proj(p: Vector2) -> Vector2:
	# Tela tem y para baixo; o plano da pista, y para cima.
	return Iso.para_tela(p, 1.0) if _iso else Vector2(p.x, -p.y)
