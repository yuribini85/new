# THE WAY BACK — Especificação Técnica (v1, pré-preenchida)

Todas as 52 decisões respondidas com a melhor definição possível a partir do que já está
fechado. **Cada resposta é uma proposta — altere livremente.** Marcadas com ⚠ as que eu
considero decisões de verdade, onde a alternativa é defensável e o custo de mudar depois é alto.

---

## BLOCO 1 — Alvo técnico e escopo

**1. Versão do Godot** — 4.4 estável. Renderer **Compatibility** (GL Compatibility), não Forward+.
Idle 2D em celular não precisa de Vulkan e Compatibility cobre muito mais aparelhos Android antigos.

**2. Escopo do primeiro build** ⚠ — **Protótipo jogável do Ato I**, não vertical slice.
Precisa provar uma coisa só: que o loop de trinta minutos dá vontade de voltar em duas horas.
Conteúdo: 6 a 8 edificações, a Casa das Fiandeiras, a chegada dos primeiros órfãos, o índice de
fome, o clique de enxotar, e a primeira expedição. Sem mina, sem anões, sem maldições, sem
monetização.

**3. Plataforma-alvo** — Android primeiro. É onde está o público de idle, o ciclo de build é mais
rápido e o teste com gente real é imediato. iOS depois, com o mesmo projeto.

**4. Resolução e orientação** ⚠ — **Retrato, 1080×1920, proporção 9:16**, com `canvas_items`
e aspecto `expand`. Retrato porque idle é jogo de uma mão, e porque a vila crescendo para cima
na tela combina com a leitura vertical de mina descendo e torre subindo.
Área segura de 100px no topo e 160px na base para HUD e barra de navegação.

**5. Geração pelo Codex** — Por módulos, nesta ordem: (1) esqueleto de projeto e save,
(2) modelo de dados e carga de JSON, (3) mapa e lotes, (4) produção e recursos, (5) população e
alocação, (6) UI, (7) expedição. Cada módulo com teste manual antes do seguinte. Pedir o jogo
inteiro de uma vez produz um projeto que não roda e não dá para depurar.

---

## BLOCO 2 — Mundo e câmera

**6. Mapa** — Pan vertical com zoom limitado (0,8× a 1,6×). O mapa é mais alto que largo,
acompanhando o retrato.

**7. Limites** — Fixos desde o início. O mapa inteiro existe desde o primeiro minuto; o que muda é
o que está construído. Isso é o que permite ver a casa de doces ao longe desde sempre.

**8. Lotes** ⚠ — **Posições fixas pré-definidas.** O jogador não escolhe onde construir.
Motivos: o eixo de contaminação depende da geografia, os trajetos entre mina e forja são arte
autoral, e construção livre em isométrico multiplica o custo de tudo.

**9. Quantidade e visibilidade** — 22 lotes. Todos visíveis desde o começo como **silhueta
escura de ruína**, no mesmo padrão da tela da mina. O jogador vê o tamanho do que vem.

**10. Tile isométrico** — 256×128 px como célula base (proporção 2:1). Edificação de footprint
2×2 ocupa 512×256 de base. Todos os assets gerados devem ser conferidos contra essa grade antes
da importação em massa.

**11. Ordenação** — `YSort` do Godot com lotes em `Node2D` posicionados manualmente.
Sprites móveis (aldeões, ratos, anões) entram no mesmo `YSort`.

---

## BLOCO 3 — Tempo e simulação

**12. Tempo** — Tick de **1 segundo**, disparado por um `Timer` único no autoload `Sim`.
Nada de `_process` para lógica de jogo.

**13. Duração do dia** ⚠ — **20 minutos reais = 1 dia da vila.** Dá 72 dias em 24h de tempo real.
O Alfaiate passa uma vez por dia; ciclo dia/noite de 14 min claro e 6 min escuro; demandas da
Holle duas vezes por ato.

**14. Cálculo de produção** — Por **timestamp**, não por tick acumulado. Cada edifício guarda
`last_tick` e produz `taxa × delta`. O tick de 1s só dispara o recálculo e a atualização visual.

**15. Ciclo dia/noite** — **Só visual.** Produção idêntica. Se a noite reduzisse produção, o
jogador que joga à noite seria punido por fuso horário, o que é injusto e invisível.

**16. Offline** ⚠ — **Fórmula fechada.** Nunca simulação retroativa. Ao abrir:
`delta = min(agora - last_seen, teto_fiandeiras)`, aplica produção linear por edifício,
consumo de comida no mesmo delta, e apresenta um resumo. Não processa eventos, não faz órfão
crescer, não roda expedição. Simulação retroativa trava o app depois de dois dias fora.

**17. Teto de offline** — Sem a Casa das Fiandeiras: **0 h.** Depois: 2 h no nível 1, e depois
4, 6, 9, 12, 16, 20, 24 h. O salto de 0 para 2 h é a maior mudança percebida do Ato I.

---

## BLOCO 4 — Persistência

**18. Formato** — JSON em `user://save.json`, com campo `version` desde o primeiro build.
Legível, depurável, e você consegue editar à mão durante o desenvolvimento.

**19. Frequência** — A cada ação relevante (construir, alocar, vender, partir em expedição) com
debounce de 2 s, mais salvamento forçado em `NOTIFICATION_APPLICATION_PAUSED` e
`NOTIFICATION_WM_CLOSE_REQUEST`.

**20. Slots** — Save único. Idle não tem partidas paralelas.

**21. Nuvem** — Não no primeiro build. Só local.

**22. Relógio adiantado** ⚠ — Guardar `max_time_seen`. Se `Time.get_unix_time_from_system()`
vier menor que ele, usar `max_time_seen` e não creditar nada. Se vier absurdamente maior
(mais de 30 dias), creditar apenas o teto. Sem isso, o exploit clássico de idle quebra a economia
na primeira semana de lançamento.

**23. Migração** — Sim. `version: 1` desde já, e uma função `migrate(save)` que roda em cadeia.
Custa dez linhas agora e salva o lançamento depois.

---

## BLOCO 5 — Modelo de dados

**24. Balanceamento** ⚠ — **JSON externo** em `res://data/`, um arquivo por domínio:
`buildings.json`, `resources.json`, `orphans.json`, `expeditions.json`, `events.json`.
Você vai ajustar número centenas de vezes; recompilar a cada ajuste é inviável.

**25. Edificações** — **Um nó genérico configurado por dado**, não uma cena por edifício.
`Building.tscn` com sprite, área de clique e estado; tudo o mais vem do JSON. Trinta cenas quase
idênticas é dívida garantida.

**26. Órfão** — `id`, `nome`, `partes_visual` (dicionário de peças sorteadas), `trauma`,
`aptidao`, `idade_segundos`, `estado` (criança / adulto_ocioso / alocado / em_expedicao / morto),
`local` (id do edifício ou alojamento), `nascido_em` (timestamp).
Acrescentei `aptidao` e `nascido_em`; o resto é o que você listou.

**27. Aptidões** — Seis, cada uma dando +25% de velocidade de produção no grupo correspondente:
`campo` (Horta, Curral), `cozinha` (Padaria, Taberna), `agua` (Pesca), `oficina` (Armas,
Alfaiataria, Sapataria), `bracos` (Lenhador, Construtor, Depósito), `letras` (Biblioteca).
Seis é o mínimo para a alocação ser decisão e o máximo para caber numa tela de celular.

**28. Traumas** — Oito, todos com custo e compensação:

| Trauma | Custo | Compensação |
|---|---|---|
| Fome antiga | come 5× | trabalha 40% mais rápido |
| Sono pesado | acorda tarde, rende 15% menos | imune a maldição |
| Medo da mata | não pode ir em expedição | +20% em qualquer edifício |
| Mudez | não aparece em diálogo | nunca é levado pelo Flautista |
| Mãos leves | rouba comida do depósito | +50% de chance de item especial em expedição |
| Insônia | come 1,5× | continua produzindo à noite (visual) |
| Teimosia | ignora realocação por 1 dia | não morre na primeira expedição |
| Sem trauma | — | — (sorteio comum, ~30%) |

---

## BLOCO 6 — Expedições

**29. Tempo da expedição** ⚠ — **Corre com o app fechado**, por timestamp, e é a única coisa
além da produção que corre. Se travasse com o app aberto, o jogador ficaria olhando a barra —
o oposto de um idle.

**30. Regiões no lançamento** — Cinco:

| Região | Requisito | Duração | Aldeões | Fôlego |
|---|---|---|---|---|
| Orla da mata | nenhum | 5 min | 0 | +5 |
| Trilha velha | tier 1 de equipamento | 20 min | 1 | +8 |
| Vale fundo | tier 2 | 1 h | 2 | +14 |
| Rio negro | tier 3 | 3 h | 3 | +25 |
| Mata cega | tier 4 | 8 h | 5 | +40 |

**31. Composição da equipe** — Escolha individual, com botão de "preencher automático" que pega
os de menor aptidão. A escolha manual é o que dá peso à morte; o automático é o que evita
tédio na décima vez.

**32. Risco** ⚠ — **Por indivíduo**, mostrado antes de partir. Orla 0%, Trilha 3%, Vale 6%,
Rio 10%, Mata cega 15%. Trava obrigatória: **nunca mais de metade da equipe** numa mesma
expedição, e Maria e Pele-de-Urso nunca morrem.

**33. Relatório** — Tela cheia ao voltar, com botão de anúncio para recuperar **um** morto,
válido só enquanto a tela estiver aberta. Depois entra num log de expedições consultável.

**34. Texto variável** — 12 linhas por região no lançamento, sorteadas, mais uma linha específica
por evento (achou anão, achou item, alguém morreu, recuou por falta de preparo).
Total aproximado: 80 linhas. É o maior bloco de escrita do primeiro ano.

---

## BLOCO 7 — Interface

**35. Telas** — Sete além do mapa: Edifício (painel), Aldeões, Expedição, Mina, Biblioteca,
Relatório de expedição, Ajustes. O Depósito e o Mercado são painéis de edifício, não telas.

**36. Clique em edificação** ⚠ — **Painel deslizando de baixo**, ocupando 55% da tela, com o
mapa vivo visível acima. Tela cheia mata o atrativo principal do jogo, que é ver a vila
funcionando.

**37. Tela de aldeões** — Lista vertical com filtro por estado (todos / ociosos / alocados /
crianças). Cada linha: retrato combinado, nome, aptidão como ícone, trauma como ícone, e o
edifício atual. Toque abre um seletor de destino. É a tela mais complexa e merece protótipo
próprio antes de qualquer código definitivo.

**38. Tabela de comida** — Não fica sempre aberta. O HUD mostra o **ícone de comida com o índice
colorido**; tocar abre a tabela completa de bocas e saldo como painel. Sempre visível ocuparia
um terço de uma tela de celular.

**39. Tutorial** — Guiado nos primeiros cinco minutos, com a voz do João, destacando um alvo por
vez. Depois, só diálogo.

**40. Idiomas** — Português e inglês desde o início, via `TranslationServer` e CSV. Retrofit de
localização em jogo com muito texto é retrabalho garantido.

---

## BLOCO 8 — Áudio

**41. Trilha** — Uma faixa de vila em camadas (`AudioStreamInteractive`), com camadas entrando
conforme a população cresce. Uma segunda faixa, mais escura, para a tela de expedição.

**42. Gazebo** ⚠ — Sim, e é o melhor uso possível do sistema: com os Músicos ativos, entra uma
camada instrumental completa e a vila soa viva. Quando o buff acaba, a camada sai. No Ato V, a
trilha perde camadas até o silêncio.

**43. Efeitos** — 20 no primeiro build: clique de construção, conclusão de obra, moeda, colheita,
enxotar bicho, chegada de órfão, partida e retorno de expedição, sino da torre, martelo da forja,
página virando, porta da taberna, e variações de interface.

---

## BLOCO 9 — Monetização e serviços

**44. SDK de anúncio** — AdMob via plugin oficial de Godot para Android. Rewarded video apenas —
nenhum interstitial, nenhum banner, conforme já decidido.

**45. Compra** — Google Play Billing no primeiro lançamento. App Store quando houver build iOS.

**46. Analytics** — Sim, mínimo e próprio: eventos de tempo de sessão, ato alcançado, primeira
morte em expedição, e ponto de abandono. Sem SDK de terceiro no primeiro build.

**47. Sem internet** ⚠ — O jogo funciona inteiro offline. Rumpelstiltskin continua aparecendo,
mas o contrato dele fica com o texto de que "hoje ele não trouxe nada" e some. Nunca bloquear
progresso por falta de rede — e nunca deixar um botão de anúncio que falha ao ser tocado.

---

## BLOCO 10 — Pipeline de arte

**48. Corte** — Automático, por script Python fora do Godot: detecta bounding box, apara,
padroniza a âncora na base do sprite e grava com a nomenclatura definida. Manual em 320 imagens
é inviável.

**49. Formato no Godot** — `AtlasTexture` por grupo (um atlas por edificação com seus estágios,
um atlas para aldeões, um para efeitos). Textura solta por arquivo estoura o número de draw calls
em celular fraco.

**50. Geração de atlas** — Script no projeto, rodando em editor via `@tool`, para que reimportar
seja um comando e não um processo manual.

**51. Aldeões** ⚠ — **Peças combinadas em tempo de execução.** Corpo, cabelo, roupa e tom de pele
como camadas separadas, sorteadas por órfão e compostas num `Sprite2D` com sub-nós. A roleta de
aparência torna frame a frame impossível — seriam milhares de combinações pré-renderizadas.

**52. Direções** — Quatro (NE, NO, SE, SO). Oito dobra o custo de arte e ninguém percebe num
sprite de 96px.

---

## Decisões que ficaram fora e ainda precisam de você

Estas não têm resposta padrão razoável — dependem do seu gosto ou de teste:

- **Quantos níveis por edificação de fato.** O gerador produz 11; se o jogo usar 7, você está
  gerando 4 imagens inúteis por prédio (mais de 100 no total).
- **Curva exata de custo.** Fixei 1,35× como regra, mas o valor inicial de cada edifício muda o
  ritmo do Ato I inteiro e só sai no teste.
- **Ordem de desbloqueio das 22 construções.** É o roteiro do jogo em forma de tabela, e é a
  próxima coisa que eu faria depois desta especificação.
- **Quantos órfãos chegam por hora**, calibrado contra a taxa de morte em expedição.
