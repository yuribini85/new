# IDs do jogo

Gerado por `tools/listar_ids.py` a partir de `data/` e do código. Não editar à mão.

## Personagens (`data/personagens.json`)

| id | nome |
|---|---|
| `adrian` | Adrian Cross |
| `elena` | Elena Cross |
| `marcus` | Marcus Reed |
| `victor` | Victor Hale |
| `lucas` | Lucas Ward |
| `sophie` | Sophie Laurent |
| `vendedor` | Vendedor · Second Chance Motors |
| `responsavel` | Vector Academy |
| `jornalista` | Jornalista |
| `sistema` |  |

## Cenas (`data/dialogos.json`, de `tools/historia/cenas.txt`)

| id | trigger | capítulo | grava |
|---|---|---|---|
| `SCN_A00` | `GAME_START` | I | `STORY_STARTED` |
| `SCN_A01` | `ENCADEADA` | I | `GARAGE_TUTORIAL_SEEN` |
| `SCN_A01L` | `LEMBRETE` | I | — |
| `SCN_A02` | `EVOLUCAO` | I | `TUNE_TUTORIAL_SEEN` |
| `SCN_A02L` | `LEMBRETE` | I | — |
| `SCN_A02B` | `EVENTO_SELECIONADO` | I | — |
| `SCN_A03` | `DEMANDA_CONCLUIDA` | I | `FIRST_TUNE_DONE` |
| `SCN_A03B` | `ENCADEADA` | I | — |
| `SCN_A04` | `ABA:EVENTOS` | I | `EVENT_MENU_TUTORIAL_SEEN`, `CHAMPIONSHIP_TUTORIAL_DONE` |
| `SCN_A04L` | `LEMBRETE` | I | — |
| `SCN_A05` | `CORRIDA_INICIO` | I | `FIRST_RACE_BRIEFED` |
| `SCN_A06` | `CORRIDA_FIM` | I | `FIRST_RACE_DONE`, `FIRST_WIN_ADRIAN` |
| `SCN_A06B` | `CORRIDA_FIM` | I | `FIRST_RACE_DONE` |
| `SCN_A07` | `EVENTO_BLOQUEADO` | I | `EVENT_REQUIREMENTS_TUTORIAL_DONE` |
| `SCN_A08` | `CAMPEONATO_SELECIONADO` | I | `CHAMPIONSHIP_TUTORIAL_DONE` |
| `SCN_A09` | `ABA:LICENCAS` | I | `ADRIAN_LICENSE_CONTEXT` |
| `SCN_A10` | `CORRIDA_FIM` | I | `CHAMPIONSHIP_CLOSED_TALK` |
| `SCN_A11` | `ULTIMA_CORRIDA_ADRIAN` | I | `LAST_RACE_STARTED` |
| `SCN_A12` | `RADIO_ULTIMA_CORRIDA` | I | — |
| `SCN_A13` | `ACIDENTE` | I | `ADRIAN_DEAD`, `ADRIAN_CAR_DESTROYED` |
| `SCN_B01` | `ENCADEADA` | II | `EMPTY_GARAGE_SEEN` |
| `SCN_B02` | `ENCADEADA` | II | — |
| `SCN_B03` | `ENCADEADA` | II | `ELENA_RETURNED` |
| `SCN_B04` | `ENCADEADA` | II | `SECOND_CHANCE_UNLOCKED`, `WORLD_EXPLAINED` |
| `SCN_C01` | `ABA:LOJA` | III | `USED_DEALER_INTRO_SEEN` |
| `SCN_C02` | `COMPRA_CARRO` | III | `ELENA_FIRST_CAR_BOUGHT` |
| `SCN_D01` | `LICENCA_EXIGIDA` | IV | `LICENSE_SYSTEM_UNLOCKED` |
| `SCN_D02` | `ABA:LICENCAS` | IV | `LICENSE_OFFLINE_TUTORIAL_SEEN`, `LICENSE_SYSTEM_UNLOCKED` |
| `SCN_D03` | `LICENCA_TREINO_INICIO` | IV | `FIRST_TRAINING_STARTED` |
| `SCN_D04` | `LICENCA_PRONTA` | IV | `FIRST_TRAINING_READY` |
| `SCN_D05` | `LICENCA_CONCEDIDA:CLUB` | IV | `ELENA_CLUB_COMPLETE` |
| `SCN_E01` | `CORRIDA_INICIO` | V | `ELENA_FIRST_OFFICIAL_RACE` |
| `SCN_E02` | `CORRIDA_FIM` | V | `ELENA_FIRST_RACE_DONE` |
| `SCN_E03` | `CORRIDA_FIM` | V | `ELENA_FIRST_WIN`, `ELENA_FIRST_RACE_DONE` |
| `SCN_F01` | `LICENCA_DISPONIVEL:SPORT` | VI | `SPORT_AVAILABLE_SEEN` |
| `SCN_F03` | `LICENCA_CONCEDIDA:SPORT` | VI | `ELENA_SPORT_COMPLETE` |
| `SCN_G02` | `GARAGEM_DOIS_CARROS` | VII | `FIRST_SECOND_CAR` |
| `SCN_G03` | `CAMPEONATO_VENCIDO` | VII | `MEDIA_COMPARISON_STARTED` |
| `SCN_H01` | `CORRIDA_CONTRA:lucas_ward` | VIII | `LUCAS_MET` |
| `SCN_H02` | `CORRIDA_CONTRA:lucas_ward` | VIII | `LUCAS_AFTER_RACE` |
| `SCN_H03` | `LICENCA_CONCEDIDA:NATIONAL` | VIII | `VICTOR_MET` |
| `SCN_I03` | `LICENCA_CONCEDIDA:INTERNATIONAL` | IX | `ELENA_INTERNATIONAL_COMPLETE` |
| `SCN_J01` | `ENCADEADA` | X | `VICTOR_OFFER_REFUSED` |
| `SCN_K01` | `ENCADEADA` | XI | `SECOND_DRIVER_CREATED` |
| `SCN_L01` | `ABA:EQUIPE` | XII | `SOPHIE_MET` |
| `SCN_M01` | `LICENCA_DISPONIVEL:PRO` | XIII | `PRO_AVAILABLE_SEEN` |
| `SCN_M03` | `LICENCA_CONCEDIDA:PRO` | XIII | `PRO_COMPLETE` |
| `SCN_N01` | `ENCADEADA` | XIV | `DRIVER_HIRE_UNLOCKED` |
| `SCN_N02` | `ENCADEADA` | XIV | `SECOND_DRIVER_SECOND_CAR` |
| `SCN_P01` | `LICENCA_DISPONIVEL:ELITE` | XVI | `ELITE_AVAILABLE` |
| `SCN_P03` | `LICENCA_CONCEDIDA:ELITE` | XVI | `ELITE_COMPLETE` |
| `SYS_01` | `SEM_DINHEIRO` | — | — |
| `SYS_02` | `EVENTO_BLOQUEADO` | — | — |
| `SYS_04` | `POTENCIA_ACIMA` | — | — |
| `SYS_09` | `LICENCA_EM_TREINO` | — | — |
| `SYS_10` | `LICENCA_PRONTA` | — | — |
| `SYS_07` | `COMPRA_CARRO_NOVO` | — | `FIRST_NEW_CAR` |
| `SYS_ENDURANCE` | `CORRIDA_RESISTENCIA` | — | `FIRST_ENDURANCE` |

## Triggers usados pelas cenas

`ABA:EQUIPE`, `ABA:EVENTOS`, `ABA:LICENCAS`, `ABA:LOJA`, `ACIDENTE`, `CAMPEONATO_SELECIONADO`, `CAMPEONATO_VENCIDO`, `COMPRA_CARRO`, `COMPRA_CARRO_NOVO`, `CORRIDA_CONTRA:lucas_ward`, `CORRIDA_FIM`, `CORRIDA_INICIO`, `CORRIDA_RESISTENCIA`, `DEMANDA_CONCLUIDA`, `ENCADEADA`, `EVENTO_BLOQUEADO`, `EVENTO_SELECIONADO`, `EVOLUCAO`, `GAME_START`, `GARAGEM_DOIS_CARROS`, `LEMBRETE`, `LICENCA_CONCEDIDA:CLUB`, `LICENCA_CONCEDIDA:ELITE`, `LICENCA_CONCEDIDA:INTERNATIONAL`, `LICENCA_CONCEDIDA:NATIONAL`, `LICENCA_CONCEDIDA:PRO`, `LICENCA_CONCEDIDA:SPORT`, `LICENCA_DISPONIVEL:ELITE`, `LICENCA_DISPONIVEL:PRO`, `LICENCA_DISPONIVEL:SPORT`, `LICENCA_EM_TREINO`, `LICENCA_EXIGIDA`, `LICENCA_PRONTA`, `LICENCA_TREINO_INICIO`, `POTENCIA_ACIMA`, `RADIO_ULTIMA_CORRIDA`, `SEM_DINHEIRO`, `ULTIMA_CORRIDA_ADRIAN`

## Ações de tutorial (TutorialAction)

`CENARIO:garagem_vazia`, `CLARO`, `ESCURO`, `HIGHLIGHT_BRAKES`, `HIGHLIGHT_CAMERA_AUTO`, `HIGHLIGHT_COMPETITIVIDADE`, `HIGHLIGHT_COPA`, `HIGHLIGHT_DEMANDA`, `HIGHLIGHT_DISPUTAR`, `HIGHLIGHT_ETAPAS`, `HIGHLIGHT_FREIOS`, `HIGHLIGHT_LICENCA_SPORT`, `HIGHLIGHT_LICENSE_REQUIREMENTS`, `HIGHLIGHT_LIC_ELITE`, `HIGHLIGHT_LIC_NATIONAL`, `HIGHLIGHT_LIC_SPORT`, `HIGHLIGHT_NAV_EVENTOS`, `HIGHLIGHT_PESO`, `HIGHLIGHT_PNEUS`, `HIGHLIGHT_POTENCIA`, `HIGHLIGHT_SALDO`, `HIGHLIGHT_USED_CAR_STATS`, `ILUSTRACAO:acidente`, `ILUSTRACAO:adrian_entra_no_carro`, `ILUSTRACAO:box_depois_da_corrida`, `ILUSTRACAO:capacete_na_bancada`, `ILUSTRACAO:elena_na_porta`, `ILUSTRACAO:elite`, `ILUSTRACAO:garagem_trio`, `ILUSTRACAO:licenca_club`, `ILUSTRACAO:marcus_e_o_carro`, `ILUSTRACAO:placa_second_driver`, `OPEN_DEALERSHIP`, `OPEN_DRIVER_HIRE`, `OPEN_GARAGE_TAB`, `OPEN_LICENSE_CENTER`, `OPEN_TEAM_FINANCE`, `OPEN_TUNE_SERVICE`, `PAUSA`, `RETURN_TO_GARAGE`, `SALTO_TEMPORAL`, `TREMOR`, `UNLOCK_TEAM_TAB`

## Flags de história

| flag | primeira origem |
|---|---|
| `ADRIAN_CAR_DESTROYED` | cena SCN_A13 |
| `ADRIAN_DEAD` | cena SCN_A13 |
| `ADRIAN_LICENSE_CONTEXT` | cena SCN_A09 |
| `CHAMPIONSHIP_CLOSED_TALK` | cena SCN_A10 |
| `CHAMPIONSHIP_TUTORIAL_DONE` | cena SCN_A04 |
| `DRIVER_HIRE_UNLOCKED` | cena SCN_N01 |
| `ELENA_CLUB_COMPLETE` | cena SCN_D05 |
| `ELENA_FIRST_CAR_BOUGHT` | cena SCN_C02 |
| `ELENA_FIRST_OFFICIAL_RACE` | cena SCN_E01 |
| `ELENA_FIRST_RACE_DONE` | cena SCN_E02 |
| `ELENA_FIRST_WIN` | cena SCN_E03 |
| `ELENA_INTERNATIONAL_COMPLETE` | cena SCN_I03 |
| `ELENA_RETURNED` | cena SCN_B03 |
| `ELENA_SPORT_COMPLETE` | cena SCN_F03 |
| `ELITE_AVAILABLE` | cena SCN_P01 |
| `ELITE_COMPLETE` | cena SCN_P03 |
| `EMPTY_GARAGE_SEEN` | cena SCN_B01 |
| `EVENT_MENU_TUTORIAL_SEEN` | cena SCN_A04 |
| `EVENT_REQUIREMENTS_TUTORIAL_DONE` | cena SCN_A07 |
| `FIRST_CHAMPIONSHIP_DONE` | condição de SCN_A10 |
| `FIRST_ENDURANCE` | cena SYS_ENDURANCE |
| `FIRST_NEW_CAR` | cena SYS_07 |
| `FIRST_RACE_BRIEFED` | condição de SCN_A04L |
| `FIRST_RACE_DONE` | cena SCN_A06 |
| `FIRST_SECOND_CAR` | cena SCN_G02 |
| `FIRST_TRAINING_READY` | cena SCN_D04 |
| `FIRST_TRAINING_STARTED` | cena SCN_D03 |
| `FIRST_TUNE_DONE` | condição de SCN_A01L |
| `FIRST_WIN_ADRIAN` | cena SCN_A06 |
| `GARAGE_TUTORIAL_SEEN` | cena SCN_A01 |
| `LAST_RACE_STARTED` | condição de SCN_A10 |
| `LICENSE_OFFLINE_TUTORIAL_SEEN` | cena SCN_D02 |
| `LICENSE_SYSTEM_UNLOCKED` | cena SCN_D01 |
| `LUCAS_AFTER_RACE` | cena SCN_H02 |
| `LUCAS_MET` | cena SCN_H01 |
| `MEDIA_COMPARISON_STARTED` | cena SCN_G03 |
| `PRO_AVAILABLE_SEEN` | cena SCN_M01 |
| `PRO_COMPLETE` | cena SCN_M03 |
| `SECOND_CHANCE_UNLOCKED` | cena SCN_B04 |
| `SECOND_DRIVER_CREATED` | cena SCN_K01 |
| `SECOND_DRIVER_SECOND_CAR` | cena SCN_N02 |
| `SOPHIE_MET` | cena SCN_L01 |
| `SPORT_AVAILABLE_SEEN` | cena SCN_F01 |
| `STORY_STARTED` | cena SCN_A00 |
| `TUNE_TUTORIAL_SEEN` | condição de SCN_A01L |
| `USED_DEALER_INTRO_SEEN` | cena SCN_C01 |
| `VICTOR_MET` | cena SCN_H03 |
| `VICTOR_OFFER_REFUSED` | cena SCN_J01 |
| `VOLTA_ABERTURA` | ui/principal.gd |
| `WORLD_EXPLAINED` | cena SCN_B04 |

## Licenças (`data/licencas.json`)

| id | nome | GT2 |
|---|---|---|
| `CLUB` | Licença Club | B |
| `SPORT` | Licença Sport | A |
| `NATIONAL` | Licença National | IC |
| `INTERNATIONAL` | Licença International | IB |
| `PRO` | Licença Pro | IA |
| `ELITE` | Licença Elite | S |

## Equipes e pilotos (`data/equipes.json`)

| equipe | nível | pilotos |
|---|---|---|
| `eq01_second_driver` Second Driver | jogador | `elena_cross`, `adrian_cross` |
| `eq02_vortex_motorsport` Vortex Motorsport | PRO | `lucien_vale`, `mara_voss` |
| `eq03_kaze_dynamics` Kaze Dynamics | INTERNATIONAL | `ren_kaito`, `hana_mori` |
| `eq04_ironclad_racing` Ironclad Racing | NATIONAL | `bram_holt`, `soren_pike` |
| `eq05_apex_dominion` Apex Dominion | ELITE | `lucas_ward`, `cassian_roe`, `nyra_sol` |
| `eq06_redline_union` Redline Union | SPORT | `dario_kest` (provisório), `lena_brook` (provisório) |
| `eq07_northstar_works` Northstar Works | INTERNATIONAL | `erik_halden`, `liv_arnesen` (provisório) |
| `eq08_black_circuit` Black Circuit | NATIONAL | `marek_stone` (provisório), `ivy_corran` (provisório) |
| `eq09_helix_racing` Helix Racing | NATIONAL | `tomas_reyl` (provisório), `sasha_imre` (provisório) |
| `eq10_ember_works` Ember Works | CLUB | `gus_harrow` (provisório), `pia_lund` (provisório) |
| `eq11_white_fang_racing` White Fang Racing | INTERNATIONAL | `viktor_ren`, `yuna_kess` |
| `eq12_brassline_motorsport` Brassline Motorsport | CLUB | `oscar_flint`, `mina_rowe` |
| `eq13_tempest_garage` Tempest Garage | SPORT | `noel_mercer`, `zara_keene` |
| `eq14_crown_vector` Crown Vector | PRO | `elias_wren`, `celeste_armand` |
| `eq15_gravelborn` Gravelborn | CLUB | `rafe_calder`, `nika_stroud` |
| `eq16_meridian_gp` Meridian GP | ELITE | `theo_maren`, `selene_ward` |
| `eq17_obsidian_crest` Obsidian Crest | ELITE | `magnus_rell`, `ines_vale` |
| `eq18_copperhead_racing` Copperhead Racing | CLUB | `ash_mercer`, `cleo_vane` |
| `eq19_cold_harbor` Cold Harbor | SPORT | `finn_sutter`, `kaia_rehn` |
| `eq20_storm_division` Storm Division | PRO | `rex_arden`, `mira_holt` |

Segundo piloto da equipe do jogador: `jonas_reid` (Jonas Reid, provisório).

## Cenários de teste (`data_model/cenarios.gd`)

| id | nome |
|---|---|
| `adrian_inicio` | Adrian: começo |
| `adrian_ultima` | Adrian: antes da última corrida |
| `elena_inicio` | Elena: depois do acidente |
| `elena_primeira_compra` | Elena: primeiro carro |
| `second_driver` | Second Driver criada |
| `segundo_piloto` | Segundo piloto na equipe |
