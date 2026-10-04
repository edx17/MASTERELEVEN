# Créditos de assets

Todo asset que entre al proyecto se registra acá con su origen y licencia.
Sólo se aceptan assets CC0 o de producción propia (animaciones: Mixamo o
similares con licencia compatible).

| Asset | Ubicación | Origen | Licencia |
|-------|-----------|--------|----------|
| Cancha, arcos, red, banderines | generados por código (`scripts/stadium/pitch_builder.gd`) | Producción propia | Propia |
| Césped (shader procedural) | `scripts/stadium/grass.gdshader` | Producción propia | Propia |
| Estadio: tribunas, butacas, techo, muro, carteles lisos, bancos, túnel | generados por código (`scripts/stadium/stadium_builder.gd`) | Producción propia | Propia |
| Tipografía de butacas 5x7 | `scripts/stadium/stadium_builder.gd` (PixelFont) | Producción propia | Propia |
| Jugadores: cuerpo con esqueleto ("Superhero Male" de Universal Base Characters; sin sus texturas, colores por club con shader propio) | `assets/models/players/player_body.gltf` + `.bin` | Quaternius — https://quaternius.com | CC0 |
| Animaciones de locomoción (Universal Animation Library, versión Godot) | `assets/animations/ual1_standard.glb` | Quaternius — https://quaternius.com | CC0 |
| Gestos de fútbol (patada, pase, cabezazo, saque, estirada, barrida) sobre el esqueleto | `scripts/player/model_visual.gd` | Producción propia | Propia |
| Animaciones de fútbol (remate, pase, cabezazo, entrada, barrida, recepción, caída, festejo, conducción, arquero) | `assets/animations/mixamo/*.fbx` — **no están en el repo** (ver abajo) | Mixamo (Adobe) | Licencia de Mixamo: uso en el juego permitido, redistribución de los archivos no |
| Humanoide provisorio (si faltan los modelos) | `scripts/player/player_visual.gd` | Producción propia | Propia |
| Textura de la pelota | generada por código (`scripts/ball/ball.gd`) | Producción propia | Propia |
| HUD (radar, paneles, "banderas" de club) | dibujado por código (`scripts/ui/match_hud.gd`) | Producción propia | Propia |
| Ícono del proyecto | `icon.svg` | Producción propia | Propia |

## Herramientas de terceros (no son assets del juego)

| Herramienta | Ubicación | Origen | Licencia |
|-------------|-----------|--------|----------|
| GUT 9.7.1 (tests unitarios) | `addons/gut/` | https://github.com/bitwes/Gut | MIT (`addons/gut/LICENSE.md`) |
| Skills de desarrollo de juegos para Claude Code (25) | `.claude/skills/` | https://github.com/gamedev-skills/awesome-gamedev-agent-skills | Apache 2.0 (`.claude/skills/LICENSE-awesome-gamedev-agent-skills`, `NOTICE-...`) |

## Animaciones de Mixamo

Desde B10 van en el repo (ya no están en el `.gitignore`), así los tests, las
capturas y el .exe de prueba usan lo mismo que se ve en el editor. La licencia
de Mixamo permite usarlas en el juego pero no redistribuir los archivos
sueltos: **conviene que el repositorio sea privado** (GitHub → Settings →
Danger Zone → Change visibility). Van en `assets/animations/` (o en la
subcarpeta `mixamo/`), FBX "Without Skin" o "With Skin". Hoy están 53 de los 58
clips; faltan `Kick Soccerball`, `Soccer Tackle 1`, `Receive Soccerball` y
`Goalkeeper Body Block` (esos gestos se hacen por código). Lista completa:
`Kick Soccerball`, `Soccer Penalty Kick`, `Soccer Pass`, `Soccer Header`,
`Soccer Tackle`, `Soccer Tackle 1`, `Receive Soccerball`, `Soccer Trip`,
`Standing Up`, `Cartwheel`, `Dribble`, `Goalkeeper Idle`, `Goalkeeper Catch`,
`Goalkeeper Catch 1`, `Goalkeeper Catch 2`, `Goalkeeper Body Block`,
`Goalkeeper Miss`, `Goalkeeper Sidestep`, `Goalkeeper Placing Ball`,
`Goalkeeper Overhand Throw`, `Goalkeeper Pass`, `Goalkeeper Diving Save`
(con espacios o guiones bajos; las variantes numeradas pueden llamarse `Goalkeeper Catch 1` o `Goalkeeper Catch (1)`, como las numera Windows). Si falta alguna, ese gesto se hace por código.

## Texturas del césped (opcionales, CC0)

El césped se ve bien con el detalle procedural, pero con una textura
fotográfica gana realismo. Desde el entorno de desarrollo no se pueden
descargar, así que se ponen a mano (son CC0: se pueden subir al repo):

1. Bajar de ambientCG (https://ambientcg.com) el material **Grass004**, versión
   **1K-JPG** (o 2K-JPG).
2. Copiar a `assets/textures/grass/` y renombrar:
   - `Grass004_1K-JPG_Color.jpg` → `grass_albedo.jpg`
   - `Grass004_1K-JPG_NormalGL.jpg` → `grass_normal.jpg` (la versión **GL**, no DX)
   - `Grass004_1K-JPG_Roughness.jpg` → `grass_roughness.jpg`
3. Abrir el editor una vez para que las importe. Si están, `GrassTextures` las
   usa automáticamente; si no, sigue el detalle procedural.

Sirve cualquier césped corto CC0 con esos tres mapas (por ejemplo Grass001 o
Grass005 de ambientCG). Las franjas de corte y el desgaste los sigue poniendo
el shader.

## Texturas y cielos procesados (B11)

| Asset | Ubicación | Origen | Licencia |
|-------|-----------|--------|----------|
| Cielos: despejado, amanecer_invierno, atardecer, nublado, nublado2, nieve | `assets/skies/*.jpg` (versión JPG 2K) | ambientCG: HdrOutdoorFieldBaseballDayClear001, HdrOutdoorSoccerFieldWinterDayClear001, HdrSkySunset007, HdrSkyOvercast001, HdrOutdoorFieldDayOvercast004, HdrOutdoorSnowMountainsEveningClear001 | CC0 |
| Césped gastado (color 2K, normal y rugosidad 1K) | `assets/textures/grass_worn/` | Poliigon GrassPatchyGround 4585 | Licencia Poliigon (uso en proyectos; no redistribuir suelto) |
| Tierra / campo (1K) | `assets/textures/ground/` | Poliigon GroundFieldAgriculture 12105 | Licencia Poliigon |
| Trama de tela (normal 512) | `assets/textures/fabric/` | ambientCG FabricPlainNaturalSheer009 | CC0 |

## Sonidos grabados (B11, paso 4)

Aportados por el autor del proyecto (subidos a `assets/_entrada/`), recortados
a la parte útil y convertidos a OGG 44,1 kHz en `assets/audio/`. El origen y la
licencia de cada grabación los informa el autor; si alguno no se puede
redistribuir, se borra el .ogg y el juego vuelve al sonido generado por código.

| Archivo | Original | Uso |
|---|---|---|
| `post.ogg` | crossbar.mp3 | Pelota en el palo / travesaño |
| `ooh.ogg` | miss from freekick.wav (4-11 s) | "Uhh" de un remate que se va cerca |
| `cheer.ogg` | sonido de gol.wav (3,5-15,5 s) | Grito de gol |
| `goal_chant.ogg` | hinchada gol.wav (3-33 s) | La hinchada canta después del gol |
| `whistles.ogg` | hinchada en contra del arbitro.wav (4,5-12,5 s) | Silbidos en faltas y tarjetas |
| `whistle_short.ogg`, `whistle_long.ogg` | sonido silbato.wav | Pitazos del árbitro |
| `whistle_end.ogg` | whistle final partido.wav (8 canales / 96 kHz → mono) | Final del partido |
| `pass.ogg` | sonido de pase.wav | Pases |
| `crowd.ogg` | supports in stadium.wav | Tribuna de fondo (loop) |
| `chant.ogg` | sonido-hinchad.wav (30-90 s) | Cánticos de fondo (loop) |
| `prematch.ogg` | sonido ambiente previo partido.wav | Ambiente durante la presentación (loop) |
| `vuvuzelas.ogg` | vuvuzelas.wav (0-20 s) | Al terminar la presentación |
| `fulltime_win.ogg` | end to game wins.mp3 | Festejo de la tribuna al final (si alguien ganó) |
| `menu_move.ogg`, `menu_select.ogg` | sonido moverse en menu.ogg, sonido de seleccion.ogg | Menúes |

## Cielos HDRI (opcionales, CC0)

`SkyTextures` usa un panorama de `assets/skies/` según el horario y el clima:
`despejado`, `amanecer_invierno`, `atardecer`, `nublado`, `nublado2`, `nieve`
(.hdr / .exr / .jpg / .png, 2K). Los de ambientCG que elegiste
(HdrOutdoorFieldBaseballDayClear001, HdrOutdoorSoccerFieldWinterDayClear001,
HdrSkySunset007, HdrSkyOvercast001, HdrOutdoorFieldDayOvercast004,
HdrOutdoorSnowMountainsEveningClear001) son CC0: se dejan en
`assets/_entrada/` y Claude los renombra y los anota acá.

## Entrada de assets

Ver `assets/_entrada/LEEME.md`: los zips se dejan tal como se bajan y se
procesan en la próxima sesión (tamaño, nombres, conexión al juego y créditos).
