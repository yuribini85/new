# Plano de ação — segundo teste com pessoas (2026-10-21)

Relato de um testador depois da rodada que trouxe a pilotagem por toques, os cartões ilustrados e
o corte de falas. **O que ele aprovou:** comprar carros, disputar contra as equipes (Grid) e as
interações durante a corrida (quer mais delas). **O que ele criticou**, do mais urgente ao maior
projeto, com o diagnóstico no código, a proposta e o tamanho.

Decisões E1–E6 aprovadas pelo usuário com a recomendação (decisão 130 em `docs/plano_mvp.md`).

## Andamento

- **Fase A feita** (2026-10-21):
  - Freada: faixa perfeita ±0,25 s, boa ±0,5 s, régua 2,5 s antes. A freada boa ou perfeita
    tocada antes do ponto vale a partir do ponto. Recalibrado (`tools/calibrar_pilotagem.gd`,
    política nova "beira": toda freada no começo da faixa verde).
  - Carros colados: separação firme na tela (dois carros lado a lado ficam a 2 m de lado, na
    hora; quem está na beira não sai da pista) e a separação suave começa mais cedo. Medido por
    `tools/medir_corrida_visual.gd` em 4 provas reais (23 mil quadros): quadros com carros um
    dentro do outro de 443 para 19 (os que restam são as batidas de propósito e quinas).
  - Curvas: a linha não vai de lado mais que 0,12 m por metro andado (antes cruzava a pista em
    poucos metros e o carro andava de caranguejo); a frente do carro segue o rumo exato da pista
    mais o desvio da linha (antes girava com atraso e ficava para fora em toda curva); deriva
    limitada a 0,1 rad. Diferença entre a frente e a direção em que o carro anda: 99% abaixo de
    4–8° (antes 13–26°).
  - Teste automático: seis carros num bolo de 6 m em duas pistas, nenhum dentro do outro,
    rodas até a zebra, frente na direção do movimento.
- **Fase B, parte 1 feita** (2026-10-21): largada e vácuo (E2).
  - Largada: com a pilotagem, as três luzes ficam acesas mais um tempo que varia por corrida
    (sorteado pela semente) e o aviso TOQUE QUANDO APAGAR aparece. Tocar ao apagarem: LARGADA
    PERFEITA (até 0,35 s), BOA LARGADA (até 0,6 s), LARGOU ATRASADO (até 1,5 s); com as luzes
    acesas, QUEIMOU A LARGADA. A corrida ao vivo espera no apagar das luzes até o toque, e a
    ordem vale desde ali (gravada na fila: termina igual com o jogo fechado). A largada boa ou
    perfeita pode ganhar posição antes da primeira zona de ultrapassagem (o grid sai em fila).
  - Vácuo no lugar do botão ATACAR: colado no rival, SEGURE NO VÁCUO; a barra enche em 1,2 s e
    fica verde (SOLTE!) por 0,8 s; soltar no verde é a ultrapassagem (PASSOU NO VÁCUO), segurar
    demais é PERDEU O VÁCUO. Depois recarrega, como o ATACAR.
  - Correção na simulação: preso atrás de outro carro, a aceleração extra das ordens (largada,
    saída de curva) agora conta para saber quem é mais rápido (antes era ignorada).
  - Calibrado com a largada (60 corridas): tudo perfeito +0,52 (teto +0,5), bom +0,35, ruim
    −0,20, só a largada +0,08, só o vácuo +0,07.
  - Fase B, parte 2 (2026-10-22): **defesa** (com um rival colado atrás, ele sai para um lado;
    deslizar o dedo para esse lado fecha a porta por 3 s: ninguém passa) e **FORÇAR / POUPAR
    PNEUS** nas resistências (recomendação aceita: "pneu que cansa", sem sistema de desgaste:
    forçar anda 1% mais até o fim da volta e cansa 1,5% nas duas seguintes; poupar anda 1% menos
    e guarda o pneu, e o próximo forçar não cansa). Com as pistas novas da fase D a corrida
    perfeita tinha subido para +0,72 posição; os bônus da freada e da saída foram recalibrados
    e ela voltou a +0,55 (ruim -0,23); a freada boa foi a 1,005 para valer metade da perfeita (+0,27). Números na nota de `data/simulacao.json`.
- **Fase C, primeira passada** (2026-10-22): arquétipos no gerador (`Carroceria.arquetipo`,
  `_arquetipo`), pela ficha do carro, sobre a forma medida:
  - muscle car (cupê americano até 1979, 23 carros): capô longo com tomada de ar, teto baixo
    em fastback, quadril largo e alto sobre a roda de trás;
  - esportivo turbo (cupê japonês forte desde 1985, 14): baixo, para-lamas alargados, asa;
  - besouro (motor atrás, até 1979, 9): teto em arco, capô e traseira caindo, corpo estreito
    entre para-lamas que saltam, faróis redondos;
  - hot hatch (compacto forte desde 1976, 40): largo, baixo, aba no fim do teto;
  - GT (cupê europeu forte, 32): cabine recuada (capô longo) em fastback;
  - picape 4x4 (13) e jipe (24): suspensão alta e rodas maiores; perua (1).
  - Folha de comparação: `tools/folha_arquetipos.gd` (antes e depois, precisa de xvfb-run).
  - Aprovado pelo usuário pela folha (2026-10-22: "Aprovado pode seguir").
- **Fase D feita** (2026-10-22): três traçados novos, cada um para os eventos de uma pista da
  referência que caía numa pista repetida (mesmo grupo de comportamento, docs/pistas_arquetipos.md):
  - **Avenida das Luzes** (`avenida_noturna`, 2,1 km): quarteirões de 90°, uma chicane, à
    noite com luz fria de neon. Recebe os eventos de roma (antes no Cais Velho).
  - **Estrada das Araucárias** (`estrada_das_araucarias`, 2,3 km): grampos em zigue-zague e a
    descida longa, entre pinheiros, de manhã. Recebe os de tahiti_t (antes no Alto da Capela).
  - **Mirante da Costa** (`mirante_da_costa`, 2,6 km): curvas médias e rápidas à beira-mar, ao
    pôr do sol. Recebe os de parma (antes no Alto da Capela).
  - As copas de marca giram também pelas três. 54 das 204 provas correm nelas.
  - Traçados fechados por `tools/fechar_pista.py` (rascunhos em `data/rascunhos_pistas/`), sem
    trecho a menos de 44 m de outro fora da vizinhança; nomes das curvas em `data/curvas.json`.
  - Licenças recalibradas pelo fluxo (`tools/calibrar_licencas.gd`): só os tempos de ouro
    mudaram (~1,2 s mais lentos), porque a calibração anterior era de antes de mudanças da
    simulação; os testes de licença continuam nas mesmas pistas.
  - Fica para depois: o oval inclinado (o Oval do Planalto já faz o papel de retas longas).
  - **Trilha do Cânion** (`trilha_do_canion`, 2,2 km, terra; pedido do usuário: "ondulações e
    rampas fortes para dar adrenalina"): três trechos de costelas e quatro rampas de 1,8 a 2,6 m
    com salto. O relevo é só da tela (`visual/relevo.gd`): o carro voa da boca da rampa com a
    velocidade da simulação, cai com tranco e deixa sombra no chão.
  - Rali: os 27 eventos de terra da referência (licenças National, International e Sport, 1
    rival) correm nela. Exigem o **pneu de terra**, como na referência (aderência 1,0 na terra,
    igual à do pneu de fábrica no asfalto, porque todos correm com ele; preço = mediana do
    estágio da referência). Recomendação aceita pelo usuário.
- **Fase E feita** (2026-10-22; recomendações aceitas: "Pode seguir" e "CONTINUA"):
  - Ajuda para quem trava (E5): cada prova guarda as derrotas seguidas; com 4 (o número do
    travado) numa prova não vencida, a faixa da freada boa fica 50% maior até a vitória, sem aviso.
  - Caixa de pintura (E4, `CaixaPintura`): na primeira vitória de cada prova da National para
    cima e em qualquer vitória com o carro mais fraco do grid (menor potência por peso, com
    peças). Abre na hora e libera um item trancado da cabine: os desenhos e logos que o Grid
    ainda não liberou e os exclusivos de caixa (aros turbina, estrela e dez; acabamento
    metálico; números pintado à mão e serifado). Sem nada a liberar, um prêmio de 1º lugar
    da licença em giros. Aparece como selo na janela do resultado; configuração em
    `data/equipe.json` → caixas.
  - Evolução pelo recorde de volta (E6, `Carreira.registrar_volta`): o piloto de corrida sobe
    quando a melhor volta da corrida bate o recorde pessoal daquele carro naquela pista; corrida
    sem recorde não conta. Medido (`tools/medir_recordes.gd`): 64% das corridas batem recorde;
    um nível a cada 2 recordes ≈ 3,1 corridas, a média de antes (3). "NOVO RECORDE PESSOAL DE
    VOLTA" no resultado; na Equipe, a barra do próximo nível conta recordes.
  - Treinador (E6): com 20% dos prêmios o caminho ficava pior (36 provas vencidas contra 67 no
    mesmo tempo). Decisão do usuário ("Sim" à recomendação): contrato de 24 h pago na hora (um
    prêmio de 1º da maior licença), recorde em dobro, sem parte dos prêmios. Botão na Equipe,
    no cartão do piloto de corrida. Medido com piloto contratado (`tools/medir_recordes.gd`):
    em 3 h de campanha o caminho é o mesmo com e sem treinador, porque o nível do piloto só tem
    teto a partir da International (equipe.json → treino.teto); lá, o treinador leva o piloto ao
    teto da licença na metade dos recordes (3 em vez de 6). O ganho total segue limitado pelo
    teto calibrado do treino (até 10% do caminho).
  - Insistência para quem trava (E5): a Mara volta a apontar o O QUE AJUDA? a cada 4 derrotas
    seguidas (a partir da segunda vez, com a fala CW_TR02, mais dura), e o botão O QUE AJUDA?
    pulsa no cartão da prova travada até a vitória.
  - Desafio opcional à vista (E5): o cartão da prova diz o que vale caixa de pintura (1ª
    vitória da National para cima; seu carro é o mais fraco do grid; ou, em prova já vencida,
    o desafio de vencer com o carro mais fraco).
  - A caixa abre na janela do resultado com animação curta (`CaixaAbrindo`, 1,4 s): treme, a
    tampa salta com faíscas e o item aparece embaixo.
  - Ficou de fora, de propósito: o treinador com foco num atributo (o treinador escolhido pelo
    usuário, recorde em dobro, já cobre o pedido).

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

**Diagnóstico** (corrigido na fase C). Os 363 carros já usam o gerador de formas (as épocas e
categorias liberadas em `Carroceria.LIBERADOS`), mas a forma de cada um vem das medidas dos
modelos 3D antigos, feitos de poucas bases: por isso parecidos. Não
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
