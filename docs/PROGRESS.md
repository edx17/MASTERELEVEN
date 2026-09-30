# Progreso — Master Eleven

Motor: **Godot 4.7.2** (última estable al arrancar la Fase 1), GDScript.

| Fase | Estado |
|------|--------|
| 1 — Partido jugable básico | 🟡 Implementada, pendiente de tu prueba de "sensación" con mando y teclado |
| 2 — IA de partido | ⬜ No iniciada |
| 3 — Atributos y jugadores | ⬜ No iniciada |
| 4 — Liga Master | ⬜ No iniciada |
| 5 — Torneos | ⬜ No iniciada |
| 6 — Gráficos y presentación | ⬜ No iniciada |
| 7 — Pulido | ⬜ No iniciada |

---

## Fase 1 — Partido jugable básico

### Hecho
- [x] Proyecto Godot 4 + estructura de carpetas + Input Map completo (teclado y mando, nada hardcodeado).
- [x] Acciones por jugador (`p0_*`, `p1_*`) derivadas del Input Map, con reasignación automática al conectar/desconectar mandos.
- [x] Parámetros de sensación en `data/tuning/default_tuning.tres` (editable desde el Inspector).
- [x] Cancha reglamentaria 105 x 68 con líneas, áreas, medialunas, círculo central, córners, banderines.
- [x] Arcos con postes, travesaño y red (colisión propia: la red frena la pelota).
- [x] Pelota con física propia: gravedad, arrastre, piques, rozamiento, efecto (Magnus), sombra para leer la altura.
- [x] 11 vs 11 con cápsulas de color + número, formación 4-4-2.
- [x] Control humano: movimiento, sprint, conducción pegada al pie, pase corto, largo/centro, al hueco, tiro con barra de potencia, toque de primera, presión, barrida.
- [x] Cambio de jugador automático (receptor del pase / más cercano) + manual.
- [x] Robo por contacto y por barrida.
- [x] Reglas: gol, saque de arco, córner, lateral, saque del medio, entretiempo con cambio de lado, final.
- [x] Cámara lateral de TV con suavizado y anticipación.
- [x] HUD: marcador, reloj acelerado (3/5/7/10 min), barra de potencia, jugador controlado, carteles.
- [x] IA provisoria (bloque que se desplaza, presión, cobertura, conducción, pase, tiro, arquero).
- [x] Menú principal (vs CPU, 2 jugadores, CPU vs CPU) y pausa.
- [x] Tests unitarios (GUT): física de pelota, reglas, reloj, elección de receptor, formación, humo de partido completo.

### Pendiente / a validar
- [ ] **Criterio de aceptación:** jugar un partido completo con mando y con teclado y confirmar que se siente fluido y divertido (lo tenés que validar vos).
- [ ] Ajuste fino de valores de `default_tuning.tres` según tu feedback.

### Limitaciones conocidas (se resuelven en fases siguientes)
- El arquero siempre lo maneja la IA (el humano no lo controla ni cuando tiene la pelota).
- Sin faltas, tarjetas, offside ni penales (Fase 2).
- Una sola formación (4-4-2) y sin atributos individuales (Fases 2 y 3).
