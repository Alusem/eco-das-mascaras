# GDD - O Eco das Máscaras

## 1. Visão Geral
* **Título:** O Eco das Máscaras
* **Gênero:** Mistério / Investigação / Puzzle de Lógica.
* **Engine:** Godot 4.x (GDScript).
* **Duração da Gameplay:** 5-10 minutos (Foco em Game Jam).
* **Objetivo:** Identificar o assassino que trocou de máscara com a vítima durante um apagão, usando contradições entre o que foi visto antes e o que é dito depois.

---

## 2. Mecânicas Principais

### A. Exploração e Diálogo (Fase 1)
* **Movimentação:** O jogador controla um convidado em um salão com 6 áreas: **Bar, Piano, Fonte, Sacada, Pista de dança e Centro**.
* **Interação [E]:** Ao falar com um NPC, ele revela sua localização e apresenta sua personalidade.
* **Caderno de Anotações:** Cada conversa ou pista ambiental gera um registro automático.
* **Relógio na UI:** Mostra fase atual e tempo restante.
* **Rodada Atual:** O caderno e o relógio exibem a rodada do ciclo.

### B. O Evento: O Apagão
* Ocorre após um tempo limite (ou por limite de interações configurável).
* **Visual:** Tela preta + mensagem de impacto.
* **Lógica de Troca:**
    1.  Um NPC é marcado como **Vítima** e seu sprite é substituído por um "Corpo" no chão.
    2.  O **Assassino** troca sua skin/máscara pela máscara da vítima.
    3.  Todos os NPCs mudam para novas posições no cenário.

### C. O Confronto (Fase 2)
* O jogador interroga os sobreviventes.
* **O Álibi:** Cada NPC diz onde estava antes das luzes apagarem.
* **A Mentira:** O assassino (agora usando a máscara da vítima) dará um álibi falso que não condiz com o registro inicial do caderno sobre aquela máscara.
* **Eventos Ambientais:** Mensagens rápidas durante a investigação (passos, sussurros, objetos caindo).

### D. O Pulso da Agonia (Mecânica de Tensão)
* **Gatilho:** Ativa na Fase 2 quando o tempo restante fica abaixo de 50%.
* **SFX:** Batimentos cardíacos aumentam volume e pitch conforme o tempo chega a zero.
* **VFX:** Vinheta escura pulsante nas bordas reduz o campo de visão.

---

## 3. Sistema de Interação e Expulsão

### O Botão de Acusação
Durante o jogo, o jogador pode ativar **"Acusar Mentira"** e falar com um NPC para confirmar a acusação. O caderno serve apenas para lembrar as falas.

1.  O jogador clica em **"Acusar Mentira"**.
2.  Uma janela de confirmação aparece: **"Acusar [máscara]?"**.
3.  O jogador confirma **Sim/Não**.

### Condições de Desfecho
* **VITÓRIA:** O jogador aponta a mentira do assassino. O criminoso é preso e o mistério resolvido.
* **DERROTA (Expulsão):** Se o jogador acusar um inocente ou apresentar a prova errada, o NPC se sente ofendido. Os seguranças são chamados e o **jogador é expulso do baile**.
* **DERROTA (Sozinho):** Se o assassino ficar sozinho com o jogador após um ciclo, é Game Over imediato.

---

## 4. Estrutura de Dados (Lógica Atual)

### NPC
* `id_mascara`: int
* `mascara_inicial`: String
* `mascara_atual`: String
* `local_fase_1`: String
* `is_killer`: bool
* `falas_fase1`: Array[String]
* `falas_fase2_inocente`: Array[String]
* `falas_fase2_killer`: Array[String]

### Pista Ambiental
* `descricao_pista`: String (texto narrativo)
* `mask_hint`: String (aponta internamente para a máscara, não mostrado ao jogador)
* `local_hint`: String

### Journal / Caderno
* `registros`: Array[String] (falas e pistas)

---

## 5. Controles
* **WASD / Setas:** Movimentação.
* **E:** Interagir / Avançar Diálogo.
* **Esc:** Abrir/Fechar Caderno.
* **Mouse:** Navegar no Caderno e clicar em "Acusar".

---

## 6. Checklist de Assets (48h)
* **Sprites:** Player, 6 variações de Máscaras, 1 Sprite de Corpo.
* **Cenário:** 1 Background de Salão com 6 áreas distintas.
* **UI:** Caixa de texto, Menu do Caderno, Tela de Game Over (Expulso), Tela de Vitória, Relógio de Fase.
* **SFX (Refinado):**
  - Música de Valsa Distorcida (Low-pass na Fase 2).
  - Som de Multidão (cortado no apagão).
  - Passos Pesados aleatórios na Fase 2.
  - Sussurro direcional ao se aproximar do assassino.
  - Badalo da Morte no apagão.
* **VFX (Refinado):**
  - CanvasModulate levemente azulado na Fase 2.
  - Partículas de poeira no ambiente.
  - Shader de distorção leve quando o tempo estiver quase acabando.