extends SceneTree
## Mede os sprites de arte/carros/ e grava arte/carros/pintura.json: para cada
## sprite de carroceria branca (pintura detectada em ao menos FRACAO_MINIMA dos
## pixels do carro, com brilho mediano de ao menos BRILHO_MINIMO), a faixa de
## brilho da pintura [v_lo, v_med, v_ref] (quantis 5%, 50% e 95%), que o shader
## de pintura usa (visual/pintura.gd). Sprite fora
## do arquivo fica com a cor que veio na arte.
## Uso: godot --headless --path . --script res://tools/medir_pintura.gd

const FRACAO_MINIMA := 0.3
## Carroceria branca, não prata: brilho mediano da pintura de ao menos isto.
const BRILHO_MINIMO := 0.85
## Mesma detecção do shader (tolerância 0,7, aprovada na Oficina de Pintura).
const TOLERANCIA := 0.7

var _feito := false


func _process(_d: float) -> bool:
	if not _feito:
		_feito = true
		_medir()
		quit()
	return false


func _medir() -> void:
	var saida := {}
	var dir := DirAccess.open(ArteCarro.PASTA)
	var arquivos := Array(dir.get_files()).filter(func(f): return f.ends_with("_iso.png") or f.ends_with("_topo.png"))
	arquivos.sort()
	for f in arquivos:
		var vista: String = "iso" if f.ends_with("_iso.png") else "topo"
		var id: String = f.trim_suffix("_%s.png" % vista)
		var img := Image.load_from_file(ArteCarro.PASTA + f)
		img.convert(Image.FORMAT_RGBA8)
		var dados := img.get_data()
		var vs := PackedFloat32Array()
		var opacos := 0
		var s_max := 0.06 + TOLERANCIA * 0.16
		var v_min := 0.75 - TOLERANCIA * 0.35
		for i in range(0, dados.size(), 4):
			if dados[i + 3] == 0:
				continue
			opacos += 1
			var mx := maxi(dados[i], maxi(dados[i + 1], dados[i + 2]))
			var mn := mini(dados[i], mini(dados[i + 1], dados[i + 2]))
			var v := mx / 255.0
			var s := (mx - mn) / float(mx) if mx > 0 else 0.0
			var w := (1.0 - smoothstep(s_max, s_max + 0.06, s)) * smoothstep(v_min - 0.08, v_min, v)
			if w > 0.8:
				vs.append(v)
		var fracao := vs.size() / float(maxi(opacos, 1))
		if fracao < FRACAO_MINIMA:
			continue
		vs.sort()
		var q := func(p: float) -> float: return snappedf(vs[int((vs.size() - 1) * p)], 0.001)
		if q.call(0.5) < BRILHO_MINIMO:
			continue
		if not saida.has(id):
			saida[id] = {}
		saida[id][vista] = [q.call(0.05), q.call(0.5), q.call(0.95)]
		print("%s %s: pintura %d%%, faixa %s" % [id, vista, roundi(fracao * 100.0), str(saida[id][vista])])
	# Só modelos com as duas vistas brancas (a corrida usa as duas).
	for id in saida.keys():
		if saida[id].size() < 2:
			saida.erase(id)
	var arq := FileAccess.open(ArteCarro.PASTA + "pintura.json", FileAccess.WRITE)
	arq.store_string(JSON.stringify(saida, "\t", true) + "\n")
	print("%d modelos de carroceria branca" % saida.size())
