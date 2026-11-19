# Kokuen

Jogo de luta 2D para dois jogadores, no estilo Street Fighter / KOF, feito em um único arquivo HTML. Roda direto no navegador, sem instalar nada.

## Como jogar
Abra o `index.html` no navegador (ou use o GitHub Pages) e aperte **Enter** (teclado) ou **Start** (controle).

- Barra de vida, timer de 60s e melhor de 3 rounds.
- Dois lutadores: **Ryo** (design provisório) e **Lian** (sprites em pixel art).

## Controles

| Ação | Jogador 1 (Ryo) | Jogador 2 (Lian) | Controle Xbox |
|---|---|---|---|
| Mover / pular / agachar | A D W S | Setas | Direcional ou analógico |
| Golpe fraco / forte (soco ou leque) | F / G | K / L | X / Y |
| Chute fraco / forte | V / B | , / . | A / B |
| Defender | C | / | LB ou LT |
| Especial 1 (Hadouken / Chuva Escarlate) | Q | ; | RB |
| Especial 2 (subida / Tensenrin) | E | ' | RT |
| Mostrar caixas de golpe (debug) | H | H | Select |

Os especiais também saem pelos comandos: **↓ ↘ → + soco** (projétil) e **→ ↓ ↘ + soco** (subida).
Com um controle só, ele joga de Lian; com dois, o primeiro é o Ryo e o segundo a Lian.

## Arquivos
- `index.html`: o jogo inteiro, com os sprites da Lian embutidos.
