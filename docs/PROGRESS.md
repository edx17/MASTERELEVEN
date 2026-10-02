# Progreso — Master Eleven

Motor: **Godot 4.7.2**, GDScript. Referencia de gameplay: WE2002 (ForeverEleven).
Ver `Claude.md` para visión, criterios y fases.

| Fase | Estado |
|------|--------|
| 1 — Base jugable | ✅ Hecha |
| 2 — Prototipo 0.1: sensación de juego | ✅ Hecha (PR #2) |
| 3 — IA de partido (TeamAI, formaciones, zonas, arquero) | 🟡 Implementada, **pendiente de tu prueba** |
| Visual 1 — Se ve como la referencia (jugadores animados, cámara, cancha) | 🟡 Implementada, **pendiente de tu prueba** |
| 4 — Reglas, atributos y plantel | 🟡 Implementada, **pendiente de tu prueba** |
| 5 — Presentación moderna (estadio, modelos, animaciones, audio) | ⬜ |
| 6 — Liga Master | ⬜ |
| 7 — Torneos | ⬜ |
| 8 — Pulido | ⬜ |

---

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
| Gol (repetición y cartel con puesto, número, nombre, altura y edad del goleador) | Fase 5 (presentación) |
| Presentación de jugadores en la previa con primeros planos | Fase 5, con tu modelo final |
| Configurar controles (cambiar los botones, por mando) | Fase 8 (pulido) |
| Liga Master, con **mercado de pases** (lista con puntos y costo, y ficha con barras) | Fase 6 |
| Liga y Copa (formato, cantidad de equipos, grupos, duración, nivel) | Fase 7 |
| Editor y creación de jugadores (pelo, cara, altura, físico, edad, pie) y de equipos | Más adelante, junto al creador de estadios |
| Sonido y audio (público, relato, pelota, silbato). Referencia que pasaste: https://www.youtube.com/watch?v=GQMqctHarjo | Fase 5 |

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
