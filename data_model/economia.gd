class_name Economia
extends RefCounted
## Saldo do jogador. Todo dinheiro entra e sai por aqui.

signal saldo_mudou(saldo: int)

var saldo: int = 0


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
