# Mapeo UV del uniforme (cuerpo clásico)

Base para el **editor externo de camisetas** (al final del plan): una sola
textura cuadrada (recomendado 1024×1024) con todas las piezas de la ropa. Si
un equipo tiene textura, el juego la usa en lugar del diseño por código
(`ModelVisual.set_kit_texture`, uniforme `kit_tex` de
`player_body.gdshader`). El número de la espalda, el del short y el escudo
se siguen pintando encima.

```
 u →  0        0.25       0.5        0.75       1
v 0   ┌──────────────────────┬──────────┬──────────┐
↓     │                      │ manga    │ manga    │
      │       TORSO          │ izquierda│ derecha  │
0.25  │  (vuelta completa)   ├──────────┴──────────┤
      │                      │                     │
0.5   ├──────────┬───────────┼──────────┬──────────┤
      │ short    │ short     │ media    │ media    │
      │ izquierdo│ derecho   │ izquierda│ derecha  │
0.75  ├──────────┴───────────┴──────────┴──────────┤
      │            (libre: piel, botines, pelo)    │
1     └────────────────────────────────────────────┘
```

- **u** = la vuelta alrededor de cada pieza; **v** = a lo largo, de arriba
  hacia abajo (torso: del cuello a la cintura; mangas: del hombro al ruedo;
  short: de la cintura al ruedo; medias: de la rodilla al tobillo).
- Torso: la espalda queda en u ≈ 0.125 (un cuarto de la vuelta) y el pecho en
  u ≈ 0.375 (tres cuartos), dentro de su mitad izquierda de la textura
  (u 0–0.5). La costura (donde empieza y termina la vuelta) va al costado.
- "Izquierda" es la del jugador (la del escudo).
- Las zonas libres (v > 0.75) no se usan.

Regiones exactas: `ClassicBody.UV_*` en `scripts/player/classic_body.gd`.
