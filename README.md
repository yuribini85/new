# The Way Back — repositório de projeto

Idle isométrico em Godot 4.4, ambientado numa vila medieval fundada por João e Maria,
que acolhe crianças fugidas dos contos dos Grimm.

**Este repositório é o material de design.** O jogo ainda não foi implementado.

---

## Por onde começar

Se você é um agente de código lendo isto pela primeira vez, leia nesta ordem:

1. **`docs/mecanicas_para_godot.md`** — a especificação de implementação. Catorze sistemas
   com estado, fórmulas e regras, mais a ordem de implementação em onze etapas.
2. **`docs/especificacao_tecnica_v1.md`** — as 52 decisões técnicas já tomadas (versão do
   Godot, save, offline, modelo de dados, pipeline de arte).
3. **`docs/ato1_balanceamento.md`** — a tabela de custos, tempos e produção do primeiro ato.
4. **`data/*.json`** — os mesmos números em formato consumível.

**Não invente nada que já esteja decidido nesses quatro.** Se algo parecer faltando,
provavelmente está em `design/pendencias_resolvidas.md`.

---

## Estrutura

```
docs/       especificação e lore — leitura obrigatória
design/     decisões de conteúdo por sistema
data/       JSON de balanceamento, prontos para res://data/
tools/      ferramentas HTML autônomas (abrir no navegador)
art/        prompts de geração e mockups
archive/    versões anteriores, mantidas por referência
```

### docs
| Arquivo | O que é |
|---|---|
| `mecanicas_para_godot.md` | Especificação de implementação. **O documento principal.** |
| `especificacao_tecnica_v1.md` | 52 decisões técnicas |
| `ato1_balanceamento.md` | Custos, tempos e curva do Ato I |
| `the_way_back_biblia.html` | Bíblia completa, 35 seções (abrir no navegador) |
| `the_way_back_lore_completa.txt` | Só a ficção, sem sistema |
| `NOMENCLATURA_ASSETS.md` | Convenção de nomes de arquivo |

### design
Cicatrizes dos órfãos, economia, torre do vigia, sistema de chuva, prompts de revisão de
telas, e `pendencias_resolvidas.md` com os atos II a V, curvas de ratos, diamantes e regras
de borda.

### tools
Abrem direto no navegador, sem servidor:
- `grimm-forge-v52.html` — gerador de prompts de edificação (31 construções, 322 blocos)
- `twb-maquete-vila.html` — posicionamento dos lotes, exporta `vila_lotes.json`
- `twb-dialogue-forge.html` — editor de diálogo, exporta JSON e CSV de tradução
- `twb-inventario-assets.html` — inventário de 686 imagens com prompts
- `twb-tela-aldeoes.html` — mockup navegável da tela mais complexa
- `the_way_back_board.html` — board de status do projeto

---

## As dez regras que não se quebram

1. **Sem combate ativo.** Expedição é loop textual com requisito, duração e resultado.
2. **Sem perda permanente por descuido.** Só morte em expedição, com risco visível, escolhida.
3. **Nível de edifício é capacidade, não potência.** Produção linear pela soma das pessoas.
4. **Os líderes são imortais e não podem ser removidos** — garantem produção mínima sempre.
5. **A mina destrava, não produz.** Nunca vira estoque.
6. **Ouro só entra por venda** (única exceção: torneira modesta no nível 6 da mina).
7. **Nada da noite tem consequência mecânica.** Atmosfera não vira tarefa.
8. **As mecânicas nunca mentem.** A estranheza vive na ficção e na imagem, nunca na matemática.
9. **Offline é fórmula fechada**, nunca simulação retroativa.
10. **Não existe cura de cicatriz.** O jogador descobre onde a pessoa funciona apesar dela.

---

## Estado atual

- Design: fechado (~95%)
- Arte: ~48 de 686 imagens
- Código: não iniciado

**Próximo passo:** módulo 1 — esqueleto de projeto, autoload de simulação, save em JSON com
versão e proteção de relógio. A ordem completa está no fim de `docs/mecanicas_para_godot.md`.

---

## Três pontos onde isto provavelmente quebra

1. **Deadlock da cadeia anão ↔ equipamento.** O anão do nível N precisa ser alcançável com o
   equipamento que o nível N−1 permitiu. Testar cada degrau explicitamente.
2. **Offline com muitos dias.** Confirmar que o teto trunca antes de qualquer laço.
3. **Reposição de órfãos menor que a taxa de morte.** Conferir em todas as regiões.
