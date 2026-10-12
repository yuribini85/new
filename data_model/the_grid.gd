class_name TheGrid
extends RefCounted
## The Grid, a lista negra (documento de narrativa e progressão): as dez
## equipes rivais no topo do circuito, da #10 à #1 (equipes.json → grid), as
## das identidades aprovadas. A equipe do jogador começa fora e sobe uma
## posição por vez: vence a equipe da vez quando ganha uma prova (corrida, ou
## o campeonato da arena com a dupla de pé) em que ela estava. Só a da vez
## conta, em ordem. Ninguém perde posição por derrota.
## (O CRED do documento ainda não existe: o filtro de hoje é a licença, que
## já decide em que provas cada equipe corre.)


## As dez, da #10 à #1.
static func equipes(dados: Node) -> Array:
	var l: Array = dados.lista("equipes").filter(func(e): return e.get("grid") != null)
	l.sort_custom(func(a, b): return int(a["grid"]) > int(b["grid"]))
	return l


## jogador.grid: {vencidas: [ids, em ordem], riscar: id da última vencida
## ainda não riscada na tela, vistas: [ids cuja ficha já apareceu; "fim"]}.
static func vencidas(jogador: Node) -> Array:
	return Array(jogador.grid.get("vencidas", []))


## Posição do jogador no Grid (0 = fora; 10 depois de vencer a #10; 1 no topo).
static func posicao(dados: Node, jogador: Node) -> int:
	var n := vencidas(jogador).size()
	return 0 if n == 0 else equipes(dados).size() + 1 - n


## A equipe da vez ({} com o Grid inteiro vencido).
static func da_vez(dados: Node, jogador: Node) -> Dictionary:
	var feitas := vencidas(jogador)
	for e in equipes(dados):
		if not e["id"] in feitas:
			return e
	return {}


## Uma vitória do jogador numa prova com estas equipes: se a da vez estava,
## ela fica para trás. Devolve a equipe vencida ({} se nada mudou).
static func registrar(dados: Node, jogador: Node, presentes: Array) -> Dictionary:
	var e := da_vez(dados, jogador)
	if e.is_empty() or not e["id"] in presentes:
		return {}
	jogador.grid["vencidas"] = vencidas(jogador) + [e["id"]]
	jogador.grid["riscar"] = String(e["id"])  # a tela Carreira risca e revela a próxima
	return e


## Equipe vencida cujo risco ainda não foi mostrado ("" se nenhuma).
static func riscar_pendente(jogador: Node) -> String:
	return String(jogador.grid.get("riscar", ""))


static func riscada(jogador: Node) -> void:
	jogador.grid.erase("riscar")


## Ficha (vinheta) ainda não vista: a da vez, ou o fim do Grid ("fim").
## "" se não há nada a apresentar.
static func ficha_pendente(dados: Node, jogador: Node) -> String:
	var vistas: Array = Array(jogador.grid.get("vistas", []))
	var vez := da_vez(dados, jogador)
	if vez.is_empty():
		return "" if equipes(dados).is_empty() or "fim" in vistas else "fim"
	return "" if vez["id"] in vistas else String(vez["id"])


static func marcar_vista(jogador: Node, id: String) -> void:
	var vistas: Array = Array(jogador.grid.get("vistas", []))
	if not id in vistas:
		jogador.grid["vistas"] = vistas + [id]


static func equipe(dados: Node, id: String) -> Dictionary:
	for e in equipes(dados):
		if e["id"] == id:
			return e
	return {}
