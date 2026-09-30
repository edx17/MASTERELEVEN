# PROYECTO "MASTER ELEVEN": sucesor espiritual moderno de Winning Eleven 2002 — Liga Master

## Visión
Juego de fútbol 3D para PC que toma el **gameplay y la lógica de Winning Eleven
2002** (y la filosofía de WE4) y los lleva a un motor 3D moderno con
presentación limpia. Referencia principal: el proyecto fan "ForeverEleven —
Winning Eleven 2002 Remastered": estadio 3D moderno, buena iluminación y césped,
jugadores relativamente simples, pero una lógica de partido que conserva WE2002.

- NO es un clon visual de PS1: nada de gráficos pixelados ni estética retro obligatoria.
- NO es "EA FC simplificado": estructura directa, pocos sistemas, bien hechos.
- SÍ es: "Fútbol 11v11 rápido, directo y táctico, con controles sencillos y mucha
  importancia en el timing". Gameplay de WE2002 + 3D moderno + arquitectura modular.

**El gameplay es el producto. Los gráficos son el envoltorio.**

El objetivo final sigue siendo el modo **Liga Master** (carrera de club con
ascensos, descensos, transferencias, torneos internacionales y Mundial), pero
recién después de que el partido se sienta bien.

### Prioridades (en este orden)
1. Gameplay  2. Respuesta de controles  3. Movimiento de jugadores
4. Física/control de pelota  5. IA  6. Cámara  7. Animaciones  8. Gráficos  9. Menús

### Principios de juego
- La pelota se siente **independiente** del jugador: al conducir queda cerca pero
  no pegada; la distancia depende de velocidad, dirección, control y presión.
- Los jugadores se sienten controlables y responsivos; el giro depende de la
  velocidad (rápido a baja velocidad, más amplio en sprint; nunca 180° instantáneo).
- Los pases requieren dirección + potencia + atributos: hay ayuda leve para
  encontrar receptor, pero se puede fallar.
- Los remates requieren timing; la precisión depende de atributos, orientación
  del cuerpo, presión y distancia. El remate se siente inmediato.
- Defender requiere timing: el defensor no roba automáticamente; la proximidad
  y el momento importan; una entrada mal hecha falla.
- La IA se posiciona: nadie corre en manada detrás de la pelota; el equipo se
  mueve como unidad (formación, zonas, estados tácticos).
- Cámara de transmisión de TV: elevada, lateral/diagonal, sigue la zona de la
  pelota con suavidad, no sigue sólo al jugador controlado.

### Criterio de éxito del gameplay (antes de agregar contenido secundario)
- correr se siente natural y girar se siente responsivo
- la pelota se siente independiente
- pasar requiere intención; rematar y defender requieren timing
- los compañeros buscan espacios y los rivales mantienen estructura
- el arquero reacciona (y no es perfecto)
- la cámara permite leer la jugada
- jugar 10 minutos resulta entretenido
Si esto no funciona, NO se agregan sistemas: se corrige el gameplay primero.

## Restricciones
- SIN LICENCIAS: todos los clubes, jugadores, ligas, torneos y selecciones son
  ficticios. Nada de nombres, logos, música, modelos, texturas ni assets de
  Konami ni de marcas reales.
- Portable para PC (Windows prioritario; Linux/Mac deseable). Objetivo: 60 FPS
  con 22 jugadores.
- Jugable 100% con teclado o con mando (DualShock/DualSense/Xbox), con
  detección automática y remapeo desde opciones.
- Solo assets libres (CC0 o de producción propia). Animaciones: Mixamo o
  similares con licencia compatible. Documentar el origen de cada asset en
  /assets/CREDITS.md.

## Stack y decisiones técnicas tomadas
- Motor: Godot 4 (4.7.x), GDScript. Tests con GUT (addons/gut).
- Física de la pelota: propia y determinista (BallPhysics), no RigidBody3D,
  con los valores del informe técnico de física (ver docs/FISICA.md).
- Jugadores: CharacterBody3D movidos por código, sin física de cuerpos entre ellos.
- Parámetros de sensación de juego y de cámara en recursos .tres editables.
- Datos (jugadores, equipos, formaciones) en Resources (.tres) o JSON; nunca
  hardcodeados en la lógica. Partidas guardadas en JSON en user://.
- Control desacoplado del singleton Input: fuentes de input intercambiables
  (HumanInput / AIInput / en el futuro NetworkInput). Multiplayer online: no
  por ahora, pero la arquitectura no debe impedirlo.
- IA: movimiento a 60 Hz, decisiones locales ~10 Hz, decisiones de equipo 3-5 Hz.
  Steering y posiciones tácticas, sin pathfinding completo por frame.
- Modo DEBUG con F9 (jugador seleccionado, posiciones tácticas, objetivos,
  estado de IA/TeamAI, posesión, trayectoria de la pelota).
- Control de versiones: Git + GitHub. Commits chicos y descriptivos por hito.

## Controles (estilo WE)
| Acción                 | Mando          | Teclado     |
|------------------------|----------------|-------------|
| Mover                  | Stick izq/cruz | WASD        |
| Pase corto / presión   | X / A          | J           |
| Tiro / barrida         | Cuadrado / X   | K           |
| Pase largo / centro    | Círculo / B    | L           |
| Pase al hueco          | Triángulo / Y  | I           |
| Sprint                 | R1 / RB        | Shift       |
| Cambiar jugador        | L1 / LB        | Q           |
| Pausa                  | Start          | Esc         |
| Cambiar cámara         | Select / Back  | C           |
| Debug                  | —              | F9          |
La potencia de tiro y pase se gradúa manteniendo el botón (barra de potencia).
Todo definido en el Input Map de Godot, nunca hardcodeado.

## Estructura
```
scenes/    match/ players/ ball/ stadium/ ui/
scripts/   player/ ball/ ai/ tactics/ match/ camera/ goalkeeper/ ui/ core/
systems/   input/ possession/ replay/ save/
data/      players/ teams/ formations/ config/
assets/    models/ textures/ animations/ audio/ fonts/
tests/
docs/
```

## FASES (no avanzar a la siguiente sin cumplir los criterios de aceptación)

### Fase 1 — Base jugable ✅ (hecha)
Cancha, pelota con física propia, 11v11 con placeholders, control humano con
barra de potencia, cambio de jugador, reglas mínimas (gol, lateral, córner,
saque de arco, saque del medio), cámara de TV, HUD, IA provisoria, menú, tests.

### Fase 2 — Prototipo 0.1: sensación de juego ✅ (hecha)
Movimiento → cambio de jugador → control de pelota → pase → recepción →
remate → arquero → gol, todo con sensación WE2002:
- Conducción con pelota independiente (toques; distancia según velocidad,
  control y presión) y robo por proximidad/timing.
- Giro dependiente de la velocidad.
- Pases corto/largo/al hueco/centro con dirección + potencia + atributos; se
  pueden fallar. Remates con error por atributos, orientación, presión, distancia.
- Datos de jugadores (PlayerData, TeamData) en recursos.
- Input desacoplado (HumanInput / AIInput).
- Cámara configurable (altura, distancia, ángulo, seguimiento, anticipación,
  zoom, offsets) al estilo de la referencia.
- HUD simple (LOC 1 - 0 VIS / reloj, jugador seleccionado, barra de potencia) y debug F9.
Criterio: el "criterio de éxito del gameplay" de arriba, jugado por vos con
mando y con teclado.

### Fase 3 — IA de partido (EN CURSO)
- TeamAI con estados DEFENDING, BUILD_UP, ATTACKING, COUNTER_ATTACK, PRESSING,
  RETREATING; TeamShape / DefensiveShape / AttackingShape.
- Formaciones 4-4-2, 4-3-3, 4-2-3-1, 3-5-2, 5-3-2 (formation_slot por jugador).
- Zonas: tercios (defensivo/medio/ataque) x carriles (izq, centro-izq, centro,
  centro-der, der); cada jugador con zona preferencial.
- Roles: defensores mantienen línea, volantes buscan líneas de pase, delanteros
  buscan espacio, extremos dan amplitud.
- Defensa: presionar, contener, entrada, barrida, intercepción, bloqueo, despeje.
- GoalkeeperController: posicionarse, achicar, lanzarse, atrapar, despejar, sacar; con error.
- PossessionManager (TEAM_A / TEAM_B / CONTESTED / FREE_BALL).
- Niveles de dificultad y estrategias rápidas (presión alta, contraataque, offside).
Criterio: un partido vs CPU es competitivo y la CPU juega "como un equipo".

### Fase 4 — Reglas, atributos y plantel
- Faltas, tiros libres, penales, offside, amarillas y rojas (lo necesario, no todo).
- Árbitro con IA (según docs/FISICA.md): cono de visión (~120°, ~20 m), se
  ubica a 10-15 m de la pelota, sólo sanciona lo que ve, con un % de errores
  (10-20 % de faltas no vistas) y criterio de tarjetas por severidad.
- Choques jugador-jugador con fuerza (atributo strength) y lesiones probabilísticas.
- Fatiga de largo plazo (la energía máxima baja durante el partido) sobre la
  energía de corto plazo ya implementada: el cansancio se acumula del primer
  al segundo tiempo (no se reinicia) y en el entretiempo se recupera sólo una
  parte. El desgaste se mide en minutos de JUEGO (el reloj va acelerado: con
  la energía en segundos reales nadie se cansa en 5 minutos) y según lo que
  corrió cada jugador; en el segundo tiempo el cansancio se tiene que notar.
- Atributos que afecten de verdad la jugabilidad (velocidad, aceleración,
  resistencia, fuerza, pase, tiro, técnica, control, cabezazo, defensa, reacción,
  equilibrio, arquero); posiciones y pierna hábil.
- Fatiga y sustituciones; menú pre-partido (formación, titulares, suplentes).
- Remates especiales (colocado, potente, globito, cabezazo, volea).

### Fase 5 — Presentación moderna
- Estadio 3D modular (tribunas, túnel, bancos, área técnica, carteles sin marcas,
  público con sprites/instancing), césped con textura, variación y patrón de corte,
  iluminación moderna (sombras, ambiente, corrección de color, SSAO opcional).
- Modelos low/medium poly animados con AnimationTree (idle, caminar, trotar,
  correr, sprint, girar, pase, pase largo, tiro, cabezazo, entrada, barrida,
  caída, levantarse, festejo); animaciones cortas que no bloqueen el control.
- Camisetas por club, sonido (pelota, público reactivo, silbato), repeticiones
  simples de goles, menús con estética moderna.
- Cámaras adicionales: personalizada (el jugador ajusta y guarda la suya) y
  desde el córner.
- Esqueletos con física (ragdoll en caídas, cinemática inversa al patear).

### Fase 6 — Liga Master
- Base de datos ficticia: al menos 3 países con 2 divisiones cada uno
  (16-20 clubes por división), más selecciones nacionales.
- Temporadas con fixture ida y vuelta, tabla, goleadores.
- Ascensos y descensos automáticos al cierre de temporada.
- Sistema de puntos al estilo WE clásico (se ganan por resultados y se usan
  para fichar) o economía simple; dejarlo configurable.
- Mercado de transferencias: fichajes, préstamos, venta, ventanas de pases,
  negociación simple, IA de los otros clubes que también ficha.
- Evolución de jugadores: crecimiento en jóvenes, pico, declive por edad,
  retiros y regeneración de juveniles.
- Lesiones y suspensiones entre partidos.
- Simulación de partidos no jugados (resultado por fuerza del plantel + azar).
- Guardar y cargar carrera.

### Fase 7 — Torneos
- Copa nacional (eliminación directa).
- Copa continental de clubes (grupos + eliminatorias) para los mejor ubicados.
- Mundial de selecciones cada 4 temporadas (clasificación, grupos,
  eliminatorias), con convocatoria de jugadores de la Liga Master.
- Historial: campeones, palmarés del club, récords.

### Fase 8 — Pulido
- Editor de clubes y jugadores (nombres, atributos, camisetas).
- Opciones: gráficos, audio, controles, duración de partido.
- Ayudas visuales activables: marca del receptor del pase (ya existe,
  apagada por defecto: `GameSettings.show_pass_target`), entre otras.
- Build exportable para Windows con instalador o zip portable.

## Reglas de trabajo
1. Antes de programar cada fase, presentá un plan breve con las tareas y
   esperá mi OK.
2. Trabajá de a una fase. Al terminar, contame qué se hizo, cómo probarlo y qué
   quedó pendiente.
3. Cada vez que modifiques o corrijas código que ya estaba entregado, avisalo
   de forma explícita: qué archivo, qué cambió y por qué. Nunca cambios
   silenciosos.
4. Priorizá que se sienta bien jugar por encima de agregar features. Evitar la
   trampa de "menú precioso y 700 archivos sin poder dar un pase de 5 metros".
5. Código modular y comentado; la lógica de Liga Master desacoplada del motor
   de partido para poder testearla sola.
6. Si una decisión técnica es grande (arquitectura, librerías, formato de
   datos), consultame antes.
7. Mantené actualizado un /docs/PROGRESS.md con el estado de cada fase.
8. Antes de seguir trabajando, revisá siempre si el PR anterior ya fue
   mergeado. Si lo fue, el trabajo nuevo arranca desde `main` actualizado
   (nunca encima de historia ya mergeada) y va en un PR nuevo.
