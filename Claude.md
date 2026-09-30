# PROYECTO "MASTER ELEVEN": Fútbol estilo Winning Eleven 4 — Liga Master

## Visión
Juego de fútbol 3D para PC, inspirado en la jugabilidad de Winning Eleven 4 (PS1),
rehecho con tecnología y gráficos actuales. El foco es el modo Liga Master:
carrera de club con ascensos, descensos, transferencias, torneos internacionales
y Mundial de selecciones. Debe sentirse arcade-simulación como WE: pases rápidos,
ritmo fluido, control preciso.

## Restricciones
- SIN LICENCIAS: todos los clubes, jugadores, ligas, torneos y selecciones son
  ficticios (nombres inventados, escudos y camisetas originales). Nada de marcas
  reales.
- Portable para PC (Windows prioritario; Linux/Mac deseable).
- Jugable 100% con teclado o con mando (DualShock/DualSense/Xbox), con
  detección automática y remapeo desde opciones.
- Solo assets libres (CC0 o de producción propia). Animaciones: Mixamo o
  similares con licencia compatible. Documentar el origen de cada asset en
  /assets/CREDITS.md.

## Stack
- Motor: Godot 4 (última versión estable), GDScript.
- Datos de Liga Master: recursos de Godot (.tres) o JSON para la base inicial;
  partidas guardadas en JSON en user://.
- Control de versiones: Git + GitHub. Commits chicos y descriptivos por hito.

## Controles (estilo WE PS1)
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
La potencia de tiro y pase se gradúa manteniendo el botón (barra de potencia).
Todo definido en el Input Map de Godot, nunca hardcodeado.

## Estructura sugerida
/scenes      (match, menus, league)
/scripts     (match/, ai/, league/, data/, ui/, core/)
/assets      (models, animations, textures, audio, fonts)
/data        (clubs, players, leagues, tournaments en JSON)
/tests

## FASES (no avanzar a la siguiente sin cumplir los criterios de aceptación)

### Fase 1 — Partido jugable básico
- Cancha reglamentaria con líneas, arcos con red y límites.
- Pelota con física creíble: rebote, rozamiento, efecto básico, altura en
  pases largos y centros.
- 11 vs 11 con placeholders (cápsulas de colores + número).
- Control del jugador humano: movimiento, sprint, pase corto, pase largo,
  pase al hueco, tiro con barra de potencia, cambio de jugador (automático al
  más cercano a la pelota + manual).
- Posesión: conducción con la pelota pegada al pie, robo por contacto.
- Cámara lateral de TV estilo WE, siguiendo la pelota con suavizado.
- Reglas mínimas: gol, saque de arco, córner, lateral, saque del medio.
- HUD: marcador, reloj (partido acelerado configurable, ej. 5-10 min reales),
  indicador del jugador controlado.
- IA provisoria simple para que los demás jugadores no queden quietos.
Criterio de aceptación: se puede jugar un partido completo con mando y con
teclado, y manejar la pelota se siente fluido y divertido.

### Fase 2 — IA de partido
- Formaciones (4-4-2, 4-3-3, 3-5-2, 4-2-3-1, 3-4-3) con posiciones base que
  se desplazan según la pelota.
- IA ofensiva: desmarques, apoyos, tomar decisión de pase/tiro/conducción.
- IA defensiva: presión al portador, coberturas, marca, línea defensiva y
  offside.
- Arquero: posicionamiento, atajadas, salidas, reposición.
- Faltas, tarjetas, tiros libres y penales.
- Estrategias rápidas en partido (presión alta, contraataque, offside trap).
- Niveles de dificultad.
Criterio: un partido vs CPU es competitivo y la CPU juega "como un equipo".

### Fase 3 — Atributos y jugadores
- Atributos por jugador (velocidad, aceleración, pase corto, pase largo, tiro,
  potencia, técnica, defensa, físico, resistencia, arquero, etc.) que afecten
  de verdad la jugabilidad.
- Posiciones y pierna hábil.
- Fatiga durante el partido y sustituciones.
- Menú pre-partido: formación, titulares, suplentes, ejes de estrategia.

### Fase 4 — Liga Master
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

### Fase 5 — Torneos
- Copa nacional (eliminación directa).
- Copa continental de clubes (grupos + eliminatorias) para los mejor ubicados.
- Mundial de selecciones cada 4 temporadas (clasificación, grupos,
  eliminatorias), con convocatoria de jugadores de la Liga Master.
- Historial: campeones, palmarés del club, récords.

### Fase 6 — Gráficos y presentación
- Reemplazar placeholders por modelos 3D animados (correr, pasar, tirar,
  barrer, cabecear, celebrar, arquero).
- Estadios con tribunas, iluminación día/noche, pasto con buen shader.
- Camisetas editables por club.
- Menús con estética moderna, transiciones, música.
- Sonido: pelota, público reactivo, silbato.
- Repeticiones de goles.

### Fase 7 — Pulido
- Editor de clubes y jugadores (nombres, atributos, camisetas).
- Opciones: gráficos, audio, controles, duración de partido.
- Build exportable para Windows con instalador o zip portable.

## Reglas de trabajo
1. Antes de programar cada fase, presentá un plan breve con las tareas y
   esperá mi OK.
2. Trabajá de a una fase. Al terminar, contame qué se hizo, cómo probarlo y qué
   quedó pendiente.
3. Cada vez que modifiques o corrijas código que ya estaba entregado, avisalo
   de forma explícita: qué archivo, qué cambió y por qué. Nunca cambios
   silenciosos.
4. Priorizá que se sienta bien jugar por encima de agregar features.
5. Código modular y comentado; la lógica de Liga Master desacoplada del motor
   de partido para poder testearla sola.
6. Si una decisión técnica es grande (arquitectura, librerías, formato de
   datos), consultame antes.
7. Mantené actualizado un /docs/PROGRESS.md con el estado de cada fase.
