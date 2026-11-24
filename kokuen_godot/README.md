# Kokuen (Godot 4.5)

Jogo de luta 2D para dois jogadores, no estilo Street Fighter / KOF.

## Como abrir
1. Abra a Godot 4.5.x (versão padrão, sem .NET).
2. Na tela de projetos, clique em **Import**, escolha o arquivo `project.godot` desta pasta e confirme.
3. Espere a Godot importar as imagens (primeira vez) e aperte **F5**.

## Controles
| Ação | Jogador 1 (Ryo, provisório) | Jogador 2 (Lian) | Controle Xbox |
|---|---|---|---|
| Mover / pular / agachar | A D W S | Setas | Direcional ou analógico |
| Golpe fraco / forte | F / G | K / L | X / Y |
| Chute fraco / forte | V / B | , / . | A / B |
| Defender | C | / | LB ou LT |
| Especial 1 (projétil) | Q | ; | RB |
| Especial 2 (Tensenrin / subida) | E | ' | RT |
| Mostrar caixas de golpe | H | H | Select |

Os especiais também saem pelos comandos: **↓ ↘ → + soco** (projétil) e **→ ↓ ↘ + soco** (subida).
Com um controle só, ele joga de Lian; com dois, o primeiro é o Ryo.

Enter (ou Start) começa a partida.

## Estrutura
- `scripts/game.gd`: todo o jogo (lógica, entrada, desenho e interface).
- `assets/atlas.png` + `assets/atlas.json`: sprites da Lian e as caixas de golpe de cada animação.
- O Ryo usa os mesmos sprites da Lian com o vermelho trocado por azul, até ter arte própria.
