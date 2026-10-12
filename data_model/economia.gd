class_name Economia
extends RefCounted
## Saldo do jogador. Todo dinheiro entra e sai por aqui.

signal saldo_mudou(saldo: int)

var saldo: int = 0
## Peças (o recurso do cabeçalho, ao lado dos giros): vêm de carros desmontados,
## de carros perdidos na arena e dos rivais que a equipe destrói lá
## (GestaoEquipe.pecas_do_carro); pagam a blindagem. O nome do campo é o do
## save antigo (era o crédito do desmanche).
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


## Peça da Oficina: em giros; `em_pecas` (a blindagem, decisão 74): peças e
## giros, as peças primeiro e os giros completam o que faltar.
func pode_pagar_peca(valor: int, em_pecas := false) -> bool:
	return valor <= (credito_pecas + saldo if em_pecas else saldo)


## Quanto da blindagem sai em peças (o resto, em giros).
func parte_em_pecas(valor: int) -> int:
	return clampi(credito_pecas, 0, maxi(valor, 0))


func debitar_peca(valor: int, em_pecas := false) -> bool:
	if valor < 0 or not pode_pagar_peca(valor, em_pecas):
		return false
	if em_pecas:
		var p := parte_em_pecas(valor)
		credito_pecas -= p
		saldo -= valor - p
	else:
		saldo -= valor
	saldo_mudou.emit(saldo)
	return true


func ganhar_pecas(n: int) -> void:
	if n > 0:
		credito_pecas += n
		saldo_mudou.emit(saldo)
