# Vocabulário: o que o jogador lê e o que é só do desenvolvimento

Duas línguas convivem no projeto. **A do jogador** aparece nas falas (`tools/historia/cenas.txt`),
nos botões, avisos e painéis. **A interna** fica no código, nos dados, nos documentos, nos commits e
nas conversas de desenvolvimento. A interna nunca chega à tela.

Teste rápido antes de escrever uma fala ou um texto de tela: **alguém que só jogou o jogo, sem ler
nada do projeto, entende a frase?** Se ela depende de saber como o sistema funciona por dentro, está
na língua errada.

`tests/checar_vocabulario.py` (roda em `tests/rodar.sh`) falha quando uma fala ou um texto de tela
usa um termo da lista "Nunca na tela" abaixo.

## 1. Termos do jogador

São os únicos nomes que o jogador vê. Cada coisa tem **um** nome, sempre o mesmo, e é o nome que
está escrito no botão ou na aba. A fala que manda tocar em algo usa o texto exato do botão.

### Telas e navegação
| Termo | O que é para o jogador |
| --- | --- |
| **Oficina** | onde o carro em uso recebe peças, pneus e blindagem |
| **Lojas** | onde se compram carros, cada loja com as suas marcas |
| **Corridas** | onde se escolhe a prova e se larga |
| **Carreira** | licenças, objetivos e o The Grid |
| **Equipe** | pilotos, patrocínio, Caixa e Sede |
| **Arena** | as lutas de demolição em dupla |
| **Garagem** | os carros da equipe; tem vagas |
| **ACELERAR** | deixa as corridas mais rápidas por um tempo |

### Corridas
| Termo | O que é para o jogador |
| --- | --- |
| **prova** | uma corrida da lista, com rivais, regras e prêmio. A lista, os filtros e as licenças falam em provas |
| **corrida** | uma largada de uma prova |
| **campeonato** / **série** | provas em etapas que somam pontos; o nome próprio vem do jogo ("Copa Primeira Marcha") |
| **etapa** | uma prova dentro do campeonato ("Etapa 2/3") |
| **título** | vencer um campeonato |
| **prêmio** | os giros que a posição paga |
| **carro de prêmio** | o carro que a primeira vitória numa prova dá |
| **Disputar** / **Disputar de novo** | largar numa prova / numa prova já vencida |
| **sequência** | várias corridas seguidas numa prova já vencida, que continuam com o jogo fechado |
| **repetição** | correr de novo uma prova vencida: o prêmio cai e volta inteiro em 24 h |
| **provas sem licença** | as provas que qualquer um pode correr |
| **PRÓXIMA PROVA** | a sugestão de prova para o carro em uso |
| **MAIS FRACO / PARELHO / MAIS FORTE** | como o carro se compara aos rivais da prova |
| **previsão** | a posição provável antes de correr; nunca é garantia |
| **O QUE AJUDA?** | o que, no seu saldo, melhora a posição numa prova perdida |
| **jogada** | a escolha rápida durante a corrida. Botões (o que mandar): ATACAR AGORA, ESPERAR A RETA, FECHAR A PORTA, POUPAR PNEUS; na pista, o que está acontecendo: ATAQUE!, PACIÊNCIA..., PORTA FECHADA!, POUPANDO PNEUS |
| **INDICAÇÃO DA MARA** | a jogada que a Mara sugere pelo rádio |
| **FREIE NO VERDE** | a régua antes da curva: tocar na tela quando o cursor chega na faixa verde |
| **DEDO NA TELA** | a barra da saída da curva: manter o dedo na tela até ela encher |
| **SEGURE NO VÁCUO / SOLTE!** | a barra que aparece colado no carro da frente: segurar o dedo enche; soltar com ela cheia (verde) é a ultrapassagem; segurar demais perde o vácuo. Depois de usar, demora para voltar |
| **TOQUE QUANDO APAGAR** | a largada: tocar quando as três luzes do semáforo apagam |
| **LARGADA PERFEITA / BOA LARGADA / QUEIMOU A LARGADA / LARGOU ATRASADO** | a nota do toque da largada |
| **PASSOU NO VÁCUO / PERDEU O VÁCUO** | a nota do vácuo |
| **treinador** | contratado na Equipe por 24 h, pago na hora (um prêmio de 1º lugar da sua maior licença): enquanto está lá, cada recorde de volta do piloto de corrida vale o dobro para subir de nível |
| **caixa de pintura** | o prêmio das provas difíceis (primeira vitória da National para cima, ou vitória com o carro mais fraco do grid): abre na hora e libera um desenho, logo, aro, acabamento ou família de número da cabine; sem nada novo, vira giros. Nunca à venda |
| **FREADA PERFEITA / BOA FREADA / FREOU CEDO / FREOU TARDE** | a nota do toque no FREIE |
| **SAÍDA LIMPA / PERDEU TRAÇÃO** | segurou a saída inteira / soltou antes |

### Dinheiro e tempo
| Termo | O que é para o jogador |
| --- | --- |
| **giros** | o dinheiro do jogo (ícone da moeda) |
| **combustível** | cada corrida ou luta gasta 1; a contagem fica no alto da tela |
| **tanque** | o combustível cheio; enche sozinho com o tempo, ou com um vídeo |
| **limite da renda offline** | quantas horas fora a renda offline cobre; cada título novo soma 1 h |
| **renda offline** | o que a equipe ganha com o jogo fechado (sequência de corridas e patrocínio), até um limite de horas |
| **patrocínio** / **patrocinador** / **contrato** | renda por hora com bônus quando a corrida cumpre a condição |
| **Caixa** | o resumo do dinheiro da equipe |
| **Sede** / **Escritório** | o Escritório abre vaga para mais um patrocinador |
| **meta do dia** | três objetivos diários com recompensa |

### Equipe, licenças e arena
| Termo | O que é para o jogador |
| --- | --- |
| **piloto de corrida** / **piloto de arena** | quem corre / quem luta; sem toque na tela, o piloto dirige sozinho |
| **mercado de pilotos** | os pilotos disponíveis para contratar; renova de tempos em tempos |
| **escalação** | qual carro vai para CORRIDA, ARENA 1 e ARENA 2 (Oficina) |
| **licença** (Club, Sport, National, International, Pro, Elite) | libera provas maiores |
| **treino da licença** | o tempo que o piloto treina para tirar a licença |
| **nível do piloto** | sobe com as corridas disputadas |
| **dupla** | os dois carros da equipe na arena |
| **blindagem** | chapa que aguenta mais pancada e pesa na corrida |
| **reparo** / **CONSERTAR AGORA** | o carro destruído na arena fica fora por um tempo; pagar conserta na hora |
| **The Grid** / **Grid** | as dez equipes do topo; sobe-se vencendo o desafio da equipe da vez |
| **desafio** | a disputa contra uma equipe do Grid |
| **pintura** | cores, faixas, número e acabamento do carro |
| **coleção** | os modelos diferentes que já passaram pela garagem |
| **TUTORIAL** / **PULAR TUTORIAL** | as falas que ensinam; um toque as tira e mantém a história |

## 2. Termos internos e como dizer ao jogador

| Interno (código, dados, docs) | Na tela ou na fala |
| --- | --- |
| fila, `jogador.fila`, `Fila` | **sequência** (de corridas) ou "a corrida em andamento" |
| simulação, amostras, sementes, triagem, `Mecanico` | **previsão** / "O QUE AJUDA?" |
| "nos testes", "corridas simuladas" | "previsão", "a posição provável" |
| `nivel_forca`, força relativa, potência/peso | MAIS FRACO / PARELHO / MAIS FORTE |
| fator de repetição, `repeticao.fatores` | "o prêmio cai a cada repetição" |
| `teto_offline_s`, teto offline | "limite da renda offline" (em horas) |
| provas abertas (`licenca == ""`) | **provas sem licença** (ABERTA no cartão é outra coisa: a prova que o carro pode correr) |
| grid (os carros da largada) | **rivais** / largada. "Grid" no jogo é só **The Grid** |
| momento de decisão, `MomentosCorrida`, cartão | **jogada** |
| pilotagem, ordem, `Pilotagem`, toque, nota | **FREIE NO VERDE** / **DEDO NA TELA** / **SEGURE NO VÁCUO** / **TOQUE QUANDO APAGAR** e o texto da nota |
| `dica_acerto`, rádio | **INDICAÇÃO DA MARA** |
| `derrotas_seguidas`, travado | nada: a Mara só aponta o O QUE AJUDA? |
| `carros_minimos` | "a arena abre com dois carros na garagem" |
| `reparo_s`, revenda | "volta em 1 h" / "valor de venda" |
| `uid`, ids (`tomoe_avenca`, `CW_P07`), flags, triggers, cenas | nunca: mostra o **nome** do carro, da prova, da pessoa |
| decisão N, plano, playtest, agente, perfil, cenário | nunca |
| arquétipo, referência, dados importados | nunca (nada da referência entra no jogo) |
| XP | **nível do piloto** |
| luvas (custo de contratar) | "custa X giros para contratar" |
| giro (rotação do motor) | **rotação** (rpm): "giros" no jogo é só o dinheiro |
| corte (limitador) | **rotação máxima** |
| `fator_tracao` e outras porcentagens da simulação | a ordem ("da que mais aproveita para a que menos"), nunca o número |
| siglas de tração (FF, FR, MR, RR, 4WD) e ids de categoria | tração dianteira/traseira, motor central/traseiro, 4x4; compacto, sedã... |
| "versão final", "a definir" (estado do desenvolvimento) | nunca: o texto diz o que vale hoje |
| Second Driver, Wreckage (nomes de equipe) | só como nomes da história, nunca como sistema |

## 3. Regras de escrita das falas

1. **O personagem fala do mundo dele, não do sistema.** A Mara fala de carro, conta, oficina,
   pista e rival. "Cada corrida gasta um de combustível" é do Sistema (a voz do TUTORIAL); a Mara
   diz "a oficina segue a noite toda, enquanto houver combustível".
2. **Sistema (TUTORIAL) diz onde tocar**, com o texto exato do botão ou da aba, em uma frase.
3. **Número só o que está na tela.** Nada de porcentagem, fórmula ou valor que o jogador não vê.
4. **Um nome por coisa.** Os termos da seção 1; nunca um sinônimo inventado na hora.
5. **Sem explicar a regra por dentro.** "O prêmio cai a cada repetição e volta inteiro em 24 h"
   explica o efeito; "o fator de repetição é 0,5" explica o código.
6. **Sem siglas técnicas na fala:** FF/FR/MR/4WD viram "tração dianteira/traseira/motor
   central/4x4"; cv e kg só na ficha do carro.

## 4. Nunca na tela

Lista que o `tests/checar_vocabulario.py` procura nas falas e nos textos de tela (frases entre
aspas no código da interface):

`fila` · `simulad` · `nos testes` · `semente` · `triagem` · `amostra` · `flag` · `trigger` ·
`gatilho` · `playtest` · `decisão <número>` · `provas abertas` · `grid` em minúsculas (a largada) ·
`fator` · `teto` · `uid` · `XP` · `luvas` · `versão final` · `a definir`

Exceções ficam na lista `PERMITIDO` do próprio script, com o motivo (ex.: o modo de teste, que não
existe na versão de loja).
