class_name Garagem
extends RefCounted
## Carros possuídos, por uid. Também é a coleção: carros-prêmio entram aqui.

signal mudou

var carros: Dictionary = {}  # uid -> Carro
## Próximo uid a entregar; persistido no save para uids nunca se repetirem.
var proximo_uid: int = 1


func adicionar(carro: Carro) -> int:
	carro.uid = proximo_uid
	proximo_uid += 1
	carros[carro.uid] = carro
	mudou.emit()
	return carro.uid


func remover(uid: int) -> Carro:
	var carro: Carro = carros.get(uid)
	if carro != null:
		carros.erase(uid)
		mudou.emit()
	return carro


func carro(uid: int) -> Carro:
	return carros.get(uid)


func lista() -> Array:
	return carros.values()
