# Chrome & Wreckage — Demanda 03 (arte, números e regras)

O que o jogo precisa e só você (ou o artista) pode entregar. Cada item diz o formato,
onde entra no jogo e o que acontece até lá. Tudo o que não depende disto já está feito.

## A. Arte

Regras gerais: personagens em PNG RGBA 1024 × 1536 (2:3), figura cortada na cintura/coxa
como as da Mara, fundo transparente sem halo; cenários em PNG 941 × 1672 (sem
transparência); estilo low‑poly chapado dos retratos já entregues. Nada de marcas,
logotipos ou carros reconhecíveis.

| # | Peça | Formato | Onde entra | Até lá |
|---|------|---------|-----------|--------|
| A1 | **Logo Wreckage Motorsport** (equipe do jogador) | PNG RGBA, ~1200 px de largura, fundo transparente; só a palavra principal + emblema (a tela já escreve "MOTORSPORT" embaixo) | Aba Equipe (faixa do topo) e resultado das corridas | Nome em texto ocre |
| A2 | **Segundo piloto da oficina** (chega na licença Pro) | Corpo 1024 × 1536 RGBA, macacão diferente do Theo | Diálogo da Mara na Pro e aba Equipe | Usa o Jonas Reid da história antiga, sem retrato |
| A3 | **Nome do segundo piloto** | Texto | `data/carreira.json` → `segundo_piloto` | "Jonas Reid" |
| A4 | **Tela inicial** com a identidade Chrome & Wreckage (oficina/pista ao entardecer, espaço livre no terço de cima para o logo) | 4 camadas de parallax como as atuais: céu (sem transparência), fundo, meio e frente (com transparência) — PNG 941 × 1672 cada | Tela de abertura | Paisagem da versão anterior |
| A5 | **Ícone do app** | PNG 1024 × 1024, sem transparência, legível em 48 px | Android/iOS | Ícone padrão do Godot (o projeto não tem ícone) |
| A6 | **Mara, pose extra (opcional)**: rindo de canto / satisfeita | Corpo 1024 × 1536 RGBA | Falas de vitória e marcos | Pose "firme" ou "gesto" |
| A7 | **Texturas de asfalto** ambientCG *Asphalt026* e *Asphalt031* | Pacote 1K‑PNG baixado do site (o site é bloqueado nesta rede) | Pista (hoje desgaste procedural) | Asfalto procedural |

## B. Números (balanceamento)

Pela regra do projeto, não estimo valores: vêm do estudo do GT2 ou de playtest seu.

| # | Valor | Onde | Hoje | Critério sugerido |
|---|-------|------|------|-------------------|
| B1 | **Patrocínio por corrida** da equipe | `data/carreira.json` → `equipe_jogador.patrocinio` | "a definir no playtest" (vale 0) | Fração do prêmio médio das provas International (extrair do GT2) |
| B2 | **Custo de staff por corrida** | `equipe_jogador.custo_staff` | "a definir no playtest" (vale 0) | Menor que o patrocínio na International, maior na Pro sem vitórias |
| B3 | **Tempo até a licença Sport** | ritmo da campanha | 142–183 min de corrida no playtest automático | Jogar 20–30 min antes de mexer; se lento, igualar ao tempo até a licença A do GT2 |

## C. Regras da Arena (antes de construir o modo)

A Arena hoje é só o botão "em breve". Para construir preciso que você decida:

1. **Risco de perda:** o carro some ao ser destruído? Com que chance, ou a partir de que dano?
2. **Prêmio:** maior que o das corridas da mesma licença? Quanto (critério, não número)?
3. **Reparo:** existe? Custa giros, tempo, ou os dois?
4. **Piloto:** pode se machucar ou só o carro sofre? (O documento recomenda só o carro.)
5. **Desbloqueio:** em que ponto da carreira a Arena abre (ex.: licença National)?
6. **Carros:** qualquer carro da garagem ou só os "reforçados" (peça de blindagem que pesa)?

## D. Já feito nesta rodada (sem depender de você)

- Falas de marco da Mara no meio do jogo: primeira vitória com licença Club, Sport e
  National; 10 e 25 provas vencidas.
- Diário de conversas (Configurações → História → Diário).
- Som de fundo da oficina nas cenas com fundo de oficina ou garagem.
- A largada espera qualquer conversa acabar (3‑2‑1 só depois).
