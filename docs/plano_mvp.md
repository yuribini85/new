# Second Drive — plano operacional do primeiro build

Desdobramento de `docs/conceito.md` em sistemas, dados e ordem de trabalho. Estruturas abaixo
são formato, não balanceamento: **nenhum número aqui é definitivo**. Os valores virão do
estudo do GT2 e de playtest, sempre em JSON externo.

## 1. Escopo do primeiro build

Entra:

- 1 concessionária de novos, 1 de usados
- ~15 carros de 3 fabricantes fictícias (faixa de entrada do GT2: compactos, esportivos leves, um turbo)
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
Tempos de volta e velocidades do GT2 servem de alvo: se o carro-arquétipo X faz Y na pista
de função Z no GT2, o equivalente fictício deve ficar na mesma ordem relativa. A meta é
preservar **ordem e distância relativa** entre carros, não tempos absolutos.

## 4. Arquivos de dados

```
data/fabricantes.json   id, nome, escola (jp/de/it/us/uk/fr), descrição
data/carros.json        id, fabricante, arquétipo_ref, categoria, tração, potência, peso, preço, ano
(usados ficam em carros.json: janelas de dias com preço, da lista do GT2)
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

1. Planilha de referência a partir do GT2: arquétipo, categoria, potência, peso, preço,
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

- **Jurídico.** Usar o GT2 só como referência de estudo. Não empacotar código, modelos,
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
4. **Licença é uma série de contratos de certificação do piloto automático**
   (substitui o teste de tempo com o carro do jogador). A escola empresta carro e peças,
   sem custo; o jogador monta a solução, envia para avaliação (execução automática, mesma
   simulação das corridas) e recebe um diagnóstico ao concluir. Bronze cumpre o contrato e
   libera a licença; prata e ouro acrescentam condições explícitas. Primeiros contratos:
   "O pequeno contra o gigante", "O último crédito", "Dois circuitos, um carro".
5. **Usados giram por número de corridas**, não por tempo real. Cada corrida conta como
   um dia, como no GT2. Imune a manipulação do relógio; a fila offline avança o estoque.
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
10. **Usados:** como no GT2 — janelas de dias com preço por carro, vindas da lista de
    usados do disco (60 períodos de 10 dias). Sem quilometragem. (Substituiu a versão
    com quilometragem sorteada, que não existe no GT2.)
11. **Piloto do jogador:** perfil fixo (`carreira.json`), sem evolução.
12. **Eventos:** restrições do GT2 (potência efetiva, tração, categoria, fabricante, ano,
    licença); jogador larga em último; prêmio por posição a cada disputa; carro-prêmio só
    na primeira vitória.
13. **Duração na fila:** uma corrida dura em tempo real o mesmo que dura simulada. O tempo
    ausente acima de `teto_offline_s` é descartado e a fila continua de onde parou.
14. **Save:** guarda só ids e estado do jogador; os números voltam de `data/` no load,
    então rebalancear não quebra saves.
15. **Visualização:** retrato 720×1280; geometria derivada dos trechos (curvas com
    `sentido`); carro provisório desenhado por código em 16 direções, com tamanho fixo
    em pixels; telas com componentes padrão do Godot até a arte existir.
16. **Dados do GT2:** `data/` vem do disco (SCUS-94488 v1.2) pelo extrator e importador
    em `tools/`. Carros fictícios ligados a modelos do GT2; séries do GT2 renomeadas;
    nenhum nome, marca ou traçado do GT2 no build.
17. **Placeholders em blocos 3D** (pedido do usuário, substitui parte da 15): corrida em
    3D com câmera ortográfica isométrica seguindo o jogador e minimapa da pista inteira;
    carros de blocos (chassi, cabine, rodas) com proporção por categoria; oficina começa
    pela escolha do carro, com vitrine girando como no GT2; ícones de carro e de pista
    nas listas. A posição lateral é só visual (a simulação é em uma dimensão): carros
    próximos abrem para faixas livres e não se atravessam; toque na troca de faixa
    aparece como tranco, sem efeito no resultado. A arte final continua a da seção 5.
18. **Colisão só visual.** O toque entre carros aparece na tela e não muda o resultado:
    no GT2 batida não tem dano, e a simulação já segura quem está atrás fora das zonas de
    ultrapassagem.
19. **Provas abertas como no GT2.** Só licenças travam provas; o começo é guiado por
    objetivos e pelas "recomendadas para começar", sem esconder nada.
20. **Sem campeonato por pontos.** No disco do GT2, o bônus de campeonato
    (`SeriesChampBonus`) só existe nas séries internacionais (GT3, GT5, GTW, FRE), fora do
    jogo; a tabela de pontos não está nas tabelas. Os eventos mostram o progresso da série
    (etapas vencidas), sem prêmio extra inventado.
21. **Preços e prêmios medidos antes de mexer.** `tools/medir_progressao.gd` mede, por
    fase e por perfil de jogador (`tools/agente.gd`), créditos por minuto de corrida e de
    renda, gastos e a tabela de compras; sessões e retornos usam os valores do playtest
    de ritmo. Ajuste, se houver, entra no importador.
22. **Licença A calibrada pelo percurso.** Limites dos testes pela mediana e quartis dos
    limites das provas A; tempos com o carro e o saldo do jogador ao tirar a B (bronze
    tolerante, prata com o carro do percurso, ouro com uma melhoria).
23. **Carro original em código** (substitui os blocos da 17): carroceria contínua por
    seções, com proporção por categoria, para validar o estilo antes da arte final.
    Agora é o gerador dos sprites provisórios (decisão 31).
24. **Leitura rápida e estimativa sob demanda nas competições.** O cartão mostra
    "Potência/peso frente aos rivais: Acima / Próxima / Abaixo" (mediana dos rivais;
    limites provisórios +8% / −5%), que não é dificuldade: pneus, curvas e frenagem
    também contam. "Estimar desempenho" simula a prova com o carro em uso e mostra a
    faixa de posições, só quando o jogador pede.
25. **Torque e câmbio na simulação.** A curva de torque e as marchas vêm do GT2; só a forma
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
    IDs CLUB, SPORT, NATIONAL, INTERNATIONAL, PRO, ELITE ligados às licenças do GT2.
34. **Offline só para repetição** (muda a 2): repetir prova já vencida roda offline; prova
    inédita, campeonato e corrida da história só com o app aberto.
35. **Campeonatos com pontos** (muda a 20 e a 28).
36. **Equipes, pilotos e carros nas corridas:** cada rival é um carro de uma equipe; a
    equipe tem piloto principal e segundo piloto; a cada corrida, 70% de chance de correr
    o principal e 30% o segundo, que pode ser até 20% pior.
37. **Fora:** taxa de inscrição e quilometragem/condição (o GT2 não tem; mantém a 10).
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
    (prêmios iguais: só o tempo encolhe, a economia do GT2 não muda). Cada vídeo soma
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
    potência ±10% e peso ±5%) fica um. Dos 618 do GT2 ficam 386. Rivais, prêmios e
    copas usam o substituto; saves migram para ele. Regra no importador
    (`reduzir_frota`), não à mão.

### Ritmo e lojas (decisões do usuário)

41. **Idle mais longo:** as voltas das provas sobem ×2,5 (as de 2 voltas viram 5; as
    demais na mesma proporção, resistência inclusive) e os preços de compra (carros,
    peças, pneus) dobram em relação aos prêmios. No importador (`FATOR_VOLTAS`,
    `FATOR_PRECO`); prêmios, bônus e saldo inicial não mudam.
42. **Lojas = workshops, sem usados.** As 6 workshops (`data/workshops.json`, logos em
    `arte/ui/workshops/`) seguem as regiões do GT2: 4 do Japão (Hayase e Kanaya
    sozinhas, as outras marcas japonesas em dois grupos), 1 dos EUA e 1 da Europa
    (de 53 a 101 carros): a estrutura do GT2 (uma loja por marca, por região)
    agrupada. Toda a frota é vendida pelo preço de tabela, inclusive os modelos
    que no GT2 só existiam usados. Sem usados nem agenda; a Second Chance Motors fica
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

### Arena (decisões do usuário, 2026-10-10; estudo Destruction Derby)

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
    piloto passa a ser escolhido entre 8 candidatos, dois por traço (Constante, Agressivo,
    Barato, Promessa; `docs/pilotos_candidatos.md`); custo e salário entram com o
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
    Elite), com o que dá emoção nas do Destruction Derby 2 sem copiar nenhuma: muro em
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
    provisórios, a confirmar: espelho da redução de peso do GT2 do próprio carro (nível k
    pesa o inverso do estágio k e custa o mesmo; `data/arena.json` → `blindagem`). Entram
    dez personagens com diálogos e tutoriais: Rico Salas (manobrista, janela Garagem),
    Kenji Arata (pintor, PINTURA), Harold Brandt (examinador da Vector Academy), Roxy Vega
    (organizadora da arena), Dex Kane (mecânico da arena, blindagem) e os vendedores
    Edgar Halloway (Charge Folio), Sal Moretti (Relay Room), Bianca Sterling (Brace Yard),
    Nora Lindqvist (Return Chapter) e Jade Ryker (Shared Grid). Spare Penny fica sem
    vendedor até haver arte.
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
