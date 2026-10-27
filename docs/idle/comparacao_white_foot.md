# Chrome Racing Team × White Foot: por que o CRT ainda não é produto (2026-10-27)

Pedido do usuário: analisar o White Foot (outro idle dele, em Godot) e entender por que o CRT está
longe de ser produto. Fontes: `docs/VERSAO_ATUAL.md`, `docs/ECONOMIA.md`, `docs/RITMO.md` e os
`qa/` do pacote do White Foot, mais a abertura rodada no navegador (390×844).

## O que o White Foot tem e o CRT não

| | White Foot | CRT hoje |
|---|---|---|
| **Fantasia** | Você é o capataz de um Senhor que ergue uma fortaleza. Tom de humor sombrio (o Mago chuta o primeiro servo da torre). Uma frase vende o jogo. | "Uma equipe de corrida que corre sozinha." Não tem protagonista, conflito nem humor. As conversas existem só para abrir funções. |
| **Marca e abertura** | Tela de título com máscara do elmo, logotipo, toque para começar, cena de abertura com fala e um toque do jogador que vira o primeiro ato. | O app abre direto numa conversa de tutorial. Não tem título, logotipo nem cena. |
| **Direção de arte** | Uma linguagem só, escrita e seguida em tudo: noite fria, contraluz, recorte dourado, duas fontes OFL próprias, ícones redesenhados em 256 px. Orcs 3D convertidos em folhas de sprites, no mesmo estilo do cenário. | Uma colagem: carros 3D do C&W, pontos sobre fundo preto, retratos e corpos do C&W, fotos de pista no topo e cartões de interface genéricos. Parece ferramenta, não jogo. |
| **O progresso aparece no mundo** | Uma fortaleza vertical contínua. Cada andar novo entra no escuro e um servo acende as tochas. Trabalhadores andam, carregam e sobem de elevador. A chaminé solta mais fumaça com os níveis, os andares envelhecem nos níveis 25/50/100 e o horizonte mostra os domínios tomados. | O progresso fica em cartões e números. A cena da corrida é sempre a mesma; muda só o modelo do carro quando você sobe de liga. |
| **O que o jogador faz** | Toca na estação antes de automatizar, compra +1/+10/MÁX (segurar acelera), ergue obras, nomeia e promove capatazes, torce na disputa, saqueia, marcha e funde. | Toca em LARGAR até a largada automática e compra o cartão mais barato. |
| **Economia** | Cadeia de recursos (madeira → carvão → ferro → armas → horda → domínio). Estações sem teto, com marco a cada 25 níveis (×2 e um trabalhador a mais). Notação K/M/B/aa. | Uma moeda e seis melhorias com teto; ligas e modalidades. Não tem marco. |
| **Retenção** | Ordens em capítulos que pagam Marcas, baú diário em ciclo de 7, Encomendas do Senhor (pedido de 10 min), Criatura (evento tocável aleatório), clima, diário da torre, Nova Era com árvore de Glória (prestígio). | Missões diárias. Nada aleatório, sem prestígio, sem login diário. |
| **Personagens** | Capatazes com traço visível (Corpulento, Avarento, Berrador, Veterano), tique de temperamento, nível e disputa pelo posto. Toque longo num Orc mostra a ficha com nome e feito. | 76 pilotos com perfil, frase e fusão. Ficam numa grade; não aparecem fazendo nada. |
| **Anúncio dentro da história** | Rufadores: tambores dão tempo em dobro, 30 min por anúncio, acumulando até 2 h. Saco da Criatura ×2. Tela de volta ×2. Pacto do Senhor (sem anúncios + dobro permanente). | PRÊMIO x2 a cada corrida (~80 s), intersticial, "sem anúncios" sem preço. |
| **Produto completo** | Configurações com comunidade, preferências, exportar/importar progresso por código, apagar conta, acessibilidade (tremor, clarões, interface ampliada, vibração por tipo) e modo leve automático por QPS. | Música, efeitos, gráficos leves e avisos. |
| **Processo** | Laboratório: um build à parte que salta para 15 momentos do jogo, de 1x a 10x. Simulação de ritmo com "trechos sem compra > 3 min". Medição de desempenho por andar. Uma página de "versão atual" como fonte única. | Robô e calibrador (bons), fotos e checagem de tela. Não dá para pular para um momento nem há métrica de tempo morto além da maior espera. |

O White Foot também tem pontos fracos que valem não repetir: no começo, metade da tela é chão
escuro vazio, e "Entrada da Mina · Mata Nv. 15" é texto de engenheiro. O conjunto, porém, é de
produto; o CRT ainda é um protótipo de sistemas.

## Por que o CRT ficou assim

1. **Nasceu como reaproveitamento.** O pedido era "publicar rápido com o que o C&W já tem"
   (`docs/idle/plano.md`). O CRT herdou sistemas e assets, mas não ganhou uma fantasia nem uma arte
   próprias.
2. **O verbo central é assistir.** No White Foot o jogador faz a fortaleza crescer com as mãos
   antes de automatizar. No CRT a corrida é resolvida sem ele, e a compra é um cartão.
3. **O mundo não guarda o progresso.** Tudo o que o jogador conquista vira número. Nada na tela
   lembra a liga 3 quando ele está na liga 6.
4. **Os polimentos foram em cima de uma base sem identidade.** Texto, som, botões e tutorial
   melhoraram uma tela que continua sem alma.

## Sugestões (em ordem de impacto)

### 1. Fantasia e tom (decisão do usuário, antes de tudo)
Uma frase e um conflito. Exemplo, usando o elenco que já existe: *"Mara herdou uma oficina
falida e um carro velho. O dono da equipe rival comprou a pista da cidade."* Um antagonista
recorrente que aparece nas ligas e nas conversas dá humor e motivo. A tela de título com logotipo
e uma abertura de 20 s com um toque do jogador como primeiro ato, como no White Foot.

### 2. Uma direção de arte só: a transmissão de TV
O CRT já tem a ideia da "transmissão na TV". Ela pode virar a linguagem do jogo inteiro: a
interface é o pacote gráfico de uma emissora (torre de tempos, lower thirds com nome do piloto,
placar de ligas como vinheta, replays), com uma paleta e duas fontes definidas e escritas num
documento de direção de arte, como o White Foot fez. A vista de cima com pontos vira o "mapa de
cronometragem" da emissora, bonito de propósito, e não a falta de TV.

### 3. O complexo da equipe como mundo que cresce
Trocar a tela "corrida + cartões" por um corte contínuo do complexo da equipe, rolando como a
fortaleza: box, oficina de motores, banco de pneus, simulador do piloto, sala dos patrocinadores
e arquibancada. Cada melhoria é uma estação com mecânicos trabalhando, e a peça sai da estação e
vai ao carro no box. A corrida fica no alto ou num painel de TV. Estações que envelhecem nos níveis
25/50/100 e a garagem que vira fábrica são o progresso que se vê.

### 4. Mãos antes da automação, e compra com peso
- **No começo o jogador toca:** na estação para montar a peça e no box para o pit stop. O chefe
  de cada estação automatiza depois (o capataz do White Foot).
- **Compra:** +1, +10 e MÁX, segurar para comprar em sequência, marco a cada 25 níveis (×2 e um
  mecânico a mais na estação) e notação K/M/B.

### 4b. Números que pipocam e saltam (pedido do usuário na aprovação)
Como o White Foot faz: a compra afunda e salta o botão com clarão dourado, faíscas estouram dele e
o nível novo pipoca acima ("Nv. 13", e "×3" nas compras seguidas, cada vez maior e mais tremido,
com o tom subindo); o dinheiro do topo salta quando entra prêmio ("+$300" pipoca ao lado) e afunda
quando gasta; a renda pipoca de leve no topo a cada poucos segundos; o botão que passa a poder ser
tocado pulsa uma vez; pódio solta faíscas. Feito no CRT atual (`idle/efeitos_idle.gd`,
`IdleUI.premiar` e `IdleUI.saltar`), reaproveitável na reconstrução.

### 5. Personagens que vivem na tela
Os chefes de estação com traço e tique, vindos dos personagens que o CRT já tem: Mara, Harold,
Kenji… Pilotos que andam no box, ficha no toque longo, disputa pela vaga de titular (a fusão vira
uma cena).

### 6. Retenção do gênero
- **Baú diário:** ciclo de 7.
- **Encomenda do patrocinador:** "faça X em 10 min".
- **Evento tocável aleatório:** um fã com autógrafo ou o drone da emissora, com recompensa e ×2
  por anúncio.
- **Clima que muda a corrida.**
- **Nova Temporada:** prestígio com árvore permanente.

### 7. Anúncio dentro da história
Trocar o PRÊMIO x2 a cada corrida por:
- **"Torcida no autódromo":** dobro por 30 min por anúncio, acumulando até 2 h.
- **×2 na tela de volta.**
- **×2 no evento tocável.**
- **"Contrato de fábrica":** sem anúncios e dobro permanente, o produto da loja.

### 8. Produto completo e processo
- **Configurações:** exportar/importar progresso por código, apagar dados, acessibilidade (tremor,
  clarões, interface ampliada) e modo leve automático por QPS.
- **Laboratório:** um build que salta para cada momento do jogo, de 1x a 10x.
- **Métrica de "tempo sem compra > 3 min"** no robô e no calibrador.
- **Uma página "versão atual"** como fonte única do que o jogo é.

## Aprovado pelo usuário (2026-10-27)
Tudo, mais o item 4b. A fantasia de exemplo (Mara, a oficina falida e o rival dono da pista), a
transmissão de TV como linguagem e o complexo da equipe no lugar dos cartões viram o ponto de
partida do documento de direção e das maquetes.

## Ordem recomendada
1. Fantasia, tom e direção de arte (itens 1 e 2): decisões do usuário, um documento curto e uma
   maquete de tela antes de código.
2. O complexo da equipe com 2–3 estações vivas e a compra +1/+10/MÁX com marcos (itens 3 e 4),
   no lugar dos cartões.
3. Personagens nas estações, retenção e anúncio na história (itens 5–7).
4. Produto completo e laboratório (item 8), junto com a pendência de lançamento de
   `docs/idle/plano.md`.

É uma reconstrução da camada de apresentação e do loop de interação. A simulação de corrida, a
economia por ligas, o save, o som, os testes e as ferramentas do CRT continuam servindo.
