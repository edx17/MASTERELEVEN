# Futsal 5 contra 5

Segunda disciplina de Virtual Eleven: **futsal** con las reglas FIFA y los
clubes de la AFA. Comparte el motor del fútbol (jugadores, pelota, IA,
menús); cambian la cancha, el reglamento, la base y las competencias.

## Fases

| Fase | Qué trae | Estado |
|---|---|---|
| F0 | Disciplina (fútbol / futsal), base AFA Futsal, formaciones de 5 | ✅ |
| F1 | Cancha 40 x 20 (parquet, pista azul o negra), arcos 3 x 2, pelota de bote bajo, gimnasio techado, cámaras a escala | ✅ |
| F2 | Reglas propias: lateral con el pie, saque de arco con la mano, 4 segundos, pase atrás al arquero, faltas acumuladas y doble penal, reloj parado (2 x 20, 5 min reales por tiempo) | ✅ |
| F3 | IA de futsal (1-2-1, 2-2, 1-3, 3-1, 4-0) y cambios volantes (L2 rápido; cuartetos y rotación por tiempo en Dirección de Equipo) | ✅ |
| F4 | Arquero jugador: orden por ataque; entra un jugador con camiseta de arquero para el 5 contra 4 y, al perder la pelota, corre al banco y vuelve el arquero | ✅ |
| F5 | Amistosos, torneos amistosos y Liga con playoffs, ascensos/descensos y Supercopa | |
| F6 | Liga Virtual de futsal (carrera) y estadios tipo España y Brasil | |

## Cómo se elige

Después del título: **¿Qué jugás? Fútbol / Futsal**. Fútbol pregunta la base
(Ficticia o Temporada 2026); futsal tiene una sola (AFA Futsal) y va directo
al menú. El menú de futsal muestra Partido amistoso, Copa, Liga, Editar y
Opciones (la Liga Virtual de futsal llega en F6; el Mundial, el Sub-20 y el
entrenamiento son de fútbol). Las partidas quedan atadas a su base, como
siempre.

En la configuración del partido, en lugar de Horario, Clima, Viento, Césped,
Estado, Offside y Estadio, aparece **Piso** (parquet, pista azul o pista
negra). El partido se juega de tarde, sin viento ni lluvia, en el
microestadio del local.

## Cancha y pelota (F1)

- 40 x 20 m; área de 6 m (cuartos de círculo desde los postes y recta entre
  ellos); penal a 6 m y doble penal a 10 m; círculo central de 3 m; zonas de
  cambio a 5 y 10 m de la línea media del lado de los bancos; arcos de 3 x 2.
- Todo sale de `Pitch.configure()` (las medidas ahora son `static var`); el
  resto del juego (IA, cámaras, marcas, estadios) lee esas medidas.
- Pelota de bote bajo: menos rebote, menos fricción en el pique y frena
  parejo (`Discipline.apply_to`). Sin offside.
- Gimnasio (`GymBuilder`): paredes de ladrillo con zócalo del color del club,
  tribuna de cemento enfrente con público, carteles bajos con el nombre del
  local, bancos y mesa de control del lado de la cámara, techo de chapa con
  cerchas y paneles de luz. Las cámaras altas (Amplia, dron) no dibujan el
  techo.
- Cámaras: los presets del fútbol se achican en proporción a la cancha (no
  del todo: si no, los jugadores se ven enormes).

## Reglamento (F2)

Todo sale de `Discipline.DATA["futsal"]["rules"]` (`Discipline.rule()`); el
fútbol sigue igual.

- **Reloj:** 2 tiempos de 20' que corren sólo con la pelota en juego (reloj
  parado). Con la duración por defecto (10 min reales), 5 min reales de
  pelota en juego por tiempo. El segundo tiempo arranca en 20:00. La CPU
  decide cambios, "hacer tiempo" y estrategia por el minuto equivalente de
  un partido de 90.
- **Lateral con el pie:** desde la línea, con una patada común (no con las
  manos).
- **Saque de arco con la mano:** el arquero, en su área cerca del arco, con
  la pelota en las manos: pase corto rodando, largo por arriba de la cabeza.
  No toma carrera ni puede patear de volea.
- **4 segundos** para sacar (lateral, córner, tiro libre, saque de arco),
  con la cuenta en el HUD. Si no saca: lateral para el rival; córner ->
  saque de arco del rival; tiro libre o saque de arco -> indirecto para el
  rival (en el área, desde su línea). La CPU siempre saca a tiempo.
- **Arquero, 4 segundos** con la pelota controlada en su campo (manos o
  pies): indirecto para el rival.
- **Pase atrás:** el arquero que la jugó en su campo no la puede volver a
  tocar ahí después de un compañero, salvo que antes la toque un rival o la
  pelota pase la mitad: indirecto para el rival. La CPU no se la devuelve.
- **Faltas acumuladas** por tiempo (en el HUD: "FALTAS 2-5"). Aviso en la
  5.ª; desde la 6.ª, tiro libre directo **sin barrera** desde el doble penal
  (10 m), o desde donde fue si es más cerca del arco; los rivales detrás de
  la pelota y a 5 m. La CPU remata al arco.
- **Área redondeada** (cuartos de círculo de 6 m): penales e indirectos se
  miden con su forma real.
- Atajada un poco más difícil que en el fútbol (arco de 3 m); el ajuste fino
  de remates y arqueros va con la IA de futsal (F3).

## IA y cambios volantes (F3)

- **IA a escala:** las distancias de la IA, los pases, los remates, los
  despejes, las pelotas paradas y el arquero se achican con la cancha
  (`Pitch.s` para la geometría, `Pitch.h` para las distancias de juego,
  `Pitch.g` para la puntería al arco de 3 m). Antes la CPU remataba desde su
  campo, apuntaba afuera del arco y despejaba de fondo a fondo.
- **Cambios volantes** sin límite y sin parar el juego: el que sale va hasta
  la zona de cambio de su equipo (banda de los bancos, en su campo) y recién
  ahí entra el suplente. El que sale vuelve al banco, recupera energía y
  puede volver a entrar.
  - **L2 + cruceta arriba:** cambio rápido (sale el más cansado, entra el
    suplente de campo con más energía, del mismo puesto si hay).
  - **Cuartetos:** el segundo cuarteto son los primeros 4 de campo del banco
    (el orden se arma en la Dirección del equipo). **Rotación** cada 3', 5'
    o 7' de juego, o a mano (por defecto, cada 5').
  - La CPU rota el cuarteto y además cambia a los que se cansan.
- En una simulación CPU contra CPU: 3-2 y 5-8, con unos 28 cambios por equipo.

## Arquero jugador (F4)

- **Orden** (L2 + cruceta abajo, se prende y se apaga): en cada ataque, con
  la pelota en campo rival, el arquero sale por la zona de cambio y entra un
  jugador de campo **con la camiseta de arquero** (sin manos) que juega
  arriba: 5 contra 4.
- **Al perder la pelota** el arquero jugador corre al banco y vuelve el
  arquero, que va a su arco. Si pierde la pelota antes de salir, el arquero
  se queda.
- **Pelota parada:** si saca el rival (o es saque de arco o del medio),
  vuelve el arquero de una; si saca el equipo con el arquero jugador
  (lateral, córner, tiro libre), sigue el 5 contra 4.
- **Arco vacío:** el rival remata al arco desde lejos si tiene el camino
  libre.
- **CPU:** lo usa si va perdiendo por 1 o 2 en los últimos minutos.
- Entra el suplente de campo con más energía y mejor pase.

## Árbitros

- **Dos árbitros, uno por cada banda,** en diagonal: siempre afuera de la
  línea, cinco metros hacia un arco y hacia el otro respecto de la pelota.
  Según el ataque, uno queda cerca del inicio de la jugada y el otro cerca
  del arco atacado. Se desplazan de costado, mirando la jugada.
- **Cuarto árbitro:** camina entre los bancos (y muestra el cartel en los
  cambios).
- **Señas** (en cola, el saque espera a que termine la seña):
  - falta: el más cercano entra unos metros a la cancha, señala con el brazo
    para quién es y avisa a la mesa (falta acumulada);
  - tarjeta: va hasta el infractor, la muestra y después avisa a la mesa;
  - barrera: camina desde la pelota contando los 5 m y marca el límite con
    el brazo estirado a la altura de la barrera;
  - lateral: el de esa banda señala para quién es;
  - 4 segundos: en cada pelota parada (y con el arquero con la pelota) el
    brazo se estira y se repliega una vez por segundo.
- La barrera y los rivales van a **5 m** (antes quedaban a 3).

## Base AFA Futsal (F0)

`godot --headless -- --build-futsal-db` arma `data/futsal_afa/` desde
`tools/db_src/futsal_afa/equipos.csv` (liga, zona, posición, equipo, overall,
mínimo y máximo del plantel, perfil):

- Primera A (18), B (18), C y D en Zona 1 y Zona 2: 92 clubes.
- Cada club con id único y las camisetas de su club de fútbol si está en la
  base (Boca, River, Racing, Vélez...); si no, colores propios.
- Planteles de 14 (2 arqueros) con pid único: los titulares cerca del overall
  del club y el resto entre el mínimo y el máximo del CSV.
- Competencias: las cinco ligas y la Supercopa (`fut_super`).

## Formato de las competencias (F5)

- **Primera A:** sin campeón del torneo regular; del 1.º al 8.º juegan el
  playoff (1.º-8.º, 2.º-7.º...), ida y vuelta. Descienden los 2 últimos.
- **Primera B:** el 1.º es campeón y asciende; del 2.º al 9.º, playoff ida y
  vuelta, y el ganador también asciende. Descienden los 2 últimos.
- **Primera C:** igual que la B; descienden los 3 últimos.
- **Primera D (Zona 1 y Zona 2):** asciende el campeón de cada zona; del 2.º
  al 5.º de cada zona, playoff cruzado (2.º Z1 - 5.º Z2, 3.º Z1 - 4.º Z2...),
  ida y vuelta; el ganador es el tercer ascenso.
- **Llaves:** empate en el global, pasa el mejor ubicado; desde semifinales,
  penales. La revancha, en cancha del mejor ubicado.
- **Supercopa** (a principio del año siguiente): los dos campeones de la D se
  cruzan antes y el ganador es el cuarto equipo; semifinales A - D y B - C.
