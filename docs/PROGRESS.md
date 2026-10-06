# Progreso — Master Eleven

Motor: **Godot 4.7.2**, GDScript. Referencia de gameplay: WE2002 (ForeverEleven).
Ver `Claude.md` para visión, criterios y fases.

## Dónde estamos (octubre 2026)

Juego de fútbol en **Godot 4.7 / GDScript**, sucesor espiritual del Winning
Eleven 2002, de **uso personal** (no se vende ni se comparte): por eso va a
llevar países, ligas, clubes y jugadores con sus nombres reales (escudos
generados, sin logos). **472 tests automáticos en verde** (corren solos en GitHub en cada push, que
además arma el `.exe` de Windows).

| Fase / tanda | Estado | PR |
|---|---|---|
| 1 — Base jugable | ✅ | — |
| 2 — Prototipo 0.1: sensación de juego | ✅ | #2 |
| 3 — IA de partido | ✅ Implementada (se sigue ajustando con tus pruebas) | — |
| 4 — Reglas, atributos y plantel | ✅ Implementada | — |
| 5 — Presentación moderna (estadios, animaciones, audio, repeticiones) | 🟡 Muy avanzada; falta el pelo "Detallados" y la voz del locutor | — |
| 6 — Liga Master | 🟡 D1–D5 hechos, **pendiente de tu prueba** | #32, #33 |
| 7 — Torneos | 🟡 Hecho en la Liga Master: copas reales de cada país y confederación, supercopas, Intercontinental, Mundial de Clubes y Mundial; **pendiente de tu prueba** | #33 |
| 8 — Pulido | ⬜ | — |
| Entrenamiento (Club House) | ✅ | #23 |
| Backlog B1–B9 | ✅ | #24 |
| Backlog B10 + infraestructura (CI, .exe, skills) | ✅ | #25 |
| Backlog B11 pasos 1-2 (assets, correcciones) | ✅ | #26 |
| Backlog B11 pasos 3-4 (pelota parada, sonidos) | ✅ | #27 |
| Resumen y regla de un solo PR | ✅ | #28 |
| Backlog B12 (correcciones de tu prueba) | ✅ | #29 |
| Paso A — Jugabilidad WE2002 | 🟡 Hecho, **pendiente de tu prueba** | #30 |
| Paso B — Jugadores low-poly WE mejorados | 🟡 Hecho, **pendiente de tu prueba** | #30 |
| Paso UI-1 — Pantallas como el WE2002 | 🟡 Hecho, **pendiente de tu prueba** | #31 |
| Paso C — Base de datos real y Mundial 2026 | 🟡 Hecho con planteles generados; **falta tu archivo de planteles** | #31 |
| E1 — Option File, partidas separadas, importar desde el juego | 🟡 Hecho, pendiente de tu prueba | #31 |
| E2 — Editor (jugadores y equipos, edición masiva) | 🟡 Hecho, pendiente de tu prueba | #31 |
| E3 — Editor: selecciones, ligas y copas propias | 🟡 Hecho, pendiente de tu prueba | #31 |
| E4 — Editor: camisetas (plantilla PNG) y botines con vista 3D | 🟡 Hecho, pendiente de tu prueba | #31 |
| Importar clubes (CSV) y Argentina sin Promocional | 🟡 Hecho, pendiente de tu prueba | #31 |
| D1 — Liga Master: carrera, temporadas, goleadores, ascensos y descensos | 🟡 Hecho, pendiente de tu prueba | #32 |
| D2 — Liga Master: tarjetas, lesiones, evolución, retiros y juveniles | 🟡 Hecho, pendiente de tu prueba | #33 |
| Menús: todo entra, tablas con el mando, cabeceras del Mundial | 🟡 Hecho, pendiente de tu prueba | #33 |
| D3 — Liga Master: Plantel, Dirección guardada, Calendario; escudos PNG | 🟡 Hecho, pendiente de tu prueba | #33 |
| D4 — Liga Master: mercado de pases con puntos WE | 🟡 Hecho, pendiente de tu prueba | #33 |
| D5 — Liga Master: noticias, historial y palmarés | 🟡 Hecho, pendiente de tu prueba | #33 |

### Base del juego (fases 1 a 3)
- **Cancha y pelota**: cancha de 105×68 con arcos y red. Física propia de la
  pelota (rebote, efecto, viento, césped mojado). Conducción guiada, pases
  que buscan al compañero, remates según la altura y modelo de atajada.
- **Control estilo WE2002**: barra de potencia, 8/16 direcciones, cambio de
  jugador, toque de primera con la orden guardada, globo, rasante, centro
  alto/raso, pared, super cancel; gambetas (marsellesa, bicicleta, amagues);
  presión de un compañero, barrida y entrada con timing.
- **IA de equipo**: 5 formaciones y roles tácticos; el bloque se mueve como
  unidad (salida, ataque, contraataque, defensa); pelotas paradas y arquero
  con achique.
- **Cámaras**: TV, amplia, cercana, vertical y dron. HUD con radar.

### Reglas, plantel y presentación (fases 4 y 5)
- **Reglas**: faltas, tarjetas (el árbitro va a mostrarlas), tiros libres,
  penales, offside, lesiones y cuerpo a cuerpo.
- **Plantel** de 23 con condición del día (flechas) y Dirección del equipo
  (en la previa y en la pausa).
- **Condiciones**: horario, lluvia, nieve (pelota naranja), viento y estado
  del césped; de noche, torres de luz.
- **Estadios** ficticios con público, túnel, techos y carteles.
- **Presentación**: túnel, formación y repeticiones de goles y faltas.
- **Animaciones Mixamo**: festejos, chilena, caídas, gestos del arquero.
- **Menús estilo WE**: liga y copa con los 8 equipos, benchmark de FPS.
- **Entrenamiento (Club House)**: práctica libre, pelota parada y desafíos
  con récord.

### Backlog B1–B9 (PR #24)
1. **Bugs**: foco del menú de cambios, retro que caminaban para atrás, L1
   cambia al instante, lateral automático a los 6 s, entretiempo con inercia
   y estadísticas con highlights.
2. **Camisetas y cuerpo**: número, diseño y escudo pintados en la tela
   (adelante sólo el escudo); cuerpo low-poly estilo WE98 por defecto.
3. **Pelota y jugador**: conducción por toques sin hueco; las gambetas mueven
   la pelota de verdad.
4. **Animaciones**: zurdos, pases sin giros bruscos, cabezazo de primera a
   tiempo.
5. **Arquero**: la estirada no flota y sale a tiempo; no ataja lo que le pasa
   por arriba; se agacha en las rasantes; no persigue su propio rebote.
6. **Ataque**: la IA ocupa el área en los centros; remate potente
   (L1 + R1 + Cuadrado).
7. **Gráficos**: césped mate, túnel iluminado, vincha sin brillo, red que se
   infla.
8. **Cinemáticas**: calentamiento (rondos 4 contra 1, arqueros), presentación
   de los 11 con cartel, repetición del offside con la línea.
9. **UI y datos**: íconos del mando, cambio de controles guardado, formación
   animada, nombre flotante chico, ficha con 15 atributos y etiquetas que
   influyen en el juego.
10. **Escenarios**: Club House como predio; estadio "Coloso del Sur" (ovalado,
    4 bandejas, anillos LED, techo traslúcido).

### Esta sesión: B10 y B11 (PR #25, #26 y #27)
- **Infraestructura**: CI con los tests y el `.exe` de Windows en cada push;
  Godot instalado solo en las sesiones de Claude; 25 skills de gamedev;
  assets en el repo (se suben a `assets/_entrada/` y Claude los procesa).
- **B10 (tu prueba)**: cancha con todas las marcas; CPU que remata (3,8 → 8,5
  remates por partido); mentalidad con L2 + cruceta; repeticiones fluidas
  con festejo y cámara del goleador; offside desde la banda; entretiempo y
  final animados (túnel, festejos, bronca, público que se va); puntajes y
  figura del partido; sombras y reflectores de noche; túnel del Coloso del
  Sur; cuerpo clásico sin aberturas; presentación prolija y entrenador de
  arqueros en el calentamiento.
- **B11 paso 1 (assets)**: 53 de 58 animaciones de Mixamo, 6 cielos HDRI,
  césped gastado (opción "Estado"), tierra y tela.
- **B11 paso 2 (correcciones)**: pelota que queda en la red, offside
  congelado, salida caminando al túnel, saludos del empate, público que se va
  por los pasillos, flecha más chica, carteles de repetición (número, nombre,
  tarjeta) y del partido (grandes), indicador de mentalidad.
- **B11 paso 3 (pelota parada a la WE2002)**: carrera en tiros libres,
  córners y penales; tiro libre según el stick (colocado, rasante, cañonazo,
  comba, globito, al palo) con la mira en el stick derecho; penal de 5
  direcciones; arquero sobre la línea que elige el lado; tierra en estadios
  humildes; tela en camisetas y trapos.
- **B11 paso 4 (tus sonidos)**: 16 sonidos tuyos recortados y en OGG
  (silbato, pase, palo, "uhh", gol + canto, silbidos, tribuna, cánticos,
  ambiente previo, vuvuzelas, final, menú) más aplausos, swoosh y música
  generados.
- **Arreglos de tus pruebas**: el cambio en la previa cerraba el juego; la
  red no se movía en el gol; el arquero corría la pelota que se fue afuera;
  el pateador quedaba trabado al entretiempo.

### Cosas para tener en cuenta
- **Animaciones de atajada**: los rangos de agachado y en el aire se
  ajustaron sin ver las animaciones reales; conviene mirarlas jugando.
- **Faltan 4 clips de Mixamo**: Kick Soccerball, Soccer Tackle 1, Receive
  Soccerball y Goalkeeper Body Block (esos gestos siguen por código).
- **Sonidos**: los recortes se eligieron midiendo el volumen, sin
  escucharlos; revisalos al jugar. Los generados (aplausos, swoosh, música)
  son los más inciertos.
- **Tests intermitentes**: se arreglaron dos (entretiempo con el pateador
  trabado; horario "al azar"). Si alguno falla una sola vez, avisar.
- **Capturas de Claude**: son en modo compatibilidad; en tu PC (Forward+) la
  luz y las sombras se ven distinto.

### Próximos pasos (en orden)
1. **Tu prueba** de los Pasos A (jugabilidad WE2002), B (jugadores), UI-1
   (pantallas) y C (equipos reales, Mundial).
2. **Tu archivo de planteles** (CSV de EA FC 26 / SoFIFA y Transfermarkt,
   ver `docs/BASE_DE_DATOS.md`): se importa y reemplaza los planteles
   generados. La lista de clubes 2026 de Argentina que pasaste se carga
   desde el Editor (Importar > Clubes y divisiones).
3. **Paso D — Liga Master**: **D1** (hecho: carrera y temporadas), **D2**
   (hecho: tarjetas, lesiones, evolución, retiros y juveniles), **D3**
   (hecho: Plantel, Dirección guardada, Calendario y escudos), **D4**
   (hecho: mercado de pases con puntos WE, préstamos, ventanas, IA que
   ficha) y **D5** (hecho: noticias, historial y palmarés).
4. **Fase 7 — Torneos**: hecho con las copas reales (Copa Argentina con
   fase preliminar, Trofeo de Campeones, Supercopa Argentina, FA Cup, EFL
   Cup, Champions/Europa/Conference con fase liga de 36, Libertadores,
   Sudamericana, Concachampions, Recopa, Supercopa de Europa,
   Intercontinental, Mundial de Clubes) y Mundial cada 4 temporadas;
   pendiente de tu prueba. Para que haya más clubes reales en las copas
   continentales, sumar ligas (Uruguay, Colombia, Francia...) desde el Editor.
5. Himno propio, relator y pulido final.
6. Editores: ya hechos (E1–E4, ver `docs/EDITOR.md`); quedan solo extras
   que vayan surgiendo de tus pruebas.

---

## Fase 7 — Torneos (en la Liga Master)
Las copas se juegan **entre fechas de la liga** (la pantalla de la carrera
avisa "Copa Libertadores · Octavos de final · ida"). Tu partido lo jugás o
lo simulás; las fechas en las que tu club no juega se simulan solas.
Clasificar depende de la **temporada anterior** de la carrera (en la
primera, del nivel de los equipos). Código: `scripts/competition/career_cups.gd`
(qué se juega y quién clasifica) y `competition.gd` (formatos).

**Formatos nuevos** (sirven para cualquier copa):
- Entrada escalonada: los de las divisiones de abajo arrancan en rondas
  previas y los de arriba entran después; sorteo en cada ronda.
- Llaves de ida y vuelta por resultado global (sin gol de visitante;
  penales si hay empate), con la final a partido único.
- Grupos de 4 de ida y vuelta, y fase liga de 36 (8 partidos, 2 rivales
  de cada bombo, sin cruces del mismo país cuando se puede).

**Copas nacionales**
- **Copa Argentina** (formato real 2026): los 30 de Primera y los 15
  mejores de la Primera Nacional entran directo a 32avos; Primera B y
  Primera C juegan la **fase preliminar** (2 rondas) por los otros 19
  lugares. Los 10 cupos del Federal A, que no está en la base, también
  salen de la preliminar. Partido único con penales.
- **Trofeo de Campeones**: campeón del Apertura (1.ª rueda de la liga)
  contra campeón del Clausura (2.ª rueda); se juega antes de la 1.ª fecha
  de la temporada siguiente. Si es el mismo club, juega con el mejor de la
  tabla anual.
- **Supercopa Argentina**: ganador del Trofeo contra el campeón de la Copa
  Argentina (si es el mismo, contra el finalista).
- La **Copa de la Liga** no está: desde 2026 no se juega.
- Inglaterra: **FA Cup** (los 92; Premier y Championship entran en la 3.ª
  ronda), **EFL Cup** (los 8 mejores de la Premier entran en 16avos) y
  **Community Shield**.
- España: **Copa del Rey** y **Supercopa de España** (4 equipos, a mitad
  de temporada). Italia: **Coppa Italia** y **Supercoppa Italiana** (4
  equipos).
- Alemania: **DFB-Pokal** y **DFL-Supercup**. Portugal: **Taça de
  Portugal**, **Taça da Liga** y **Supertaça**. Países Bajos: **KNVB
  Beker** y **Johan Cruijff Schaal**. Brasil: **Copa do Brasil** y
  **Supercopa do Brasil**. México: **Campeón de Campeones** (la Copa MX ya
  no se juega).

**Copas continentales**
- **Champions, Europa League y Conference**: 36 equipos con fase liga.
  Del 1.º al 8.º van a octavos y del 9.º al 24.º al playoff; las llaves son
  de ida y vuelta.
  - Cupos por la tabla: Inglaterra, España, Italia y Alemania 4/1/1;
    Portugal 2/1/1; Países Bajos 2/1/2.
  - El campeón de copa nacional va a la Europa League; el de la EFL Cup, a
    la Conference.
  - El campeón de la Champions y el de la Europa League entran a la
    Champions; el de la Conference, a la Europa League.
- **Libertadores**: 8 grupos de 4 de ida y vuelta, octavos por sorteo (1.º
  contra 2.º) y final única. Argentina: 5 por tabla y el campeón de la Copa
  Argentina; Brasil: 6 + la copa.
- **Sudamericana**: los 8 terceros de la Libertadores juegan el playoff
  contra los 2.º de grupo; los 1.º esperan en octavos.
- **Concachampions**: 16 equipos con llaves de ida y vuelta.
- **Nunca entran clubes del ascenso**: solo los de primera división.
  - Sudamérica: además de Argentina y Brasil, la base trae las primeras
    2026 de Uruguay (16 clubes), Paraguay (12), Chile (16), Colombia (20),
    Ecuador (16), Perú (18), Bolivia (16) y Venezuela (14), con colores y
    estadios reales (planteles generados hasta que importes los tuyos).
  - Cupos: Argentina 5 + Copa Argentina a la Libertadores y 6 a la
    Sudamericana; Brasil 6 y 6; el resto, 2 y 2. Los lugares que en la
    realidad salen de las fases previas los ocupan los mejores de primera
    que no clasificaron.
  - Se pueden elegir también en Liga/Copa y partidos sueltos.
- Las copas de las otras confederaciones se simulan al final de cada
  temporada, para la Intercontinental y el Mundial de Clubes.

**Copas entre campeones**
- **Supercopa de Europa**: partido único. **Recopa Sudamericana**: ida y
  vuelta.
- **Copa Intercontinental FIFA**: el campeón de la Libertadores juega con
  el de la Concachampions (Derbi de las Américas) y el ganador juega la
  final con el campeón de la Champions.
- **Mundial de Clubes** cada 4 años desde 2029, antes de la temporada: 32
  equipos en 8 grupos de 4 (Europa 16, Sudamérica 10, Concacaf 6).
  Clasifican los campeones continentales de las últimas 4 temporadas y los
  mejores de cada confederación.

**Premios en puntos WE**: Champions y Libertadores 8000; Europa League y
Sudamericana 5000; Concachampions 5000; Conference 3500; Mundial de Clubes
10000; Intercontinental 6000; copa nacional 3000; copa de la liga 2000;
supercopas entre 1500 y 2500.

**Mundial de selecciones** cada 4 años (2030, 2034...), al terminar la
temporada y simulado. La selección del país se arma con los mejores 23
entre su plantel y los jugadores de la carrera de esa nacionalidad; te
avisa a quiénes de tu club convocaron.

**Pantalla de la carrera**
- Vista **Copas** con un selector de copa: estado, tus partidos (con el
  global y los penales), la tabla de la fase liga con sus zonas, los grupos
  o la ronda de la llave.
- El resumen de fin de temporada y el **Historial** muestran los campeones
  de todas las copas, los títulos de tu club y el récord de goles.
- En el menú principal dice **MUNDIAL** (sin el año).

## D5 — Liga Master: noticias, historial y palmarés
- **Noticias** (Ver ◀ ▶ en la pantalla de la carrera): lesiones y
  suspensiones de tu plantel, tus pases, los **bombazos** del mercado (los
  tres más caros de cada ventana), campeones de cada división, cómo te fue,
  retiros y juveniles. Con la temporada y la fecha de cada una.
- **Historial**: el **palmarés** de tu club (títulos, ascensos y descensos),
  una fila por temporada (año, división, posición, campeón / ascenso /
  descenso y el goleador del club) y los clubes con más títulos de la
  carrera.

## D4 — Liga Master: mercado de pases (puntos WE)
- **Mercado de pases** (botón en la pantalla de la carrera y en el resumen
  de fin de temporada). Abre en las **primeras 4 fechas**, en las **4
  alrededor de la mitad** y al **terminar la temporada**; si está cerrado,
  dice cuándo abre.
- **Comprar**: todos los jugadores del país, con filtros (puesto, división)
  y orden (media, edad, precio). El **precio** sale de la media y la edad
  (los jóvenes valen más; desde los 32, mucho menos) y el club pide 50 %
  más por sus tres mejores. Se puede **pagar lo que piden**, **ofertar el 80
  %** (aceptan a veces) o pedirlo a **préstamo** hasta fin de temporada (un
  cuarto del valor; vuelve solo a su club).
- **Vender**: un club al que le falta ese puesto ofrece entre 70 y 110 % del
  valor (aceptás o no); también **dejar libre** o devolver un préstamo.
- Límites: tu plantel entre 16 y 30 (al partido van 23); un club no vende
  si le quedan 18 o menos.
- **Los otros clubes también fichan** en la pretemporada y a mitad de
  temporada (uno de cada cuatro, de su división o de la de abajo; el que
  vende repone con un juvenil).
- **Pases de la temporada**: la lista de todo el país, con los tuyos en
  dorado.

## D3 — Liga Master: Plantel, Dirección y Calendario; escudos propios
- **Plantel y Dirección** (botón en la pantalla de la carrera): la
  formación (◀ ▶) y los 23, con los 11 titulares arriba en el orden de los
  puestos, edad, media, goles y estado (rojo: lesionado o suspendido). X
  sobre un jugador y después sobre otro: se cambian. **Queda guardado** para
  todos los partidos; si un titular no puede jugar, entra el mejor libre de
  su puesto y al volver recupera su lugar. "Mejor once" vuelve a lo
  automático. A la derecha, la ficha con los atributos y **cuánto cambió
  cada uno en la temporada**.
- **Calendario** (Ver ◀ ▶ en la pantalla de la carrera): tus partidos con
  local / visitante, rival y resultado (verde ganado, rojo perdido) y la
  próxima fecha marcada.
- **Fixture**: localías alternadas como en las tablas de Berger (nadie
  juega más de dos fechas seguidas de local o de visitante).
- **Escudos propios**: Editor → Camisetas → "Importar escudo (PNG)". Se
  guarda en la carpeta del Option File y se ve en los menús, la elección de
  equipos, las tablas y la previa. Las carreras nuevas lo toman al crearse.

## D2 — Liga Master: el plantel con el paso del tiempo
- **Tarjetas y suspensiones**: 5 amarillas = 1 fecha; roja (o doble
  amarilla) = 1 fecha, a veces 2. En tu partido cuentan las que sacó el
  árbitro; en el resto, simuladas (más a los defensores y volantes
  centrales).
- **Lesiones**: en tu partido, las del juego (un golpe a veces deja afuera
  una fecha; una lesión, de 1 a 3 casi siempre, a veces hasta 8 y rara vez
  hasta 20); en los simulados, al azar.
- Los lesionados y suspendidos **no entran en el once** (quedan al final del
  plantel) y la pantalla de la carrera muestra tus bajas. Cumplen las fechas
  solas.
- **Cambio de año** (al terminar la temporada): todos cumplen un año; los
  atributos suben hasta los 26, se mantienen hasta los 29 y bajan desde los
  30 (los físicos, un poco más). **Retiros** desde los 33 (los arqueros
  desde los 35; a los 39, seguro). Cada club **repone con juveniles** de 17
  a 19 años hasta tener 23, con los puestos que le faltan.
- El resumen de fin de temporada muestra tu plantel: quiénes se retiraron,
  los juveniles nuevos y los que más crecieron.

## D1 — Liga Master: carrera y temporadas
- **LIGA MASTER** en el menú: elegís país (los que tienen más de una
  división), tu club y el plantel: **Plantel real** o **Equipo WE**
  (jugadores genéricos con el nombre y la camiseta de tu club; obligatorio
  con un club de primera).
- Arrancás en la **Primera C** (Argentina), **League Two** (Inglaterra) o
  la **2.ª** (el resto). Si tu club juega más arriba, baja a esa división y
  sube un club de cada división de por medio (las ligas no cambian de
  tamaño).
- Cada carrera tiene sus propios planteles (fijados al crearla, cada
  jugador con su número único): los ascensos no los cambian y las etapas
  siguientes (lesiones, pases, evolución) los van a modificar.
- **Temporada completa**: todas las divisiones a la vez, ida y vuelta, con
  las fechas reales (46 en la Primera C, 70 en la Primera Nacional, 38 en
  la Premier). Tu partido lo jugás o lo simulás; el resto se simula.
- Pantalla de la carrera: tabla de cualquier división (◀ ▶) con la zona de
  ascenso en verde y la de descenso en rojo, **goleadores** (los de tu
  partido son los reales; el resto, según puesto y remate), **puntos WE**
  (victoria 400, empate 200, derrota 100, 50 por gol, 3000 el título, 2000
  el ascenso; se gastan en el mercado, D3), próximo partido y últimos
  resultados.
- **Fin de temporada**: campeón y goleador de cada división, quiénes suben y
  quiénes bajan, cómo te fue. Ascensos y descensos automáticos: 3 en
  Inglaterra y 2 en el resto, **editable** en el Editor (Ligas → "Bajan a
  la de abajo").
- Se guarda sola después de cada fecha en `saves/master` y se sigue desde
  **CONTINUAR**.

## E1 y E2 — Option File, partidas y Editor (PR #31)
- **Carpeta del jugador** `Documentos/MasterEleven/`: configuración,
  botones, Option Files, partidas (`saves/ligas`, `saves/copas`,
  `saves/master`), `importar/` y récords. Lo de versiones anteriores se
  mueve solo.
- **Option File** (`.meof`): sólo tus cambios sobre la base (clubes y
  selecciones editados o nuevos, divisiones, borrados). OPCIONES → DATOS
  elige el activo, importa planteles desde la carpeta `importar` y abre las
  carpetas. Detalle en `docs/BASE_DE_DATOS.md`.
- **Partidas separadas**: cada Liga, Copa y Mundial en su archivo;
  **CONTINUAR** (menú principal) las lista con dónde van y activa el Option
  File con el que se crearon.
- **Editor** (`MasterEleven Editor.exe` o EDITOR en el menú): jugadores
  (uno o varios a la vez, edición masiva), equipos (datos, camisetas en
  texto, orden del plantel, altas, bajas y pases), selecciones
  (convocatorias, nuevas, borradas), ligas (pasar de división, clubes
  nuevos), copas propias (se juegan desde COPA), camisetas (colores, diseño,
  plantilla PNG para pintar, vista 3D) e importar. Guía en `docs/EDITOR.md`.

## Paso C — Base de datos real y Mundial 2026 (PR #31)

Detalle, fuentes y formato del CSV en `docs/BASE_DE_DATOS.md`. Tests en
`tests/unit/test_team_db.gd` y `test_import_players.gd`.
- **59 selecciones** con bandera (dibujada por código), camisetas titular y
  suplente con su diseño, color de arquero, formación y nivel: las 48 del
  Mundial 2026 (42 seguras + las 12 candidatas del repechaje que pasaste) más
  China, Rusia, Nigeria, Camerún y Turquía.
- **9 países, 18 divisiones, 394 clubes reales**: Inglaterra (4),
  España (2), Italia (2), Alemania (2), Portugal, Países Bajos, México,
  Brasil y Argentina (4). Cada uno con sus colores, camisetas reales (rayas,
  bastones, franja de Boca, banda de River, V de Vélez, cuadros...), medias,
  estadio y capacidad.
- **Planteles**: generados (estables, nombres del país, nivel según la
  división) hasta que llegue tu archivo. **Importador** de CSV (EA FC /
  SoFIFA, Transfermarkt o planilla propia): `godot --headless --
  --import-players=archivo.csv`; convierte los atributos de FC a los del
  juego y arma las selecciones por nacionalidad.
- **Elección de equipos por grupos**: Selecciones, cada división de cada país
  y Equipos WE; L1/R1 (Q/E) cambian de grupo; banderas para las selecciones
  y escudos con el diseño de la camiseta; la camiseta del panel muestra su
  diseño.
- **Liga y Copa con equipos reales**: con un club, la Liga es toda su
  división (tabla con desplazamiento); la Copa, 8 de su grupo.
- **Mundial 2026** (menú principal): eliges los 6 cupos del repechaje y tu
  selección; sorteo por bombos (anfitriones al frente), 12 grupos de 4, dos
  por grupo + 8 mejores terceros, 16avos hasta la final.
- **Estadio del local**: con un club real y el estadio "al azar", su estadio
  con nombre real ("EN VIVO — La Bombonera") y forma según la capacidad.
- Nuevos diseños de camiseta en el cuerpo 3D: franja en el pecho, V y
  cuadros; las medias pueden ser de otro color que la camiseta.

## Paso UI-1 — Pantallas como el WE2002 (PR #31)

Detalle por pantalla en `docs/UI_WE2002.md`. Tests en `tests/unit/test_ui1.gd`.
- **Título**: al abrir el juego, estadio de alambre azul que gira, logo
  "MASTER ELEVEN" amarillo y rojo, "Press START Button" titilando y
  "© 2026 VirtualFutsal". Start / Aceptar pasa al menú (al volver de un
  partido no aparece).
- **Partido > Tanda de penales**: sólo la definición, en el estadio elegido.
  Cinco por equipo alternados (los mejores definidores primero, el elegido
  para los penales encabeza) y muerte súbita; los demás esperan en el
  círculo central. Arriba, el marcador con ● gol / ○ errado. Al final,
  Aceptar o Start vuelven al menú.
- **Elección de equipos**: leyenda fija de botones (□ Al azar · ✕ Aceptar ·
  ○ Volver).
- **Dirección del equipo**: puestos como en el WE (GK, CB, LB, RB, DMF, CMF,
  LMF, RMF, AMF, WG, CF; también en la presentación y las repeticiones);
  pateadores separados: **TL corto** (a menos de 25 m) y **TL largo**,
  **córner izquierdo** y **derecho** (si falta uno, patea el otro);
  **Copiar estrategia**: guardar / cargar la formación, los 4 botones de
  estrategia, los pateadores y el capitán de ese equipo.
- **Presentación**: cartel con los dos equipos y recuadro rojo "EN VIVO"
  con estadio y clima en el calentamiento; bandera gigante del local
  (flameando) atrás de la fila; **foto del equipo** del jugador 1 (dos
  filas, flash) antes de las formaciones. Las selecciones van a traer su
  bandera real (campo `flag` en el equipo, Paso C).
- **HUD**: número de mando (1, 2) al lado de la flecha del controlado.
- **Pelota parada**: cartel 3D con los metros al arco ("23M") en el tiro
  libre con la cámara atrás.
- **Pausa**: "PAUSA — MANDO N" (el que apretó Start), Cámara (◀ ▶),
  submenúes **Pantalla** (radar, marcador y reloj, etiquetas), **Sonido**
  (efectos, público) y **Opciones de juego** (formación, dificultad,
  movimiento, velocidad, arquero).
- **Resultado**: título "RESULTADO", goles de cada tiempo ("1T 1-0  2T 0-2")
  y filas nuevas de tiros libres y penales (además de offsides).

## Paso B — Jugadores low-poly estilo WE mejorados (PR #30)

Detalle y estado de cada punto en `docs/JUGADORES_WE2002.md`.

| Qué | Cambio |
|---|---|
| Cuerpo paramétrico | En vez de 7 moldes fijos, cada jugador tiene estatura en cm (155–205), masa, músculo, hombros y largo de piernas, que salen de su físico (letras A–G del WE), sus atributos (fuerza, balance) y una variación propia: dos "normales" ya no son iguales. Escala desde la cadera; con piernas largas la cadera sube (los pies siguen en el piso) y las animaciones compensan el paso. La estatura en cm cuenta también en el juego (cabezazos, cuerpo a cuerpo). |
| Identidad guardada | Piel A–D, color de pelo (7), barba/bigote (de tres días, bigote, candado, completa) y su color, botines A–H, nacionalidad, puesto detallado y pie **ambidiestro** (sin pierna mala). Lo que no está cargado sale estable por jugador (antes piel y pelo cambiaban en cada partido). |
| Malla más fina | Cuerpo clásico de 1600 triángulos (antes ~1000): pecho, trapecio, glúteo, rodilla, pantorrilla, antebrazo, manos con pulgar, mandíbula, nariz y orejas. Siguen las caras planas del estilo WE. |
| Cara | Ojos, cejas, nariz, boca y barba dibujados sobre la cabeza (la barba sigue la mandíbula, con patillas). |
| Ropa | Mapeo UV real de camiseta, mangas, short y medias (`docs/KIT_UV.md`, base del editor de camisetas). Manga larga con lluvia o nieve (de noche la mitad; arqueros casi siempre). Número en el short. |
| Pelo | El cuerpo clásico muestra el peinado de cada jugador (antes, un casquete igual para todos). Mechones con textura de hebras y transparencia (menos "plastilina", también en los Detallados). 5 peinados nuevos: afro, trenzas pegadas, flequillo, copete y corto con raya al costado (14 en total). |

Herramientas: `--poses=...body.png` (cuerpos de 1,60 a 2,03 m),
`...face.png` (caras y barbas), `...uvtest.png` (mapeo UV), `...hair.png`.

Tests: `test_backlog_b15.gd` (10). `test_model_visual` admite la malla nueva
(hasta 2500 triángulos) y `test_we_combos` usa la estatura en cm.

---

## Paso A — Jugabilidad WE2002 (PR #30)

| Qué | Cambio |
|---|---|
| Potencia de remate 6–9 | El atributo se lee como el nivel del WE (30 → 5, 58 → 7, 70 → 8, 85 o más → 9) y se muestra en la ficha, p. ej. "78 (8)". En jugada, el 9 sale ~30 % más fuerte que el 6 (antes ±8 %). De más de 24 m, con potencia menor a 8 la pelota pierde fuerza (hasta 16 % a 40 m); con 8 o más llega entera y más recta. También en los tiros libres. |
| Remate en carrera | La velocidad del que patea cuenta: a toda carrera la pelota sale hasta 0,55 m más alta y con 35 % más de error; parado, 10 % más preciso. |
| Defensores que leen el pase en profundidad | La marca se adelanta a la carrera del delantero que pica hacia el arco (según defensa y respuesta). Con un pase al hueco rival en el aire, el defensor que mejor lo lee sale a cortar la línea del pase si llega a tiempo (además del que va a la pelota). |
| Despeje a fondo | Llega a 50 m (más con los fuertes): desde el área propia cae en el campo rival. |
| Rebotes jugables | El arquero que da rebote a veces la deja adelante, en el área (15 % un buen arquero, hasta 45 % uno flojo; más con remates muy fuertes), para el segundo atacante. |
| Cámara Lejana | Nueva cámara "Lejana" (como la Normal Far del WE): más alta y lejos, con el nombre de todos los jugadores. También hay una opción de etiquetas "nombres de todos" para cualquier cámara. |

CPU vs CPU (6 partidos, semillas fijas): 8,5 remates y 2,0 goles por
partido (antes, 3 partidos: 11 remates y 1,0 gol). Pocas muestras: hay que
confirmarlo jugando.

Tests: `test_backlog_b14.gd` (8). `test_camera` cuenta 7 cámaras.

---

## Backlog B12 — correcciones de tu prueba de B11 (PR #29)

| Pedido | Cambio |
|---|---|
| Sonido de "fritura" al cobrar una falta | Era el "swoosh" generado de la repetición (cada falta tiene repetición): ruido blanco que se abría a los agudos. Ahora es un "whoosh" de aire grave (pasabanda de 250 a 1200 Hz) y más bajo. |
| El ganador no festejaba al final | El gesto duraba 3 s de una toma de 7,5 s. Ahora la mitad del equipo (y el arquero) corre a juntarse y hace festejos de gol; el resto salta con los brazos arriba toda la toma, y la cámara los enfoca. |
| Entretiempo: alejar la cámara | Toma aérea con la cancha completa, alternada cada 3,5 s con una toma desde adentro del túnel viéndolos venir. |
| Animación de los cambios | El suplente espera en la mitad de cancha junto al **cuarto árbitro** (con el cartel luminoso). El que sale camina hasta ahí y chocan las manos, se dan la mano o nada; si está a más de 25 m sale por la línea más cercana. Después el que entra corre a su puesto. El reloj se detiene y el juego no se reanuda hasta que termina (tope de 12 s). Cámara sobre el cambio. En el saque del medio el cambio sigue siendo directo. |
| El público desaparecía al irse | Las tribunas tienen **escaleras** (pasillos sin butacas, con medio escalón) y **bocas de salida** (vomitorios) en la mitad de cada bandeja. Cada persona camina por su fila hasta la escalera con boca más cercana, baja o sube hasta la boca y entra. También en el Coloso del Sur (escaleras radiales parejas). |

Tests: `test_backlog_b13.gd` (7). Se actualizaron `test_substitutions` y
`test_fouls_keeper` (el cambio ahora es animado) y `test_backlog_b10` (el
ganador festeja corriendo a juntarse).

---

## Backlog B11 — pasos 3 y 4: pelota parada a la WE2002, tierra, tela y sonidos (PR #27)

### Pelota parada
- **Carrera**: en tiros libres, córners y penales el pateador se para atrás
  de la pelota (no gira en el lugar) y al apretar el botón toma carrera y le
  pega al llegar. Lo que tengas apretado **en el momento del contacto** decide
  el remate.
- **Tiro libre** (en campo rival, cámara atrás del pateador): el **stick
  derecho gira la mira** (flecha amarilla en el pasto) y la cámara con ella.
  - Cuadrado solo: remate normal.
  - Atrás + Cuadrado: colocado, sube por encima de la barrera y cae (ideal
    potencia de remate 7; con 8 o más sale más recto).
  - Adelante + toque corto de Cuadrado: rasante por debajo de la barrera.
  - Adelante + Cuadrado cargado: cañonazo casi recto (rinde con potencia 8+).
  - Costado (o arriba + costado) + Cuadrado: comba hacia ese lado (según la
    "curva" del jugador).
  - Círculo suave: globito al segundo palo; atrás + Círculo a fondo: rasante
    fuerte al palo del arquero.
  - Cuentan potencia de remate, precisión y curva; "especialista" erra menos.
- **Penal**: 5 direcciones con el stick izquierdo al patear (arriba o abajo a
  cada lado, o al medio sin stick). Más fuerza = más alta; pasada (>92 %) se
  va por arriba. Los malos pateadores erran más; "penales" ayuda.
- **Arquero en el penal**: espera sobre la línea (ya no sale a buscar al
  pateador). Si lo manejás, elegí el lado con el stick al momento del remate;
  si adivina, la atajada depende de la altura y su atributo.
- Córners y tiros libres sin cámara: la comba del stick derecho se aplica al
  patear, después de la carrera.

### Visual
- **Tierra** en las zonas peladas (frente a los arcos, punto penal y centro)
  en el Gran Coliseo del Plata, el Club House y con la cancha "Gastada".
- **Trama de tela** en camisetas, shorts y en los trapos de la tribuna.

### Sonidos (generados por código)
- Silbidos de la hinchada en las faltas y más fuertes en las tarjetas.
- Cánticos con bombo de fondo que arrancan cada tanto.
- Aplausos cuando sale un jugador reemplazado.
- "Swoosh" en la cortina de la repetición.
- Música en los menúes (Opciones → *Volumen de la música*).

### Arreglos de tu prueba
- **Hacer un cambio antes del partido cerraba el juego**: el calentamiento
  seguía usando al titular que se iba. Ahora el suplente toma su lugar.
- **La red no se movía en el gol**: en vivo la cámara ya se iba al goleador y
  la repetición no la hacía temblar. Ahora se graba el golpe en la red y se
  repite; además la red se infla más y tarda más en volver.
- **El arquero seguía corriendo la pelota que se fue afuera**: al salir se
  borra el plan de atajada y, con el juego detenido, vuelve caminando a su arco.
- Si el tiempo terminaba con una pelota parada armada, el pateador quedaba
  trabado y no se iba al túnel.
- El error "Format not supported for WAVE file" venía de tu copia local de
  `whistle final partido.wav` (8 canales, 96 kHz, 32 bits: Godot no lo
  importa). Si tenés una carpeta `sonidos/` en tu proyecto local, borrala:
  ya están todos convertidos en `assets/audio/`.

### Tus sonidos (paso 4)
Recortados a la parte útil y pasados a OGG (de ~90 MB a 3,2 MB) en
`assets/audio/` (detalle en `assets/CREDITS.md`): silbato y pitazo final,
pase, palo, "uhh", grito de gol + la hinchada cantando después, silbidos
contra el árbitro, tribuna y cánticos de fondo, ambiente previo en la
presentación, vuvuzelas al salir, festejo al final y los sonidos del menú.
Los que no tienen archivo (aplausos, swoosh, música del menú, bombo del Club
House) siguen generados por código.

Tests: `tests/unit/test_backlog_b12.gd` (15 tests).

---

## Backlog B11 — pasos 1 y 2: assets y correcciones (PR #26)

### Paso 1: tus assets
| Qué | Cambio |
|---|---|
| Animaciones | `MixamoLibrary` busca los FBX en `assets/animations/` (y en `mixamo/`): 53 de 58 clips. Faltan Kick Soccerball, Soccer Tackle 1, Receive Soccerball y Goalkeeper Body Block. |
| Cielos | Los 6 de ambientCG en JPG 2K (`assets/skies/`, 1,7 MB; los EXR pesaban 100 MB). |
| Texturas | Césped gastado (Poliigon GrassPatchyGround), tierra (GroundFieldAgriculture) y trama de tela. `assets/_entrada/` pasó de 163 MB a 7 MB. |
| Césped gastado | Opción "Estado" en la configuración del partido; siempre en el Club House. |

### Paso 2: correcciones de tu prueba
| Pedido | Cambio |
|---|---|
| La pelota no entraba en la red | El fondo de la red la devuelve un poco (12 %) y adentro del arco se frena; la cámara del gol muestra la pelota en la red 1,2 s antes de ir con el goleador. |
| Offside: seguían moviéndose | En la pausa de la repetición todos quedan quietos. |
| Entretiempo al trote y trabados en el túnel | Caminando y en fila hasta adentro, sin empujarse en la boca. |
| Empate | Cada uno saluda al más cercano (rival: apretón de manos; compañero: choque de manos). |
| Público que desaparece | Se para, camina por la fila al pasillo, sube a la salida y recién ahí desaparece. |
| Flecha del jugador | A la mitad del tamaño. |
| Carteles de repetición | Gol, falta, remate: número y nombre; offside: nada; tarjeta dibujada delante del nombre. |
| Carteles del partido | Más grandes, mayúsculas, letra gruesa con borde. |
| Mentalidad | Cuadrado con tres barras (rojo ofensiva, verde equilibrada, azul defensiva) al lado del jugador, con la estrategia activa arriba. |

Tests: `test_backlog_b11.gd` (6).

---

## Backlog B10 e infraestructura (PR #25)

### Infraestructura

| Tema | Cambio |
|---|---|
| Tests automáticos | `.github/workflows/ci.yml`: en cada push y PR, GitHub corre los tests de GUT con Godot 4.7.2 sin pantalla (~3 min). Un push nuevo cancela la corrida anterior de la misma rama. |
| .exe de prueba | El mismo workflow exporta el preset **Windows Desktop** (`export_presets.cfg`): un solo `MasterEleven.exe` con todo adentro. Se baja desde GitHub → *Actions* → la corrida → *Artifacts* (se guarda 30 días). |
| Sesiones en la nube | `.claude/hooks/session-start.sh` instala Godot e importa el proyecto, así Claude corre los tests y saca capturas en cada sesión. |
| Skills de desarrollo de juegos | 25 skills de `awesome-gamedev-agent-skills` (Apache 2.0) en `.claude/skills/` (Godot 3D, animación, audio, export, shaders, UI, IA, game feel, cámara, rendimiento...). Se activan solas en las sesiones de Claude Code. |
| Assets en el repo | Mixamo y las texturas ya no están en el `.gitignore`. Los zips/fbx/sonidos se dejan tal cual en `assets/_entrada/` (ver su LEEME) y Claude los procesa. El césped fotográfico pasó de 4K (24 MB) a 2K (1,4 MB). |
| Cielos HDRI | `SkyTextures`: si hay un cielo en `assets/skies/` (despejado, amanecer_invierno, atardecer, nublado, nublado2, nieve) se usa según horario y clima; si no, el procedural. **Faltan los archivos** (ver más abajo). |
| Capturas | `capture_runner.gd --shot=x,y,z,mx,my,mz[,fov]`: una toma fija sin jugadores (para revisar estadios, luces, túnel). |

### Tu lista (B10)

| Pedido | Cambio |
|---|---|
| Entrenamiento: al tirar un centro los compañeros se iban a la línea de su arco | La "línea del offside" daba 0 sin defensores de campo (= tu propio arco). Ahora nunca queda detrás de la mitad ni de la pelota, y sin offside (o en el entrenamiento) no limita. |
| La pelota se frena sobre la línea en el gol | La repetición dejaba de grabar 0,8 s después de cruzar la línea: en un remate lento terminaba con la pelota en la línea. Ahora sigue 3 s después (se ve la red). |
| Dirección del equipo: al cambiar la formación el cursor se iba al final | El foco queda en *Formación*. |
| Repeticiones a los tirones, cortadas | Interpolan entre cuadros (sin tirones en cámara lenta). Arrancan cuando empezó la acción (entre 3 y 6 s antes) y siguen 3 s después. |
| Gol: repetir también el festejo desde otro ángulo | Después de la repetición del gol, el festejo de frente al goleador (lo sigue la cámara). |
| Gol: la cámara con el goleador | Apenas es gol, la cámara lo persigue en plano medio mientras corre y festeja; después la repetición. |
| Offside de costado y lejos, en el momento justo | Toma desde la banda, lejos, que muestra al que pasa y al adelantado; se congela 1,4 s en el pase con la línea. |
| Entretiempo: que espere | La pantalla espera siempre (también CPU vs CPU) y los botones no responden el primer 1,5 s (si venías apretando X no se saltea sola). |
| Final: puntajes en lugar de Dirección del equipo | `PlayerRatings`: pases, asistencias, remates, quites, intercepciones, atajadas, goles recibidos, faltas y tarjetas de cada jugador; puntaje de 1 a 10 y **figura del partido**. En el final, "Puntajes de los jugadores". |
| Fin del 1er tiempo: que se vayan al túnel | Caminando al túnel; de a dos charlan; uno va a hablar con el árbitro. En la pantalla del entretiempo la cancha queda vacía (vuelven para el 2º tiempo). |
| Final: festejos y bronca | Los que ganan levantan los brazos o aplauden; los que pierden se tiran al piso, se agarran la cabeza, quedan cabizbajos o le protestan al árbitro (hasta dos). Empate: aplausos y cabizbajos. Después, la pantalla con la cancha vacía y **la gente que se va yendo** (en 90 s). |
| Árbitro en el saque del medio | Al costado del círculo central, del lado de enfrente de la cámara, en el campo del que saca. |
| Canchas dibujadas con todas las marcas | `PitchMarkings`: área chica, punto penal, medialuna, círculo y punto central, arcos de córner y arcos. Las usan la cancha, las canchas paralelas del Club House, el radar y la minicancha de la Dirección del equipo. |
| La CPU casi no patea; llega al área y la tira al lateral | En el área remata casi siempre (al palo libre); cerca del arco no la devuelve atrás ni al costado (sólo a uno mejor ubicado); en el último tercio encara hacia el área. CPU vs CPU (8 partidos): **3,8 → 8,5 remates por partido**, goles 1,1 → 1,0. |
| Compañeros que acompañen: 3 niveles con L2 + cruceta | **L2 + cruceta izquierda / derecha** (teclado: **R + ← / →**): mentalidad defensiva / equilibrada / ofensiva. Sube o baja el bloque, más o menos jugadores llegan al área en los centros (en ofensiva también el volante defensivo y el lateral del otro lado), más desmarques y un apoyo más por afuera. Se ve arriba a la derecha. |
| Coliseo del Sur: algo tapa el túnel | En el Coloso del Sur el muro de la cancha hundida no tenía la boca del túnel y el banco de suplentes quedaba delante. Ahora el túnel se ve y los bancos van embutidos en el muro. |
| Sombras muy fuertes; de noche, reflectores mal puestos | De noche las líneas cruzadas sobre el césped eran sombras de arcos, red, carteles y techos: ahora los reflectores sólo proyectan sombras de jugadores y pelota, y alumbran más parejo. De día la sombra del sol es más suave (los techos hacen sombra pero no oscurecen tanto). |
| Cuerpo clásico: aberturas en hombros y cuello | El cuello de la camiseta cierra contra el cuello, un hombro pegado a la clavícula tapa la unión con la manga y el ruedo de la manga cierra contra el brazo. |
| Presentación fea | La fila queda prolija (cada uno en su lugar, de frente, el árbitro al medio) y la cámara pasa más lejos (antes había jugadores caminando delante de la toma). |
| Calentamiento: entrenadores que le pateen al arquero, pelotas sueltas | Un entrenador de arqueros (de buzo) le patea desde el borde del área (toma de costado) y hay pelotas sueltas por cada área. |
| Gestos nuevos | `APPLAUD`, `HEAD_HOLD`, `HANDS_HIPS` (cabizbajo) y `PROTEST`, revisados con `--poses=...gestures.png`. |

**Tests:** 352 en verde (nuevo `test_backlog_b10.gd`, 18 tests).

### Pendiente
- [ ] **Tu prueba** de todo lo de arriba (en Forward+: las capturas de Claude son en modo compatibilidad).
- [ ] **Subir los assets**: las animaciones de Mixamo (`assets/animations/mixamo/`) y los zips de texturas y cielos en `assets/_entrada/`. Por el chat sólo llegaron 4 imágenes de muestra y el desplazamiento de *GrassPatchyGround* (no los mapas de color/normal/rugosidad).
- [ ] Animaciones "trabadas": no se pudo reproducir sin las de Mixamo (acá se ven los gestos por código). Un video corto ayudaría.
- [ ] Sonido grabado (ver la lista de bancos de sonidos en el chat de esta sesión).

## Backlog de pulido (PR #24)

| Módulo | Cambio |
|---|---|
| B1 Bugs | El foco no se pierde en el menú de cambios; jugadores "retro" de frente; L1 cambia al instante al que va a recibir (o al que llega primero, del lado del arco); el lateral se saca solo a los 6 s (cuenta regresiva en pantalla); entretiempo/final con la jugada que sigue por inercia y después la pantalla de estadísticas (posesión, remates, córners, faltas…) con cámaras que giran y los highlights; la pelota gira en las repeticiones. |
| B2 Pelota-jugador | Conducción por toques (pie alternado, la pelota sale del botín sin hueco); quien está más cerca domina; las gambetas (ruleta, bicicleta, amague) mueven la pelota de verdad y la bicicleta arranca con un pique. |
| B3 Animaciones | Zurdos (clips espejados); el cuerpo gira hacia donde va el pase; el gesto del pase depende del tipo; en los centros el que recibe cabecea de primera y el cabezazo se anticipa para llegar a tiempo. |
| Camisetas | Número, rayas/aros/mitades/banda y escudo pintados en la tela con un shader (se doblan con el cuerpo). Adelante sólo el escudo; atrás el número con contorno. |
| Cuerpo clásico | Cuerpo low-poly proporcionado al estilo WE98 (por defecto; Jugadores: Clásico / Retro / Detallado). |
| B4 Arquero | La estirada no flota (clip más rápido y desplazamiento lateral corto); se tira a tiempo (nunca después de que pasó la pelota); no hace el gesto de atajar una pelota que le pasa por arriba; se agacha en las rasantes (rango del clip de recoger); después de su rebote no la persigue en bucle. |
| B5 Ataque | Con la pelota en la banda en el último tercio, los de arriba ocupan el área: punto penal, primer palo, segundo palo y uno a la puerta del área (nunca en offside). **Remate potente: L1 + R1 + Cuadrado**: la barra carga más lento, el jugador se perfila 0,3 s y le pega 30 % más fuerte con el doble de error. La CPU también lo usa de lejos. |
| B6 Gráficos | Césped mate (rugosidad mínima 0,85 y casi sin especular: no se ve de plástico); túnel con paredes claras y cuatro paneles de luz (ya no es una cueva); vincha de tela mate sin brillo; **la red se infla donde pega la pelota** (según la velocidad) y vuelve oscilando; la pelota gira en las repeticiones (de B1). |
| B7 Cinemáticas | Calentamiento: en cada mitad dos **rondos 4 contra 1** (la pelota de utilería circula de pie en pie y el del medio la persigue) y **los arqueros en su área atajando** remates (estirada, en el aire o agachado). Presentación: cada equipo en su fila (ya no pasa uno por delante del otro) y **dolly frontal** por los 11 de cada equipo; al llegar a cada jugador aparece su cartel (número, nombre, puesto) y el público responde (señal `player_announced` para el locutor). **Repetición del offside** con la línea del penúltimo defensor sobre el césped; las atajadas en las manos quedan en los highlights; los remates cerca/al palo ya tenían repetición. |
| B8 UI | **Íconos de los botones** dibujados en el juego (cruz, círculo, cuadrado, triángulo, L1/R1/L2/R2) en las ayudas, la pantalla de equipo, el HUD y la presentación (en los textos: `{X}`, `{SQ}`...). **Dirección del equipo** rediseñada: cancha grande con fichas (número, puesto, apellido) que se deslizan a su lugar al cambiar la formación o hacer un cambio; menú con más aire y estrategias con su combinación de botones; ficha ampliada. **Cambio de controles** (Opciones > Controles): elegís la acción y apretás el botón o la tecla nueva; si otra la usaba se intercambian; Restaurar vuelve a fábrica; se guarda en `user://controls.cfg`. Nombre flotante más chico. **Ficha ampliada**: Ataque, Defensa, Balance, Estamina, Velocidad, Aceleración, Respuesta, Potencia de salto, Precisión de cabeza, Técnica, Precisión de pase, Potencia de remate, Precisión de remate, Gambeta, Curva (+ Fuerza y Arquero), altura cargada y etiquetas Gambeteador, Lanzador de tiros libres, Especialista en penales, Lanzador de córners, Muro defensivo, Atajador de penales y Capitán. Juegan: la potencia cambia la velocidad del remate, la curva la comba, el salto el alcance del cabezazo; los lanzadores patean sus pelotas paradas si no elegiste otro; el especialista en penales y el atajador de penales tienen ventaja en los once metros; el muro entra mejor. La pantalla de entretiempo es de B1. |
| B9 Escenarios | **Club House tipo predio**: la cancha principal con su alambrado, una mini tribuna con techo frente a la cámara, el edificio de los vestuarios, dos canchas paralelas sin usar (con líneas y arcos), el vallado alto del predio con el nombre del club (o MASTER ELEVEN) y su escudo, árboles frondosos (copas en racimo, tres verdes) y una franja de bosque en el horizonte. **Estadio "Coloso del Sur"** (inventado, `OvalStadiumBuilder`): cuenco ovalado de cuatro bandejas con butacas grises y cancha hundida tras un muro; anillo LED continuo (colores del club, en movimiento) entre la 1.ª y la 2.ª, anillo VIP vidriado con cabinas de TV sobre la tribuna principal, cinta LED en la 3.ª; techo traslúcido tipo PTFE con pasarela arriba y una línea roja en el borde interno, sobre 50 columnas de hormigón en V; pantallas anchas en las cabeceras; bancos embutidos y un único túnel central. Afuera, a nivel de calle: explanada, estacionamiento de 5 pisos con dos puentes al estadio, museo vidriado e instalaciones del club con una cancha auxiliar. Unas 28 mil personas (como Northbridge Park). |

---

## Entrenamiento (Club House)

Modo nuevo desde el menú principal (ENTRENAMIENTO). Detalle de la arquitectura en `docs/ENTRENAMIENTO.md`.

| Tema | Cambio |
|---|---|
| Club House | Cancha de práctica sin tribunas ni público: pasto, alambrado bajo, árboles, el edificio del club con su cartel, bancos y mástiles de luz. Sonido: redoblante y bombo en lugar de la hinchada. |
| Práctica libre | Ataque contra defensa con la cantidad que quieras de cada lado (1–10 / 0–10) y arquero rival opcional. Sin reloj, tarjetas ni offside; gol, afuera, atajada o falta: se rearma sola. SELECT reinicia al instante. |
| Pelota parada | Tiros libres (distancia, ángulo, barrera sí/no), córners (de cada lado) y penales, con el pateador que elijas. |
| Desafíos con récord | Slalom (tiempo), precisión de pase (pases en 60 s), rondo (pases seguidos contra 2 marcas) y puntería (10 tiros libres a los ángulos). |
| Menú de práctica | START: práctica, jugadores de cada lado, arquero rival, tiro libre, barrera, córner, pateador, reinicio, Dirección del equipo, cámara y salir. |

**Tests:** 292 en verde. Nuevo `test_training.gd`. Captura: `--training`.

## La falta como en el WE (árbitro, tarjeta, repetición, tiro libre)

| Tema | Cambio |
|---|---|
| Árbitro | Nuevo `Referee` (sólo presentación, de negro): sigue la jugada a distancia, atrás y en diagonal del lado del centro. Sale en las repeticiones. |
| Secuencia de la falta | 1) El derribado queda en el piso (falta fuerte, 3,4 s). 2) Si hay tarjeta, el árbitro corre hasta el infractor, se para enfrente y levanta la amarilla o la roja, con una toma de costado cerca (2 s). Al expulsado se lo ve recibir la roja y después se va. 3) Repetición de la falta (ahora todas las faltas tienen repetición). 4) Tiro libre. |
| Cámara del tiro libre | En campo rival (y en los penales): cámara atrás del pateador, como en el WE, con la barrera y el arco a la vista; el pateador se para en diagonal atrás de la pelota. Sin nombres ni marcas flotando en esa toma. Al patear sigue la pelota 1,2 s y vuelve la cámara del partido. En campo propio, la cámara con la que se está jugando. |
| Arquero se levanta | Después de tirarse sobre la pelota se levanta (Stand_Up) con la pelota en la mano izquierda contra el pecho, mientras se apoya con la otra. Si va ganando sobre el final, la duerme hasta 5,4 s. |

**Tests:** 280 en verde. Nuevo `test_foul_sequence.gd`. Captura: `--foul` en `tools/capture_runner.gd`.

## Festejos, animaciones nuevas y jugadores retro (beta)

| Tema | Cambio |
|---|---|
| Festejo del gol | El goleador corre al córner más cercano del arco donde hizo el gol y frena unos metros antes del banderín; ahí festeja con un festejo al azar (Festejo1 Catwheel o Festejo2 Golf Putt si están; si no, la rueda de antes). Lo acompañan 2 o 3 de los compañeros más cercanos, que se ubican alrededor y levantan los brazos. Los demás del equipo levantan los brazos desde donde están. Dura lo que tarde en llegar más el festejo (tope 9 s); X lo saltea. Después, la repetición. |
| Animaciones nuevas (tanda "Animation Pro") | Reemplazan a las viejas (ya no hay respaldo a las anteriores con el mismo uso). Carrera: Jog Forward, Sprint y Jog Backward, con la cadencia ajustada a la velocidad real (sale de cuánto avanza la cadera en un ciclo). Remate (remate), pase (Soccer Pass), cabezazo según la altura de la pelota (No jump Header / Soccer Header / Soccer Header little jump), amague X + Cuadrado (XCuadrado Chip), pecho (Receive pecho), lateral (Throw In), barrida (Soccer Tackle), caída tras una falta o barrida (foul) y levantarse (Standing Up), marsellesa (Soccer Spin), conducción (Dribble), festejos al azar (Festejo1 Catwheel / Festejo2 Golf Putt). Arquero: espera, atajada parado / con salto / corta centro (si viene muy alta) / de abajo (Scoop), estirada (Diving Save, ahora va hacia la derecha del modelo y se espeja para el otro lado), error, saque con la mano rápido y rodando, saque de volea (Drop Kick), paso lateral de achique. |
| Festejos a elección | 12 festejos (Rueda, Golpe de golf, Mortal hacia atrás, Capoeira, Carrera y frenada, El fusil, Gateo, La araña, Molinete, Baile del jinete, Paso lunar, El robot) en `Celebrations`. Cada jugador tiene su preferido (`PlayerData.celebration`, -1 = al azar) para el futuro modo edición; si no, uno al azar. Los cortos se repiten y los bailes largos se cortan (entre 2,6 y 5,5 s). |
| Chilena | Remate con la pelota a media altura (0,95 a 2,05 m), de espaldas al arco y a menos de 24 m: sale de chilena (humano o CPU, también cuando la CPU la iba a cabecear al arco). Después queda 2 s en el piso y se levanta. |
| Arranque y giro en carrera | R1 casi parado: arranque de velocista (Idle To Sprint). Corte brusco a toda velocidad: giro en carrera (Sprint Turn, espejado para el otro lado), una vez por giro. |
| Arquero ordena a la defensa | Con la pelota en el otro campo (a más de 52 m) o mientras la tiene en las manos (los 6 s): Goalkeeper Directing; la pelota va en la mano que queda pegada al cuerpo. |
| Hacer tiempo | Va ganando desde el 75': el arquero de la CPU la duerme casi hasta los 6 s, y al agarrarla salta y se tira encima (GoalkeeperReceiver Catch; antes del 75', a veces). También se tira encima de una pelota dividida con un rival a menos de 3 m. |
| Faltas fuertes | Barrida o falta de atrás (o si lo lesionan): queda 3,4 s en el piso y el juego espera. De atrás cae de espaldas (caida de atras Hit On Legs); si no, se cae (foul) y queda tirado dolorido (Fallen Idle) hasta levantarse. |
| Lesionado | Trota rengo (Lesionado andando Injured Jog). |
| Arreglo | Cada gesto se avisaba dos veces a la repetición; ahora una. |
| Jugadores retro (beta) | Opción "Jugadores: actuales / retro PS1 (beta)" en la configuración del partido. Usa el modelo base que pasaste (libre, en `assets/models/players/retro/`) vestido sobre el esqueleto del juego: se escala, los brazos pasan de la pose A a la T, cada vértice va pegado al hueso más cercano (como en PS1) y cada cara se pinta de un color plano por zona (camiseta, short, rodillas, medias, botines, piel, pelo y guantes del arquero). Toma todas las animaciones y los físicos. |

**Tests:** 275 en verde. Se agregaron `test_celebration.gd` (córner, compañeros y brazos arriba) y `test_animation_pack3.gd` (festejos, chilena, arranque y giro, falta fuerte, arquero que ordena y que hace tiempo, lesionado).

## Repeticiones limpias y sombras que no quedan negras (tu feedback)

| Tema | Cambio |
|---|---|
| Repetición | En pantalla sólo queda el marcador, la marca **REPETICIÓN** (con un punto rojo que late) arriba a la derecha y un cartel simple abajo con quién hizo la jugada. Nada del HUD de jugadores ni el radar. Entra y sale con una **cortina** (una franja con el nombre del juego que cruza la pantalla). X / Start la saltea. |
| Jugadas peligrosas | También se repiten (antes del saque): remates que se van cerca del palo o pegan en él ("¡Cerca! / ¡Al palo! Remate de ..."), atajadas que el arquero manda al córner ("¡Atajada de ...!") y faltas importantes (penal, tarjeta o tiro libre cerca del área: "Falta de ... · AMARILLA"). Las de jugadas duran 4 s; la del gol, 6. |
| Opción | "Repeticiones: goles y jugadas / sólo goles / no" en Opciones. |
| Sombras de día | La sombra del sol deja pasar parte de la luz (como la que rebota en el cielo, el césped y las tribunas): queda marcada pero nunca negra. Se sumó un relleno de luz parejo que no depende de cuánto cielo "ve" cada lugar, menos oclusión ambiental y más rebote de la iluminación global. El arco, el área y los jugadores bajo la sombra del techo ahora se ven. |
| Túnel | Ya no es un hueco negro: pasillo con paredes pintadas, piso de goma, paneles de luz en el techo y lámparas. |
| Estructuras | El muro perimetral y el frente de las bandejas pasaron de casi negro a hormigón pintado; el banco de suplentes dejó de ser una caja oscura: ahora tiene pared de fondo, laterales, asientos y techo traslúcido. |

## Mientras armás el modelo: repetición, sonido, Liga y Copa

| Tema | Cambio |
|---|---|
| Repetición del gol | Después del festejo se ve la jugada otra vez (los últimos 6 s), con una cámara baja que sigue la pelota y cámara lenta al final. Arriba dice "REPETICIÓN"; abajo, la ficha del goleador como en tu captura: puesto, número, nombre, altura y edad (y "en contra" si fue gol en contra). Se ven también los gestos (patada, cabezazo, estirada). X / Start la saltea. Opción "Repeticiones de gol" en Opciones. |
| Sonido | Generado por código, sin archivos de terceros: silbato (corto en faltas y saques del medio, doble en el entretiempo, triple al final), patada (más grave cuanto más fuerte), pique, palo, red, murmullo del público que sube cuando la pelota se acerca a un arco, grito de gol y "uhh" cuando un remate se va cerca o pega en el palo. Volúmenes de efectos y del público en Opciones. Es una base: cuando tengamos sonidos grabados (CC0) o tu referencia de video, se reemplazan uno por uno. |
| Liga | Todos contra todos con los 8 equipos (7 fechas). Elegís tu equipo; cada fecha jugás tu partido (pasando por la configuración del partido, de local o de visitante) o lo simulás; el resto se simula según los puntajes de los equipos. Tabla con PJ, G, E, P, GF, GC, DG y puntos. Al final, el campeón. |
| Copa | Eliminación directa por sorteo: cuartos, semis y final. Si tu partido termina empatado se define por penales (por ahora simulados). |
| Guardado | La Liga o la Copa en curso se guarda entre partidos y sesiones; "Abandonar" la borra (pide confirmación). Un partido que se abandona a mitad no cuenta. |

**Tests:** 260 en verde. Se agregaron:
- `test_replay.gd`: gol, repetición con ficha y saque del medio; ficha; sin repetición si está apagada;
- `test_audio.gd`: todos los sonidos, pitazo final y el partido los dispara;
- `test_competition.gd`: fixture, tabla, resultado del lado correcto, copa con penales y campeón, simulación con 2 a 3 goles por partido, guardado y jugar de visitante.

## Menús estilo WE (según tus capturas)

| Pantalla | Qué tiene |
|---|---|
| Menú principal | Ya no se corta. Barras violetas a la izquierda: Partido, Liga, Copa, Liga Master, Entrenamiento, Editor, Opciones y Salir; las que todavía no existen aparecen apagadas. A la derecha el logo con una pelota (sin marcas) y abajo la caja verde de ayuda que explica la opción elegida. |
| Modo | 1 jugador vs CPU, 2 jugadores (si hay mando para el segundo) o CPU vs CPU. |
| Elección de equipos | Grilla de escudos de los **8 equipos** (6 nuevos, todos inventados: Real Costanera, Unión Pampa, Sporting Bahía, Atlético Cordillera, Club Puerto Viejo, Norteña FC). Arriba, el local y el visitante con escudo y uniforme, y en el medio las barras de ataque, defensa, fuerza, velocidad y técnica. Primero se elige el local, después el visitante; Cuadrado (Z) elige al azar. |
| Partido ("Match Mode") | Filas con flechas a los costados: horario, clima, viento, césped, duración, nivel de la CPU, offside, estadio y **uniforme** de cada equipo (titular o alternativo; si las camisetas se confunden, el visitante usa la otra). A la derecha, la miniatura del estadio y los dos uniformes. |
| Opciones | Controles, velocidad del juego, movimiento (8 / 16 / libre), qué se ve sobre los jugadores, el arquero a los 6 s y la prueba de rendimiento. |
| Controles | Tabla de ataque y defensa por botón, con mando y teclado. Cambiar los botones queda para más adelante. |
| Pausa | Como la del WE: cartel "PAUSA" arriba a la izquierda, barras a la izquierda (el partido se sigue viendo) y ayuda abajo. |
| Previa | Botones con el mismo estilo; durante la formación en la cancha aparece el cartel con los once titulares (puesto, número y nombre) de cada equipo. |

Los equipos y uniformes elegidos se guardan para el próximo partido.

**Tests:** 247 en verde. Se agregaron (`tests/unit/test_menus.gd`):
- ocho equipos de 23 con dos uniformes;
- páginas del menú y volver;
- elegir local y visitante;
- filas de la configuración;
- uniformes elegidos y camisetas que no se confunden.

### Pantallas que faltan (hoja de ruta)

| Pantalla | Cuándo |
|---|---|
| Gol: repetición con la ficha del goleador | ✅ Hecho |
| Presentación de jugadores en la previa con primeros planos | Fase 5, con tu modelo final |
| Configurar controles (cambiar los botones, por mando) | Fase 8 (pulido) |
| Liga Master, con **mercado de pases** (lista con puntos y costo, y ficha con barras) | Fase 6 |
| Liga y Copa: más equipos, fase de grupos, penales jugados, dos ruedas desde el menú | Fase 7 |
| Editor y creación de jugadores (pelo, cara, altura, físico, edad, pie) y de equipos | Más adelante, junto al creador de estadios |
| Sonido grabado y relato (hoy: sonido generado por código). Referencia que pasaste: https://www.youtube.com/watch?v=GQMqctHarjo | Fase 5 |

## Fase 4 (3): cuerpo a cuerpo, lesiones, habilidades especiales y estrategias

| Tema | Cambio |
|---|---|
| Cuerpo a cuerpo | Corriendo a la par del que lleva la pelota, a veces chocan de hombros. Pierde el de menos fuerza, equilibrio y físico (el flaquito trastabilla; el pesado o musculoso aguanta). Si pierde el que la lleva, la pelota queda suelta. Al separarse, el más pesado corre al otro. Unos 5 choques por partido entre la CPU. |
| Lesiones | Al que le hacen falta se puede lesionar: barrida de atrás 15 %, barrida 7 %, otra 2 %. Un golpe lo deja rengo (−10 % de velocidad); algo peor (−25 %) obliga a cambiarlo: la CPU lo cambia sola y a vos se te avisa. Se ve en la Dirección del equipo. |
| Habilidades especiales | Como las estrellitas del WE, según los atributos: **pasador** (pases un 35 % más precisos), **goleador** (define mejor en el área), **gambeteador** (cuesta sacarle la pelota y aguanta los choques), **cabeceador** (salta más y cabecea más preciso), **especialista** (tiros libres y penales más precisos), **marcador** (entra mejor y hace menos faltas), **atajador** (arquero que achica mejor el mano a mano). Se ven en la ficha del jugador. |
| Estrategias | En la Dirección del equipo se asignan cuatro a los botones; en el partido se activan y apagan con **L2 + X / Cuadrado / Círculo / Triángulo** (con teclado, **R** + la tecla). Presión en todo el campo, contraataque (los de arriba no bajan y se sale rápido), trampa del offside (línea alta), ataque por las bandas, todos al ataque, todos atrás. La activa se ve arriba a la derecha. La CPU va con todos al ataque si pierde desde el 70' y con todos atrás si gana desde el 80'. Mientras L2 está apretado los botones no patean. |

**Tests:** 241 en verde. Se agregaron (`tests/unit/test_contact_strategy.gd`):
- choque de hombros: quién gana y qué pasa;
- frecuencia de los choques;
- empuje según el peso;
- lesión: más lento y la CPU lo cambia;
- habilidades: gambeteador, marcador y pasador;
- forma del equipo con cada estrategia;
- L2 + botón activa la estrategia sin patear;
- presión en todo el campo;
- estrategia de la CPU según el resultado;
- asignar estrategias a los botones.

## Fase 4 (2): plantel de 23, Dirección del equipo y condición

| Tema | Cambio |
|---|---|
| Plantel | 23 por equipo como en el WE: 11 titulares y 12 suplentes (tres arqueros). Siguen siendo 3 cambios. |
| Dirección del equipo | Pantalla al estilo del WE, desde la pausa y desde la previa del partido. A la izquierda, la minicancha con la formación y la lista de los 23. Con L1 / R1 (o Q / E) la columna pasa por **Puesto** (GK, CB, SB, DH, CH, OH, SH, WG, CF), **Energía** (con el desgaste en oscuro) y **Condición**. A la derecha, el menú y la ficha del jugador elegido: pie, altura, condición, energía y los 13 puntajes (los altos en amarillo y naranja). |
| Sustituir | X sobre un jugador y después sobre otro. Dos titulares cambian de puesto (si uno va al arco, se cambia la ropa). Titular y suplente: en la previa es un cambio libre de la alineación; en el partido es uno de los 3 cambios. |
| Pateadores y capitán | Tiros libres (cerca del arco), córners y penales los patea el elegido; capitán marcado con (C). |
| Condición (flechas) | Cada jugador llega al partido en un estado al azar: roja arriba (+6 a todos los atributos), naranja (+3), amarilla (normal), azul (−3), gris abajo (−6). Afecta el juego y se ve en la lista. |

**Tests:** 229 en verde. Se agregaron (`tests/unit/test_team_sheet.gd`):
- plantel de 23;
- la condición cambia los atributos;
- sorteo de la condición;
- columnas con L1 / R1;
- cambio libre en la previa;
- en el partido, un cambio;
- dos titulares cambian de puesto;
- pateadores elegidos;
- capitán y pateador desde la pantalla.

## Fase 4 (1): cambios, cansancio acumulado y arquero expulsado

| Tema | Cambio |
|---|---|
| Arquero expulsado | Al arquero también lo echan (roja directa o segunda amarilla). Si quedan cambios y hay arquero en el banco, entra él y sale un jugador de campo (el delantero más cansado): el equipo queda con 10. Si no hay cambios, va al arco el defensor más cercano, con la ropa y los guantes de arquero pero **con su propio número**. |
| Banco | 5 suplentes por equipo (los jugadores 12 a 16 del plantel, con un arquero). Se crean recién cuando entran. |
| Cambios | Hasta 3 por partido. El que entra ocupa el puesto del que sale, en su mismo lugar de la cancha; el que sale no vuelve. |
| Cambios del humano | Pausa → **Cambios (N restantes)**: a la izquierda los de la cancha (**Sale**), con puesto y energía; a la derecha el banco (**Entra**); **Confirmar**. Con la pelota parada se hace en el momento; con la pelota en juego, en la próxima pelota parada. |
| Cambios de la CPU | Desde el minuto 55, en cada pelota parada cambia al más cansado (si su energía no pasa de 80) por un suplente del mismo puesto. |
| Cansancio acumulado | Además de la energía que se gasta y se recupera en el momento, cada minuto de juego baja el **tope** de energía: más en sprint, menos parado, y menos con buen atributo de resistencia. En el entretiempo se recupera el 30 % del desgaste. Con el tope bajo, la velocidad máxima baja hasta un 6 % y la puntería empeora (ya dependía de la energía). En el HUD, la parte oscura a la derecha de la barra de energía es el tope perdido. |

En simulaciones CPU vs CPU: desgaste promedio de 28 al final del partido (el tope queda cerca de 72) y 2 cambios por equipo.

**Tests:** 220 en verde. Se agregaron (`tests/unit/test_substitutions.gd`):
- banco y cambio en el mismo puesto;
- máximo de 3 cambios;
- cambio pedido que espera la pelota parada;
- arquero expulsado con arquero suplente;
- arquero expulsado sin cambios: un defensor va al arco con la ropa de arquero y su número;
- segunda amarilla al arquero;
- desgaste, entretiempo y velocidad;
- el desgaste corre con el reloj;
- cambio de la CPU desde el minuto 55.

Se arregló además el test del offside: la línea defensiva del test quedaba sobre la trayectoria del pase y un defensor lo cortaba.

Próximo: menú previo al partido (como el de tu imagen) con **Jugar partido · Dirección del equipo** (formación, titulares y suplentes, quién patea) **· Ajustes · Controles**.

## Ronda WE2002 (14): offside

| Regla | Cambio |
|---|---|
| Posición adelantada | Al patear, se anotan los compañeros que están en campo rival, delante de la pelota y del penúltimo rival (con 30 cm de tolerancia: "en línea" está habilitado). |
| Cuándo se cobra | Si uno de esos la toca primero (recibe, cabecea o la desvía) antes que un rival u otro compañero. Tiro libre para el que defiende donde estaba el adelantado. |
| Excepciones | No hay offside en laterales, saques de arco ni córners. |
| Opción | "Offside: sí/no" en el menú principal (se guarda). |

En simulaciones CPU vs CPU da 2 a 3 offsides por partido (en el fútbol real son unos 4): no corta el juego a cada rato. Offsides en las estadísticas (`stats["offsides"]`).

**Tests:** 211 en verde. Se agregaron:
- se cobra al recibir el adelantado;
- habilitado no se cobra;
- lateral y opción apagada.

## Ronda WE2002 (13): expulsiones (primera parte de la Fase 4)

| Regla | Cambio |
|---|---|
| Roja directa | Barrida que es falta de atrás: roja el 85 % de las veces (como en el WE). |
| Segunda amarilla | Es roja. |
| Expulsión | El jugador sale de la cancha y el equipo sigue con 10. Ya no cuenta para la IA, los controles (si lo manejabas, pasás al más cercano a la pelota), la posesión ni las reglas. Cada uno conserva su puesto en la formación (`Team.roster` guarda el plantel y `Team.players` los que están en cancha). El saque del medio funciona con menos jugadores. |
| Arquero | ~~A lo sumo amarilla.~~ Desde la Fase 4 (1) también lo pueden echar (ver arriba). |

Rojas en las estadísticas del partido (`stats["reds"]`).

**Tests:** 208 en verde. Se agregaron:
- roja directa de atrás;
- segunda amarilla;
- jugar con 10 (puestos y saque del medio).

El test de los resbalones ahora es determinista.

## Ronda WE2002 (12): más mecánicas del WE

| Mecánica | Cambio |
|---|---|
| L1 + Triángulo | Filtrado por elevación: la picada pasa por arriba de la línea y cae a espaldas de los centrales. |
| Comba en la pelota parada | En tiros libres y córners, el stick derecho al patear (como la cruceta del WE): de costado curva hacia ese lado; adelante cae de golpe; atrás sale más alto y flota. |
| Pierna mala | Con la pelota claramente del lado de la pierna menos hábil, el remate sale mordido: +40 % de error y −10 % de potencia. Con la pelota al medio usa la buena. |
| La pared "invisible" | Durante 2 s la marca rival sigue a la pelota y pierde al que pica en la pared. |
| Resbalones | Con césped mojado (hasta 30 % según cuánto) o nevado (20 %), un corte seco a más de 5,5 m/s puede hacer resbalar al jugador. El equilibrio reduce la chance. |

`docs/REFERENCIA_WE.md` actualizado con estos estados.

**Tests:** 205 en verde. Se agregaron:
- filtrado por elevación;
- comba y caída en pelota parada;
- marca que pierde al de la pared;
- pierna mala;
- resbalones en mojado (en seco, nunca).

## Ronda WE2002 (11): mecánicas del WE (centros, colocado, freno, achique y físico)

Tu análisis del WE está en `docs/REFERENCIA_WE.md`, cruzado con el estado de cada mecánica en el juego. De ahí, esta tanda:

| Mecánica | Cambio |
|---|---|
| Centros por toques | 1 Círculo = alto al segundo palo; 2 = a media altura, tenso, al punto penal; 3 = rasante al primer palo. Afuera de la zona de centro, el doble sigue siendo pase raso. |
| Tiro colocado | R2 (o E) mientras se carga el remate, o justo al soltarlo: abre el pie y va al palo que marca el stick (sin stick, al más lejano). Lleva un 22 % menos de velocidad y un 55 % menos de error. |
| Frenar en seco | R2 (o E) conduciendo: pisa la pelota, que queda junto al pie, y el jugador se planta. |
| Achique | El arquero que viene corriendo a achicar (Triángulo) reacciona hasta 0,2 s más tarde al remate: la vaselina entra más. Si se frena antes (soltando Triángulo), recupera la reacción. |
| El físico importa | Los altos alcanzan la pelota más arriba y un poco más lejos, y entre dos que llegan parejo gana el más alto. Los bajos y flacos giran más cerrado; los altos y pesados, más abierto. |

Nueva acción `brake` (R2 / E); está en la ayuda de controles del menú.

**Tests:** 200 en verde. Se agregaron:
- centros de 1, 2 y 3 toques;
- tiro colocado;
- freno con la pelota;
- el alto que alcanza el cabezazo y el bajo que gira más;
- el arquero en carrera que reacciona más tarde.

## Ronda WE2002 (10): nieve difuminada, barrida, saludo, pelota en las manos y "riel" del receptor

| Reclamo | Causa | Cambio |
|---|---|---|
| Rectas y "cuadrados" en la nieve | El ruido del shader (de valor, con grilla) más un borde de transición angosto dejaban contornos poligonales. | Manchas con una textura de ruido simplex suave (sin costuras) y un borde ancho: quedan redondeadas y difuminadas. |
| La marca de la barrida aparece antes de tocar el piso | Se dibujaba entera (4,5 m) en el momento de tirarse. | Nace cuando el cuerpo toca el piso (0,1 s) y se va alargando detrás del jugador mientras se desliza. |
| El reflejo en la nieve y el pasto sigue con mucho brillo | — | Menos brillo especular en el pasto (seco y mojado) y casi nada en la nieve. |
| En el saludo, el que espera no se mueve | Chocaban los cinco, pero el local casi no lo hacía y no coincidían. | Se dan la mano: los dos estiran la derecha a la vez (un poco antes de quedar enfrentados, así las manos se juntan en el medio). El que espera gira el cuerpo hacia el que llega. |
| La pelota rueda en las manos del arquero mientras camina | La pelota giraba según su velocidad aunque estuviera agarrada. | En las manos no gira. |
| El receptor se mueve muy libre antes de recibir | Mover el stick cancelaba la ayuda y el receptor salía corriendo libre. | "Riel" como en el WE2002: mientras viene el pase, el receptor va al encuentro de la pelota aunque se mueva el stick (y sin sprint); el control vuelve al recibir. El super cancel (L1+R1) corta el riel y deja el control manual. |

### Tu análisis del WE2002, contra lo que ya hay
- **Ya está:**
  - riel del receptor y super cancel (esta ronda);
  - 8 direcciones (también 16 o libre, desde la pausa);
  - presión del compañero con Cuadrado y presión propia manteniendo X;
  - Triángulo para el pase al hueco y para sacar al arquero;
  - pared con L1+X;
  - centro alto, y bajo con doble toque;
  - globo con L1+Cuadrado;
  - barridas con falta más probable de atrás y de costado;
  - tiro según cuánto se carga la barra.
- **Para ver más adelante:**
  - el tercer tipo de centro (triple toque, rasante);
  - el timing del cabezazo en el punto más alto del salto;
  - el frenazo al soltar R1 como cambio de ritmo;
  - la roja directa en barridas de atrás (Fase 4);
  - el peso de la potencia y la precisión del pateador;
  - los rebotes cortos del arquero hacia el medio;
  - la debilidad del primer palo (decidir si se quiere imitar).

**Tests:** 196 en verde. Se agregaron:
- la marca de la barrida que crece;
- el receptor sigue en el riel aunque se mueva el stick;
- el super cancel corta el riel.

## Ronda WE2002 (9): nieve, brillo del piso y sombras de noche

| Reclamo | Causa | Cambio |
|---|---|---|
| El piso brilla rarísimo (noche, húmedo) | Mojado, el pasto quedaba casi como un espejo (rugosidad 0,28) y los reflectores tenían mucho brillo especular. | Pasto mojado: oscurece y brilla un poco (rugosidad ≥ 0,55); reflectores con poco brillo especular. La nieve es mate. |
| Triángulos y franjas en el césped de noche | Las vigas del techo común proyectaban sombra desde las cuatro torres de luz, y se cruzaban. | De noche el estadio no proyecta ninguna sombra: sólo los jugadores, tenues (opacidad 45 %). Las vigas tampoco proyectan sombra de día. |
| La nieve flota en el aire | Los copos caían a 1-2 m/s con mucha turbulencia y eran grandes: parecían quietos frente a la cámara. | Copos más chicos que caen a ~3 m/s, derivan con el viento y tienen un vaivén leve. |
| La nieve crece de afuera hacia adentro y en "cuadrados" | La cobertura dependía de la distancia al borde de la cancha (un máximo entre largo y ancho, que arma contornos rectangulares y diagonales). | Dispersa por toda la cancha: manchas de varios tamaños que crecen y se juntan, un poco menos donde más se pisa. Al final del partido queda algo de verde. |
| El arquero se tira un poco antes de tiempo | — | La estirada arranca 0,3 s antes de que llegue la pelota (antes, 0,45 s). |

**Herramienta:** las capturas aceptan `--late` (reloj en el segundo tiempo, para ver la nieve acumulada).

**Tests:** 195 en verde. Se agregó un test de que de noche el estadio no proyecta sombras.

## Ronda WE2002 (8): nieve que se acumula, lateral, arquero que reacciona y menú

Resultados de tu prueba de rendimiento con la ronda 7: todos los casos en "OK".

| Caso | Promedio | 1 % más lentos | Antes (promedio / 1 %) |
|---|---|---|---|
| Coliseo, mañana | 143 FPS | 114 FPS | — |
| Northbridge, tarde | 141 FPS | 101 FPS | 76 / 41 |
| Torri con lluvia | 96 FPS | 70 FPS | 50 / 32 (despejado) |
| Torri con nieve | 90 FPS | 64 FPS | 69 / 29 |

| Pedido | Cambio |
|---|---|
| Mucha nieve: tiene que ser acumulativa | La nieve acumulada va de poca (30 %, en manchas, primero en bandas, fondos y donde no se pisa) a casi todo blanco al final del partido; va tapando el verde a medida que cae. En el entretiempo sólo se limpian los surcos de las líneas: la nieve del resto queda. |
| Lateral: la pelota en las manos, atrás de la nuca | El que saca espera con los brazos arriba, los codos doblados y la pelota entre las manos atrás de la cabeza. Al sacar, la pelota sale desde las manos con el gesto del lanzamiento. |
| El arquero vuela apenas le rematan | Al remate se queda plantado durante su tiempo de reacción (0,25-0,4 s según el atributo). Después se acomoda hacia el punto de atajada y se tira recién cuando la pelota está por llegar (~0,45 s antes). A quemarropa se tira apenas reacciona. Quién ataja lo sigue decidiendo el modelo de atajada (que ya contaba la reacción): en 40 remates simulados, las 9 atajadas previstas se concretaron. |
| Números arriba de los jugadores en la presentación | Durante la presentación no se ve ninguna marca (nombre, número, flecha, aro); vuelven al empezar el partido. |
| El menú no deja cambiar opciones después de la prueba de rendimiento | Start/Esc para salir de la prueba también abría la pausa del partido de la prueba, y el menú cargaba con el juego pausado. El menú principal ahora siempre arranca despausado (y con velocidad normal). |

**Pendiente (después de tu modelo en Blender):** pulir la distancia jugador-pelota de los controles, los deslizamientos que quedan y las animaciones.

**Tests:** 194 en verde. Se agregaron:
- la nieve se acumula y en el entretiempo sólo se limpian las líneas;
- el lateral con la pelota en las manos;
- el arquero reacciona y se tira tarde;
- sin marcas en la presentación.

## Ronda WE2002 (7): correcciones de tu prueba (animación, césped, clima, luz y rendimiento)

| Reclamo | Causa | Cambio |
|---|---|---|
| Reciben la pelota "deslizándose de pie" | El gesto de recepción (con la suela, en el lugar) se usaba hasta 3,5 m/s, o sea trotando. | Sólo casi quieto (< 1,2 m/s). Andando, recibe con la carrera, como en el WE. |
| Siguen desplazándose mientras pasan | La animación de pase es en el lugar y el cuerpo seguía a toda velocidad. | Al patear o pasar frena 0,3 s (35 % de la velocidad, con la desaceleración normal): el cuerpo acompaña el golpe. |
| A veces se paran en T (también en los laterales) | Parado se usaba la pose en T de la librería y los brazos se bajaban por código sólo si no había un gesto. En las mezclas (parado ↔ caminar) y con un gesto activo se veía la T. | Al cargar se arman animaciones de parado con los brazos ya acomodados, una por postura (al costado, mano en el pecho, atrás, cintura). Las mezclas nunca pasan por la T. Por código quedan sólo la respiración y el giro de cabeza. |
| Césped "granulado" (atardecer, Northbridge) | La textura del césped (4K) se importaba sin mipmaps: a la distancia de la cámara cada píxel de pantalla toma un píxel suelto de la textura. | Los mipmaps se generan al cargar la textura, sirve para cualquier textura local. El detalle procedural fino se apaga antes con la distancia. |
| Nieve espantosa en el piso | El ruido de las manchas tenía una grilla alineada a los ejes (cuadrados) y la cobertura era parcial. | Capa pareja con variaciones suaves (ruido rotado por octava). Asoma el pasto donde más se juega y se ven los surcos de las líneas. |
| Lluvia como palitos celestes zigzagueando | Las gotas eran planos que giraban hacia la cámara sólo sobre el eje vertical, mientras se movían en otra dirección. | Gotas de dos planos cruzados orientados por la velocidad, de color gris claro. El viento las corre de costado a su velocidad: con viento fuerte caen en diagonal. |
| Sombra demasiado firme (techo alto) y rayas en el césped | El sol no tenía tamaño aparente. Las cerchas de arriba del techo proyectaban rayas. | Sombra con penumbra (`light_angular_distance`): la de un techo alto se desdibuja y la de un jugador queda nítida. Las cerchas y vigas de arriba del techo no proyectan sombra. |
| No se ve nada en el córner (Torri al atardecer) | Los reflectores de los estadios techados estaban arriba del techo, y los que hacen sombra quedaban tapados. | En los estadios techados los reflectores cuelgan debajo del borde del techo, en las esquinas; la altura sale de los datos del estadio. |
| 1 % más lentos 29-41 FPS | Al ocultar la tribuna del lado de la cámara se volvía a encender la sombra de todo (público y butacas incluidos: decenas de miles de instancias por pasada de sombra). Además, la iluminación global (SDFGI) re-voxelizaba el público y las butacas cada vez que la cámara cambiaba de zona. La simulación no es: ~0,65 ms por paso, sin picos. | El público, las butacas, barandas y banderas no proyectan sombra ni entran en la iluminación global. En la tribuna oculta directamente no se dibujan. |

**Tests:** 191 en verde. Se agregaron:
- parado sin pose en T, también en la mezcla;
- el que pasa frena;
- lluvia en diagonal con viento.

Se actualizó el test de la tribuna oculta.

**Pendiente:** que repitas la prueba de rendimiento (Torri y Northbridge, con nieve y sin nieve) para ver cuánto mejoraron los cuadros lentos.

## Ronda WE2002 (6): configuración guardada y vista previa de estadios

> **Nota:** la ronda 5 (estadios, túnel, pelo y físicos) había quedado fuera de `main`. El PR #15 se mergeó antes de que se subiera ese commit. Va en el mismo PR que esta ronda.

| Pedido | Cambio |
|---|---|
| Guardar la configuración | `GameSettings` guarda las opciones en `user://settings.cfg` cada vez que cambian (menú principal, pausa, cámara) y las lee al abrir el juego. Las opciones guardadas son: duración, dificultad, estadio, horario, clima, viento, césped, velocidad, marca del jugador, arquero a los 6 s, rumbos del stick, cámara y ayuda de pase. Un valor inválido o de otro tipo se ignora o se ajusta al rango. Los tests y las herramientas no leen ni pisan tu configuración. |
| Vista previa de estadios | El botón "Estadio" del menú muestra el nombre y una miniatura aérea que cambian juntos. Para "Aleatorio" se ve un recuadro neutro. Las miniaturas (`assets/ui/stadiums/<n>.png`, CC0 propias) se generan con `-- --stadium-thumbs=res://assets/ui/stadiums`. |

**Herramienta:** `-- --menu-shot=archivo.png` saca una captura del menú principal.

**Tests:** 188 en verde. Se agregaron:
- guardar y cargar la configuración;
- valores inválidos;
- que los tests no tocan tu configuración;
- miniaturas de todos los estadios.

## Ronda WE2002 (5): estadios, túnel, pelo y físicos

| Pedido | Cambio |
|---|---|
| Tres estadios más | Los estadios son datos (`scripts/stadium/stadium_styles.gd`). `StadiumBuilder` arma cualquiera de los cuatro. Todos son ficticios y sólo toman ideas de arquitectura. Se elige en el menú principal (opción "Estadio", con "Aleatorio"). |
| Túnel que nace de la tribuna | La tribuna sur tiene un hueco real: sin escalones, butacas, baranda ni banderas sobre la boca. Adentro es todo negro (paredes, techo y fondo) con marco de hormigón. El muro perimetral se abre frente a la salida. La boca depende del estadio (`StadiumBuilder.tunnel_z`). |
| Pelo pintado | Peinados con volumen (`scripts/player/hair_builder.gd`): corto degradé, pelado, casco, mohicano, coleta, rulos con vincha, rastas, pelado arriba y largo con raya. El pelo va pegado al hueso de la cabeza, con textura de mechones. Se arregló la línea negra entre la piel y el pelo: la zona de color ahora se interpola plana. |
| Físicos | Normal, gordo, flaco, alto, bajo, fornido y musculoso: escala por hueso, compensando a los hijos, más la altura total. `PlayerData.build` lo fija a mano. Si no, sale de los atributos: arqueros y buenos cabeceadores, altos; con mucha fuerza, fornidos o musculosos; rápidos y livianos, flacos; poca resistencia, a veces gordos. `PlayerData.hair` fija el peinado. |

Los cuatro estadios:
- **Estadio Master:** el de siempre.
- **Northbridge Park** (estilo inglés):
  - tribunas pegadas a la cancha y esquinas cerradas;
  - techo blanco en voladizo, todo techado;
  - butacas rojas;
  - reflectores colgados del techo.
- **Gran Coliseo del Plata** (herradura rioplatense):
  - pista de atletismo con andariveles;
  - dos bandejas, la baja blanca y la alta roja;
  - casi sin techo;
  - torres de luz altas por fuera.
- **Stadio delle Torri:**
  - tres bandejas empinadas, todo cerrado;
  - techo oscuro sobre vigas rojas;
  - cuatro torres grandes en las esquinas y ocho torres con rampas en espiral.

**Herramientas:**
- `tools/pose_sheet.gd` arma hojas de peinados (`--poses=...hair...png`) y de físicos (`--poses=...build...png`).
- Las capturas aceptan `--stadium=N` y `--tunnel` (boca del túnel y vista de TV).

**Tests:** 184 en verde. Se agregaron:
- los cuatro estadios con túnel y salida libre;
- las esquinas y las torres;
- los peinados;
- los físicos;
- el físico automático.

**Pendiente:**
- Creador de estadios y creador de jugadores (pedido tuyo), después del diseño final del jugador. Ya está la base: estadios como datos (`StadiumStyles`) y aspecto en `PlayerData`.
- Medir FPS en tu máquina con el Stadio delle Torri: tiene más del doble de butacas y público que el Estadio Master.

## Ronda WE2002 (4): correcciones de tu prueba

| Pedido | Cambio |
|---|---|
| La camiseta parece la piel pintada | La camiseta es una capa de tela: se infla apenas sobre el cuerpo y el torso se sombrea como un cilindro liso (no marca músculos). Tiene trama de tejido, brillo de tela y vivos de otro color: cuello, puños y ruedo de la camiseta y del pantalón. Se sacó el sombreado facetado. |
| Parados como peleadores de MMA | Parado, el jugador de campo está derecho (ya no en guardia) y respira. En la formación, cada uno tiene su postura: brazos al costado, mano en el pecho, manos atrás o en la cintura. Los arqueros también se paran derechos. Giran la cabeza para mirar a los compañeros. En el saludo, el local mira al visitante que se acerca. |
| Saque de arco | El arquero deja la pelota en la línea del área chica y retrocede unos 5 m, abierto hacia el centro, para tomar carrera. Con la orden (la tuya o la de la CPU), corre y patea al llegar a la pelota. Los rivales quedan fuera del área. |
| La defensa rival encima del arquero con la pelota en las manos | Cuando el arquero rival tiene la pelota en las manos, la CPU no presiona: todos vuelven a su puesto, como mínimo a 24 m de la línea del arco. |
| Lluvia "rara" en la toma que gira | En las tomas de la presentación, la lluvia y la nieve se emiten delante de la cámara y por encima de ella. Antes salían de un punto viejo y la cámara del menú quedaba por encima del emisor. |
| Saludo FIFA | El visitante da un paso al frente y pasa en fila, 1 m por delante de la fila local, sin atravesarla. Todos caminan a la misma velocidad y el primero de la fila llega más lejos. Chocan los cinco con cada jugador local (gesto nuevo `HIGH_FIVE`). |
| Texturas pesadas | Las texturas que falten quedan en `.gitignore` (`assets/textures/grass/`) y se usan desde tu copia local. `grass_albedo.jpg` ya está en el repo. |

**Herramienta:** `tools/pose_sheet.gd` (`-- --poses=archivo.png`) arma una hoja con las posturas de frente y de costado.

**Tests:** 179 en verde. Se agregaron:
- posturas y choque de manos;
- carrera del saque de arco;
- repliegue con el arquero rival con la pelota en las manos.

## Ronda "WE2002" (tu prueba de jugabilidad) — en 3 rondas

### Ronda 1: juego (hecha)
| Pedido | Cambio |
|---|---|
| El arquero no tiene la pelota en las manos (flota, brazos abajo) | Pose de agarre: brazos adelante y antebrazos doblados, la pelota entre las manos contra el pecho (sigue también en la atajada, la estirada y la caída). |
| Todo va muy rápido | Velocidad del juego como en el WE2002: -2 .. +2 en la pausa. Por defecto el juego corre al 84 % (todo: jugadores, pelota, animaciones); el reloj del partido se compensa, así que la duración en minutos reales no cambia. |
| 6 s del arquero (FIFA) | Cuenta en pantalla en los últimos 3 s. A los 6 s la juega solo según la opción de la pausa: pelotazo hacia adelante o la suelta al piso. **Triángulo** con la pelota en las manos: la suelta para jugarla con los pies (no la puede volver a agarrar hasta que la toque otro). |
| Saque de arco | La pelota en el borde del área chica y el arquero patea con el pie: X pase corto a un compañero, Círculo pelotazo largo (fuerza y dirección). Verificado con un test. |
| No se cobran faltas ni tiros libres | Faltas en barridas (de atrás casi siempre, de costado a veces, de frente rara vez; con el césped mojado, más) y en algunas entradas fallidas. Tiro libre donde fue (con barrera de 2-4 a 9,15 m si está a menos de 32 m del arco), **penal** si fue en el área (todos afuera, patea el mejor rematador), y **amarilla** según la gravedad. La CPU patea al arco los tiros libres cercanos y los penales. |
| Nieve que no se ve caer; pelota | Copos más grandes y más; **pelota naranja**. Las líneas tienen un **surco limpio** al costado que se va tapando de nieve durante cada tiempo y se limpia en el entretiempo. |
| Barro en barridas | Con lluvia o césped mojado (y con nieve) cada barrida deja una marca de barro a lo largo del deslizamiento. |
| Nombre arriba del jugador | El nombre del que manejás arriba de la flecha (como en el WE). En la pausa: nombre / números de todos / nada. |

Pendiente para la Fase 4: segunda amarilla y roja (expulsión), que van con los cambios y el plantel.

### Ronda 2: look WE2002 (hecha)
| Pedido | Cambio |
|---|---|
| Público: con volumen, pero no "conos con cabeza" | Cada hincha es una persona sentada de pocos polígonos (~90 triángulos): piernas dobladas, torso con hombros más anchos que la cintura, brazos, cuello y cabeza redondeada con pelo; algo girados y de distinto tamaño. 85 % de las butacas ocupadas; como en el WE, mucho blanco y gris con los colores de los clubes salpicados (la cabecera visitante, con los suyos). Saltan en los goles. Banderas de los hinchas colgadas de las barandas. |
| Jugadores más "cuadrados" (WE2002) | Sombreado facetado (caras planas), pecho y hombros más anchos y botines más grandes. |
| Césped como la referencia | Franjas de corte con más contraste. |

### Ronda 3: presentación (hecha)
Al entrar a un partido desde el menú principal (`MatchIntro`; X / Start saltea cada etapa):
1. **Menú previo** con el estadio de fondo (la cámara recorre el estadio por dentro, los jugadores calientan): "Comenzar el partido", "Saltear la presentación", "Salir al menú" y el resumen del clima. Barras violáceas al estilo WE.
2. **Calentamiento**: toma abierta y un corte cerca de un jugador.
3. **Salida por el túnel**: dos filas salen de la boca del túnel (nueva, con marco y el interior oscuro, bajo la tribuna de la cámara) y caminan hacia el centro.
4. **Formación protocolar** frente a la tribuna principal, con paneo a lo largo de las filas.
5. **Saludo**: la fila visitante pasa frente a la local.
6. **Formaciones**: pantalla con los dos equipos en la cancha (números y nombres).
Después, saque del medio. En los tests y la prueba de rendimiento no hay presentación.

## Visual 2 — Look con más profundidad y condiciones del partido

### Pedido
"Debería tener mejores texturas, iluminación y sombras; está bastante plano,
parece un juego de navegador; un poco más oscuro. Y el clima: noche / día /
mañana / tarde, viento, lluvia, nieve, seco, húmedo."

### Hecho
| Tema | Cambio |
|---|---|
| Condiciones (`MatchConditions`) | Horario (mañana, tarde, atardecer, noche), clima (despejado, nublado, lluvia, nieve), viento (sin, leve 4 m/s, fuerte 9 m/s, con dirección) y césped (seco, húmedo, mojado). En el menú principal, cada una con "Aleatorio". Al empezar se muestra el resumen ("Noche · Lluvia · viento 9 m/s · césped mojado"). |
| Efectos en el juego | Cada partido usa una **copia** del ajuste base modificada por el clima. Mojado: la pelota corre ~25 % más y patina en los piques, la conducción se va un poco más larga, las barridas resbalan más lejos y derriban más. Nieve: la pelota frena (~25 % menos de recorrido) y pica menos, jugadores algo más lentos. Viento: empuja la pelota **en el aire** (un pelotazo con 9 m/s de costado se desvía ~3 m); rodando no la afecta. |
| Luz por horario (`Atmosphere`) | Mañana: sol bajo y frío. Tarde: sol alto. Atardecer: sol naranja rasante y luces del estadio a media potencia. Noche: cielo negro, cuatro torres de luz (reflectores que se cruzan; sombras de dos torres por costo). Nublado / lluvia / nieve: luz difusa y sombras blandas. |
| Lluvia, nieve y viento visibles | Gotas (inclinadas por el viento) con algo de bruma; césped mojado más oscuro y con brillo. Copos que caen despacio y césped nevado en manchones (más en las bandas; el medio pisado se ve verde). Banderines del córner que flamean con el viento. Indicador de viento (flecha + m/s) bajo el marcador. |
| Menos plano, más oscuro | Exposición 1,0 y más contraste; oclusión ambiental más marcada; bruma de distancia. Césped con detalle en varias escalas, relieve fino (normal procedural que se suaviza a lo lejos) y desgaste en las áreas chicas y el círculo central. Hormigón con manchas y relieve. **Público** en las tribunas (≈60 % de ocupación, con los colores del local y la cabecera visitante con los suyos) que salta en los goles. |
| Texturas fotográficas | `GrassTextures`: si se ponen texturas CC0 de césped en `assets/textures/grass/`, se usan en lugar del detalle procedural (instrucciones en `assets/CREDITS.md`). |

### Pendiente
- [ ] **Tu prueba**: el look nuevo (¿sigue plano? ¿muy oscuro?), cada clima y la prueba de rendimiento con el público y la noche (si baja de 60 FPS, agrego un ajuste de calidad).
- [ ] Si querés más realismo: bajar las texturas de césped de `assets/CREDITS.md`.

## Visual 1 — Que se vea como la referencia (antes de la Fase 4, a pedido tuyo)

### Hecho (parte 1)
- [x] **Capa de presentación separada** (`PlayerVisual`): la simulación no cambia; la capa recibe velocidad, estado y eventos (patear, pasar, cabecear, lateral, atrapar, estirada izquierda/derecha, barrida, caída). Misma interfaz que va a usar el modelo con esqueleto.
- [x] **Humanoide provisorio** por piezas (camiseta, short, medias y botines con los colores del club; piel y pelo variados) con animación por código: carrera con zancada y braceo según la velocidad, inclinación al acelerar, patada, pase, cabezazo, lateral, estirada del arquero, barrida y caída.
- [x] **Cámara "WE" por defecto**: alta y lejana con lente cerrada (30 m de alto, 36 m de distancia, FOV 28°), como la referencia. La TV anterior sigue en el ciclo de cámaras (C / Select).
- [x] **Cancha y luz de día**: césped verde más claro con franjas suaves; sol más alto (sombras cortas) y ambiente más claro.
- [x] **Flecha** del jugador controlado: cono del color del humano sobre la cabeza (antes el ▼ no se dibujaba) + anillo en el piso.
- [x] Triángulo (arquero sale a achicar) funciona con el rival **en cualquier parte de tu campo** (antes sólo a menos de 30 m del arco) y también con la pelota suelta que tocó el rival.

### Hecho (parte 2)
- [x] **Modelos CC0 de Quaternius** integrados (`ModelVisual`): cuerpo con esqueleto de 65 huesos (Universal Base Characters) + animaciones de la Universal Animation Library (mismo esqueleto). Si faltaran los archivos, se usa el humanoide provisorio.
- [x] **Colores del club por zona** (camiseta, short, medias, piel, botines, pelo; guantes del arquero) con un shader; la zona se calcula una vez sobre la malla.
- [x] **Locomoción** según la velocidad (quieto, caminar, trotar, sprint) con la cadencia ajustada a la velocidad real.
- [x] **Gestos de fútbol** que la librería no trae, moviendo huesos encima de la animación: patada, pase, cabezazo, saque con la mano, atajada, estirada a cada lado, barrida y caída; inclinación del torso al acelerar.
- [x] Costo: la animación de los 22 jugadores lleva ~0,6-1,6 ms por cuadro (test incluido), muy por debajo de los 16,6 ms de 60 FPS.

### Ronda 3 (tu prueba de los modelos + tráiler de ForeverEleven)
| Pedido | Cambio |
|---|---|
| El radar tapa la banda cercana | Se vuelve casi transparente cuando la pelota o tu jugador pasan por detrás. |
| El arquero no vuela al atajar | Estirada de verdad: despega, vuela de costado con los brazos extendidos y cae (≈1 s). |
| No se ve cabezazo, remate ni pase | Gestos más largos y amplios: carga atrás, golpe, acompañamiento y giro de torso; salto al cabecear. |
| No hay gesto de entrada | Entrada de pie con la pierna adelante (X); la barrida ahora abre los brazos. |
| Siempre corren igual / trote rápido / no caminan | La IA se acomoda al paso que pide la distancia (camina cerca, trota a media distancia, corre sólo si quedó lejos o es urgente). Animación: caminar hasta 2,4 m/s, trote hasta 6,6, sprint sólo corriendo de verdad; cadencia ajustada. Inclinación de esfuerzo en el sprint. |
| Círculo (B) barre, X (A) entra | Defendiendo: X mantenido = presión + entrada; Círculo = barrida; Cuadrado ya no barre. |
| Triángulo no es pase en profundidad | Pase al hueco con adelanto largo (9-24 m) y que cae **detrás de la última línea** rival. |
| Visual como ForeverEleven | Carteles LED negros "MASTER ELEVEN." alrededor de la cancha; césped verde natural más apagado y mate; luz de menos contraste, tonemap ACES y oclusión ambiental (Forward+). |

### Ronda 5 (segunda tanda de animaciones + movimiento WE2002)
| Pedido | Cambio |
|---|---|
| Moverse en 8/16 direcciones como el WE2002 | `StickDirections`: el stick del humano se lleva al rumbo fijo más cercano (8 por defecto), en coordenadas de pantalla y con histéresis para que no haga zigzag. Desde la pausa: 8 → 16 → libre (`tuning.stick_directions` fija el inicial). Los pases siguen apuntando con el ángulo exacto del stick. La CPU se mueve libre. |
| Entrada de pie (X) | Clip de estocada con la pierna (`Soccer Tackle 1`, sólo el tramo del cruce). |
| Recepción | Control con la suela al recibir frenado; de pecho si llega alta (gesto por código). A la carrera, sin gesto (como en WE). |
| Caídas | La barrida que roba **derriba** al que conducía (50 %, `slide_trip_chance`): cae, queda en el piso y se levanta en 1,7 s (`trip_duration`), sin poder jugar mientras tanto. Clip de caída + clip de levantarse ajustado para terminar justo cuando vuelve a jugar. |
| Más atajadas | Según la altura: arriba con salto, a media altura, abajo agachado; achique a los pies con el cuerpo. Saque con la mano rodando con gesto de bochas. **Paso lateral**: el arquero se acomoda de costado sin dejar de mirar la pelota. Tras un gol, el arquero se lamenta. |
| Festejos | El goleador hace la medialuna y se queda festejando hasta el saque del medio. |
| Revisión | `tools/clip_sheet.gd`: hoja de cuadros de cualquier clip (para elegir tramos); los clips que en Mixamo giran el cuerpo se adaptan sin ese giro (el rumbo lo manda la simulación). |

Corrección: antes del saque del medio todos se seguían acomodando con la pelota quieta; ahora quedan quietos en su puesto (CPU y humano) hasta que se saca.

### Ronda 5b (tu prueba)
| Falla / pedido | Cambio |
|---|---|
| El arquero ataja, se cae y la pelota queda flotando | En las manos, la pelota sigue el punto medio de las manos del modelo (atajada, estirada, achique, caída). |
| No cabecean / no saben cuándo | Duelo aéreo: la pelota alta que nadie puede bajar con el pecho la cabecea el que llega (alcance 1 m, hasta 2,6 m de altura saltando). CPU: cerca del arco rival, **remate de cabeza**; en su campo, **despeje** largo; si no, pase de cabeza. Los compañeros del destinatario de un pase no se la "roban" de cabeza (la deja bajar y la controla). Tu jugador cabecea cuando tiene una orden: tiro = cabezazo al arco, pase = pase de cabeza. |
| Orden que espera la pelota (WE) | Pase / tiro pedido antes de tener la pelota queda **esperando hasta que llega** (antes vencía a los 0,55 s): se ejecuta de primera o de cabeza apenas está al alcance. Con el stick suelto el jugador va a buscarla. Se pierde si el rival la anticipa, si se corta el juego o con **R2 / E (cancelar)**. Mientras espera no se cambia de jugador solo. |
| La pelota sale del aire, no del pie | El gesto arranca justo en el golpe y la pelota se **dibuja saliendo del pie** (o de la frente) y en 0,08 s se acomoda a su posición real (sólo presentación). |

### Ronda 5c: controles a tu gusto y combinaciones del WE
| Pedido | Cambio |
|---|---|
| Mapa de botones | X pase, Cuadrado remate, Círculo centro, Triángulo profundidad, R1 correr, L1 gambeta / combinaciones (sin la pelota: cambio de jugador), cruceta y stick izquierdo para moverse. Se quitó el cancelar con R2 / E. |
| Menús con X | `ui_accept` incluye X (botón inferior) y `ui_cancel` Círculo, en el menú inicial y en la pausa. |
| L1 + Cuadrado / doble Cuadrado | Globo (picada por arriba del arquero) / remate rasante por el piso. El doble toque espera 0,2 s un segundo toque antes de patear. |
| L1 + Círculo / doble Círculo | Centro alto (más bombeado) / centro raso (tenso, por el piso). |
| L1 + X | Pared: el compañero la devuelve de primera al espacio y el que la tocó pica (con el stick suelto). |
| L1 + R1 | Super cancel: cancela la orden guardada, la pared y la carrera automática a la pelota. |
| L1 mantenido | Conducción cerrada: pelota pegada, giros más cortos, algo más lento. |
| L1 x3 / stick derecho 360° | Bicicleta (después, pique) / marsellesa (clip `Soccer Spin`; mientras gira, la entrada rival tiene 35 % de su chance). |
| Cuadrado + X / Círculo + X | Enganche: hace el gesto de patear, engancha para el lado del stick (o lejos del rival) y los rivales cerca de la CPU quedan medio segundo sin reaccionar. |
| Pelota aérea | X pase de cabeza; Círculo despeje (pie o cabeza); Cuadrado: despeje de cabeza en campo propio, remate de cabeza en el rival (volea si viene más baja). |
| Cuadrado defendiendo | Mantenido: el compañero de la CPU más cercano sale a presionar. |

Sin usar por ahora: `Kick Up` / `Stall Soccerball` (sin pelota se ven raros), `Soccer Spin` (va con los amagues de la Fase 4), `Receiver Catch` (es de fútbol americano), `Defender` y `Situp To Idle`.

### Cierre de Visual 1 (comparación con ForeverEleven en Forward+)
Hasta ahora las capturas salían en Compatibilidad; esta vez se compiló Godot
con Vulkan y se comparó en **Forward+**, que es lo que corre en tu máquina.
| Diferencia con la referencia | Cambio |
|---|---|
| En Forward+ todo salía oscuro y los jugadores casi negros (a contraluz) | Sol del lado de la cámara (los jugadores quedan iluminados de frente), exposición 1,2, luz ambiente 1,0, oclusión ambiental más suave. |
| Césped oscuro | Césped más claro y amarillento, con franjas suaves (como la referencia). |
| Cámara casi cenital (40°) | Cámara "WE" más baja (≈24°, lente 25°): se ve la perspectiva de la cancha y la tribuna de enfrente, como en ForeverEleven. |
| Butacas lavadas a blanco | Butacas con el color del club más profundo y saturado. |
| Medir los 60 FPS | **Prueba de rendimiento** en el menú principal (30 s de CPU vs CPU): promedio, 1 % más lentos y peor cuadro; queda guardada en `benchmark.txt`. FPS también en F9. |

### Pendiente
- [ ] **Tu prueba**: correr la prueba de rendimiento y pasarme el resultado (criterio: 1 % más lentos ≥ 55 FPS).
- [ ] Tu opinión del look nuevo y de los movimientos (si algo se ve raro, un video corto).
- [x] Tribunas de dos bandejas (también detrás de los arcos), butacas con respaldo y color parejo, barandas metálicas y frente oscuro de la bandeja superior.
- [x] Número en la espalda (sigue al torso; blanco o negro según la camiseta).
- [x] Iluminación global (SDFGI) y un leve brillo en Forward+ (en Compatibilidad se ignora).
- [x] **Animaciones de fútbol de Mixamo** (`MixamoLibrary`): retarget al esqueleto de Quaternius al cargar (≈0,1 s para 13 clips), sin desplazamiento propio (al jugador lo mueve la simulación). Remate, pase, cabezazo, barrida, conducción; arquero en espera, atajada, estirada a cada lado (una espejada) con vuelo lateral, saque con la mano y con el pie. El clip arranca de modo que el golpe coincida con la salida de la pelota. Los FBX **no van en el repo** (licencia; repo público): ver `assets/CREDITS.md`. Sin ellos, gestos por código.
- [ ] CPU vs CPU: el apoyo cerca del portador bajó a 88-93 % (antes 93-98 %) porque ahora se acomodan caminando/trotando; vigilar.

---

## Fase 3 — IA de partido (en curso)

### Hecho
- [x] **Roles tácticos** por puesto (`TacticalRole`: ARQ, DFC, LAT, MCD, MC, MCO, VOL, EXT, DC) y **5 formaciones** como datos (`data/formations/`): 4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 5-3-2. Aurora juega 4-3-3 y Halcones 4-4-2.
- [x] **Zonas**: 3 tercios x 5 carriles (`Zones`).
- [x] **Forma del equipo** (`TeamShape`): la línea defensiva sube y baja con la pelota, las líneas se estiran al atacar y se juntan al defender, el bloque se abre con la pelota y se cierra sin ella corriéndose al lado de la pelota; el lateral del lado de la pelota pasa y el otro cierra; los delanteros quedan en la última línea; el volante defensivo siempre detrás de la pelota; sin la pelota casi todos detrás de ella; los defensores forman línea.
- [x] **IA de equipo** (`TeamAI`, reemplaza a la IA provisoria) con estados DEFENSA, SALIDA, ATAQUE, CONTRAATAQUE, PRESIÓN (contrapresión al perderla arriba) y REPLIEGUE (cuando quedaron muchos adelante de la pelota).
- [x] **Roles del momento**: apoyos en triángulo cerca del que tiene la pelota (también del humano), desmarque en la última línea para el pase al hueco, presión (1 o 2), cobertura y marcas en zona.
- [x] **Decisiones del portador** según el estado: salida paciente, ataque que busca progresar, contraataque vertical, centros con gente en el área, remate según distancia y línea de tiro.
- [x] **Pelotas paradas** (`SetPieceShape`): saque de arco con salida escalonada (centrales abiertos) y presión alta del rival; laterales con dos opciones cortas; córners con cinco cabeceadores, opción corta y dos atrás, y defensa con palos, zona y rebote. La IA se ubica desde que la pelota sale.
- [x] **Arquero** (`GoalkeeperController`): ubicación (líbero si el equipo defiende alto), atajada con el modelo de la Fase 2, achique, salida a los centros, reposición según el estado (corta, rápida en contra, larga si presionan).
- [x] **Dificultad** Fácil / Normal / Difícil (menú principal y pausa; sólo afecta a la CPU). En la pausa también se cambia la formación del equipo propio.
- [x] Debug F9 muestra el estado táctico, formación y dificultad de cada equipo y la posición táctica de cada jugador.
- [x] Tests (88): forma del equipo, estados, acompañamiento del portador, córner, saque de arco, lateral, cambio de formación.
- [x] Pulido tras tu prueba (ver abajo): arquero, achique con Triángulo, pases de primera/atrás/horizontales, control aéreo. Tests: 99.

### Resultado en simulaciones CPU vs CPU (3 min)
Siempre hay un compañero a menos de 15 m del que tiene la pelota (96-99 %); 4-8 tiros y 0-4 goles por partido; posesión repartida; los equipos pasan por todos los estados.

### Pendiente
- [ ] **Tu prueba**: ¿la CPU juega "como un equipo" y un partido contra ella es competitivo?
- [ ] Offside y trampa del offside quedan con las reglas (Fase 4).

### Primera ronda de pulido (tu prueba de la Fase 3)
Te gustaron la dificultad y el acompañamiento en ataque y defensa. Cambios por cada reclamo:

| Reclamo | Causa encontrada | Cambio |
|---|---|---|
| "Siempre que patean a mi arco es gol" | El modelo de atajada aislado andaba (~75 % en el área), pero en el partido: (1) un remate desviado en un defensor dejaba el plan viejo y el arquero **no podía tocar** la pelota nueva; (2) el arquero despejaba de volea y la pelota rebotaba en el delantero que presionaba y volvía al arco; (3) de líbero se adelantaba hasta 14 m y volvía caminando. | Todo desvío invalida el plan; si el desvío va fuerte al arco se replanifica (con +0,12 s de reacción) y si es flojo el arquero la agarra normal. El despeje del arquero no se puede cortar los primeros 0,3 s. Líbero hasta 9 m y vuelve corriendo. `SaveModel` ahora evalúa todo el tramo final del remate: adelantado achica el ángulo, pero una vaselina le pasa por arriba. KPI: 75 % de atajadas en el área, **90 % de afuera del área**. En la simulación con un "humano" que presiona: de 6 goles recibidos a 1 (9 tiros, 5 atajadas). |
| Triángulo para que salga el arquero | — | **Triángulo mantenido defendiendo**: el arquero sale a achicar al que lleva la pelota (hasta 30 m del arco); fuera del área va a la entrada. |
| Pase de primera "sale a cualquier lugar" | Con el stick apuntando al próximo compañero, el receptor **caminaba hacia ese lado** en vez de ir a la pelota; la orden guardada vencía a los 0,55 s (antes de que llegara un pase largo) y el receptor se elegía desde la pelota en el aire. | Con un toque de primera pedido, el stick sólo apunta: el receptor sigue yendo a la pelota; la orden dura hasta que llega; el receptor se elige desde el pie del que va a patear. Test: 8/8 al compañero del stick. |
| Pases hacia atrás y horizontales cuestan | La ayuda sólo corregía el 88 % del ángulo hacia el receptor (la IA siempre apunta exacto); el pase corto con toque corto de botón salía flojo; pasar "con el cuerpo cruzado" sumaba hasta 4° de error. | Ayuda al 97 % (como la IA: el error lo ponen atributos, presión y cansancio); pase corto siempre firme (7-10 m/s al llegar); orientación del cuerpo hasta 1,5°. Tests: atrás 100 %, horizontal 100 % (rivales lejos). |
| Los pases aéreos no se controlan | Sólo se controlaba por debajo de 1,1 m: un pase largo pasaba de largo o picaba alto. | **Control con pecho/muslo**: el receptor del pase la baja hasta 1,9 m (cualquier otro hasta 1,5 m) y la pelota cae mansa al pie. El pase largo siempre busca a alguien en la dirección del stick (hasta 100°). Test: 100 % de pases largos controlados. |

### Segunda ronda de pulido (tu video + "tiene que jugarse como WE2002")
| Reclamo | Cambio |
|---|---|
| El arquero agarra con la mano el pase atrás y no se lo puede usar | **Regla del pase atrás**: si un compañero se la pasa a propósito (pie o lateral) y nadie más la toca, el arquero la controla con los pies y se juega como un jugador más. **Con la pelota (manos o pies) al arquero lo maneja el humano**, como en WE. Con la pelota en las manos camina dentro del área (no sale). |
| El arquero "la lanza para arriba" | Desde las manos: **X / Triángulo = saque con la mano rodando**; **Círculo / Cuadrado = pelotazo**. La IA sale jugando rodando si hay un compañero libre y sólo revienta si la presionan. Con los pies no se la duerme (0,5 s). |
| Pases que tardan en salir | El que conduce **patea en el mismo instante** (antes esperaba que la pelota volviera al pie tras el toque). |
| Pases lentos / los cortan | Pase corto más fuerte (llega a 10-13 m/s). Un pase firme sólo lo corta el que está **en la línea** (el radio de intercepción se achica con la velocidad). |
| El receptor la controla mal | Radio de recepción 1,1 → 1,4 m; el primer control amortigua pases más fuertes. |
| Giros lentos o raros | Giro casi instantáneo (24 rad/s; en sprint 10) y **cortes secos**: más de 100° frena en seco y sale para el otro lado (de sprint a 3 m/s para atrás en 0,37 s). Se acelera hacia donde pide el stick, sin arcos de "auto". |
| No se ve a quién manejo | Flecha más grande sobre la cabeza + **anillo en el piso** del color del humano; sombra de la pelota más marcada. |

Tests: 104 (nuevo `test_we_feel`: pase atrás con los pies y arquero manejable, saque rodando, arquero no sale del área con la pelota en la mano, pase instantáneo, corte seco).

### Para la Fase 4 (de tu prueba)
- Energía: fatiga acumulada en minutos de juego y entre tiempos (hoy nadie se cansa en un partido de 5 minutos reales).

---

## Fase 2 — Prototipo 0.1 (en curso)

### Hecho
- [x] `Claude.md` fusionado con la visión "WE2002 modernizado" y fases reordenadas.
- [x] Estructura de carpetas nueva (`scripts/{player,ball,camera,tactics,stadium,...}`, `systems/input`, `data/{teams,formations,config}`).
- [x] Datos en recursos: `PlayerData` (atributos 1-99), `TeamData`, `FormationData`; 2 equipos ficticios de 16 jugadores en `data/teams/*.tres` (regenerables con `tools/generate_data.gd`).
- [x] Input desacoplado: `InputSource` → `HumanInput` (teclado/mando) y `ScriptedInput` (tests). `HumanController` ya no lee el singleton `Input`.
- [x] **Pelota independiente al conducir** (`Dribble`): toques que la hacen rodar libre; la distancia depende de velocidad (trote corto, sprint largo), `ball_control` y presión rival. Toque de giro y asistencia de conducción para doblar con la pelota.
- [x] Recepción con primer control según `ball_control` y velocidad de la pelota; el receptor humano va al encuentro con el stick suelto.
- [x] Defensa por timing: entre toques la pelota queda expuesta y el rival bien ubicado se la queda; con la pelota en el pie sólo por contacto y con menos probabilidad (defensa vs control, más difícil desde atrás).
- [x] Giro dependiente de la velocidad (rápido lento, amplio en sprint) y atributos de velocidad/aceleración.
- [x] Pases con asistencia parcial (`pass_assist`), error por atributos/presión/orientación/potencia; centro automático desde la banda; remates con error, cabezazo y volea según la altura.
- [x] Cámara configurable con modos **TV / Amplia / Cercana / Vertical / Dron** (`data/config/cameras/*.tres`), cambio con C / Select; controles relativos a la cámara (en Vertical, arriba = hacia el arco rival).
- [x] HUD simple (`AUR 1 - 0 HAL` + reloj, jugador seleccionado, barra de potencia chica abajo al centro) e indicador discreto sobre la cabeza.
- [x] HUD estilo WE2002 (según tus imágenes de referencia): colores de equipo + marcador arriba a la izquierda, "1st 27:57" arriba a la derecha, **radar** abajo al centro, paneles abajo a los costados con posición (GK/DF/MF/FW), nombre, barra de energía (llena hasta la Fase 4) y barra de potencia amarilla encima.
- [x] Primer pase de ambientación (adelanto de la Fase 5, según las capturas de ForeverEleven): estadio modular (`StadiumBuilder`) con tribunas escalonadas de butacas instanciadas en el color del club local y su nombre escrito con butacas, techo con vigas que proyectan franjas de sombra, muro perimetral oscuro, carteles lisos, bancos, túnel y área técnica; césped con shader (franjas de corte + variación natural); sol bajo con sombras largas, tonemapping fílmico.
- [x] Capturas automáticas para revisar la presentación: `godot -- --capture=<carpeta>` (con `xvfb-run` en Linux sin pantalla).
- [x] Modo debug **F9**: estado del partido, posesión, pelota, presión, error del último pase/tiro, estados de IA; trayectoria de la pelota, objetivos y posiciones tácticas en 3D.
- [x] Tests: 45 (física, reglas, reloj, receptor, formación, conducción, giro, pase con input programado, precisión, humo de partido, debug).

### Pulido tras la primera prueba (tu feedback)
| Feedback | Cambio |
|---|---|
| "La pelota no tiene control, siempre se le termina yendo" | Conducción guiada: un resorte mantiene la pelota delante del pie con toques visibles (0,3 m trotando, hasta ~0,9 m en sprint); ya no se escapa sola. Bajo presión y yendo lento, el jugador la cubre con el cuerpo. |
| "No me da seguridad que el defensor robe; no protege" | Entradas con timing: presionar (pase corto mantenido) intenta la entrada al llegar a ~1,3 m; éxito según ángulo (de frente 70 %, costado 45 %, atrás 18 %), defensa vs control y pelota expuesta; si falla, el defensor queda desbalanceado. Se eliminó el robo por roce constante. |
| "El receptor no la domina con seguridad" | Primer control que amortigua casi toda la velocidad; radio de recepción mayor para el receptor del pase. |
| "El arquero ataja todas" / "toda la potencia es lo mismo que poca" | La potencia define velocidad **y altura de llegada** al arco. Modelo de atajada (`SaveModel`): reacción + desplazamiento + alcance del arquero contra tiempo y distancia del tiro; fuerte y colocado suele ser gol, flojo al medio se ataja; rebotes al costado. |
| "Pases y tiros un poco frustrantes" | Menos error por atributos/presión/orientación y más asistencia (`pass_assist` 0,88). |
| "No veo el lateral en la banda cercana" / "el techo tapa" | La cámara sigue más a lo ancho; la tribuna, bancos y túnel del lado de la cámara sólo proyectan sombra. |
| "Agregá controles de cámara" | Modos TV, Amplia, Cercana, Vertical, Dron. |

CPU vs CPU (3 min) tras el pulido: 2-0, 1-2, 0-0 con ~10 tiros por partido y entradas ganadas/perdidas.

### Tercera ronda (tu 2.ª prueba + informe de física)
| Tema | Cambio |
|---|---|
| "Pasar es sacarse la pelota de encima, no busca al jugador" | Mientras se carga la barra se marca en el piso al receptor (se corrige con el stick) y al soltar queda trabado; se recuerda la última dirección del stick (0,35 s); el pase corto siempre busca a un compañero. |
| Informe de física: pelota | Arrastre físico con crisis de arrastre, masa 0,43 kg, Magnus en rad/s, rebote en césped 0,6, tiro máx. 108 km/h, pases rasantes por integración numérica. KPIs en tests (rebote FIFA, comba de tiro libre, pelotazo). |
| Informe de física: jugadores | Energía (sprint gasta, descanso recupera, cansado más lento e impreciso) visible en el HUD; tiempo de reacción de la IA 0,15-0,25 s. |
| Informe de física: arquero | Reacción 0,25-0,40 s; KPI de atajadas en el área 74 % (< 75 %). |
| Árbitro, faltas, lesiones, ragdoll | Planificados en Fases 4 y 5 (ver `docs/FISICA.md` y `Claude.md`). |
| Cámara | TV queda como predeterminada. Personalizada y desde el córner: Fase 5. |

### Cuarta ronda (tu 3.ª prueba)
| Tema | Cambio |
|---|---|
| "Me obliga a soltar el stick para que el receptor no se vaya a otra dirección" | Recepción trabada: tras el pase, el stick que quedó apretado en la dirección del pase se ignora y el receptor va al encuentro de la pelota; el control vuelve al soltar el stick o al moverlo > 50° hacia otro lado. Test que reproduce el problema (sin la corrección el receptor se escapaba 24 m). |
| "El aro que no se vea" | La marca del receptor queda oculta por defecto (`GameSettings.show_pass_target`); el receptor se elige y se traba igual. Activarla será una opción de ayudas visuales (Fase 8). |
| Energía en el segundo tiempo | Anotado para la Fase 4: el cansancio se acumula entre tiempos y el entretiempo recupera sólo una parte. |

### Pendiente
- [ ] **Tu prueba** con el "criterio de éxito del gameplay" de `Claude.md` y ajuste de `data/config/tuning.tres` / `cameras/*.tres` según tu feedback.
- [ ] La IA sigue siendo la provisoria (Fase 3): CPU vs CPU es muy conservadora.

### Cambios a código ya entregado (Fase 2)
- Archivos movidos de carpeta sin cambios de lógica (ver commit "migración").
- `scripts/ball/ball.gd`: la conducción ya no "pega" la pelota al pie; ahora son toques con física libre. `give_to(player, receive)` aplica primer control.
- `scripts/player/footballer.gd`: `setup()` recibe `PlayerData`; giro según velocidad; atributos de velocidad y aceleración; se quitó el aro del piso (indicador discreto).
- `scripts/player/human_controller.gd`: recibe un `InputSource`; sólo patea con la pelota al alcance (si no, guarda la orden); recepción asistida.
- `scripts/player/kick_actions.gd`: asistencia parcial y error en pases/remates; centros; cabezazo/volea. Se quitó `Tuning.shot_error_max` (reemplazado por `KickAccuracy`).
- `scripts/match/match_controller.gd`: equipos desde `TeamData`; `can_kick`; asistencia de conducción; robo por pelota expuesta; `loose_ball_intercept` compartido con la IA; debug.
- `scripts/core/tuning.gd`: parámetros de cámara movidos a `CameraConfig`; nuevos `dribble_lose_distance`, `turn_rate_sprint`, `turn_rate_ball_factor`, `intercept_rate`, `pass_assist`.
- `scripts/camera/match_camera.gd`: reescrita con `CameraConfig`.
- `scripts/ui/match_hud.gd`: reescrito al estilo WE2002 (radar, paneles de jugador, reloj "1st/2nd").
- `scripts/stadium/pitch_builder.gd`: el césped pasa a un shader; se quitaron los carteles y el bloque de tribuna (ahora en `StadiumBuilder`).
- `scripts/match/match_controller.gd`: iluminación en `_build_lighting()` (sol bajo desde atrás de la tribuna principal) y estadio agregado.
- `scripts/camera/camera_config.gd`: cámara más baja y alejada para que se vea la tribuna del fondo como en la referencia.
- Pulido (segunda ronda): `scripts/ball/dribble.gd` y `ball.gd` (conducción guiada en vez de toques libres; se quitó la asistencia de conducción de `match_controller.gd`), `match_controller.gd` (entradas, recepción, plan de atajada, toasts, `screen_to_world`), `scripts/goalkeeper/save_model.gd` (nuevo), `simple_ai.gd` (la IA pide entradas y el arquero usa el plan de atajada), `kick_actions.gd` (altura de llegada del remate), `kick_accuracy.gd` (menos error), `tuning.gd` (parámetros de conducción, entradas y remate; se quitaron `steal_*` y `shot_angle_*`), `camera_config.gd`/`match_camera.gd` (modos), `stadium_builder.gd` (tribuna del lado de la cámara sólo sombra; letras de la tribuna al derecho), `human_controller.gd` (stick relativo a la cámara, entradas). `data/config/camera.tres` se reemplazó por `data/config/cameras/*.tres`.

---

## Fase 1 — Base jugable ✅

Cancha 105x68, arcos con red, pelota con física propia, 11v11 placeholders,
control humano con barra de potencia, cambio de jugador, reglas mínimas, cámara
de TV, HUD, IA provisoria, menú y pausa, tests.

Correcciones hechas al validarla con Godot real: `move_and_slide()` movía ~8x
de más (reemplazado por integración propia), pelota disparada al soltarse,
arquero empujado dentro del arco, reglas antes que posesión, HUD creado antes
que los controladores, bucles tipados para Godot 4.7.

### Limitaciones conocidas (se resuelven en fases siguientes)
- El arquero siempre lo maneja la IA.
- Sin faltas, tarjetas, offside ni penales (Fase 4).
- Una sola formación (4-4-2) y sin TeamAI (Fase 3).
