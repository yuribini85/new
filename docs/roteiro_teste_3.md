# Roteiro do terceiro teste com pessoas

Confere o que mudou depois do segundo teste (`docs/plano_acao_testes_2.md`, fases A a E). Cada
ponto abaixo responde a uma frase do segundo teste ou a uma novidade daquela rodada. Anote o
minuto e a frase da pessoa.

## Preparação

- Build com as ferramentas de teste (a demo web de playtest ou um build de depuração; o build
  da loja não as tem). Celular em retrato.
- As ferramentas ficam escondidas: em Configurações, tocar 5 vezes na linha da versão, no pé
  da tela. Aparecem "Modo de playtest" e "Cenários de teste".
- Duas partes com a mesma pessoa, de 20 a 25 minutos cada, com uma pausa entre elas:
  - **Parte 1, jogo novo:** save zerado. Em Configurações → Modo de playtest, ligar o registro
    e apagar o anterior.
  - **Parte 2, tudo liberado:** em Configurações → Cenários de teste, escolher **Teste
    completo** (todas as licenças, saldo de sobra, vários carros).
- Gravar a tela e o áudio. Pedir que a pessoa pense em voz alta.
- De preferência, chamar pelo menos uma pessoa do segundo teste, para comparar com o que ela
  disse, e uma pessoa nova.

## O que dizer

Só isto: "É um jogo de corrida em que você administra uma equipe. Na corrida, dá para ajudar o
piloto com toques na tela. Jogue como quiser e fale o que está pensando."

Não explicar os gestos. Se a pessoa travar por mais de 2 minutos, anotar onde e perguntar só
"o que você tentaria agora?".

## Parte 1: jogo novo (pilotagem e começo)

| # | Momento | O que observar | Resposta ao segundo teste |
|---|---|---|---|
| 1 | Largada | Tocou quando as luzes apagaram? Quantas vezes queimou? Entendeu a nota (LARGADA PERFEITA, QUEIMOU A LARGADA)? | Novidade da fase B |
| 2 | Freadas | Acerta a faixa verde? Diz que está rápido demais ou que ficou fácil? Contar as notas de 5 curvas seguidas | "O tempo de clicar no freio está muito rápido" |
| 3 | Saída de curva | Mantém o dedo na tela na saída (DEDO NA TELA)? Solta antes? | — |
| 4 | Vácuo | Colado no rival, segurou e soltou no verde? Perdeu o vácuo por segurar demais? Disse que entendeu sozinho ou só pela dica? | "Gostei das interações, quero mais" |
| 5 | Defesa | Com alguém colado atrás, viu a seta e deslizou para o lado certo? Achou o gesto natural ou confuso com o toque da freada? | "Quero mais interações" |
| 6 | Carros colados | Algum carro atravessou outro? Alguma roda muito para fora ou para dentro da curva? Pedir que aponte se vir | "Carros muito próximos tinham uns bugs"; "a roda muito para fora" |
| 7 | Perdendo | Depois de algumas derrotas na mesma prova: notou o O QUE AJUDA? pulsando? Leu a fala da Mara? Usou? | "Ajuste de dificuldade sem deixar fácil" |
| 8 | Recorde de volta | Notou "NOVO RECORDE PESSOAL DE VOLTA" e que o piloto sobe por isso? | "Nível do piloto pelo tempo de volta" |
| 9 | Fim da parte 1 | Pergunta aberta: "o que você mais gostou e o que mais irritou?" | — |

Sinal de problema: a pessoa erra a freada sempre e para de tentar; confunde o deslize da defesa
com o toque da freada; ou não percebe que os toques mudam alguma coisa.

## Parte 2: tudo liberado (conteúdo novo)

Pedir só: "Corra em pistas diferentes e olhe os carros." Se a pessoa não achar um item, sugerir
a prova pelo nome depois de 5 minutos.

| # | Onde | O que observar | Resposta ao segundo teste |
|---|---|---|---|
| 10 | Lojas e garagem | Os carros parecem diferentes entre si? Reconhece "tipos" (muscle, esportivo turbo, besouro, picape, jipe)? Qual chamou atenção? | "Carros muito parecidos; gosto de Charger, GTR, Fusca" |
| 11 | Pistas novas | Correr na Avenida das Luzes, na Estrada das Araucárias, no Mirante da Costa e no Oval da Usina. Acha as pistas diferentes umas das outras? Qual preferiu? | "Muitas pistas praticamente iguais" |
| 12 | Rali na Trilha do Cânion | Achou o aviso "precisa de pneu de terra" e comprou o pneu sozinho? Nos saltos e ondulações: reação (anotar a frase). Dá adrenalina? | Pedido do usuário: "ondulações e rampas fortes" |
| 13 | Oval da Usina | Percebeu que as curvas são inclinadas? | — |
| 14 | Resistência | Usou FORÇAR e POUPAR PNEUS? Entendeu que forçar cansa o pneu e que poupar guarda? Forçou toda volta? | Novidade da fase B |
| 15 | Caixa de pintura | Viu no cartão da prova "1ª VITÓRIA DÁ CAIXA DE PINTURA" ou o desafio do carro mais fraco? Ao ganhar: a caixa abrindo agradou? Foi à cabine de pintura usar o item? | "Grafismos em caixas, nas corridas difíceis, sem tempo para abrir" |
| 16 | Treinador | Na Equipe, entendeu o treinador (recorde em dobro por 24 h)? Contrataria? Por quê? | "Treinadores" |
| 17 | Fim | "Voltaria a jogar amanhã? O que faria primeiro?" | — |

## Depois do teste

- Do registro de playtest (Configurações → Modo de playtest): tempo em cada tela, provas
  programadas e saídas.
- Comparar com o segundo teste, item por item da tabela acima: resolvido, melhorou, igual ou
  piorou.
- Os números que dependem deste teste, para recalibrar se a pessoa reclamar:
  - Janela da freada (perfeita ±0,25 s, boa ±0,5 s) e da largada (0,35 / 0,6 s):
    `data/simulacao.json` → pilotagem.
  - Tempo para deslizar na defesa (1,5 s) e quanto a porta fica fechada (3 s): pilotagem.defesa.
  - Derrotas até a ajuda e a fala da Mara (4): `data/carreira.json` → travado.
- Levar as frases anotadas para um `docs/plano_acao_testes_3.md`, como no teste anterior.
