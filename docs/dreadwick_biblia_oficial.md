DREADWICK • Bíblia Oficial de Desenvolvimento • 2026-09-03

DREADWICK

BÍBLIA OFICIAL DE DESENVOLVIMENTO

Lore • Gameplay • Economia • UI/UX • Direção Visual • Arquitetura de Implementação

Escócia, 1925 | Mobile vertical | Idle horror lovecraftiano

Versão executiva assertiva para produção e programação - 03/09/2026

AUTORIDADE DO PROJETO: regras canônicas são obrigatórias. Somente valores marcados como "provisórios" permanecem abertos a balanceamento.

—————————————————————————————

REGRA GERAL DE LOCALIZAÇÃO DE ARQUIVOS

—————————————————————————————

Todos os arquivos de assets do projeto Dreadwick — imagens, documentos, planilhas e pastas de produção — estão centralizados na pasta raiz do Drive: https://drive.google.com/drive/folders/170FhCkDBiFNrklu1HaDEmskp-zTIiBc9

Qualquer caminho de arquivo mencionado nesta Bíblia ou no Manual de Estrutura de Assets é relativo a essa raiz. Novos arquivos devem ser adicionados dentro dessa estrutura, nunca soltos fora dela.

# Como usar este documento

Esta Bíblia é a referência oficial do projeto Dreadwick para narrativa, game design, arte, UI e implementação. Decisões marcadas como cânone devem ser preservadas. Valores numéricos marcados como provisórios existem para permitir prototipagem e devem permanecer configuráveis em dados, nunca hardcoded.

Cânone fechado: premissa, personagens, organizações, funções das edificações, loops principais, regras de apresentação e arquitetura geral dos sistemas.

Cânone com balanceamento aberto: custos, tempos, taxas, capacidades, penalidades e recompensas numéricas.

Regra de produção: implementar o núcleo do Ato 1 primeiro e só depois introduzir ACE, Insanidade e sistemas do Ato 2.

# Índice de referência

1. Visão do jogo e pilares

2. Lore central e contenção

3. Organizações

4. Personagens

5. Estrutura narrativa por atos

6. Loop principal de Quint

7. Tempo, tarefas e offline

8. Economia e recursos

9. Pesca

10. Farol e Lux

11. Insanidade e ACE

12. Confiança, pedidos e NPCs

13. Edificações e upgrades

14. Interfaces e HUD

15. Cutscenes e diálogos

16. Direção visual e arte

17. Regras de implementação

18. Valores provisórios de protótipo

19. Vertical slice recomendado

20. Pendências de balanceamento

# 1. Visão do jogo e pilares

Dreadwick é um idle horror mobile em formato vertical, ambientado em 1925 numa ilha-farol remota da costa escocesa. O jogador acompanha Quint Hollowell, veterano da Primeira Guerra Mundial e mecânico especializado, contratado para manter e modernizar uma instalação aparentemente convencional que esconde uma função de contenção muito mais antiga.

| Pilar | Regra |

|---|---|

| Competência humana | Quint não possui poderes especiais. Resolve problemas por engenharia, diagnóstico, manutenção e procedimento. |

| Idle com presença física | Ações são representadas no mundo: Quint caminha, entra em edifícios, pega galões, embarca, retorna e conclui animações. |

| Automação como recompensa | O jogador aprende manualmente uma rotina e depois desbloqueia automação para reduzir fricção sem eliminar planejamento. |

| Horror progressivo | O Ato 1 é majoritariamente cotidiano. O sobrenatural surge ambíguo e ganha materialidade ao longo dos atos. |

| Ilha como protagonista visual | A ilha isométrica vertical permanece o palco principal. HUDs e menus não devem sufocar o cenário. |

| Números mecânicos | Valores acumuláveis aparecem como odômetros/roletes; estados contínuos usam instrumentos analógicos, agulhas e registradores. |

## 1.1. Tom

Escócia costeira de 1925: austera, úmida, ventosa, funcional e isolada.

Humor seco e raro; a latrina e pequenos flertes cômicos funcionam como alívio, nunca como paródia constante.

Horror lovecraftiano sem "caça a monstros", culto obrigatório ou superpoderes.

Cthulhu não deve ser mostrado cedo nem explicado como uma criatura de regras simples.

# 2. Lore central e contenção

Cthulhu já influencia Dreadwick e o Atlântico Norte antes da chegada de Quint. O farol não mantém a entidade completamente inerte: ele desacelera o despertar. Isso explica anomalias prévias em geografia, fauna, rádio, sonhos e percepção.

## 2.1. Como o farol contém

Mais lux é sempre melhor para a contenção. Não existe punição por "lux demais".

A luz não machuca Cthulhu. Ela energiza/projeta um padrão formado por óptica, inscrições, rotação, tempo, orientação, geografia e condições astronômicas.

A lente Fresnel histórica possui microinscrições discretas e irregularidades preservadas por The Vigil.

A rotação transforma o padrão em uma sequência temporal; pausas e variações herdadas têm função real.

Formações costeiras naturais funcionam como pontos de referência/estabilização. Algumas desaparecem ou mudam conforme o ACE avança.

## 2.2. A ruptura

A Fresnel original está trincada e perto do fim da vida útil. Quint, agindo corretamente como engenheiro de um farol convencional, produz/instala uma lente moderna tecnicamente superior. Durante a remoção, a lente antiga perde segmentos e não pode ser simplesmente reinstalada. A nova lente aumenta muito o lux, mas elimina a configuração ritual histórica.

## 2.3. Solução final

No Ato 3, Quint percebe que as inscrições e a rotação não são um "feitiço fixo", mas um sistema configurável. Com Stewart, Thomas, Eddie e Duncan, ele cria um mecanismo adaptativo de alta potência que recalibra a contenção para a geografia atual. A solução é engenharia + tradição + dados, nunca combate físico.

# 3. Organizações

## 3.1. The Vigil

Tradição antiga de custódia costeira, formalizada entre o fim do século XVII e o início do XVIII. Não é culto, ordem militar ou sociedade de heróis. Preserva procedimentos observados empiricamente: luz, símbolos, tempos, ciclos, registros e proibições.

Cultura: preservar, repetir, não alterar além do necessário.

Conhecimento fragmentado: parte escrita, parte oral, parte deliberadamente compartimentalizada.

Em 1925 está decadente e dependente de poucos custodiantes, como Stewart.

Utiliza fachada civil/administrativa para contratar Quint e Thomas e pagar salários/bônus.

## 3.2. N.A.S.H.

North Atlantic Survey & Hydrographic Company Ltd. Empresa moderna, rica, científica e aparentemente legítima. Monitora o ACE por discrepâncias hidrográficas, cartográficas, biológicas e eletromagnéticas. Não é onisciente e não controla Cthulhu.

ACE = Anomalous Coastal Event.

Eddie coleta dados aéreos/cartográficos.

Duncan coleta dados biológicos/marítimos.

A N.A.S.H. investe em hidroavião, embarcação de pesquisa, fotografia, combustível, amostras e instrumentação.

# 4. Personagens

## 4.1. Quint Hollowell

Protagonista. Veterano da Primeira Guerra Mundial, mecânico/engenheiro de tanques e amputado de uma perna. Reservado, pragmático, teimoso, observador, emocionalmente contido e de humor seco. Nunca fala como caçador de monstros: sua linguagem é de falha, ferramenta, risco, causa e procedimento.

Chega a Dreadwick por salário alto e estabilidade, não por destino ou trauma.

Durante a guerra ajudou a preparar/manter um tanque que posteriormente atingiu uma mina; a tripulação morreu. Em incidente posterior, Quint perdeu uma perna.

A culpa só ganha novo significado quando vidas voltam a depender de uma máquina sob sua responsabilidade.

Arco: dinheiro → curiosidade/responsabilidade profissional → preocupação com Thomas → risco regional → dever moral.

## 4.2. Stewart

Custodiante humano de The Vigil, cerca de 25–30 anos em Dreadwick. Magro, austero, cerebral, conservador, muito rabugento e metódico. Sabe operar o sistema antigo, mas não reconstruí-lo. Sua oposição a Quint deve parecer irracional antes de revelar sua função.

Rotina ambiental autônoma: cachimbo, píer, farol, depósito e aposentos.

Sem medidor, controle direto ou upgrades.

Casa fechada no Ato 1; no Ato 2 vira biblioteca/arquivo de The Vigil.

CONFIANÇA limitada por atos; não pode ser "farmada" até o máximo cedo.

## 4.3. Thomas

Operador de rádio e observador meteorológico. Chega junto de Quint no mesmo transporte. Foi contratado por uma fachada civil ligada à Vigil, mas não sabe que The Vigil existe no início. É racional, curioso, falante, organizado e orientado a evidências.

Mora na própria estação, que possui pequeno alojamento e fonte de calor/chaminé.

Ato 1: diálogos específicos e pequenas solicitações técnicas aumentam CONFIANÇA.

Ato 2: zumbido → padrões com rádio desligado → insônia/tremor → previsão de transmissões → retraimento progressivo.

Rotina visual se degrada: menos sono, mais tempo na antena/rádio, comportamentos estranhos.

O sismógrafo/registrador nasce de suas tentativas de medir o ACE objetivamente; em fase avançada o aparelho passa a sustentar o monitoramento de Insanidade.

Detalhe cômico/perturbador: em estágio avançado seu sprite de cocô na latrina fica verde.

## 4.4. Betsy

Barqueira e mercadora. Principal ligação regular com o continente e principal fornecedora de Kit Sobrevivência, querosene, peças comuns, ferramentas e encomendas. Compra peixes normais. Representa normalidade, logística e uma rota real de fuga.

Nova direção visual substitui completamente a versão antiga: mulher negra, robusta, aparência vivida, macacão de trabalho, botas de cano alto, roupa marítima funcional e postura firme.

Existe interesse romântico leve e mútuo entre Betsy e Quint. Alguns diálogos devem incluir flertes cômicos, secos e discretos, sem transformar o relacionamento em romance melodramático.

Quando o Ato 2 torna a rota perigosa, Betsy aumenta muito o preço do Kit Sobrevivência como prêmio de risco e demonstra crescente relutância em continuar indo à ilha.

## 4.5. Duncan

Pesquisador/mercador da N.A.S.H., homem negro mais velho, cabelo grisalho volumoso e bigode marcante. Compra exclusivamente peixes mutantes e espécimes anômalos, vende itens especializados e registra espécie, local, profundidade, data e morfologia.

Fascinação: fauna parece adaptar-se antecipadamente a um ambiente que ainda não existe completamente.

Padrões incluem olhos extras, alterações respiratórias e órgãos sensoriais adicionais.

## 4.6. Eddie Mercer

Britânico de 40–45 anos, ex-reconhecimento aéreo da guerra, muito gordo, metódico, racional e profissional. Opera hidroavião biplano de dois flutuadores inspirado no Fairey IIID. Investiga rochas, recifes e ilhotes que desapareceram ou mudaram de posição.

Ato 1: aparece ocasionalmente cruzando o céu sem apresentação formal.

Ato 2: amerissa e revela os levantamentos da N.A.S.H.

Ato 3: mapas e fotos permitem recalcular a geometria da contenção.

## 4.7. Skye

Cão de Quint. Companheira emocional e sensor comportamental ambíguo. Não possui medidor nem controle direto. CONFIANÇA começa em 100%.

Quando Quint dorme, Skye vai para casa e só sai com ele.

Quando Quint pesca, Skye vai à boathouse e embarca junto.

Fora disso anda, dorme, observa e circula autonomamente pela ilha.

No Ato 2 pode evitar áreas, observar o mar ou acompanhar Quint com mais insistência; nunca é detector sobrenatural infalível.

## 4.8. Regra visual universal de personagens

Não gerar personagens com as mãos nos bolsos.

Poses devem ser espontâneas, naturais, variadas e contextualizadas.

Evitar pose frontal rígida como padrão. As mãos devem ficar visíveis, ocupadas ou coerentes com a ação.

A pose deve reforçar função e personalidade. Gerar variações entre imagens do mesmo personagem.

# 5. Estrutura narrativa por atos

| Ato | Objetivo de gameplay | Mudança narrativa | Clímax |

|---|---|---|---|

| Ato 1 — Trabalho, rotina e domínio | Necessidades, pesca, economia, manutenção, upgrades e automação básica. Sem Insanidade como sistema ativo. | Stewart parece apenas conservador; Thomas registra interferências plausíveis; Eddie é só presença aérea. | Nova Fresnel aumenta brutalmente o lux e rompe a configuração histórica. |

| Ato 2 — Padrão e consequência | Insanidade, mutantes, Duncan, Eddie, Thomas deteriorando, fragmentos, biblioteca de Stewart e investigação. | O jogador descobre que luz, lente, rotação, inscrições e geografia formavam uma única máquina de contenção. | Restaurar a configuração antiga é impossível porque a geografia mudou. |

| Ato 3 — Reconstrução e dever | Automação madura + protótipos de alta potência + testes de configuração + feedback de todos os personagens. | Quint sintetiza tradição e ciência e decide permanecer por responsabilidade. | Ativação do sistema adaptativo final e sono profundo de Cthulhu. |

# 6. Loop principal de Quint

## 6.1. Necessidades básicas

Quint possui Energia, Fome e Latrina, todas representadas em um instrumento analógico triplo de 0% a 100%. Em todas, 0% = resolvido e 100% = emergência. A agulha vai do verde ao vermelho.

Energia cresce com trabalho; pesca e manutenção pesada aceleram desgaste.

Fome cresce com o tempo e rotina.

Latrina cresce até 100%.

Em 100%, Quint termina a animação atual de encerramento e abandona temporariamente a tarefa.

Desempate: Latrina . Energia . Fome.

## 6.2. Casa de Quint

Para Energia ou Fome, Quint caminha até a porta, entra com fade de alpha e permanece invisível enquanto recupera.

Fome e Energia nunca recuperam simultaneamente.

Inicialmente recuperação máxima .80%; upgrades levam a 100% e aceleram regeneração.

Fome consome Kit Sobrevivência.

## 6.3. Latrina

Compartilhada por Quint, Stewart e Thomas; um personagem por vez.

Se ocupada, o próximo espera do lado de fora, inclusive Quint em emergência.

Uso: entrada por alpha, tempo interno, saída; pequeno sprite de cocô cai pelo penhasco.

## 6.4. Desmaio por Insanidade

Em 100% de Insanidade, Quint desmaia onde estiver.

Stewart interrompe a rotina, encontra Quint e o carrega para casa.

A recuperação forçada é mais lenta que um sono voluntário equivalente e não zera completamente a Insanidade.

# 7. Tempo, tarefas e offline

## 7.1. Ciclo de tempo

Um dia de Dreadwick dura 8 minutos reais no protótipo inicial.

| Fase | Duração sugerida | Uso |

|---|---|---|

| Dia pleno | 3 min | Visitas, trabalho externo, pesca diurna. |

| Entardecer | 1 min | Farol deve ligar; transição visual. |

| Noite plena | 3 min | Farol ativo; pesca exige luz no barco; maior pressão narrativa. |

| Amanhecer | 1 min | Farol desliga ao final; retorno gradual ao dia. |

A duração de 8 minutos é cânone de protótipo e pode ser revista após playtest.

## 7.2. Agenda de visitantes

| Dia | Visitante regular |

|---|---|

| Segunda | Betsy |

| Terça | Duncan |

| Quarta | Betsy |

| Quinta | Duncan |

| Sexta | Eddie |

| Sábado | Betsy |

| Domingo | Sem visitante comercial regular |

A chegada deve ocorrer numa janela do período diurno, não no mesmo segundo exato, para evitar comportamento robótico.

## 7.3. Fila de tarefas

HUD: 1 tarefa atual + 3 futuras.

Prioridade: colapso/necessidade crítica . emergência crítica do farol . comando manual . retomada de tarefa pausada . automação . idle.

Interrupção sistêmica pausa e preserva progresso. Cancelamento manual pode destruir a tarefa e não devolver materiais consumidos, com aviso explícito.

Automação coloca tarefas na fila; não teletransporta Quint nem ignora deslocamentos.

## 7.4. Offline

O offline usa simulação econômica resumida, não simulação literal de cada caminhada, refeição ou uso da latrina. O jogo aberto deve render sempre mais que o jogo fechado.

Capacidade offline inicial: 2h.

Upgrades iniciais: 2h → 3h → 4h → 5h; 6h/8h e acima devem exigir investimento relevante. Teto tardio pode chegar a 24h.

Eficiência offline é um eixo separado do tempo máximo e permanece abaixo de 100%.

Offline respeita combustível, Kits, estoque, capacidade, upgrades e automações desbloqueadas.

Não dispara cutscene obrigatória nem cria softlock.

No retorno, exibir relatório/diário: dinheiro, peixe, Kits, querosene, lux, visitas automáticas e perdas por falta de recurso/estoque cheio.

Tempo offline e eficiência offline aparecem e são melhorados na Tela de Quint, não em uma edificação.

# 8. Economia e recursos

## 8.1. Moeda

Sistema britânico pré-decimal: libras, xelins e pence (£/s/d). Valores acumuláveis são exibidos por odômetros mecânicos. Itens comuns custam pence/poucos xelins; upgrades relevantes avançam para xelins e poucas libras, evitando inflação absurda de idle.

## 8.2. Renda

Salário semanal: renda-base estável, acima da média devido ao isolamento e especialização.

Pesca comum: principal motor de crescimento no Ato 1, vendida a Betsy.

Peixes mutantes: renda especializada no Ato 2, vendidos a Duncan.

Bônus e pedidos: complementam renda e CONFIANÇA.

## 8.3. Kit Sobrevivência

Recurso alimentar agregado comprado de Betsy. Representa água, frutas, pão, massas, conservas e outros suprimentos essenciais. A interface não controla cada alimento individualmente.

Comer em casa consome Kit Sobrevivência para reduzir Fome.

Se Fome = 100% e estoque = 0, Stewart fornece quantidade mínima e cobra 3x o preço corrente de Betsy. Se necessário, vira dívida para impedir softlock.

No Ato 2, Betsy aumenta fortemente o preço por risco de viagem; o Kit vira dreno econômico importante.

## 8.4. Estoques

| Recurso | Unidade | Observação |

|---|---|---|

| Querosene | Litros | Capacidade própria; usado pelo farol. |

| Kit Sobrevivência | Unidades | Capacidade própria; consumido ao comer. |

| Peixes | Quilos | Capacidade compartilhada entre comuns e mutantes, salvo futuro compartimento especial. |

| Materiais | Abstração/slots | Evitar inventário de dezenas de parafusos e rebites. |

| Peças-chave | Itens únicos | Não precisam ocupar capacidade comum; usadas para upgrades específicos. |

# 9. Pesca

## 9.1. Fluxo visual

Jogador manda Quint pescar.

Quint caminha até a boathouse, entra por alpha; Skye acompanha e entra.

Barco de Quint surge no slipway e sai.

A câmera desliza para baixo, centralizando o mar e levando o píer para a parte alta da tela.

Barco navega pela zona de pesca, movimenta-se, para e repete ciclos. Cada captura mostra brevemente o sprite exato do peixe acima do barco.

Pesca continua automaticamente até carga máxima, autonomia segura, interrupção manual ou necessidade crítica.

Barco retorna animado à boathouse, desaparece; Quint e Skye reaparecem e a câmera volta ao enquadramento padrão da ilha.

## 9.2. Progressão

Capacidade do barco em kg.

Autonomia.

Velocidade/deslocamento.

Eficiência/taxa de captura.

Equipamentos de pesca portáteis: melhorados/fabricados na oficina.

Upgrades físicos do barco: feitos na boathouse.

Luz de pesca: libera pesca noturna.

Zonas futuras: costeira, intermediária e profunda/anômala, desbloqueadas por autonomia/equipamento.

## 9.3. Catálogo canônico

O catálogo marítimo definitivo de Dreadwick possui 20 espécies. Cada espécie tem um par comum + mutante com o mesmo identificador numérico de 01 a 20. A espécie é sorteada primeiro; a mutação é decidida em uma rolagem separada a partir do Ato 2.

Espécies removidas do catálogo: Truta-marrom, Lúcio, Perca, Grayling, Truta-arco-íris, Vendace, Powan e o Robalo duplicado. Esses peixes não devem aparecer na coleção, nas tabelas de pesca ou no runtime.

O Peixe-pipa permanece como espécie oficial. Os assets comum e mutante foram corrigidos e não possuem mais pendência anatômica ou visual.

## 9.4. Pesos, valores e raridade

Os limites abaixo são faixas de gameplay, não recordes biológicos. Os valores numéricos formam a base aprovada para protótipo e devem permanecer data-driven para ajuste por playtest. A chance das 20 espécies totaliza exatamente 100% dentro de uma captura válida.

| Nº | Espécie | Categoria | Chance | Peso (kg) | Valor/kg normal / mutante |

|---|---|---|---|---|---|

| 01 | Sardinha | Comum | 14% | 0,06-0,20 | 12d / 48d |

| 02 | Cavala | Comum | 12% | 0,25-1,40 | 8d / 32d |

| 03 | Carapau | Comum | 10% | 0,15-1,10 | 7d / 28d |

| 04 | Faneca | Comum | 9% | 0,25-1,80 | 9d / 36d |

| 05 | Linguado | Comum | 7,5% | 0,30-2,50 | 11d / 44d |

| 06 | Peixe-agulha | Comum | 6% | 0,25-1,30 | 9d / 36d |

| 07 | Escamudo | Comum | 6% | 0,60-6,00 | 10d / 40d |

| 08 | Bodião | Incomum | 5% | 0,30-2,50 | 8d / 32d |

| 09 | Abrótea | Incomum | 4,5% | 0,80-6,00 | 12d / 48d |

| 10 | Pescada | Incomum | 4% | 0,80-10,00 | 14d / 56d |

| 11 | Truta-marinha | Incomum | 3,5% | 0,70-7,00 | 18d / 72d |

| 12 | Robalo-legítimo | Incomum | 3,5% | 0,50-7,50 | 16d / 64d |

| 13 | Peixe-pipa | Raro | 2,5% | 0,02-0,12 | 18d / 72d |

| 14 | Badejo | Incomum | 3% | 1,50-15,00 | 12d / 48d |

| 15 | Salmão-do-Atlântico | Raro | 2,8% | 2,00-14,00 | 24d / 96d |

| 16 | Tubarão-cação | Raro | 2,3% | 2,00-8,00 | 10d / 40d |

| 17 | Arraia-linguado | Raro | 2% | 2,00-14,00 | 14d / 56d |

| 18 | Arraia-elétrica | Raro | 1% | 1,50-16,00 | 20d / 80d |

| 19 | Cação | Raro | 1,2% | 5,00-30,00 | 16d / 64d |

| 20 | Esturjão | Ultrararo | 0,2% | 25,00-120,00 | 30d / 120d |

| TOTAL | | 100% | | | |

## 9.5. Categorias e cálculo econômico

Comum: chance igual ou superior a 6%; Incomum: 3% a 5,9%; Raro: 1% a 2,9%; Ultrararo: abaixo de 1%.

Usar pence como unidade monetária interna: 1 libra = 20 xelins = 240d; 1 xelim = 12d.

Valor de venda = peso capturado x valor por kg, arredondado para o penny mais próximo.

Betsy compra exclusivamente peixes normais. Venda normal mínima: 1d.

Duncan compra exclusivamente peixes mutantes. O valor por kg é 4x o normal e a venda mínima é 12d (1 xelim).

A mutação é calculada depois da espécie: 6% no início do Ato 2, 14% no meio do Ato 2 e 25% no fim do Ato 2/Ato 3.

Chance real de uma espécie mutante = chance da espécie x taxa de mutação vigente.

# 10. Farol e Lux

## 10.1. Atividades recorrentes

Limpeza dos vidros: sujeira reduz percentual de luz e enfraquece visualmente o feixe, tornando-o mais transparente.

Manutenção do mecanismo: desgaste causa travadas visíveis na rotação; em 0% o feixe pode permanecer aceso, mas não gira.

Abastecimento: Quint vai ao depósito, pega galão, leva fisicamente ao farol, entra, descarrega e sai sem o galão.

Ligamento/desligamento: manual no começo. Se o jogador esquece, Stewart corrige tarde; à noite isso reduz muito o rendimento.

Automação de ligar/desligar é desbloqueada cedo porque a repetição seria irritante num idle.

## 10.2. Querosene e potência

Mais potência gera mais lux e consome mais querosene. Lux nunca é "ruim"; o trade-off é econômico. Eficiência de combustível é um ramo separado de potência.

## 10.3. Luxímetro

Instrumento analógico próprio, separado das necessidades.

Agulha vibra intensamente, lembrando uma asa de beija-flor; não deve parecer acelerador automotivo.

Odômetros inferiores mostram Lux Gerado e Lux Armazenado.

## 10.4. Lux contra Insanidade

Lux armazenado pode ser consumido em um Pulso de Contenção/estabilização. A justificativa: a luz corretamente configurada reduz a interferência externa do ACE sobre percepção e orientação; não "cura a mente" de Quint.

Dormir = recuperação biológica lenta e gratuita em lux.

Pulso = redução rápida de Insanidade, consumindo reserva de lux.

Pulso não deve substituir completamente o sono; pode haver piso de redução ou custo crescente em níveis altos.

# 11. Insanidade e ACE

Insanidade entra no Ato 2 e funciona como uma quarta necessidade, mas com apresentação independente. Aumenta de forma constante sob pressão do ACE e também por eventos, rádio, fauna impossível, áreas alteradas e exposição anômala. Dormir reduz Insanidade.

## 11.1. Penalidade

A Insanidade reduz gradualmente a eficiência de Quint em praticamente todas as atividades: fabricação, manutenção, deslocamento, pesca e execução de tarefas. Evitar degraus bruscos; a perda deve ser contínua e perceptível.

## 11.2. Resistência ao ACE

A resistência não reduz Insanidade já acumulada; reduz a velocidade de ganho. Cresce com melhorias que tornam Dreadwick mais previsível, segura e funcional. A justificativa deve ser material e narrativa, não mágica.

Casa melhor: sono mais restaurador e rotina mais estável.

Farol melhor: contenção mais forte reduz pressão externa.

Oficina melhor: tarefas mais rápidas reduzem exposição.

Conhecimento/instrumentação: Quint reconhece padrões e reduz desorientação.

## 11.3. Sismógrafo/registrador

Thomas desenvolve/adapta um registrador mecânico para correlacionar microtremores, vibrações e rádio. O aparelho começa técnico e ganha significado quando registra fenômenos sem tremor físico. Em estágio avançado de Thomas, o instrumento passa a sustentar o monitoramento independente de Insanidade/pressão do ACE no HUD.

# 12. CONFIANÇA, pedidos e NPCs

## 12.1. Régua universal

| Faixa | Estado |

|---|---|

| 0–24% | Desconhecido |

| 25–49% | Conhecido |

| 50–74% | Confiável |

| 75–99% | Alta Confiança |

| 100% | Confiança Máxima |

Todos os NPCs aparecem na área de relacionamento. Skye começa em 100%. Stewart possui tetos narrativos por ato. Thomas evolui principalmente por diálogos e solicitações técnicas no Ato 1 e depois deteriora.

## 12.2. Como ganha confiança

Pedidos concluídos: ganho relevante.

Diálogos específicos/contextuais: ganho pequeno ou médio.

Eventos pessoais/ajuda significativa: ganho relevante.

Comércio rotineiro repetido: não deve permitir farm. No máximo a primeira interação relevante da visita concede ganho pequeno.

## 12.3. Pedidos

No máximo 1 pedido ativo por NPC.

Aparece em pequeno quadro na interação do personagem.

Pode pedir espécie, kg, item, componente ou ação específica.

Recompensas variam: dinheiro, CONFIANÇA, item, informação, acesso ou diálogo.

Pedidos especiais permanecem manuais mesmo após automação comercial; automação não deve esvaziar o relacionamento.

## 12.4. Automação por confiança

Em 75% (Alta Confiança), NPCs comerciais podem liberar compra/venda configurada automaticamente. 100% deve ter benefício específico/pessoal, não apenas mais desconto.

## 12.5. Visitantes e veículos

Veículo chega animado, aproxima-se e taxia/manobra até posição próxima do píer.

Personagem aparece no píer; veículo permanece visível.

Jogador pode clicar no píer/personagem ou no veículo.

Quint termina a animação da tarefa atual, caminha até o píer e só então abre a interação.

Após a interação, personagem embarca, veículo parte animado e Quint retoma a tarefa se ainda for válida.

# 13. Edificações e upgrades

| Edificação | Função principal | Hotspots / ramos |

|---|---|---|

| Casa de Quint | Fome, Energia, conforto e estoque doméstico | Cama; Cozinha; Despensa; Aquecimento/Conforto. |

| Farol | Lux, Fresnel, combustível, rotação e contenção | Óptica/Fresnel; Mecanismo; Tanque; Automação. |

| Oficina | Centro tecnológico e fabricação | Bancada; Torno; Precisão; Área óptica; Engenharia avançada. |

| Boathouse | Barco, pesca, transição marítima e upgrades físicos | Barco; Equipamentos; Armazenamento; Enciclopédia. |

| Depósito | Leitura de estoque e capacidade | Kits; Querosene; Peixes; Materiais; acesso a upgrades. |

| Estação de Thomas | Rádio, meteorologia, moradia e registradores | Rádio; Antena; Meteorologia; Registrador/Sismógrafo. |

| Casa de Stewart | Biblioteca/arquivo da Vigil | Estantes; Mapas; Caixas; Documentos restritos; sem árvore tradicional. |

| Latrina | Necessidade fisiológica compartilhada | Poucos upgrades: velocidade, proteção climática, conforto simples. |

## 13.1. Oficina como gargalo tecnológico

A oficina é melhorada primeiro para liberar upgrades avançados em outras estruturas. Exemplos: mecanismo de giro do farol, nova Fresnel, equipamentos de pesca e componentes do sistema final. Evitar torná-la um gargalo universal absoluto; alguns ramos podem evoluir em paralelo.

## 13.2. Itens e fornecedores por categoria

| Fornecedor | Especialidade |

|---|---|

| Betsy | Infraestrutura comum, sobrevivência, querosene, ferragens, ferramentas, itens domésticos, encomendas do continente. |

| Duncan | Pesca especializada, recipientes/amostras e itens científicos/marítimos incomuns. |

| Eddie | Óptica, instrumentação e componentes de precisão ligados à N.A.S.H. |

| Thomas | Não vende; desbloqueia projetos/conhecimento técnico. |

| Stewart | Não vende; fornece registros, fragmentos, inscrições e conhecimento da Vigil. |

## 13.3. Regra de materiais

Evitar administração granular de dezenas de rebites, tábuas e parafusos. Preferir peça-chave + materiais básicos abstratos + custo + tempo. O protagonismo mecânico de Quint vem da fabricação/instalação e não de micromanagement de inventário industrial.

## 13.4. Upgrades provisórios por construção

Casa: Cama I–III; Cozinha I–III; Despensa I–III; Aquecimento/Conforto I–II.

Farol: Queimador/Potência I–III; Tanque I–III; Óptica I–II; Rotação I–III; Automação I–III; Fresnel; sistema adaptativo do Ato 3.

Oficina: Bancada → Torno → Instrumentação de precisão → Área óptica → Engenharia avançada → bancada experimental.

Boathouse: carga, autonomia, velocidade, pesca noturna, equipamento de pesca, armazenamento.

Thomas: rádio, antena, meteorologia, registro automático, sismógrafo, instrumentação avançada.

# 14. Interfaces e HUD

## 14.1. HUD principal da ilha

Mobile vertical. A ilha deve permanecer protagonista. O HUD contorna a cena e evita virar dashboard administrativo.

| Elemento | Regra |

|---|---|

| Necessidades | Instrumento analógico triplo: Energia em cima, Fome e Latrina embaixo. 0 verde → 100 vermelho. |

| Lux | Instrumento próprio com agulha vibrante + odômetros de Lux Gerado/Armazenado. |

| Insanidade | Registrador/sismógrafo independente, introduzido no Ato 2. |

| Dinheiro | Odômetros £ / s. / d. |

| Recursos | Odômetros para litros de querosene, unidades de Kit, kg de peixe e outros acumuláveis. |

| Fila | 4 slots: tarefa atual maior + 3 próximas. |

| Quint | Retrato/emoção; mudanças emocionais e falas ampliam temporariamente o painel. |

| Confiança | Acesso compacto; barras completas ficam na Tela de Quint/Relacionamentos. |

| Ciclo | Relógio/fase dia–entardecer–noite–amanhecer; sem calendário permanente na tela. |

## 14.2. Retrato e emoções de Quint

Estados principais de gameplay: Neutro, Satisfeito, Cansado, Tenso e Abalado. Estados adicionais de diálogo: Irritado, Desconfiado, Curioso, Determinado, Assustado, Exausto e Aliviado.

Troca normal de emoção: painel cresce 50% por .2 segundos e retorna.

Em diálogo de Quint: painel cresce 70%, usa o retrato emocional pertinente à fala e volta ao estado sistêmico após a fala.

Emoção é apresentação/estado dominante; penalidades matemáticas continuam vindo de necessidades, Insanidade e outros sistemas reais.

## 14.3. HUD universal de edificações

Todas as telas internas de edificações DEVEM usar ambiente imersivo, câmera dentro do espaço e nenhum HUD global superior. Hotspots físicos selecionam módulos. O painel inferior contextual é o único padrão de HUD de edificação e DEVE ser universal e modular.

Cabeçalho: nome do componente/objeto.

Estado atual → próxima melhoria/ação.

Efeito: valores concretos antes → depois sempre que possível.

Requisitos: peça, fornecedor, dinheiro, tecnologia, CONFIANÇA, ato ou condição narrativa; mostrar apenas o que for relevante.

Ação: Instalar, Fabricar, Reparar, Limpar, Abastecer, Abrir, Ler, Consultar etc.

Estado em execução: "Quint trabalhando", barra e tempo restante.

Sem miniatura redundante do objeto ou retrato de Quint no painel.

## 14.4. Interiores

Interiores NÃO DEVEM ser cortes técnicos. DEVEM parecer fotografias/observações feitas por alguém dentro do ambiente, com câmera humana fixa e textura sutil de fotografia de 1925: paleta dessaturada, granulação leve, vinheta mínima e sem sépia pesado. Dreadwick NÃO possui eletricidade doméstica. Toda iluminação interna deve vir de janela, lampião/lamparina ou fogão/salamandra.

## 14.5. Depósito

Tela funcional sem cenário interno obrigatório. Objetivo é leitura de estoque. Topo: Kits atual/capacidade, querosene litros/capacidade, peixe kg/capacidade, materiais. Meio: lista de itens armazenados e filtros. Rodapé: peso/capacidade, espaço restante, acesso a Upgrades e Enciclopédia. Remover bússolas/decorações sem função.

## 14.6. Enciclopédia de peixes

Cada espécie possui um card com peixe comum e variação mutante correspondente.

Não descoberto = silhueta preta do próprio PNG.

Completa = comum + mutante descobertos; Parcial = apenas um; Não descoberta = nenhum.

Filtros: Todos / Comuns / Mutantes; "Raros" só se raridade virar sistema formal.

Coleção não mostra capacidade de estoque.

## 14.7. Tela de Quint

Centro humano e sistêmico do personagem. Não é ficha de RPG: sem nível, XP, build de equipamentos ou skills arbitrárias.

Retrato, emoção atual e motivo.

Resumo: Energia, Fome, Latrina, Insanidade, Resistência ao ACE e Eficiência atual.

CONFIANÇA com todos os NPCs, com acesso aos detalhes.

Biografia progressiva e marcos narrativos, sem datas literais obrigatórias.

Tempo offline atual, eficiência offline e upgrades desses dois eixos.

## 14.8. Tela detalhada de CONFIANÇA

Coluna com todos os NPCs, porcentagem e estágio.

Área principal: retrato, relação atual, Solicitação Atual, progresso e recompensa.

Próximo Marco: mostrar um único marco por vez.

Automação: em 75% para NPCs aplicáveis; compra/venda configurada, não pedidos especiais.

Histórico registra apenas interações significativas; não ganhos por compras rotineiras.

Stewart pode exibir teto/condição narrativa. Thomas pode trocar "Pedido Atual" por "Estado Atual" quando já não responde normalmente.

## 14.9. Tipografia aprovada

O sistema tipográfico oficial deve priorizar legibilidade em celular, coerência com 1925 e distinção clara entre informação mecânica, diálogo e documento histórico. As famílias abaixo são gratuitas e licenciadas sob SIL Open Font License 1.1.

HUD, indicadores e rótulos: Oswald Medium 500.

Botões, títulos curtos e ênfases do HUD: Oswald SemiBold 600.

Números e recursos do HUD: Oswald SemiBold 600 quando houver texto tipográfico; contadores acumulados continuam representados por odômetros mecânicos, nunca por aparência digital.

Nomes de personagens nas caixas de diálogo: Crimson Pro SemiBold 600.

Texto de diálogo: Crimson Pro Regular 400.

Narração e descrição ambiental: Crimson Pro Italic 400.

Documentos antigos, inscrições e materiais históricos especiais: IM Fell English Regular. Seu uso é pontual; não deve substituir a fonte principal de diálogo nem do HUD.

Fontes góticas, monstruosas, manuscritas ou explicitamente lovecraftianas são proibidas na leitura contínua. O horror deve vir da arte e da situação, não da perda de legibilidade.

Os arquivos de fonte e suas licenças devem acompanhar o projeto e ser incorporados ao runtime; não depender de fontes instaladas no sistema do jogador.

# 15. Cutscenes e diálogos

## 15.1. Cutscenes

Cutscenes DEVEM ser reservadas a mudanças irreversíveis de estado. São sequências curtas de imagens fortes e silenciosas, em linguagem dramática semelhante a Darkest Dungeon. É PROIBIDO inserir fala, caixa de diálogo ou texto explicativo dentro da cutscene.

| Momento recomendado | Função |

|---|---|

| Abertura — chegada a Dreadwick | Apresentar ilha, Quint, Thomas, Betsy, Skye e Stewart; sem horror explícito. |

| Fim do Ato 1 — nova Fresnel | Vitória técnica vira ruptura; cor impossível, rádio, Stewart, ausência de formação rochosa. |

| Thomas — ponto de ruptura | Imagem forte do rádio/registrador e deterioração, sem exposição verbal. |

| Stewart abre a biblioteca | Mudança de acesso/verdade sobre a função do farol. |

| Fim do Ato 2 — mapa impossível | Quint percebe que a configuração antiga não pode ser restaurada. |

| Final — contenção | Ativação do sistema adaptativo; Cthulhu nunca mostrado de forma banal ou inteira. |

## 15.2. Diálogo padrão

Todo diálogo DEVE ser simples e sobreposto ao jogo. Um fundo prático reduz a leitura da cena; o NPC aparece de corpo inteiro. A interface DEVE exibir: trecho de fala do NPC, trecho de fala de Quint, descrição/narração ambiental no estilo DREDGE e um controle claro de confirmação para avançar.

Quando Quint fala, usar o HUD padrão dele ampliado 70% com emoção pertinente ao diálogo.

Cada nova caixa/fala de personagem começa com grunhido curto característico, sem voz completa.

Textos narrativos puros não precisam de grunhido.

Evitar exibir "+X% confiança" antes da resposta; o feedback pode aparecer depois.

# 16. Direção visual e arte

## 16.1. Ilha

Mobile vertical, diorama isométrico único.

Farol domina o ápice e a silhueta.

Escócia 1925: pedra, harl/off-white, ardósia, madeira envelhecida, metal funcional; evitar estética Nova Inglaterra/Canadá.

Vegetação baixa, fria e esparsa; rochas angulosas/fraturadas.

Base sem fumaça, glow, feixes ou efeitos; portas fechadas; personagens separados; fundo alpha real quando asset isolado.

Latrina em balanço sobre o penhasco; boathouse com slipway; píer longo e estreito.

## 16.2. HUD

Evitar steampunk ornamental. Buscar instrumento marítimo britânico de 1925 adaptado por mecânico.

Latão escurecido, ferro pintado, madeira, vidro e papel; menos filetes dourados e molduras grossas.

Estados contínuos = agulhas/gráficos. Valores acumulados = odômetros.

## 16.3. Personagens

Tratamento artístico consistente, estilizado e legível em sprite.

Mãos fora dos bolsos; poses espontâneas e naturais.

Retratos oficiais dos NPCs devem ser usados pela programação; mocks podem usar substitutos apenas como layout.

## 16.4. Iluminação noturna, fumaça e ocupação

Luz interna, fumaça de chaminé e lampiões são informações visuais de presença. Devem responder ao ciclo de tempo e ao estado real dos personagens, sem permanecer ligados como decoração fixa.

As casas de Quint, Stewart e Thomas devem possuir sprites/overlays separados de janelas acesas e de fumaça de chaminé, sempre com fundo alpha e alinhados ao sprite da respectiva construção.

Nas três casas, luz e fumaça aparecem somente à noite e somente quando o respectivo personagem está dentro. Se a casa estiver vazia, ambos permanecem desligados.

Na rotina de sono, luz e fumaça ficam ativas no início e no fim do ato de dormir. Durante a maior parte do sono, ambos ficam desligados, com a janela escura.

À noite, as janelas do farol acendem somente quando houver alguém dentro. A iluminação das janelas é independente do funcionamento da lente, do feixe e do sistema de lux.

Oficina, boathouse e latrina seguem a mesma regra de ocupação: à noite, suas janelas ou pontos de luz acendem enquanto um personagem estiver dentro e apagam quando o local fica vazio.

Todo personagem humano que caminhar pela ilha à noite deve carregar um lampião aceso por meio de sprite/overlay próprio, compatível com a direção e a animação de movimento.

Skye é exceção completa: por ser um cão, não acende edifícios por ocupação, não produz fumaça doméstica e nunca carrega lampião.

Esses efeitos são camadas de runtime. Nunca devem ser pintados permanentemente na ilha-base, nas construções-base ou nos sprites-base de caminhada.

# 17. Regras de implementação

## 17.1. Máquina de estados de Quint

| Estado | Função |

|---|---|

| Idle | Sem tarefa ativa. |

| Walking | Deslocamento terrestre. |

| Working | Trabalho genérico. |

| Fishing | Estado composto embarcado/captura/retorno. |

| EnteringBuilding / ExitingBuilding | Transições por alpha. |

| Sleeping | Recupera Energia e Insanidade conforme regras. |

| Eating | Consome Kit e reduz Fome. |

| UsingLatrine | Resolve Latrina e respeita fila de ocupação. |

| Talking | Interação com NPC. |

| Upgrading | Quint permanece ocupado; materiais consumidos no início. |

| Maintaining | Limpeza/reparo/abastecimento. |

| CarryingFuel | Galão visível no caminho depósito → farol. |

| Collapsed | Insanidade 100%. |

| Recovering | Recuperação forçada após Stewart levar Quint para casa. |

Implementar como FSM central. Evitar booleans dispersos que permitam estados incompatíveis simultâneos.

## 17.2. Estrutura da tarefa

Cada tarefa deve guardar: task.id, task.type, target, progress, duration, can.pause, can.cancel, source(manual/automation/system), resume.after.interrupt e requirements consumidos.

## 17.3. Save

player: estado, posição, necessidades, Insanidade, emoção, resistência.

world: dia/fase, clima visual, flags ambientais.

buildings: níveis, integridade, limpeza, combustível, automações.

inventory: dinheiro, Kits, querosene, peixes, materiais, peças-chave.

npcs: confiança, pedido, estado narrativo, visita, automação.

fishing: barco, capacidade, autonomia, equipamentos, coleção.

narrative: ato, flags, diálogos e marcos.

tasks: tarefa atual, fila, progresso e pausas.

## 17.4. Flags narrativas recomendadas

Usar flags explícitas em vez de um único story.progress numérico.

| Ato 1 | Ato 2 | Ato 3 |

|---|---|---|

| arrived.dreadwick | insanity.unlocked | adaptive.system.project.started |

| tutorial.complete | duncan.introduced | new.geography.mapped |

| first.salary.received | eddie.introduced | thomas.final.data.obtained |

| first.betsy.trade | thomas.stage.1 / stage.2 | duncan.feedback.active |

| lighthouse.automation.unlocked | stewart.library.unlocked | stewart.final.procedure.unlocked |

| workshop.level.2 | first.fresnel.fragment.found | final.configuration.ready |

| fresnel.project.started | ace.confirmed | containment.activated |

| fresnel.replaced / act1.complete | old.configuration.impossible / act2.complete | ending.complete |

## 17.5. Schema universal de upgrade

Todos os upgrades devem ser data-driven. Campos sugeridos: id, name, building, hotspot, level, max.level, cost, duration, required.items, supplier, required.act, required.trust, required.upgrade, effects, visual.state, unlock.ids.

## 17.6. Schema universal de NPC

Campos sugeridos: id, name, portrait, sprite, trust, trust.cap, routine, visit.days, requests, dialogues, narrative.state, automation, commerce.profile. Thomas usa estados normal → affected.1 → affected.2 → severe → withdrawn. Stewart usa tetos por ato.

## 17.7. Regra crítica de dados

Custos, taxas, tempos, capacidades, ganhos, penalidades e curvas devem viver em Resources/JSON/arquivos de configuração editáveis sem alterar código. O objetivo é permitir balanceamento por playtest.

# 18. Valores provisórios de protótipo

Todos os valores desta seção são placeholders aprovados para implementar e testar. Não são balanceamento final.

| Sistema | Valor inicial sugerido |

|---|---|

| Energia idle | +1 ponto / 20 s |

| Energia pesca | +1 / 8 s |

| Energia trabalho pesado | +1 / 10 s |

| Fome | +1 / 25 s |

| Latrina | +1 / 35 s |

| Recuperação Energia | -1 / 3 s dormindo |

| Recuperação Fome | -1 / 2,5 s comendo |

| Kit Sobrevivência | 1 Kit ≈ 20 pontos de Fome |

| Barco inicial | 20 kg; autonomia 90 s |

| Captura | 1 peixe a cada 8–15 s, ajustável |

| Farol inicial | Tanque para .2 noites |

| Insanidade base Ato 2 | +1 a cada 30–60 s sob pressão normal |

| CONFIANÇA diálogo relevante | +2 a +5% |

| CONFIANÇA pedido normal | +5 a +8% |

| CONFIANÇA pedido importante | .+10% |

| Comércio rotineiro | 0% após interação inicial relevante |

| Automação de NPC | 75% / Alta Confiança |

| Offline inicial | 2h, eficiência .45% |

| Upgrades iniciais | 5–15 min |

| Intermediários | 20–60 min |

| Avançados | 1–3 h |

| Projetos narrativos grandes | várias horas |

## 18.1. Penalidade provisória de Insanidade

| Insanidade | Penalidade de eficiência sugerida |

|---|---|

| 0–20% | quase nenhuma |

| 20–40% | até .-5% |

| 40–60% | até .-12% |

| 60–80% | até .-22% |

| 80–99% | até .-35% |

| 100% | desmaio e recuperação forçada |

A implementação final deve interpolar suavemente, não aplicar degraus rígidos.

# 19. Vertical slice recomendado para começar

Antes de implementar Ato 2, construir um Ato 1 mínimo totalmente jogável que prove o loop idle e a arquitetura.

Relógio central de 8 minutos + fases do dia.

FSM de Quint + pathfinding + entrada/saída por alpha.

Necessidades: Energia, Fome, Latrina.

Casa: dormir/comer, Kit Sobrevivência e upgrades básicos.

Latrina compartilhada e fila de ocupação.

Boathouse + pesca automática + câmera deslocando para o mar.

Depósito + estoques + enciclopédia base.

Betsy: chegada animada, comércio, pedido simples, CONFIANÇA e Kit/querosene.

Dinheiro £/s/d e salário semanal.

Oficina + upgrade universal data-driven.

Farol: abastecimento, limpeza, rotação, ligar/desligar e automação inicial.

Fila 1+3 tarefas e prioridades.

Save/load + offline inicial de 2h.

Tela de Quint com emoções, confiança e offline.

Só depois: Fresnel e transição narrativa para Ato 2.

# 20. Pendências de balanceamento e conteúdo

Os itens abaixo não impedem o início da programação, desde que sejam implementados como dados configuráveis.

Playtest fino dos valores por kg e da curva de mutação, preservando o catálogo, as relações de preço e as regras econômicas canônicas da Seção 9.

Capacidades exatas de estoque e progressão por nível.

Consumo final de querosene por potência/lux.

Taxas finais de necessidades e recuperação.

Curva exata de Insanidade e Resistência ao ACE.

Custos finais do Pulso de Contenção.

Número final de níveis por ramo de upgrade.

Valores de CONFIANÇA por evento e benefícios específicos de 100% para cada NPC.

Conteúdo completo de diálogos, pedidos e documentos.

Destino final/estado exato de Thomas após sua deterioração avançada.

# 21. Regras que não devem ser quebradas

Quint não é escolhido por profecia e não ganha poderes.

Stewart é humano e possui conhecimento incompleto; não é entidade secreta.

The Vigil não é culto nem ordem de combate.

N.A.S.H. não é corporação onisciente nem culto disfarçado.

Cultistas não fazem parte da estrutura atual.

Mais lux é sempre melhor para contenção.

Quint não é incompetente; seus upgrades do Ato 1 são tecnicamente sensatos.

A Fresnel antiga já estava estruturalmente condenada.

O jogador nunca deve sofrer softlock permanente por necessidade, falta de Kit ou erro comum.

Automação reduz cliques repetitivos, mas preserva deslocamentos, visitas e presença física na ilha.

Cutscenes são visuais e silenciosas; diálogos acontecem separadamente.

Personagens não devem ser gerados com mãos nos bolsos; poses precisam ser espontâneas.

Interiores não usam eletricidade doméstica; luz vem de fontes plausíveis de 1925.

Luzes internas, fumaça e lampiões noturnos devem refletir tempo, ocupação e estado real; não podem funcionar como decoração permanente. Skye é a única exceção às regras de lampião e ocupação.

O jogo é mobile vertical e todas as interfaces devem ser testadas em escala real de celular.

# 22. Resumo de implementação para Claude

Prioridade de arquitetura: TimeSystem → QuintFSM → TaskQueue → Save/Offline → Data-driven Upgrades/Items → Buildings → NPC Framework → UI universal → Fishing → Lighthouse → Narrative Flags. Não espalhar regras de prioridade em scripts individuais. Sistemas devem conversar por eventos/sinais e dados configuráveis.

Primeiro objetivo jogável: um ciclo completo em que Quint trabalha, sente necessidades, usa casa/latrina, pesca, vende para Betsy, compra Kit/querosene, melhora uma construção, mantém o farol e salva/retorna offline. Se esse loop for sólido, o Ato 2 pode ser adicionado sem reescrever a base.

# 23. Contrato técnico de assets e integração com Godot

REGRA DE PRECEDÊNCIA: Esta seção substitui qualquer orientação anterior de assets que conflite com ela. Mockups são referência visual; a programação nunca deve depender de uma tela ou cenário achatado em um único PNG.

## 23.1. Estrutura de cenário

O runtime NÃO deve assumir parallax lateral tradicional. Dreadwick usa composição vertical isométrica em camadas.

Camadas mínimas de runtime: fundo/atmosfera, mar, ilha-base, edificações, personagens/veículos e overlays/FX.

A ilha completa achatada pode existir como guia visual e mockup, mas NÃO é o asset técnico final se houver qualquer construção com upgrade, dano, destaque, ocultação ou troca de estado.

Rocha, terreno, caminhos e elementos permanentes ficam na ilha-base. Cada edificação deve ser um sprite transparente independente, posicionado por coordenada/pivô documentado.

Efeitos como neblina, chuva, luz do farol, fumaça, glow e animações ambientais ficam em camadas separadas e nunca são pintados permanentemente na ilha-base.

FX noturnos obrigatórios: overlays de janelas/pontos de luz para as casas de Quint, Stewart e Thomas, farol, oficina, boathouse e latrina; sprites de fumaça para as chaminés das três casas; e sprite/overlay de lampião aceso para cada personagem humano que caminhe à noite.

A ativação desses FX deve ser dirigida por TimeSystem + ocupação do edifício + fase de sono. Um único estado autoritativo deve controlar imagem, luz e fumaça para evitar divergências visuais.

## 23.2. Padrão obrigatório de sprites de mundo

Todo sprite de personagem deve usar a mesma escala de referência do mundo. A altura padrão deve ser documentada em pixels e aplicada a todo o elenco.

O pivô/anchor de personagens deve ficar nos pés. Veículos e edifícios devem possuir pivô consistente e documentado.

Movimento isométrico deve ter, no mínimo, as quatro direções usadas pelo jogo (NE, NW, SE, SW). Direções adicionais só são produzidas se a implementação realmente as utilizar.

Arquivos de animação devem seguir nomenclatura determinística: personagem.acao.direcao.frame.extensão (ex.: quint.walk.ne.01.png).

Cada animação deve declarar quantidade de frames e FPS em um manifest de assets. Não variar frame count ou escala sem registrar a alteração.

Personagens NÃO devem ter mãos nos bolsos. Poses ilustrativas e de diálogo devem ser espontâneas, variadas e coerentes com função/personalidade.

## 23.3. Personagens oficiais

A programação deve utilizar exclusivamente os retratos e sprites oficiais aprovados. Mockups de UI podem usar placeholders, mas placeholders nunca entram no build de produção.

Betsy substitui definitivamente qualquer versão antiga: mulher negra, robusta, aparência vivida, macacão de trabalho escuro, botas pretas de cano alto, roupa marítima funcional e postura firme.

Betsy e Quint possuem interesse romântico leve e mútuo. Retratos/poses podem incluir ironia, diversão, preocupação e flerte discreto; não criar linguagem visual melodramática.

Quint deve manter prótese discreta, casaco mostarda envelhecido e leitura de mecânico/veterano; não transformar o personagem em aventureiro genérico.

## 23.4. Assets de UI

Telas completas geradas como mockup NÃO devem ser usadas como um único PNG interativo. A UI deve ser montada com componentes separados no Godot.

Componentes mínimos reutilizáveis: molduras, papéis, cabeçalhos, botões, odômetros, barras, agulhas, ícones de requisito, hotspots, caixas de diálogo e blocos de narração.

O HUD universal de edificações deve existir como componentes modulares: cabeçalho, estado atual, próximo estado, efeito, requisitos, fornecedor, custo, tempo, progresso e botão de ação.

A tela de diálogo deve montar dinamicamente: fundo prático, NPC de corpo inteiro, fala do NPC, HUD emocional de Quint, fala de Quint, bloco narrativo e confirmação de avanço.

Tela de Quint, CONFIANÇA, Depósito e Coleção são telas funcionais próprias e devem ter diretórios de UI específicos.

Fontes oficiais de runtime: Oswald (Medium 500 e SemiBold 600), Crimson Pro (Regular 400, Italic 400 e SemiBold 600) e IM Fell English Regular para usos históricos pontuais. Incluir arquivos e licenças no projeto.

## 23.5. Veículos obrigatórios

Barco de Quint: saída do boathouse, navegação/pesca, retorno e estados visuais de upgrade.

Barco de Betsy: aproximação, atracação/espera e partida.

Barco de Duncan: aproximação, atracação/espera e partida, com identidade N.A.S.H. consistente.

Hidroavião de Eddie: cruzeiro no céu, aproximação/amerissagem, taxiamento/espera e partida; orientações necessárias devem ser produzidas conforme uso real da câmera.

Todos os veículos devem ter escala e pivô documentados e nunca ser fundidos permanentemente à ilha.

## 23.6. Identidade N.A.S.H.

Deve existir um master oficial da logo N.A.S.H. e variantes técnicas aprovadas para uniforme, hidroavião, barco de Duncan, bolsa/equipamento, documentos e carimbos.

Nenhum artista ou script deve recriar a logo manualmente em cada asset. Todas as aplicações derivam do mesmo master.

## 23.7. Fauna e silhuetas

Cada espécie deve possuir par comum + mutante com o mesmo identificador-base.

A silhueta preta de peixe não descoberto DEVE ser gerada no Godot a partir do alpha do PNG, por shader/material. Não produzir uma segunda imagem manual por espécie salvo exceção aprovada.

Peixes devem manter fundo alpha real e escala relativa consistente para UI, captura sobre o barco e coleção.

O catálogo de runtime é fechado em 20 espécies, numeradas de 01 a 20 nas pastas Peixes.Comuns e Peixes.Mutantes; os dois arquivos de cada espécie devem compartilhar o mesmo número-base.

O Peixe-pipa corrigido é o master oficial da espécie. Versões anatômicas antigas não devem retornar ao runtime ou à enciclopédia.

Truta-marrom, Lúcio, Perca, Grayling, Truta-arco-íris, Vendace, Powan e o Robalo duplicado são assets descontinuados e não devem ser reintroduzidos.

## 23.8. Áudio de diálogo

Cada personagem deve possuir 3–6 grunhidos curtos reutilizáveis. Uma variação é sorteada no início de cada nova caixa de fala.

Não há dublagem completa. Texto narrativo puro não dispara grunhido.

SFX devem ser separados por sistema: ambiente, passos, pesca, barcos, hidroavião, farol, rádio, sismógrafo, odômetros/UI, latrina e eventos ACE.

## 23.9. Arquivos-fonte e runtime

Arquivos editáveis vivem fora da árvore importada pelo Godot, em art.source/ (ou equivalente).

O projeto usa game/assets/ (ou equivalente) apenas para PNG/WAV/OGG/TTF finais utilizados no runtime.

Não manter uma terceira cópia manual "espelho" de exportação. O asset aprovado deve ter uma única cópia de runtime para evitar divergência de versão.

Versões antigas e testes não entram na pasta de runtime.

## 23.10. Manifest de assets

Todo asset de mundo deve possuir registro em manifest com: id, caminho, categoria, ato, status (placeholder/aprovado/final), escala, pivô, direções, animações, FPS e fonte visual aprovada.

A programação deve referenciar assets por id/caminho estável, nunca por nomes improvisados ou arquivos de mockup.

Mudança de asset aprovado exige atualização do manifest e substituição controlada no runtime.

## 23.11. Ordem de produção obrigatória

Vertical slice Ato 1: Quint, Skye, ilha-base e construções essenciais, Casa, Latrina, Boathouse/barco, Betsy, Depósito, necessidades, dinheiro, Farol e Oficina.

Thomas e estação entram assim que o loop base estiver jogável e estável.

Somente depois: Duncan, Eddie, mutantes, Insanidade, arquivos avançados de Stewart e conteúdo visual dos Atos 2/3.

Cutscenes são produzidas por último dentro de cada marco narrativo, depois que o gatilho correspondente estiver validado em gameplay.

# 24. Ordem final de autoridade

PARA CLAUDE E PRODUÇÃO: Quando uma decisão estiver nesta Bíblia como regra canônica, a implementação deve obedecê-la. Se um mockup, asset antigo, manual anterior ou placeholder divergir desta versão, esta Bíblia prevalece. Balanceamento numérico permanece configurável; arquitetura, funções, narrativa, direção de arte e regras de apresentação não devem ser reinterpretadas sem decisão explícita do projeto.

DREADWICK — Bíblia Oficial de Desenvolvimento
