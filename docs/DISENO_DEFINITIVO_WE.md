# Diseño Definitivo WE

El jugador nuevo de Virtual Eleven, copiado del estilo de ForeverEleven /
Winning Eleven 2002: pocos polígonos, caras planas, camiseta suelta y
cuadrada, short ancho, medias hasta la rodilla, botines en bloque y puños.
Es el estilo **por defecto** (Partido > Jugadores: "Diseño Definitivo WE").

**Etapa 3 (esta):** cabeza con mandíbula, mentón, nariz y orejas; 20 caras
en pixel art (5 barbas x 4 estilos de ojos, cejas y boca); 8 peinados en
bloques (corto, rastas, afro, largo, coleta, mohicano, copete, pelado
arriba) con el color de pelo del jugador; short y mangas más sueltos;
textura de detalle (pliegues, costuras, suela, cordones).

![Blender: pose T, zancada de carrera y peinados](img/we_definitivo_blender.jpg)
![En el juego: hoja de poses](img/we_definitivo_juego.png)
![Hoja de caras: columnas = barba, filas = estilo](img/we_definitivo_caras.png)

## Archivos

| Archivo | Qué es |
|---|---|
| `tools/blender/we_definitivo.py` | Arma el modelo desde cero (script de Blender). |
| `tools/blender/we_definitivo.blend` | El modelo para editarlo a mano en Blender. |
| `tools/blender/we_preview.py` | Saca fotos del modelo (pose T y de carrera). |
| `assets/models/players/we_definitivo.glb` | Lo que carga el juego: cuerpo y peinados (exportado del .blend). |
| `assets/models/players/we_definitivo_detalle.png` | Textura de detalle en pixel art (256×256). |
| `assets/models/players/we_definitivo_caras.png` | Hoja de caras (5 × 4 caras de 128×64). |
| `scripts/player/we_body.gd` | Lo pone sobre el esqueleto del juego y le pasa las zonas al shader. |

`tools/blender/` tiene `.gdignore`: Godot no importa el `.blend`.

## Cómo está hecho

- **Esqueleto:** el mismo del juego (`player_body.gltf`, 1,81 m, pose T), con
  los mismos nombres de huesos (`pelvis`, `spine_01..03`, `neck_01`, `Head`,
  `clavicle/upperarm/lowerarm/hand_l/_r`, `thigh/calf/foot/ball_l/_r`). Por eso
  el modelo usa todas las animaciones del juego, y las animaciones propias que
  se hagan en Blender sobre este Armature van a servir para todos.
- **Malla:** unos 860 triángulos (más el peinado). Tubos de 4 a 8 caras por
  anillo. Caras planas (Shade Flat) en toda la malla.
- **UV y textura de detalle:** cada tubo está desenrollado en un rectángulo
  derecho (la ropa sigue `docs/KIT_UV.md`). La textura (256×256, sin
  suavizar: "Closest") NO trae los colores: va encima de los del club.
  Canal R = sombreado (128 = neutro, más oscuro = pliegue o costura); G =
  cuánto se pinta encima; B = el gris de esa pintura (ojos, cejas, suela,
  cordones). Así la misma textura sirve para todos los equipos. Sin marcas
  ni logos (regla del proyecto).
- **Caras:** la hoja de caras reemplaza la región de la cabeza de la textura
  de detalle. Columna = barba del jugador (0 nada, 1 de tres días, 2 bigote,
  3 candado, 4 barba); fila = estilo de ojos, cejas y boca, que sale de la
  semilla del jugador (siempre el mismo). Canal A = pelo: cejas y barba van
  con el color de barba/pelo del jugador.
- **Peinados:** objetos aparte pegados al hueso `Head`: `WE_Pelo_corto`,
  `_rastas` (rastas y trenzas), `_afro` (afro y rulos), `_largo`, `_coleta`,
  `_mohicano`, `_copete` y `_herradura` (pelado arriba). Pelado: sin pieza.
  Degradé, casco, flequillo y raya al costado usan el corto.
- **Pesos rígidos:** cada anillo va a un hueso. En codos, rodillas, cintura,
  cuello, tobillos y hombros, el anillo de la articulación va mitad y mitad, para
  que no se abra al doblar.
- **Zonas = materiales.** El color de cada material es sólo para verlo en
  Blender: en el juego cada zona se pinta con los colores del club, el diseño
  de la camiseta (rayas, bastones, banda...), el número y el escudo.

| Material | Zona en el juego |
|---|---|
| `camiseta` | Torso: lleva el diseño, el número de la espalda y el escudo. |
| `manga` | Mangas (color de la camiseta, sin número). |
| `ribete_camiseta` | Cuello, puños y ruedo: color secundario. |
| `short` | Short (con el número en el muslo izquierdo). |
| `ribete_short` | Ruedo del short. |
| `medias` | Medias (con la franja de arriba). |
| `piel` | Piel (cara, cuello, brazos, rodillas). |
| `botines` | Botines. |
| `pelo` | Pelo (los peinados), con el color de pelo del jugador. |
| `manos` | Manos (guantes en los arqueros). |

## Editar el modelo a mano

1. Abrí `tools/blender/we_definitivo.blend` (Blender 4.2 o más nuevo).
2. Editá en modo edición **sin mover el Armature ni salir de la pose T**.
   Respetá la altura (1,81 m), porque el número y el escudo se ubican por
   posición: la espalda va de y 1,12 a 1,42 m y el pecho, a la altura de 1,33 m.
3. Las caras nuevas tienen que tener un material de la tabla y pesos en
   los grupos de vértices (los nombres de los huesos).
4. Exportá: File > Export > glTF 2.0, formato **glTF Binary (.glb)**, a
   `assets/models/players/we_definitivo.glb`. Opciones: Include sin
   "Selected Objects" ni "Visible Objects" (van el Armature, el cuerpo y los
   peinados), Data > Armature/Skinning activado, Material > Images: None,
   Animation desactivado.

Para volver a generarlo desde cero (pisa el .blend y el .glb):
`blender --background --python tools/blender/we_definitivo.py`.

Para retocar la textura a mano: abrí `we_definitivo_detalle.png` en
Aseprite o similar y pintá sólo en gris sobre el canal rojo (sombras), o
en verde+azul (pintura). Si volvés a correr el script, la pisa.

## Próximos pasos

1. **Animaciones propias** (reemplazan a las de Mixamo y a la librería
   actual), hechas en Blender sobre este Armature. Primero correr (rodilla
   adelante a 90°, codos a 90°, como el WE2002), trotar, caminar y parado;
   después pase, remate, cabezazo, barrida y arquero.
