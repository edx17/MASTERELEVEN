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
| Humanoide provisorio (si faltan los modelos) | `scripts/player/player_visual.gd` | Producción propia | Propia |
| Textura de la pelota | generada por código (`scripts/ball/ball.gd`) | Producción propia | Propia |
| HUD (radar, paneles, "banderas" de club) | dibujado por código (`scripts/ui/match_hud.gd`) | Producción propia | Propia |
| Ícono del proyecto | `icon.svg` | Producción propia | Propia |

## Herramientas de terceros (no son assets del juego)

| Herramienta | Ubicación | Origen | Licencia |
|-------------|-----------|--------|----------|
| GUT 9.7.1 (tests unitarios) | `addons/gut/` | https://github.com/bitwes/Gut | MIT (`addons/gut/LICENSE.md`) |
