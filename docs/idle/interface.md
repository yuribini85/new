# Interface do Chrome Racing Team: legibilidade e layout

Regras de tela que valem para todo o CRT. Nasceram de três falhas que a documentação de HUD não
pegou (apontadas pelo usuário em 2026-10-24): texto pequeno demais no celular, ícones minúsculos
ao lado dos botões e texto cortado ou por cima de outro. `tools/checar_tela_idle.gd` (rodado por
`tests/rodar.sh`) abre todas as telas com tudo aberto e barra as três.

## 1. Tamanho de texto

A base do jogo tem 720 px de largura (`project.godot`, `canvas_items`, `keep_width`) e ocupa a
largura do celular, que tem perto de 360 dp. Então **1 px da base ≈ 0,5 dp**: um texto de 16 px
aparece com ~8 sp, abaixo do mínimo de qualquer plataforma.

| Uso | Base (px) | No celular | Referência |
|---|---|---|---|
| mínimo absoluto (rótulo, legenda, "Nv. 3") | **24** | ~12 sp | menor tamanho da escala do Material (12 sp); iOS: mínimo 11 pt |
| texto corrido, valores dos cartões | 28–34 | 14–17 sp | corpo do Material (14–16 sp) e do iOS (17 pt) |
| botões | 30–36 | 15–18 sp | |
| títulos | 40+ | 20+ sp | |

Todo texto passa por `IdleUI.legivel()` (em `rotulo`, `botao`, `botao_premio`): o que estava em
14–30 px sobe ×1,3 com piso de 24 px (`IdleUI.TEXTO_MIN`). O painel de posições da corrida
(`HudCorrida`, do Chrome & Wreckage) usa `escala_texto = 1.3` no CRT.

## 2. Alvo de toque

Botão com no mínimo **96 px** de altura na base (~48 dp; Android pede 48 dp e iOS 44 pt):
`IdleUI.ALTURA_MIN`.

## 3. Ícones

- **Nada de ícone pequeno ao lado do texto de botão ou de título de cartão**: no tamanho do texto ou
  menor ele não se lê, briga com o texto e não acrescenta nada. O botão diz o que faz em palavras.
  O de anúncio é a exceção da seção 5: o ícone de vídeo entra grande, num selo próprio.
- Ícone entra **sozinho e grande** (abas do menu de baixo, cadeado das modalidades, moeda do
  BEM-VINDO, ícones das missões), com pelo menos 40 px na base.

## 4. Caber na caixa

- Nenhum texto **cortado** (rótulo com `clip_text` cujo texto não cabe) nem **vazando** da caixa.
- Nada **sai da tela pela lateral** (a rolagem é só vertical).
- Nenhum texto **por cima de outro**.
- Quando não cabe: mudar o layout (nome numa linha e valores na outra, cartões em menos colunas,
  botões um embaixo do outro), não diminuir a letra abaixo do mínimo.

## 5. Botão de anúncio (vídeo premiado)

O jogador precisa saber **antes de tocar** que o botão abre um anúncio. É também regra do AdMob:
o app mostra de forma clara a ação pedida e a recompensa antes de cada vídeo premiado (ícone vale
se for inequívoco), e o vídeo só abre depois do toque do jogador. As redes recomendam o botão de
anúncio diferente dos outros (cor, forma, texto) e em duas partes: o "ver vídeo" e a recompensa
(a Unity cita o botão roxo com uma TV do Subway Surfers).

No CRT (`IdleUI.botao_premio`): botão **verde**; à esquerda um **selo** verde-escuro com o
**ícone de vídeo grande** (o ▶ na tela, 30–48 px) e a palavra **VÍDEO**; à direita a recompensa
(**PRÊMIO x2**, **COLETAR x2**, **CONTRATAR · 5 HOJE**). Nunca "GRÁTIS" num botão de anúncio
(grátis é o do relógio).

## 6. Palavras

O texto segue o dialeto dos idles de `docs/vocabulario.md`, seção 5 (por exemplo, ATUAL na escada
de ligas, nunca "aqui").

## Fontes

- [AdMob: política de anúncios premiados](https://support.google.com/admob/answer/7313578)
- [Unity: fundamentos do posicionamento do vídeo premiado](https://unity.com/blog/the-fundamentals-of-rewarded-video-ad-placements)
- [Pangle: boas práticas do vídeo premiado](https://www.pangleglobal.com/resource/27805)
- [Applixir: botão de anúncio](https://www.applixir.com/?p=2993)

- [Material Design 3: tipografia](https://m3.material.io/styles/typography/type-scale-tokens)
- [Apple HIG: tipografia](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Android: alvos de toque de 48 dp](https://developer.android.com/guide/topics/ui/accessibility/apps#large-controls)
- [Game Accessibility Guidelines: tamanho de texto legível](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/)
