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
- **SEQUÊNCIA 1 (abertura):** as nove falas do roteiro, na ordem, com o Tony entrando no
  "Tony! Venha aqui." e o sobrinho abrindo espaço.
- **SEQUÊNCIA 2 (loja):** a garagem nova (também a aba GARAGEM): o galpão do Tony ao fundo, a
  vitrine com os quatro carros — os de divisão ainda fechada em silhueta preta, sem nome nem
  preço —, o carro escolhido girando em 3D. O primeiro carro vem do ferro-velho (tinta queimada,
  ferrugem, poeira, riscos) por 1/3 do preço: US$ 175 com os US$ 525 riscados. O chefe dá US$ 275
  (os mesmos US$ 100 de sobra de antes; o resto do jogo não muda). No "E aquele ali?" o carro do
  meio pulsa como se desse para comprar; no "Agora compre!" pulsa o ferro-velho, e então aparece
  a compra com o botão pulsando.
- **SEQUÊNCIA 3 (corrida):** o arquivo do pacote repete o texto da loja, então as falas são
  **proposta** (trocar em `data/idle/cenas.json`): antes da largada (Tony com a caixa de
  ferramentas, o sobrinho de braços cruzados), depois da primeira corrida (Tony na cerca:
  "Último..."), e na primeira vitória (Tony comemorando; ele promete pintar o carro). Depois da
  vitória o carro sai do ferro-velho e ganha a pintura da família (preto, o 13).
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
