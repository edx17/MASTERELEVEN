# Master Eleven

Fútbol 3D arcade-simulación: gameplay de Winning Eleven 2002 con presentación
moderna, y modo Liga Master como objetivo. Todo ficticio: clubes, jugadores y
torneos inventados. Ver `Claude.md` para la
visión completa y `docs/PROGRESS.md` para el estado.

## Cómo abrirlo
1. Bajá **Godot 4.7** (versión *Standard*, no .NET) desde https://godotengine.org/download
   — es un ejecutable sin instalación.
2. Abrí Godot → *Importar* → elegí `project.godot` de esta carpeta.
3. **F5** para jugar.

## Controles
| Acción | Mando | Teclado |
|--------|-------|---------|
| Mover | Stick izq / cruceta | WASD |
| Pase corto / presionar | A / Cruz | J |
| Tiro / barrida | X / Cuadrado | K |
| Pase largo / centro | B / Círculo | L |
| Pase al hueco | Y / Triángulo | I |
| Sprint | RB / R1 | Shift |
| Cambiar jugador | LB / L1 | Q |
| Pausa | Start | Esc |
| Modo debug | — | F9 |

Mantené el botón para cargar la barra de potencia. Se remapea desde
*Proyecto → Configuración del proyecto → Mapa de entrada*.

## Ajustar la sensación de juego
- `data/config/tuning.tres`: velocidades, giro, conducción, robo, pases, tiros, arquero.
- `data/config/camera.tres`: altura, distancia, ángulo, seguimiento, zoom de la cámara.
- `data/teams/*.tres`: equipos y atributos de jugadores (regenerables con
  `godot --headless -s res://tools/generate_data.gd`).

## Tests
Desde el editor: panel **GUT** (abajo) → *Run All*.
Por línea de comandos:
```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```
