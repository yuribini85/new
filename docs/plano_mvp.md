# Second Drive — plano operacional do primeiro build

Desdobramento de `docs/conceito.md` em sistemas, dados e ordem de trabalho. Estruturas abaixo
são formato, não balanceamento: **nenhum número aqui é definitivo**. Os valores virão do
estudo da referência e de playtest, sempre em JSON externo.

## 1. Escopo do primeiro build

Entra:

- 1 concessionária de novos, 1 de usados
- ~15 carros de 3 fabricantes fictícias (faixa de entrada da referência: compactos, esportivos leves, um turbo)
- garagem com coleção
- 5 categorias de peça + 3 compostos de pneu (incluindo chuva)
- 2 licenças
- 3 pistas, uma de cada função: rápida, técnica, montanha
- ~6 eventos com restrição de entrada, prêmio em dinheiro e 1 carro-prêmio
- simulação de corrida + visualização isométrica
- save local e progresso offline

Fica fora: lore, endurance, box com estratégia, clima dinâmico além de seco/chuva,
monetização, pipeline 3D completo (o primeiro build usa sprites placeholder).

## 2. Sistemas

| Sistema | Responsabilidade | Depende de |
|---|---|---|
| Dados | carregar JSON de carros, peças, pistas, eventos, licenças | — |
| Economia | saldo, compra, venda, prêmio | Dados |
| Garagem | carros possuídos, peças instaladas, estado | Economia |
| Concessionária | estoque de novos; estoque rotativo de usados | Economia, Garagem |
| Tuning | instalar peça → recalcular atributos efetivos | Garagem |
| Elegibilidade | checar restrição do evento contra o carro e as licenças | Garagem, Licenças |
| Simulação | resolver a corrida trecho a trecho | Tuning, Pistas |
| Visualização | animar sprites a partir do resultado da simulação | Simulação |
| Carreira | eventos, campeonatos, licenças, carros-prêmio | tudo acima |

A visualização **lê** a simulação; nunca a influencia. Isso permite resolver corridas
offline sem renderizar nada.

## 3. Modelo da simulação

### Pista
Lista ordenada de trechos. Cada trecho:

```json
{ "tipo": "curva_media", "comprimento_m": 0, "raio_m": 0,
  "ultrapassagem": false, "pontos_trajetoria": [[0,0],[0,0]] }
```

Tipos: `reta`, `curva_lenta`, `curva_media`, `curva_rapida`, `frenagem`, `aceleracao`,
`entrada_box`, `saida_box`.

### Carro (atributos efetivos, já com peças)
`potencia`, `peso`, `tracao` (FF/FR/MR/RR/4WD), `aderencia`, `freio`, `velocidade_max`,
`composto_pneu`.

### Piloto de IA
`ritmo`, `consistencia`, `agressividade`. O mesmo modelo serve jogador e adversários.

### Resolução
Para cada carro, para cada trecho: velocidade de entrada, velocidade-alvo do trecho
(limitada por aderência em curva, pela força na roda — curva de torque do carro na melhor
marcha, ver `data/README.md` — e pela tração em aceleração, por velocidade máxima
em reta) e tempo gasto. Ruído controlado por `consistencia`. Ultrapassagem só em trechos
marcados, decidida pela diferença de ritmo naquele trecho e por `agressividade`.

Saída: série temporal de posição ao longo da trajetória por carro. A visualização
interpola sobre ela e escolhe a direção do sprite (16) pelo ângulo da tangente.

### Calibração
Tempos de volta e velocidades da referência servem de alvo: se o carro-arquétipo X faz Y na pista
de função Z na referência, o equivalente fictício deve ficar na mesma ordem relativa. A meta é
preservar **ordem e distância relativa** entre carros, não tempos absolutos.

## 4. Arquivos de dados

```
data/fabricantes.json   id, nome, escola (jp/de/it/us/uk/fr), descrição
data/carros.json        id, fabricante, arquétipo_ref, categoria, tração, potência, peso, preço, ano
(usados ficam em carros.json: janelas de dias com preço, da lista da referência)
data/pecas.json         id, categoria, efeitos por atributo, preço, compatibilidade
data/pneus.json         compostos, aderência seco/chuva, preço
data/pistas.json        id, função, trechos
data/eventos.json       id, restrições, adversários, voltas, prêmios, carro-prêmio
data/licencas.json      id, testes, requisito
data/pilotos_ia.json    perfis de piloto
```

`arquétipo_ref` guarda a referência de estudo (ex.: "hatch FF leve de entrada") e não o
nome real do carro — esse campo pode ir para o build sem problema.

## 5. Pipeline de carros (ordem de construção)

1. Planilha de referência a partir do jogo de referência: arquétipo, categoria, potência, peso, preço,
   tração, posição na progressão. Uso interno, nunca empacotado.
2. Agente gera ficha fictícia: fabricante, nome, números ajustados, briefing de design.
3. Modelo 3D simplificado (low-poly, paleta limitada).
4. Renders: concessionária, garagem, miniatura.
5. Render em 16 direções → redução → tratamento pixel art → spritesheet.
6. Validação: silhueta não pode reproduzir carro real; nome não pode colidir com marca.

Etapas 1–2 entram no primeiro build. 3–5 podem esperar: o build roda com sprites
placeholder por categoria.

## 6. Ordem de implementação

1. Dados — loader dos JSON, carro com atributos efetivos
2. Simulação headless — uma pista, dois carros, saída em texto; calibrar ordem relativa
3. Economia + garagem + concessionária de novos
4. Tuning e pneus, com uso automático de pneu de chuva
5. Eventos e elegibilidade
6. Visualização isométrica sobre a simulação já pronta
7. Usados, licenças, carros-prêmio
8. Save e offline

Cada etapa testada antes da próxima. A simulação vem antes da tela porque é o único risco
técnico real do projeto.

## 7. Riscos

- **Jurídico.** Usar o jogo de referência só para estudo. Não empacotar código, modelos,
  texturas, músicas, nomes de carros, marcas ou traçados reconhecíveis. Dados numéricos
  devem ser reajustados, não copiados em bloco.
- **Design parecido demais.** O pipeline precisa de uma etapa explícita de checagem
  contra carros reais (item 5.6).
- **Corrida sem tensão.** Sem pilotagem, a corrida vira espera. Mitigação já prevista:
  isometria legível, ultrapassagens visíveis, opção de pular e ver só o resultado.
- **Deriva para Motorsport Manager.** Qualquer decisão durante a corrida está fora. Se
  surgir pedido de estratégia de box, recusar no primeiro build.

## 8. Decisões tomadas

1. **Engine: Godot 4.4.** 2D isométrico e exportação mobile resolvidos; código de save e
   offline de The Way Back (branch `backup/the-way-back`) pode ser adaptado.
2. **Offline de verdade.** As corridas acontecem com o app fechado e são resolvidas em
   lote na volta, pela simulação headless, com relatório de resultados, dinheiro e
   prêmios. Há um teto de tempo offline; o valor é balanceamento, fica em JSON.
3. **Um carro por vez, com fila de repetições.** O jogador escolhe evento, carro e número
   de repetições; offline, a fila é consumida. Corridas simultâneas com vários carros
   ficam fora do primeiro build.
4. **Licença é requisito + treino no relógio** (decisão 99; substitui os contratos de
   certificação e os testes de tempo). Cumpridos os requisitos, o jogador inicia o treino;
   ele corre em tempo real, com o app aberto ou fechado, e ao terminar a licença é
   concedida sozinha. Não há avaliação, montagem nem medalha.
5. **Usados giram por número de corridas**, não por tempo real. Cada corrida conta como
   um dia, como na referência. Imune a manipulação do relógio; a fila offline avança o estoque.
6. **Fabricantes: 3 no primeiro build, 8 a 10 no lançamento.** Primeiro build: uma
   japonesa, uma alemã e uma de outra escola. Lançamento: ~3 japonesas, 2 alemãs, 1
   italiana, 1 americana, 1 britânica, 1 francesa.
7. **Nome oficial: Second Drive** (antes Apex Garage, provisório; trocado para Chrome &
   Wreckage pela decisão 44). A pasta de dados do
   aparelho continua "Apex Garage" para preservar os saves. Recomendada a busca de marca
   registrada e nas lojas (App Store e Google Play) antes do lançamento.

### Decisões de implementação (aprovadas)

8. **Ordem:** etapa 7 (usados, licenças, carros-prêmio) antes da 6 (visualização).
9. **Licença:** testes com pista, voltas, condição e restrição fixas; tempos de ouro,
   prata e bronze em `licencas.json`; concedida com todos os testes em bronze ou melhor.
10. **Usados:** como na referência — janelas de dias com preço por carro, vindas da lista de
    usados do disco (60 períodos de 10 dias). Sem quilometragem. (Substituiu a versão
    com quilometragem sorteada, que não existe na referência.)
11. **Piloto do jogador:** perfil fixo (`carreira.json`), sem evolução.
12. **Eventos:** restrições da referência (potência efetiva, tração, categoria, fabricante, ano,
    licença); jogador larga em último; prêmio por posição a cada disputa; carro-prêmio só
    na primeira vitória.
13. **Duração na fila:** uma corrida dura em tempo real o mesmo que dura simulada. O tempo
    ausente acima de `teto_offline_s` é descartado e a fila continua de onde parou.
14. **Save:** guarda só ids e estado do jogador; os números voltam de `data/` no load,
    então rebalancear não quebra saves.
15. **Visualização:** retrato 720×1280; geometria derivada dos trechos (curvas com
    `sentido`); carro provisório desenhado por código em 16 direções, com tamanho fixo
    em pixels; telas com componentes padrão do Godot até a arte existir.
16. **Dados da referência:** `data/` vem do disco (SCUS-94488 v1.2) pelo extrator e importador
    em `tools/`. Carros fictícios ligados a modelos da referência; séries da referência renomeadas;
    nenhum nome, marca ou traçado da referência no build.
17. **Placeholders em blocos 3D** (pedido do usuário, substitui parte da 15): corrida em
    3D com câmera ortográfica isométrica seguindo o jogador e minimapa da pista inteira;
    carros de blocos (chassi, cabine, rodas) com proporção por categoria; oficina começa
    pela escolha do carro, com vitrine girando como na referência; ícones de carro e de pista
    nas listas. A posição lateral é só visual (a simulação é em uma dimensão): carros
    próximos abrem para faixas livres e não se atravessam; toque na troca de faixa
    aparece como tranco, sem efeito no resultado. A arte final continua a da seção 5.
18. **Colisão só visual.** O toque entre carros aparece na tela e não muda o resultado:
    na referência batida não tem dano, e a simulação já segura quem está atrás fora das zonas de
    ultrapassagem.
19. **Provas abertas como na referência.** Só licenças travam provas; o começo é guiado por
    objetivos e pelas "recomendadas para começar", sem esconder nada.
20. **Sem campeonato por pontos.** No disco da referência, o bônus de campeonato
    (`SeriesChampBonus`) só existe nas séries internacionais (GT3, GT5, GTW, FRE), fora do
    jogo; a tabela de pontos não está nas tabelas. Os eventos mostram o progresso da série
    (etapas vencidas), sem prêmio extra inventado.
21. **Preços e prêmios medidos antes de mexer.** `tools/medir_progressao.gd` mede, por
    fase e por perfil de jogador (`tools/agente.gd`), créditos por minuto de corrida e de
    renda, gastos e a tabela de compras; sessões e retornos usam os valores do playtest
    de ritmo. Ajuste, se houver, entra no importador.
22. **Tempos de licença por regra simples.** Só a licença sem contratos (SPORT) usa os
    testes. Limites pela mediana e quartis das provas que ela abre; tempos com o carro de
    fábrica: bronze = pior carro elegível, prata = percentil 75 do melhor carro inicial,
    ouro = percentil 25 do mesmo carro. Sem percurso nem melhorias.
23. **Carro original em código** (substitui os blocos da 17): carroceria contínua por
    seções, com proporção por categoria, para validar o estilo antes da arte final.
    Agora é o gerador dos sprites provisórios (decisão 31).
24. **Leitura rápida e estimativa sob demanda nas competições.** O cartão mostra
    "Potência/peso frente aos rivais: Acima / Próxima / Abaixo" (mediana dos rivais;
    limites provisórios +8% / −5%), que não é dificuldade: pneus, curvas e frenagem
    também contam. "Estimar desempenho" simula a prova com o carro em uso e mostra a
    faixa de posições, só quando o jogador pede.
25. **Torque e câmbio na simulação.** A curva de torque e as marchas vêm da referência; só a forma
    é usada, escalada para a potência efetiva. O câmbio ajustável oferece curto,
    equilibrado e longo (passo provisório). `tools/provas_profundidade.gd` verifica as três
    provas de profundidade: menos potente que vence onde é adequado, ajuste que muda
    com a pista e usado preparado que alcança carro mais caro.
26. **Renda e desafio separados.** Repetir uma prova (renda automática, fila com
    repetições) só depois de vencê-la; antes disso, cada inscrição é um desafio de uma
    corrida. Teste de preparação: compara duas preparações na prova, sem prêmio e sem
    contar dia. Após uma derrota, o resultado oferece "Testar preparação".
27. **Peças compradas × preparação equipada.** Peças pertencem ao carro; a preparação
    equipada muda de graça e pode ser salva com nome por carro. A fila guarda uma cópia
    da preparação (peças, câmbio e pneus) na inscrição: mexer no carro ou numa preparação
    salva depois não muda corridas já programadas.
28. **Campeonatos sem pontos neste build** (mantém a 20): rivais persistentes e progresso
    das etapas vencidas, sem classificação acumulada.
29. **Um carro por vez** (mantém a 3): sem ocupação de carros nem corridas paralelas; a
    utilidade da coleção vem das restrições e das características das provas.
30. **Hipótese de balanceamento, não regra:** uma compra importante custa de uma a duas
    sessões. Antes de ajustar preços: definir a duração da sessão e medir a renda ativa e
    offline.
31. **Arte final dos carros: um modelo 3D por carro** (`docs/carros_3d.md`; decisão do
    usuário em 2026-10-11, substitui os dois sprites por modelo). GLB low-poly com atlas
    de cores chapadas e lataria branca (o jogo pinta), usado na corrida, na arena, na
    oficina e nas fotos da loja; menus, diálogos e retratos continuam 2D. Migração carro
    a carro: sem modelo, o sprite antigo (`docs/arte_carros.md`); sem sprite, o carro em
    código. Sem pintura livre: cada modelo tem as cores de fábrica e a escolha é na
    compra. A corrida mantém os três estados de câmera: normal (de cima), foco (disputa,
    mais perto) e velocidade (inclinada, atrás do carro, com efeitos nas bordas),
    desligados por "Reduzir animações".

### Documento de implementação "Second Driver" (aprovadas em 2026-10-08)

Origem: documento do usuário com prólogo (Adrian), salto para Elena, equipe Second Driver
Motorsport, diálogos e licenças CLUB a ELITE. Onde contraria decisões acima, vale isto:

32. **História agora** (muda a regra 8 do README): diálogos e flags em dados; o
    DialogueManager é o único sistema novo e faz também o tutorial (TutorialAction).
33. **Licença híbrida** (muda a 4 e a 9): estados LOCKED → AVAILABLE → TRAINING (treino por
    tempo, timestamp absoluto, conta offline) → READY_FOR_EVALUATION → COMPLETE. A
    avaliação são os contratos de certificação. Requisitos combináveis com status na tela.
    IDs CLUB, SPORT, NATIONAL, INTERNATIONAL, PRO, ELITE ligados às licenças da referência.
34. **Offline só para repetição** (muda a 2): repetir prova já vencida roda offline; prova
    inédita, campeonato e corrida da história só com o app aberto.
35. **Campeonatos com pontos** (muda a 20 e a 28).
36. **Equipes, pilotos e carros nas corridas:** cada rival é um carro de uma equipe; a
    equipe tem piloto principal e segundo piloto; a cada corrida, 70% de chance de correr
    o principal e 30% o segundo, que pode ser até 20% pior.
37. **Fora:** taxa de inscrição e quilometragem/condição (a referência não tem; mantém a 10).
    Equipe do jogador (finanças leves, 2º carro e piloto) só na fase 9 do documento.
38. **Segundo piloto e gestão leve (fase 9):** o segundo piloto é só visual, com a
    penalidade de segundo piloto (36): corre a mesma prova com outro carro da garagem,
    sem contrato nem salário. Os ganhos são da equipe: vale quem chegar na frente
    (prêmio, vitória, carro-prêmio) e os dois pontuam no campeonato. Caixa único: o
    saldo do jogador é o da equipe. Patrocínio e staff por corrida, com valores do
    playtest. Fora: taxa de inscrição e manutenção (37).

### Monetização (decisão do usuário)

39. **Corridas aceleradas por vídeo com recompensa; sem banner fixo.** O jogador assiste
    a um anúncio por escolha e as corridas da fila andam 2× mais rápido por 30 minutos
    (prêmios iguais: só o tempo encolhe, a economia da referência não muda). Cada vídeo soma
    tempo; vale com o app fechado. Uma compra única **Sem anúncios** dá a aceleração sem
    o vídeo. Sem banner permanente, sem anúncio forçado e sem vender carros ou Giros.
    Fator e duração em `data/monetizacao.json`; teto diário de aceleração pendente
    (critério: playtest, mantendo a compra importante em uma a duas sessões, item 30).
    O anúncio real (plugin AdMob, Android/iOS) e a compra real entram depois do MVP;
    até lá, o jogo mostra os mesmos lugares com um vídeo de teste e a compra
    indisponível. Marcador da aceleração e engrenagem das configurações no cabeçalho.

### Frota (decisão do usuário)

40. **Frota sem carros abertos e sem repetidos.** Sem capota o piloto aparece, e as
    corridas não desenham piloto: todo carro aberto sai. Num jogo idle, carros do mesmo
    modelo com números quase iguais não têm função diferente: de cada grupo (mesmo
    modelo, inclusive vendido por duas marcas; mesma tração; de rua ou de corrida;
    potência ±10% e peso ±5%) fica um. Dos 618 da referência ficam 386. Rivais, prêmios e
    copas usam o substituto; saves migram para ele. Regra no importador
    (`reduzir_frota`), não à mão.

### Ritmo e lojas (decisões do usuário)

41. **Idle mais longo:** as voltas das provas sobem ×2,5 (as de 2 voltas viram 5; as
    demais na mesma proporção, resistência inclusive) e os preços de compra (carros,
    peças, pneus) dobram em relação aos prêmios. No importador (`FATOR_VOLTAS`,
    `FATOR_PRECO`); prêmios, bônus e saldo inicial não mudam.
42. **Lojas = workshops, sem usados.** As 6 workshops (`data/workshops.json`, logos em
    `arte/ui/workshops/`) seguem as regiões da referência: 4 do Japão (Hayase e Kanaya
    sozinhas, as outras marcas japonesas em dois grupos), 1 dos EUA e 1 da Europa
    (de 53 a 101 carros): a estrutura da referência (uma loja por marca, por região)
    agrupada. Toda a frota é vendida pelo preço de tabela, inclusive os modelos
    que na referência só existiam usados. Sem usados nem agenda; a Second Chance Motors fica
    só na história (garagem vazia da Elena).
43. **Garagem com vagas:** começa com 4; cada ampliação dobra as vagas. A 1ª custa a
    soma dos prêmios de 1º lugar das provas da licença Club × 2; cada uma seguinte
    custa o dobro da anterior (`data/garagem.json`).

### Chrome & Wreckage (decisões do usuário, 2026-10-10)

44. **Nome: Chrome & Wreckage.** A pasta de dados do aparelho continua "Apex Garage"
    (saves preservados).
45. **Campanha do dono para jogos novos.** O jogador é o novo dono de uma oficina; Mara
    Hayes, mecânica veterana, é a guia (falas curtas). Quem corre é um piloto fixo
    apresentado por ela (contratação fica para depois). Começa com a mesma montagem do
    Adrian (carro, pneu, primeira peça e o critério de saldo), sem licenças. Equipe na
    International e segundo piloto na Pro. Saves com Adrian ou Elena seguem a história
    deles. Dados em `data/historia.json` → `nova_campanha`, `dono`.
46. **Comentários de contexto:** no máximo um a cada 3 corridas
    (`reativa_intervalo_corridas`). Caixa baixo = o saldo não paga a peça mais barata do
    carro em uso. Só a Mara fala por enquanto; sem tela de histórico dos carros.
47. **Arena:** só o botão na barra de baixo, com ícone genérico e sem tela, até o modo
    existir. Sem regras de perda, reparo ou integridade de piloto por enquanto.

48. **Equipe da campanha do dono: Wreckage Motorsport** (`historia.json` → `dono.equipe`;
    saves antigos seguem Second Driver). Aprovados também: o comentário de compra cara
    acima do percentil 90 dos preços do catálogo e o tutorial de corridas na primeira
    prova que o carro em uso já pode correr.

### Arena (decisões do usuário, 2026-10-10; estudo de arena)

49. **Arena: perda do carro sempre.** Carro eliminado na arena sai da garagem para
    sempre. Só pode se inscrever quem tem **ao menos 2 carros** na garagem (nunca se
    perde o único carro). Prêmio por pontos (giros provocados de 90°/180°/360°,
    eliminações e sobrevivência), conversão para giros pelo critério do prêmio das
    corridas da mesma licença; sem reparo na primeira versão (quem sobrevive volta
    inteiro); só o carro sofre (nada com o piloto); abre com a licença National;
    qualquer carro da garagem, o peso conta no dano. **15 competidores por luta** (o
    jogador e 14 rivais; decisão do usuário em 2026-10-11), largando em roda de frente
    para o centro, com o semáforo 3-2-1 da corrida.
50. **Simulação da arena** (`sim/arena.gd`, `data/arena.json`): 2D, passo fixo e
    semente; dano em seis regiões pela energia do impacto (½·m_efetiva·v_normal²)
    sobre a resistência ½·m·v_ref²; eliminação com uma região da frente a 100% e ré
    para proteger a frente a 90% (limites do estudo); cinco estágios visuais. Valores
    de velocidade, raio e tempos provisórios até o playtest (com 15 carros, lutas
    de ~50–100 s).

### Gestão da equipe (decisões do usuário, 2026-10-11; estudo Grand Prix Story)

51. **Patrocínio é a renda offline** (`GestaoEquipe`, `data/equipe.json`,
    `data/patrocinadores.json`). Corridas continuam com o app fechado só depois de
    começar com o app aberto; o patrocínio rende por hora no relógio real, também
    fechado (até `teto_offline_s` de ausência). Abre com a equipe (International):
    ofertas de patrocinadores de licença até a do jogador, contrato por um prazo, renda
    por hora e bônus quando a corrida cumpre a condição dele. Substitui o patrocínio
    por corrida (B1 da demanda 03).
52. **Sede**: uma tela própria na aba Equipe com melhorias pagas com o caixa
    (contratos simultâneos, renda, bônus, desmanche): mais onde gastar.
53. **Desmanche**: além de vender, desmontar o carro vira crédito que só paga peças
    (antes do caixa), pela soma das peças compradas para ele.
54. **Evolução do piloto por treino** aprovada: o treino sobe o **ritmo** do piloto
    principal (a consistência quase não muda a corrida: ~0,3% do tempo, ruído de 2% por volta). Teto por
    licença: o maior ritmo que encurta em até 10% o caminho até vencer as provas dela
    (`tools/calibrar_treino.py`, decisão do usuário em 2026-10-11). O segundo piloto não
    herda o treino.
55. Todo sistema novo entra com a fala da Mara e o número visível na tela.
    Valores de 51–53: fatores sobre o prêmio de 1º lugar médio da licença, provisórios
    até o playtest.
56. **Pilotos** (2026-10-11): 40 rivais (20 equipes × 2), sem nomes repetidos; cada equipe
    tem um perfil (agressivo, equilibrado, cauteloso → `carreira.json` → `perfis_piloto`,
    a chance de tentar a ultrapassagem; valores provisórios até o playtest) e uma frase de
    personalidade, mostrada quando a equipe vence. O ritmo dos rivais não muda. O segundo
    piloto passa a ser escolhido entre 8 candidatos, dois por traço (Calculista, Destemido,
    Versátil, Instintivo; eram Constante, Agressivo, Barato e Promessa, renomeados pelo
    usuário em 2026-10-16; `docs/pilotos_candidatos.md`); custo e salário entram com o
    `custo_staff`.
57. **Câmera 3D** (2026-10-11, pedido do usuário): corrida e arena em perspectiva para o
    jogo se ler como 3D. Corrida: perseguição atrás e acima do carro seguido (32°, desce a
    16° e abre para o lado no modo velocidade); "Pista inteira" segue de cima, como o
    minimapa. Arena: inclinada (34°), girando devagar em volta da sua briga (você e o rival
    mais perto); fora da luta, enquadra os vivos.
58. **Pintura na Oficina** (2026-10-11, pedido do usuário; muda a regra de "sem pintura
    livre" da decisão 31): aba pendurada PINTURA; o jogador paga para trocar a cor da
    carroceria (a paleta de fábrica mais saturada) e pintar um de 15 desenhos (faixas,
    geometrias: xadrez, chevron, zigue-zague, círculo…) com cor da faixa e do filete. Fica no carro e aparece na
    oficina, na corrida e na arena. Preço: fator sobre o prêmio de 1º lugar médio da
    maior licença (`equipe.json` → `pintura`), a definir pelo usuário. O nome do carro
    desce para baixo dele, abrindo espaço para as abas.
59. **Arenas** (2026-10-11, aprovado pelo usuário): 4 originais (Pátio da Pedreira,
    National; Fosso das Docas, International; Anel do Ferro-Velho, Pro; Cratera do Vale,
    Elite), com o que dá emoção nas da referência de arena sem copiar nenhuma: muro em
    polígono irregular (cantos para encurralar), ilhas no meio que separam a briga e o
    chão que não é plano. O relevo (crateras, lombadas, morro, a borda subindo no muro)
    entra na física: a gravidade acelera na descida e freia na subida, então a cratera
    puxa a briga para o fundo e o morro joga quem passa; os carros sobem, descem e
    inclinam com o chão. Mesma área do círculo de 45 m; a luta sorteia entre as arenas
    abertas pelas licenças (`arena.json` → `arenas`, `sim/arena_forma.gd`). Rampas e
    saltos (carro no ar) ficam para uma segunda etapa.
60. **Equipes com 4 pilotos e cores próprias** (2026-10-11, pedido do usuário): cada equipe
    rival tem quatro pilotos, cada um com perfil (agressividade) e frase próprios; o
    titular corre na maioria das provas e, nas outras, sai um dos outros três. Cada
    equipe tem cores (carro, faixa, filete) e seus carros correm nelas, com um desenho de
    faixa sorteado por prova. Os 37 pilotos novos ainda não têm retrato.

61. **Arena em duplas, campeonato escalonado** (2026-10-11, pedido do usuário): na arena as
    equipes lutam em duplas e vence a última dupla com carro de pé (a IA não ataca o
    colega). O campeonato começa em 2×2 e cada vitória da dupla do jogador acrescenta uma
    equipe (2×2×2, 2×2×2×2…) até 10 equipes, 20 carros (`data/arena.json` →
    `campeonato`). O parceiro do jogador é o segundo piloto no carro dele (eliminado, sai
    da garagem) ou, sem segundo carro apto, o "Piloto da casa" num carro emprestado. As
    rivais entram com dois dos seus quatro pilotos, sorteados, nas cores da equipe.
62. **Blindagem e elenco da Wreckage** (2026-10-12, pedido do usuário): a Oficina ganha a
    blindagem em 3 níveis (cartão de escudo ao lado da velocidade máxima). É peso a mais:
    na arena a resistência cresce com a massa; na corrida o carro fica mais lento. Números
    provisórios, a confirmar: espelho da redução de peso da referência do próprio carro (nível k
    pesa o inverso do estágio k e custa o mesmo; `data/arena.json` → `blindagem`). Entram
    dez personagens com diálogos e tutoriais: Rico Salas (manobrista, janela Garagem),
    Kenji Arata (pintor, PINTURA), Harold Brandt (examinador da Vector Academy), Roxy Vega
    (organizadora da arena), Dex Kane (mecânico da arena, blindagem) e os vendedores
    Edgar Halloway (Charge Folio), Sal Moretti (Relay Room), Bianca Sterling (Brace Yard),
    Nora Lindqvist (Return Chapter) e Jade Ryker (Shared Grid). Spare Penny ganhou o
    vendedor Walt Pruitt quando chegou a arte (2026-10-17).
63. **Cabine de pintura** (2026-10-12, proposta do usuário avaliada): a PINTURA vira tela
    cheia (`ui/cabine_pintura.gd`) com o carro real em 3D fixo em cima (arrasto gira e sobe
    a câmera, pinça aproxima, vistas 3/4, lateral, traseira e topo da mesma câmera), abas
    CORES (um seletor de canal: carroceria, faixa, filete, com uma paleta só), FAIXAS
    (miniaturas renderizadas no próprio carro com cada desenho), IDENTIDADE (número de
    corrida 0–99 nas portas, capô e/ou teto, com cor e contorno; medido em metros, sem
    esticar) e ACABAMENTO (fosco, acetinado, brilhante, metálico), e ações fixas: DESFAZER
    (volta ao que estava ao abrir), CANCELAR e APLICAR. A prévia só troca parâmetros do
    shader (`CarroBloco.repintar`). Descartados: logos da equipe (o pacote de logos não está
    no projeto), pinturas recentes (sem histórico), desgaste, rodas e vidros. Os desenhos
    removidos antes (bolinhas, ondas, transversais, pontas, tigrado) continuam fora.
64. **Identidades das equipes** (2026-10-12, pacote do usuário avaliado): 20 emblemas sem
    texto (`arte/equipes/emblemas`, 512 px webp, catálogo em `data/emblemas.json`). As 10
    identidades rivais (nome, logo, paleta, família do número) entram em 10 das 19
    equipes já existentes, as de símbolo ou cor mais próximos, mantendo ids, pilotos e
    licença: Redline Union, Blackwater Racing, Iron Vultures, Redemption County, Velvet Thunder,
    Copperhead Motors, Hollow Saints, Blue Collar Syndicate, Midnight Relay e Last Exit
    Club; as outras 9 seguem sem logo até haver arte. Rival na pista: cores da equipe,
    desenho sorteado (decisão 60), número da vaga do piloto (equipe × 4 − 3 + vaga) nas
    portas, na família da equipe, e o logo nos paralamas. Equipe do jogador: nome livre
    (padrão Wreckage Motorsport) e um dos 10 logos, independentes, no save
    (`Jogador.identidade`). Cabine: abas Pintura (base, secundária, acento, largura,
    espelho), Grafismos, Identificação (nome e logo da equipe, encaixes do logo — paralamas,
    lateral traseira, capô, traseira —, número com cinco famílias, tamanho, suporte em
    círculo) e Acabamento (com poeira e arranhões numa camada à parte); desfazer e refazer
    passo a passo. Fora: cor por região e rodas/vidros (sem malhas separadas confiáveis),
    sujeira dinâmica de corrida.
65. **Animação dos diálogos** (2026-10-12, aprovado pelo usuário): pausas no texto depois da
    pontuação; respiração do personagem parado; entrada própria de cada um
    (`personagens.json` → entrada: firme, rápida, pesada, quique, passo, esmaecer,
    tá-dá, elegante, curta); caixa com a faixa e o nome na cor de quem fala, subindo ao
    aparecer, e "toque para continuar" pulsando só com o texto pronto; dois em cena (quem
    escuta recua para o outro lado, menor e mais escuro, e volta à frente quando fala);
    `[IMPACTO]` no roteiro (salto curto, usar pouco). No tutorial, o busto de quem fala
    (corpo sem fundo, medidas em `personagens.json` → busto) com a cabeça inteira acima
    da caixa e o corte rente à borda de baixo. "Pular" sobe quando a caixa desce. Tudo
    vira corte seco com Reduzir animações.
66. **Peças e The Grid** (2026-10-12, pedido do usuário): peças são um recurso próprio
    (`economia.credito_pecas`), mostrado no cabeçalho. Vêm do desmanche, dos carros
    perdidos na arena (o do jogador e o do parceiro) e dos rivais que a dupla do jogador
    elimina; pagam só a blindagem. Quantas peças um carro rende
    (`GestaoEquipe.pecas_do_carro`): `fator_pecas` × (revenda + peças compradas) ×
    bônus da Sede — critério provisório, a confirmar. A lista negra ("The Grid") fica na
    tela de Licenças/Carreira: dez equipes (`equipes.json` → `grid`, 10 a 1), vencidas
    uma por vez ganhando uma prova em que a da vez correu ou a arena com ela presente
    (`TheGrid`, `jogador.grid`).
67. **The Grid: risco, revelação e ficha** (2026-10-12, proposta "The Grid Pack" do
    usuário, protótipo): ao vencer a equipe da vez, a tela Carreira desce até o Grid, um
    risco (camada, não mexe no emblema) atravessa a vencida, a próxima acende e abre a
    ficha dela (VinhetaGrid): posição, emblema, nome, licença e jeito, dois pilotos (o
    primeiro na frente; sem retrato, a silhueta do jogo) e como desafiar, com botões para
    Corridas e Arena. A #10 tem ficha de entrada; depois da #1, a ficha do fim. Tocar numa
    linha vencida ou na da vez reabre a ficha. Risco e ficha não se repetem
    (`jogador.grid` → `riscar`, `vistas`). Aceitas pelo usuário (2026-10-12): dirigente por equipe (nome em
    `equipes.json` → `dirigente`, arte em `retrato_dirigente`, pedida pelo pacote
    `tools/pacote_arte_grid.py` com os retratos de todos os pilotos rivais, pessoas no estilo
    aprovado dos personagens; os retratos de animal antigos foram descartados; entra com
    `tools/importar_arte_grid.py`); carros especiais do catálogo da licença da equipe, nas
    cores dela (critério: o carro do rival da série na referência); modo do desafio pelo jeito da
    equipe; desafio dedicado depois disso, com o prêmio da prova existente; decisão 61
    mantida; CRED fora.
68. **Escalação, uma corrida por vez e patrocínio na Carreira** (2026-10-12, decisão do
    usuário; substitui a fila de repetições da decisão 3 e a decisão 34). Uma corrida por
    vez, sem repetições programadas; depois de largar, ela termina mesmo com o app fechado.
    Fora isso, offline só rende o patrocínio, administrado na tela Carreira (na Equipe desde a
    decisão 103). Corrida e arena
    nunca ao mesmo tempo. Escalação no topo da Oficina (`Escalacao`, `jogador.escalacao`):
    vaga CORRIDA (nas corridas só corre um piloto da equipe) e vagas ARENA 1 e ARENA 2 (a
    dupla), três carros diferentes; escalado não se vende nem se desmonta. A arena pede 3
    carros, as duas vagas de arena e o segundo piloto contratado (sem carro emprestado).
    Pendente: pilotos só de corrida e só de arena, resolvido na tela de pilotos.
69. **O jogador administra; pilotos de corrida e de arena** (2026-10-12, decisão do
    usuário). O protagonista não pilota: quem corre é contratado na tela de pilotos (aba
    Equipe). Três vagas (`jogador.pilotos`): 1 piloto de corrida (nas corridas só ele corre)
    e 2 de arena (a dupla). Cada candidato tem o seu tipo (`carreira.json` →
    candidatos → `tipo`; desde 2026-10-16, por decisão do usuário, um candidato de cada
    traço em cada vaga, para os pilotos da tela serem diferentes: na referência a habilidade da IA
    é uma só por prova, então não há dispersão de piloto para importar),
    sem salário novo (a gestão segue a tabela atual). Tutorial: depois dos freios, a Mara
    abre a Equipe e o primeiro piloto (de corrida) é contratado antes da primeira prova
    (CW_P03C/D); o piloto da casa saiu. Com 3 carros na garagem vem o tutorial da arena
    (CW_P07, gatilho GARAGEM_TRES_CARROS), que libera os pilotos de arena e abre a arena
    (no lugar da licença mínima, que ficou só para o prêmio de referência). Caixa, Sede e
    patrocínio continuam abrindo com a International (flag GESTAO_LIBERADA).
70. **Atributos por piloto e treino como energia** (2026-10-12, sugestão aprovada pelo
    usuário, inspirada no Grand Prix Story). Cada piloto contratado tem os três números que a
    simulação lê, tirados de números que já existem: agressividade pelo perfil do traço
    (`perfis_piloto`), consistência do piloto-base, ou com a perda do segundo piloto nos
    traços mais crus (`tracos` → `perfil`, `menos_consistencia`), e ritmo do piloto-base mais
    o treino dele. O treino passa a ser por piloto e aparece como energia: começar gasta a
    energia, ela volta enchendo no tempo do treino de hoje e o nível entra quando enche.
    Correr cansado custa consistência (`equipe.json` → `treino.cansaco` = 0,2, aprovado: a
    perda do segundo piloto, proporcional à energia que falta); a corrida guarda o piloto da
    inscrição (`fila.piloto`). Rivais da arena usam o piloto-base.
    Próximos (aprovados): mercado de pilotos que muda e pilotos das equipes vencidas do
    Grid; experiência por corrida/luta; embalo; contrato por temporada.
71. **Mercado de pilotos, experiência e embalo** (2026-10-12, critérios aprovados pelo
    usuário). Mercado (`carreira.json` → `equipe_jogador.mercado`): mostra 4 de corrida e
    4 de arena (os que já existiam) e renova a cada 24 h (a duração de um contrato de
    patrocínio); vencer uma equipe do Grid põe os pilotos com retrato dela no mercado, com o
    traço pelo perfil da equipe; contratado, ele não corre mais pela equipe de origem.
    Experiência (`equipe.json` → `treino.xp_por_nivel` = 3, as etapas de uma série): a cada
    3 corridas (piloto de corrida) ou lutas (pilotos de arena), um nível de treino, até o
    teto da licença. Embalo: 3 vitórias seguidas deixam o próximo treino com metade do
    tempo. Contrato por temporada fica para quando o custo da equipe sair do playtest.
72. **Pilotos com retrato genérico** (2026-10-12, escolha do usuário: "genérico em tudo").
    Todo piloto — candidato, mercado, rival — usa um de 12 retratos genéricos
    (`arte/pilotos/genericos/generico_NN.png`, corpo inteiro em `genericos/corpo/`), sempre o
    mesmo para o mesmo piloto: a ordem dos dados (candidatos, depois as equipes) dá o número,
    então os quatro pilotos de uma equipe não repetem rosto. Os 01–08 são os 8 candidatos
    aprovados; os 09–12 vêm do pedido `tools/pacote_arte_grid.py` (corpo inteiro; o retrato
    sai recortado do corpo). Os pilotos não têm mais campo `retrato`. Dirigentes e
    personagens da história seguem com arte própria. Com isso entram no mercado os quatro
    pilotos de cada equipe do Grid vencida, o traço pelo perfil do próprio piloto (o da
    equipe, se faltar): 48 pilotos no total, 17 de corrida e 31 de arena.
73. **Introdução e história do dono** (2026-10-12, proposta do usuário avaliada; imagens
    do usuário). A abertura (`ui/abertura_cinema.gd`, `arte/abertura/roteiro.json`) passa a
    ser os últimos carros da Wreckage saindo da arena no guincho e a Mara diante das contas,
    em imagens paradas que entram em fusão, sem música nem zoom (pedido do usuário; o
    mesmo vale para o fundo e as ilustrações dos diálogos); a noite do acidente sai. Depois, a chegada (ilustração `chegada`, o jogador em silhueta): o jogador
    responde ao anúncio e assume a administração; a Mara cuida dos carros. A cena pede o nome
    do administrador (`jogador.nome_admin`, ação `PEDIR_NOME`, trigger `NOME_DEFINIDO`,
    variável `{admin}`); a equipe segue Wreckage Motorsport (o nome se troca na cabine de
    pintura, como antes). O cenário `oficina_mara` é a oficina das imagens (o carro nos
    cavaletes). Primeiro objetivo, "De volta às pistas": renovar a licença = passar na
    licença Club, grátis como na referência (seção 8), sem prazo, com os giros das provas abertas;
    aprovada, a Mara apresenta o The Grid. Avaliado e não adotado agora: taxa de 25.000 giros
    pela licença (número sem fonte; muda a seção 8) e o CRED (sem desbloqueios próprios nem
    números com fonte; volta junto com os carros especiais do Grid). Fala final do Grid (#1)
    pela proposta. A revelação do passado da Mara e o rival da #1 ficam para quando os
    carros especiais do Grid forem definidos. Sem prazos, timers ou falência por tempo; sem
    assistente da Mara.
74. **Desafios do The Grid, revelação da Mara, pinturas pelo Grid e blindagem** (2026-10-12,
    definidos pelo usuário). A equipe da vez só fica para trás no desafio dela
    (`data/grid_desafios.json`, `GridDesafio`); vencer prova comum ou campeonato da arena não
    conta mais. #10 corrida pista 1, 2 voltas · #9 pista 2, 3 · #8 arena 1 · #7 pista 3, 4 ·
    #6 pista 4, 5 · #5 arena 2 · #4 pista 5, 6 · #3 arena 3, melhor de 3 · #2 pista 6, 8 ·
    #1 confronto na arena, melhor de 3. Corrida 1x1 (piloto de corrida contra o da equipe),
    arena 2x2 (a dupla contra dois pilotos de arena da equipe). Pistas 1-6: Oval do Planalto,
    Lago Sereno, Cais Velho, Colinas do Vinhedo, Alto da Capela (curto), Alto da Capela;
    arenas 1-3 e confronto: as da decisão 75 (antes: Pátio da Pedreira, Fosso das Docas, Anel do Ferro-Velho, Cratera
    do Vale; em ordem de dificuldade, troca-se no JSON). Melhor de 3: os carros
    destruídos são trocados pelos próximos da garagem entre os rounds, por isso pede 6 carros
    fora o de corrida (a série fica salva entre rounds). Carros especiais: os adversários
    reais (referência) da licença da equipe pela maior relação potência/peso (sem repetir no Grid:
    da #1 para a #10, cada equipe fica com os melhores ainda livres da sua licença), com o ajuste de
    potência deles; a licença da equipe é exigida. Sem prêmio em giros na corrida do desafio
    (a recompensa é o Grid e as pinturas); na arena vale o prêmio por pontos. Revelação: ao
    chegar à #6 (a próxima é arena), a Mara conta que a Wreckage perdeu tudo numa noite de
    arena (ilustração `noite_da_arena`, a da abertura). Pinturas: 6 desenhos e nenhum logo no
    começo; cada equipe vencida libera 1 desenho e 1 logo (16 e 10 no topo). Blindagem: peças
    (desmanche e arena) e os giros completam o que faltar.
75. **Arenas novas** (2026-10-12, aprovada pelo usuário). Seis, no formato da decisão 59
    (`tools/arenas_novas.py` grava em `arena.json` → `arenas`; mesma área do círculo de 45 m,
    largada conferida para até 20 carros). Para as licenças sem arena: Várzea do Galpão
    (Club; pátio quase plano, sem ilhas) e Curral dos Fardos (Sport; hexágono, dois fardos).
    Exclusivas dos desafios do The Grid (`grid: true`, o campeonato não sorteia): Pátio da
    Fundição (#8, galpão com docas e três pilhas de lingotes), Estacionamento da Última
    Saída (#5, em L, quatro colunas e rampas), Bacia de Blackwater (#3, reservatório oval de
    fundo fundo e anel de lombadas) e Claustro Vazio (#1, em cruz, o altar no meio, uma
    cratera em cada braço e o muro mais alto). As quatro originais seguem no campeonato.
76. **Cenas paradas** (2026-10-12, pedido do usuário: "não está bom"). Sem música na
    abertura (sai `arte/sons/abertura.ogg` e o gerador), sem zoom lento nem câmera
    seguindo quem fala nas imagens (abertura, cenários e ilustrações dos diálogos) e sem
    personagens se mexendo: sem respiração, sem entrada deslizando ou quicando, sem salto
    no [IMPACTO]; o personagem aparece no lugar num esmaecer curto e o ouvinte vai direto
    para o lado dele. Substitui a parte de animação dos personagens da decisão das
    animações do diálogo; o campo `entrada` de personagens.json sai.
    Abertura final (pedido do usuário): as 5 cenas do usuário (`arte/abertura/cena_1..5`:
    a corrida noturna, a arena destruindo os carros, a Mara vendo o guincho, a Mara com as
    contas, a chegada do jogador), cada uma entrando e saindo pelo preto, e o logo. A cena 5
    é também a ilustração `chegada` do diálogo e a cena 3 a `noite_da_arena` da revelação.
77. **Oficina no padrão do mockup do usuário** (2026-10-12). A lista de peças vira cartões
    com o ícone da peça (`arte/ui/pecas/<categoria>.png`, pack do usuário, escala uniforme),
    o nome, a barra inclinada com a conta e a seta. Duas abas: Preparação de corrida (motor
    à esquerda: aspiração, escapamento, computador, freios, balanceamento, kit de corrida,
    cilindrada; chassi à direita: câmbio, pneus, peso, polimento de dutos, resfriamento;
    só as que existem para o carro) e Preparação de arena (a blindagem). As barras de
    progresso ficam mais altas e mais inclinadas, em todo o jogo. Do mockup não entram: nitro
    (não existe na referência) e "Teste" no lugar de Acelerar; a escalação continua no topo.
    Depois (pedido do usuário, para desafogar): a Preparação de corrida vira uma roleta, uma
    categoria por vez num cartão grande (ícone, barra, a próxima peça com o preço e o botão
    Melhorar; ‹ › ou deslizar), com a faixa de ícones de todas embaixo (a atual destacada,
    em ocre as que já têm peça; tocar leva a ela). A arena usa o mesmo cartão. A tela não rola.
    O carro da Oficina fica parado em três quartos (não gira); ao trocar de carro, o novo
    entra de lado numa derrapada (~1,1 s, deslizando de lado) e assenta. Com "reduzir animações", só troca.
78. **Arenas pelo terreno** (2026-10-13, pedido do usuário: "mudar só o contorno e colocar
    ilhas de pneus não tem graça; o legal é trabalhar o terreno como curvas de nível").
    O relevo ganha termos novos além de montes e crateras: valas e diques (com fundo plano),
    rampas (sobem e caem numa queda curta) e platôs ou poços de topo plano, em círculo ou
    polígono, que empilham em degraus (`sim/arena_forma.gd`; a física e o desenho do chão
    usam a mesma conta). As ilhas de pneus saem; fica só o monte de sucata do Anel do
    Ferro-Velho. As dez arenas são redesenhadas pelo chão (`tools/terreno_arenas.py`, que
    confere as largadas em chão plano e a inclinação máxima e gera a prévia de cima):
    Várzea (vala rasa com passagem, duas rampinhas), Curral (valas em X com poço no
    cruzamento, rampas para ele), Pedreira (bancadas em três degraus, entulho, rampa na
    beira), Docas (fosso de leste a oeste com duas passagens, cais alto com rampa, rampa de
    salto), Ferro-Velho (o monte num morro, anel de vala com três passagens, rampas
    tangentes), Cratera (mesa com caldeira, três rampas de subida, três ravinas), Fundição
    (plataforma de carga com rampa, dois poços, dique baixo), Estacionamento (dois andares
    com rampas, rampa de saída, doca rebaixada), Blackwater (reservatório em três degraus,
    canal do vertedouro, rampas na bancada) e Claustro (altar alto com rampas leste e
    oeste, fossos nos braços norte e sul, criptas rebaixadas). Alturas e formas são desenho;
    ajustar no playtest.
79. **Ajustes da luta na arena** (2026-10-13, teste do usuário no celular). Placar começa
    recolhido (só "N restantes"); um toque abre e ele desce até quase a tela toda (linhas
    maiores, crescem com poucos carros); o toque do celular e o clique emulado contam uma vez
    só. A integridade (os seis quadrados) sai do placar, que mostra equipe, piloto, modelo e
    "FORA"; a dos carros da sua equipe fica grande embaixo (`PainelVidaArena`). A fumaça
    leva a cor no material (no renderizador de compatibilidade a cor da partícula chegava
    preta: a "bola preta" no capô). Capotagem (só visual): batida de lado a partir de 0,2
    de dano (~5 por luta de 10 carros) dá uma volta inteira no ar e cai nas rodas; o
    eliminado nela fica de teto para baixo. Terreno mais suave (`tools/terreno_arenas.py`:
    alturas × 0,7, encosta com 2,5 m por m de desnível, rampa até 30%; inclinação até ~0,6
    por termo) e subida que pesa: além da gravidade, a força do motor cai com a inclinação
    contra o carro (`subida_perda` 0,5 em `arena.json`, provisório; mais que isso prendia
    carro dentro de vala).
80. **Frota 360** (2026-10-13, decisões do usuário). A frota do jogo passa a ser a do pacote
    "Veículos 360" (modelos 3D com rodas separadas e proteções por região), mais os 3
    modelos aprovados que vieram fora da lista (Nimbo, Bastion, Aster): 363 carros no lugar
    dos 386. Números: o carro que existe na referência (71, casados à mão pela geração) usa o
    disco; os outros, a ficha real pesquisada (potência, peso, tração, ano) com um doador
    da referência (mesma tração, potência e peso mais perto) para curva de torque, câmbio,
    aderência, freio, distribuição de peso e peças; preço = preço do doador ×
    (cv/cv)^1,235 × (kg/kg)^-0,900 (regressão nos carros de rua da referência). Sem peso na
    ficha: peso pelo volume do modelo (regressão nas fichas com peso, R² 0,78); sem ficha
    (3) ou sem referência real (os 3 aprovados): clone do carro antigo de medidas mais
    parecidas, provisório. Marcas: as reais reusam as fictícias que já existiam (cada marca real
    → uma fictícia) e as que faltavam ganharam 14 novas (Feldhaus, Corsalto, Taurenza,
    Tridella, Vantra, Norrvik, Halberton, Ashworth, Ridgeway, Voltane, Ishigumo, Volnar,
    Iporã, Brakhaus Industrial); categorias novas picape, utilitário e pesado. Os 3
    caminhões (Brakhaus) são chefes: fora da loja, das provas e dos rivais sorteados.
    Saves: cada um dos 618 ids antigos vai para o carro novo mais parecido da mesma marca
    (`carros_removidos.json`). Blindagem visível: o nível de blindagem do carro monta as
    proteções do modelo (moldura, contraventamento, placa) na Oficina e na arena; na
    arena a proteção da região atingida se solta e cai. Os modelos ainda estão em revisão
    artística (o REVIEW.json do pacote; `arte_provisoria` nos dados). Fontes reais (nomes,
    fichas, casamento) ficam só em `referencia/frota360/`, fora do git e do build;
    ferramenta `tools/frota360.py` → `tools/importar_referencia.py --frota`.
81. **Pacote de pista, piloto e dano** (2026-10-13, decisões do usuário). A simulação da arena
    ganha fogo, fuga e explosão: o carro eliminado com o motor destruído (a outra metade da
    frente também no limite da ré) pega fogo; os outros só param e fumegam. Tempos e raio
    da bancada do pacote (fogo 2 s depois do motor parar, piloto sai 1,5 s depois, explosão
    3,5 s depois da saída com o piloto a 7 m; raio 12 m, força (1 − d/12)²). A explosão dá
    dano a quem está perto (a força × uma batida a v_ref contra o carro que explodiu, na
    região virada para ela; pode eliminar); depois do fim da luta, só visual. O piloto corre
    para o muro mais perto; carro andando o atropela: ele é lançado, fica caído, levanta e
    continua até sair. Atropelado da sua dupla fica fora (tempo real) o mesmo tempo do
    próximo nível de treino dele (decisão 83) e a arena espera. O amassado continua. Na tela
    (física só de tela, sem mudar o resultado): fumaça clara que escurece, fogo, porta, piloto
    com ragdoll, explosão com rodas e chapas soltas e carcaça queimada; na arena, barreiras de
    concreto que racham e quebram no muro, barreira de pneus que desmonta, cones, barris e
    árvores fora do muro, empurrados pelos carros (corpo cinemático); nas pistas de corrida,
    cones e pneus só de decoração. Arte e animações do pacote em `arte/dano/` (animações CC0).
82. **Capotagem, amassado e medidas** (2026-10-13, teste do usuário). O carro que capota fica de
    teto para baixo (sem a volta inteira de volta às rodas, que parecia artificial; como no
    referência de arena); o nariz sobe menos nas batidas de frente/trás. Amassado com metade da
    profundidade. A arena usa as medidas do modelo 3D de cada carro (`comprimento`, `largura`
    em carros.json, do model-info do pacote pelo importador): antes todos tinham 4,4 × 1,75 m
    e os maiores se sobrepunham na tela.
83. **Capotado fora da luta; recuperação do atropelado** (2026-10-13, decisões do usuário). A
    batida de lado com dano ≥ `capota_dano` (0,2, o limite que a tela já usava) capota o carro:
    ele cai de teto para baixo e sai da luta, como na referência de arena (~20% dos carros por
    luta); a eliminação conta para quem bateu. O piloto atropelado fica fora pelo tempo do
    próximo nível de treino dele (`recuperacao_atropelo: "treino"`), sem o desconto do embalo.
84. **Ordem do tutorial do dono** (2026-10-13, pedido do usuário). O piloto vem primeiro:
    abertura → nome do administrador → a equipe nasce e a Mara pede quem vai dirigir (aba
    Equipe, contratar o piloto de corrida; o treino no relógio é citado) → ficha do carro e a
    peça que ela pede (freios) → Corridas, primeira prova aberta → resultado → Carreira
    (licença Club: treino e avaliação) → o resto como antes (lojas na primeira visita, arena
    aos 3 carros, gestão na International, The Grid). Antes, o carro vinha antes do piloto e
    Corridas, antes dos freios, mandava contratar numa aba que ainda não existia.
85. **Começo da campanha do dono** (2026-10-13, decisões do usuário; substitui a ordem da 84).
    História: a oficina da Mara está hipotecada; ela é ruim de negócio, mas domina oficina e
    preparação de pilotos; o jogador assume as contas e a dívida em troca de sociedade na
    oficina e na Wreckage. A dívida é só história: vencer o The Grid é o que salva a oficina.
    Ordem do tutorial: abertura e nome ("COMO VOCÊ SE CHAMA?") → The Grid (Carreira) →
    comprar o primeiro carro (a garagem começa vazia) → contratar o piloto de corrida →
    primeira prova → aprimorar o carro (a peça mais barata do carro em uso, que o prêmio da
    primeira prova paga) → segunda prova → licença Club → prova com a Club → patrocínio →
    arena (3 carros, depois do patrocínio). Números: saldo inicial = preço do carro novo mais
    barato com a potência do rival mais forte da prova aberta mais fácil (importador; hoje 658,
    o Vallon Vazante); provas abertas (sem licença) com 2 voltas; o patrocínio abre na
    primeira corrida com a Club e rende com o app fechado até 2 h na primeira licença, +1 h
    por licença conquistada (equipe.json); caixa e sede seguem na International. O carro dos
    cavaletes (Bancroft Arraia) chega na licença National com a peça mais forte de cada
    categoria (historia.json → dono.carro_mara).
86. **Tutorial em sequência, sem disputar a tela** (2026-10-13, pedido do usuário; ajusta a
    ordem da 85). Uma conversa nunca abre por cima de uma janela do jogo: espera o painel
    (resultado, carro novo) fechar; no fim da corrida, primeiro o resultado, depois a Mara.
    As exceções são as cenas que mostram algo dentro do próprio painel (peças, blindagem,
    garagem) e a da largada. O botão Pular fica sempre no mesmo lugar (alto, à direita). Depois
    da primeira prova não entra nada novo: o tutorial da Oficina começa da segunda prova em
    diante e só quando o caixa paga a peça pedida (condição demanda_paga). No dono, o que a
    Mara ainda não apresentou fica oculto: Lojas e Carreira depois do The Grid, Corridas
    depois do piloto, Oficina depois do tutorial dela, Arena depois do dela; na Carreira, a
    licença e a coleção só depois da conversa da licença. Ordem: … primeira prova → segunda
    prova → aprimorar o carro → prova → licença Club → …
87. **Uma campanha só** (2026-10-14, pedido do usuário). A campanha antiga (Adrian, o acidente,
    Elena e a Second Chance Motors) saiu do jogo: cenas, personagens, cenários, a volta de
    abertura e os cenários de teste dela. O jogo novo é sempre a campanha da oficina
    (Chrome & Wreckage). Saves antigos com Adrian ou Elena abrem, mas sem as cenas deles.
88. **Pilotos com rosto e intro das equipes do Grid** (2026-10-14, protótipo GridRivalIntro do
    usuário, sugestões aceitas). Os 84 pilotos (8 candidatos e 76 das equipes) têm retrato e
    corpo próprios (arte/pilotos/<id>.webp e corpo/); o genérico da decisão 72 fica só para
    quem não tiver arte. 17 pilotos trocaram de nome para casar com a arte; cada piloto de
    equipe ganhou número (o capitão, primeiro da lista, é o 1) e apelido em equipes.json. O
    rival corre com o traço do perfil, como no mercado (traco_por_perfil): o agressivo perde a
    consistência do segundo piloto. Na revelação (próxima equipe e entrada no Grid) abre a
    intro: terminal, emblema, os quatro pilotos (número, retrato que ganha cor, nome, apelido,
    estilo, carro especial do desafio, currículo, ritmo = teto de treino da licença,
    consistência e agressividade pelas regras, carimbo CAPITÃO/CORRIDA/ARENA) e o confronto
    com a sua equipe, o prêmio médio de vitória da licença em giros e o desafio. Toque passa
    para o próximo piloto; Pular vai ao confronto; Reduzir animações tira terminal, efeitos e
    digitação. Aberta da lista, segue a ficha (VinhetaGrid). Fontes: Big Shoulders e IBM
    Plex Mono (OFL).
89. **Abertura mais curta e nome no celular** (2026-10-14, pedido do usuário; ajusta a
    abertura final). A chegada não passa mais antes do logo: ela já é o fundo do diálogo
    (ilustração `chegada`), então a abertura fica com as cenas 1–4 e o logo, em ~19 s (antes
    32,5 s; `arte/abertura/roteiro.json`). No pedido do nome, o teclado do celular abre ao
    tocar no campo: a exportação Web liga o teclado virtual e, em tela de toque, o campo não
    pega o foco sozinho (o navegador só abre o teclado com o toque).
90. **Correções da auditoria** (2026-10-15, recomendações aceitas pelo usuário).
    - Save: a fila num desafio do Grid é válida (antes o save era recusado e o jogo
      recomeçava). Ao voltar de um cenário de teste, o jogo do jogador recarrega do zero.
    - Retomada do tutorial (`Historia.recuperar`, ao abrir): as flags que destravam telas
      saem do estado real (carro → equipe criada; piloto de corrida; Club; International →
      Caixa e Sede); o passo da chegada interrompido volta (pedir o nome, a conversa
      seguinte ou a apresentação do Grid). As Lojas aparecem com carro na garagem.
    - Arena do Grid: um carro sempre fica de fora (o da vaga de corrida ou, vazia, o de
      menor uid): a série nunca zera a garagem.
    - Corridas que terminam com o app fechado ou várias de uma vez disparam as conversas
      delas (Grid de cada uma, a chegada da última) depois do relatório.
    - Tutorial da peça: destaca a peça pedida (antes, os freios); a peça já comprada não é
      pedida. "Papel pronto" uma vez por licença. Licença concedida: primeiro o painel,
      depois a conversa. A contratação abre depois de a cena do carro fechar. O jogo abre
      na primeira tela já apresentada. A arena é conferida depois de cada conversa.
    - O resultado da corrida espera painel aberto, intro do Grid, luta e o pedido do nome.
    - Textos: piloto sem gênero fixo ({piloto}), jogador sem "sócio", blindagem paga com
      peças e o que faltar em giros, marcas dos vendedores conferidas com workshops.json,
      loja Spare Penny com a fala da Mara. Saem as cenas sem gatilho (CW_SYS04, CW_SYS09).
    - A escalação dos rivais é a da inscrição (os contratados ficam na fila).
    - Dados: a equipe do jogador em equipes.json é a Wreckage, sem pilotos fixos; a chave
      do código antigo sai das licenças; a abertura usa a ilustração `noite_da_arena` (cópia removida).
    - Web: texturas grandes com perda (pacote de 112 para 45 MB), malhas 3D sem LODs,
      sombras e tangentes, `docs/` fora do build, uma meta viewport (área segura do iPhone),
      aviso para girar o aparelho, save ao perder o foco, efeitos leves por padrão no Web,
      inclinação lida a 20 Hz, ícone de 512 px, deploy depois dos testes e só da main.
    - Pendências resolvidas depois (recomendações aceitas pelo usuário, 2026-10-16): saldo
      inicial mantido em 658 giros (o critério do carro mais barato vale sobre os carros
      novos; com 226 só um carro cabia); os 11 carros sem marchas no disco recebem o câmbio
      do carro mais parecido em tração e potência (importador, regra da decisão 69); todos
      os botões de ação com 88 px de toque (DISPUTAR, filtros de Corridas, Aplicar,
      Confirmar, Voltar à arena, fechar, amostras de cor); o pacote Web deixa de levar os
      GLB de carroceria (a frota inteira é gerada; ficam as blindagens).
    - Corrida resolvida aos poucos (engasgo das resistências): `Simulacao.iniciar` devolve
      um `Andamento` que avança por orçamento de tempo (`avancar(ms)`) e dá o mesmo
      resultado, bit a bit, de `Simulacao.correr` (que agora é o mesmo laço de uma vez,
      para testes, ferramentas e o offline). A inscrição só monta o grid; a principal
      resolve a corrida ~4 ms por quadro (`Fila.FATIA_MS`), a tela da corrida espera no
      grid com "Preparando a corrida..." e o 3-2-1 vem depois. Quem pede o resultado antes
      termina a mesma resolução, sem recomeçar. A estimativa de posição da prova
      (`Mecanico.avaliar_aos_poucos`) também é fatiada. O processamento ao abrir o app
      (antes do primeiro quadro) segue de uma vez.
91. **Visual dos carros: gerador facetado e rodas trocáveis** (2026-10-15, pedido do
    usuário: "o maior problema do jogo é a qualidade visual dos carros").
    - Verniz e reflexo do céu na lataria (`CarroBloco.reflexo`), sombra embaixo.
    - O gerador de imagens foi descartado. Os carros passam a ser gerados em código no
      estilo facetado dos pilotos (`visual/carroceria.gd`), com a forma de cada carro
      (`arte/carros3d/formas.json`) e uma linguagem por época, categoria e escola.
    - Processo pedido pelo usuário: melhorar um carro feio até aprovar e só depois todos.
      Carro piloto: Kanaya Kestrel, aprovado na versão com proporções da época (capô
      longo, estufa baixa, cunha), detalhes dos anos 80 e rodas rentes
      (`docs/carros_3d.md`). O gerado só substitui o GLB dos ids em `Carroceria.ATIVOS`
      e das épocas/categorias em `Carroceria.LIBERADOS`.
    - Folha da frota (recomendação aceita): liberados cupê, compacto e sedã dos anos 80 e
      90. Clássicos (até 1971): piloto Calderwood Sabre aprovado, cupê, compacto e sedã
      liberados. Picapes: piloto Kanaya Sulco aprovado, todas as épocas liberadas.
      Anos 70: piloto Hayase Cedro aprovado, cupê, compacto e sedã liberados.
      Modernos: piloto Hayase Granito aprovado, cupê, compacto e sedã liberados.
      Utilitários: piloto Kanaya Chapada aprovado, todas as épocas liberadas.
      Pesados: desenhados um a um fora do gerador (`visual/pesados.gd`), aprovados com a
      lança d'água do resgate mais comprida. A frota inteira usa os modelos novos; os
      GLB das carrocerias seguem no pacote até decisão sobre removê-los (~13 MB no Web).
    - Canhão d'água do resgate (pedido do usuário): gira para o rival e o jato empurra na
      simulação com 10.000 N (decisão do usuário; ~10x um canhão real de ~1.000 N),
      `data/arena.json` → `canhao.forca_n`: arrasta um carro parado de frente ou de trás
      e, de lado, quase vence a aderência.
    - Rodas: o mesmo conjunto para todos os carros, 8 desenhos (`visual/rodas.gd`),
      trocados na cabine de pintura (aba RODAS), gravados no carro; a troca não custa
      (preço da pintura ainda "a definir").
92. **Arquibancadas com público na arena** (2026-10-16, pacote enviado pelo usuário).
    Blocos de 6 m do pacote (`visual/arquibancada/`, malhas de caixa, público em
    MultiMesh) nos três lados mais compridos do muro, até 4 blocos por lado, de frente
    para a luta, atrás do muro de pneus. Só tela: a simulação não vê a arquibancada.
    Lotação pela licença da arena (CLUB meio vazia; SPORT e NATIONAL semi cheia; acima,
    cheia). O público faz a ola na largada, comemora as explosões (todas as
    arquibancadas) e as batidas fortes entre carros (a mais perto) e foge pela escada
    quando um carro bate forte no muro bem na frente dele (não volta até a próxima luta).
93. **Acabamento das arenas para a vista de longe** (2026-10-16, pedido do usuário com
    referência de maquete; recomendação aceita). `visual/cenario_arena.gd`, só tela:
    o terreno vira um bloco quadrado com as laterais em camadas de terra, sobre fundo
    claro; terra só dentro do muro e na faixa da barreira, grama fora; barreira de
    concreto contínua na linha do muro (pula a quebrável do pacote de dano) com pilhas
    de pneus nos cantos; alambrado; seis torres de luz; bandeirinhas por cima do
    alambrado; estrada de terra com portão e cercas no lado mais comprido sem
    arquibancada; pinheiros em grupos e pedras na grama (MultiMesh). Luz mais clara e
    câmera geral a 40° (era 58°). Segundo lote (aceito): terra própria (cor quente com
    manchas e rastros de pneu em arco numa textura gerada), relevo mais legível (topo
    dos platôs claro, fundo das valas escuro), divisa terra/grama em faixa contínua (sem
    degraus), losango na cor do carro sobre cada um na visão geral (os seus em âmbar),
    pedras no corte do bloco e sombra embaixo dele. Terceiro lote (aceito): paddock ao
    longo da estrada (tendas nas cores das equipes da luta, caminhão com carreta, guincho,
    barraca de comida), placas de patrocínio no alambrado com as marcas fictícias dos
    fabricantes do jogo, cobertura nas fileiras de trás das arquibancadas com faixa na
    cor de uma equipe, copas e bandeirinhas balançando com o vento (parado com Reduzir
    animações) e poeira atrás do carro acima de 7 m/s (sem ela em Efeitos leves).
    Temas (pedido do usuário: todas as arenas de uma vez), `data/arena.json` →
    `arenas[].tema` (nas de `tools/arenas_novas.py`, lá) e `visual/temas_arena.gd`, no
    canto do bloco mais longe da estrada: montanha (Cratera do Vale: picos com neve e
    riacho que cai pela lateral num poço à vista), pedreira (bancadas em degraus, brita,
    basculante), docas (mar ao longo de um lado, cais, navio, pórtico e contêineres),
    ferro-velho (pilhas de carcaças, pneus, guindaste com eletroímã), galpão (galpão
    vermelho, silo, plantação), fardos (fardos de feno, cata-vento que gira, caixa
    d'água), fundição (galpão em dentes de serra, chaminés com fumaça, tanques),
    estacionamento (vagas pintadas, carros, postes, placa da saída), lago (lago escuro,
    juncos, píer com barco, árvores secas) e claustro (colunas e arcos em ruína, torre,
    ciprestes). A visão geral enquadra o bloco inteiro (margem de 30 m em volta do
    muro) e, com tema alto, fica do lado oposto a ele, indo e voltando.
94. **Física da arena: capotagem, relevo e objetos** (2026-10-16, três problemas
    apontados pelo usuário). Capotagem: a tela não marcava o carro como capotando desde
    a troca para capota_dano (36f7c8c) e o segurava no limite de tombar; agora a batida
    que capota na simulação gira o carro até o teto e ele fica assim (com Reduzir
    animações, já de teto). Objetos: o corpo cinemático do carro na física de tela era
    filho do carro e era teletransportado, sem empurrar; agora é top_level e movido por
    ele mesmo, e cones, barris e barreiras são empurrados. Relevo: na tela, o carro sai
    do chão na crista de rampas e lombadas e cai pela gravidade (até ~2 m), com tremor
    na aterrissagem pesada; na simulação, a IA deixa embalar na descida
    (`descida_sobra` 3,0) e a subida tira mais força do motor (`subida_perda` 0,5 →
    2,0). Provisórios até o playtest.
95. **Jogo mais leve** (2026-10-16, itens 1 a 8 aprovados pelo usuário; o 9 ficou
    pendente). Arena: amassado com a malha pré-calculada (só soma o deslocamento e
    refaz as normais dos triângulos atingidos: 11 → 3 ms por quadro), público a 20 Hz
    quando reage e 5 Hz parado, peças fixas fundidas em poucas malhas por material
    (`FundirMalhas`: ~1.300 → ~260 chamadas de desenho), chão com a altura exata só
    perto do muro e malha indexada (montagem 1,7 → 1,1 s). Pacote: kit das pistas em
    WebP com perda 0,8 (7,5 → 1,4 MB), corpos dos pilotos em 512×768 (a maior exibição;
    6,8 → 5,0 MB), `pecas.json` agrupado por carro (1,44 → 0,56 MB; o `Dados` expande).
    **Pendente (item 9):** modelo de exportação Web do Godot compilado sem os módulos
    que o jogo não usa (`index.wasm` de 43,7 MB, 30,9 MB comprimido, é a maior parte do
    download). Exige compilar o motor (scons com `profile` de módulos desligados) e
    apontar `custom_template` no preset Web; fazer quando o build Web for para
    lojas/divulgação.
96. **Experiência do jogador** (2026-10-16, análise com o playtest da campanha;
    recomendações aceitas pelo usuário). Mede-se com `tools/playtest_campanha.gd`
    (o agente segue o que a tela sugere).
    - **The Grid depois da primeira corrida** (substitui a ordem da decisão 85): nome →
      carro → piloto → corrida → Grid. A apresentação das equipes ficou curta (~3 s até o
      Continuar, era ~35 s): o emblema da rival cai, o da Wreckage sobe, o corte e o VS
      batem; o confronto mostra a Wreckage no nosso lado.
    - **Primeira vitória cedo** (critério da Sunday Cup da referência: a primeira prova sugerida
      vencível com o carro que o saldo inicial compra): na primeira compra, cada carro
      mostra a força na estreia ("ESTREIA: MAIS FORTE/PARELHO/MAIS FRACO", frente ao
      rival mais forte da prova mais favorável); Corridas abre com a **Próxima prova** (a
      mais favorável ao carro) e o tutorial aponta para ela. 1ª vitória: 22 → 3 min.
    - **Comentários do dia a dia** (vitória, pódio, derrota, peça comprada): repetíveis e
      reativos, em rodízio; o fim de corrida dá a vez aos marcos antes deles. Maior vazio
      sem fala: 46 → 21 min.
    - **Arena na primeira sessão**: luta de demonstração com o carro da Mara (~7 min de
      jogo, simulada, sem prêmio nem perda); a arena de verdade segue abrindo com 3 carros.
    - **Aviso de fim de corrida** na versão web (Notification API, só com a aba em segundo
      plano; permissão pedida a partir da segunda corrida). **Pendente:** no celular, o
      Godot 4.4 não tem notificação local sem plugin (Android: plugin de notificação local
      com `AlarmManager`; iOS: `UNUserNotificationCenter`); fazer junto do build de loja.

97. **Pilotos: variação e pack premium** (2026-10-16, decisões do usuário). Cada piloto tem
    consistência e agressividade próprias, fixas, de uma calculadora
    (`EquipeJogador.variar`): as faixas saem dos dados (agressividade ± metade do menor
    intervalo entre os perfis; consistência ± metade da perda do segundo piloto) e
    `carreira.json` → `variacao_piloto.fator` escala no playtest. O ritmo segue a referência e a
    barra é uma escala própria: do pior piloto do jogo (35%, `PISO_BARRA`) ao premium (100%).
    Vantagem real do premium (2026-10-17): ritmo `carreira.json` → `ritmo_premium` = 1.023,
    medido com `tools/calibrar_treino.gd --licenca=INTERNATIONAL --meta=0.2` (o teto do
    treino comum é 1.007, medido no PRO). Pack premium:
    3 pilotos de elite (1 de corrida, 2 de arena; nomes inventados), compra única e
    permanente, 100% em tudo, sem cansaço. Vendido com dinheiro real numa tela de loja
    própria, separada (pendente: criar essa loja, com a loja do aparelho, como o Sem
    anúncios); na seleção os premium aparecem só depois de comprados e ficam sempre no
    mercado (flag PACK_PREMIUM).
98. **Combustível e repetição** (2026-10-17, decisões do usuário, números pelo ritmo medido
    no playtest da campanha: corrida mediana 7 min, 6-8 corridas nos primeiros 30 min, ~10/h
    depois). Tanque de 8 (`monetizacao.json` → `combustivel`), +1 a cada 15 min em tempo
    real, também com o app fechado; corrida e luta da arena (e desafios do Grid) gastam 1;
    treino de licença e tutorial (até liberar o ACELERAR) não gastam. Tanque vazio: o vídeo
    com recompensa enche o tanque inteiro. Repetir prova já vencida paga 50%, 25% e depois
    10% do prêmio, voltando a 100% a cada 24 h (`carreira.json` → `repeticao`); provas sem
    licença ficam fora, para não travar o começo (a renda inicial é repetir a primeira
    prova vencida). Não vem da referência.
99. **Licença sem avaliação** (2026-10-17, decisão do usuário: "as licenças são adquiridas
    com tempo correndo online e offline apenas"). Saem os contratos da Club (montagem com
    peças da escola, "O pequeno contra o gigante" etc.) e os testes de tempo da Sport em
    diante. Fica: requisitos (`licencas.json`) → iniciar o treino → esperar a duração
    (`treino_s`) em tempo real → licença concedida automaticamente
    (`Licencas.atualizar`, checado a cada segundo e na volta do app). O modelo de contratos
    e testes saiu do código na limpeza de 2026-10-17.
100. **Patrocínio: bônus pela dificuldade da condição e cartão compacto** (2026-10-17,
    recomendação aceita pelo usuário). O bônus de cada patrocinador é
    `bonus_fator × prêmio de referência × bonus_condicao[condição]`; o multiplicador é a
    frequência do pódio ÷ a frequência da condição, medidas por corrida no playtest
    automático (`tools/calibrar_bonus.gd`, grava `equipe.json → patrocinio.bonus_condicao`):
    o bônus esperado por corrida é igual em todas, e a condição mais difícil paga mais por
    vez. Condição sem amostra (menos de 30 corridas cumpridas) vale 1 até nova medição.
    Cartão: nome e licença (texto) numa linha; ramo, "24 h" e "rende com o jogo fechado"
    na segunda; renda e bônus à esquerda e o botão ASSINAR à direita.
101. **Loja de dinheiro real** (2026-10-17, pedido do usuário; recomendação aceita). Tela
    própria (painel LOJA), aberta das Configurações (seção LOJA, primeira), do botão
    "Pilotos de elite" na aba Equipe (só sem o pack) e da compra Sem anúncios da aceleração.
    Produtos em `monetizacao.json → loja.produtos` (compra única; cada um liga uma flag):
    Pack Elite (PACK_PREMIUM, os 3 pilotos premium) e Sem anúncios (SEM_ANUNCIOS: a
    aceleração sem vídeo). O preço é o da loja do aparelho (sku), nunca do JSON; até o plugin
    dela entrar (depois do MVP), comprar e restaurar avisam que a loja chega na versão final.
    Na Web a loja não aparece. O modo de playtest tem "Liberar as compras da Loja (teste)".
102. **Loja em tela cheia** (2026-10-17, sugestões aprovadas pelo usuário). A loja vira
    tela própria por cima de tudo (`LojaRealTela`): fundo da garagem dos pilotos escurecido
    com facho dourado; PACK ELITE com brilho que passa; os três premium de corpo inteiro
    (corrida na frente, arena atrás) com contorno dourado; nomes carimbados com vaga e frase;
    barras de ritmo, consistência e agressividade da Elite contra o melhor piloto que o
    mercado oferece no momento (valores do jogo); botão dourado pulsando com "Compra única ·
    para sempre"; Sem anúncios em faixa menor; aviso da loja do aparelho e "Restaurar
    compras" no pé. Comprado o pack: cerimônia (os três entram, carimbo ELITE, "Bem-vindos
    à equipe", "Ver pilotos" leva à Equipe). Frases dos premium em `carreira.json`.
103. **Patrocínio na Equipe e combustível no cabeçalho** (2026-10-17, pedido do usuário). A
    seção de patrocínio (contratos e ofertas) sai da Carreira e fica na aba Equipe, depois do
    caixa; a cena do patrocínio abre a Equipe. O combustível sai do topo de Corridas e Arena
    e fica na faixa do cabeçalho, entre o título e os giros, em todas as telas (bomba e
    "5/8"; vazio em vermelho); tocar abre a janela do combustível.
104. **Capacidade de renda offline por títulos** (2026-10-17, decisão do usuário: "o jogador
    gosta de evoluir a capacidade de retorno"; substitui o teto da decisão 85). Começa em
    2 h (`equipe.json → patrocinio.teto_offline_h_base`) e cada série com título soma 1 h
    (`teto_offline_h_por_titulo`); o cartão da série ainda sem título mostra "+1 H OFFLINE"
    e o resultado do título, "+1 H DE RENDA OFFLINE". O contrato de patrocínio dura essa
    capacidade (fixada ao assinar) e paga todas as horas dela, com o jogo aberto ou fechado:
    sem teto escondido. Licença nova não soma mais hora.
105. **Turno da Noite na loja** (2026-10-17, decisão do usuário: horas extras permanentes).
    Compra única de dinheiro real (`monetizacao.json → loja.produtos`, flag OFFLINE_EXTRA,
    `horas_offline` 6): soma 6 h à capacidade de renda offline para sempre, somando com os
    títulos; com ela o início (2 h) cobre uma noite (8 h) e os contratos duram 6 h a mais.
    Faixa na loja com o antes e depois ("2 h → 8 h"); sem aviso fora da loja (pedido do usuário).
106. **Preços da loja em dólar** (2026-10-17, sugestão aceita pelo usuário). Preço-base para
    cadastrar nas lojas do aparelho (cada loja converte por país), em `monetizacao.json →
    preco_usd`: Pack Elite US$ 9,99; Turno da Noite US$ 4,99; Sem anúncios US$ 3,99. A tela
    mostra o preço da loja do aparelho e, sem ela, esse preço-base. Na comparação da loja só
    entram os atributos em que a Elite supera o melhor do mercado por 10 pontos ou mais.
107. **Avisos do aparelho** (2026-10-17, decisão do usuário: liga por padrão, desliga nas
    Configurações → AVISOS). Ao sair de foco, o jogo agenda avisos do que acontece longe
    dele (contrato de patrocínio que acaba, tanque cheio, treino de licença pronto, piloto
    recuperado); ao voltar, cancela todos (`Notificacoes`). O envio usa o plugin de avisos
    locais do aparelho (singleton `LocalNotification`, a instalar no export Android/iOS);
    sem ele (editor, Web), nada acontece.
108. **Tela de volta e renda offline em dobro** (2026-10-17, sugestões aceitas pelo usuário;
    o vídeo só dobra a renda offline). Ao abrir o jogo, ou ao voltar depois de 5 min ou
    mais fora, com renda do patrocínio, abre "Enquanto você esteve fora" (`TelaVolta`): os
    giros do patrocínio contando, as corridas, o treino e os contratos encerrados; COLETAR
    fecha e DOBRAR COM VÍDEO paga a renda offline do patrocínio mais uma vez (uma vez por
    volta). Sem renda do patrocínio, o relatório das corridas de antes.
109. **Meta do dia** (2026-10-17, sugestão aceita pelo usuário). Na Carreira, depois dos
    objetivos: 3 tarefas por dia (meia-noite do aparelho), sorteadas pela data entre as que
    o jogador pode fazer (`carreira.json → meta_dia.tarefas`: corridas, vitórias, pódios,
    luta da arena, peça, contrato de patrocínio). Cumprida, COLETAR paga
    `recompensa_premios` (1) × o prêmio de referência da maior licença; critério: uma
    vitória a mais por tarefa, menos de meia hora de corrida no total. Ajustar no playtest.
110. **Cobrança do Google Play** (2026-10-17, sugestão aceita pelo usuário). `LojaPlay` liga a
    loja ao plugin oficial GodotGooglePlayBilling (consulta os preços dos skus, compra,
    reconhece a compra e restaura as já feitas); o Principal só cria a ponte quando o
    plugin está no export Android. Para valer: ativar o plugin no export Android, cadastrar
    no Google Play Console os produtos `pack_premium`, `turno_noite` e `sem_anuncios`
    (compra única, preços da decisão 106) e testar com uma conta de teste. iOS (App Store)
    fica para quando houver export iOS.
111. **Memória e corrida leve** (2026-10-17, defeito relatado pelo usuário: o jogo fechava na
    segunda corrida e pesava em 2×). Texturas de arte só ficam na memória enquanto alguma tela
    as usa; telas fora de vista (menos a corrida e a anterior) soltam o conteúdo; o estúdio de
    fotos guarda as 48 mais recentes e uma cópia webp das outras. Velocidade dos efeitos medida
    no relógio da corrida; efeitos leves sem o borrão de velocidade; cenário chapado numa malha.
112. **Recuperar carros da arena com vídeo** (2026-10-17, pedido do usuário). Na tela do
    resultado, os carros eliminados voltam como estavam (mesmo uid, escalação) e as peças do
    desmanche saem; uma vez por luta. Com Sem anúncios, sem o vídeo.
113. **Progresso fora do aparelho** (2026-10-17, sugestão aceita pelo usuário). Configurações →
    PROGRESSO: código do progresso (save comprimido, ~2 KB) para copiar e carregar em outro
    aparelho; no navegador, o aviso de que o jogo fica só nele. Android: `NuvemPlay` envia o
    código aos jogos salvos do Play Games ao ir para segundo plano e baixa pelas Configurações
    (plugin GodotPlayGameServices; os nomes da API ficam em constantes, a conferir na integração).
114. **Avisos desligados por padrão e idiomas previstos** (2026-10-17, pedidos do usuário).
    Notificações começam desligadas (Configurações → AVISOS liga). Configurações → IDIOMA:
    português e, marcados EM BREVE, English, Español, Français, Deutsch e Italiano (alfabeto
    latino, que as fontes cobrem). A tela de volta avisa, numa linha, quando o tempo fora
    passou do teto da renda offline.
115. **Proteção contra adulteração e cópia** (2026-10-17, pedido do usuário). Ferramentas de
    teste (modo de playtest, cenários, liberar as compras, Teste completo) só no editor e nos
    builds com a feature `playtest` (a demo web); o build da loja não as tem. Save e código do
    progresso levam selo HMAC-SHA256 (`Selo`, chave do segredo `SELO_CHAVE` no CI): código
    alterado não carrega; save alterado carrega sem as compras pagas. No Android, a consulta
    de compras da Google Play tira do jogo o que a conta não possui. Scripts exportados como
    bytecode comprimido (já era). Criptografia do pacote e validação em servidor: a decidir.
116. **Corrida e arena ao mesmo tempo** (2026-10-17, pedido do usuário; substitui a regra da
    decisão 61). A arena (e o desafio do Grid na arena) abre com uma corrida em andamento: a luta
    é resolvida na hora. Enquanto a tela da luta está aberta, a pista 3D da corrida sai da memória
    (`AbaCorrida.pausada`) e é remontada ao fechar, com a capa "Preparando a pista". O desafio
    do Grid em corrida continua esperando a corrida em andamento (uma corrida por vez).
