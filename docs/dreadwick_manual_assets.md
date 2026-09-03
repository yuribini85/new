# DREADWICK — Manual de Estrutura de Assets (v2)

Baseado na Bíblia Oficial de Desenvolvimento (`dreadwick_biblia_oficial.md`) — em qualquer
conflito, a Bíblia (seção 24) tem autoridade final sobre este manual.

**Regra de autoridade:** regras marcadas como canônicas na Bíblia são obrigatórias. Só
valores numéricos marcados "provisórios" ficam abertos a balanceamento. Este manual nunca
reinterpreta arquitetura, função, narrativa ou direção de arte — só organiza onde cada asset
vive.

Todos os arquivos de assets do projeto estão centralizados na pasta raiz do Drive:
https://drive.google.com/drive/folders/170FhCkDBiFNrklu1HaDEmskp-zTIiBc9 — qualquer caminho
mencionado aqui é relativo a essa raiz.

---

## Nomenclatura (bíblia §23.2)

1) Sprites de mundo/animação (personagens, veículos em movimento):
   `personagem_acao_direcao_frame.extensão` — ex.: `quint_walk_ne_01.png`,
   `betsy_barco_chegada_se_03.png`. Direções mínimas: NE, NW, SE, SW.

2) Estados estáticos (retratos, HUD, edificações, ícones):
   `categoria_nome_estado.extensão` — ex.: `quint_retrato_neutro.png`,
   `farol_exterior_nivel2.png`.

Regras fixas: PNG com alpha real para tudo isolado (nunca fundo sólido); pivô nos pés para
personagens, documentado para veículos/edificações; todos os personagens na MESMA altura de
referência; cada animação declara frames e FPS no manifest; nunca gerar personagem com as
mãos nos bolsos.

**Fonte e cópia de runtime (§23.9):** só duas cópias de cada asset — `_fonte/` (editável) e
o PNG/WAV/OGG/TTF final solto na pasta do item (já é o arquivo de runtime, sem espelho de
exportação separado).

---

## Estrutura de pastas no Drive

- `00_NASH_IDENTIDADE/` — `Master_Logo/` (logo N.A.S.H. única) + `Variantes_Aplicadas/`
  (toda aplicação deriva do master, nunca redesenhada à mão).
- `01_PERSONAGENS/<Nome>/` — `retrato/`, `corpo_inteiro/`, `sprite_mundo/`, `variações/`,
  `_fonte/`. Estados de retrato de Quint: neutro, satisfeito, cansado, tenso, abalado
  (gameplay); irritado, desconfiado, curioso, determinado, assustado, exausto, aliviado
  (diálogo).
- `02_ILHA_E_CENARIO/` — composição vertical isométrica em camadas, **nunca** parallax
  lateral tradicional:
  - `Camadas_Runtime/Fundo_Atmosfera/`, `Mar/`, `Ilha_Base/` (rocha, terreno, caminhos —
    tudo que não é edificação nem efeito).
  - `Edificacoes/<Nome>/exterior/` (estados de upgrade) + `hotspots/` — uma subpasta por
    edificação (Casa_Quint, Farol, Oficina, Boathouse, Deposito, Estacao_Thomas,
    Casa_Stewart, Latrina), cada uma um sprite transparente independente com pivô próprio.
  - `Overlays_FX/` — neblina, chuva, luz do farol, fumaça, glow: nunca pintado na ilha-base.
  - `Interiores/` — fotografia 1925 (paleta dessaturada, granulação leve, vinheta mínima,
    sem sépia pesado); luz só de janela, lampião ou fogão (sem eletricidade doméstica).
- `03_HUD_UI/` — telas completas em mockup **nunca** viram PNG único interativo; tudo
  montado no Godot a partir de componentes: `Componentes_UI_Base/`,
  `Instrumentos_Necessidades/`, `Instrumento_Lux/`, `Instrumento_Insanidade/`,
  `Odometros_Dinheiro_Recursos/` (spritesheet de dígitos 0-9), `Retratos_Emocoes_Quint/`,
  `Retratos_Oficiais_NPCs/`, `Paineis_Edificacao/`, `Icones_Diversos/`, e telas próprias:
  `Tela_Quint/`, `Tela_Confianca/`, `Tela_Deposito/`, `Tela_Colecao_Enciclopedia/`.
  Direção: instrumento marítimo britânico 1925 adaptado por mecânico — latão escurecido,
  ferro pintado, madeira, vidro, papel; nada de steampunk ornamental.
- `04_VEICULOS/` — `Barco_Quint/`, `Barco_Betsy/`, `Barco_Duncan/`, `Hidroaviao_Eddie/`.
  Escala e pivô documentados; nunca fundidos à ilha.
- `05_FAUNA_ENCICLOPEDIA/` — `Peixes_Comuns/` + `Peixes_Mutantes/`, par com o mesmo
  identificador-base. A silhueta de "não descoberto" é gerada no Godot por shader a partir
  do alpha do PNG — nunca uma segunda imagem manual por espécie.
- `06_CUTSCENES/` — uma subpasta por cutscene, imagens numeradas, sem texto embutido.
  Produzidas por último, depois do gatilho de gameplay validado.
- `07_AUDIO/` — `Musica/`, `SFX/` (por sistema: Ambiente, Passos, Pesca, Barcos,
  Hidroaviao, Farol, Radio, Sismografo, Odometros_UI, Latrina, Eventos_ACE),
  `Grunhidos_Personagens/` (3-6 por personagem, sorteados por caixa de fala).
- `08_TIPOGRAFIA_FONTES/` — `.ttf`/`.otf` + licença.
- `09_REFERENCIAS_MOODBOARD/` — não entra no jogo, só briefing de artista.

**Manifest obrigatório (§23.10):** planilha `DREADWICK_MANIFEST_ASSETS` na raiz do Drive —
toda peça de asset de mundo tem uma linha com id, caminho, categoria, ato, status
(placeholder/aprovado/final), escala, pivô, direções, animações, FPS, fonte visual aprovada.
**A programação referencia assets por id/caminho estável, nunca por nome improvisado.**

## Ordem de produção obrigatória (§23.11)

1. Vertical slice Ato 1: Quint, Skye, ilha-base e construções essenciais — Casa, Latrina,
   Boathouse/barco, Betsy, Depósito, necessidades, dinheiro, Farol, Oficina.
2. Thomas e estação, assim que esse loop base estiver jogável e estável.
3. Só depois: Duncan, Eddie, peixes mutantes, Insanidade, arquivos avançados de Stewart,
   conteúdo visual de Ato 2/3.
4. Cutscenes por último, dentro de cada marco narrativo, após o gatilho de gameplay validado.

Se qualquer mockup, asset antigo ou placeholder divergir da Bíblia, a Bíblia prevalece.
