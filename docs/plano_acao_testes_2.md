# Plano de ação — segundo teste com pessoas (2026-10-21)

Relato de um testador depois da rodada que trouxe a pilotagem por toques, os cartões ilustrados e
o corte de falas. **O que ele aprovou:** comprar carros, disputar contra as equipes (Grid) e as
interações durante a corrida (quer mais delas). **O que ele criticou**, do mais urgente ao maior
projeto, com o diagnóstico no código, a proposta e o tamanho.

Nada aqui foi implementado: as decisões (seção final) vêm antes do código.

## Ordem recomendada

| Fase | O quê | Por quê nessa ordem | Tamanho |
| --- | --- | --- | --- |
| A | Freada com mais tempo, carros sem se atravessar, rodas na linha da curva | Defeitos que ele sentiu em toda corrida; baratos | 2–4 dias |
| B | Mais interações na corrida | O que ele mais gostou: dobrar a aposta | 1 semana |
| C | Carros com personalidade (arquétipos clássicos) | Pedido de apelo; usa o gerador de formas que já existe | 1–2 semanas |
| D | Pistas novas de verdade | Hoje são 4 traçados (+3 versões curtas e um oval) | 1–2 semanas |
| E | Caixas de pintura nas provas difíceis, treinador do piloto, ajuda automática para quem trava | Progressão nova: precisa das decisões | 2–3 semanas |

A e B podem andar juntas; C e D em paralelo depois.

## 1. "O tempo de clicar no freio está muito rápido" (fase A)

**Diagnóstico.** A janela da freada perfeita é ±0,15 s e a boa ±0,35 s (`data/simulacao.json`,
`pilotagem.frenagem`), contadas a partir do ponto de frenagem. A régua aparece 1,5 s antes. Para
quem nunca jogou, ±0,15 s é janela de jogo de ritmo exigente. Já corrigido hoje: no ACELERAR (2×) a
janela encolhia pela metade.

**Proposta.**
- Janela maior para a freada boa (±0,5 s) e a perfeita (±0,25 s), e a régua aparecendo 2,5 s
  antes. Recalibrar com `tools/calibrar_pilotagem.gd` para manter o critério já decidido (perfeita
  +0,5 posição, ruim −0,25): janela maior não pode virar vitória fácil.
- Cursor que desacelera perto da faixa verde (a mesma janela, mais fácil de ler).
- Primeiras 3 corridas com a janela ainda maior (aprendizado), sem anúncio.

## 2. "Carros muito próximos tinham uns bugs" (fase A)

**Diagnóstico.** A simulação é em uma dimensão (distância percorrida). A posição lateral é só
visual (`Corrida3D.faixas`): cada carro procura uma faixa livre e troca de faixa a 1,5 m/s. Com
três ou mais carros colados, as faixas-alvo se cruzam e os carros se atravessam ou "pulam" de
lado.

**Proposta.**
- Separação mínima lateral garantida na tela (empurrar o de trás para a faixa vizinha antes de
  encostar) e limite de troca de faixa por carro.
- Teste automático: em todas as provas do jogo, nenhuma sobreposição de carros na tela acima de
  X cm por mais de 1 quadro (a medir; o número sai da largura dos carros, não de balanceamento).

## 3. "Nas curvas parecia que a roda estava muito para fora ou para dentro" (fase A)

**Diagnóstico.** O traçado visual (`Tracado`) põe o carro por dentro da próxima curva até
`TANGENCIA_M` metros do centro, e a deriva das curvas (ângulo por g lateral, por tração) gira a
carroceria. Em curva fechada o carro desenhado sai da linha que a pista sugere e a roda passa da
zebra.

**Proposta.**
- Linha ideal desenhada de verdade: entra por fora, tangencia por dentro, sai por fora, com o
  raio de cada curva; deriva menor em curvas lentas.
- Teste automático: em todas as pistas, as quatro rodas dentro do asfalto em todo o trajeto.

## 4. "Gostei das interações, quero mais" (fase B)

**Proposta** (cada uma é uma ordem da simulação, como a freada: a corrida continua decidida e
igual com o jogo fechado):
- **Vácuo:** atrás de um rival na reta, segurar para pegar o vácuo; soltar na hora certa para a
  ultrapassagem (substitui o ATACAR fixo por um gesto).
- **Defesa:** com alguém colado atrás, deslizar o dedo para o lado em que ele vai tentar passar.
- **Largada:** tocar quando a última luz apaga (largada perfeita, queimada ou atrasada).
- **Pneu e combustível nas corridas longas:** um botão "poupar / forçar" por volta.
- Cada interação nova entra no calibrador com o mesmo critério de peso (a soma de todas pilotadas
  perfeitas fica no teto já decidido, para não tirar o valor do carro e das peças).

## 5. "Carros muito parecidos; gosto de Dodge Charger, GTR, Fusca" (fase C)

**Diagnóstico.** Dos 363 carros, só 1 usa o gerador de formas por época e categoria
(`Carroceria.ATIVOS`); os outros usam modelos 3D feitos de poucas bases, por isso parecidos. Não
podemos usar carros reais (CLAUDE.md: nada de nomes, marcas ou formas reconhecíveis), mas podemos
**evocar o tipo**, como já está na regra da arte ("evoca a época e o tipo, sem copiar").

**Proposta.**
- Arquétipos com silhueta forte no gerador de formas, sem artista: **muscle car** americano
  (capô longo, traseira curta, grade larga), **esportivo japonês turbo** (cupê baixo, asa,
  para-lamas largos), **besouro popular** (teto em arco, para-lamas separados, faróis redondos),
  **perua/van divertida**, **picape 4x4 alta**, **hot hatch** e **GT europeu**. Nomes próprios do
  jogo, nada de cópia de linha de carro real.
- Ligar o gerador para toda a frota (hoje só um carro) e distribuir os arquétipos pelos carros
  que já têm o tipo (o muscle nos cupês FR americanos dos anos 60–70, o besouro nos compactos de
  motor traseiro etc.), revisando as famílias parecidas.
- Os carros mais caros e os carros-prêmio com as formas mais marcantes (coleção com desejo).

## 6. "Muitas pistas praticamente iguais" (fase D)

**Diagnóstico.** São 8 pistas, mas 4 traçados: anel do vale, docas, serra (cada um com versão
curta), oval de testes e o misto.

**Proposta.**
- 4 traçados novos de verdade, com cara própria: **rua de cidade à noite** (curvas de 90°,
  muros), **terra/rali** (pouca aderência, salto), **circuito de montanha com descida longa** e
  **oval inclinado com retão duplo**. Ambientação pelo kit de cenário que já existe, sem arte nova.
- Variações de clima e horário nas pistas atuais (chuva já existe na simulação; noite e
  entardecer são só visual).
- Os traçados novos seguem `docs/pistas_arquetipos.md` e passam pelo validador de pistas.

## 7. "Grafismos em caixas, nas corridas difíceis, sem tempo para abrir" (fase E)

**Proposta.** Caixa de pintura como prêmio de vitória nas provas difíceis (as que o jogador
venceu com o carro mais fraco ou nas licenças altas): abre na hora, com animação curta, e dá
desenho, cor especial, rodas ou número estilizado. **Só cosmético e só ganha correndo**, nunca à
venda por dinheiro real (caixa paga com sorteio é proibida ou restrita em vários países e
desagrada o público). Repetidos viram giros.

## 8. "Treinadores e nível do piloto pelo tempo de volta" (fase E)

**Diagnóstico.** Hoje o piloto sobe de nível pelas corridas disputadas (XP) e o treino é por tempo
real.

**Proposta.**
- **Treinador** contratável na Equipe (custo por hora, como o patrocínio ao contrário), que
  acelera o treino e foca um atributo (ritmo, consistência, agressividade).
- **Evolução pelo desempenho:** o piloto ganha mais quando a volta dele bate a melhor volta
  anterior naquele carro e pista (recorde pessoal), não pela posição. Mostrar o recorde batido na
  corrida ("NOVO RECORDE PESSOAL").

## 9. "Ajuste dinâmico de dificuldade, sem deixar fácil" (fase E)

**Cuidado.** Rivais que ficam mais fracos quando você perde tiram o valor de melhorar o carro e
contradizem a progressão do jogo de referência (CLAUDE.md: a progressão fica). E rivais mais fortes
quando você ganha punem quem se esforça.

**Proposta.** Ajuste **na ajuda**, não nos rivais:
- Quem perde muitas vezes na mesma prova recebe mais ajuda de pilotagem (janela da freada maior),
  e a Mara aponta o O QUE AJUDA? com mais insistência (a cena de travado já existe).
- Quem pilota perfeito recebe desafio opcional: "corrida com o carro mais fraco" e provas
  difíceis com a caixa de pintura (item 7).
- Os rivais de cada prova continuam fixos.

## Decisões pendentes (com a recomendação)

- **E1 — Janela da freada:** perfeita ±0,25 s e boa ±0,5 s, régua 2,5 s antes, recalibrando
  para o critério já decidido (recomendado), ou manter e só ajudar quem erra.
- **E2 — Mais interações:** começar por vácuo + largada (recomendado: são as de maior emoção e
  cabem no gesto que já existe) ou pelas quatro de uma vez.
- **E3 — Carros:** arquétipos clássicos no gerador de formas para a frota inteira (recomendado)
  ou só para os ~60 carros das primeiras licenças primeiro.
- **E4 — Caixas:** só cosmético, só ganhas correndo, nunca vendidas (recomendado).
- **E5 — Dificuldade:** ajuste na ajuda e desafios opcionais, rivais fixos (recomendado), ou
  rivais que se ajustam ao jogador.
- **E6 — Treinador e evolução por recorde de volta:** entra no lugar do nível por corridas
  (recomendado) ou soma com ele.
