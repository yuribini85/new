# THE WAY BACK — Perguntas para a especificação técnica

Objetivo: chegar num documento que o Codex consiga transformar em projeto Godot sem inventar nada.
O que já está fechado (lore, economia, elenco, edificações, nomenclatura) não volta aqui.

Ordem importa: **o Bloco 1 trava todos os outros.** Responda ele e eu já consigo redigir a
arquitetura de cenas e o modelo de dados para você criticar.

---

## BLOCO 1 — Alvo técnico e escopo do primeiro build

1. Godot 4.x confirmado? Qual versão exata?
2. O primeiro build é **protótipo jogável de um ato** ou **vertical slice completo**?
3. Plataforma-alvo do primeiro build: Android, iOS, desktop, ou navegador?
4. Resolução base e orientação. Retrato ou paisagem? Qual proporção de referência?
5. O Codex vai gerar o projeto inteiro de uma vez, ou por módulos que você integra?

---

## BLOCO 2 — Mundo e câmera

6. O mapa é **fixo** (uma tela, tudo cabe) ou tem **pan e zoom**?
7. Se tem pan: limites fixos do mapa, ou o mapa cresce conforme a vila cresce?
8. Os lotes de construção são **posições fixas pré-definidas** ou o jogador escolhe onde construir?
9. Quantos lotes existem no total, e todos já são visíveis desde o começo (como sombra) ou aparecem conforme desbloqueiam?
10. Tamanho do tile isométrico em pixels. Já está definido pela arte gerada?
11. Ordenação de profundidade: `YSort` padrão do Godot ou índice manual por lote?

---

## BLOCO 3 — Tempo e simulação

12. O tempo do jogo é **contínuo em tempo real** ou por **ticks** (ex.: um tick por segundo)?
13. Um "dia da vila" dura quanto em tempo real? Isso define a passagem do Alfaiate, o ciclo dia/noite e as demandas da Holle.
14. A produção é calculada **por tick acumulado** ou por **timestamp** (produz X por segundo desde a última visita)?
15. Ciclo dia/noite é só visual ou afeta produção?
16. O que exatamente acontece no cálculo de offline: a simulação roda por inteiro ou é uma fórmula fechada? (a segunda é muito mais barata e é o padrão do gênero)
17. Teto de offline em horas por nível da Casa das Fiandeiras — quais valores?

---

## BLOCO 4 — Persistência

18. Formato do save: JSON em `user://`, recurso binário, ou banco local?
19. Salva **a cada ação** ou em intervalo fixo?
20. Save único ou múltiplos slots?
21. Vai ter save em nuvem no primeiro build, ou só local?
22. Como o jogo lida com **relógio adiantado** pelo jogador? (mudar a data do aparelho é o exploit clássico de idle)
23. Vai existir migração de save entre versões? Se sim, precisa de campo de versão desde o primeiro build.

---

## BLOCO 5 — Modelo de dados

24. Os dados de balanceamento ficam em **arquivos externos** (JSON/CSV que você edita sem recompilar) ou embutidos em `Resource` do Godot?
25. Cada edificação é uma cena instanciada ou um nó genérico configurado por dado?
26. Como um órfão é representado: id, nome sorteado, aparência sorteada, trauma, idade, alocação. Falta algo?
27. As aptidões dos órfãos — quantas existem e como se ligam às edificações? (isso ainda está em aberto na bíblia)
28. Quantos traumas existem no total? Cada um precisa de: efeito negativo, efeito positivo, e como aparece na UI.

---

## BLOCO 6 — Expedições

29. A expedição roda **em tempo real** mesmo com o app fechado, ou só conta tempo com o jogo aberto?
30. Quantas regiões existem no lançamento, e qual o requisito de cada uma?
31. A composição da equipe é escolhida um a um, ou é automática por "mandar N aldeões"?
32. O risco de morte é por indivíduo ou por expedição? Qual a faixa percentual?
33. O relatório de volta é uma tela, um popup ou uma entrada num log que fica salvo?
34. Quantas linhas de texto variável por região? (é o conteúdo de escrita mais volumoso do jogo)

---

## BLOCO 7 — Interface

35. Quantas telas existem além do mapa? (mina, biblioteca, depósito, expedição, aldeões, loja, ajustes…)
36. Ao clicar numa edificação, abre **painel lateral** ou **tela cheia**?
37. Como o jogador vê a lista de aldeões e faz alocação? É a tela mais complexa do jogo e precisa de decisão explícita.
38. A tabela de comida sempre visível fica onde, e quanto ocupa da tela?
39. Tem tutorial guiado passo a passo, ou só o diálogo do João?
40. Idiomas do primeiro build. Se for mais de um, precisa de sistema de localização desde o início.

---

## BLOCO 8 — Áudio

41. Trilha por ato, por região, ou única?
42. O gazebo dos Músicos altera a trilha quando ativo? (seria o melhor uso possível do sistema)
43. Quantos efeitos sonoros no primeiro build?

---

## BLOCO 9 — Monetização e serviços

44. Qual SDK de anúncio? AdMob, Unity Ads, outro? Isso define plugin e configuração de exportação.
45. Compra única de remoção de anúncio: Google Play Billing, App Store, ou os dois?
46. Vai ter analytics no primeiro build? Qual?
47. Como o jogo se comporta **sem internet**? Os anúncios do Rumpelstiltskin somem, ou ele oferece outra coisa?

---

## BLOCO 10 — Pipeline de arte

48. As imagens geradas passam por corte automático ou manual antes de entrar no Godot?
49. Vão para `SpriteFrames`, `AtlasTexture`, ou textura solta por arquivo?
50. Quem gera os atlas — script no projeto ou ferramenta externa?
51. Os sprites de aldeão são **animação frame a frame** ou peças combinadas em tempo de execução? (a roleta de aparência empurra para a segunda, e isso muda toda a estrutura)
52. Quantas direções de caminhada? Quatro ou oito?

---

## Perguntas que eu já responderia por você, se não discordar

- **Save:** JSON em `user://save.json`, com campo `version`, salvando a cada ação relevante e no `NOTIFICATION_APPLICATION_PAUSED`.
- **Offline:** fórmula fechada com `Time.get_unix_time_from_system()`, nunca simulação retroativa.
- **Relógio adiantado:** guardar o maior timestamp já visto e ignorar qualquer valor menor.
- **Balanceamento:** JSON externo. Você vai querer ajustar número sem recompilar centenas de vezes.
- **Aldeões:** peças combinadas em tempo de execução, quatro direções.
- **Ordenação:** `YSort` com lotes em posições fixas.

Se concordar com esses seis, eles saem da lista e sobram 46 decisões reais.
