# Base de datos real (Paso C)

Uso personal: nombres reales de países, ligas, clubes y jugadores; sin
escudos, logos, marcas ni sponsors (ver `Claude.md`, Restricciones).

## Qué hay

| | Cantidad | Archivo |
|---|---|---|
| Selecciones (con bandera generada) | 59 | `data/db/nations.json` |
| Inglaterra: Premier, Championship, League One, League Two (2025-26) | 20 + 24 + 24 + 24 | `data/db/leagues/eng.json` |
| España: LaLiga, LaLiga 2 (2025-26) | 20 + 22 | `esp.json` |
| Italia: Serie A, Serie B (2025-26) | 20 + 20 | `ita.json` |
| Alemania: Bundesliga, 2. Bundesliga (2025-26) | 18 + 18 | `ger.json` |
| Portugal: Liga Portugal (2025-26) | 18 | `por.json` |
| Países Bajos: Eredivisie (2025-26) | 18 | `ned.json` |
| México: Liga MX (2025-26) | 18 | `mex.json` |
| Brasil: Brasileirão (**2025**) | 20 | `bra.json` |
| Argentina: LPF, Primera Nacional, Primera B, Primera C | 30 + 36 + 20 + 24 | `arg.json` |
| Uruguay, Paraguay, Chile, Colombia, Ecuador, Perú, Bolivia y Venezuela: primera división (2026) | 16, 12, 16, 20, 16, 18, 16 y 14 | `uru.json`, `par.json`... (`tools/db_src/conmebol.py`) |

Cada club trae nombre, sigla, camisetas titular y suplente (colores de
camiseta / pantalón / medias y diseño), estadio y capacidad. Los archivos
se generan con `tools/db_src/*.py` (fuente legible); se pueden editar a mano.

**Ojo con la temporada:** la composición de las ligas sale de lo que Claude
sabe a mediados de 2026. El Brasileirão es el de 2025 y la LPF y el Ascenso
argentino son los de 2025 (los ascensos y descensos de fin de 2025 no están
confirmados). El Torneo Promocional Amateur no está (decisión: la división
más baja es la Primera C). Todo se corrige con una lista de clubes desde el
Editor (Importar > Clubes y divisiones), con el archivo de planteles o
editando el JSON.

## Planteles

Mientras no se importe un archivo, cada equipo tiene un plantel **generado**
(estable: siempre el mismo), con nombres verosímiles del país, la piel según
el país y el nivel según la división (o el nivel de la selección). Con el
archivo real se reemplazan.

### De dónde sacarlos (recomendado)
1. **EA FC 26 / SoFIFA** (datasets de Kaggle en CSV): atributos completos,
   estatura, pie, puestos, edad y nacionalidad para casi todas las ligas
   de la lista y las selecciones. Es la mejor fuente: los atributos se
   convierten solos.
2. **Transfermarkt**: para lo que FC no trae (Primera Nacional, Primera B,
   Primera C). Sin atributos: se estiman por la
   división y el puesto.
3. Para cerrar el Ascenso argentino: Promiedos, Solo Ascenso o las páginas
   de los clubes.

### Formato del CSV
Una fila por jugador. Se aceptan columnas en inglés o castellano (las que
sobran se ignoran; separador `,` o `;`):

| Dato | Columnas reconocidas |
|---|---|
| Nombre | `short_name`, `nombre_corto`, `name`, `nombre`, `player`, `jugador`, `long_name` |
| Club | `club_name`, `club`, `team`, `equipo` |
| Nacionalidad | `nationality_name`, `nationality`, `nacionalidad` |
| Dorsal | `club_jersey_number`, `dorsal`, `number` |
| Puestos | `player_positions`, `puesto`, `position` (ST, CB, LW... o GK, CB, LB, DMF, CMF, AMF, WG, CF; también ARQ, DFC, LI, LD, MCD, MC, MCO, EXT, DC) |
| Pie | `preferred_foot`, `pie` (Right/Left, Diestro/Zurdo/Ambidiestro) |
| Estatura | `height_cm`, `estatura_cm` (cm o metros) |
| Edad | `age`, `edad` |
| Valoración | `overall`, `ovr`, `valoracion`, `media` |
| Selección (opcional) | `seleccion`, `national_team`: marca la convocatoria real |
| Atributos (opcional) | los de FC: `movement_sprint_speed`, `attacking_finishing`, `skill_ball_control`, `defending_standing_tackle`, `goalkeeping_*`, ... (o `pace`, `shooting`, `passing`, `dribbling`, `defending`, `physic`) |

### Cómo se importa (desde el juego)
1. **OPCIONES → DATOS → ABRIR CARPETA DE IMPORTAR** (abre
   `Documentos/VirtualEleven/importar/` en el Explorador).
2. Copiá ahí tus CSV.
3. **IMPORTAR PLANTELES**: muestra el resumen (jugadores, clubes,
   selecciones y los clubes que no encontró) y guarda todo en el **Option
   File** activo (si no hay, crea "Mi Option File"). La base no se toca.

Para quien trabaja en el proyecto también está la versión de consola, que
escribe en la base (`data/db`):
```
godot --headless -- --import-players=planteles.csv[,otro.csv]
```
- Cada jugador va a su club si el nombre coincide con uno de la base
  (acepta "CA Boca Juniors" ~ "Boca Juniors"). Entran todos los del
  listado, hasta 40 por club (con al menos 2 arqueros); al partido van los
  23 de la lista (11 titulares y 12 suplentes).
- Las selecciones se arman con los mejores 23 de cada nacionalidad (3
  arqueros, 8 defensores, 7 volantes, 5 delanteros), o con la convocatoria
  marcada en la columna `seleccion`.
- Al final lista los clubes del CSV que no encontró (también en
  `user://import_report.txt`) para corregir el nombre.

### Importar con revisión (Editor → Importar → Planteles)

1. **Revisar planteles**: una fila por club y liga del CSV, con el club del
   juego que le corresponde. Estados: OK (encontrado), REVISAR (hay varios
   parecidos: elegís en el desplegable), Nuevo (se crea), Salteada (no se
   importa). Para asignar un club que no aparece: elegí la fila, buscalo en
   "Asignar a la fila elegida" y apretá Asignar.
2. **Importar planteles**: aplica la propuesta (Ctrl+Z la deshace; Ctrl+S guarda).

Cómo empareja: busca en la división de la columna `league_name` (alias:
"Primera B Nacional" = Primera Nacional, "Primera B" = B Metropolitana...),
entiende abreviaturas ("Talleres (R.E)" = Talleres de Remedios de Escalada,
"Mitre (Santiago)" = Mitre (Santiago del Estero)) y recuerda lo que elegiste
(`club_alias` del Option File) para la próxima importación.

Qué hace con cada cosa:
- **Liga**: la división queda formada por los clubes del CSV (suben, bajan y
  se crean los que falten). Una liga que no está (Ligue 1, MLS, Süper Lig...)
  se crea, y su país también si no existe.
- **Sub-20** (Proyección, Libertadores Sub-20, Youth League, Primavera...): el
  plantel va a la Sub-20 del club (`youth`), no a Primera.
- **Libres** (club "Libre", "Sin club"...): a la lista de libres del Option File.
- **Torneos de selecciones** (Mundial, Nations League, Copa América...): el
  jugador va a su selección; a su club sólo si el club ya está en el juego
  (se suma al plantel, no lo reemplaza).
- **Selecciones nuevas**: si un país no está en la base y trae 16 o más
  jugadores, se crea con bandera y camisetas de `data/db/nation_catalog.json`
  (119 selecciones; se genera con `tools/db_src/nation_catalog.py`).
- El informe completo queda en `importar/informe_importacion.txt`.
- Scrapers de ejemplo (SoloAscenso, Transfermarkt): `tools/scrapers/`.

## Option File y carpeta del juego
Todo lo del jugador va en `Documentos/VirtualEleven/`:

| Qué | Dónde |
|---|---|
| Configuración y botones | `config.cfg`, `controles.cfg` |
| Option Files (tus cambios sobre la base) | `optionfiles/*.veof` (los `.meof` de Master Eleven se renombran solos) |
| Ligas en curso | `saves/ligas/` (un archivo cada una) |
| Copas y Mundiales en curso | `saves/copas/` |
| Liga Virtual (próximamente) | `saves/master/` |
| CSV para importar | `importar/` |
| Récords del entrenamiento y estrategias guardadas | `records.json`, `planes.cfg` |

- El **Option File** guarda sólo los cambios: clubes y selecciones
  editados o nuevos, qué clubes juegan cada división y selecciones
  borradas. Se elige en OPCIONES → DATOS ("Option File activo"); "VOLVER A
  LA BASE" deja de usarlo sin borrarlo. Para pasarlo a otra PC, copiá el
  `.veof` a la carpeta `optionfiles` (aparece solo en la lista).
- **CONTINUAR** (menú principal) lista las Ligas, Copas y Mundiales
  guardados con dónde van ("Fecha 7 de 29", "Cuartos de final"); al seguir
  una, se activa el Option File con el que se creó.

## Mundial 2026
Menú principal → **MUNDIAL 2026**: se eligen los 6 cupos del repechaje entre
las 12 candidatas (por defecto Italia, Polonia, Kosovo, Dinamarca, RD del
Congo e Irak) y después tu selección. Sorteo por bombos según el nivel (los
anfitriones encabezan), 12 grupos de 4, pasan los dos primeros y los 8
mejores terceros, 16avos, octavos, cuartos, semis y final.

## Estadios
Con un club real de local y el estadio "al azar", se juega en su estadio:
el nombre real y una forma según la capacidad (más de 65.000: cuenco de
cuatro bandejas). Los 20-30 emblemáticos con modelo propio llegan en la etapa
de pulido.


### Sub-20 (inferiores)

Cada club puede tener `"youth": [jugadores]` en su entrada: son sus
inferiores. Las usan los torneos Sub-20 (`db:u20:club:pais:id`) y la Liga
Master (suben a primera). Se cargan importando un CSV de liga juvenil o desde
el Editor (Equipos → Plantel: Sub-20). Si un club no tiene, se generan.
