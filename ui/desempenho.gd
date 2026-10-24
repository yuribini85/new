class_name Desempenho
extends RefCounted
## Desempenho no aparelho (plano de ação do teste com pessoas, 2026-10-21,
## fase 0): mede e, se preciso, alivia sozinho.
##
## - Medição: o aparelho, o tempo de abertura e os quadros por segundo de cada
##   tela (média e pior segundo). Só nos builds de teste (APK e demo:
##   Preferencias.ferramentas_teste), em user://desempenho.json, e aparece nas
##   Configurações para o testador mandar o print. Nada sai do aparelho.
## - Qualidade automática (todos os builds): com uma cena 3D na tela, se a média
##   dos últimos JANELA segundos fica abaixo de LIMIAR, liga os efeitos leves
##   (sem sombras, suavização e partículas, 3D em resolução menor). Uma vez só:
##   se o jogador desligar nas Configurações, a escolha dele fica.

const CAMINHO := "user://desempenho.json"
## Meta do plano: 30 quadros estáveis num aparelho da classe do Galaxy A20s.
const META_FPS := 30.0
## Média abaixo disto (com folga para oscilação) liga os efeitos leves.
const LIMIAR := META_FPS * 0.85
const JANELA := 8
## Resolução do 3D com os efeitos leves (fração da tela).
const ESCALA_3D_LEVE := 0.75

## Cenas 3D vivas (Corrida3D, Arena3D): se alguma está visível, a amostra conta
## para a qualidade automática.
static var cenas_3d: Array = []
static var _janela: Array = []
static var _telas := {}
static var _abertura_s := -1.0
static var _gravado_em := 0


static func entrou_3d(n: Node) -> void:
	if not cenas_3d.has(n):
		cenas_3d.append(n)


static func saiu_3d(n: Node) -> void:
	cenas_3d.erase(n)


static func em_3d() -> bool:
	for n in cenas_3d:
		if is_instance_valid(n) and n.is_visible_in_tree():
			return true
	return false


static func medindo() -> bool:
	return Preferencias.ferramentas_teste()


## Tempo do início do programa até a primeira tela pronta.
static func abertura() -> void:
	if _abertura_s < 0.0:
		_abertura_s = Time.get_ticks_msec() / 1000.0


## Uma amostra por segundo. Devolve true quando acabou de ligar os efeitos
## leves (a tela avisa o jogador).
static func amostra(fps: float, tela: String) -> bool:
	var tres_d := em_3d()
	if medindo():
		var t: Dictionary = _telas.get_or_add(tela + (" (3D)" if tres_d else ""), {"soma": 0.0, "segundos": 0, "pior": 9999.0})
		t["soma"] += fps
		t["segundos"] += 1
		t["pior"] = minf(float(t["pior"]), fps)
		_gravado_em += 1
		if _gravado_em >= 15:
			_gravado_em = 0
			gravar()
	return _qualidade_auto(fps, tres_d)


static func _qualidade_auto(fps: float, tres_d: bool) -> bool:
	if not tres_d or Preferencias.efeitos_leves or Preferencias.limitar_fps or Preferencias.leves_automatico:
		_janela.clear()
		return false
	_janela.append(fps)
	if _janela.size() < JANELA:
		return false
	if _janela.size() > JANELA:
		_janela.pop_front()
	var soma := 0.0
	for f in _janela:
		soma += f
	if soma / _janela.size() >= LIMIAR:
		return false
	Preferencias.efeitos_leves = true
	Preferencias.leves_automatico = true
	Preferencias.salvar()
	_janela.clear()
	if medindo():
		gravar()
	return true


## Ajustes de uma cena 3D conforme os efeitos leves (na criação da cena).
static func preparar_viewport(vp: SubViewport) -> void:
	vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_2X
	vp.scaling_3d_scale = ESCALA_3D_LEVE if Preferencias.efeitos_leves else 1.0


static func aparelho() -> Dictionary:
	var tela := DisplayServer.screen_get_size()
	return {"modelo": OS.get_model_name(), "sistema": "%s %s" % [OS.get_name(), OS.get_version()],
			"processador": OS.get_processor_name(), "nucleos": OS.get_processor_count(),
			"tela": "%dx%d" % [tela.x, tela.y], "video": RenderingServer.get_video_adapter_name()}


static func relatorio() -> Dictionary:
	var telas := {}
	for nome in _telas:
		var t: Dictionary = _telas[nome]
		telas[nome] = {"media": snappedf(float(t["soma"]) / maxi(int(t["segundos"]), 1), 0.1),
				"pior": float(t["pior"]), "segundos": int(t["segundos"])}
	return {"aparelho": aparelho(), "abertura_s": snappedf(_abertura_s, 0.1), "telas": telas,
			"efeitos_leves": Preferencias.efeitos_leves, "leves_automatico": Preferencias.leves_automatico}


static func gravar() -> void:
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(relatorio(), "\t"))


## Linhas para as Configurações (ferramentas de teste).
static func resumo() -> Array:
	var r := relatorio()
	var a: Dictionary = r["aparelho"]
	var linhas := ["Aparelho: %s · %s · %s" % [a["modelo"], a["sistema"], a["tela"]],
			"Abertura: %.1f s · efeitos leves: %s%s" % [r["abertura_s"], "sim" if r["efeitos_leves"] else "não",
					" (ligados sozinhos)" if r["leves_automatico"] else ""]]
	for nome in r["telas"]:
		var t: Dictionary = r["telas"][nome]
		linhas.append("%s: média %.0f · pior %.0f quadros/s (%d s)" % [nome, t["media"], t["pior"], t["segundos"]])
	return linhas
