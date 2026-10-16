class_name FundirMalhas
extends RefCounted
## Junta as malhas fixas de um cenário em poucas (uma chamada de desenho por
## material, em vez de uma por peça): as de cor lisa (StandardMaterial3D sem
## textura, transparência nem brilho) viram uma malha só com a cor no vértice;
## as outras, uma por material. As originais ficam sem malha (o nó, os filhos,
## como um Label3D, e as colisões continuam). Pula o que está escondido e o que
## se mexe (nó com a meta "animado" ou dentro dele).


static func fundir(raizes: Array, pai: Node3D) -> int:
	var inv := pai.global_transform.affine_inverse()
	var lisas := _acumulador()
	var por_material := {}  # Material -> acumulador
	var n := 0
	for raiz in raizes:
		for mi: MeshInstance3D in (raiz as Node).find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree() or _animado(mi, raiz):
				continue
			var x := inv * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if _lisa(mat):
					_somar(lisas, mi.mesh.surface_get_arrays(s), x, (mat as BaseMaterial3D).albedo_color)
				else:
					if not por_material.has(mat):
						por_material[mat] = _acumulador()
					_somar(por_material[mat], mi.mesh.surface_get_arrays(s), x, null)
			mi.mesh = null
			n += 1
	var malha := ArrayMesh.new()
	if not (lisas["v"] as PackedVector3Array).is_empty():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.95
		_superficie(malha, lisas, m)
	for mat in por_material:
		_superficie(malha, por_material[mat], mat)
	if malha.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		pai.add_child(mi)
	return n


static func _animado(n: Node, raiz: Node) -> bool:
	while n != null and n != raiz:
		if n.has_meta("animado"):
			return true
		n = n.get_parent()
	return raiz.has_meta("animado")


static func _lisa(mat: Material) -> bool:
	var m := mat as BaseMaterial3D
	return m != null and m.albedo_texture == null and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and not m.emission_enabled and not m.vertex_color_use_as_albedo \
			and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and m.cull_mode == BaseMaterial3D.CULL_BACK


static func _acumulador() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
			"c": PackedColorArray(), "i": PackedInt32Array(), "com_uv": true}


## Soma uma superfície (vértices e normais já no espaço do pai); `cor` não nula
## pinta os vértices, senão ficam as cores que a malha já tem (ou branco).
static func _somar(acc: Dictionary, arr: Array, x: Transform3D, cor) -> void:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns = arr[Mesh.ARRAY_NORMAL]
	var uvs = arr[Mesh.ARRAY_TEX_UV]
	var cores = arr[Mesh.ARRAY_COLOR]  # malha que já pinta os vértices (camadas do bloco)
	var idx = arr[Mesh.ARRAY_INDEX]
	var base: int = (acc["v"] as PackedVector3Array).size()
	var nb := x.basis.inverse().transposed()
	var v: PackedVector3Array = acc["v"]
	var nn: PackedVector3Array = acc["n"]
	var uv: PackedVector2Array = acc["uv"]
	var cc: PackedColorArray = acc["c"]
	var ii: PackedInt32Array = acc["i"]
	for k in vs.size():
		v.append(x * vs[k])
		nn.append((nb * (ns[k] as Vector3)).normalized() if ns != null and k < (ns as PackedVector3Array).size() else Vector3.UP)
		if uvs != null and k < (uvs as PackedVector2Array).size():
			uv.append(uvs[k])
		else:
			uv.append(Vector2.ZERO)
		if cor != null:
			cc.append(cor)
		elif cores != null and k < (cores as PackedColorArray).size():
			cc.append(cores[k])
		else:
			cc.append(Color.WHITE)
	if idx != null and not (idx as PackedInt32Array).is_empty():
		for k in (idx as PackedInt32Array):
			ii.append(base + k)
	else:
		for k in vs.size():
			ii.append(base + k)
	acc["v"] = v
	acc["n"] = nn
	acc["uv"] = uv
	acc["c"] = cc
	acc["i"] = ii


static func _superficie(malha: ArrayMesh, acc: Dictionary, mat: Material) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = acc["v"]
	arr[Mesh.ARRAY_NORMAL] = acc["n"]
	arr[Mesh.ARRAY_TEX_UV] = acc["uv"]
	arr[Mesh.ARRAY_COLOR] = acc["c"]
	arr[Mesh.ARRAY_INDEX] = acc["i"]
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	malha.surface_set_material(malha.get_surface_count() - 1, mat)
