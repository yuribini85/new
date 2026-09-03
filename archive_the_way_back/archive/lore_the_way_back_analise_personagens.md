# THE WAY BACK — Análise de Lore a partir das 98 entradas do Grimm Asset Forge R09

Documento de direção narrativa. Base: briefing 0.1 (idle 2D isométrico, Godot 4.7, vila de órfãos, pai morto secretamente pela força antagonista da floresta) + lista de 98 personagens/seres KHM.

---

## 1. A tese central da lore

O briefing já contém, sem explicitar, a regra que organiza os 98 personagens:

> **Todo conto de Grimm é a história de uma criança que é entregue à floresta por um adulto que deveria protegê-la.**

João e Maria são o caso arquetípico: pai passivo, madrasta ativa, floresta como executora. A vila é a resposta a isso — o primeiro lugar do mundo dos contos onde a entrega não acontece.

Disso decorre a estrutura mecânica:

- **Cada conto = um par.** Uma vítima (vira habitante) e um algoz (vira ameaça). O conto só é "arquivado" quando o jogador acolhe a vítima *e* neutraliza/entende o algoz.
- **A floresta é simultaneamente fonte de população e ameaça** (item 21 do briefing). A lista de 98 confirma isso numericamente: ~40 vítimas contra ~20 antagonistas contra ~25 seres ambíguos.
- **O jogador não salva as crianças.** Ele constrói o lugar para onde elas conseguem correr. Isso preserva o gênero idle: você administra a chegada, não a missão de resgate.

---

## 2. Classificação funcional das 98 entradas

### 2.1 Órfãos acolhidos — a população (≈ 30 entradas)
Entradas 6–41 da lista, exceto os adultos. São crianças que chegam à vila fugindo do próprio conto. Mecanicamente: entram como *criança*, crescem, viram *adulto*, recebem função.

Cada uma carrega uma **aptidão herdada do conto** — é daqui que sai o sistema de funções sem precisar inventar classes genéricas:

| Personagem | Conto | Aptidão sugerida |
|---|---|---|
| Filha do Moleiro | KHM 55 | Fiar / têxtil (produção de alto valor, custo emocional) |
| Pastora de Gansos | KHM 89 | Criação animal |
| Menina Trabalhadora de Holle | KHM 24 | Produtividade base +, referência de "trabalho justo" |
| Alfaiate Valente | KHM 20 | Defesa por astúcia, não por força |
| Simplório | KHM 62–64 | Sorte / eventos raros |
| Menina dos Táleres | KHM 153 | Doação: converte recursos em moral |
| Filha Sábia do Camponês | KHM 94 | Administração, reduz custo de upgrade |
| Menina sem Mãos | KHM 31 | Cura / enfermaria (regeneração lenta) |
| Duas-Olhos | KHM 130 | Alimento (a mesa que aparece do nada = plantação) |
| Jovem que não conhecia o medo | KHM 4 | Vigia noturno, imune a eventos de terror |
| Rapunzel, Bela Adormecida, Maleen | KHM 12/50/198 | Arquétipo "aprisionada": chegam tarde, valor alto |

**Decisão de design recomendada:** limite de ~12 órfãos nomeados no primeiro ano de conteúdo. O resto da população é anônima. Personagem nomeado é caro (arte modular, diálogo, evento próprio) e o apego só funciona se houver poucos.

### 2.2 Adultos e mentores (≈ 8 entradas)
Pescador, Mestre Ladrão, Caçador de Chapeuzinho, Pele-de-Urso, João Fiel, Avó de Chapeuzinho, Henrique de Ferro, Servo da Serpente Branca.

Função: **desbloqueiam edifícios e ensinam funções**. São os poucos adultos que não traíram uma criança — por isso podem estar na vila. O Caçador abre a defesa; o Pescador abre a pesca; o Mestre Ladrão abre a recuperação de recursos da floresta (risco/retorno); Pele-de-Urso é o veterano marcado, mercenário caro.

**Henrique de Ferro** merece destaque: o servo que pôs faixas de ferro no próprio peito para não se partir de tristeza. É o personagem-tema do jogo. Sugestão: NPC fixo da vila, ligado ao luto pelo pai.

### 2.3 Antagonistas ativos — as ameaças da floresta (≈ 20 entradas)
Bruxa da Casa de Doces, Rainha Má, Feiticeira de Rapunzel, Madrasta de Cinderela, Feiticeira-Coruja, Feiticeiro do Pássaro de Fitcher, Noivo Ladrão, Feiticeira de Roland, Madrasta do Junípero, Lobo dos Contos, Uma-Olho e Três-Olhos, Irmãs de Cinderela, Falsa Noiva, Mulher do Pescador, Irmã Preguiçosa, Velho Rinkrank, Nixie do Lago, Rumpelstiltskin.

Escalonamento por **tier de ameaça**, que dá a curva de dificuldade do idle:

- **T1 — Predadores simples:** Lobo, Irmãs de Cinderela, Irmã Preguiçosa. Perdem recursos, não vidas.
- **T2 — Sequestradores:** Feiticeira-Coruja, Feiticeira de Rapunzel, Rinkrank, Nixie. Removem um habitante temporariamente; exigem resgate.
- **T3 — Devoradores:** Bruxa da Casa de Doces, Madrasta do Junípero, Feiticeiro de Fitcher, Noivo Ladrão. Perda permanente possível.
- **T4 — Rainhas e pactos:** Rainha Má, Rumpelstiltskin. Não atacam: negociam. Oferecem ganhos enormes por preço narrativo (uma criança, um nome, um ano de vida).

**Observação importante:** a Bruxa da Casa de Doces está morta na premissa (João e Maria sobreviveram a ela). Recomendo mantê-la morta e usá-la como *ruína visitável* — a casa de doces apodrecida vira um dos desbloqueios de território. Ressuscitá-la enfraquece a abertura.

### 2.4 Potências — os candidatos ao mistério (6 entradas)
Diabo dos Contos, Madrinha Morte, Senhora Holle, Décima Terceira Sábia, João de Ferro, Grifo.

Estes não são inimigos de combate. São **leis do mundo**. Cada um responde a uma pergunta diferente sobre por que a floresta existe.

### 2.5 Seres ambíguos e contratantes (≈ 12 entradas)
Rei Sapo, Espírito na Garrafa, Homem da Luz Azul, Rainha das Abelhas, Raposa Conselheira, Pássaro de Ouro, Ganso de Ouro, Urso Encantado, Falada, Pássaro do Junípero, Elfos do Sapateiro, Três Homenzinhos da Floresta, Gigante Grimm, Dragão dos Dois Irmãos.

Função: **sistema de favores**. Não são bons nem maus; respondem a hospitalidade. É a mecânica que amarra o tema — a vila prospera porque acolhe, inclusive o que é estranho.

- **Elfos do Sapateiro / Três Homenzinhos:** produção offline noturna. Encaixe perfeito no sistema idle (item 38–39 do briefing). Se o jogador deixar oferendas, o ganho offline sobe. Se tentar *ver* os elfos, eles vão embora — punição por checar o jogo demais. Elegante.
- **Rainha das Abelhas:** bônus de plantação.
- **Falada** (cabeça de cavalo falante pregada no portão): sistema de aviso. Anuncia ameaças que chegam. Visualmente Rackham puro.
- **Raposa Conselheira:** tutorial diegético, substitui pop-ups de ajuda.
- **Gigante / Dragão:** eventos de território tardio, bloqueiam expansão de mapa.

### 2.6 Grupos — pacotes de população (≈ 10 entradas)
Sete Cabritinhos, Seis Irmãos-Cisnes, Sete Corvos, Doze Irmãos-Corvos, Três Fiandeiras, Doze Princesas Dançarinas, Músicos de Bremen, Seis Servos Extraordinários, Sete Homens da Montanha.

Chegam **em bloco**, com um custo de acolhimento alto e um bônus coletivo. São os marcos de crescimento da vila: o momento em que a população salta.

- **Sete Corvos / Doze Irmãos:** chegam como corvos. Ocupam espaço, não produzem, até serem desencantados por um custo longo. Excelente sink de recursos de médio prazo.
- **Músicos de Bremen:** os quatro animais velhos, descartados por não servirem mais. Tematicamente são o oposto exato do pai que abandona — quatro adultos que se recusam a morrer sozinhos. Devem ser um marco emocional, não só um bônus.
- **Seis Servos Extraordinários:** cada um com uma habilidade absurda. Pacote de late-game, um por vez.

### 2.7 Fauna (8 entradas)
Corvo, Cervo, Ganso, Lebre, Coelho, Raposa, Lobo, Urso.

Camada de recurso e ambientação. Recomendo tratá-los como **estado do mapa**, não como personagens: a proporção de corvos visíveis indica o nível de ameaça atual da floresta. Barra de perigo diegética, sem UI extra.

---

## 3. O mistério central: quem matou o pai

O briefing exige uma resposta (itens 20 e 22). A lista oferece quatro candidatos legítimos. Ranqueados por força temática:

**1ª opção — A Décima Terceira Sábia (KHM 50). Recomendada.**
A fada não convidada. A que amaldiçoou um reino inteiro porque não havia prato para ela na mesa. Num jogo cujo verbo central é *acolher*, o antagonista ser **aquela que não foi acolhida** fecha o círculo perfeitamente. Implicação: o pai de João e Maria fez a única coisa imperdoável nesse mundo — mandou embora alguém que pediu abrigo (provavelmente na noite em que abandonou os filhos). A floresta cobrou. E a vila, ao acolher todo mundo, está literalmente desfazendo a maldição estrutura por estrutura. O final não é matá-la: é pôr um prato para ela.

**2ª opção — Madrinha Morte (KHM 44).**
Mais melancólica, menos jogável. Funciona se você quiser um jogo sobre luto em vez de sobre culpa. Risco: retira a agência do jogador — contra a Morte não se constrói vila.

**3ª opção — O Diabo dos Contos (KHM 29/100/125/189).**
Mais direto, mais genérico. Bom para pactos e comércio, fraco como revelação final. Sugiro usá-lo como **falsa pista principal**: tudo aponta para ele por 2/3 do jogo.

**4ª opção — Senhora Holle (KHM 24).**
Não como assassina, mas como **juíza**. Ela recompensa quem trabalha e pune quem não trabalha. Reserve-a para o sistema de avaliação da vila: ao fim de cada era, Holle inspeciona e cobre ouro ou piche. Melhor papel que o de vilã.

**Estrutura de revelação sugerida (3 atos):**
1. *Ato I* — a morte parece acidente da floresta. Ameaças T1–T2. Suspeita recai sobre o Lobo.
2. *Ato II* — pistas apontam para um pacto. Rumpelstiltskin e o Diabo entram em cena; o jogador é tentado a fazer o mesmo pacto que o pai supostamente fez.
3. *Ato III* — revela-se que não houve pacto. Houve uma porta fechada. A Décima Terceira Sábia sempre esteve visível no mapa, desde o primeiro minuto, como uma figura na borda da floresta que o jogador não podia interagir — até ter alojamento sobrando.

---

## 4. Consequências diretas para o protótipo 0.1

Nada acima exige trabalho extra agora, mas três decisões baratas no MVP preservam tudo isso:

1. **O órfão-lenhador do 0.1 deve ter nome de conto**, não "orphan_worker_01" na ficção. Sugestão: usar a **Menina Trabalhadora de Holle** ou o **Alfaiate Valente** — ambos são personagens cuja identidade é o trabalho. Custo: uma linha de texto.
2. **Reservar um lote dos 6** (item 68) como visualmente ocupado por algo que o jogador não pode construir ainda — a borda onde a figura observa. Ancora o mistério desde a primeira tela.
3. **O ganho offline (2h, 50%) deve ser narrado como trabalho dos Elfos/Três Homenzinhos**, não como número. Mesma mensagem do item 78, moldura diferente, zero custo técnico.

---

## 5. Lacunas a decidir

- Qual é o papel da **Madrasta de João e Maria** (entrada 5)? Está viva? A premissa fala só da morte do pai. Ela é a peça mais óbvia ainda não alocada — e a candidata natural a antagonista intermediária do Ato I.
- **João e Maria são jogáveis ou NPCs fundadores?** O item 18 diz que o jogador é o guardião da comunidade *fundada por* eles, o que sugere NPC. Convém fixar antes da arte.
- **Cinderela, Branca de Neve e Rapunzel** são personagens de destino próprio, não de vila. Decidir se entram como habitantes (barateia o mito) ou como visitantes/eventos (preserva a escala). Recomendo visitantes.
