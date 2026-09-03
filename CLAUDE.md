# Instruções para o agente

## O que este repositório é

Dreadwick: idle horror mobile vertical, ambientado em 1925 numa ilha-farol da costa
escocesa. O protagonista é Quint Hollowell, veterano da Primeira Guerra e mecânico, que
mantém um farol cuja função real é conter Cthulhu. Godot 4.4. O jogo ainda não existe além
do que está neste repositório.

Este repositório antes continha outro projeto ("The Way Back", vila medieval/Grimm). Esse
material foi arquivado em `archive_the_way_back/`, intacto, e não faz parte do Dreadwick.

## Leia antes de escrever qualquer código

- `docs/dreadwick_biblia_oficial.md` — a bíblia. Fonte de verdade de tudo: lore, sistemas,
  economia, UI, arte, implementação. Cânone fechado não se reinterpreta sem decisão
  explícita; valores marcados "provisórios" são balanceamento aberto.
- `docs/dreadwick_manual_assets.md` — onde cada asset vive no Drive e a nomenclatura.
- `data/*.json` — todo o balanceamento extraído da bíblia (pesca, tempo, necessidades,
  moeda, confiança, insanidade). O que a bíblia marca como pendente aparece com uma chave
  `_status` explicando o que falta, em vez de um número inventado.

Em qualquer conflito entre um mockup, asset antigo ou versão anterior de documentação, a
bíblia prevalece (§24).

## Regras de trabalho

**Não invente balanceamento.** Custos, taxas, tempos, capacidades, penalidades e curvas
vêm de `data/*.json` (bíblia §17.7). Se um valor não estiver na bíblia nem em `data/`,
marque como pendente (`_status`) e pergunte, em vez de estimar.

**Tudo data-driven.** Nenhum número de balanceamento fica hardcoded em `.gd`. Upgrades
seguem o schema universal da bíblia §17.5 (id, name, building, hotspot, level, max_level,
cost, duration, required_items, supplier, required_act, required_trust, required_upgrade,
effects, visual_state, unlock_ids); NPCs seguem o schema §17.6.

**Não gere arte.** A direção visual e o pipeline de assets são do usuário — pasta do Drive
citada no manual. Use placeholders geométricos até existir um asset aprovado, e referencie
sempre por id/caminho estável do manifest (`DREADWICK_MANIFEST_ASSETS`), nunca por nome
improvisado. Mockups servem só de referência de layout, nunca entram no build.

**Máquina de estados central para Quint** (bíblia §17.1): Idle, Walking, Working, Fishing,
EnteringBuilding/ExitingBuilding, Sleeping, Eating, UsingLatrine, Talking, Upgrading,
Maintaining, CarryingFuel, Collapsed, Recovering. Evitar booleans dispersos que permitam
estados incompatíveis simultâneos.

**Regras que não podem ser quebradas** (bíblia §21, resumo): Quint não tem poderes; The
Vigil não é culto nem ordem de combate; N.A.S.H. não é onisciente; mais lux é sempre melhor
para a contenção; a Fresnel antiga já estava condenada; nunca softlock permanente por
necessidade/falta de Kit; automação reduz cliques repetitivos mas preserva deslocamento e
presença física; cutscenes são silenciosas, sem texto ou diálogo embutido; sem eletricidade
doméstica em interiores; personagens nunca com as mãos nos bolsos.

**Escopo do primeiro build:** vertical slice do Ato 1 (bíblia §19 e manual §ordem de
produção) — relógio central de 8 min + fases do dia, FSM de Quint + deslocamento + entrada/
saída por alpha, necessidades (Energia/Fome/Latrina), Casa (dormir/comer + Kit), Latrina
compartilhada com fila, Boathouse + pesca automática + câmera para o mar, Depósito +
estoques + enciclopédia base, Betsy (chegada, comércio, pedido, confiança, Kit/querosene),
dinheiro £/s/d, Oficina + upgrade universal data-driven, Farol (abastecimento, limpeza,
rotação, liga/desliga + automação inicial), fila de tarefas (1 atual + 3 futuras), save/load
+ offline inicial de 2h, Tela de Quint. **Sem** Insanidade/ACE, Thomas em deterioração,
Duncan, Eddie, peixes mutantes ou cutscenes — isso é Ato 2/3.

## Ordem de implementação (bíblia §22)

TimeSystem → QuintFSM → TaskQueue → Save/Offline → Data-driven Upgrades/Items → Buildings →
NPC Framework → UI universal → Fishing → Lighthouse → Narrative Flags. Sistemas conversam
por eventos/sinais e dados configuráveis, nunca por regra de prioridade espalhada em scripts
individuais.
