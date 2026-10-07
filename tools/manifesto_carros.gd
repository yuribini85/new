extends SceneTree
## Completa arte/carros/manifesto.json com a geometria de cada vista: tamanho
## da tela e retângulo ocupado pelo carro, medidos nos sprites atuais. Os
## provisórios (tools/gerar_sprites.gd) já estão na escala e na posição certas
## (docs/arte_carros.md); o importador encaixa a arte final nesse retângulo.
## Também calcula onde ficam as duas rodas visíveis no isométrico (rodas_iso:
## centro e dois semieixos da elipse, em px), projetando as rodas do carro em
## código com a mesma câmera do gerador; o importador refina pelo desenho.
## Só preenche o que falta: carro novo, rode gerar_sprites.gd e depois este.
## Uso: godot --headless --path . --script res://tools/manifesto_carros.gd

const MANIFESTO := "res://arte/carros/manifesto.json"
const Importador := preload("res://tools/importar_kit_pista.gd")


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTO))
	var d: Node = root.get_node_or_null("Dados")
	var ids := itens.map(func(i): return i["id"])
	if d != null:
		for b in d.lista("carros"):
			if not ids.has(b["id"]):
				printerr("sem descrição no manifesto: %s" % b["id"])
	for it in itens:
		for vista in ["topo", "iso"]:
			if it.has(vista):
				continue
			var caminho := "res://arte/carros/%s_%s.png" % [it["id"], vista]
			if not FileAccess.file_exists(caminho):
				printerr("sem sprite: %s" % caminho)
				continue
			var img := Image.load_from_file(caminho)
			img.convert(Image.FORMAT_RGBA8)
			var r := Importador._contorno(img)
			it[vista] = {"tela": [img.get_width(), img.get_height()], "rect": [r.position.x, r.position.y, r.size.x, r.size.y]}
	if d != null:
		for it in itens:
			if not it.has("rodas_iso"):
				var b: Dictionary = d.carro(it["id"])
				if not b.is_empty():
					it["rodas_iso"] = await _rodas_iso(b)
	var f := FileAccess.open(MANIFESTO, FileAccess.WRITE)
	f.store_string(JSON.stringify(itens, " ", false) + "\n")
	print("manifesto dos carros: %d modelos" % itens.size())
	quit()


## Rodas visíveis no isométrico: as duas mais perto da câmera do gerador.
func _rodas_iso(base: Dictionary) -> Array:
	var tela := Vector2i(1120, 800)
	var px := 160.0
	var vp := SubViewport.new()
	vp.size = tela
	vp.own_world_3d = true
	root.add_child(vp)
	var carro := CarroBloco.new()
	vp.add_child(carro)
	carro.configurar_modelo(base, Color.WHITE)
	carro.rotation.y = -PI / 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = tela.y / px
	vp.add_child(cam)
	var olho := Vector3(70, 57.15, 70).normalized() * 30.0 + Vector3(0, 0.6, 0)
	cam.look_at_from_position(olho, Vector3(0, 0.6, 0))
	await process_frame
	# O lado do carro virado para a câmera: as duas rodas desse lado.
	var lados := {-1: [], 1: []}
	for roda in carro._rodas:
		lados[1 if roda.position.z > 0.0 else -1].append(roda)
	var perto := func(lista: Array) -> float:
		return lista.reduce(func(acc, rd): return acc + rd.global_position.distance_to(olho), 0.0)
	var visivel: Array = lados[-1] if perto.call(lados[-1]) < perto.call(lados[1]) else lados[1]
	var r := []
	for roda in visivel:
		var c: Vector3 = roda.global_position
		var raio: float = roda.position.y
		var frente: Vector3 = carro.global_basis.x.normalized()
		var p0 := cam.unproject_position(c)
		var pa := cam.unproject_position(c + frente * raio) - p0
		var pb := cam.unproject_position(c + Vector3.UP * raio) - p0
		r.append({"c": [snappedf(p0.x, 0.1), snappedf(p0.y, 0.1)], "a": [snappedf(pa.x, 0.1), snappedf(pa.y, 0.1)],
				"b": [snappedf(pb.x, 0.1), snappedf(pb.y, 0.1)]})
	vp.queue_free()
	return r
