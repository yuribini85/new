class_name Preferencias
extends RefCounted
## Preferências do aparelho (não vão no save da carreira): volume e reduzir
## animações. Ficam em user://preferencias.cfg.

const CAMINHO := "user://preferencias.cfg"

## 0..1
static var volume := 0.7
static var reduzir_animacoes := false
static var _carregado := false


static func carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO) == OK:
		volume = clampf(float(cfg.get_value("som", "volume", volume)), 0.0, 1.0)
		reduzir_animacoes = bool(cfg.get_value("tela", "reduzir_animacoes", reduzir_animacoes))
	aplicar()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("som", "volume", volume)
	cfg.set_value("tela", "reduzir_animacoes", reduzir_animacoes)
	cfg.save(CAMINHO)
	aplicar()


static func aplicar() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
