extends SceneTree
## Executa: godot --headless --script res://tests/run_tests.gd
## Sai com código 1 se algum teste falhar.

const SUITES := [
	preload("res://tests/test_dados.gd"),
	preload("res://tests/test_carro.gd"),
	preload("res://tests/test_pista.gd"),
	preload("res://tests/test_simulacao.gd"),
	preload("res://tests/test_concessionaria.gd"),
	preload("res://tests/test_carreira.gd"),
	preload("res://tests/test_licencas_usados.gd"),
	preload("res://tests/test_fila_save.gd"),
]


func _init() -> void:
	var falhas := 0
	var total := 0
	for suite_script in SUITES:
		var suite = suite_script.new()
		for m in suite.get_method_list():
			if not m["name"].begins_with("test_"):
				continue
			total += 1
			suite.falhas.clear()
			suite.call(m["name"])
			if suite.falhas.is_empty():
				print("ok   %s.%s" % [suite_script.resource_path.get_file(), m["name"]])
			else:
				falhas += 1
				print("FAIL %s.%s" % [suite_script.resource_path.get_file(), m["name"]])
				for f in suite.falhas:
					print("     " + f)
		if suite is Node:
			suite.free()
	print("\n%d/%d testes passaram" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
