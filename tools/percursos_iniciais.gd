extends SceneTree
## Percurso inicial com cada carro que o saldo inicial paga (usados do dia 0 e
## novos): confere se há caminho com vários carros, sem uma escolha única.
## Uso: godot --headless --script res://tools/percursos_iniciais.gd

const Percurso := preload("res://tools/percurso.gd")
const LIMITE_S := 30.0 * 60.0

var _feito := false


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var d: Node = root.get_node("Dados")
	var saldo := int(d.economia()["saldo_inicial"])
	var ofertas := []
	for o in Usados.estoque(d.lista("carros"), 0, {}):
		if int(o["preco"]) <= saldo:
			ofertas.append(o)
	for c in d.lista("carros"):
		if c.get("novo", true) and int(c["preco"]) <= saldo:
			ofertas.append({"carro_id": c["id"], "preco": int(c["preco"])})
	print("%-18s %7s %9s %6s %8s %9s %8s" % ["carro", "preço", "pronto B", "ciclo", "vitórias", "saldo", "minutos"])
	for o in ofertas:
		var r: Dictionary = Percurso.jogar(d, o, LIMITE_S)
		print("%-18s %7d %9s %6s %8d %9d %8.1f" % [o["carro_id"], o["preco"], "sim" if r["pronto_b"] else "não",
				"sim" if r["ciclo"] else "não", r["vitorias"], r["saldo"], r["tempo"] / 60.0])
