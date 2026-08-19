# Instruções para o agente

## O que este repositório é
Material de design de um jogo idle isométrico para Godot 4.4. O jogo ainda não existe.

## Leia antes de escrever qualquer código
- `docs/mecanicas_para_godot.md` — especificação de implementação
- `docs/especificacao_tecnica_v1.md` — decisões técnicas já tomadas
- `docs/ato1_balanceamento.md` — números do primeiro ato
- `data/*.json` — balanceamento consumível

## Regras de trabalho

**Não gere arte.** A direção visual está fechada e há um pipeline próprio com 686 imagens
catalogadas em `tools/twb-inventario-assets.html`. Use placeholders com a nomenclatura de
`docs/NOMENCLATURA_ASSETS.md` e nunca invente assets.

**Não invente balanceamento.** Todo número vem de `data/`. Se faltar algum, pergunte em vez
de estimar.

**Não altere as dez regras do README.** Elas são decisões de design, não preferências.

**Escopo do primeiro build:** apenas o Ato I. Onze edificações, economia, população, tela de
aldeões, primeira expedição. Sem mina, sem anões, sem maldições, sem monetização.

**Balanceamento fica em JSON externo**, nunca embutido no código. É ajustado centenas de
vezes.

**Um nó genérico de edifício** configurado por dado, nunca uma cena por construção.

## Ordem de implementação
1. Fundação — autoload de simulação, ciclo do dia, save, offline
2. Dados — carga dos JSON, modelo de edifício genérico
3. Mapa — lotes fixos de `data/vila_lotes.json`, ruínas, construção
4. Economia — recursos, produção, teto, índice de fome, venda
5. População — órfãos, cicatrizes, alocação, tela de aldeões
6. Rotas — sprites, colisão por cortesia, floresta e coleta
7. Expedição — regiões, mochilas, risco, relatório

Cada etapa depende só das anteriores. Testar antes de avançar.
