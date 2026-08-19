# THE WAY BACK — Prompts de revisão das telas

Um prompt por tela, para regenerar corrigindo o que conflita com o design fechado.
Todos assumem **paisagem 16:9**, HUD idêntico e a mesma direção de arte já validada.

**Bloco de estilo comum** — cole no fim de qualquer prompt:

```
STYLE: dark storybook game UI, aged parchment panels with torn edges over a near-black
background, fine ink linework with muted watercolour washes, Arthur Rackham inspired.
Restrained earthy palette: umber, ochre, bone, deep green, dull gold. Serif display type
for titles, small caps for labels. Ornate thin borders and corner flourishes, engraved
icons, no flat modern UI, no bright saturated colours, no neon, no gradients, no drop
shadows, no emoji. Landscape 16:9, clean readable hierarchy.
```

**HUD comum** — repetir literalmente em todas:

```
TOP BAR (identical across all screens): a black band with engraved icons and values —
bread 412 COMIDA, timber 1.204 MADEIRA, coin 3.870 OURO, water drop 86 FÔLEGO, gem
12 DIAMANTES, two figures 18/24 GENTE, crate 1,9k/3k DEPÓSITO. On the right, a framed
box reading DIA 23 / Manhã with a small sun icon, and a gear button. Far left, a small
village banner tab.
```

---

## 1 · Biblioteca (a versão de cards) — a manter

Mudanças: devolver o diamante ao HUD, e a líder passa a ser a personagem fixa.

```
Landscape 16:9 game UI screen: BIBLIOTECA.

LEFT COLUMN (parchment panel): title BIBLIOTECA with a short intro paragraph. Below, a
framed portrait card of the library keeper — a young peasant woman in her twenties, dark
braid over the shoulder, plain blue-grey overdress, ink-stained fingers, holding a scroll,
labelled A FILHA SÁBIA · Nível 3 · "Aumenta a velocidade de leitura em +12%". Under it a
list of three assigned villagers with small portraits, each with a reading bonus. A fourth
slot is locked with a padlock and the note "Desbloqueia no nível IV". Bottom: a VOLTAR button.

CENTRE: a row of six category tabs with engraved icons — TODOS, FAMÍLIA, ADVERTÊNCIAS,
MAGIA, CRIATURAS, OBJETOS. Under it "CONTOS ENCONTRADOS 12 / 58" and a grid of ten tall
tale cards. Found tales show an illustrated cover and a LER button; undiscovered ones show
a locked clasped black book with an hourglass and "Descobre em 2h 14min". One card is
highlighted with a gold border.

RIGHT COLUMN: header LENDO AGORA. A tale title, a wide illustration, a short synopsis, a
gold PROGRESSO DA LEITURA bar at 62% with "Tempo restante: 1h 37min". Below, a section
ENSINA ESTE CONTO with an icon and the bonus it grants. Bottom: a wide dark button
ACELERAR LEITURA with a gem icon and the number 10.

[bloco de estilo + HUD]
```

---

## 2 · Construções

Mudanças: o painel direito ganha **nível atual e próximo**, e a arte central passa a ser
o Gigante trabalhando sozinho — ele é o construtor.

```
Landscape 16:9 game UI screen: CONSTRUÇÕES.

LEFT COLUMN: title CONSTRUÇÕES with a short intro. Below, a vertical list of category rows
with engraved icons and counters: TODAS AS CONSTRUÇÕES 12/18, RECURSOS 4/6, ARMAZENAMENTO
2/4, ALIMENTAÇÃO 2/4, DEFESA 2/4, COMUNIDADE 1/3, ESPECIAIS 1/2. The first row is
highlighted. Bottom: PROGRESSO GERAL with a horizontal bar reading "12 / 18 construções
erguidas".

CENTRE: a large framed illustration of an enormous giant, twice the height of a man,
raising a heavy timber frame alone while two small villagers work at his feet placing
stone blocks. Overcast light, pine forest and a watchtower behind. A caption plaque below
reads ENGENHARIA DE MADEIRA with one line of description.

RIGHT COLUMN: a selected building card — small header with icon, name CABANA DE PESCA and
NÍVEL 1. A framed illustration of the building. Two lines of description. Then a stats
table with rows: PRODUÇÃO POR CICLO showing "— → +8 PEIXES", CUSTO DE CONSTRUÇÃO with
timber 120 and coin 80, TEMPO DE CONSTRUÇÃO 00:00:30, and REQUISITOS showing 2 villagers.
Bottom: a wide black CONSTRUIR button with a hammer icon.

[bloco de estilo + HUD]
```

---

## 3 · Bestiário

Mudança essencial: **não há combate no jogo.** Fora VIDA, ATAQUE, DEFESA, VELOCIDADE.
Entram observação, comportamento e o que a criatura faz à vila.

```
Landscape 16:9 game UI screen: BESTIÁRIO.

LEFT COLUMN: title BESTIÁRIO with a two-line intro. A vertical list of creature groups
with engraved icons and counters: CORVOS 6/18, RAPOSAS 5/16, LOBOS 4/14, LADRÕES 3/12,
GIGANTES 1/6, CRIATURAS MÍTICAS 2/10, OUTRAS AMEAÇAS 7/20. The first is highlighted.
Bottom: CRIATURAS DESCOBERTAS 28 / 96 with a bar.

CENTRE: creature name CORVOS with subtitle "Ameaça Comum". A large framed illustration of
crows perched on a fence post above a misty village. Two lines of description below.
Then VARIANTES DESCOBERTAS: a row of six small cards, three revealed with names and star
ratings, three locked showing padlocks and "???".

RIGHT COLUMN — observation, never combat statistics. Sections with engraved icons:
O QUE FAZEM — three short lines about stealing crops and following the sick.
QUANDO APARECEM — night, and more often when the village is hungry.
COMO AFASTAR — three lines: scaring them by hand, the watchtower, keeping stores closed.
ONDE FORAM VISTOS — clareiras, restos de vilarejos, campos abandonados.
A dead tree and a skull illustration in the lower right corner.
Bottom note: "Mais informações são reveladas ao observar e registrar a criatura."
NO health bars, NO attack or defence values, NO numeric stat block.

[bloco de estilo + HUD]
```

---

## 4 · Preparar expedição

Mudança: **uma mochila por expedicionário**, não uma só. E o painel esquerdo mostra o
requisito de Fôlego.

```
Landscape 16:9 game UI screen: PREPARAR EXPEDIÇÃO.

LEFT COLUMN: title PREPARAR EXPEDIÇÃO with the region name VALE DAS RAPOSAS below it and
two lines of atmospheric description. Three small framed stats side by side: DURAÇÃO
30-45 min, PERIGO shown as three diamonds with two filled, FÔLEGO NECESSÁRIO 14. Below,
EXPEDICIONÁRIOS 2/3: two selected character cards with portraits, name, role, level and a
small risk indicator, each with a remove X, plus an empty "+ Adicionar expedicionário"
slot.

CENTRE: an open travel pack seen from above, its interior a grid of square slots holding
irregular rectangular items — a long loaf across four slots, salted meat blocks, timber
bundles, a fish, a ham, two bottles, herbs, a coil of rope. Header above reads MOCHILA DE
MARIA 12/15. Directly under the pack, a row of three small tabs with tiny portraits —
MARIA 12/15, MIKEL 6/8, BERTA 5/8 — the first one selected, so each expedition member
carries a separate smaller pack. A caption below: "Arraste os itens para organizar o
espaço da mochila."

RIGHT COLUMN: ITENS DISPONÍVEIS, a list of resources with icons, name, type and a
stepper with quantity. Below, a detail card for the selected item with its illustration
and two lines. Bottom: a wide black INICIAR EXPEDIÇÃO button with an arrow, and a
secondary VOLTAR button.

[bloco de estilo + HUD]
```

---

## 5 · Cabana do Lenhador

Mudanças: produção por minuto e não por segundo, e **fora o bloco "Melhorias do Edifício"** —
melhoria vem de nível de mina e de itens de expedição. No lugar, o item especial encontrado.

```
Landscape 16:9 game UI screen: interior panel of CABANA DO LENHADOR.

LEFT: a large framed illustration of a log cabin at the forest edge, two woodcutters
splitting logs, stacked timber, a chopping block with an axe, smoke from the chimney.
Overlaid at the top left, the building name CABANA DO LENHADOR and NÍVEL 3 shown as three
diamonds with two filled, plus two lines of description.

CENTRE PANEL (parchment): PRODUÇÃO with a timber icon and "+3,6 /min MADEIRA" in green.
Below, CAPACIDADE with "3/5 LENHADORES". Below, ARMAZENAMENTO "1.020 / 1.500" with a bar.
Bottom: a wide black MELHORAR button and, under it, the cost as timber 600 and coin 240.

RIGHT COLUMN: header LENHADORES 3/5, a list of three worker cards, each with a small
portrait, name, level, individual output "+1,2 /min" and a remove X. Below them an empty
slot reading "+ Adicionar lenhador — Crianças órfãs podem crescer e preencher esta vaga."
Under that, a separate framed section ITEM ENCONTRADO showing one engraved special item —
an iron-headed axe — with its name, the bonus it grants, and two empty locked slots
labelled "Encontrado em expedição".
NO building upgrade shop, NO purchasable improvement rows.

[bloco de estilo + HUD]
```

---

## 6 · Evento da Senhora Holle — quase final

Mudança pequena: deixar explícito que a falha é **chuva de piche com queda de produção**,
e que o prazo é o dia da vila.

```
Landscape 16:9 game UI screen: EVENT — SENHORA HOLLE.

LEFT HALF: a tall framed illustration of a severe pale woman with wild white curls in a
heavy grey feathered cloak, snow falling from her open palm, a snow-covered village behind
her. She fills the full height of the panel.

RIGHT HALF (parchment): small label EVENTO above the title SENHORA HOLLE. A line of
description, then a two-line quotation in italics, then one closing line. Section header
O QUE ELA PEDE with three request rows, each with an engraved icon, item name, one line of
description, a fraction and a segmented progress bar: Pão 420/600 in red, Carne 180/180 in
green with a check mark, Madeira 300/400 in red.

RIGHT SIDE COLUMN, three stacked framed boxes: an hourglass with 18:42 TEMPO RESTANTE; a
box headed SE FALHAR reading "Chuva de piche sobre a vila. Toda a produção cai 30% até a
entrega ser completada." with a small snowflake-like emblem; and a circular question-mark
button reading "O QUE ACONTECE SE EU FALHAR?".

Bottom: a wide black ENTREGAR button with an arrow.

[bloco de estilo + HUD]
```

---

## 7 · Diálogo — quase final

Mudanças: emoção correta ao texto, e espaço para o indicador de quem fala.

```
Landscape 16:9 game UI screen: DIALOGUE.

A single large parchment card with torn stained edges fills the screen over a blurred
village background at dusk.

LEFT THIRD: a half-body portrait of a young woman in her early thirties, weathered and
lean, dark braided hair, dark travelling cloak over a leather jerkin, looking off to the
side with a tense, wary expression — apprehension, not sadness. A village and pine forest
sketched faintly behind her.

RIGHT TWO THIRDS: the speaker name MARIA in large serif capitals, an ornate thin divider
below it, then two short lines of dialogue in large readable serif, generously spaced.
Bottom right: a dark CONTINUAR button with an arrow, and under it a small framed hint box
with a book icon and two small lines.

Small detail: a row of three faint dots under the name indicating dialogue progress.

[bloco de estilo + HUD]
```

---

## 8 · Biblioteca alternativa (contos com objetivos)

Esta é um **sistema diferente** do aprovado: missões por conto, com Ensinamentos, Objetivos
e Recompensas. Boa demais para descartar, mas é escopo novo. Prompt para avaliar como
sistema futuro, e não como substituto da tela 1.

```
Landscape 16:9 game UI screen: CONTOS — tale progression.

LEFT COLUMN: title CONTOS with a two-line intro. A framed illustration of stacked old
books and a candle. A vertical category list with counters: TODOS OS CONTOS 32/32, CONTOS
DE INFÂNCIA 12/12, HISTÓRIAS SOMBRIAS 8/8, CRIATURAS E MALDIÇÕES 6/6, ARTEFATOS E ENCANTOS
6/6. Bottom: PROGRESSO GERAL with a full green bar.

CENTRE: a vertical list of tale rows, each with a small illustrated thumbnail, the tale
name in serif capitals, and a green completion bar with a percentage. Completed ones show
an open book icon, incomplete ones a closed clasped book. The first row is highlighted.

RIGHT COLUMN: the selected tale — title, a wide illustration, a short synopsis.
Then ENSINAMENTOS: three short italic lines with engraved icons. Then two side-by-side
sections: OBJETIVOS with three checked checkboxes, and RECOMPENSAS with three lines
showing an icon and the reward. Bottom: a wide green button reading CONTO COMPLETO with a
check mark.

[bloco de estilo + HUD]
```

---

## Decisões que os prompts assumem

1. **Paisagem 16:9** substitui o retrato da especificação. Muda mapa, maquete e pan.
2. **Sem combate:** o bestiário vira observação. Nenhum atributo de luta em nenhuma tela.
3. **Uma mochila por expedicionário**, com abas — mantém o sistema fechado.
4. **Sem loja de melhorias por edifício:** melhoria vem de nível de mina e item de expedição.
5. **Diamante permanece no HUD.**
6. **Líderes têm identidade fixa**, não nome sorteado.
7. **DIA 23 · Manhã fica.** Boa adição — dá âncora temporal ao ciclo dia/noite.
