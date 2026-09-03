# Dreadwick — repositório de projeto

Idle horror mobile vertical em Godot 4.4. Escócia, 1925: Quint Hollowell mantém um farol
numa ilha isolada cuja função real é conter Cthulhu.

**Este repositório é o jogo em desenvolvimento.**

O material do projeto anterior deste repositório ("The Way Back", vila medieval/Grimm) está
arquivado em `archive_the_way_back/`, intacto — não é parte do Dreadwick.

---

## Por onde começar

1. **`docs/dreadwick_biblia_oficial.md`** — a bíblia oficial. Lore, gameplay, economia,
   UI/UX, direção visual, arquitetura de implementação. Fonte de verdade única; em qualquer
   conflito, ela prevalece (§24).
2. **`docs/dreadwick_manual_assets.md`** — estrutura de pastas do Drive, nomenclatura,
   manifest de assets.
3. **`data/*.json`** — balanceamento extraído da bíblia, pronto para `res://data/`. Chaves
   `_status`/`_fonte` documentam o que é canônico vs. o que ainda é placeholder de
   protótipo.

**Não invente nada que a bíblia já decidiu.** O que falta aparece marcado como pendente na
própria seção 20 da bíblia e nos `_status` dos JSONs.

---

## Estrutura

```
docs/       bíblia e manual de assets — leitura obrigatória
data/       JSON de balanceamento, prontos para res://data/
autoload/   singletons de simulação (TimeSystem, FSM de Quint, save, economia...)
data_model/ classes de dado (RefCounted) consumidas pelos autoloads
scenes/     cenas do Godot
archive_the_way_back/   projeto anterior deste repositório, intacto, fora de escopo
```

---

## Regras que não se quebram (bíblia §21, resumo)

1. Quint não tem poderes especiais — resolve por engenharia e procedimento.
2. The Vigil não é culto nem ordem de combate; N.A.S.H. não é onisciente.
3. Mais lux é sempre melhor para a contenção — nunca punição por "lux demais".
4. A Fresnel antiga já estava estruturalmente condenada antes de Quint chegar.
5. Nunca softlock permanente por necessidade, falta de Kit ou erro comum.
6. Automação reduz cliques repetitivos, mas preserva deslocamento e presença física.
7. Cutscenes são visuais e silenciosas — nunca fala, caixa de diálogo ou texto embutido.
8. Interiores não têm eletricidade doméstica — luz só de janela, lampião ou fogão.
9. Personagens nunca gerados com as mãos nos bolsos.
10. Balanceamento (custo, taxa, tempo, capacidade, penalidade) sempre em dado, nunca
    hardcoded em `.gd`.

---

## Estado atual

- Bíblia: fechada, lida por completo (24 seções).
- Arte: pipeline no Drive, maioria ainda em placeholder/mockup (pastas `TESTES`,
  `EXEMPLOS`, `AJUSTAR`) — nada sincronizado no repositório ainda.
- Código: primeira fatia da arquitetura (bíblia §22) implementada e não testada no editor
  (sem Godot instalado neste ambiente): `Tempo` (TimeSystem — dia de 8 min em quatro fases,
  agenda semanal de visitantes, offline por fórmula fechada), `Quint` (FSM central com os
  15 estados de #17.1 + Energia/Fome/Latrina com as taxas de #18), `FilaTarefas` (TaskQueue
  com a prioridade de #7.3), `Economia` (dinheiro em pence, estoques de querosene/Kit/
  peixe) e `SaveManager`. `scenes/ilha.tscn` é só um HUD de debug com botões manuais de
  estado — sem mapa, sem arte, sem deslocamento.

**Próximo passo:** abrir no editor Godot e validar a fatia acima antes de continuar. Depois,
seguindo a ordem de produção (§23.11): Casa (dormir/comer + Kit), Latrina compartilhada com
fila real de ocupação, Boathouse + pesca automática, Depósito + estoques, Betsy (chegada,
comércio, confiança), Farol e Oficina.
