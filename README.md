# Virtual Eleven

Fútbol 3D arcade-simulación: gameplay de Winning Eleven 2002 con presentación
moderna, y modo Liga Virtual como objetivo. Todo ficticio: clubes, jugadores y
torneos inventados. Ver `Claude.md` para la visión completa y
`docs/PROGRESS.md` para el estado.

## Jugar la última versión (.exe de prueba)
Cada push arma un `VirtualEleven.exe` para Windows (un solo archivo):
GitHub → pestaña **Actions** → la última corrida de **CI** → abajo,
**Artifacts** → `VirtualEleven-windows-...` (zip). Se guarda 30 días.

## Abrirlo en el editor
1. Bajá **Godot 4.7** (versión *Standard*, no .NET) desde https://godotengine.org/download
   — es un ejecutable sin instalación.
2. Abrí Godot → *Importar* → elegí `project.godot` de esta carpeta.
3. **F5** para jugar.

## Controles (estilo WE)
| Acción | Mando | Teclado |
|--------|-------|---------|
| Mover | Stick izq. / cruceta | WASD |
| Pase (atacando) · presión (defendiendo) | X / A | J |
| Remate · un compañero presiona | Cuadrado / X | K |
| Centro / pase largo · barrida | Círculo / B | L |
| Pase al hueco · sale el arquero | Triángulo / Y | I |
| Correr | R1 / RB | Shift |
| Gambeta / combinaciones · cambio de jugador | L1 / LB | Q |
| Estrategia (L2 + X / Cuadrado / Círculo / Triángulo) | L2 / LT | R + la tecla |
| Mentalidad defensiva / ofensiva | L2 + cruceta ← / → | R + ← / → |
| Pausa | Start | Esc |
| Cambiar cámara | Select / Back | C |
| Modo debug | — | F9 |

**Pelota parada**: el pateador toma carrera y lo que tengas apretado al
llegar decide el remate. Tiro libre: stick derecho = mira; Cuadrado solo =
normal, atrás + Cuadrado = colocado, adelante + toque = rasante, adelante
cargado = cañonazo, costado = comba, Círculo = globito / rasante al palo.
Penal: 5 direcciones con el stick al patear (la fuerza sube la pelota; pasada,
se va por arriba). Arquero: el stick al momento del remate elige el lado.

Mantené el botón para cargar la barra de potencia. Las combinaciones (globo,
pared, centros, bicicleta, marsellesa...) están en `Claude.md` y en el menú
*Opciones → Controles*, donde también se cambian los botones.

## Ajustar la sensación de juego
- `data/config/tuning.tres`: velocidades, giro, conducción, robo, pases, tiros, arquero.
- `data/config/cameras/*.tres`: modos de cámara (altura, distancia, ángulo, seguimiento, zoom).
- `data/teams/*.tres`: equipos y atributos de jugadores (regenerables con
  `godot --headless -s res://tools/generate_data.gd`).

## Assets (texturas, cielos, animaciones, sonidos)
Dejá los archivos tal como los bajaste en `assets/_entrada/` y subilos
(`git add assets/_entrada && git commit && git push`). Claude los descomprime,
los achica, los conecta al juego y los anota en `assets/CREDITS.md`
(ver `assets/_entrada/LEEME.md`).

## Tests
Corren solos en GitHub en cada push (pestaña *Actions*). Para correrlos a mano:
- Desde el editor: panel **GUT** (abajo) → *Run All*.
- Por línea de comandos:
```
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

## Capturas sin abrir el juego
```
xvfb-run -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility \
    --resolution 1280x720 -- --capture=carpeta [--quick | --intro | --replay | --foul |
    --training | --tunnel | --sheet | --far | --stadium=N | --cond=horario,clima |
    --shot=x,y,z,mira_x,mira_y,mira_z] [--empty=0.5]
```
