# Pistas: arquétipos do GT2 e proposta de pistas novas

Estudo, não build. Os traçados do jogo são originais. Daqui sai só o **comportamento**
de cada grupo de pistas (proporção de retas, raios, frenagens), nunca o desenho.

## Uso das pistas do GT2 nos eventos

Do disco (`referencia/gt2/eventos.csv`), pelo código interno da pista: total de eventos
e quantos estão entre os 38 importados.

| Código | Eventos no GT2 | Nos nossos 38 | Hoje vai para |
|---|---|---|---|
| laguna | 14 | 4 | Docas |
| mountain | 11 | 4 | Serra |
| roma | 10 | 4 | Docas |
| tahiti_t | 9 | 7 | Serra |
| parma (+ new_parmaS 6) | 9 | 4 | Serra |
| test_in2 | 8 | 3 | Anel |
| highway | 7 | 0 | Anel |
| seattle / seatt_s | 5 / 4 | 0 / 3 | Anel |
| roma_short | 5 | 4 | Docas |
| grindel | 4 | 1 | Serra |
| sprint2 | 4 | 1 | Docas |
| circuit, s_speed, testline | 3 cada | 0, 0, 1 | Anel, Anel, Docas |
| autumn, short | 2 cada | 1, 0 | Docas |
| shortway, speed, maxspeed, circle80 | 1 cada | 1, 0, 0, 0 | Docas, Anel, —, — |
| terra e rali (pikes, tahiti_d, nn_dirt…) | 24 | 0 | fora (fase 5) |
| "none" (séries de marca) | 102 | 0 | sem pista no disco |

## Por que o câmbio "Longo" não vence hoje

Medição com os 17 carros de fábrica (piloto do jogador, sem rivais):

- No Anel do Vale (reta de 1.034 m, a maior das três), a velocidade máxima atingida fica
  **20 a 70 km/h abaixo** do corte na última marcha, para todos os carros. Ninguém chega
  ao corte, então alongar a relação só tira força.
- Em 11 dos 17 carros, o corte na última marcha coincide com a velocidade de equilíbrio
  com o arrasto (ex.: 237/237 km/h). O câmbio do GT2 é feito para isso. Nos outros 6
  (Kobo, Wren, Kaze, Kestrel, Gleiter, Brute), o arrasto limita antes do corte, e
  "Longo" nunca ajuda. **É coerente, não é defeito.**
- Para "Longo" valer, a reta precisa ser longa o bastante para o carro chegar perto do
  equilíbrio. Isso só acontece em pistas do tipo "teste de velocidade", com retas muito
  longas, que o GT2 usa (test_in2, testline, maxspeed) e que nós não temos.

## Grupos de comportamento

A identificação de alguns códigos é provável, não confirmada (marcados com ?). O
comportamento de cada grupo é o que importa para o desenho.

| Grupo | Códigos | Comportamento | Hoje |
|---|---|---|---|
| 1. Retas muito longas | test_in2, testline?, maxspeed | duas retas de vários quilômetros e curvas rápidas e largas; velocidade final decide | Anel (não representa) |
| 2. Rápida fluida | highway, speed, s_speed?, circuit?, seattle, seatt_s | retas longas (~1 km) e curvas de raio grande | **Anel do Vale** |
| 3. Rua técnica | roma, roma_short, short?, shortway?, sprint2? | retas curtas e médias, muitas curvas de 90°, frenagens fortes | **Parque das Docas** |
| 4. Misto permanente | laguna, autumn | retas médias, curvas de raios variados, sequências de curvas, desníveis | Docas (não representa) |
| 5. Montanha e estrada | mountain, grindel, tahiti_t, parma | curvas fechadas encadeadas, retas curtas | **Serra Alta** |

## Proposta: duas pistas novas

**A. Pista de testes (grupo 1)**: a experimental, primeiro só headless.
- Duas retas muito longas ligadas por curvas rápidas, e uma chicane ou curva lenta
  para a aceleração também contar.
- Comprimento das retas: o mínimo para os carros com câmbio limitado pelo corte
  chegarem perto do equilíbrio. Medido com a simulação, não estimado.
- Critério de sucesso: "Longo" vence em alguns carros (os limitados pelo corte) e não
  nos limitados pelo arrasto; "Curto" e "Equilibrado" continuam melhores nas outras pistas.
- Eventos: os 3 de test_in2 e o de testline saem do Anel e vêm para cá.

**B. Circuito misto (grupo 4)**
- Retas médias, sequência de curvas de raios diferentes, uma curva lenta depois de reta.
- Critério: a ordem dos carros muda em relação ao Anel e às Docas
  (`tools/provas_profundidade.gd`: pares em que o vencedor troca entre as pistas).
- Eventos: os 4 de laguna e o de autumn saem das Docas e vêm para cá.

Ficam como estão: o Anel (grupo 2), as Docas (grupo 3) e a Serra (grupo 5).

## Ordem

1. A, headless: traçado no editor, mapeamento no importador, critério medido.
2. Se o critério for atendido: tema visual da A, recalibrar licenças e contratos.
3. B, pelo mesmo caminho.
4. Medir de novo (`tools/medir_progressao.gd`, `tools/provas_profundidade.gd`).

## Resultado da pista A (headless)

`pista_de_testes` (`data/rascunhos_pistas/pista_de_testes.json`), 4.112 m: reta de 1.200 m,
duas curvas rápidas de 250 m de raio, reta oposta de 1.255 m, curva lenta (35 m), reta de
525 m e curva média (90 m). As retas usam a mediana (~1,2 km) da distância que os carros
limitados pelo câmbio precisam, saindo de uma curva de 250 m, para chegar a 97% do
corte. Sem eventos nem visual próprio por enquanto (usa o tema padrão).

Melhor ajuste do câmbio ajustável (2 voltas, média de 3 sementes):

| Preparação | Anel do Vale | Pista de testes |
|---|---|---|
| De fábrica | curto em 12 carros, equilibrado em 5, longo em nenhum | equilibrado em 15, curto em 2, longo em nenhum |
| Motor preparado (estágio mais forte de cada peça de potência) | equilibrado em 12, longo em 3, curto em 2 | **longo em 10**, equilibrado em 7 |

O critério foi atendido: "Longo" vale para alguns carros, nas condições adequadas (motor
preparado e reta longa), e não para outros. Kumo, Ryujin, Lauf, Strecke e Brute continuam
no equilibrado mesmo preparados; Tsubame e Kaze, também. De fábrica, o câmbio do GT2 já
acaba no equilíbrio com o arrasto, e por isso "Longo" não ajuda. Preparar o motor e
alongar o câmbio é a combinação que a pista revela, como no GT2.

**No jogo:** os 3 eventos de test_in2 (Liga Regional V, etapas 1 a 3) e o de testline
(Copa de Domingo, etapa 2) correm aqui. O tema visual é um planalto seco com mesas ao
longe. Licenças recalibradas; os contratos não mudaram.

Efeito no começo do jogo: a Copa de Domingo etapa 2, segunda prova de quem começa, agora
é de velocidade máxima. Com os carros iniciais de fábrica ela não se vence só com peças
baratas, e o jogador passa pelos contratos da B antes de voltar a ela. A identificação de
testline como "retas muito longas" ainda está marcada como provável.

## Resultado da pista B (circuito misto): critério não atendido

Rascunho em `data/rascunhos_pistas/em_teste/circuito_misto.json` (2.600 m: retas de 180 a 450 m,
curvas de 25 a 150 m de raio, um "S"). Ordem dos 17 carros de fábrica (2 voltas, 3
sementes): em **0 de 136 pares** o vencedor no misto difere ao mesmo tempo do Anel e das
Docas. A ordem do misto fica entre a das duas.

Causa: de fábrica, os carros têm aderência 0,98–1,00 e freio 0,90–1,00. A simulação só os
separa por potência por peso (mais tração e câmbio). Qualquer traçado é uma mistura de
retas e curvas, e a ordem segue a mesma escala. **Pista nova não cria ordem nova enquanto
o chassi não entrar** (distribuição de peso, aderência dianteira e traseira, tração), que
o disco tem (tabela Chassis). O misto fica fora de `pistas.json` e será testado de novo
depois do chassi.

Depois da distribuição de peso (tração pelo peso no eixo motriz) a ordem dos carros
passou a variar mais entre as pistas: Brute (FR, 45% do peso atrás) cai na Serra, Kestrel
(MR, 61% atrás) sobe, os 4WD ganham nas técnicas. O misto continua no meio: 0 de 136.

## Estado (importação completa do GT2)

Feitas as duas propostas: a pista de testes (grupo 1) e o circuito misto, Colinas do Vinhedo
(`circuito_misto`, grupo 4: laguna e autumn). As versões curtas do GT2 (roma_short, seatt_s,
new_parmaS) ganharam versões curtas das nossas pistas do mesmo grupo (`docas_curta`,
`anel_curto`, `serra_curta`), com o começo da pista-mãe e um atalho que fecha a volta.
Todos os traçados são originais; só o comportamento do grupo vem do GT2.

