# The Fastfather — identidade visual, abertura e primeira corrida

Pacote do usuário (2026-10-27, `Fastfather.zip`): o logo, a arte da abertura (escritório do
chefão), da loja (galpão do Tony) e da primeira corrida, e o "LEIA-ME PRIMEIRO". O jogo
idle (antes Chrome Racing Team) passa a se chamar **The Fastfather**: máfia, 1930–1950.

## 1. O que entrou

- **Nome e logo:** título, página web (`web/shell_idle.html`), nome do app Android
  (`export_presets.cfg`, "The Fastfather"), canal de avisos e ícones (`arte/idle/icone_*`,
  o carro do logo). O identificador do pacote (`com.yuribini.chromeracingteam`) ficou: trocar
  cria outro app na Play Store e o save não passa de um para o outro.
- **Arte:** `arte/fastfather/{abertura,loja,corrida}` em WebP, recortada sem mudar a
  proporção; as poses do mesmo personagem saem do mesmo quadro (trocar de pose não pula).
- **Cenas em quadrinho** (`idle/cena_quadrinho.gd`, textos em `data/idle/cenas.json`): o
  estilo das cenas do inFAMOUS 2 — a ilustração parada que a câmera percorre, aproxima de quem
  fala e anda o fundo menos que as figuras; a passada de tinta abrindo e fechando o quadro; a
  retícula de impressão nas bordas; balões facetados e tortos como a arte low poly dos
  personagens, com sombra dura, tarja do nome e letra de gibi pulp (Bangers).
- **Lugar e ano (2026-10-27):** depois do título, preto e o cartão "BROOKLYN, NOVA YORK — 1937"
  (`cenas.json` → abertura → "cartao"); a cena do chefão sobe do preto e espera 1 s antes da
  primeira fala. 1937: o Ford Model A de 1928 já é carro de ferro-velho, e as divisões seguintes
  chegam com o tempo (Ford De Luxe 1940, Hudson Hornet 1951). Brooklyn: o cais da GAZETA DO CAIS e
  do porto no alto da tela, e a Nova York das famílias.
- **SEQUÊNCIA 1 (abertura):** as nove falas do roteiro, na ordem, com o Tony entrando no
  "Tony! Venha aqui." e o sobrinho abrindo espaço.
- **SEQUÊNCIA 2 (loja):** a garagem nova (também a aba GARAGEM): o galpão do Tony ao fundo, a
  vitrine com os quatro carros — os de divisão ainda fechada em silhueta preta, sem nome nem
  preço —, o carro escolhido girando em 3D. O primeiro carro vem do ferro-velho (tinta queimada,
  ferrugem, poeira, riscos) por 1/3 do preço: US$ 175 com os US$ 525 riscados. O chefe dá US$ 275
  (os mesmos US$ 100 de sobra de antes; o resto do jogo não muda). No "E aquele ali?" o carro do
  meio pulsa como se desse para comprar; no "Agora compre!" pulsa o ferro-velho, e então aparece
  a compra com o botão pulsando.
- **Carro na garagem (2026-10-27):** a câmera 3D segue a perspectiva da arte do galpão —
  o horizonte na linha em que a cidade encontra o chão lá fora e o carro, antes do primeiro
  toque, alinhado com o ponto de fuga da parede; o chão do carro fica logo acima da ficha, do
  mesmo tamanho em qualquer tela (em tela baixa a câmera desce). Só gira com o dedo; a seta
  curva embaixo pisca devagar. Das duas luminárias sai um cone de luz em facetas, somado à
  arte, com a mancha no chão, respirando devagar.
- **SEQUÊNCIA 3 (corrida):** o arquivo do pacote repete o texto da loja. As falas que eu tinha
  proposto (antes da largada, último lugar, primeira vitória) saíram a pedido do usuário; a
  corrida começa logo depois da compra e as falas esperam o texto dele. Depois da primeira
  vitória o carro ainda sai do ferro-velho e ganha a pintura da família (preto, o 7).
- O Don e o sobrinho das conversas da escada usam a arte nova (`corpo/chefao`, `corpo/sobrinho`).

## 2. Tipografia

| Uso | Antes | Agora | Por quê |
|---|---|---|---|
| Dinheiro e títulos de tela | Racing Sans One / Big Shoulders | **Limelight** (art déco) | letreiro dos cartazes de cinema e das fachadas dos anos 1930 |
| Falas (balões e conversas) | Barlow | **Bangers** | gibi pulp dos anos 1940; anguloso como a arte facetada |
| Botões e rótulos curtos | Big Shoulders | Big Shoulders | desenhada a partir das placas de Chicago dos anos 1920; lê bem em botão |

Licenças em `ui/fontes/LICENCA-*.txt` (OFL; Special Elite, a máquina de escrever, Apache 2.0 —
ficou fora das falas porque combina com a época mas não com o traço da arte).

## 3. O que os jogos de máfia de 1930–1950 fazem na interface (sugestões)

Estudo pelo que esses jogos mostram na tela (sem copiar nada deles):

- **Mafia (2002), cidade nos anos 1930:** cada missão abre com um cartão de capítulo em
  letreiro de cinema e data. → *Sugestão:* o "CAPÍTULO" das conversas como cartão de cinema em
  tela cheia por 1 s (letra Limelight, fundo preto, a data "Nova York, 1932").
- **Mafia II (1940–50):** dinheiro em notas, rádio de época, revistas e jornais colecionáveis.
  → *Sugestão:* manchete de jornal na subida de liga ("SOBRINHO DO BELLUCCI VENCE NO CAIS"),
  com retícula e papel amarelado; o prêmio contado como maço de notas.
- **The Godfather (2006):** respeito/medo como medidor e o "favor" como moeda de história.
  → *Sugestão:* a renda por segundo como "proteção" (o envelope do bairro), mesmo número.
- **L.A. Noire (1947):** caderno de anotações do detetive como menu. → *Sugestão:* a aba
  MISSÕES como o caderno do Tony (papel pautado, letra à mão nos riscados).
- **Empire of Sin / Omerta (anos 1920):** mapa da cidade com territórios e livro-caixa.
  → *Sugestão:* a aba PISTAS como mapa com alfinetes, e o resumo de volta ao jogo ("BEM-VINDO DE
  VOLTA!") como página do livro-caixa.
- **inFAMOUS 2:** cenas em quadrinho com movimento de câmera — já em uso (seção 1).

Aplicado agora: as letras da seção 2, os cantos chanfrados de placa art déco em todos os painéis
do jogo (`IdleUI.caixa`), o dinheiro do alto em dourado déco e as cenas em quadrinho. As
sugestões acima ficam para a decisão do usuário.

## 4. "Corridas como Super Star Race" (LEIA-ME 1)

O laço do jogo já é esse: a mesma corrida se repete sem fim, o prêmio cai pela posição, o
dinheiro entra também parado (patrocínio, arquibancada, com o app fechado) e as melhorias
sobem a posição até o primeiro lugar, que abre a liga seguinte. Não mudou nada aqui.

## 5. Melhorias aprovadas (2026-10-27)

O usuário aprovou a lista de melhorias, menos o redesenho do elenco antigo: **Mara, Theo,
Bianca, Harold e o resto do elenco antigo saem; a história é outra.** Até a história nova:

- **Elenco:** as funções que eles entregavam (ultrapassagem, pneus, patrocínio, largada
  automática, pilotos, vácuo, missões, contador, olheiros) agora vêm do Tony ou do chefão, com
  falas provisórias; nas estações de melhoria, o Tony (oficina, pneus, túnel de vento), o
  sobrinho (simulador, arquibancada) e o chefão (patrocinadores). As conversas do Moretti e o
  camarote saíram.
- **1. Corrida em 3D desde a primeira** (a vista de cima saiu; `camera_tv` vem de saída).
- **3. Interface art déco:** moldura dupla de latão com cantos em degrau (`MolduraDeco`) no
  topo, no objetivo, nas estações e na ficha da garagem; placa de latão com o nome da estação;
  botões de latão chanfrados com o preço em Limelight; a barra de baixo como balcão de madeira;
  números da corrida e o dinheiro que pipoca em Limelight.
- **4. Jornal na subida de liga** (`JornalIdle`, "GAZETA DO CAIS"): manchete que muda a cada
  liga, foto da pista em sépia com retícula, a divisão nova como EXTRA; entra girando.
- **5. Livro-caixa** no BEM-VINDO DE VOLTA (`LivroCaixa`): papel pautado, margem vermelha, uma
  linha por divisão e o TOTAL sublinhado.
- **6. Notas de dólar** voando da corrida até o dinheiro do alto no prêmio.
- **7. Cenas de marco** (`data/idle/cenas.json`): o rival Moretti aparece (escritório), a
  divisão nova abre (escritório), o segundo carro chega (galpão). Falas provisórias.
- **8. Famílias rivais:** a plaquinha de posição mostra o sobrenome da família (Moretti,
  Calabrese, Greco...), uma por equipe, sempre a mesma cor.
- **9. Público da época:** torcida de terno e chapéu na arquibancada, o apostador com o
  quadro-negro das cotações na cerca e fumaça de charuto na torre dos fiscais.
- **10. Flash e foto da vitória:** clarão branco e a foto da chegada em sépia num papel de
  jornal, por 3 s no canto do telão.
- **11. Trilha da época:** três gravações de 1924 da Wolverine Orchestra (domínio público,
  `arte/sons/LICENCA.md`), uma depois da outra; na garagem a música passa por um rádio AM.
- **12. Locutor:** pronto para tocar `locutor_largada`, `locutor_vitoria` e `locutor_chegada`
  (arte/sons/), com o filtro de rádio, assim que forem gravados. Texto sugerido:
  - largada: "Estão na linha... e lá vão eles! O carro 7 dos Bellucci larga atrás!"
  - vitória: "Inacreditável, senhoras e senhores! O sobrinho dos Bellucci cruza em primeiro!"
  - chegada: "Fim de corrida! O 7 dos Bellucci ainda tem muito o que aprender."
- **13. PULAR ›** nas cenas em quadrinho, a partir da segunda fala.
- **14. Repintura:** depois da cena da vitória, a oficina do Tony: a ferrugem some, a lataria
  escurece e entra a pintura da família com o 7.
- **15. Mural de cartazes** de corrida no fundo da aba PISTAS.

## 6. O sobrinho corre; os rapazes vão para a Rinha (2026-10-27)

Pedido do usuário: o piloto é sempre o sobrinho; a mecânica de pilotos (contratar
grátis, contratar com vídeo, juntar dois do mesmo nível) vira **os rapazes da família**,
que lutam na **Rinha das Famílias** — a arena do Chrome & Wreckage com outro nome —
rodando o tempo todo ao lado da corrida. A corrida é o idle; assistir à Rinha de vez em
quando é o tempero.

- A corrida usa sempre o piloto base (o sobrinho); o nível dos rapazes não muda a corrida.
- A Rinha (`IdleEstado.lutar_rinha`/`pagar_rinha`, aba RINHA) abre junto com os rapazes
  (2ª liga dos Bairros) e luta sem parar enquanto o app está aberto: o rapaz de nível mais
  alto, num cupê 1940, contra carros de época das famílias rivais. Não tem compras
  próprias: o carro leva as melhorias da corrida, a liga acompanha a corrida mais alta e
  o prêmio usa a escada dos Bairros (multiplicador 1 a 50,3). Luta não conta como corrida.
- Vitória dos rapazes com o jogador em outra aba: aviso no alto e o prêmio sobe.
- Aba RAPAZES: nomes da época (`data/idle/cenas.json` → "rapazes"), retratos em silhueta
  até a arte chegar, o mais forte vai sozinho para a Rinha (sem ESCALAR).
- PISTAS mostra a Rinha como "luta sozinha"; a corrida não pode ir para lá.

## 7. Tela da corrida no layout do usuário (2026-10-27)

Imagem de referência do usuário: faixa do alto (CAIXA DA FAMÍLIA, LUCRO POR SEGUNDO, engrenagem);
a corrida do cabeçalho até a oficina, com a liga (objetivo e corrida da vez, posição com os pontos
do pelotão, volta) e o PRÊMIO ATUAL com as câmeras por cima, em faixas translúcidas; a OFICINA DO
TONY com MELHORIAS (a lista completa, com +10 e MÁX.) e os cartões de melhoria rolando de lado; o
COMBUSTÍVEL ADULTERADO (vídeo, 2 por dia; bônus e duração provisórios em `idle.json` →
"combustivel"); as TRAPAÇAS DA FAMÍLIA (Ultrapassagem = Corrida arranjada, Vácuo = Sabotagem; Fiscal
comprado fechado até ter efeito). Pedidos do usuário na mesma rodada: a letra ornamentada (Limelight)
só no caixa e no prêmio; a barra de baixo com o fundo da de cima; bordas finas e cantos pequenos;
sem ícones pequenos nem placas atrás da posição, da volta e da aba escolhida; sem o Tony e a fala
na oficina; sem barra de andamento. As abas continuam as de antes.
