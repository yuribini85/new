# GERADOR × LORE — Lista de mudanças do catálogo

Base: `catalog_v48.json` / `grimm-forge-v49.html` (36 edificações × 11 estágios + 7 hostis × 3 estados = 417 blocos).
Confrontado com a bíblia de lore v4 + economia.

---

## Resumo

| | Qtd |
|---|---|
| Edificações no catálogo hoje | 36 |
| **Mantidas sem mudança** | 14 |
| **Renomeadas** (asset serve, nome/âncora mudam) | 7 |
| **Removidas** | 8 |
| **Refundidas** (duas viram uma) | 2 → 1 |
| **Novas a criar** | 6 |
| **Catálogo final** | **34 edificações** |

Blocos finais: 33 × 11 + Cemitério × 2 + 7 hostis × 3 = **386 blocos**.

---

## 1. Mantidas — nenhuma ação

| Edificação | Status atual |
|---|---|
| Cabana do Lenhador | ✅ validada |
| Horta | ✅ validada |
| Forja | ✅ validada |
| Padeiro / Padaria | ✅ validada |
| Cabana do Caçador | prompts prontos |
| Cabana do Herbalista | prompts prontos |
| Curandeiro | pendente |
| Biblioteca | pendente — próximo da fila |
| Depósito | pendente — próximo da fila |
| Alfaiataria | pendente |
| Oficina do Sapateiro | pendente |
| Cabana do Construtor | pendente |
| Casa de João e Maria | pendente |
| Poço | pendente |
| Lago | pendente |
| Moinho | ⏸ pausado (terreno) |

---

## 2. Renomeadas — o asset serve, muda nome e âncora

| Nome atual | Novo nome | Ajuste de âncora |
|---|---|---|
| **Estalagem** | **Taberna** | Mantém o volume de estalagem. Âncora passa a ser o balcão de bebida e as mesas; some qualquer sugestão de hospedagem. Dona: Mulher do Pescador. |
| **Cabana de Morador** | **Alojamento** | Mesma casa. Âncora: dormitório coletivo — fila de camas visível pela porta, roupa estendida do lado de fora. Cresce em capacidade, não em conforto. |
| **Feira** | **Mercado** | Ponto fixo de venda, não feira sazonal. Dono: Mestre Ladrão. |
| **Fazenda** | **Curral dos Animais** | Já validada. Âncora vira criação — cercado, gansos e cabras, cocho. Remove campo de cultivo (é da Horta). Dona: Pastora de Gansos. |
| **Caçador de Bruxas** | **Casa de Maria** | O prompt de pedra angular com paliçada já está certo. É a casa dela, e é o asset que ganha evoluções junto com o equipamento. |
| **Salão Principal** | **Lar dos Órfãos** | Volume grande e comunitário já resolvido. Âncora: crianças, bancos baixos, telhado longo. Dona: Menina dos Táleres. |
| **Gazebo dos Músicos** | **Gazebo** | Sem mudança estrutural. Mantida a regra: sem teto nem cobertura, músicos compostos como sprite. |

---

## 3. Refundidas

| Antes | Depois |
|---|---|
| **Mina de Ouro** + **Mina de Ferro** + **Torre** | **Mina** (asset composto único, 8 estágios: ruína + 7 níveis) |

A torre deixa de ser edificação independente e passa a fazer parte do mesmo asset. Regras:

- Rocha e terreno **imutáveis** entre os oito estágios.
- A mina desce a encosta; a torre sobe. Saltos de altura maiores nos níveis III, V e VII.
- A torre não tem morador nem mecânica: é o mostrador da mina.
- Sete níveis são pedra, carvão, ferro, bronze, prata, ouro, pedra branca — mas isso **não muda a arte da boca da mina**, só o que ela destrava. A leitura visual é profundidade e altura, não tipo de minério.

**Consequência:** a escada `fuste` da Torre pode ser aproveitada como a metade superior do novo asset. A `Torre Rapunzel` (ver remoções) libera o resto.

---

## 4. Removidas

| Edificação | Motivo |
|---|---|
| **Castelo** | Virou cenário de fundo em projeção livre, não asset isométrico. |
| **Torre Rapunzel** | Idem — substituída pela montanha de vidro do Rinkrank e pelo castelo da Bela Adormecida, ambos em silhueta de fundo. |
| **Casa da Vovó** | Chapeuzinho é adulta e trabalha na padaria; a avó não está no elenco. |
| **Cofre** | Não existe na economia. O teto de estoque é do Depósito. |
| **Oficina de Melhorias** | Melhoria acontece por nível de edifício e por item especial de expedição. Sem edifício próprio. |
| **Entreposto de Trocas** | Função absorvida pelo Mercado (fixo) e pelo Alfaiate (ambulante). |
| **Chiqueiro** | Absorvido pelo Curral dos Animais. |
| **Praça** | Não é construção: é o espaço vazio ao redor do gazebo. Tratada como terreno. |
| **Apicultor** | A Rainha das Abelhas saiu do projeto. |

---

## 5. Novas a criar

| Edificação | Escada | Âncora | Notas |
|---|---|---|---|
| **Cabana de Pesca** | casa | Cabana pequena na margem, secadouro de rede, barco encalhado | Fica no lago, longe da mina. Dono: o Pescador. |
| **Vendedor de Armas** | casa | Banca coberta com armas expostas em rack, bigorna pequena | Não é forja: é venda. A luz azul pendurada é o objeto memorável. |
| **Casa das Fiandeiras** | casa | Casebre baixo e torto, rocas visíveis pela porta, meadas penduradas fora | Sistema de offline. Nível define o teto de tempo acumulado. |
| **Casa dos Anões** | casa | Casinha pequena, limpa e modesta, fila de camas, sete lugares à mesa | Cresce para receber cada anão resgatado. Perto da mina. |
| **Cemitério** | aberta | Cercado baixo, lápides de pedra tosca, portão de ferro | **Único caso de 2 estágios: ruína + tier único.** É onde ficam os órfãos mortos em expedição; a Madrinha Morte devolve por dois anúncios. |
| **Casa de Doces vitrificada** | fixa, sem estágios | Casa preta e vítrea, açúcar cristalizado e endurecido, formato ainda reconhecível, árvores mortas | Canto do mapa, além da mina. Sem evolução. Aparece no Ato III. |

---

## 6. Ajustes de regra no gerador

**Estágios variáveis por edificação.** O gerador assume 11 para todas. Precisa aceitar exceção: Cemitério com 2, Casa de Doces com 1, Mina com 8.

**Regra do Cemitério.** Como não tem teto nem paredes, herda a escada `aberta` da Horta — que é a única validada nesse caminho. Vale gerar logo depois da Biblioteca para testar a escada aberta com risco baixo.

**Casa de Maria.** Precisa de uma segunda dimensão de progressão além do nível de edifício: as evoluções dela como personagem. Decidir se são o mesmo asset ou dois sistemas.

---

## 7. Ordem sugerida de trabalho no gerador

1. **Renomeações** — sete edificações, mexe só em nome e âncora. Rápido e destrava metade das ausências.
2. **Remoções** — oito, reduz o catálogo e o zip.
3. **Cemitério** — testa a escada aberta com apenas 2 estágios, risco mínimo.
4. **Novas de escada casa** — Pesca, Vendedor de Armas, Fiandeiras, Casa dos Anões. Molde já validado seis vezes.
5. **Casa de Doces** — asset único, sem escada, prompt próprio.
6. **Mina composta** — o mais difícil. Oito estágios, dois eixos de progressão, terreno fixo. Deixar por último e tratar como projeto separado.

Fila anterior (Biblioteca, Depósito) segue válida e pode rodar em paralelo com o passo 1.

---

## 8. Ponto que precisa de decisão

**As sete cabanas de ofício vão ficar parecidas.** Alfaiataria, Sapateiro, Construtor, Herbalista, Curandeiro, Vendedor de Armas e Pesca usam todas o mesmo molde 2×2×2, e a diferenciação vem só da âncora e dos props.

Com onze estágios cada, são 77 imagens de cabanas quadradas. Vale considerar dar a cada uma um traço estrutural fixo — uma marquise, um alpendre, um telhado de duas águas contra quatro, uma parede de pedra — para que a silhueta separe antes dos props.
