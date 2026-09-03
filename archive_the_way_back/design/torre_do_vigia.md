# TORRE DO VIGIA — prompts de estágio

Edificação independente da mina. Onze estágios, escada `fuste` (torre).
Nomenclatura: `twb_bld_torre-do-vigia_t00.png` … `_t10.png`

**Regra de leitura:** a torre é lida pela **altura e pelo fogo**, não por detalhe.
Nada de engrenagem, mecanismo de relógio, lente ou lâmpada — é madeira, pedra, ferro e
fogo aberto. O espelho é cobre martelado, empurrado à mão.

**Terreno imutável** entre os onze estágios: mesma base rochosa, mesma orientação.

---

## Bloco comum

Cole no fim de todos os prompts:

```
STYLE: hand-painted storybook illustration, Arthur Rackham inspired, fine ink linework with
muted watercolour washes, crisp readable game asset. Restrained earthy palette: weathered
dark umber timber, cold grey fieldstone, black iron, dull ochre. Overcast daylight, soft
shadows. No engineering diagram, no gears, no clockwork, no lens, no oil lamp, no modern
metalwork. Medieval, hand-built, rough.

TECHNICAL: true isometric projection, ground axes at 30 degrees, single building on a
rocky outcrop, transparent background, no shadow on the ground plane, no scenery, no
people, no text, no labels, even flat lighting, consistent camera angle.
```

---

## T0 — ruína

```
An isometric ruined watchtower on a rocky outcrop: a squat stump of dry-stone wall no
higher than a man, its timber frame collapsed inward, two snapped posts still standing at
an angle, charred beams and fallen rubble at the base, creeper and dry weeds growing
through the stones. An overturned rusted iron fire basket lies broken on the ground beside
it. Nothing intact above the first course of stone.
```

## T1 — o vigia

Um aldeão observando. Ainda não há fogo.

```
An isometric small watchtower: a rough dry-stone base one storey high with a simple open
timber platform above it, reached by a plain ladder leaning against the wall. A low railing
of untrimmed poles around the platform. No roof. No fire. A rolled blanket and a horn hang
from a post. Modest, hastily built, barely taller than the trees around it.
```

## T2 — o fogo

Entra o braseiro. Consome madeira.

```
An isometric watchtower slightly taller than before: the same dry-stone base with a second
level of squared timber above it, an enclosed ladder stair, and on the open platform a
black iron fire basket on a short tripod, burning with a small open flame. A stack of split
firewood on the platform and another leaning against the base. A wooden rail with an iron
hook for a bucket.
```

## T3 — o fogo grande

Mais um aldeão alimentando. Chama alta.

```
An isometric watchtower of three levels: dry-stone base, squared timber middle with narrow
slit openings, and a broad open platform on top carrying a large black iron fire basket on
a heavy tripod, burning with a tall open flame. A timber crane arm with a rope and pulley
for hauling firewood up the outside wall. Two large stacked woodpiles at the base, one
covered with a canvas sheet.
```

## T4 — o espelho

Entra a folha de cobre, empurrada à mão.

```
An isometric watchtower of four levels, noticeably taller: dry-stone base, two timber
storeys, and a wide open platform with a tall iron fire basket burning strongly. Behind the
flame stands a large hammered copper sheet mounted upright in a heavy wooden cradle, curved
slightly to throw the light forward, with a long wooden push-bar at its side so it can be
turned by hand. Rope, pulley and firewood at the platform edge. Warm reflected light on the
copper.
```

## T5 — o espelho grande

Dois girando. É o estágio que a lore descreve como completo.

```
An isometric tall watchtower of five levels: dry-stone base, three timber storeys with
narrow openings and an external stair, and a broad open platform under a simple shingled
canopy. On the platform, a very large iron fire basket burning high, and behind it an
oversized curved hammered copper mirror in a pivoting timber frame, with two long push-bars
extending from its base so two people can turn it together. A heavy counterweight stone
hangs on a rope at the side. Firewood stacked on every level.
```

## T6

```
An isometric watchtower of six levels, the stonework now cut and coursed at the base, the
timber squared and pegged. A shingled canopy over the platform, the great copper mirror
polished brighter in its pivoting frame, a taller iron fire basket, and an outer gallery
running around the platform. An iron-banded water barrel and a fire hook mounted on the
wall.
```

## T7

```
An isometric tall watchtower of seven levels: dressed pale stone base, dark seasoned timber
above, an enclosed stair turret on one side, a wide galleried platform under a steep
shingled roof open on all sides. A very large polished copper mirror on a heavy pivot,
paired push-bars, and a tall iron fire basket burning bright. Carved timber brackets under
the gallery.
```

## T8

```
An isometric imposing watchtower of eight levels: fully dressed pale stone lower half with
a carved string course, dark timber upper half, a stair turret, and a broad galleried
platform under an ornamented shingled roof with a finial. A great polished copper mirror,
double pivot frame, iron fire basket on a decorated stand. Iron lanterns hung along the
gallery rail.
```

## T9 — prata

A prata da mina entra no espelho.

```
An isometric tall ornate watchtower of nine levels: pale dressed stone with carved detail,
dark seasoned timber, a galleried platform under a steep decorated roof. The great mirror
is now silvered — a pale, cold, almost white reflective sheet in a heavy carved frame — set
behind a large iron fire basket. Fine silver inlay traces the timber brackets and the roof
edge. The light it throws reads cold rather than warm.
```

## T10

```
An isometric monumental watchtower of ten levels, the tallest structure of the village:
white dressed stone with gilded inlay, dark timber, a stair turret, a wide galleried
platform under an ornate roof with a gilded finial. An enormous silvered mirror in a
gilded pivoting frame stands behind a great iron fire basket. Gilded lanterns along the
gallery, banners of plain cloth at the corners. Imposing but still hand-built and rough at
the joints.
```

---

## Sistema

| Nível | Entra | Efeito |
|---|---|---|
| 1 | 1 aldeão — o vigia | Observação. Sem fogo, sem consumo |
| 2 | +1 aldeão — o fogo | Braseiro aceso. **Consome madeira por noite** |
| 3 | +1 aldeão | Chama alta. Mais alcance, mais consumo |
| 4 | +1 aldeão — o espelho | Feixe girando à mão |
| 5 | +1 aldeão — espelho maior | Dois girando. Alcance máximo da versão base |

**Bônus, escalonados por nível:**
- **Alcance para expedições em curso** — a luz é referência para quem está longe. Aplica-se a quem já saiu, não a quem vai sair, o que dá motivo para manter aceso enquanto Maria está fora.
- **Redução de maldição na vila**, com **teto de 40%**. Nunca reduz maldição de história: a casa que apodrece no Ato III não é evitável por ter torre.

**Três regras:**
1. **A torre pode ser apagada.** Botão na tela dela, com o consumo por noite visível. Aceso significa lenhador trabalhando para o fogo em vez de para construção — e o jogador vai querer apagar justo quando as maldições mais doem.
2. **Os cinco postos são noturnos.** É onde a cicatriz Vigília finalmente tem lugar.
3. **A luz não afasta nada.** Nenhum efeito sobre lobos, sombras ou olhos. Ela existe porque a vila quer acreditar que serve — e isso é mais Grimm que uma torre que funciona.

**No mapa da vila:** o feixe gira duas vezes por noite, ou seja uma volta a cada dois minutos. Lento o bastante para não cansar. Cone com gradiente aditivo, opacidade baixa, sobre a máscara de escuridão. **A informação de alcance vive na tela de expedição**, em léguas — no mapa fica só a beleza do giro.
