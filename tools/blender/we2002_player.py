"""MASTER ELEVEN - jugador low-poly estilo fútbol de PS1 / PS2 (WE2002), Blender.

Ejecutar en Blender (Scripting > Run Script). Probado en Blender 4.2.

Arma un jugador listo para animar:
  1. Modelado low-poly: torso de caja deformada, brazos y piernas como
     prismas de 4 lados, cabeza tipo esfera de 8 segmentos, pelo en un bloque
     compacto, puños cúbicos y botines en bloque. Shade Flat (caras planas).
  2. Textura pixel art: una sola imagen chica (ATLAS_SIZE, 128 o 256) con
     filtro Closest. Cada pieza tiene un UV ordenado y recto (con las costuras
     marcadas) en su lugar del atlas, que ya sale pintado: camiseta, número,
     short, medias, botines, cara y pelo. Guardalo (Image > Save As) y
     pintalo encima en Blender o en Aseprite.
  3. Material sin brillo (Roughness 1, Specular 0). Con TOON = True se arma
     el sombreado toon de Eevee: Shader to RGB -> Color Ramp en Constant
     (tres tonos, sin degradé) multiplicado por la textura.
  4. Esqueleto simple ("Player_Rig") y una sola malla ("Player_Mesh") con
     pesos rígidos: cada vértice pertenece al 100% a un hueso, así las
     articulaciones se doblan toscas, sin estirarse, como en esa época.

Huesos: Hips (raíz) > Spine > Head; Spine > UpperArm.L/R > LowerArm > Hand;
Hips > Thigh.L/R > Calf > Foot.
Convención de Blender: Z arriba, el jugador mira hacia -Y (vista Front,
numpad 1) y su izquierda es +X (.L). Unidades: metros (~1,83 m con el pelo).
Para Godot: exportar glTF 2.0 (+Y Up) con el esqueleto (Skinning).
"""

import math

import bmesh
import bpy

# --- Parámetros ---------------------------------------------------------------

ATLAS_SIZE = 256
TOON = True               # sombreado toon (Eevee); False: Principled plano
MAX_TRIS = 700

# Colores del equipo (RGB 0-1). Por defecto, el azul / blanco / rojo de la
# captura de referencia.
COLORS = {
    "shirt": (0.13, 0.22, 0.62),
    "shirt_shade": (0.10, 0.16, 0.48),  # costados: da volumen con luz plana
    "trim": (0.95, 0.95, 0.95),         # cuello y puños
    "number": (0.95, 0.95, 0.95),
    "crest": (0.80, 0.65, 0.25),
    "shorts": (0.94, 0.94, 0.93),
    "shorts_shade": (0.80, 0.80, 0.80),
    "sock": (0.78, 0.12, 0.16),
    "sock_trim": (0.95, 0.95, 0.95),
    "boot": (0.97, 0.97, 0.97),
    "boot_accent": (0.95, 0.32, 0.62),
    "skin": (0.66, 0.44, 0.30),
    "skin_dark": (0.48, 0.30, 0.20),
    "hair": (0.10, 0.08, 0.07),
    "hair_light": (0.22, 0.16, 0.12),
    "eyes": (0.08, 0.06, 0.05),
    "eye_white": (0.92, 0.90, 0.86),
    "mouth": (0.42, 0.22, 0.18),
}
SHIRT_NUMBER = "10"

# Articulaciones (m desde el piso).
HIP_Z = 0.92
WAIST_Z = 1.02
NECK_Z = 1.52
SHOULDER_X = 0.215
SHOULDER_Z = 1.44
ELBOW_Z = 1.16
WRIST_Z = 0.92
HIP_X = 0.10
KNEE_Z = 0.50
ANKLE_Z = 0.08

SQ2 = math.sqrt(2.0)


def box(z, hw, hd, cy=0.0):
    """Anillo de 4 lados (caja) con medio ancho `hw` y media profundidad `hd`."""
    return (z, hw * SQ2, hd * SQ2, cy)


# --- Piezas ---------------------------------------------------------------------
# Cada pieza es una torre de anillos: (z, radio_x, radio_y, centro_y), con z
# en metros desde el piso y centrada en `at` (x, y). `paint`: color de cada
# tramo entre anillos; `caps`: tapas (primer anillo, último); `rect`: tamaño
# en píxeles de su lugar en el atlas; `bone`: hueso al que pertenece (peso 1).
# Las piezas de los dos lados (side=True) comparten los píxeles del atlas.

PARTS = [
    # Short: un bloque ancho.
    {"name": "Shorts", "bone": "Hips", "at": (0.0, 0.0), "sides": 4,
     "rings": [box(0.78, 0.190, 0.122), box(WAIST_Z + 0.02, 0.172, 0.112)],
     "paint": ["shorts"], "caps": ("shorts", "shorts"), "rect": (112, 40), "detail": "shorts"},
    # Camiseta: caja deformada, ancha de pecho y hombros.
    {"name": "Torso", "bone": "Spine", "at": (0.0, 0.0), "sides": 4,
     "rings": [box(0.96, 0.178, 0.114), box(1.26, 0.212, 0.135, -0.010),
               box(SHOULDER_Z, 0.222, 0.124), box(NECK_Z, 0.098, 0.078, 0.008)],
     "paint": ["shirt", "shirt", "shirt"], "caps": ("shirt", "skin"), "rect": (128, 96),
     "detail": "torso"},
    # Cabeza: esfera de 8 segmentos (cuello, mandíbula, pómulos, frente, coronilla).
    {"name": "Head", "bone": "Head", "at": (0.0, 0.0), "sides": 8,
     "rings": [(1.50, 0.052, 0.052, 0.0), (1.57, 0.078, 0.086, -0.014),
               (1.65, 0.098, 0.106, -0.006), (1.72, 0.100, 0.108, 0.004),
               (1.79, 0.070, 0.076, 0.010)],
     "paint": ["skin", "skin", "skin", "hair"], "caps": ("skin", "hair"), "rect": (96, 64),
     "detail": "head"},
    # Pelo en bloque: un casco compacto apenas más grande que el cráneo,
    # corrido hacia atrás (nuca).
    {"name": "Hair", "bone": "Head", "at": (0.0, 0.014), "sides": 8,
     "rings": [(1.64, 0.106, 0.110, 0.010), (1.72, 0.112, 0.118, 0.004),
               (1.80, 0.090, 0.094, 0.004), (1.835, 0.050, 0.054, 0.004)],
     "paint": ["hair", "hair", "hair"], "caps": ("hair", "hair"), "rect": (96, 32),
     "detail": "hair"},
    # Manga gruesa y el brazo.
    {"name": "UpperArm", "bone": "UpperArm", "side": True, "at": (SHOULDER_X, 0.0), "sides": 4,
     "rings": [box(1.46, 0.070, 0.068), box(1.29, 0.066, 0.064),
               box(1.288, 0.044, 0.044), box(ELBOW_Z, 0.041, 0.041)],
     "paint": ["shirt", "skin", "skin"], "caps": ("shirt", "skin"), "rect": (48, 48),
     "detail": "sleeve"},
    {"name": "LowerArm", "bone": "LowerArm", "side": True, "at": (SHOULDER_X, 0.0), "sides": 4,
     "rings": [box(ELBOW_Z, 0.041, 0.041), box(WRIST_Z, 0.033, 0.031)],
     "paint": ["skin"], "caps": ("skin", "skin"), "rect": (32, 32)},
    # Puño cúbico.
    {"name": "Hand", "bone": "Hand", "side": True, "at": (SHOULDER_X, -0.004), "sides": 4,
     "rings": [box(WRIST_Z - 0.105, 0.054, 0.048), box(WRIST_Z + 0.01, 0.046, 0.042)],
     "paint": ["skin"], "caps": ("skin", "skin"), "rect": (32, 24), "detail": "fist"},
    # Pierna del short y el muslo.
    {"name": "Thigh", "bone": "Thigh", "side": True, "at": (HIP_X, 0.0), "sides": 4,
     "rings": [box(KNEE_Z, 0.055, 0.058), box(0.718, 0.064, 0.068),
               box(0.72, 0.104, 0.124), box(HIP_Z, 0.098, 0.118)],
     "paint": ["skin", "shorts", "shorts"], "caps": ("skin", "shorts"), "rect": (64, 64),
     "detail": "short_leg"},
    # Media con gemelo marcado.
    {"name": "Calf", "bone": "Calf", "side": True, "at": (HIP_X, 0.0), "sides": 4,
     "rings": [box(ANKLE_Z + 0.02, 0.038, 0.040), box(0.37, 0.061, 0.068, 0.008),
               box(KNEE_Z + 0.01, 0.057, 0.060)],
     "paint": ["sock", "sock"], "caps": ("sock", "sock"), "rect": (48, 64), "detail": "sock"},
    # Botín en bloque: suela larga, empeine y caña baja.
    {"name": "Boot", "bone": "Foot", "side": True, "at": (HIP_X, 0.0), "sides": 4,
     "rings": [box(0.0, 0.054, 0.140, -0.050), box(0.05, 0.052, 0.118, -0.045),
               box(0.11, 0.042, 0.060, 0.0)],
     "paint": ["boot", "boot"], "caps": ("boot_accent", "sock"), "rect": (48, 32), "detail": "boot"},
]
CAP_PX = 12

# Huesos: nombre -> (cabeza, cola, padre). Los de los lados se espejan.
BONES = {
    "Hips": ((0.0, 0.0, HIP_Z), (0.0, 0.0, WAIST_Z), None),
    "Spine": ((0.0, 0.0, WAIST_Z), (0.0, 0.0, NECK_Z), "Hips"),
    "Head": ((0.0, 0.0, NECK_Z), (0.0, 0.0, 1.82), "Spine"),
    "UpperArm": ((SHOULDER_X, 0.0, SHOULDER_Z), (SHOULDER_X, 0.0, ELBOW_Z), "Spine"),
    "LowerArm": ((SHOULDER_X, 0.0, ELBOW_Z), (SHOULDER_X, 0.0, WRIST_Z), "UpperArm"),
    "Hand": ((SHOULDER_X, 0.0, WRIST_Z), (SHOULDER_X, 0.0, WRIST_Z - 0.10), "LowerArm"),
    "Thigh": ((HIP_X, 0.0, HIP_Z), (HIP_X, 0.0, KNEE_Z), "Hips"),
    "Calf": ((HIP_X, 0.0, KNEE_Z), (HIP_X, 0.0, ANKLE_Z), "Thigh"),
    "Foot": ((HIP_X, 0.0, ANKLE_Z), (HIP_X, -0.17, 0.02), "Calf"),
}
SIDE_BONES = {"UpperArm", "LowerArm", "Hand", "Thigh", "Calf", "Foot"}


# --- Escena -------------------------------------------------------------------------

def clear_scene() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Atlas: lugar de cada pieza (estantes) -----------------------------------------

def pack_atlas() -> dict:
    items = []
    for p in PARTS:
        items.append((p["name"], p["rect"]))
        items.append((p["name"] + ":cap0", (CAP_PX, CAP_PX)))
        items.append((p["name"] + ":cap1", (CAP_PX, CAP_PX)))
    items.sort(key=lambda it: -it[1][1])
    rects, x, y, shelf = {}, 0, 0, 0
    for key, (w, h) in items:
        if x + w > ATLAS_SIZE:
            x, y, shelf = 0, y + shelf, 0
        rects[key] = (x, y, w, h)
        x += w
        shelf = max(shelf, h)
    assert y + shelf <= ATLAS_SIZE, "las piezas no entran en el atlas"
    return rects


# --- Geometría y UV ---------------------------------------------------------------

def ring_angles(sides: int) -> list:
    # Una cara plana mirando al frente (-Y).
    return [2.0 * math.pi * i / sides + math.pi / sides - math.pi / 2.0 for i in range(sides)]


def u_of(angle: float, theta0: float) -> float:
    """U alrededor del cuerpo: desde el costado derecho del jugador (-X) por el
    frente, la izquierda y la espalda. De frente y de espaldas la textura se
    lee derecha (sin espejar)."""
    return ((angle - theta0) % (2.0 * math.pi)) / (2.0 * math.pi)


def part_layout(p: dict) -> dict:
    """Bandas en V (de abajo hacia arriba) de cada tramo y U del frente y la espalda."""
    zs = [r[0] for r in p["rings"]]
    z0, z1 = min(zs), max(zs)
    bands = [tuple(sorted(((a - z0) / (z1 - z0), (b - z0) / (z1 - z0)))) for a, b in zip(zs, zs[1:])]
    angles = [((a + math.pi) % (2.0 * math.pi)) - math.pi for a in ring_angles(p["sides"])]
    theta0 = min(angles)
    return {"bands": bands, "theta0": theta0,
            "u_front": u_of(-math.pi / 2.0, theta0), "u_back": u_of(math.pi / 2.0, theta0)}


def add_part(bm, uv, p: dict, rects: dict, sx: float) -> list:
    """Agrega la pieza a `bm` (en el mundo; sx = -1 la espeja al lado
    derecho) con su UV y sus costuras. Devuelve sus vértices."""
    n = p["sides"]
    angles = ring_angles(n)
    lay = part_layout(p)
    ax, ay = p["at"]
    # En el lado espejado se recorren los vértices al revés para que las caras
    # sigan mirando hacia afuera; cada vértice usa la U de su gemelo.
    order = list(range(n)) if sx > 0 else list(reversed(range(n)))
    us = [u_of(angles[i], lay["theta0"]) for i in order]
    loops = []
    for z, rx, ry, cy in p["rings"]:
        loops.append([bm.verts.new(((ax + math.cos(angles[i]) * rx) * sx,
                                    ay + cy + math.sin(angles[i]) * ry, z)) for i in order])
    rect = rects[p["name"]]

    def to_uv(u, v, r):
        return ((r[0] + 0.5 + u * (r[2] - 1.0)) / ATLAS_SIZE, (r[1] + 0.5 + v * (r[3] - 1.0)) / ATLAS_SIZE)

    zs = [r[0] for r in p["rings"]]
    z0, z1 = min(zs), max(zs)
    for k in range(len(loops) - 1):
        ra, rb = loops[k], loops[k + 1]
        va = (zs[k] - z0) / (z1 - z0)
        vb = (zs[k + 1] - z0) / (z1 - z0)
        for i in range(n):
            j = (i + 1) % n
            ui, uj = us[i], us[j]
            if abs(ui - uj) > 0.5:  # la cara de la costura: el 0 pasa a ser 1
                if ui < uj:
                    ui = 1.0
                else:
                    uj = 1.0
            face = bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
            for loop, (u, v) in zip(face.loops, ((ui, va), (uj, va), (uj, vb), (ui, vb))):
                loop[uv].uv = to_uv(u, v, rect)
    # Tapas: proyección plana en su cuadradito.
    for c, ring in enumerate((loops[0], loops[-1])):
        face = bm.faces.new(ring if c == 1 else list(reversed(ring)))
        xs = [v.co.x for v in ring]
        ys = [v.co.y for v in ring]
        wx = max(max(xs) - min(xs), 1e-6)
        wy = max(max(ys) - min(ys), 1e-6)
        for loop in face.loops:
            loop[uv].uv = to_uv((loop.vert.co.x - min(xs)) / wx, (loop.vert.co.y - min(ys)) / wy,
                                rects[f"{p['name']}:cap{c}"])
    # Costuras (Seams) donde se corta el UV: el borde de la vuelta y el
    # contorno de las tapas. Sirven si después se re-desenrolla a mano.
    seam = us.index(min(us))
    for k in range(len(loops) - 1):
        e = bm.edges.get((loops[k][seam], loops[k + 1][seam]))
        if e is not None:
            e.seam = True
    for ring in (loops[0], loops[-1]):
        for i in range(n):
            e = bm.edges.get((ring[i], ring[(i + 1) % n]))
            if e is not None:
                e.seam = True
    return [v for ring in loops for v in ring]


# --- Textura pixel art -------------------------------------------------------------

DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


class Canvas:
    def __init__(self, size: int):
        self.size = size
        self.px = [0.0] * (size * size * 4)
        # Nada se pinta fuera del lugar de la pieza actual (si no, un detalle
        # pisa a la pieza vecina del atlas).
        self.clip = (0, 0, size, size)

    def put(self, x, y, c) -> None:
        x, y = int(x), int(y)
        cx, cy, cw, ch = self.clip
        if cx <= x < cx + cw and cy <= y < cy + ch:
            i = (y * self.size + x) * 4
            self.px[i:i + 4] = (c[0], c[1], c[2], 1.0)

    def fill(self, x0, y0, x1, y1, c) -> None:
        x0, x1 = min(x0, x1), max(x0, x1)
        y0, y1 = min(y0, y1), max(y0, y1)
        for yy in range(int(y0), int(math.ceil(y1))):
            for xx in range(int(x0), int(math.ceil(x1))):
                self.put(xx, yy, c)


def _u(r, u):
    return r[0] + u * r[2]


def _v(r, v):
    return r[1] + v * r[3]


def _side_centers(r, lay, sides: int = 4) -> list:
    """Centros (x en píxeles) de las caras de los costados."""
    out = []
    for k in range(sides):
        u = (k + 0.5) / sides
        if min(abs(u - lay["u_front"]), abs(u - lay["u_back"])) > 0.2:
            out.append(_u(r, u))
    return out


def _number(cv, cx, cy, text, sx, sy, color) -> None:
    x0 = int(cx - (len(text) * 4 * sx - sx) / 2)
    for n, ch in enumerate(text):
        g = DIGITS.get(ch)
        for row in range(5):
            for col in range(3):
                if g and g[row][col] == "1":
                    px = x0 + n * 4 * sx + col * sx
                    py = int(cy) + (4 - row) * sy
                    cv.fill(px, py, px + sx, py + sy, color)


def _detail_torso(cv, r, lay) -> None:
    v_sh = lay["bands"][-1][0]
    face = r[2] / 4.0
    for x in _side_centers(r, lay):
        cv.fill(x - face / 2, r[1], x + face / 2, _v(r, v_sh), COLORS["shirt_shade"])
    top = r[1] + r[3]
    cv.fill(r[0], top - 3, r[0] + r[2], top, COLORS["trim"])          # cuello
    uf = _u(r, lay["u_front"])
    cv.fill(uf - 4, top - 9, uf + 4, top - 3, COLORS["trim"])          # cuello polo
    cv.fill(uf - 2, top - 8, uf + 2, top - 3, COLORS["skin"])
    vc = (lay["bands"][1][0] + v_sh) * 0.5
    cv.fill(uf + 6, _v(r, vc), uf + 12, _v(r, vc) + 8, COLORS["crest"])  # escudo
    cv.fill(uf + 7, _v(r, vc) + 1, uf + 11, _v(r, vc) + 6, COLORS["shirt_shade"])
    _number(cv, _u(r, lay["u_back"]), _v(r, (lay["bands"][0][1] + v_sh) * 0.5) - 6,
            SHIRT_NUMBER, 3, 5, COLORS["number"])


def _detail_head(cv, r, lay) -> None:
    (n0, n1), (j0, j1), (c0, c1), (b0, b1) = lay["bands"]
    uf = _u(r, lay["u_front"])
    half = r[2] * 0.17
    # Pelo atrás y a los costados (lo que no tapa el bloque de pelo).
    for x in range(r[0], r[0] + r[2]):
        d = abs(x - uf)
        d = min(d, r[2] - d)
        if d > half:
            cv.fill(x, _v(r, c0 if d < r[2] * 0.3 else j0 + 0.06), x + 1, _v(r, b1) + 1, COLORS["hair"])
    cv.fill(uf - half, _v(r, b0) - 1, uf + half, _v(r, b0) + 1, COLORS["hair"])  # nacimiento del pelo
    ye = _v(r, c0 + (c1 - c0) * 0.5)
    for s in (-1, 1):
        ex = uf + s * 5
        cv.fill(ex - 2, ye + 3, ex + 2, ye + 4, COLORS["hair"])         # ceja
        cv.fill(ex - 2, ye, ex + 2, ye + 2, COLORS["eye_white"])        # ojo
        cv.fill(ex - (1 if s < 0 else 0), ye, ex + (0 if s < 0 else 1) + 0.01, ye + 2, COLORS["eyes"])
    cv.fill(uf - 1, _v(r, c0) - 1, uf + 1, ye - 1, COLORS["skin_dark"])  # nariz
    ym = _v(r, j0 + (j1 - j0) * 0.6)
    cv.fill(uf - 3, ym, uf + 3, ym + 1, COLORS["mouth"])
    for s in (-1, 1):                                                    # orejas
        ox = uf + s * (half + 2)
        cv.fill(ox - 1, _v(r, j1) - 1, ox + 1, ye + 2, COLORS["skin_dark"])
    cv.fill(r[0], _v(r, n1) - 2, r[0] + r[2], _v(r, n1), COLORS["skin_dark"])  # sombra del mentón


def _detail_hair(cv, r, lay) -> None:
    # Mechones: rayas verticales más claras dan volumen al bloque.
    for x in range(r[0], r[0] + r[2], 3):
        cv.fill(x, r[1] + 2, x + 1, r[1] + r[3] - 2, COLORS["hair_light"])


def _detail_sleeve(cv, r, lay) -> None:
    v_cuff = lay["bands"][-1][0]
    face = r[2] / 4.0
    for x in _side_centers(r, lay):
        cv.fill(x - face / 2, _v(r, v_cuff), x + face / 2, r[1] + r[3], COLORS["shirt_shade"])
    cv.fill(r[0], _v(r, v_cuff), r[0] + r[2], _v(r, v_cuff) + 2, COLORS["trim"])  # puño


def _detail_fist(cv, r, lay) -> None:
    uf = _u(r, lay["u_front"])
    cv.fill(uf - 3, r[1] + 3, uf + 3, r[1] + 4, COLORS["skin_dark"])  # nudillos


def _detail_shorts(cv, r, lay) -> None:
    face = r[2] / 4.0
    for x in _side_centers(r, lay):
        cv.fill(x - face / 2, r[1], x + face / 2, r[1] + r[3], COLORS["shorts_shade"])
    cv.fill(r[0], r[1] + r[3] - 3, r[0] + r[2], r[1] + r[3], COLORS["shirt"])  # elástico


def _detail_short_leg(cv, r, lay) -> None:
    v0 = lay["bands"][1][0]  # botamanga
    face = r[2] / 4.0
    for x in _side_centers(r, lay):
        cv.fill(x - face / 2, _v(r, v0), x + face / 2, r[1] + r[3], COLORS["shorts_shade"])
    cv.fill(r[0], _v(r, v0), r[0] + r[2], _v(r, v0) + 2, COLORS["shirt"])  # ribete


def _detail_sock(cv, r, lay) -> None:
    top = r[1] + r[3]
    cv.fill(r[0], top - 6, r[0] + r[2], top - 3, COLORS["sock_trim"])


def _detail_boot(cv, r, lay) -> None:
    cv.fill(r[0], r[1], r[0] + r[2], r[1] + 4, COLORS["boot_accent"])      # suela
    uf = _u(r, lay["u_front"])
    cv.fill(uf - 5, r[1], uf + 5, r[1] + r[3] * 0.45, COLORS["boot_accent"])  # puntera
    ub = _u(r, lay["u_back"])
    cv.fill(ub - 5, r[1], ub + 5, r[1] + r[3], COLORS["boot_accent"])      # talón
    for x in _side_centers(r, lay):                                          # tiras
        for k in range(3):
            for t in range(int(r[3] * 0.5)):
                cv.put(x - 5 + k * 3 + t * 0.3, r[1] + 5 + t, COLORS["boot_accent"])


def paint_atlas(rects: dict) -> list:
    cv = Canvas(ATLAS_SIZE)
    cv.fill(0, 0, ATLAS_SIZE, ATLAS_SIZE, (0.5, 0.5, 0.5))
    for p in PARTS:
        r = rects[p["name"]]
        cv.clip = r
        lay = part_layout(p)
        for (v0, v1), key in zip(lay["bands"], p["paint"]):
            cv.fill(r[0], _v(r, v0), r[0] + r[2], _v(r, v1) + 1, COLORS[key])
        if p.get("detail"):
            globals()["_detail_" + p["detail"]](cv, r, lay)
        for c in (0, 1):
            cr = rects[f"{p['name']}:cap{c}"]
            cv.clip = cr
            cv.fill(cr[0], cr[1], cr[0] + cr[2], cr[1] + cr[3], COLORS[p["caps"][c]])
    return cv.px


# --- Material: plano o toon --------------------------------------------------------

def make_material(rects: dict):
    img = bpy.data.images.new(f"WE_Atlas_{ATLAS_SIZE}", ATLAS_SIZE, ATLAS_SIZE)
    img.pixels = paint_atlas(rects)
    img.pack()
    mat = bpy.data.materials.new("WE_Player")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    out = nodes.get("Material Output")
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.name = "Atlas"
    tex.image = img
    tex.interpolation = "Closest"  # sin filtrado: píxeles nítidos
    tex.location = (-700, 300)
    # Sin brillo.
    bsdf.inputs["Roughness"].default_value = 1.0
    spec = bsdf.inputs.get("Specular IOR Level") or bsdf.inputs.get("Specular")
    spec.default_value = 0.0
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if not TOON:
        return mat
    # Toon (Eevee): la luz pasa a tres tonos fijos y multiplica la textura.
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.location = (-450, -200)
    to_rgb = nodes.new("ShaderNodeShaderToRGB")
    to_rgb.location = (-250, -200)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = (-50, -200)
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.45, 0.45, 0.50, 1.0)
    els[1].position, els[1].color = 0.55, (1.0, 1.0, 1.0, 1.0)
    els.new(0.2).color = (0.72, 0.72, 0.76, 1.0)
    mult = nodes.new("ShaderNodeMix")
    mult.data_type = "RGBA"
    mult.blend_type = "MULTIPLY"
    mult.inputs["Factor"].default_value = 1.0
    mult.location = (250, 100)
    emit = nodes.new("ShaderNodeEmission")
    emit.location = (450, 100)
    links.new(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
    links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    links.new(tex.outputs["Color"], mult.inputs[6])
    links.new(ramp.outputs["Color"], mult.inputs[7])
    links.new(mult.outputs[2], emit.inputs["Color"])
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    out.location = (650, 100)
    return mat


# --- Esqueleto y malla ---------------------------------------------------------------

def bone_list() -> list:
    """[(nombre, cabeza, cola, padre)] con los lados .L (+X) y .R (-X)."""
    out = []
    for name, (head, tail, parent) in BONES.items():
        if name in SIDE_BONES:
            for suf, sx in (("L", 1.0), ("R", -1.0)):
                par = f"{parent}.{suf}" if parent in SIDE_BONES else parent
                out.append((f"{name}.{suf}", (head[0] * sx, head[1], head[2]),
                            (tail[0] * sx, tail[1], tail[2]), par))
        else:
            out.append((name, head, tail, parent))
    return out


def build_rig():
    arm = bpy.data.armatures.new("Player_Rig")
    arm.display_type = "STICK"
    rig = link(bpy.data.objects.new("Player_Rig", arm))
    rig.show_in_front = True
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = bone_list()
    for name, head, tail, parent in bones:
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, tail
    for name, head, tail, parent in bones:
        if parent:
            b = arm.edit_bones[name]
            b.parent = arm.edit_bones[parent]
            b.use_connect = (arm.edit_bones[parent].tail - b.head).length < 1e-6
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def build_mesh(rig, mat, rects):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    groups = {}
    for p in PARTS:
        for suf, sx in ((("L", 1.0), ("R", -1.0)) if p.get("side") else (("", 1.0),)):
            bone = f"{p['bone']}.{suf}" if suf else p["bone"]
            groups.setdefault(bone, []).extend(add_part(bm, uv, p, rects, sx))
    bm.verts.index_update()
    index_groups = {b: [v.index for v in vs] for b, vs in groups.items()}
    mesh = bpy.data.meshes.new("Player_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False  # Shade Flat
    mesh.materials.append(mat)
    obj = link(bpy.data.objects.new("Player_Mesh", mesh))
    # Pesos rígidos: cada vértice al 100% en su hueso.
    for bone, idx in index_groups.items():
        obj.vertex_groups.new(name=bone).add(idx, 1.0, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature", "ARMATURE").object = rig
    return obj


def triangle_count(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def main() -> None:
    clear_scene()
    rects = pack_atlas()
    mat = make_material(rects)
    rig = build_rig()
    mesh = build_mesh(rig, mat, rects)
    if TOON:
        # El toon (Shader to RGB) es de Eevee; el nombre cambió entre versiones.
        for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
            try:
                bpy.context.scene.render.engine = engine
                break
            except TypeError:
                continue
    tris = triangle_count(mesh)
    print(f"MASTER ELEVEN: {tris} triángulos, {len(rig.data.bones)} huesos (máx. {MAX_TRIS} triángulos)")
    assert tris <= MAX_TRIS, f"El jugador tiene {tris} triángulos (máximo {MAX_TRIS})"


if __name__ == "__main__":
    main()
