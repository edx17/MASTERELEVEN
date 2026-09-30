# Progreso — Master Eleven

Motor: **Godot 4.7.2**, GDScript. Referencia de gameplay: WE2002 (ForeverEleven).
Ver `Claude.md` para visión, criterios y fases.

| Fase | Estado |
|------|--------|
| 1 — Base jugable | ✅ Hecha |
| 2 — Prototipo 0.1: sensación de juego | 🟡 En pulido tras tu primera prueba; **pendiente de tu segunda prueba** |
| 3 — IA de partido (TeamAI, formaciones, zonas, arquero) | ⬜ |
| 4 — Reglas, atributos y plantel | ⬜ |
| 5 — Presentación moderna (estadio, modelos, animaciones, audio) | ⬜ |
| 6 — Liga Master | ⬜ |
| 7 — Torneos | ⬜ |
| 8 — Pulido | ⬜ |

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
