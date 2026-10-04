# Carpeta de entrada de assets

Dejá acá los archivos **tal como los bajaste** (los .zip de ambientCG o Poliigon,
los .fbx de Mixamo, sonidos .wav/.ogg/.mp3) y subilos al repo:

```
git add assets/_entrada
git commit -m "Assets nuevos"
git push
```

En la próxima sesión Claude los descomprime, elige los mapas que sirven
(color, normal, rugosidad), los achica a un tamaño razonable (2K para
texturas y cielos), los renombra, los conecta al juego, los anota en
`assets/CREDITS.md` y borra los originales de esta carpeta.

Godot ignora esta carpeta (`.gdignore`), así que no se importa nada de acá.

## Qué conviene bajar

| Qué | Resolución | Formato |
|---|---|---|
| Texturas (césped, tela, tierra) | 2K | JPG (ambientCG: "2K-JPG") |
| Cielos HDRI | 2K | HDR o EXR (ambientCG: "2K-HDR") |
| Animaciones de Mixamo | — | FBX, "Without Skin", 30 fps |
| Sonidos | — | WAV u OGG |
