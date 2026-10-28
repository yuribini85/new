# The Fastfather — pedido de arte (2026-10-28)

Levantamento do que o jogo carrega de fato hoje. Ordem de prioridade: o que o jogador vê mais cedo e
mais vezes vem primeiro. Estilo de tudo: o da pasta `arte/fastfather/` (anos 30, sépia/carvão, traço de
quadrinho, neon âmbar só no que é tocável). Medidas iguais às dos arquivos que cada peça substitui.

## A. Substituir: arte do Chrome & Wreckage ainda em uso

| # | O quê | Onde aparece | Arquivos hoje | Medida | Qtd |
|---|---|---|---|---|---|
| A1 | Fotos das pistas | Cabeçalho e lista de PISTAS, faixa da corrida, foto do jornal | `arte/ui/banner_parque_das_docas`, `banner_circuito_misto`, `banner_anel_do_vale`, `banner_serra_alta`, `banner_arena_patio_pedreira`, `banner_arena_fosso_docas`, `banner_arena_anel_ferro_velho`, `banner_arena_cratera_vale`, `fundo_competicoes` | 1200×500 webp | 9 |
| A2 | Ícones das modalidades | Selo da modalidade na corrida e botões de PISTAS | `arte/ui/icone_correr`, `icone_pista`, `icone_potencia`, `icone_tracao_4x4`, `emblema_arena` | 256×256 png transparente | 5 |
| A3 | Ícones soltos | Visto (Missões, Pistas, fim da corrida); vaga vazia de capanga | `arte/ui/icone_ok`, `icone_piloto` (o `icone_cadeado` saiu de cena) | 256×256 png | 2 |
| A4 | Folhas de números pintados | Número na lataria de todos os carros | `arte/ui/pintura/digitos_{condensado,bloco,estencil,pincel,serifa}` | 1280×192 png, dígitos 0–9 em linha | 5 (podem virar 2–3 da época: estêncil, pincel, letreiro de placa) |
| A5 | Objetos da Rinha | Cones, barris, pneus, troncos, blocos de concreto na arena | `arte/dano/*.glb` | modelos low-poly | 12 → trocar por fardos de feno, barris de madeira, caixotes, pneus de época, mourões |
| A6 | Sons de antes | Motor, pneu, torcida, batida, moeda, toque, ultrapassagem, chegada, impactos da Rinha | `arte/sons/` motor, motor_grave, pneu, torcida, batida, moeda, toque, passagem, comemoracao, impacto, raspagem, explosao, ofegante, porta_abre | ogg | 14 (prioridade: motor e motor_grave — carro de 4 cilindros dos anos 30 —, torcida com chapéu e apito, moeda → caixa de lata) |
| A7 | Fontes | Rótulos e números de toda a interface | Barlow Condensed, Big Shoulders Display, Racing Sans One | — | decisão sua (ver nota) |

Já resolvido em código, sem arte: a modalidade Rinha das Famílias usava os caminhões e picapes modernos do
C&W (`arte/carros3d/*.glb`); agora usa os mesmos carros da época da aba RINHA.

Nota sobre A7: Barlow/Big Shoulders são neutras e leem bem no celular; a troca é de identidade, não de defeito.
Sugestão: manter Barlow nos números pequenos e trocar só a "display" (títulos) por uma art déco condensada
da mesma família da Limelight já em uso.

## B. Criar: arte que falta (hoje o jogo usa um substituto)

| # | O quê | Onde | Substituto atual | Medida |
|---|---|---|---|---|
| B1 | Fotos de 5 pistas | PISTAS e corrida | `fundo_competicoes` genérico | 1200×500 — `mirante_da_costa`, `avenida_noturna`, `oval_inclinado`, `trilha_do_canion`, `estrada_das_araucarias` |
| B2 | Ícone da câmera dupla | Barra de câmeras | ícone do mapa | 160×160 `arte/fastfather/icones/cameras/dupla.png` |
| B3 | Voz do locutor | Largada, chegada, vitória | silêncio | ogg `arte/sons/locutor_largada`, `locutor_chegada`, `locutor_vitoria` (rádio AM, 2–4 s) |
| B4 | Mapa de cada cidade | PISTAS (troca de cidade) | só texto | a definir junto (1 por cidade) |
| B5 | 16º troféu | Estante de troféus | — | 256×256 `trofeu_16.png` |
| B6 | Loja à noite | Garagem quando a corrida é noturna | fundo do dia | 941×1672 `arte/fastfather/loja/fundo_noite.webp` |
| B7 | Capanga exclusivo da Família Fundadora (opcional) | Capangas | dourado por pintura | 204×387 como `rapazes/rapaz_XX.png` |

## C. Arrumação (sem pedido de arte)

- `arte/personagens/corpo/` (chefão, sobrinho, Tony) já é arte nova; só está na pasta antiga. Mover para
  `arte/fastfather/personagens/` quando houver uma rodada de limpeza.
- Arte nova que nenhum código usa: `arte/fastfather/corrida/*` (ponteiro, velocímetro, poses do Tony e do
  sobrinho) e `arte/fastfather/icones/atlas_*.png`. As poses podem virar a reação do Tony na chegada.
- Pastas do C&W que o Fastfather não carrega (pilotos, pistas/kit, cenários, cenas): ficam para o outro jogo.
