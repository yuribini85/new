class_name Economia
extends RefCounted
## Saldo do jogador. Todo dinheiro entra e sai por aqui.

signal saldo_mudou(saldo: int)

var saldo: int = 0
## Crédito de peças (desmanche de carros, GestaoEquipe): só paga peças, antes do saldo.
var credito_pecas: int = 0


func _init(saldo_inicial: int = 0) -> void:
	saldo = saldo_inicial


func pode_pagar(valor: int) -> bool:
	return valor <= saldo


## Retorna false (e não debita nada) se o saldo não cobre o valor.
func debitar(valor: int) -> bool:
	if valor < 0 or not pode_pagar(valor):
		return false
	saldo -= valor
	saldo_mudou.emit(saldo)
	return true


func creditar(valor: int) -> void:
	if valor <= 0:
		return
	saldo += valor
	saldo_mudou.emit(saldo)


## Peça: o crédito de peças paga primeiro, o saldo o resto.
func pode_pagar_peca(valor: int) -> bool:
	return valor <= saldo + credito_pecas


func debitar_peca(valor: int) -> bool:
	if valor < 0 or not pode_pagar_peca(valor):
		return false
	var do_credito := mini(credito_pecas, valor)
	credito_pecas -= do_credito
	saldo -= valor - do_credito
	saldo_mudou.emit(saldo)
	return true
