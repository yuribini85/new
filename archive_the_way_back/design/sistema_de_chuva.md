# THE WAY BACK — Sistema de chuva

Uma solução para os três casos: chuva normal, chuva de ouro (demanda cumprida) e chuva de piche
(demanda perdida). Mesma base, três configurações.

---

## A decisão: shader de tela cheia, não partículas

Partículas parecem o caminho óbvio e são a escolha errada aqui. Para cobrir uma vila inteira em
retrato você precisaria de milhares de partículas, e isso derruba o desempenho em celular fraco —
que é o alvo do projeto.

Um **shader de tela cheia num CanvasLayer** desenha chuva infinita a custo fixo, independente da
área coberta. As partículas ficam reservadas para o que o shader não faz bem: os respingos de
impacto no chão, que são poucos e localizados.

**A inclinação vende o isométrico.** Chuva vertical numa cena isométrica parece errada. A queda
precisa acompanhar o eixo da projeção — algo entre 12° e 20° na mesma direção das faces dos
prédios.

---

## Estrutura de nós

```
CanvasLayer (layer = 10)          ← acima do mundo, abaixo da UI
└── ColorRect  (anchors = tela cheia)
    └── material: ShaderMaterial (rain.gdshader)
```

Para a UI ficar fora da chuva, ela vive noutro CanvasLayer com layer maior.

---

## rain.gdshader

```glsl
shader_type canvas_item;

uniform vec4  streak_color : source_color = vec4(0.72, 0.78, 0.85, 0.35);
uniform float density   : hint_range(1.0, 60.0)  = 26.0;
uniform float speed     : hint_range(0.1, 6.0)   = 1.6;
uniform float slant     : hint_range(-0.6, 0.6)  = 0.22; // inclinação isométrica
uniform float streak_len: hint_range(0.005, 0.2) = 0.05;
uniform float thickness : hint_range(0.2, 1.0)   = 0.55;
uniform float opacity   : hint_range(0.0, 1.0)   = 1.0;
uniform float glow      : hint_range(0.0, 2.0)   = 0.0; // ouro brilha, piche não

float hash(vec2 p){
    return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

// uma camada de chuva; chamada 3x com escalas diferentes para dar profundidade
float layer(vec2 uv, float scale, float t, float seed){
    uv *= scale;
    uv.x += uv.y * slant;              // inclina o eixo inteiro
    uv.y += t;                         // faz cair
    vec2 cell = floor(uv);
    vec2 f    = fract(uv);

    float r = hash(cell + seed);
    if (r > density / 60.0) return 0.0;           // só algumas células têm gota

    float x_off = hash(cell + seed + 7.7);
    float dx = abs(f.x - x_off);
    float dy = f.y;

    float line = smoothstep(thickness * 0.06, 0.0, dx);   // largura do risco
    float head = smoothstep(streak_len * scale, 0.0, dy); // comprimento
    return line * head;
}

void fragment(){
    vec2 uv = SCREEN_UV;
    uv.x *= 0.6;                       // corrige o esticamento em tela retrato
    float t = TIME * speed;

    float r = 0.0;
    r += layer(uv, 22.0, t * 1.00, 0.0) * 1.00;   // camada próxima
    r += layer(uv, 34.0, t * 1.45, 3.3) * 0.65;   // média
    r += layer(uv, 48.0, t * 1.90, 9.1) * 0.40;   // distante

    vec3 col = streak_color.rgb * (1.0 + glow * r);
    COLOR = vec4(col, r * streak_color.a * opacity);
}
```

---

## As três configurações

### Chuva normal
```gdscript
mat.set_shader_parameter("streak_color", Color(0.72, 0.78, 0.85, 0.30))
mat.set_shader_parameter("density",   26.0)
mat.set_shader_parameter("speed",      1.6)
mat.set_shader_parameter("streak_len", 0.05)
mat.set_shader_parameter("glow",       0.0)
```
Fina, rápida, quase incolor. Deve **escurecer a cena junto**: um `CanvasModulate` indo para
0.85 durante a chuva vende mais que o shader sozinho.

### Chuva de ouro — demanda da Holle cumprida
```gdscript
mat.set_shader_parameter("streak_color", Color(0.95, 0.76, 0.30, 0.85))
mat.set_shader_parameter("density",   14.0)   # menos, para valer mais
mat.set_shader_parameter("speed",      1.1)   # cai mais devagar: é pesada
mat.set_shader_parameter("streak_len", 0.02)  # risco curto — são moedas, não fios
mat.set_shader_parameter("thickness",  0.9)
mat.set_shader_parameter("glow",       1.4)
```
Risco curto e grosso lê como objeto caindo, não como água. E o `glow` faz o ouro ser a única
coisa da tela que emite luz — coerente com a regra de paleta contida.

**Acompanhamentos:** brilho global subindo por 2 s, moedas empilhando no chão como partículas
(50 a 80, com `gravity` e `damping`), e o som separado do som de chuva.

### Chuva de piche — demanda perdida
```gdscript
mat.set_shader_parameter("streak_color", Color(0.09, 0.07, 0.06, 0.9))
mat.set_shader_parameter("density",   20.0)
mat.set_shader_parameter("speed",      0.55)  # lento e viscoso
mat.set_shader_parameter("streak_len", 0.11)  # fio longo, escorrendo
mat.set_shader_parameter("thickness",  0.85)
mat.set_shader_parameter("glow",       0.0)
```
Lento, grosso e preto. A leitura de "viscoso" vem inteiramente da **velocidade baixa somada ao
risco longo** — é o mesmo shader.

**E o piche fica.** Diferente das outras duas, ele deixa estado: uma textura escura sobre os
telhados enquanto a penalidade de 30% durar. Essa mancha é o que comunica a maldição depois que
a chuva para, e é ela que some quando a entrega é completada.

---

## Transições

Nunca ligar ou desligar de uma vez. Um `Tween` no `opacity` do shader, 1,5 s para entrar e 3 s
para sair. Chuva que aparece instantaneamente parece bug.

```gdscript
func chuva(tipo: String, ativa: bool) -> void:
    aplicar_preset(tipo)
    var t := create_tween()
    t.tween_property(mat, "shader_parameter/opacity",
        1.0 if ativa else 0.0, 1.5 if ativa else 3.0)
```

---

## Respingos — o que as partículas fazem

Um `GPUParticles2D` por tipo, com poucas partículas e vida curta, emitindo numa faixa horizontal
logo acima do chão visível. Não precisa acertar geometria: em isométrico, respingo distribuído já
convence.

- **Água:** 40 partículas, círculo achatado que expande e some em 0,3 s.
- **Ouro:** 60 partículas com gravidade, acumulando no chão por 2 s antes de desaparecer.
- **Piche:** 20 partículas lentas, grandes, sem expansão — só caem e ficam.

---

## Custo

Um `ColorRect` de tela cheia com três camadas de ruído procedural roda tranquilo em celular de
entrada no renderer Compatibility. Se houver problema em algum aparelho, a saída é reduzir de três
camadas para duas — a perda visual é pequena e o ganho é imediato.

---

## O que ainda precisa ser decidido

- **A chuva normal é evento climático aleatório ou só cenário de momentos específicos?** Se for
  climática, precisa de uma curva de frequência por ato e não pode coincidir com as outras duas.
- **Chove sobre a floresta também, ou só sobre a vila?** Cobrir tudo é mais barato e mais correto.
- **A chuva de ouro cai sobre a vila inteira ou só sobre o depósito?** A vila inteira é mais
  bonita; o depósito é mais legível como recompensa.
