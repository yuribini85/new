# Chrome Racing Team: conversão máfia americana e automobilismo clássico (1946–1955)

Briefing de conversão v1.0 do usuário (2026-10-27). **Escopo fechado:** narrativa, visual e
nomenclatura. Não muda corrida, progressão, economia, melhorias, colisão nem arena (matriz do
briefing, item 9). Substitui a fantasia da Mara contra o Sal de `docs/idle/direcao.md`; a linguagem
da transmissão e o complexo da equipe continuam, com a cara da época.

## 1. Elenco (arquétipos originais; a arte do acervo é provisória até o usuário trocar)

| Personagem | Papel | Arte provisória |
|---|---|---|
| **Don Carmine Bellucci** | o chefe, financia a escuderia | `edgar_halloway` (terno com colete) |
| **Frankie Bellucci** | o sobrinho vaidoso, o piloto | `walt_pruitt` (terno bege) |
| **Sal Moretti** | chefe da família rival | `sal_moretti` |
| Mara Hayes | chefe dos mecânicos | `mara_hayes` |
| Theo Lane | piloto aposentado (ensina a ultrapassar) | `theo_lane` |
| Bianca Sterling | viúva rica (patrocínio) | `bianca_sterling` |
| Harold Brandt | comissário de prova (largada automática) | `harold_brandt` |
| Jade Ryker | agenciadora de pilotos | `jade_ryker` |
| Roxy Vega | diretora da emissora (TV) | `roxy_vega` |
| Rico Salas | gerente (missões) | `rico_salas` |
| Nora Lindqvist | contadora da família (analista) | `nora_lindqvist` |
| Kenji Arata | cinegrafista (câmeras) | `kenji_arata` |

Nenhum nome ou fala vem de filme; os nomes são originais.

## 2. Abertura (feito, `idle/abertura_idle.gd`)
- **Cena 1** (~3 s): rua de Nova York, 1948, porta da "Bellucci & Filhos". O chefe: "Meu sobrinho vai ser campeão."
- **Cena 2** (~3 s): Frankie, encostado no carro de época, ajeita o cabelo (brilho no topete): "Nasci para correr!"
- **Corte seco para a 1ª corrida, que larga sozinha** (critério do briefing: corrida em até 15 s).
- **Cena 3 e 4**, na volta da 1ª corrida (conversa `inicio` da escada): "Que vergonha. Você vai fazer esse idiota vencer. E não me faça repetir." Em seguida o Theo abre a Ultrapassagem, como antes, e a dica aponta o +1; o primeiro +1 larga a corrida seguinte sozinha.
- Um toque completa a fala e pula a pausa. Sem modal de explicação.

## 3. Capítulos (falas da escada de desbloqueios, sem mudar quando nem o que libera)
A escada já liga cada passo a um marco da progressão. A conversão só troca quem fala, o que diz e
marca o capítulo. A ordem segue a progressão real: a arena abre depois do analista e das câmeras,
então "Ferro e Sangue" é o capítulo 6, e não o 4 do briefing (mover o desbloqueio mudaria a progressão).

| Capítulo | Passo da escada | Quem |
|---|---|---|
| 1 · O Favor | abertura, `inicio`, ultrapassagem, pneus, patrocínio, largada | o chefe, Theo, Mara, Bianca, Harold |
| 2 · A Família | `familia` (novo, só fala), pilotos, transmissão | Sal, Jade, Roxy |
| 3 · Os Negócios | vácuo, arquibancada, missões, pistas | Mara, o chefe, Rico |
| 4 · O Sindicato | analista | Nora |
| 5 · O Campeonato | câmeras | Kenji |
| 6 · Ferro e Sangue | arena | Sal |
| 7 · O Herdeiro | `herdeiro` (novo, só fala, liga 16 somada) | Frankie |

A conversa que abre um capítulo traz a tarja "CAPÍTULO N · NOME" acima do nome. O calendário da
escada não mudou (medido com o robô: empurrar a Ultrapassagem uma corrida deixava o carro mais tempo
em 7º). Na volta da 1ª corrida vêm duas conversas seguidas: a bronca do chefe e o Theo.

## 4. Divisões (nomes; as ligas e os números são os de antes)
O jogo tem 4 modalidades de pista com 8 ligas cada, mais a arena. As 7 divisões do briefing viram
as modalidades (1–4) e os nomes das ligas de topo (5–7):

| Antes | Agora |
|---|---|
| Compactos | **Corridas de Bairro** |
| Turismo | **Circuito Clandestino** |
| GT | **Liga dos Hot Rods** |
| Terra | **Stock Cars** |
| Arena | **Guerra das Famílias** (mesma arena, mesma física) |
| ligas Estreantes · Regional · Estadual · Nacional · Continental · Mestres · Elite · Lendas | Novatos · Regional · Estadual · Nacional · **Interestadual** · **Copa das Famílias** · **Grande Campeonato** · Lendas |

## 5. Identidade visual (feito em parte)
- **Paleta** (`IdleUI`):

  | Cor | Valor |
  |---|---|
  | Fundo | preto quente #0F0D0B |
  | Painéis | #1A1612 |
  | Texto | creme #F1E9D8 |
  | Ações | latão #D4A24C |
  | Ganho | verde-garrafa claro #74B08A |
  | Anúncio | verde-garrafa #2F7A52 |
  | Tarjas e alerta | vinho #8E2A26 / #B23A32 |

- **Título e abertura:** rua de tijolo de 1948 com janelas acesas, poste, cartaz "GRANDE CORRIDA ·
  SÁBADO · 1948" e o carro de época em planos chapados (para-lamas destacados, cabine alta, estribo,
  sem emblema).
- **Andares do complexo:** paredes de tijolo escuro, latão nos detalhes.

## 6. Carros históricos (próxima etapa)
O CRT desenha a corrida com os modelos 3D da frota do C&W, não com um gerador procedural. A
conversão pedida (silhuetas de 1928–1955 por divisão) pede um gerador de carrocerias de época em 3D
(distância entre eixos, altura, capô, para-brisa, para-lamas, grade, faróis, para-choques) ligado
ao carro de cada liga, sem tocar nos atributos. Fica para a próxima etapa, com a lista de
referência abaixo.

**Nomes:** a regra do projeto é que nome e marca de carro real não entram no build (CLAUDE.md), e
o briefing pede nomes visíveis configuráveis e verificação jurídica. Por isso a lista de modelos
reais fica **só aqui**, como referência de silhueta; no jogo, cada carro tem nome neutro e
original.

| Divisão | Referência de silhueta (só documento) |
|---|---|
| Corridas de Bairro | Ford Model A 1928, Ford Model B 1932, Plymouth P4 1937 |
| Circuito Clandestino | Ford De Luxe Coupé 1940, Willys Americar 1941, Chevrolet Fleetline 1948 |
| Liga dos Hot Rods | Ford 1932 hot rod, Willys coupé preparado, Mercury Eight 1949 |
| Stock Cars | Oldsmobile 88 1950, Hudson Hornet 1951, Studebaker Commander 1953 |
| Interestadual (ligas) | Tucker 48, Chevrolet Corvette 1953, Kaiser Darrin 1954 |
| Copa das Famílias (ligas) | Cadillac Fleetwood 1941, Packard Custom Eight 1948, Lincoln Continental 1946 |
| Grande Campeonato (ligas) | Chevrolet Bel Air 1955, Ford Thunderbird 1955, Chrysler C-300 1955 |

## 7. Pendente (próximas etapas)
1. Gerador de carros de época (item 6) e nomes neutros dos carros por liga.
2. Arte definitiva do chefe, do sobrinho e do elenco em roupas da época (o usuário sugere os assets).
3. Arena "Guerra das Famílias": cartaz de luta de carros na apresentação; sedãs e coupés de época.
4. Som: trilha swing/jazz/jump blues (a atual é provisória), locutor de corrida, motores de 6 e 8 cilindros.
5. Fundo das pistas (fotos do C&W no topo) por cenários de época.
6. Verificação de direitos antes de publicar (briefing, item 8).

## 8. Regressão
- Testes do jogo, robô e calibrador rodam sobre a mesma economia: os números de `data/idle/idle.json`
  só mudaram em textos e nomes.
- A arena não foi tocada.
