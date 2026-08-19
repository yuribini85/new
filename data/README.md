# data/

JSON de balanceamento, prontos para `res://data/`. Ajustáveis sem recompilar.

| Arquivo | Conteúdo |
|---|---|
| `vila_lotes.json` | 30 lotes com célula, footprint e zona. Grade 68×56, tile 256×128 |
| `economia.json` | Recursos, produção, curva de custo, índice de fome, preços |
| `ciclo.json` | Dia/noite, offline, órfãos, aptidões |
| `expedicoes.json` | 5 regiões com requisito, duração, risco e fôlego |
| `mina.json` | 7 níveis e o que cada minério destrava |
| `ato1.json` | Ordem de desbloqueio e custo do primeiro ato |
| `vila_lotes_maquete.json` | Formato de trabalho da ferramenta de maquete |
| `orfaos.json` | Nomes (germânicos, masc/fem) e mapa de aptidão → edifícios |
| `cicatrizes.json` | As 20 cicatrizes de lançamento, transcritas de `design/cicatrizes_orfaos.md` |
| `floresta.json` | Raio de trabalho, densidade e taxa de regeneração da floresta (placeholder) |

**Fonte:** `docs/ato1_balanceamento.md` e `design/pendencias_resolvidas.md`.
Todos os números são chute calibrado — o que importa é a relação entre eles.

**Placeholder pendente:** `economia.json#indice_fome.fator_variacao_por_seg` (1.0) — a
taxa de subida/queda do Índice de Fome está listada em `design/economia.md` como número
que ainda falta decidir. Implementado como `indice += saldo_comida_por_seg * fator`,
autorizado como placeholder até ser calibrado por playtest.
