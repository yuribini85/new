# IDs do jogo

Gerado por `tools/listar_ids.py` a partir de `data/` e do código. Não editar à mão.

## Personagens (`data/personagens.json`)

| id | nome |
|---|---|
| `mara` | Mara Hayes |
| `piloto_casa` | Theo Lane |
| `dono` |  |
| `examinador` | Harold Brandt |
| `manobrista` | Rico Salas |
| `mecanico_arena` | Dex Kane |
| `organizadora` | Roxy Vega |
| `pintor` | Kenji Arata |
| `vendedor_charge_folio` | Edgar Halloway |
| `vendedor_relay_room` | Sal Moretti |
| `vendedora_brace_yard` | Bianca Sterling |
| `vendedora_return_chapter` | Nora Lindqvist |
| `vendedora_shared_grid` | Jade Ryker |
| `vendedor_spare_penny` | Walt Pruitt |
| `sistema` |  |

## Cenas (`data/dialogos.json`, de `tools/historia/cenas.txt`)

| id | trigger | capítulo | grava |
|---|---|---|---|
| `CW_P01` | `GAME_START` | — | `STORY_STARTED`, `TUTORIAL_INTRO_SEEN` |
| `CW_P01B` | `NOME_DEFINIDO` | — | `ADMIN_NAMED` |
| `CW_P02` | `ENCADEADA` | — | `GARAGE_TUTORIAL_SEEN` |
| `CW_P02L` | `LEMBRETE` | — | — |
| `CW_P03` | `EVOLUCAO` | — | `TUNE_TUTORIAL_SEEN` |
| `CW_P03L` | `LEMBRETE` | — | — |
| `CW_P03B` | `DEMANDA_CONCLUIDA` | — | `FIRST_TUNE_DONE` |
| `CW_P06C` | `CORRIDA_FIM` | — | `SECOND_RACE_DONE` |
| `CW_P03C` | `ABA:EQUIPE` | — | — |
| `CW_P03D` | `PILOTO_CONTRATADO` | — | `PILOT_HIRED`, `PILOT_MET` |
| `CW_P04` | `ABA:EVENTOS` | — | `EVENT_MENU_TUTORIAL_SEEN` |
| `CW_P04L` | `LEMBRETE` | — | — |
| `CW_C01` | `CAMPEONATO_SELECIONADO` | — | `CHAMPIONSHIP_TUTORIAL_DONE` |
| `CW_P05` | `CORRIDA_INICIO` | — | `FIRST_RACE_BRIEFED` |
| `CW_P05C` | `CORRIDA_EM_CURSO` | — | `CAMERA_TUTORIAL_SEEN` |
| `CW_P06` | `CORRIDA_FIM` | — | `FIRST_RACE_DONE`, `FIRST_WIN` |
| `CW_P06B` | `CORRIDA_FIM` | — | `FIRST_RACE_DONE` |
| `CW_P06D` | `CORRIDA_FIM` | — | — |
| `CW_E01` | `EVENTO_BLOQUEADO` | — | `EVENT_REQUIREMENTS_TUTORIAL_DONE` |
| `CW_AD01` | `CORRIDA_FIM` | — | `ARENA_DEMO_SEEN` |
| `CW_AD02` | `ARENA_DEMO_FIM` | — | `ARENA_DEMO_TALK` |
| `CW_L01` | `LICENCA_EXIGIDA` | — | `LICENSE_SYSTEM_UNLOCKED` |
| `CW_L02` | `ABA:LICENCAS` | — | `LICENSE_OFFLINE_TUTORIAL_SEEN`, `LICENSE_SYSTEM_UNLOCKED` |
| `CW_GR00` | `ENCADEADA` | — | `GRID_INTRO` |
| `CW_C00` | `ENCADEADA` | — | — |
| `CW_C01B` | `COMPRA_CARRO` | — | `FIRST_CAR` |
| `CW_L03` | `LICENCA_TREINO_INICIO` | — | `FIRST_TRAINING_STARTED` |
| `CW_L05` | `LICENCA_DISPONIVEL:SPORT` | — | `SPORT_AVAILABLE_SEEN` |
| `CW_L06` | `LICENCA_DISPONIVEL:NATIONAL` | — | `NATIONAL_AVAILABLE_SEEN` |
| `CW_R10` | `LICENCA_CONCEDIDA:CLUB` | — | `CLUB_COMPLETE` |
| `CW_S00` | `CORRIDA_FIM` | — | `PATROCINIO_INTRO`, `PATROCINIO_LIBERADO` |
| `CW_R10B` | `LICENCA_CONCEDIDA:SPORT` | — | `SPORT_COMPLETE` |
| `CW_R10C` | `LICENCA_CONCEDIDA:NATIONAL` | — | `NATIONAL_COMPLETE` |
| `CW_T01` | `LICENCA_CONCEDIDA:INTERNATIONAL` | — | `INTERNATIONAL_COMPLETE`, `GESTAO_LIBERADA` |
| `CW_T02` | `LICENCA_CONCEDIDA:PRO` | — | `PRO_COMPLETE` |
| `CW_T03` | `LICENCA_CONCEDIDA:ELITE` | — | `ELITE_COMPLETE` |
| `CW_GR06` | `GRID_SUBIU` | — | `MARA_PASSADO` |
| `CW_GR01` | `GRID_SUBIU` | — | — |
| `CW_GR02` | `GRID_TOPO` | — | `GRID_TOP` |
| `CW_SYS11` | `SEM_PECAS` | — | — |
| `CW_R02` | `CORRIDA_FIM` | — | `FIRST_WIN` |
| `CW_F01` | `FILA_INICIADA` | — | `FIRST_QUEUE` |
| `CW_G01` | `GARAGEM_DOIS_CARROS` | — | `FIRST_SECOND_CAR` |
| `CW_G02` | `CAMPEONATO_VENCIDO` | — | `FIRST_TITLE_TALK` |
| `CW_R11` | `COLECAO` | — | `COLLECTION_FIVE` |
| `CW_R12` | `GARAGEM_AMPLIADA` | — | `GARAGE_EXPANDED` |
| `CW_M01` | `VITORIA_LICENCA:CLUB` | — | `FIRST_CLUB_WIN` |
| `CW_M02` | `VITORIA_LICENCA:SPORT` | — | `FIRST_SPORT_WIN` |
| `CW_M03` | `VITORIA_LICENCA:NATIONAL` | — | `FIRST_NATIONAL_WIN` |
| `CW_M00` | `VITORIA` | — | `FIVE_WINS` |
| `CW_M04` | `VITORIA` | — | `TEN_WINS` |
| `CW_M05` | `VITORIA` | — | `TWENTY_FIVE_WINS` |
| `CW_M06` | `VITORIA` | — | `FIFTY_WINS` |
| `CW_M07` | `VITORIA` | — | `HUNDRED_WINS` |
| `CW_P07` | `GARAGEM_TRES_CARROS` | — | `ARENA_INTRO` |
| `CW_AR02` | `ENCADEADA` | — | `DEX_MET` |
| `CW_AR03` | `BLINDAGEM` | — | `ARMOR_TUTORIAL_SEEN` |
| `CW_AR04` | `BLINDAGEM_COMPRADA` | — | `FIRST_ARMOR` |
| `CW_R06` | `ARENA_INSCRICAO` | — | `ARENA_FIRST_ENTRY` |
| `CW_R07` | `ARENA_FIM` | — | `ARENA_SURVIVED` |
| `CW_A01` | `ARENA_VITORIA` | — | `ARENA_FIRST_WIN` |
| `CW_R09` | `ARENA_PERDA` | — | `ARENA_FIRST_LOSS` |
| `CW_R09B` | `ARENA_PERDA` | — | — |
| `CW_S01` | `ABA:EQUIPE` | — | `PATROCINIO_INTRO` |
| `CW_S02` | `PATROCINIO_ASSINADO` | — | `FIRST_SPONSOR` |
| `CW_S03` | `CARRO_DESMONTADO` | — | `FIRST_DISMANTLE` |
| `CW_S05` | `TREINO_CONCLUIDO` | — | `FIRST_TRAINING_LEVEL` |
| `CW_S04` | `SEDE_MELHORADA` | — | `FIRST_HQ_UPGRADE` |
| `CW_GA01` | `GARAGEM_ABERTA` | — | `GARAGE_WINDOW_SEEN` |
| `CW_PT01` | `PINTURA` | — | `PAINT_TUTORIAL_SEEN` |
| `CW_PT02` | `PINTURA_APLICADA` | — | `FIRST_PAINT` |
| `CW_PT03` | `PINTURA_APLICADA` | — | — |
| `CW_LJ01` | `LOJA:charge_folio_motors` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_CHARGE_FOLIO` |
| `CW_LJ02` | `LOJA:charge_folio_motors` | — | `SHOP_CHARGE_FOLIO` |
| `CW_LJ03` | `LOJA:relay_room_garage` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_RELAY_ROOM` |
| `CW_LJ04` | `LOJA:relay_room_garage` | — | `SHOP_RELAY_ROOM` |
| `CW_LJ05` | `LOJA:brace_yard_works` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_BRACE_YARD` |
| `CW_LJ06` | `LOJA:brace_yard_works` | — | `SHOP_BRACE_YARD` |
| `CW_LJ07` | `LOJA:return_chapter_customs` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_RETURN_CHAPTER` |
| `CW_LJ08` | `LOJA:return_chapter_customs` | — | `SHOP_RETURN_CHAPTER` |
| `CW_LJ09` | `LOJA:shared_grid_motors` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_SHARED_GRID` |
| `CW_LJ10` | `LOJA:shared_grid_motors` | — | `SHOP_SHARED_GRID` |
| `CW_LJ11` | `LOJA:spare_penny_repairs` | — | `SHOP_TUTORIAL_SEEN`, `SHOP_SPARE_PENNY` |
| `CW_LJ12` | `LOJA:spare_penny_repairs` | — | `SHOP_SPARE_PENNY` |
| `CW_R01` | `CORRIDA_FIM` | — | `FIRST_LOSS_TALK` |
| `CW_D01` | `CORRIDA_FIM` | — | — |
| `CW_D02` | `CORRIDA_FIM` | — | — |
| `CW_D03` | `CORRIDA_FIM` | — | — |
| `CW_D04` | `CORRIDA_FIM` | — | — |
| `CW_D05` | `CORRIDA_FIM` | — | — |
| `CW_D06` | `CORRIDA_FIM` | — | — |
| `CW_D07` | `CORRIDA_FIM` | — | — |
| `CW_D08` | `CORRIDA_FIM` | — | — |
| `CW_D09` | `CORRIDA_FIM` | — | — |
| `CW_D10` | `CORRIDA_FIM` | — | — |
| `CW_D14` | `CORRIDA_FIM` | — | — |
| `CW_D15` | `CORRIDA_FIM` | — | — |
| `CW_D16` | `CORRIDA_FIM` | — | — |
| `CW_D17` | `CORRIDA_FIM` | — | — |
| `CW_D18` | `CORRIDA_FIM` | — | — |
| `CW_D19` | `CORRIDA_FIM` | — | — |
| `CW_D11` | `PECA_COMPRADA` | — | — |
| `CW_D12` | `PECA_COMPRADA` | — | — |
| `CW_D13` | `PECA_COMPRADA` | — | — |
| `CW_R03` | `CAIXA_BAIXO` | — | — |
| `CW_R04` | `COMPRA_CARRO_CARA` | — | — |
| `CW_SYS01` | `SEM_DINHEIRO` | — | — |
| `CW_SYS02` | `EVENTO_BLOQUEADO` | — | — |
| `CW_SYS_ENDURANCE` | `CORRIDA_RESISTENCIA` | — | `FIRST_ENDURANCE` |

## Triggers usados pelas cenas

`ABA:EQUIPE`, `ABA:EVENTOS`, `ABA:LICENCAS`, `ARENA_DEMO_FIM`, `ARENA_FIM`, `ARENA_INSCRICAO`, `ARENA_PERDA`, `ARENA_VITORIA`, `BLINDAGEM`, `BLINDAGEM_COMPRADA`, `CAIXA_BAIXO`, `CAMPEONATO_SELECIONADO`, `CAMPEONATO_VENCIDO`, `CARRO_DESMONTADO`, `COLECAO`, `COMPRA_CARRO`, `COMPRA_CARRO_CARA`, `CORRIDA_EM_CURSO`, `CORRIDA_FIM`, `CORRIDA_INICIO`, `CORRIDA_RESISTENCIA`, `DEMANDA_CONCLUIDA`, `ENCADEADA`, `EVENTO_BLOQUEADO`, `EVOLUCAO`, `FILA_INICIADA`, `GAME_START`, `GARAGEM_ABERTA`, `GARAGEM_AMPLIADA`, `GARAGEM_DOIS_CARROS`, `GARAGEM_TRES_CARROS`, `GRID_SUBIU`, `GRID_TOPO`, `LEMBRETE`, `LICENCA_CONCEDIDA:CLUB`, `LICENCA_CONCEDIDA:ELITE`, `LICENCA_CONCEDIDA:INTERNATIONAL`, `LICENCA_CONCEDIDA:NATIONAL`, `LICENCA_CONCEDIDA:PRO`, `LICENCA_CONCEDIDA:SPORT`, `LICENCA_DISPONIVEL:NATIONAL`, `LICENCA_DISPONIVEL:SPORT`, `LICENCA_EXIGIDA`, `LICENCA_TREINO_INICIO`, `LOJA:brace_yard_works`, `LOJA:charge_folio_motors`, `LOJA:relay_room_garage`, `LOJA:return_chapter_customs`, `LOJA:shared_grid_motors`, `LOJA:spare_penny_repairs`, `NOME_DEFINIDO`, `PATROCINIO_ASSINADO`, `PECA_COMPRADA`, `PILOTO_CONTRATADO`, `PINTURA`, `PINTURA_APLICADA`, `SEDE_MELHORADA`, `SEM_DINHEIRO`, `SEM_PECAS`, `TREINO_CONCLUIDO`, `VITORIA`, `VITORIA_LICENCA:CLUB`, `VITORIA_LICENCA:NATIONAL`, `VITORIA_LICENCA:SPORT`

## Ações de tutorial (TutorialAction)

`ARENA_DEMO`, `CENARIO:oficina_mara`, `HIGHLIGHT_ACELERAR`, `HIGHLIGHT_CAMERA_AUTO`, `HIGHLIGHT_COMPETITIVIDADE`, `HIGHLIGHT_COPA`, `HIGHLIGHT_DEMANDA`, `HIGHLIGHT_DISPUTAR`, `HIGHLIGHT_FREIOS`, `HIGHLIGHT_GRID`, `HIGHLIGHT_LICENSE_REQUIREMENTS`, `HIGHLIGHT_NAV_EQUIPE`, `HIGHLIGHT_NAV_EVENTOS`, `HIGHLIGHT_NAV_LICENCAS`, `HIGHLIGHT_NAV_LOJA`, `HIGHLIGHT_PATROCINIO`, `HIGHLIGHT_PECA_PEDIDA`, `HIGHLIGHT_PESO`, `HIGHLIGHT_PILOTO_CORRIDA`, `HIGHLIGHT_PNEUS`, `HIGHLIGHT_POTENCIA`, `HIGHLIGHT_SALDO`, `ILUSTRACAO:chegada`, `ILUSTRACAO:noite_da_arena`, `IMPACTO`, `OPEN_GARAGE_TAB`, `OPEN_LICENSE_CENTER`, `OPEN_TEAM_FINANCE`, `PAUSA`, `PEDIR_NOME`, `UNLOCK_ACELERAR`, `UNLOCK_ARENA_PILOTS`, `UNLOCK_TEAM_TAB`

## Flags de história

| flag | primeira origem |
|---|---|
| `ABERTURA_DONO` | data_model/cenarios.gd |
| `ACELERAR_LIBERADO` | ui/principal.gd |
| `ADMIN_NAMED` | cena CW_P01B |
| `ARENA_DEMO_SEEN` | cena CW_AD01 |
| `ARENA_DEMO_TALK` | cena CW_AD02 |
| `ARENA_FIRST_ENTRY` | cena CW_R06 |
| `ARENA_FIRST_LOSS` | cena CW_R09 |
| `ARENA_FIRST_WIN` | cena CW_A01 |
| `ARENA_INTRO` | cena CW_P07 |
| `ARENA_PILOTS_UNLOCKED` | data_model/equipe_jogador.gd |
| `ARENA_SURVIVED` | cena CW_R07 |
| `ARMOR_TUTORIAL_SEEN` | cena CW_AR03 |
| `CAMERA_TUTORIAL_SEEN` | cena CW_P05C |
| `CARRO_MARA` | data_model/prologo.gd |
| `CHAMPIONSHIP_TUTORIAL_DONE` | cena CW_C01 |
| `CLUB_COMPLETE` | cena CW_R10 |
| `COLLECTION_FIVE` | cena CW_R11 |
| `DEX_MET` | cena CW_AR02 |
| `DRIVER_HIRE_UNLOCKED` | data_model/equipe_jogador.gd |
| `ELITE_COMPLETE` | cena CW_T03 |
| `EVENT_MENU_TUTORIAL_SEEN` | cena CW_P04 |
| `EVENT_REQUIREMENTS_TUTORIAL_DONE` | cena CW_E01 |
| `FIFTY_WINS` | cena CW_M06 |
| `FIRST_ARMOR` | cena CW_AR04 |
| `FIRST_CAR` | condição de CW_P03C |
| `FIRST_CLUB_WIN` | cena CW_M01 |
| `FIRST_DISMANTLE` | cena CW_S03 |
| `FIRST_ENDURANCE` | cena CW_SYS_ENDURANCE |
| `FIRST_HQ_UPGRADE` | cena CW_S04 |
| `FIRST_LOSS_TALK` | cena CW_R01 |
| `FIRST_NATIONAL_WIN` | cena CW_M03 |
| `FIRST_PAINT` | cena CW_PT02 |
| `FIRST_QUEUE` | cena CW_F01 |
| `FIRST_RACE_BRIEFED` | condição de CW_P04L |
| `FIRST_RACE_DONE` | condição de CW_C01 |
| `FIRST_SECOND_CAR` | cena CW_G01 |
| `FIRST_SPONSOR` | cena CW_S02 |
| `FIRST_SPORT_WIN` | cena CW_M02 |
| `FIRST_TITLE_TALK` | cena CW_G02 |
| `FIRST_TRAINING_LEVEL` | cena CW_S05 |
| `FIRST_TRAINING_STARTED` | cena CW_L03 |
| `FIRST_TUNE_DONE` | condição de CW_P02L |
| `FIRST_WIN` | cena CW_P06 |
| `FIVE_WINS` | cena CW_M00 |
| `GARAGE_EXPANDED` | cena CW_R12 |
| `GARAGE_TUTORIAL_SEEN` | cena CW_P02 |
| `GARAGE_WINDOW_SEEN` | cena CW_GA01 |
| `GESTAO_LIBERADA` | cena CW_T01 |
| `GRID_INTRO` | cena CW_GR00 |
| `GRID_TOP` | cena CW_GR02 |
| `HUNDRED_WINS` | cena CW_M07 |
| `INTERNATIONAL_COMPLETE` | cena CW_T01 |
| `LICENSE_OFFLINE_TUTORIAL_SEEN` | cena CW_L02 |
| `LICENSE_SYSTEM_UNLOCKED` | cena CW_L01 |
| `MARA_PASSADO` | cena CW_GR06 |
| `NATIONAL_AVAILABLE_SEEN` | cena CW_L06 |
| `NATIONAL_COMPLETE` | cena CW_R10C |
| `PACK_PREMIUM` | data_model/equipe_jogador.gd |
| `PAINT_TUTORIAL_SEEN` | cena CW_PT01 |
| `PATROCINIO_INTRO` | cena CW_S00 |
| `PATROCINIO_LIBERADO` | cena CW_S00 |
| `PILOT_HIRED` | condição de CW_P03C |
| `PILOT_MET` | cena CW_P03D |
| `PRIMEIRO_PILOTO_CONTRATADO` | data_model/equipe_jogador.gd |
| `PRO_COMPLETE` | cena CW_T02 |
| `SECOND_DRIVER_CREATED` | data_model/equipe_jogador.gd |
| `SECOND_RACE_DONE` | cena CW_P06C |
| `SHOP_BRACE_YARD` | cena CW_LJ05 |
| `SHOP_CHARGE_FOLIO` | cena CW_LJ01 |
| `SHOP_RELAY_ROOM` | cena CW_LJ03 |
| `SHOP_RETURN_CHAPTER` | cena CW_LJ07 |
| `SHOP_SHARED_GRID` | cena CW_LJ09 |
| `SHOP_SPARE_PENNY` | cena CW_LJ11 |
| `SHOP_TUTORIAL_SEEN` | cena CW_LJ01 |
| `SPORT_AVAILABLE_SEEN` | cena CW_L05 |
| `SPORT_COMPLETE` | cena CW_R10B |
| `STORY_STARTED` | cena CW_P01 |
| `TEN_WINS` | cena CW_M04 |
| `TUNE_TUTORIAL_SEEN` | condição de CW_P02L |
| `TUTORIAL_INTRO_SEEN` | cena CW_P01 |
| `TUTORIAL_PULADO` | data_model/tutorial.gd |
| `TWENTY_FIVE_WINS` | cena CW_M05 |

## Licenças (`data/licencas.json`)

| id | nome |
|---|---|
| `CLUB` | Licença Club |
| `SPORT` | Licença Sport |
| `NATIONAL` | Licença National |
| `INTERNATIONAL` | Licença International |
| `PRO` | Licença Pro |
| `ELITE` | Licença Elite |

## Equipes e pilotos (`data/equipes.json`)

| equipe | nível | pilotos |
|---|---|---|
| `eq01_second_driver` Wreckage Motorsport | jogador |  |
| `eq02_vortex_motorsport` Blackwater Racing | PRO | `lucien_vale`, `nadia_voss`, `akira_delacroix`, `beatriz_oyelaran` |
| `eq03_kaze_dynamics` Kaze Dynamics | INTERNATIONAL | `ren_kaito`, `hana_mori`, `dmitri_abernathy`, `esme_lindgren` |
| `eq04_ironclad_racing` Iron Vultures | NATIONAL | `bram_holt`, `soren_pike`, `felix_hakimi`, `greta_saarinen` |
| `eq05_apex_dominion` Apex Dominion | ELITE | `lucas_ward`, `cassian_roe`, `nyra_sol`, `hugo_esposito` |
| `eq06_redline_union` Redline Union | SPORT | `dario_kest` (provisório), `lena_brook` (provisório), `isadora_aldana`, `jasper_laurier` |
| `eq07_northstar_works` Midnight Relay | INTERNATIONAL | `erik_halden`, `liv_arnesen` (provisório), `katya_whitcombe`, `leon_iwata` |
| `eq08_black_circuit` Last Exit Club | NATIONAL | `marek_stone` (provisório), `ivy_corran` (provisório), `marisol_eriksen`, `nils_petrakis` |
| `eq09_helix_racing` Helix Racing | NATIONAL | `tomas_reyl` (provisório), `sasha_imre` (provisório), `odette_bastos`, `pablo_morrow` |
| `eq10_ember_works` Ember Works | CLUB | `gus_harrow` (provisório), `pia_lund` (provisório), `quinn_ishida`, `rafaela_takeda` |
| `eq11_white_fang_racing` White Fang Racing | INTERNATIONAL | `viktor_ren`, `yuna_kess`, `stellan_fairbanks`, `tamsin_bergstrom` |
| `eq12_brassline_motorsport` Brassline Motorsport | CLUB | `oscar_flint`, `mina_rowe`, `ulrich_marchetti`, `valentina_yamaguchi` |
| `eq13_tempest_garage` Blue Collar Syndicate | SPORT | `noel_mercer`, `zara_keene`, `wes_jaramillo`, `xenia_falcone` |
| `eq14_crown_vector` Hollow Saints | PRO | `elias_wren`, `celeste_armand`, `yusuf_quintero`, `zoe_coutinho` |
| `eq15_gravelborn` Redemption County | CLUB | `rafe_calder`, `nika_stroud`, `anders_nyberg`, `bianca_jovanovic` |
| `eq16_meridian_gp` Meridian GP | ELITE | `theo_maren`, `selene_ashby`, `cyrus_ulloa`, `dalia_grimaldi` |
| `eq17_obsidian_crest` Obsidian Crest | ELITE | `magnus_rell`, `ines_calloway`, `emil_castellan`, `fiona_nakamura` |
| `eq18_copperhead_racing` Copperhead Motors | CLUB | `ash_corwin`, `cleo_vane`, `gideon_zelenko`, `helga_kowal` |
| `eq19_cold_harbor` Cold Harbor | SPORT | `finn_sutter`, `kaia_rehn`, `ivo_galloway`, `juno_rasmussen` |
| `eq20_storm_division` Velvet Thunder | PRO | `rex_arden`, `mira_danvers`, `kenji_drummond`, `livia_okafor` |

Segundo piloto da equipe do jogador: `jonas_reid` (Hiro Sakuno).

## Cenários de teste (`data_model/cenarios.gd`)

| id | nome |
|---|---|
| `dono_inicio` | Oficina: começo |
| `dono_arena` | Oficina: arena aberta |
| `completo` | Teste completo |
