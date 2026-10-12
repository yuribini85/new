class_name HudArena
extends Control
## Painel da arena: por equipe, o nome dela (com a posição quando cai) e, embaixo,
## uma linha por carro com o piloto, o modelo e o carro visto de cima em
## seis regiões (frente, lados, traseira; esquerda e direita), cada uma na cor
## do dano. Cores como o indicador do estudo: verde → amarelo até a metade,
## amarelo → vermelho até o limite da ré, piscando daí até quebrar; preto no
## eliminado. O fundo da linha enche de vermelho com o pior dano (cheio = eliminado).

const LINHA := 46.0
const LARGURA := 280.0
const EQUIPE := 32.0  # altura da linha do nome da equipe
const CARRO := Vector2(30.0, 40.0)  # o carro de pé: frente para cima
## Com muitos carros (lutas de 15), as linhas encolhem para caber na tela.
const MUITOS := 6
const ESCALA_COMPACTA := 0.62
const VERDE := Color(0.3, 0.8, 0.35)
const AMARELO := Color(0.95, 0.8, 0.2)
const VERMELHO := Color(0.92, 0.2, 0.15)
const ALERTA := Color(1.0, 0.95, 0.85)
const FUNDO := Color(0.05, 0.05, 0.06, 0.72)
const FUNDO_DANO := Color(0.62, 0.08, 0.06, 0.62)

## [{tipo: "equipe", nome, cor, posicao (0 = de pé), eliminado, voce} ou
##  {id, nome, carro, cor, dano: PackedFloat32Array(6), eliminado, voce}]
var linhas: Array = []:
	set(v):
		linhas = v
		queue_redraw()
var limite_re := 0.9
## Recolhida (toque no cabeçalho): só o cabeçalho e a sua linha, para ver a luta.
var recolhida := false
const CABECALHO := 34.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque and e.position.y <= CABECALHO:
		recolhida = not recolhida
		queue_redraw()
		accept_event()


func _process(_d: float) -> void:
	if linhas.any(func(l): return l.has("dano") and not l["eliminado"] and _pior(l["dano"]) >= limite_re):
		queue_redraw()  # pisca


func _draw() -> void:
	var fonte := Tipografia.fonte("semibold")
	var carros := linhas.filter(func(l): return l.has("dano"))
	var k := ESCALA_COMPACTA if carros.size() > MUITOS else 1.0
	var linha := LINHA * k
	var carro := CARRO * k
	# Cabeçalho: quantos ainda estão de pé e a seta de recolher/abrir.
	var vivos := carros.filter(func(l): return not l["eliminado"]).size()
	draw_rect(Rect2(0, 0, LARGURA, CABECALHO - 4.0), Color(0.05, 0.05, 0.06, 0.82))
	draw_string(fonte, Vector2(12, CABECALHO * 0.5 + 5.0), "COMPETIDORES · %d DE PÉ" % vivos,
			HORIZONTAL_ALIGNMENT_LEFT, LARGURA - 50, 17, Color(0.86, 0.87, 0.9))
	var seta := Vector2(LARGURA - 22, CABECALHO * 0.5 - 2.0)
	var pts := PackedVector2Array([seta + Vector2(-7, -4), seta + Vector2(7, -4), seta + Vector2(0, 5)]) if not recolhida \
			else PackedVector2Array([seta + Vector2(-4, -7), seta + Vector2(-4, 7), seta + Vector2(5, 0)])
	draw_colored_polygon(pts, Aba.COR_DESTAQUE)
	var y := CABECALHO
	for l in linhas:
		if recolhida and not l.get("voce", false):
			continue
		if l.get("tipo", "") == "equipe":
			y += _equipe(l, y, k)
			continue
		var r := Rect2(0, y, LARGURA, linha - 6.0 * k)
		# O fundo é a barra do dano: enche de vermelho da esquerda para a direita
		# conforme o pior dano; cheio = eliminado.
		# Vermelho e preto lado a lado, os dois transparentes (sem empilhar).
		var cheio := 1.0 if l["eliminado"] else clampf(_pior(l["dano"]), 0.0, 1.0)
		var w := r.size.x * cheio
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), FUNDO_DANO)
		draw_rect(Rect2(r.position + Vector2(w, 0), Vector2(r.size.x - w, r.size.y)), FUNDO)
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), l["cor"])
		_carro(Vector2(12, y + (r.size.y - carro.y) * 0.5), l["dano"], l["eliminado"], carro)
		var cor_nome := Aba.COR_DESTAQUE if l.get("voce", false) else Color(0.92, 0.92, 0.9)
		if l["eliminado"]:
			cor_nome = Color(0.88, 0.72, 0.7)
		var modelo := String(l.get("carro", ""))
		var dois := k == 1.0 and modelo != ""  # sem espaço para o modelo na lista compacta
		var x_nome := 20 + carro.x + 4
		var largura_nome := LARGURA - x_nome - 10.0
		draw_string(fonte, Vector2(x_nome, y + r.size.y * 0.5 + (-2.0 if dois else 7 * k)), String(l["nome"]),
				HORIZONTAL_ALIGNMENT_LEFT, largura_nome, roundi(20 * maxf(k, 0.8)), cor_nome)
		if dois:
			draw_string(fonte, Vector2(x_nome, y + r.size.y * 0.5 + 15.0), modelo, HORIZONTAL_ALIGNMENT_LEFT,
					largura_nome, 14, Color(0.78, 0.62, 0.6) if l["eliminado"] else Color(0.6, 0.6, 0.62))
		y += linha
	custom_minimum_size = Vector2(LARGURA, y)
	size = custom_minimum_size  # fora de contêiner: a área do toque acompanha a lista


## Linha da equipe: faixa na cor dela, a posição (quando já tem) e o nome.
## Devolve a altura usada.
func _equipe(l: Dictionary, y: float, k: float) -> float:
	var h := EQUIPE * maxf(k, 0.75)
	var r := Rect2(0, y, LARGURA, h - 2.0)
	var cor: Color = l["cor"]
	draw_rect(r, Color(cor.r, cor.g, cor.b, 0.22 if l["eliminado"] else 0.4).darkened(0.35))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), cor)
	var x := 12.0
	var tam := roundi(18 * maxf(k, 0.8))
	if int(l["posicao"]) > 0:
		var txt := "#%d" % int(l["posicao"])
		draw_string(Tipografia.fonte_numero(), Vector2(x, y + h * 0.5 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam + 2,
				Aba.COR_DESTAQUE if int(l["posicao"]) == 1 else Color.WHITE)
		x += Tipografia.fonte_numero().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam + 2).x + 10
	draw_string(Tipografia.fonte("semibold"), Vector2(x, y + h * 0.5 + 6), String(l["nome"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, LARGURA - x - 10, tam, Color(0.6, 0.6, 0.6) if l["eliminado"] else Color.WHITE)
	return h


## Carro de pé em 2 colunas × 3 linhas: [frente_e, frente_d], [lado_e, lado_d], [tras_e, tras_d].
func _carro(o: Vector2, dano: PackedFloat32Array, eliminado: bool, tam := CARRO) -> void:
	var cel := Vector2(tam.x / 2.0, tam.y / 3.0)
	for r in 6:
		var col := r % 2
		var lin := r / 2
		var q := Rect2(o + Vector2(col * cel.x, lin * cel.y), cel - Vector2(2, 2))
		draw_rect(q, Color(0.02, 0.02, 0.02) if eliminado else cor(dano[r], limite_re))


func cor(d: float, re: float) -> Color:
	if d <= 0.5:
		return VERDE.lerp(AMARELO, d / 0.5)
	if d < re:
		return AMARELO.lerp(VERMELHO, (d - 0.5) / maxf(re - 0.5, 0.01))
	# Perto de quebrar: alterna vermelho e claro, mais rápido quanto pior.
	var hz := lerpf(2.0, 6.0, clampf((d - re) / maxf(1.0 - re, 0.01), 0.0, 1.0))
	return VERMELHO if fmod(Time.get_ticks_msec() / 1000.0 * hz, 1.0) < 0.5 else ALERTA


static func _pior(d: PackedFloat32Array) -> float:
	var m := 0.0
	for x in d:
		m = maxf(m, x)
	return m
