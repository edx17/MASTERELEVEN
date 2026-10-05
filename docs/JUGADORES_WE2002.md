# Jugadores: modelo, aspecto y datos (referencia: Winning Eleven 2002)

> **Paso B hecho (PR #30):** cuerpo paramétrico, identidad guardada, malla
> más fina con cara, UV de la ropa, manga larga, número en el short y pelo
> con mechones (14 peinados). Quedan para más adelante: cuellos en V/polo
> (editor de camisetas), nombre en la espalda y la cara con textura para los
> "Detallados".

Especificación que pasó el dueño del proyecto (octubre 2026), cruzada con
lo que ya tiene Master Eleven (`PlayerData`, `ModelVisual`, `ClassicBody`,
`HairBuilder`). Estados: ✅ hecho · 🟡 parcial · ⬜ falta.

## 1. Malla y físico
| Pide | Estado | Paso |
|---|---|---|
| Malla low-poly por jugador | ✅ Cuerpo clásico low-poly (por defecto) y "Detallados" (Mixamo). | — |
| Físico A delgado / B estándar / C musculoso / D-E-G corpulento o alto | 🟡 `PlayerData.Build`: NORMAL, HEAVY, SLIM, TALL, SHORT, STOCKY, MUSCULAR (+ AUTO). Falta mostrarlo con las letras del WE (A = SLIM, B = NORMAL, C = MUSCULAR, D = STOCKY, E = HEAVY, G = TALL). | B |
| Estatura 155–205 cm, escalando el cuerpo desde la cadera | 🟡 `height` existe (o se deduce del físico) y cuenta en el juego (cabezazos, cuerpo a cuerpo), pero el modelo se escala por físico, no por los cm exactos. | B |

## 2. Cabeza, cara y pelo
| Pide | Estado | Paso |
|---|---|---|
| Piel A clara / B trigueña / C oscura / D muy oscura | 🟡 4 tonos, pero **al azar**: no se guarda en el jugador. | B |
| Peinados intercambiables (rapado, calvo con coronilla, corto con raya, melena con vincha, rulos/afro, rastas/trenzas, flequillo/copete) | 🟡 `hair` con 9 estilos (FADE, SHAVED, HELMET, MOHAWK, PONYTAIL, CURLY_BAND, DREADS, HORSESHOE, LONG_PARTED). Faltan: afro largo, trenzas pegadas, flequillo/copete, corto con raya; y el pelo de los "Detallados" parece plastilina. | B |
| Color de pelo: negro, castaño oscuro/claro, rubio, pelirrojo, canoso, teñido | 🟡 4 tonos **al azar**. | B |
| Barba / bigote (candado, bigote, poblada, de tres días) y su color | ⬜ | B |
| Cara con textura (ojos, nariz, boca) | ⬜ (cara lisa) | B (opcional) |

## 3. Ropa y botines
| Pide | Estado | Paso |
|---|---|---|
| Camiseta con escudo adelante, dorsal (y nombre) atrás | ✅ Pintados en la tela (sin nombre en la espalda). | UI/C |
| Cuello en V, redondo o polo | ⬜ (ribete único) | C / editor de camisetas |
| Manga corta / **larga en lluvia o invierno** | ⬜ | B |
| Short con número en el muslo izquierdo | ⬜ | B |
| Medias altas con franjas | ✅ | — |
| Botines tipo A–H (negros clásicos, blancos/plateados, de color) **por jugador** | 🟡 Color de botines por equipo, no por jugador. | B |

## 4. Atributos
| Pide (WE) | En Master Eleven |
|---|---|
| SPEED, ACCELERATION, JUMP | `speed`, `acceleration`, `jump` ✅ |
| BODY BALANCE / STRENGTH | `balance`, `strength` ✅ |
| ATTACK, DEFENCE, STAMINA | `attack`, `defense`, `stamina` ✅ |
| PASS ACC., SHOT POWER, SHOT ACC. | `passing`, `shot_power`, `shooting` ✅ |
| DRIBBLE, CURVE, HEADER, TECHNIQUE, REACTIONS | `ball_control`, `curve`, `heading`, `technique`, `reaction` ✅ |
| Pie: derecho / izquierdo / **ambos** | 🟡 `foot` RIGHT/LEFT; falta BOTH (ambidiestro: sin pierna mala). B |
| Arquero | `goalkeeping` ✅ (el WE lo tiene aparte) |

Escala: Master Eleven usa 1–99. Los valores del WE (de 1 a 19 en la ficha,
los buenos entre 12 y 19) se convierten al cargar los datos reales (paso C)
con una tabla lineal que se va a calibrar (propuesta: 10 → 45, 15 → 72,
19 → 95), así la potencia 6–9 y los demás efectos siguen funcionando.

## 5. Datos (JSON de referencia) → `PlayerData`
| JSON | `PlayerData` | Estado |
|---|---|---|
| `player_identity.name` | `player_name` | ✅ |
| `callname_id` | (nombre para el relator) | ⬜ con el relator |
| `nationality` | `nationality` (con bandera) | ⬜ C |
| `age` | `age` | ✅ |
| `position_main` / `position_secondary` (CF, WG, OMF...) | `position` (GK/DF/MF/FW) + rol táctico de la formación | 🟡 B/C: puesto detallado y secundarios |
| `morphology.height_cm`, `physique_type`, `foot_pref`, `skin_colour` | `height`, `build`, `foot`, (piel) | 🟡 B |
| `head_appearance.*` (peinado, color, barba y color) | `hair` (+ color, barba) | 🟡 B |
| `kit_equipment.sleeve_type`, `shoe_model`, `shirt_number` | (mangas), (botines), `number` | 🟡 B |
| `attributes_core.*` | atributos 1–99 | ✅ (con la conversión de escala) |

## Paso B ampliado (propuesto)
1. `PlayerData`: nacionalidad, tono de piel (A–D), color de pelo, barba /
   bigote y su color, botines (A–H y color), pie BOTH, puesto detallado y
   secundarios. Todo con "AUTO" para los datos que todavía no lo tienen.
2. Físico con las letras del WE y estatura en cm que escala el modelo
   desde la cadera (155–205 cm).
3. Peinados que faltan (afro largo, trenzas pegadas, flequillo/copete, corto
   con raya) y arreglo del pelo de los "Detallados".
4. Barba / bigote como decal o malla simple.
5. Manga larga automática con lluvia, nieve o frío; número en el short.
6. Botines por jugador (y los de color especial).
7. La ficha muestra físico, estatura, pie y estos datos.
