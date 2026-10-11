# Futsal 5 contra 5

Segunda disciplina de Virtual Eleven: **futsal** con las reglas FIFA y los
clubes de la AFA. Comparte el motor del fútbol (jugadores, pelota, IA,
menús); cambian la cancha, el reglamento, la base y las competencias.

## Fases

| Fase | Qué trae | Estado |
|---|---|---|
| F0 | Disciplina (fútbol / futsal), base AFA Futsal, formaciones de 5 | ✅ |
| F1 | Cancha 40 x 20 (parquet, pista azul o negra), arcos 3 x 2, pelota de bote bajo, gimnasio techado, cámaras a escala | ✅ |
| F2 | Reglas propias: lateral con el pie, saque de arco con la mano, 4 segundos, pase atrás al arquero, faltas acumuladas y doble penal, reloj parado (2 x 20, 5 min reales por tiempo) | Próximo PR |
| F3 | IA de futsal (1-2-1, 2-2, 1-3, 3-1, 4-0) y cambios volantes (L2 rápido; cuartetos y rotación por tiempo en Dirección de Equipo) | |
| F4 | Arquero jugador: orden por ataque; entra un jugador con camiseta de arquero para el 5 contra 4 y, al perder la pelota, corre al banco y vuelve el arquero | |
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
