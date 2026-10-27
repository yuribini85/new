# Sons

Todos CC0 (domínio público, uso comercial livre, sem atribuição obrigatória),
da Kenney (kenney.nl), tirados dos starter kits publicados por ela no GitHub.
O README de cada kit declara os sons como CC0.

| Arquivo | Origem |
|---|---|
| motor.ogg | KenneyNL/Starter-Kit-Racing — audio/engine.ogg |
| pneu.ogg | KenneyNL/Starter-Kit-Racing — audio/skid.ogg |
| batida.ogg | KenneyNL/Starter-Kit-Racing — audio/impact.ogg |
| moeda.ogg | KenneyNL/Starter-Kit-3D-Platformer — sounds/coin.ogg |
| toque.ogg | KenneyNL/Starter-Kit-City-Builder — sounds/toggle.ogg |

Do **GDC Game Audio Bundle 2026, parte 9** (Sonniss, sonniss.com): royalty-free,
uso pessoal ou comercial sem atribuição (Readme e "License - GDC Game Audio.pdf" do
pacote). Cortados por `tools/preparar_sons.py` (os WAV originais ficam fora do
repositório):

| Arquivo | Origem |
|---|---|
| impacto.ogg | The Noisery, Moaning Metal — DSGNImpt_Metal Hit Thud Thump Low Ring Geofon 1 |
| raspagem.ogg | The Noisery, Moaning Metal — DSGNTonl_Metal Scrape Low Tonal LFE 4 |
| porta_abre.ogg, porta.ogg | SoundBits, Mad Mustang Mercury — VEHDoor_Car Foley Car Door Open and Close Exterior 04 Perspective A |
| oficina.ogg | Victor Ermakov, Ship Repair Factory — AMBInd_Factory Hall Busy Alarm Machines Voices |
| motor_grave.ogg | SoundBits, Mad Mustang Mercury — VEHCar_Various Driving at Slow Speed 15 06 (marcha lenta, 0–2,2 s) |
| ofegante.ogg | SoundBits, Vox Hominis — HMNBrth_Panting Male 02 04 |

Da **Mixkit** (mixkit.co), pela Mixkit Sound Effects Free License: uso em
projetos pessoais e comerciais, sem atribuição; proíbe só revender ou distribuir os
sons soltos. Cortados por `tools/preparar_sons.py`:

| Arquivo | Origem |
|---|---|
| torcida.ogg | Mixkit 462 — Huge crowd cheering victory |
| comemoracao.ogg | Mixkit 3022 — Stadium joy shouting crowd |
| passagem.ogg | Mixkit 1538 — Fast car drive by |
| explosao.ogg | Mixkit 1562 — Car explosion debris |
| parafusadeira.ogg | Mixkit 817 — Garage pneumatic screwer |

Da **Kenney**, CC0, pacote Interface Sounds (kenney.nl/assets/interface-sounds):

| Arquivo | Origem |
|---|---|
| erro.ogg | Audio/error_003.ogg |

Bipes da largada, ultrapassagem, chegada e zebra continuam gerados em código
(`visual/sons.gd`).

Da **Kenney** (kenney.nl), CC0, pacotes *Music Jingles* e *Interface Sounds*
(docs/idle/sonorizacao.md: família de recompensa, botão desativado e voz de conversa).
Os quatro jingles de recompensa foram escolhidos pelo contorno de tom que sobe:

| Arquivo | Origem |
|---|---|
| recompensa_1.ogg | Music Jingles — Sax jingles/jingles_SAX04 |
| recompensa_2.ogg | Music Jingles — Sax jingles/jingles_SAX10 |
| recompensa_3.ogg | Music Jingles — Sax jingles/jingles_SAX02 |
| recompensa_4.ogg | Music Jingles — Steel jingles/jingles_STEEL02 |
| nao.ogg | Interface Sounds — error_004 |
| voz.ogg | Interface Sounds — pluck_001 |

Gerados no projeto (sem fonte externa):

| Arquivo | Origem |
|---|---|
| musica_box.ogg | `tools/gerar_musica_crt.py`: laço provisório de funk lo-fi (90 BPM, 21 s), até a trilha definitiva |

## Música (The Fastfather)

Gravações de 1924 da **Wolverine Orchestra** (com Bix Beiderbecke), Gennett, gravadas em
6 de maio de 1924. Domínio público nos EUA desde 1º/1/2025 (Music Modernization Act:
gravações publicadas em 1924 entram 100 anos depois); as composições, de 1924, desde 2020.
Transferências dos discos de 78 rpm do Great 78 Project (archive.org). Cortadas no
silêncio, volume normalizado, mono 64 kbps.

| Arquivo | Faixa | Origem |
|---|---|---|
| jazz_1.ogg | Riverboat Shuffle (Carmichael) | archive.org/details/78_riverbeat-shuffle_wolverine-orchestra-carmichael_gbia0009181a |
| jazz_2.ogg | Copenhagen (Davis) | archive.org/details/78_copenhagen_wolverine-orchestra-davis_gbia0009180b |
| jazz_3.ogg | Oh! Baby (De Sylva, Donaldson) | archive.org/details/78_oh-baby_wolverine-orchestra-de-sylva-donaldson_gbia0009180a |

`musica_box.ogg` saiu da trilha do idle (fica para o outro jogo).

## Locutor de rádio (a gravar)

Se existirem, a corrida toca estes arquivos com o filtro de rádio: `locutor_largada.ogg`
(na largada), `locutor_vitoria.ogg` (vitória), `locutor_chegada.ogg` (chegada sem vitória).
Texto sugerido em `docs/idle/identidade_fastfather.md`.
