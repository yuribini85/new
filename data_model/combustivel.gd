class_name Combustivel
extends RefCounted
## Combustível (2026-10-17, decisão do usuário): cada corrida ou luta da arena
## gasta 1 do tanque; o tanque renova sozinho em tempo real (1 a cada
## `renova_s`, também com o app fechado) e um vídeo com recompensa o enche de
## uma vez. O tutorial não gasta (vale depois de liberado o ACELERAR). Regras
## em data/monetizacao.json → combustivel {tanque, renova_s}; sem elas, não há
## limite.
##
## Estado em jogador.combustivel: {} = tanque cheio; {qtd, desde} = qtd no
## instante `desde` (relógio real, segundos Unix). A renovação conta do `desde`;
## relógio voltando não tira nem dá combustível.

## Mesma liberação do ACELERAR (principal.gd → acelerar_liberado): o primeiro
## treino de licença encerra o tutorial.
const FLAGS_FIM_TUTORIAL := ["ACELERAR_LIBERADO", "FIRST_TRAINING_STARTED"]


static func regras(dados: Node) -> Dictionary:
	var r = dados.monetizacao().get("combustivel", {})
	return r if r is Dictionary and r.get("tanque") != null and r.get("renova_s") != null else {}


## O tanque vale para o jogador agora (fora do tutorial e com regras nos dados).
static func vale(dados: Node, jogador: Node) -> bool:
	if regras(dados).is_empty():
		return false
	if jogador.historia == null or jogador.personagem != "dono":
		return true
	for f in FLAGS_FIM_TUTORIAL:
		if jogador.flags.has(f):
			return true
	return false


static func tanque(dados: Node) -> int:
	return int(regras(dados).get("tanque", 0))


## Combustível no instante `agora`.
static func quantidade(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> int:
	var r := regras(dados)
	if r.is_empty():
		return 0
	var c: Dictionary = jogador.combustivel
	if c.is_empty():
		return int(r["tanque"])
	var passou := maxf(agora - float(c["desde"]), 0.0)
	return mini(int(r["tanque"]), int(c["qtd"]) + int(floor(passou / float(r["renova_s"]))))


## Segundos até a próxima unidade (0 com o tanque cheio).
static func proxima_s(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> float:
	var r := regras(dados)
	if r.is_empty() or quantidade(dados, jogador, agora) >= int(r["tanque"]):
		return 0.0
	var passo := float(r["renova_s"])
	var passou := maxf(agora - float(jogador.combustivel["desde"]), 0.0)
	return passo - fmod(passou, passo)


## Segundos até encher o tanque.
static func cheio_em_s(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> float:
	var falta := tanque(dados) - quantidade(dados, jogador, agora)
	if falta <= 0:
		return 0.0
	return proxima_s(dados, jogador, agora) + float(falta - 1) * float(regras(dados)["renova_s"])


## Pode largar agora? (sem limite, ou com combustível no tanque)
static func pode(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> bool:
	return not vale(dados, jogador) or quantidade(dados, jogador, agora) > 0


## Gasta 1 (se valer). false = tanque vazio, nada gasto.
static func gastar(dados: Node, jogador: Node, agora: float = Time.get_unix_time_from_system()) -> bool:
	if not vale(dados, jogador):
		return true
	var r := regras(dados)
	var q := quantidade(dados, jogador, agora)
	if q <= 0:
		return false
	var c: Dictionary = jogador.combustivel
	var desde := agora
	if q < int(r["tanque"]) and not c.is_empty():
		# Guarda a fração já andada da unidade seguinte.
		var passo := float(r["renova_s"])
		var passou := maxf(agora - float(c["desde"]), 0.0)
		desde = agora - fmod(passou, passo)
	jogador.combustivel = {"qtd": q - 1, "desde": desde}
	return true


## Vídeo com recompensa: tanque cheio.
static func encher(jogador: Node) -> void:
	jogador.combustivel = {}
