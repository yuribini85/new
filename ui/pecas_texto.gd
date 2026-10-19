class_name PecasTexto
extends RefCounted
## Textos das peças (nomes, o que fazem, onde pesam na corrida), usados pela
## Evolução da Oficina e pelas licenças.

## Atributo que cada categoria muda (o resto: potência).
const AFETA_CATEGORIA := {"lightweight": "peso", "brake": "freio", "corrida": "peso",
		"blindagem": "blindagem"}

## O que cada grupo de peças faz (detalhe da janela de compra).
const EXPLICA_CATEGORIA := {
	"aspiracao": "Mais potência pela admissão (turbo ou preparação aspirada).",
	"lightweight": "Tira peso: o carro acelera, freia e contorna melhor.",
	"brake": "Freia mais forte e mais tarde antes das curvas.",
	"muffler": "Escapamento esportivo: um pouco mais de potência.",
	"portpolish": "Melhora o fluxo no motor: mais potência.",
	"enginebalance": "Motor balanceado: mais potência.",
	"displacement": "Motor maior: mais potência.",
	"computer": "Nova central eletrônica: mais potência.",
	"intercooler": "Resfria o ar do turbo: mais potência.",
	"blindagem": "Chapas de aço na carroceria: aguenta mais pancada na arena, mas pesa na corrida.",
	"corrida": "Carroceria de corrida: mais leve e aceita nas copas de marca \"Corrida\". O carro deixa de entrar nas copas só de carro de rua.",
}
const NOMES_CATEGORIA := {
	"aspiracao": "Aspiração", "lightweight": "Peso", "brake": "Freios", "muffler": "Escapamento",
	"portpolish": "Retrabalho do cabeçote", "enginebalance": "Balanceamento", "displacement": "Cilindrada",
	"computer": "Central eletrônica", "intercooler": "Intercooler", "cambio": "Câmbio", "corrida": "Kit de corrida",
	"blindagem": "Blindagem",
}

## O que a melhoria faz na pista, dito pela função.
const FUNCAO := {
	"potencia": "acelera mais forte e chega mais rápido no fim da reta",
	"peso": "acelera, contorna e freia melhor",
	"freio": "permite frear mais tarde antes das curvas",
	"pneu": "contorna mais rápido e freia mais curto",
	"blindagem": "na arena aguenta mais pancada antes de quebrar; na corrida o peso a mais tira aceleração, freio e curva",
}

