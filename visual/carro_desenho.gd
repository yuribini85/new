class_name CarroDesenho
extends Node3D
## Carro da corrida em sprite (decisão 31): o de cima deitado no chão, girando
## com o carro, e o isométrico de frente para a câmera, que só aparece no modo
## velocidade (a câmera fica atrás do carro, no ângulo do desenho). mistura()
## faz a troca com alfa cruzado. Mesma orientação do CarroBloco: frente em +X.

var _topo: Sprite3D
var _iso: Sprite3D


## false se o modelo não tem os dois sprites (aí a corrida usa o CarroBloco).
func configurar(id: String) -> bool:
	var t := ArteCarro.textura(id, "topo")
	var i := ArteCarro.textura(id, "iso")
	if t == null or i == null:
		return false
	var px := 1.0 / ArteCarro.PX_POR_M
	var sombra := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(t.get_height() * px * 0.95, t.get_width() * px * 0.9)
	q.orientation = PlaneMesh.FACE_Y
	sombra.mesh = q
	var ms := StandardMaterial3D.new()
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ms.albedo_color = Color(0, 0, 0, 0.35)
	sombra.material_override = ms
	sombra.position = Vector3(0.15, 0.02, 0.15)
	add_child(sombra)
	_topo = Sprite3D.new()
	_topo.texture = t
	_topo.pixel_size = px
	_topo.shaded = false
	_topo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	# Deitado no chão, com o alto da imagem (a frente) apontando para +X.
	_topo.rotation = Vector3(-PI / 2.0, -PI / 2.0, 0.0)
	_topo.position.y = 0.06
	add_child(_topo)
	_iso = Sprite3D.new()
	_iso.texture = i
	_iso.pixel_size = px
	_iso.shaded = false
	_iso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_iso.position.y = 0.6  # o gerador centra a imagem a 0,6 m do chão
	_iso.visible = false
	add_child(_iso)
	return true


## 0 = só o de cima; 1 = só o isométrico; no meio, alfa cruzado.
func mistura(b: float) -> void:
	if _topo == null:
		return
	_topo.modulate.a = 1.0 - b
	_iso.modulate.a = b
	_topo.visible = b < 0.999
	_iso.visible = b > 0.001


func girar_rodas(_distancia: float) -> void:
	pass
