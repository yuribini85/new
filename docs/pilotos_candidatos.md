# Segundo piloto: os 8 candidatos

Decisão 56 (`docs/plano_mvp.md`): o segundo piloto da equipe deixa de ser fixo e é
escolhido entre 8 candidatos (aba Equipe → "Trocar piloto"), como no Grand Prix Story.
Hiro Sakuno é o padrão, o que entra na cena que libera o segundo piloto. Cada candidato tem
**um traço**, dois candidatos por traço: um de corrida e um de arena (decisão do usuário, 2026-10-16), para a tela de cada vaga mostrar os quatro traços. Dados em `data/carreira.json` → `equipe_jogador`
(`candidatos`, `tracos`). Cada candidato tem `genero` ("m"/"f", pela arte); os textos flexionam por ele
(`EquipeJogador.flexao`, e nas falas `{g:masculino|feminino}`).

| id | nome | traço | vaga | arte | em uma frase |
|---|---|---|---|---|---|
| `jonas_reid` | Hiro Sakuno | Calculista | corrida | 2 | "Não ganha corrida sozinho, mas não joga ponto fora." |
| `amir_castell` | Amir Castell | Calculista | arena | 4 | "Bate sempre no mesmo lugar, do mesmo jeito. Não erra o alvo." |
| `ayla_moreno` | Ayla Moreno | Destemido | arena | 3 | "Vê uma brecha onde os outros veem um muro." |
| `axel_brennan` | Axel Brennan | Destemido | corrida | 1 | "Larga para ganhar ou para não chegar. Ainda não decidiu qual." |
| `bastian_kroll` | Bastian Kroll | Versátil | arena | 8 | "Já foi rápido. Hoje conhece todo mundo no paddock e se vira em qualquer carro." |
| `caleb_wynn` | Caleb Wynn | Versátil | corrida | 6 | "Corre em qualquer carro e agradece a vaga." |
| `noor_haddad` | Noor Haddad | Instintivo | corrida | 7 | "Crua, mas sem medo. Cada hora de treino aparece no carro." |
| `sofia_rinaldi` | Sofia Rinaldi | Instintivo | arena | 5 | "Veio do kart com fome. Treina como se a vaga fosse de outra." |

## Efeito de cada traço

| traço | efeito | estado |
|---|---|---|
| Instintivo | o treino do piloto principal vale para ele (`treina: true`) | ativo |
| Calculista | perde menos consistência que o segundo piloto padrão | número com o `custo_staff`, no playtest |
| Destemido | tenta mais ultrapassagens | idem (o piloto do jogador já tem agressividade 1,0: o efeito é dos outros traços terem menos) |
| Versátil | salário menor | idem |

Trocar não custa nada até o `custo_staff` existir; aí entram preço de contratação e salário
por traço.

## Arte

Entregue em 2026-10-11 (8 PNG de corpo inteiro, 1024 × 1536, com o macacão da equipe).
Instalada com `python3 tools/preparar_piloto.py <png> <id>...`: corpo 600 × 900 em
`arte/pilotos/corpo/<id>.webp` e retrato 240 × 280 recortado do rosto em
`arte/pilotos/<id>.png`, escala uniforme, sem fundo.

Na tela: a aba Equipe mostra o busto (o corpo recortado justo na silhueta, da cabeça à
coxa) com nome, traço em selo e a frase; "Trocar piloto" abre um candidato por vez de
corpo inteiro, sob um foco de luz com sombra no chão, passando com as setas da garagem.

## Pack premium (decisão do usuário, 2026-10-16)

Três pilotos de elite, vendidos juntos num pack (compra única, permanente). 100% em
tudo (ritmo no teto do treino, consistência e agressividade 1), sem cansaço. Vendido
com dinheiro real numa tela de loja própria (a criar); na seleção aparecem só depois de
comprados (flag PACK_PREMIUM) e ficam sempre no mercado.

| id | nome | vaga | estilo |
|---|---|---|---|
| `enzo_varga` | Enzo Varga | corrida | Elite |
| `gunnar_vale` | Gunnar Vale | arena | Elite |
| `scarlet_reyes` | Scarlet Reyes | arena | Elite |

## Variação por piloto

Consistência e agressividade variam por piloto, fixas (calculadora em
`EquipeJogador.variar`; faixas tiradas dos dados, `variacao_piloto.fator` no playtest).
