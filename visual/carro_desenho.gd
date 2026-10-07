class_name CarroDesenho
extends Node3D
## Carro da corrida em sprite (decisão 31): o de cima deitado no chão, girando
## com o carro, e o isométrico de frente para a câmera, que só aparece no modo
## velocidade (a câmera fica atrás do carro, no ângulo do desenho). mistura()
## faz a troca com alfa cruzado. Mesma orientação do CarroBloco: frente em +X.
## A sombra é a silhueta do carro, presa ao chão logo abaixo dele, sempre para
## o mesmo lado da tela; as rodas do isométrico giram com a distância andada.

const RAIO_RODA_M := 0.3
## Deslocamento da sombra no mundo (m): pouco, para o carro parecer no chão.
const SOMBRA_M := Vector3(0.14, 0.0, 0.1)

var _topo: Sprite3D
var _iso: MeshInstance3D
var _mat_iso: ShaderMaterial
var _sombra: Sprite3D
var _giro := 0.0
var _vista_iso := 0.0


## false se o modelo não tem os dois sprites (aí a corrida usa o CarroBloco).
func configurar(id: String) -> bool:
	var t := ArteCarro.textura(id, "topo")
	var i := ArteCarro.textura(id, "iso")
	if t == null or i == null:
		return false
	var px := 1.0 / ArteCarro.PX_POR_M
	# Sombra: a silhueta de cima, escura, fora da hierarquia de giro (top_level)
	# para o deslocamento não girar com o carro.
	_sombra = Sprite3D.new()
	_sombra.texture = t
	_sombra.pixel_size = px * 1.03
	_sombra.shaded = false
	_sombra.modulate = Color(0.0, 0.0, 0.02, 0.55)
	_sombra.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sombra.top_level = true
	add_child(_sombra)
	_topo = Sprite3D.new()
	_topo.texture = t
	_topo.pixel_size = px
	_topo.shaded = false
	_topo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	# Deitado no chão, com o alto da imagem (a frente) apontando para +X.
	_topo.rotation = Vector3(-PI / 2.0, -PI / 2.0, 0.0)
	_topo.position.y = 0.06
	add_child(_topo)
	_iso = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(i.get_width(), i.get_height()) * px
	_iso.mesh = q
	_mat_iso = ShaderMaterial.new()
	_mat_iso.shader = preload("res://visual/shaders/carro_iso.gdshader")
	_mat_iso.set_shader_parameter("textura", i)
	_mat_iso.set_shader_parameter("tela", Vector2(i.get_width(), i.get_height()))
	var rodas := ArteCarro.rodas(id)
	if rodas.size() == 2:
		_mat_iso.set_shader_parameter("usar_rodas", 1.0)
		for nome in ["c", "a", "b"]:
			_mat_iso.set_shader_parameter("roda_" + nome, PackedVector2Array([
					Vector2(rodas[0][nome][0], rodas[0][nome][1]), Vector2(rodas[1][nome][0], rodas[1][nome][1])]))
	_mat_iso.render_priority = 2
	_iso.material_override = _mat_iso
	_iso.position.y = 0.6  # o gerador centra a imagem a 0,6 m do chão
	_iso.visible = false
	add_child(_iso)
	_posicionar_sombra()
	return true


## 0 = só o de cima; 1 = só o isométrico; no meio, alfa cruzado.
func mistura(b: float) -> void:
	if _topo == null:
		return
	_vista_iso = b
	_topo.modulate.a = 1.0 - b
	_mat_iso.set_shader_parameter("modulacao", Color(1, 1, 1, b))
	_topo.visible = b < 0.999
	_iso.visible = b > 0.001


## Gira as rodas pela distância andada neste quadro (m): ângulo e borrão.
func girar_rodas(distancia: float) -> void:
	if _mat_iso == null:
		return
	_giro = fmod(_giro + distancia / RAIO_RODA_M, TAU)
	_mat_iso.set_shader_parameter("giro", _giro)
	_mat_iso.set_shader_parameter("borrao", clampf(distancia / RAIO_RODA_M, 0.0, 1.6))
	_posicionar_sombra()


func _posicionar_sombra() -> void:
	if _sombra == null or not is_inside_tree():
		return
	var g := global_transform
	var rumo := g.basis.orthonormalized().get_euler().y
	_sombra.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, rumo - PI / 2.0, 0.0)).scaled(g.basis.get_scale()),
			g.origin + SOMBRA_M * g.basis.get_scale().x + Vector3(0, 0.02, 0))
