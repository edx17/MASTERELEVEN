# Editor de Master Eleven

Programa aparte: **MasterEleven Editor.exe** (sale junto al juego en cada
build). También se abre desde el juego: menú principal → **EDITOR** (con
"Volver al juego" arriba).

Todo lo que cambiás va al **Option File** elegido arriba (se guarda en
`Documentos/MasterEleven/optionfiles/`). La base del juego no se toca: con
"VOLVER A LA BASE" (OPCIONES → DATOS) o eligiendo otro Option File vuelve
todo como estaba.

## Barra de arriba
| Botón | Qué hace |
|---|---|
| Option File | Cuál estás editando. |
| Nuevo | Crea uno vacío con el nombre que quieras. |
| Guardar (Ctrl+S) | Guarda los cambios (al cerrar la ventana también se guarda). |
| Deshacer (Ctrl+Z) | Vuelve atrás el último cambio (hasta 50). |
| Usar en el juego | El juego pasa a usar este Option File. |
| Abrir carpeta | La carpeta de los Option Files (para copiarlos a otra PC). |

## Jugadores
- Filtros: grupo (Selecciones o una división), equipo, puesto y búsqueda
  por nombre. Se pueden ver todos los jugadores de una división juntos.
- **Un jugador**: nombre, dorsal, puesto (siglas WE), otros puestos, pie,
  estatura, edad, nacionalidad, físico, piel, peinado, color de pelo,
  barba, botines y los 17 atributos. "Aplicar cambios" y listo.
- **Varios jugadores** (Ctrl o Shift + clic): edición masiva — sumar,
  restar o poner un valor en un atributo, o poner el mismo botín / piel /
  físico / nacionalidad a todos. Ej.: +3 de velocidad a todos los
  delanteros de la Premier.
- **Baja**: "Quitar del plantel". **Pase**: "Pasar a" otro equipo (si el
  dorsal está ocupado, le da otro; máximo 23 por plantel).

## Equipos
- Nombre, sigla, estadio, capacidad, formación y camisetas (titular y
  suplente, en texto: `camiseta/pantalón/medias|diseño|color`; diseños:
  stripes, pinstripes, hoops, halves, sash, band, v, checks).
- Plantel: los 11 primeros son los titulares; "▲ Subir" / "▼ Bajar" cambian
  el orden; "Nuevo jugador" (alta) y "Quitar" (baja).

## Importar
Lo mismo que en el juego: copiás los CSV a la carpeta `importar`, apretás
**Importar** y los planteles van al Option File de arriba, con el resumen de
lo que entró y de los clubes que no se encontraron. Formato y fuentes:
`docs/BASE_DE_DATOS.md`.

## Próximas etapas
- **E3**: Selecciones (convocatorias), Ligas (crear / borrar divisiones,
  mover clubes) y Copas.
- **E4**: Camisetas (colores, diseños, números, plantilla PNG para el mapeo)
  y botines, con vista 3D del jugador.
