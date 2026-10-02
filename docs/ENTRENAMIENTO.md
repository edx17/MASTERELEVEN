# Entrenamiento (Club House)

Modo de práctica inspirado en la cancha de entrenamiento del WE: sin tribunas ni
público, con árboles, el edificio del club de fondo y percusión en lugar de la
hinchada. Usa el mismo partido (`MatchController`, IA, física, controles), así
que todo lo que se practica se juega igual que en un partido.

## Componentes

| Pieza | Archivo | Qué hace |
|---|---|---|
| Cancha | `scripts/stadium/club_house_builder.gd` | Pasto alrededor, alambrado bajo transparente, árboles (MultiMesh), edificio "CLUB HOUSE" con galería, bancos y 4 mástiles de luz. Liviano: sin público, butacas ni carteles. |
| Sesión | `scripts/training/training_session.gd` (`TrainingSession`) | Estado de la práctica, armado de cada jugada, reglas propias, desafíos, récords y su HUD. |
| Partido | `scripts/match/match_controller.gd` | Si `GameSettings.training`: arma el Club House, no hay presentación, árbitro, reloj, tarjetas, offside, festejo ni repetición; delega en la sesión. |
| Pausa | `scripts/ui/pause_menu.gd` | Menú de práctica (reemplaza al del partido). |
| Menú | `scripts/ui/main_menu.gd` | ENTRENAMIENTO → qué practicar → tu equipo y el rival → al Club House. |
| Sonido | `scripts/audio/match_audio.gd` | Loop de redoblante y bombo (100 pulsos/min) generado por código; sin gritos de público. |

## Estado (TrainingSession)

- `kind`: `FREE`, `FREE_KICK`, `CORNER`, `PENALTY`, `SLALOM`, `PASSING`, `RONDO`, `TARGETS`.
- Configuración: `attackers` y `defenders` (de campo, 1–10 y 0–10), `rival_keeper`,
  `wall`, `fk_distance` (16–36 m), `fk_angle` (−50° a 50°), `corner_side`, `taker_index`.
- Métricas: `attempts`, `goals`, `score`, `timer`, `running`, `finished`.
- Récords: `best` (por práctica), en `user://training.json`.

## Ciclo de vida

1. `setup(match)`: lee la práctica elegida, carga los récords y arma el HUD.
2. `start(kind)`: elige quiénes juegan (`_squad`: los de ataque primero en tu
   equipo, los de defensa en el rival; los demás quedan ocultos fuera de la
   cancha), arma los elementos (`_build_props`: banderas, conos, círculo, aros)
   y llama a `reset_play()`.
3. `reset_play()`: vuelve a armar la jugada desde el origen. Lo usan SELECT, el
   menú y el fin de cada intento.
4. Durante el juego:
   - `after_ai(dt)`: después de la IA. Los de las estaciones se quedan en su lugar y las marcas del rondo presionan.
   - `tick(dt)`: después de las reglas. Atiende SELECT, la espera para rearmar, las pelotas paradas (atajada, despeje, 7 s) y cada desafío.
5. Fin de la jugada:
   - `on_outcome(outcome)`: gol o pelota afuera. Cuenta el intento y lo rearma a los 1,6 s.
   - `on_stopped()`: falta.
6. `_finish(...)`: cierra un desafío, guarda el récord y lo vuelve a empezar.

## Prácticas

| Práctica | Jugadores | Cómo se juega |
|---|---|---|
| Práctica libre | Los que elijas (+ arquero rival) | El delantero arranca con la pelota a 32 m del arco; compañeros abiertos y la defensa entre la pelota y el arco. |
| Tiros libres | Pateador + atacantes vs barrera y arquero | Distancia, ángulo, barrera sí/no y pateador desde la pausa. Cámara atrás del pateador. |
| Córners | Atacantes vs marcas y arquero | Del lado que elijas. |
| Penales | Pateador vs arquero | |
| Slalom | Uno solo | 7 pares de banderas en zigzag; tiempo desde la línea blanca hasta la amarilla; banderas salteadas, +2 s. |
| Precisión de pase | 5 compañeros en estaciones | Pasala al marcado con el aro amarillo; 60 s desde el primer pase. |
| Rondo | 5 compañeros vs 2 marcas | Pases seguidos sin que te la saquen ni se vaya del círculo de 9 m. |
| Puntería | Pateador vs barrera y arquero | 10 tiros libres desde distintos lugares; aro en los ángulos 3 puntos, resto del arco 1. |

## Menú de práctica (START)

Práctica · Atacantes · Defensores · Arquero rival · Distancia y ángulo del tiro
libre · Barrera · Lado del córner · Pateador · Reiniciar la jugada · Dirección
del equipo (formación y estrategias) · Cambiar de cámara · Salir.

SELECT reinicia la jugada en cualquier momento (en el entrenamiento, la cámara
se cambia desde el menú).
