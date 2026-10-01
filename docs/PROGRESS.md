# Progreso — Master Eleven

Motor: **Godot 4.7.2**, GDScript. Referencia de gameplay: WE2002 (ForeverEleven).
Ver `Claude.md` para visión, criterios y fases.

| Fase | Estado |
|------|--------|
| 1 — Base jugable | ✅ Hecha |
| 2 — Prototipo 0.1: sensación de juego | ✅ Hecha (PR #2) |
| 3 — IA de partido (TeamAI, formaciones, zonas, arquero) | 🟡 Implementada, **pendiente de tu prueba** |
| Visual 1 — Se ve como la referencia (jugadores animados, cámara, cancha) | 🟡 Implementada, **pendiente de tu prueba** |
| 4 — Reglas, atributos y plantel | ⬜ |
| 5 — Presentación moderna (estadio, modelos, animaciones, audio) | ⬜ |
| 6 — Liga Master | ⬜ |
| 7 — Torneos | ⬜ |
| 8 — Pulido | ⬜ |

---

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

Sin usar por ahora: `Kick Up` / `Stall Soccerball` (sin pelota se ven raros), `Soccer Spin` (va con los amagues de la Fase 4), `Receiver Catch` (es de fútbol americano), `Defender` y `Situp To Idle`.

### Pendiente
- [ ] **Tu prueba** de esta ronda (8 direcciones y animaciones nuevas).
- [ ] Cierre de Visual 1: capturas lado a lado con ForeverEleven y 60 FPS en tu máquina.
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
