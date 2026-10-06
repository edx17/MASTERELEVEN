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

## Selecciones
- Datos: nombre, sigla, nivel (para los planteles generados), formación,
  camisetas, si juega el Mundial 2026 (clasificada / repechaje) y la bandera
  (descripción simple, con vista previa).
- **Convocatoria**: subir / bajar (los 11 primeros son titulares),
  desconvocar y **convocar** a cualquier jugador de un club (se copia a la
  lista; máximo 23).
- **Nueva selección** (con plantel generado) y **Borrar selección**.

## Escudos
- En **Camisetas**, arriba: "Importar escudo (PNG)" elige una imagen (mejor
  cuadrada y con fondo transparente); se copia achicada a la carpeta del
  Option File y el juego la muestra en lugar del escudo generado (en las
  selecciones, en lugar de la bandera). "Quitar escudo" vuelve al generado.

## Ligas
- Por país, sus divisiones y los clubes de cada una.
- **Pasar de división** (ascensos y descensos a mano), **Sacar de la
  liga**, **Agregar club** nuevo (plantel generado según la división) y
  "Editar equipo" (lo abre en la pestaña Equipos).
- **Bajan a la de abajo**: cuántos clubes descienden de esa división (y
  ascienden de la de abajo) en la Liga Master. Si no se toca: 3 en
  Inglaterra y 2 en el resto.

## Copas
- Copas propias: nombre, formato (eliminación directa de 4, 8, 16 o 32, o
  liga de 3 a 40 equipos) y equipos (de a uno o un grupo entero). Avisa si
  la cantidad no sirve.
- En el juego: **COPA** muestra "Copa rápida" y tus copas; elegís tu equipo
  entre los de la copa.

## Camisetas
- Por equipo (selecciones o clubes), **Titular** o **Suplente**: color de
  camiseta, pantalón, medias, diseño (lisa, rayas, rayas finitas, aros,
  mitades, banda diagonal, franja en el pecho, V, cuadros), segundo color y
  color del arquero. "Aplicar colores".
- **Vista 3D** del jugador con la camiseta (gira sola; botones Frente /
  Espalda).
- **Plantilla PNG** para pintarla a mano: "Exportar plantilla" guarda el PNG
  con los colores actuales en `Documentos/MasterEleven/plantillas/` y abre la
  carpeta; lo pintás con cualquier programa (Paint, GIMP, Photoshop) **sin
  mover las piezas** (torso, mangas, short, medias: ver `docs/KIT_UV.md`),
  lo guardás con el mismo nombre y apretás "Importar plantilla". El juego
  la usa en lugar del diseño (el número y el escudo van encima). "Quitar
  plantilla" vuelve al diseño por colores.

## Botines y aspecto
En la ficha de cada jugador (pestaña Jugadores) hay una vista 3D con su
aspecto, sus botines y la camiseta del equipo; los botines (A-H), piel,
peinado, color de pelo, barba y físico se eligen ahí (o para muchos a la vez
con la edición masiva).

## Importar
Lo mismo que en el juego: copiás los CSV a la carpeta `importar`, apretás
**Importar** y los planteles van al Option File de arriba, con el resumen de
lo que entró y de los clubes que no se encontraron. Formato y fuentes:
`docs/BASE_DE_DATOS.md`.

### Clubes y divisiones
Para armar las ligas con una planilla propia (por ejemplo, la temporada
nueva con ascensos y descensos). El CSV necesita las columnas **nombre** y
**división**; opcionales: **estadio**, **país**, **id**, **sigla** y
**capacidad** (en castellano o en inglés).
1. Copiá el CSV en la carpeta `importar` y apretá **1. Revisar lista de
   clubes**. Aparece una tabla con cada fila del CSV y qué va a hacer:
   - **OK**: encontró el club (por id, por nombre —"Velez", "Newell´s" o
     "Atletico Rafaela" se reconocen— o, si hay varios con el mismo nombre,
     por el estadio: los dos "Estudiantes" se separan así).
   - **REVISAR**: hay varios clubes posibles; elegís cuál en la última
     columna (o "Club nuevo" / "No importar").
   - **Nuevo**: no está en el juego; se crea con colores lisos y plantel
     generado (después se edita en Equipos y Camisetas).
   - **Salteada**: la división no existe en el juego.
2. Apretá **2. Aplicar**: cada división del CSV queda con esos clubes (los
   que no figuran salen de esa división; las divisiones que no están en el
   CSV no se tocan). Con "Usar los estadios del CSV" también se cambian los
   estadios. Ctrl+Z lo deshace y Ctrl+S lo guarda.
Con una columna **id** (los ids del juego: `boca`, `racingcba`...) el club
se encuentra directo, sin dudas.

