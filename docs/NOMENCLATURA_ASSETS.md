# THE WAY BACK — Nomenclatura de arquivos para o Godot

Convenção aplicada no gerador v50. Aparece na interface (campo ARQUIVO), em cada bloco do
pacote (`SAVE AS:`) e no nome do `.txt` exportado.

## Formato

```
twb_<tipo>_<slug>_<variante>.png
```

Sempre minúsculo, sem acento, sem espaço. Underscore separa campos; hífen só dentro do slug.
Ordena alfabeticamente na ordem certa e não quebra em nenhum sistema de arquivos.

## Tipos

| Prefixo | Conteúdo | Variante |
|---|---|---|
| `twb_bld_` | Edificação da vila | `_t00` … `_t10` (estágio) |
| `twb_hos_` | Estrutura hostil | `_sa` `_sb` `_sc` (estado) |
| `twb_chr_` | Personagem | `_idle` `_walk_n` `_portrait` |
| `twb_prp_` | Item, ícone, prop | `_01` |
| `twb_env_` | Terreno, fundo, névoa | `_01` |
| `twb_fx_` | Ratos, fumaça, partículas | `_01` … `_10` |
| `twb_ui_` | Interface | — |

## Exemplos

```
twb_bld_padaria_t00.png          ruína da padaria
twb_bld_padaria_t07.png          padaria no tier 7
twb_bld_mina_t00.png … _t07.png  mina + torre (asset composto, 8 estágios)
twb_bld_cemiterio_t00.png        ruína
twb_bld_cemiterio_t01.png        estágio único
twb_bld_casa-de-doces-vitrificada_t00.png
twb_hos_covil-do-diabo_sa.png    ativo
twb_chr_maria_t03_idle.png       Maria no nível 3 de equipamento
twb_chr_orfao_corpo-adulto_01.png
twb_fx_rato_03.png               um dos dez sprites de rato
twb_env_castelo-espinheiro.png   fundo, projeção livre
```

## Regras

1. **O número do estágio é sempre a posição na escada daquela edificação**, com dois dígitos.
   A mina vai até `_t07`, o cemitério até `_t01`, a casa vitrificada só tem `_t00`.
2. **Nunca renomear depois de importado no Godot.** O caminho vira dependência de cena.
3. **Uma pasta por tipo**, espelhando o prefixo: `res://art/bld/`, `res://art/chr/`, etc.
4. Variações de fundo, quando existirem, entram como sufixo final: `_alpha` ou `_white`.
