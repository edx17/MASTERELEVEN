# Master Eleven

Fútbol 3D arcade-simulación inspirado en Winning Eleven 4, con modo Liga Master.
Todo ficticio: clubes, jugadores y torneos inventados. Ver `Claude.md` para la
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

Mantené el botón para cargar la barra de potencia. Se remapea desde
*Proyecto → Configuración del proyecto → Mapa de entrada*.

## Ajustar la sensación de juego
Abrí `data/tuning/default_tuning.tres` en el Inspector: velocidades, potencia de
pases y tiros, rozamiento de la pelota, cámara, etc.

## Tests
Desde el editor: panel **GUT** (abajo) → *Run All*.
Por línea de comandos:
```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```
