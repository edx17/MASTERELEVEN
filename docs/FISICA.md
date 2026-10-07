# Física del juego — Virtual Eleven

Referencia: *Informe Técnico: Física Realista en un Juego de Fútbol* (aportado
por el equipo). Este documento registra qué se adoptó, con qué valores, dónde
está implementado y cómo se valida. Filosofía: **realismo al servicio del
gameplay WE2002**; cuando ambos chocan, gana la jugabilidad.

## Resumen de decisiones

| Tema del informe | Decisión | Dónde | Validación (tests) |
|---|---|---|---|
| Pelota: masa 0,41-0,45 kg, radio 0,11 m | 0,43 kg, 0,11 m | `Tuning.ball_mass/ball_radius` | — |
| Arrastre ½·ρ·Cd·A·v² con "crisis de arrastre" (Cd ≈ 0,2-0,3 a alta velocidad) | `k(v) = ½·ρ·Cd(v)·A/m`; Cd 0,45 → 0,22 entre 9 y 15 m/s (transición suave) | `BallPhysics.drag_k` | `test_kpi_drag_crisis_makes_hard_shots_fly` (k(25 m/s) ≈ 0,0117) |
| Efecto Magnus (comba) | `a = k·(ω × v)`, ω en rad/s, k = 0,005 | `BallPhysics.step` | `test_kpi_free_kick_curls_a_few_meters` (25 m/s + 60 rad/s → 2-5 m de desvío en 25 m) |
| Coeficiente de restitución 0,7-0,8 (prueba FIFA: cae de 2 m, rebota 1,2-1,4 m) | Césped 0,6 (absorbe más); superficie dura 0,8 cumple la prueba FIFA | `Tuning.ground_restitution` | `test_kpi_fifa_bounce_on_hard_surface` |
| Fricción horizontal en el pique (~0,9) | 0,88 | `Tuning.bounce_friction` | `test_bounce_loses_energy` |
| Tiros fuertes ~100 km/h | Máximo 30 m/s (108 km/h) | `Tuning.shot_speed_max` | `test_kpi_strong_shot_speed_is_realistic` |
| Trayectoria de pelotazos | Simulación completa con arrastre | `BallPhysics.lob_*` | `test_kpi_long_ball_distance` (28 m/s a 35° → 45-65 m) |
| Pase rasante con arrastre variable | Integración RK4 hacia atrás desde la velocidad de llegada | `BallPhysics.ground_pass_speed` | `test_ground_pass_speed_arrives_at_distance` |
| Control/regate: "muelle virtual" que engancha la pelota al pie | Conducción guiada: resorte hacia un punto delante del pie con pulso de toques | `Dribble`, `Ball._dribble` | `test_dribble.gd`, `test_controlled_player.gd` |
| Jugadores: sprint 8-9 m/s | Sprint 8,4 m/s (±8 % por atributo) | `Tuning.sprint_speed`, `Footballer` | — |
| Tiempo de reacción 0,15-0,25 s | IA: 0,15-0,25 s ante cada patada según `reaction` | `SimpleAI.tick`, `Tuning.ai_reaction_*` | `test_ai_reacts_after_a_delay` |
| Estamina: sprint -20-30 puntos en 10 s, recuperación en reposo, al agotarse baja la velocidad y la precisión | Energía 0-100: -2,6/s en sprint (menos con buen atributo), +0,9/s trotando, +2,2/s parado; < 35 → hasta -15 % de velocidad; sin energía no se sprinta; hasta +2,5° de error | `Footballer.update_stamina`, `KickAccuracy.fatigue_penalty` | `test_stamina.gd` |
| Arquero: reacción 0,3-0,4 s, desplazamiento 6-7 m/s, < 75 % de atajadas en el área | Reacción 0,25-0,40 s, estirada 4,5-6,5 m/s, alcance 0,8-1,4 m según atributos; se evalúa todo el tramo final del remate (achicar sirve, la vaselina le gana al adelantado); desvíos: +0,12 s | `SaveModel` | `test_kpi_save_rate_in_the_box_is_realistic` (75 %), `test_kpi_long_shots_are_mostly_saved` (90 %) |

## Qué NO se adopta (y por qué)

| Propuesta del informe | Motivo | Cuándo |
|---|---|---|
| Motor de física general (PhysX/Bullet/RigidBody) para la pelota | Decisión A: física propia determinista, testeable y ajustable para gameplay. El informe cubre las fuerzas; se implementan igual. | — |
| Colisión pie-pelota por impulso elástico | En WE el pateo es una acción con dirección y potencia, no un choque físico; se mantiene `KickActions` (dirección + potencia + atributos + error). | — |
| Esqueletos articulados, ragdoll, cinemática inversa | Requiere modelos animados. | Fase 5 (presentación) |
| Masa de jugadores y empujones por fuerza | Hoy hay separación suave sin masa; el choque con `strength` entra con las faltas. | Fase 4 |
| Lesiones probabilísticas | Depende de faltas/choques. | Fase 4 / Liga Virtual |
| Árbitro con cono de visión (~120°, ~20 m), sesgo local y errores (10-20 % de faltas no vistas); faltas, tiros libres, penales, amarillas y rojas | Es el módulo de reglas. | Fase 4 |
| Densidad del aire por altitud/clima | Parámetro ya expuesto (`air_density`); el clima llega con estadios/ligas. | Fase 5-6 |
| Transferencia de spin en el pique, rozamiento balón-bota | Poco impacto en jugabilidad frente a su costo. | Si hace falta |

## KPIs a seguir midiendo (con simulaciones CPU vs CPU)

- Goles por partido (referencia real ~2,5-3), tiros y tiros al arco.
- % de atajadas en el área (< 75 %).
- Entradas intentadas / ganadas.
- Faltas por partido (~20-30) y tarjetas (< 5) cuando exista el árbitro (Fase 4).
- Energía media al final del partido y velocidad media de sprint.
