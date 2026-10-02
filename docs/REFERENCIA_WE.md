# Referencia de jugabilidad: Winning Eleven (PS1, WE3 a WE2002)

Resumen del análisis que pasaste, cruzado con lo que tiene MASTER ELEVEN. Sirve de guía para decidir qué sigue; se actualiza a medida que avanzamos.

Estados: **Hecho** · **Parcial** (existe, falta afinar) · **Pendiente** · **Fase N** (va con esa fase del plan de `Claude.md`).

## 1. Movimiento, pelota e inercia

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Pelota independiente del pie, con peso; con R1 se adelanta y te la anticipan | Hecho | Conducción por toques con física libre; corriendo, los toques son más largos. |
| 8 direcciones, recortes de 45/90° | Hecho | 8, 16 o libre (pausa). Cortes secos al cambiar mucho de dirección. |
| Inercia en sprint: no se gira 180° en una baldosa | Hecho | Aceleración/desaceleración y giro más abierto en sprint. |
| R2 = pisar la pelota y frenar en seco | Hecho | E / R2 conduciendo. |
| Soltar R1 a tiempo como cambio de ritmo | Parcial | La desaceleración existe; falta afinar cuántos pasos da de más. |
| Lluvia: pases rasantes más rápidos, pelotazos largos, resbalones en giros bruscos | Hecho | La pelota corre más con el pasto mojado. Un corte seco a toda velocidad puede hacer resbalar (más con poco equilibrio; también con nieve). |
| Rebotes impredecibles (la pelota pega en un jugador y entra) | Hecho | Desvíos en el cuerpo con física. |

## 2. Pases, centros y paredes

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| X: pase al pie rápido | Hecho | |
| Triángulo: pase al hueco según la velocidad del que pica | Hecho | |
| L1 + Triángulo: filtrado por elevación | Hecho | Picada por arriba de la línea, cae a espaldas de los centrales. |
| L1 + X: pared, el que pasa pica al vacío | Hecho | |
| La IA rival sigue la pelota y pierde al que pica en la pared | Hecho | Durante 2 s la marca no lo sigue. |
| Centros: 1 toque alto al segundo palo, 2 a media altura, 3 rasante al primer palo | Hecho | Esta ronda. L1 + Círculo: centro bien bombeado. |
| Playmaker: el pase al hueco de un enganche pasa justo entre los centrales | Pendiente | Habilidad especial (Fase 4: atributos). |

## 3. Remates

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Barra de potencia: poco = a las manos; mitad = misil; mucho = a la tribuna | Hecho | |
| Doble Cuadrado: rasante | Hecho | |
| L1 + Cuadrado: globo / vaselina | Hecho | |
| R2 después de cargar: colocado al palo (menos potencia, más precisión) | Hecho | Esta ronda. |
| Postura y pierna mala: perfilado sale misil, mordido se va | Hecho | Influye el ángulo entre el cuerpo y el tiro. Con la pelota del lado de la pierna mala: +40 % de error y −10 % de potencia. |
| Fuerza de tiro y precisión del jugador se notan mucho | Parcial | Afectan error y velocidad; se puede marcar más la diferencia. |
| Amague de tiro (Cuadrado → X) que deja tirado al defensor/arquero | Hecho | Los defensores cerca quedan "comprados" medio segundo (no reaccionan). |
| Comba en tiros libres y córners con la cruceta | Hecho | Con el stick derecho al patear: de costado curva; adelante cae de golpe; atrás flota. |

## 4. Arquero

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Reflejos bajo los palos; atajada decidida por la trayectoria | Hecho | Modelo de atajada al remate; reacciona, se acomoda y se tira tarde. |
| Triángulo: sale a achicar; corriendo reacciona peor (la vaselina entra) | Hecho | Esta ronda: hasta +0,2 s de reacción en plena carrera. |
| Soltar Triángulo a mitad: frena y vuelve a reaccionar bien | Hecho | Sale de la misma regla: la penalización depende de su velocidad al remate. |
| Casi no sale a los centros | Parcial | Sale sólo si cae en el área chica y llega antes. |
| Rebotes cortos al medio del área | Pendiente | Hoy rebota al costado. Decidir. |
| Debilidad en el primer palo con tiros cruzados fuertes | Pendiente | Decidir si se imita. |

## 5. Defensa y árbitro

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Cuadrado mantenido: un compañero presiona (2 contra 1) | Hecho | |
| X mantenido: presión "teledirigida" (desarma la línea) | Hecho | |
| Anticipo: pararse en la línea de pase | Hecho | Intercepción por cercanía a la trayectoria. |
| Barrida de atrás = roja directa; de frente tocando la pelota primero = limpia | Hecho | De atrás: falta casi siempre y roja directa (85 %). Segunda amarilla = roja. El expulsado sale y el equipo juega con 10. Falta: la barrida que toca primero la pelota nunca es falta. |
| Riel del receptor y super cancel | Hecho | Ronda 10. |
| Offside (con opción para sacarlo) | Hecho | Se cobra si el que estaba adelantado al pase la toca primero. No hay offside en laterales, saques de arco ni córners. Opción en el menú. |

## 6. Físico y habilidades

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Altura: los altos ganan los centros | Hecho | Esta ronda: los altos alcanzan más alto y ganan el duelo entre parejos. |
| Centro de gravedad: los bajos giran más cerrado | Hecho | Esta ronda: agilidad por físico. |
| Balance: el flaquito trastabilla en el cuerpo a cuerpo | Fase 4 | Choques con fuerza y equilibrio. |
| Velocidad que "rompe" el juego | Parcial | Atributo de velocidad ±8 %; se puede ampliar. |
| Reaction: delanteros que leen el rebote antes | Pendiente | Habilidad especial (Fase 4). |
| Animaciones propias por estrella (carrera, tiro libre) | Pendiente | Después del modelo nuevo. |

## 7. Plantel, condición y fatiga

| Mecánica del WE | Estado | En MASTER ELEVEN |
|---|---|---|
| Barra de energía; R1 la vacía; fundido llega tarde y patea mordido | Hecho | Energía de corto plazo y penalización de precisión, más cansancio acumulado: el tope de energía baja con los minutos y el sprint (en el HUD, la parte oscura de la barra). El entretiempo recupera el 30 %. |
| Cambios: 3 por partido desde el banco | Hecho | Pausa → Cambios (Sale / Entra / Confirmar). La CPU cambia a los cansados desde el minuto 55. |
| Arquero expulsado | Hecho | Entra el arquero suplente por un jugador de campo; sin cambios, va al arco un defensor con ropa de arquero y su número. |
| Flechas de condición (roja a gris) | Fase 4/6 | |
| Táctica libre en la pizarra y flechas de actitud por jugador | Pendiente | Hoy hay 5 formaciones; editor libre más adelante. |
| Master Liga | Fase 6 | |
