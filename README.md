# Chrome & Wreckage

Jogo mobile idle de automobilismo, feito em Godot 4.4.

Preserva a estrutura de carreira de um Gran Turismo clássico — comprar carros novos e usados, preparar, correr eventos, ganhar prêmios,
colecionar — e substitui a pilotagem por corridas automáticas isométricas.

## Estado

Demo jogável com a história. As fases 1 a 9 do documento de implementação "Second
Driver" estão feitas (decisões 32 a 38 em `docs/plano_mvp.md`); `data/` tem o
balanceamento importado do disco do GT2; a arte final de personagens e equipes ainda vai
chegar (hoje: placeholders).

O que existe hoje:

- história como camada de dados: jogo novo na campanha do dono da oficina, guiado pela
  Mara Hayes (Chrome & Wreckage), com o piloto da casa ao volante; saves antigos seguem a
  história anterior (Adrian → Elena → Second Driver Motorsport); diálogos com tutorial
  (abrir telas e destacar elementos), flags e comentários de contexto com limite;
- concessionária de novos e usados, garagem, oficina com peças e pneus por carro,
  pintura por cores do modelo, venda;
- licenças CLUB a ELITE (treino por tempo, requisitos, avaliação por testes ou
  contratos), eventos do GT2 com equipes e pilotos rivais, campeonatos por pontos,
  resistência, copas de marca;
- equipe do jogador: segundo piloto na mesma prova, caixa único, patrocínio e staff
  (valores pendentes do playtest);
- corrida resolvida pela simulação e reproduzida em 3D, com câmera automática, HUD,
  minimapa e sons; fila de repetições (só repetição corre offline), save com `.bak`;
- modo de playtest com registro local de sessões e cenários de teste (saves prontos em
  pontos da história, num arquivo próprio: o save do jogador não muda).

Em aberto: playtest (patrocínio, staff, `fator_treino`), arte nova de personagens e
equipes, e os valores "a confirmar" em `data/README.md`.

## Jogar

Abra a pasta no Godot 4.4 (Importar → `project.godot`) e aperte F5. O save fica em
`user://save.json` (no Windows, `%APPDATA%\Apex Garage\`; a pasta mantém o nome antigo para não perder saves).

## Estrutura

```
autoload/dados.gd             carga e validação de data/*.json
autoload/jogador.gd           estado do jogador (saldo, garagem, licenças, vitórias, dias)
autoload/save_manager.gd      save com .bak e proteção; processa o offline ao abrir
data_model/                   carro, pista, economia, garagem, concessionária, elegibilidade,
                              carreira, licenças, usados, fila, save, campeonatos, história,
                              prólogo, equipe do jogador, cenários de teste
sim/simulacao.gd              corrida headless (envelope de velocidade, arrasto, cortesia)
visual/                       corrida 3D e minimapa, carro de blocos, vitrine, ícones (placeholders)
ui/                           telas: garagem, loja, oficina, eventos, corrida, carreira, equipe;
                              diálogo e destaques do tutorial
scenes/principal.tscn         cena principal (retrato 720×1280)
data/                         balanceamento (gerado do GT2; ver data/README.md)
tools/                        extração e importação do GT2, calibração, editor de pistas,
                              captura de telas, matriz de progressão
tests/                        testes Godot e Python, fixtures sintéticas
```

## Testes

```
tests/rodar.sh            # ou: tests/rodar.sh /caminho/do/godot
```

Roda os testes Godot (fixtures sintéticas) e os das ferramentas Python (disco
sintético). Também roda no GitHub Actions a cada push e pull request.

## Dados do GT2

`data/` é gerado a partir de uma cópia legítima do disco pelo fluxo
`tools/extrair_gt2.py` → `tools/importar_gt2.py` → `tools/calibrar_licencas.gd`. Passo a
passo, conversões e o que ainda está "a confirmar" em `data/README.md`.
`tools/simular_progressao.gd` mostra a posição de cada carro de fábrica em cada evento;
`tools/medir_progressao.gd`, a progressão e a renda por fase e por perfil de jogador.

## Ver as telas com dados de teste

```
godot -- --dados=res://tests/fixtures/
```

O save desse modo fica separado (`user://save_fixtures.json`).

## Cenários de teste

Carreira → Preferências → modo de playtest ligado → "Cenários de teste": Adrian no
começo e antes da última corrida, Elena depois do acidente e com o primeiro carro,
Second Driver criada e segundo piloto na equipe. Cada um grava em
`user://save_cenario_<id>.json`; "Voltar ao meu jogo" retoma o save do jogador.

## Documentos

| Arquivo | O que é |
|---|---|
| `docs/conceito.md` | Conceito, princípios e limites do projeto. |
| `docs/plano_mvp.md` | Escopo do primeiro build, sistemas, modelo da simulação, dados, ordem de implementação, riscos e decisões tomadas. |
| `docs/playtest_percurso.md` | Roteiro do playtest: modalidades de clareza e de ritmo. |
| `docs/medicao_progressao.md` | Progressão e renda por fase medidas pelo agente (`tools/medir_progressao.gd`). |
| `tools/pacote_arte_equipe.py` | Gera `build/pedido_arte_equipe.zip`: retratos, logos das equipes e ícone da aba Equipe, com os nomes de arquivo que os dados já usam (`visual/assets.gd` mostra cada um assim que entra). |
| `tools/pacote_arte_cenas.py` | Gera `build/pedido_arte_cenas.zip`: cenários dos diálogos e ilustrações dos momentos da história (`data/historia.json` → `cenarios`, `ilustracoes`), com a arte do jogo como referência de estilo. Até a arte chegar, cada cena usa a provisória do catálogo. |
| `tools/gerar_shell_web.gd` | Gera `web/shell.html`, a tela de carregamento da versão web (logo e garagem embutidas, mesma composição da tela inicial), a partir de `web/shell_modelo.html`. Rodar de novo quando a logo ou o fundo mudarem. |
| `docs/ids.md` | IDs de personagens, cenas, triggers, ações, flags, licenças, equipes e cenários (gerado por `tools/listar_ids.py`). |

## Regras do projeto

1. O jogador decide; a IA executa. Nenhuma decisão durante a corrida.
2. Não é Motorsport Manager.
3. Não inventar sistema quando o GT2 já tem uma solução que funciona.
4. O movimento visual é consequência da simulação, nunca o contrário.
5. A mesma IA controla o jogador e os adversários.
6. Carros, fabricantes, pistas e arte são originais. Nenhuma marca, nome ou traçado real.
7. O GT2 é referência de estudo a partir de cópia legítima. Nada dele é redistribuído.
8. A história (Chrome & Wreckage: o jogador é o dono da oficina e Mara Hayes o guia; saves
   antigos seguem Adrian → Elena → Second Driver Motorsport) é uma camada de dados —
   diálogos e flags — sobre os sistemas do jogo; o diálogo também é o tutorial. Aprovado
   pelo usuário em 2026-10-08 e trocado para Chrome & Wreckage em 2026-10-10 (antes: "Lore
   só depois que o jogo funcionar, e sem sistema novo").

## Histórico

O conteúdo anterior deste repositório (The Way Back / Dreadwick HUD) está preservado na
branch `backup/the-way-back`.
