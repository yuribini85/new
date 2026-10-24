# Sonorização do Chrome Racing Team

Como os idles usam som, o que o CRT já toca, o que falta e em que ordem fazer. Pedido do usuário
(2026-10-24). Volume, tom e duração são apresentação, não balanceamento: os números daqui ficam
no código de som (`visual/sons.gd`, `idle/`), não em `data/`.

## 1. O que a pesquisa mostra

**Muita gente joga sem som, mas quem fica no jogo tende a jogar com som.** Os números são velhos
e brigam entre si: telemetria da Appington (2013) mediu 73% jogando com volume acima de 10%; uma
pesquisa da TapResearch, por autodeclaração, teve 91% dizendo que joga sem som. A mesma pesquisa
diz que quem joga mais vezes e por mais tempo tende a deixar música e efeitos ligados, e que
jogadores de simulação e tycoon ligam o som mais que a média. Quem joga em público, no trabalho
ou sem fone desliga. Duas consequências para o CRT:

- **Todo som tem um par visual** (pulso, clarão, número subindo, vibração). O jogo precisa ser
  inteiro sem som.
- **O som é recompensa, não informação obrigatória.** Ele deixa o toque gostoso para quem ouve,
  e quem não ouve não perde nada.

**O que o gênero faz** (padrões que se repetem nas descrições de jogos e nos guias de design;
nenhum estudo de peso, são práticas recorrentes):

| Momento | Padrão do gênero |
|---|---|
| toque em botão | "pop" ou "clique" curto e seco, com o tom variando um pouco a cada toque para não cansar |
| compra de melhoria | moeda, caixa registradora; melhoria grande ganha um som mais pesado ("clunk" mecânico) |
| compras seguidas | o tom sobe a cada compra dentro de uma janela curta (combo) e volta ao normal quando para |
| coletar dinheiro | cascata de moedas, maior quanto maior o valor |
| marco (liga, desbloqueio) | fanfarra ou carrilhão que **sobe** de tom; recompensas maiores ganham acordes maiores e camadas (aplauso, fogos) |
| fundo | música em laço leve que não briga com nada (lo-fi, 8-bit, jazz leve), mais uma camada de ambiente baixa (o lugar "vivo") |
| configurações | **música** e **efeitos** em chaves separadas (muita gente quer só os efeitos) |
| anúncio | o som do jogo pausa enquanto o anúncio toca e volta depois |

As críticas de jogador sobre som em idle são poucas e todas sobre **repetição**: a música
agradável que cansa depois de semanas (AdVenture Capitalist), o efeito idêntico mil vezes. Daí
a variação de tom, as camadas que mudam com o progresso e a música mais baixa que os efeitos.

**Som de recompensa sobe.** Um tom que sobe soa como progresso (é o desenho de quase todo som de
"level up"). Recompensas em escala ficam melhores como uma família: o mesmo carrilhão, com mais
notas e mais camadas quanto maior o prêmio (guia da CRI sobre efeitos de recompensa).

## 2. O que o CRT toca hoje

Tudo passa por `Sons` (`visual/sons.gd`, do Chrome & Wreckage) num barramento só (Master), com
uma chave SOM nas Configurações que muda o volume.

| Momento | Som | Estado |
|---|---|---|
| tocar em aba, modalidade | `toque` (Kenney, CC0) | ok |
| comprar melhoria | `moeda`, tom sobe com o nível (ciclo de 6) | bom; falta o combo de compras seguidas |
| coletar (BEM-VINDO DE VOLTA, missão) | `moeda`, um pouco mais alto | falta a cascata, que cresce com o valor |
| oferta comprada (TV, analista…) | `moeda` + clarão | falta um som de "desbloqueou" |
| conversa abre | `toque` baixo | falta a voz do personagem |
| liga nova, modalidade nova | só clarão e vibração | **sem som**: falta a fanfarra |
| piloto novo, evolução | `comemoracao` (torcida) | troca: torcida é da pista, não do escritório |
| botão desativado tocado | nada | falta o "não dá" suave |
| largada 3-2-1 | bipes gerados | ok |
| corrida | motor em duas camadas (giro), pneu, zebra, pelotão, carro passando, torcida no fim | rico; igual na vista de cima e na TV |
| ultrapassagem / perdeu a posição | bipe que sobe / desce | ok |
| chegada, vitória | sinal + torcida; vitória com `comemoracao` | ok |
| arena | motor, impacto, raspagem, explosão | ok |
| música de fundo | — | **não existe** |
| ambiente de fundo | — | não existe no CRT (o C&W tem `oficina`) |
| anúncio na tela | o jogo segue tocando | **falta pausar** |

## 3. Proposta

Em ordem de valor por esforço. Os sons novos vêm de pacotes de licença livre como os que o
projeto já usa (`arte/sons/LICENCA.md`): Kenney (CC0: *Interface Sounds*, *UI Audio*, *Casino
Audio* para moedas e fichas, *Music Jingles* para fanfarras), GDC Game Audio Bundle e Mixkit.
Nada da referência.

### 3.1 Barramentos e chaves (base de tudo)

- Três barramentos: **Música**, **Efeitos** (interface e corrida) e **Ambiente**, todos no Master.
- Configurações com duas chaves, **MÚSICA** e **EFEITOS**, no lugar de SOM (o padrão do gênero).
- **Abaixar a música** (−6 dB por ~1 s) quando toca fanfarra ou coleta grande, para a recompensa
  aparecer.
- **Anúncio:** o Master muda no `show` do AdMob e volta no fechamento (os callbacks já existem em
  `idle/anuncios.gd`); o app em segundo plano também fica mudo.

### 3.2 A família de recompensa (o som que cresce com o jogador)

Um carrilhão só, em quatro tamanhos, sempre subindo:

| Tamanho | Quando | Forma |
|---|---|---|
| 1 | coletar missão, oferta pequena | 2 notas |
| 2 | piloto novo, evolução, desbloqueio de graça | 3 notas |
| 3 | oferta comprada, liga nova | 4 notas + brilho |
| 4 | modalidade nova, última liga | 4 notas + acorde + aplauso |

Junto do clarão e da vibração que já existem (`celebrar`): o tamanho do som acompanha o tamanho
do clarão.

### 3.3 Toques e compras

- **Combo de compras:** cada compra até 1,2 s depois da anterior sobe um semitom (até +7); parada,
  volta ao tom base. Hoje o tom segue o nível da melhoria; o combo dá a sensação de "maratona de
  compras" que o gênero usa.
- **Coleta em cascata:** de 3 a 12 moedas espalhadas em ~0,6 s, pelo tamanho do valor em relação
  à renda (faixas, não fórmula na tela).
- **Botão desativado:** um "tuc" grave e curto (`erro.ogg` já existe), sem vibrar.
- **Variação:** ±3% de tom aleatório em todo som de interface, para mil toques não soarem iguais.

### 3.4 O som também cresce com a escada de desbloqueios

O jogo já começa "quase vazio" na tela (`docs/idle/plano.md`); o som pode acompanhar:

- **Vista de cima (antes da TV):** a corrida soa como **rádio de box**: motor e torcida com filtro
  passa-baixa (abafados), bipes limpos.
- **TRANSMISSÃO NA TV comprada:** o filtro sai e entra o som cheio (motor, pneu, torcida). A
  compra fica audível, não só visível.
- **Arquibancada:** a torcida da reta final fica mais forte com o nível da Arquibancada.

### 3.5 Música e ambiente

- **Música:** um laço por tela de 60–120 s, instrumental, leve (lo-fi/funk de garagem), a −18 dB
  em relação aos efeitos; a música da corrida some sob o motor na TV e fica na vista de cima e
  nas outras telas. Laços longos e com variação cansam menos (a crítica do gênero é repetição).
- **Ambiente:** o box ao fundo nas telas de PILOTOS, PISTAS e MISSÕES (ferramentas, rádio
  distante), a −22 dB. O C&W já tem `oficina.ogg` e o gerado.

### 3.6 Personagens

- **Voz de conversa:** um "blip" curto por sílaba digitada, com um tom por personagem (Mara grave,
  Roxy aguda…), no estilo dos jogos que dão voz sem gravar falas. Barato e dá personalidade.

## 4. Mistura (referência)

| Camada | Nível |
|---|---|
| toque, abas | −8 dB |
| moeda (compra) | −6 dB |
| coleta, carrilhão 1–2 | −4 dB |
| carrilhão 3–4, fanfarra | −2 dB (com a música abaixada) |
| motor e corrida | como hoje (`visual/sons.gd`) |
| música | −18 dB |
| ambiente | −22 dB |

## 5. Ordem de implementação

1. Barramentos, chaves MÚSICA/EFEITOS e o mudo no anúncio (3.1). Sem asset novo.
2. Combo de compras, variação de tom, "tuc" do botão desativado (3.3). Sem asset novo.
3. Rádio de box antes da TV (3.4). Sem asset novo (filtro do Godot).
4. Carrilhão em quatro tamanhos e cascata de moedas (3.2, 3.3). Assets: Kenney *Casino Audio* e
   *Music Jingles* (CC0).
5. Voz de conversa (3.6). Gerada em código ou Kenney *Interface Sounds*.
6. Música e ambiente (3.5). Assets: decidir a fonte (Kenney *Music Loops* CC0, Mixkit ou
   encomenda), com licença registrada em `arte/sons/LICENCA.md`.

Os passos 1 a 3 cabem num lote sem nada novo no acervo; o 4 em diante pede baixar os pacotes.

## Fontes

- [73% dos jogadores de celular jogam com som (TouchArcade, 2013)](https://toucharcade.com/2013/11/05/73-of-mobile-gamers-play-with-the-sound-on/)
- [How Sound Preferences Impact Player Engagement (TapResearch)](https://blog.tapresearch.com/how-sound-preferences-impact-player-engagement)
- [Embracing the Mute Switch (Immersion)](https://www.immersion.com/?p=2175)
- [Dynamite Jack: estatísticas de configurações (Phil Hassey)](https://www.philhassey.com/blog/?p=1202)
- [Reward Effects (CRI Atom Craft)](https://blog.criware.com/?p=4525)
- [Level up sound effects (Morphic)](https://morphic.com/resources/sounds/level-up-sound-effects)
- [AdVenture Capitalist, resenha](https://onlinegamee.it.com/?p=735)
- [AdMob: configurações globais de volume e mudo](https://developers.google.com/admob/ios/global-settings?authuser=3)
- [AudioMob: como o áudio do jogo cede ao anúncio](https://audiomob.com/blog/common-questions-about-audiomob)
- Exemplos de especificação de som de clicker: [Money Maker Idle](https://www.seeles.ai/games/casual/money-maker-idle), [Click Click Clicker](https://www.seeles.ai/games/casual/click-click-clicker)
