# Segundo piloto: os 4 candidatos

Decisão 56 (`docs/plano_mvp.md`): o segundo piloto da equipe deixa de ser fixo (Jonas
Reid, provisório) e passa a ser escolhido entre 4 candidatos, como no Grand Prix Story.
Cada um tem **um traço** que o jogador vê antes de contratar. O traço mexe numa alavanca
que a corrida já tem; os números (quanto muda, preço, salário) entram junto com o
`custo_staff` e saem do playtest, não daqui.

| id | nome | traço | alavanca | em uma frase (tela de contratação) |
|---|---|---|---|---|
| `jonas_reid` | Jonas Reid | **Constante** | perde menos consistência que o segundo piloto padrão | "Não ganha corrida sozinho, mas não joga ponto fora." |
| `ayla_moreno` | Ayla Moreno | **Agressiva** | tenta mais ultrapassagens (agressividade) | "Vê uma brecha onde os outros veem um muro." |
| `bastian_kroll` | Bastian Kroll | **Veterano barato** | salário menor; perde mais consistência | "Já foi rápido. Hoje é barato e conhece todo mundo no paddock." |
| `noor_haddad` | Noor Haddad | **Promessa** | o treino da equipe vale para ela também (o segundo piloto hoje não herda) | "Crua, mas aprende rápido. Cada hora de treino aparece no carro." |

Contratar troca o segundo piloto da equipe; o anterior sai (sem multa no MVP). A Mara
comenta a escolha na primeira contratação (decisão 55).

## Pedido de arte

Quatro retratos no padrão dos outros pilotos (`tools/pacote_arte_equipe.py`): **480 × 560
px**, cabeça e ombros, levemente de lado, olhos a um terço do topo, fundo escuro liso com
degradê suave, mesmo estilo da série. Arquivos: `arte/pilotos/<id>.png`. Corpo inteiro
para a vitrine, como os rivais: `arte/pilotos/corpo/<id>.webp`.

Estilo (o mesmo do pacote): *minimalist, theatrical and melancholic. Flat geometric shapes
with few planes, strong clean silhouettes, faces simplified to a handful of shapes, a
limited muted palette (deep navy, graphite, dusty teal, faded ochre) lit by one warm light
source with hard stage-like shadows. Original design only: no real people, no logos, no
readable text.*

- **Jonas Reid**: racing driver in his late twenties, calm and steady, neat short hair,
  plain racing suit zipped to the collar, a patient almost bored expression.
- **Ayla Moreno**: young racing driver, early twenties, restless energy, dark hair in a
  loose braid, suit sleeves tied at the waist over a fitted top, a sharp half grin.
- **Bastian Kroll**: veteran driver in his late forties, weathered face, greying stubble,
  an old faded racing jacket over the suit, tired but amused eyes.
- **Noor Haddad**: rookie driver, about nineteen, serious and attentive, hair under a
  plain cap, oversized suit that is still a little too big, notebook in hand.
