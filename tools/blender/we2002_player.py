"""MASTER ELEVEN - jugador estilo Winning Eleven 2002 (PS1), para Blender.

Ejecutar en Blender (Scripting > Run Script). Probado en Blender 4.2.

El look es el del WE2002 / ISS Pro Evolution 2 remasterizado: el cuerpo
armado con cajas (4 lados) apenas afinadas, torso cuadrado y ancho de
hombros, mangas cortas que son bloques gruesos, short ancho tipo pollera con
cada pierna como un bloque que gira con el muslo, manos en puño (cubos),
medias y botines en bloque, y todo el detalle (tres tiras, número, cara,
pelo) pintado en la textura.

Reglas técnicas:
  - Piezas separadas, sin skinning: en la animación sólo rotan y se
    atraviesan (clipping), como en la PS1.
  - Origen de cada pieza en su articulación y jerarquía FK:
        Player (Empty, en el piso, entre los pies)
        └─ Hips (cintura del short; origen: centro de la cadera)
           ├─ Torso (camiseta; origen: cintura)
           │  ├─ Head (cabeza y cuello; origen: base del cuello)
           │  └─ UpperArm.L/R (hombro) ─ LowerArm (codo) ─ Hand (muñeca)
           └─ Thigh.L/R (cadera) ─ Calf (rodilla) ─ Boot (tobillo)
  - Cajas de 4 lados con anillos (la cabeza, de 8), Shade Flat, menos de
    MAX_TRIS triángulos (el script lo verifica).
  - Un único atlas de ATLAS_SIZE x ATLAS_SIZE (filtrado Closest, pixel art).
    Cada pieza tiene su UV cilíndrico en un rectángulo propio (.L y .R
    comparten los mismos píxeles, como en la PS1), y el atlas sale pintado
    con los colores del equipo, el número de espalda, la cara y el pelo.
    Guardalo (Image > Save As) y pintalo encima.

Convención de Blender: Z arriba, el jugador mira hacia -Y (vista Front,
numpad 1) y su izquierda es +X (.L). Unidades: metros (1,80 m de alto).
Para Godot: exportar glTF 2.0 (+Y Up), sin "Skinning".
"""

import math

import bmesh
import bpy

# --- Parámetros ---------------------------------------------------------------

ATLAS_SIZE = 256
MAX_TRIS = 380

# Colores del equipo (RGB 0-1). Por defecto, el blanco y negro de las capturas.
COLORS = {
    "shirt": (0.93, 0.93, 0.91),
    "shirt_shade": (0.80, 0.80, 0.79),  # costados y espalda baja
    "trim": (0.08, 0.08, 0.10),         # cuello, puños y tres tiras
    "number": (0.08, 0.08, 0.10),
    "shorts": (0.08, 0.08, 0.10),
    "shorts_trim": (0.93, 0.93, 0.91),
    "sock": (0.93, 0.93, 0.91),
    "sock_trim": (0.08, 0.08, 0.10),
    "boot": (0.97, 0.97, 0.97),
    "boot_accent": (0.95, 0.30, 0.62),  # botines modernos: blanco y rosa
    "skin": (0.86, 0.66, 0.52),
    "skin_dark": (0.66, 0.47, 0.36),
    "hair": (0.34, 0.21, 0.11),
    "eyes": (0.10, 0.08, 0.07),
    "eye_white": (0.95, 0.95, 0.93),
}
SHIRT_NUMBER = "10"
THREE_STRIPES = True    # tiras en hombros, mangas y short

# Articulaciones (m desde el piso o respecto del padre).
HIP_Z = 0.92        # centro de la cadera: origen de Hips y de los muslos
HIP_X = 0.10
WAIST_DZ = 0.10     # cintura (origen del torso) sobre la cadera
NECK_DZ = 0.50      # base del cuello sobre la cintura
SHOULDER_X = 0.225
SHOULDER_DZ = 0.42  # hombros sobre la cintura
THIGH_LEN = 0.42
CALF_LEN = 0.42     # tobillo a 0,08 m: la suela apoya en el piso
UPPER_ARM_LEN = 0.28
LOWER_ARM_LEN = 0.24

SQ2 = math.sqrt(2.0)


def box(z, hw, hd, cy=0.0):
    """Anillo de 4 lados (caja) con medio ancho `hw`, media profundidad `hd`."""
    return (z, hw * SQ2, hd * SQ2, cy)


# --- Piezas -----------------------------------------------------------------------
# Cada anillo: (z, radio_x, radio_y, centro_y) relativo al origen de la pieza.
# `paint`: color de cada tramo entre anillos; `caps`: tapas (primer anillo, último).
# `rect`: tamaño en píxeles de su lugar en el atlas.

PARTS = [
    # Short: un bloque ancho que baja hasta el muslo (tipo pollera).
    {"name": "Hips", "parent": "Player", "joint": (0.0, 0.0, HIP_Z), "sides": 4,
     "rings": [box(-0.13, 0.195, 0.125), box(WAIST_DZ + 0.02, 0.175, 0.115)],
     "paint": ["shorts"], "caps": ("shorts", "shorts"), "rect": (112, 40),
     "detail": "shorts"},
    # Camiseta: caja más ancha en el pecho y los hombros, que cierra al cuello.
    {"name": "Torso", "parent": "Hips", "joint": (0.0, 0.0, WAIST_DZ), "sides": 4,
     "rings": [box(-0.06, 0.175, 0.112), box(0.24, 0.205, 0.130, -0.008),
               box(SHOULDER_DZ, 0.215, 0.120), box(NECK_DZ, 0.100, 0.080, 0.008)],
     "paint": ["shirt", "shirt", "shirt"], "caps": ("shirt", "skin"), "rect": (128, 96),
     "detail": "torso"},
    # Cabeza (8 lados): cuello corto, mandíbula, pómulos, frente y coronilla
    # con volumen de pelo.
    {"name": "Head", "parent": "Torso", "joint": (0.0, 0.0, NECK_DZ), "sides": 8,
     "rings": [(-0.02, 0.052, 0.052, 0.0), (0.05, 0.078, 0.088, -0.014),
               (0.13, 0.098, 0.108, -0.006), (0.205, 0.100, 0.110, 0.004),
               (0.275, 0.068, 0.074, 0.010)],
     "paint": ["skin", "skin", "skin", "hair"], "caps": ("skin", "hair"), "rect": (96, 64),
     "detail": "head"},
    # Manga: un bloque grueso; debajo, el brazo.
    {"name": "UpperArm", "parent": "Torso", "joint": (SHOULDER_X, 0.0, SHOULDER_DZ), "sides": 4,
     "rings": [box(0.02, 0.068, 0.066), box(-0.15, 0.064, 0.062),
               box(-0.152, 0.044, 0.044), box(-UPPER_ARM_LEN, 0.040, 0.040)],
     "paint": ["shirt", "skin", "skin"], "caps": ("shirt", "skin"), "rect": (48, 48),
     "detail": "sleeve"},
    {"name": "LowerArm", "parent": "UpperArm", "joint": (0.0, 0.0, -UPPER_ARM_LEN), "sides": 4,
     "rings": [box(0.0, 0.040, 0.040), box(-LOWER_ARM_LEN, 0.032, 0.030)],
     "paint": ["skin"], "caps": ("skin", "skin"), "rect": (32, 32)},
    # Puño: un cubo.
    {"name": "Hand", "parent": "LowerArm", "joint": (0.0, 0.0, -LOWER_ARM_LEN), "sides": 4,
     "rings": [box(-0.11, 0.052, 0.046, -0.004), box(0.01, 0.044, 0.040)],
     "paint": ["skin"], "caps": ("skin", "skin"), "rect": (32, 24)},
    # Pierna del short (bloque que gira con el muslo) y el muslo.
    {"name": "Thigh", "parent": "Hips", "joint": (HIP_X, 0.0, 0.0), "sides": 4,
     "rings": [box(0.0, 0.098, 0.118), box(-0.20, 0.104, 0.124),
               box(-0.202, 0.064, 0.068), box(-THIGH_LEN, 0.055, 0.058)],
     "paint": ["shorts", "shorts", "skin"], "caps": ("shorts", "skin"), "rect": (64, 64),
     "detail": "short_leg"},
    # Media con gemelo marcado.
    {"name": "Calf", "parent": "Thigh", "joint": (0.0, 0.0, -THIGH_LEN), "sides": 4,
     "rings": [box(0.0, 0.056, 0.060), box(-0.13, 0.060, 0.068, 0.008),
               box(-CALF_LEN, 0.038, 0.040)],
     "paint": ["sock", "sock"], "caps": ("sock", "sock"), "rect": (48, 64),
     "detail": "sock"},
    # Botín en bloque: suela larga, empeine y caña baja.
    {"name": "Boot", "parent": "Calf", "joint": (0.0, 0.0, -CALF_LEN), "sides": 4,
     "rings": [box(-(HIP_Z - THIGH_LEN - CALF_LEN), 0.054, 0.140, -0.050),
               box(-0.030, 0.052, 0.118, -0.045), box(0.030, 0.042, 0.060, 0.0)],
     "paint": ["boot", "boot"], "caps": ("boot_accent", "sock"), "rect": (48, 32),
     "detail": "boot"},
]
MIRRORED = {"UpperArm", "LowerArm", "Hand", "Thigh", "Calf", "Boot"}
CAP_PX = 12


# --- Escena -------------------------------------------------------------------------

def clear_scene() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Atlas: lugares de cada pieza (estantes) --------------------------------------

def pack_atlas() -> dict:
    """Rectángulos (x, y, w, h) en píxeles: la pieza y sus dos tapas."""
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


# --- Malla (bmesh): anillos, tapas y UV cilíndrico --------------------------------

def ring_angles(sides: int) -> list:
    # Una cara plana mirando al frente (-Y).
    return [2.0 * math.pi * i / sides + math.pi / sides - math.pi / 2.0 for i in range(sides)]


def u_of(angle: float, theta0: float) -> float:
    """U alrededor del cuerpo: arranca en el costado derecho del jugador (-X),
    pasa por el frente y la izquierda y termina en la espalda; de frente y
    de espaldas la textura se lee derecha (sin espejar)."""
    return ((angle - theta0) % (2.0 * math.pi)) / (2.0 * math.pi)


def part_layout(p: dict) -> dict:
    """Bandas en V de cada tramo y U del frente / espalda (para pintar)."""
    zs = [r[0] for r in p["rings"]]
    z0, z1 = min(zs), max(zs)
    bands = [((a - z0) / (z1 - z0), (b - z0) / (z1 - z0)) for a, b in zip(zs, zs[1:])]
    angles = [((a + math.pi) % (2.0 * math.pi)) - math.pi for a in ring_angles(p["sides"])]
    theta0 = min(angles)
    return {"bands": bands, "theta0": theta0,
            "u_front": u_of(-math.pi / 2.0, theta0), "u_back": u_of(math.pi / 2.0, theta0)}


def build_mesh(p: dict, rects: dict):
    n = p["sides"]
    angles = ring_angles(n)
    lay = part_layout(p)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    loops = []
    for z, rx, ry, cy in p["rings"]:
        loops.append([bm.verts.new((math.cos(a) * rx, math.sin(a) * ry + cy, z)) for a in angles])

    x, y, w, h = rects[p["name"]]

    def to_px(u, v, rect):
        rx0, ry0, rw, rh = rect
        return ((rx0 + 0.5 + u * (rw - 1.0)) / ATLAS_SIZE, (ry0 + 0.5 + v * (rh - 1.0)) / ATLAS_SIZE)

    zs = [r[0] for r in p["rings"]]
    z0, z1 = min(zs), max(zs)
    for k in range(len(loops) - 1):
        ra, rb = loops[k], loops[k + 1]
        va = (zs[k] - z0) / (z1 - z0)
        vb = (zs[k + 1] - z0) / (z1 - z0)
        for i in range(n):
            j = (i + 1) % n
            ui = u_of(angles[i], lay["theta0"])
            uj = ui + 1.0 / n
            # Cara con la vuelta de la U: siempre entera, sin cruzar el borde.
            face = bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
            for loop, (u, v) in zip(face.loops, ((ui, va), (uj, va), (uj, vb), (ui, vb))):
                loop[uv].uv = to_px(min(u, 1.0), v, (x, y, w, h))
    # Tapas: proyección plana en su cuadradito.
    for c, ring in enumerate((loops[0], loops[-1])):
        verts = ring if c == 1 else list(reversed(ring))
        face = bm.faces.new(verts)
        xs = [v.co.x for v in ring]
        ys = [v.co.y for v in ring]
        sx = max(max(xs) - min(xs), 1e-6)
        sy = max(max(ys) - min(ys), 1e-6)
        for loop in face.loops:
            u = (loop.vert.co.x - min(xs)) / sx
            v = (loop.vert.co.y - min(ys)) / sy
            loop[uv].uv = to_px(u, v, rects[f"{p['name']}:cap{c}"])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def make_object(name: str, p: dict, rects: dict, mat):
    bm = build_mesh(p, rects)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False  # Shade Flat
    mesh.materials.append(mat)
    return link(bpy.data.objects.new(name, mesh))


# --- Textura: el atlas pintado ------------------------------------------------------

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
        # Rectángulo de la pieza que se está pintando: nada se sale de él
        # (si no, un detalle pisa a la pieza vecina del atlas).
        self.clip = (0, 0, size, size)

    def put(self, x: int, y: int, c) -> None:
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


def paint_atlas(rects: dict) -> list:
    cv = Canvas(ATLAS_SIZE)
    cv.fill(0, 0, ATLAS_SIZE, ATLAS_SIZE, (0.5, 0.5, 0.5))
    for p in PARTS:
        x, y, w, h = rects[p["name"]]
        cv.clip = (x, y, w, h)
        lay = part_layout(p)
        for (v0, v1), key in zip(lay["bands"], p["paint"]):
            cv.fill(x, y + min(v0, v1) * h, x + w, y + max(v0, v1) * h + 1, COLORS[key])
        detail = p.get("detail")
        if detail:
            globals()["_detail_" + detail](cv, (x, y, w, h), lay)
        for c in (0, 1):
            cx, cy, cw, ch = rects[f"{p['name']}:cap{c}"]
            cv.clip = (cx, cy, cw, ch)
            cv.fill(cx, cy, cx + cw, cy + ch, COLORS[p["caps"][c]])
    cv.clip = (0, 0, ATLAS_SIZE, ATLAS_SIZE)
    return cv.px


def _u(rect, u):
    return rect[0] + u * rect[2]


def _v(rect, v):
    return rect[1] + v * rect[3]


def _side_faces(r, lay, sides: int = 4) -> list:
    """Centros en píxeles (x) de las caras laterales (ni frente ni espalda)."""
    out = []
    for k in range(sides):
        u = (k + 0.5) / sides
        du = min(abs(u - lay["u_front"]), abs(u - lay["u_back"]))
        if du > 0.2:
            out.append(_u(r, u))
    return out


def _three_stripes(cv: Canvas, x: float, y0: float, y1: float, c) -> None:
    for k in (-3, 0, 3):
        cv.fill(x + k - 0.5, y0, x + k + 0.5, y1, c)


def _detail_torso(cv: Canvas, r, lay) -> None:
    v_top = lay["bands"][-1][1]
    v_sh = lay["bands"][-1][0]
    face = r[2] / 4.0
    # Costados un poco más oscuros (da volumen con luz plana).
    for x in _side_faces(r, lay):
        cv.fill(x - face / 2, r[1], x + face / 2, _v(r, v_sh), COLORS["shirt_shade"])
    # Cuello redondo con ribete.
    uf = _u(r, lay["u_front"])
    cv.fill(r[0], _v(r, v_top) - 2, r[0] + r[2], _v(r, v_top) + 1, COLORS["trim"])
    # Tres tiras sobre los hombros (en el tramo de los hombros al cuello).
    if THREE_STRIPES:
        for x in _side_faces(r, lay):
            _three_stripes(cv, x, _v(r, v_sh), _v(r, v_top), COLORS["trim"])
    # Escudo a la izquierda del pecho (derecha de la imagen) y número chico.
    vc = (lay["bands"][1][0] + v_sh) * 0.5
    cv.fill(uf + 6, _v(r, vc) + 2, uf + 12, _v(r, vc) + 9, COLORS["trim"])
    cv.fill(uf + 7, _v(r, vc) + 3, uf + 11, _v(r, vc) + 8, COLORS["shirt_shade"])
    _number(cv, uf - 9, _v(r, vc) + 1, SHIRT_NUMBER, 1, 1)
    # Número de espalda, grande.
    _number(cv, _u(r, lay["u_back"]), _v(r, (lay["bands"][0][1] + v_sh) * 0.5) - 6, SHIRT_NUMBER, 3, 5)


def _number(cv: Canvas, cx: float, cy: float, text: str, sx: int, sy: int, color=None) -> None:
    width = len(text) * 4 * sx - sx
    x0 = int(cx - width / 2)
    for n, ch in enumerate(text):
        g = DIGITS.get(ch)
        if g is None:
            continue
        for row in range(5):
            for col in range(3):
                if g[row][col] == "1":
                    px = x0 + n * 4 * sx + col * sx
                    py = int(cy) + (4 - row) * sy
                    cv.fill(px, py, px + sx, py + sy, color or COLORS["number"])


def _detail_head(cv: Canvas, r, lay) -> None:
    (n0, n1), (j0, j1), (c0, c1), (b0, b1) = lay["bands"]
    uf = _u(r, lay["u_front"])
    face_half = r[2] * 0.17
    # Pelo: atrás y a los costados desde la nuca; patillas hasta la mandíbula.
    for x in range(r[0], r[0] + r[2]):
        d = abs(x - uf)
        d = min(d, r[2] - d)
        if d > face_half:
            cv.fill(x, _v(r, c0 if d < r[2] * 0.3 else j0 + 0.06), x + 1, _v(r, b1) + 1, COLORS["hair"])
    # Flequillo y cejas.
    cv.fill(uf - face_half, _v(r, b0) - 1, uf + face_half, _v(r, b0) + 1, COLORS["hair"])
    ye = _v(r, c0 + (c1 - c0) * 0.55)
    for s in (-1, 1):
        ex = uf + s * 5
        cv.fill(ex - 2, ye + 3, ex + 2, ye + 4, COLORS["hair"])          # ceja
        cv.fill(ex - 2, ye, ex + 2, ye + 2, COLORS["eye_white"])         # ojo
        cv.fill(ex - (1 if s < 0 else 0), ye, ex + (0 if s < 0 else 1) + 0.01, ye + 2, COLORS["eyes"])
    # Nariz (sombra), boca y mentón.
    cv.fill(uf - 1, _v(r, c0) - 1, uf + 1, ye - 1, COLORS["skin_dark"])
    ym = _v(r, j0 + (j1 - j0) * 0.6)
    cv.fill(uf - 3, ym, uf + 3, ym + 1, COLORS["skin_dark"])
    # Orejas: un toque más oscuro en los costados de la cara.
    for s in (-1, 1):
        ox = uf + s * (face_half + 2)
        cv.fill(ox - 1, _v(r, j1) - 1, ox + 1, ye + 2, COLORS["skin_dark"])
    # Sombra del cuello bajo la mandíbula.
    cv.fill(r[0], _v(r, n1) - 2, r[0] + r[2], _v(r, n1), COLORS["skin_dark"])


def _detail_sleeve(cv: Canvas, r, lay) -> None:
    v_cuff = lay["bands"][0][1]
    v_top = lay["bands"][0][0]
    cv.fill(r[0], _v(r, v_cuff), r[0] + r[2], _v(r, v_cuff) + 2, COLORS["trim"])
    if THREE_STRIPES:
        for x in _side_faces(r, lay):
            _three_stripes(cv, x, _v(r, v_cuff) + 2, _v(r, v_top) + 1, COLORS["trim"])


def _detail_shorts(cv: Canvas, r, lay) -> None:
    if THREE_STRIPES:
        for x in _side_faces(r, lay):
            _three_stripes(cv, x, r[1], r[1] + r[3], COLORS["shorts_trim"])
    # Elástico de la cintura.
    cv.fill(r[0], r[1] + r[3] - 3, r[0] + r[2], r[1] + r[3], COLORS["trim"])


def _detail_short_leg(cv: Canvas, r, lay) -> None:
    v0, v1 = sorted(lay["bands"][0])
    if THREE_STRIPES:
        for x in _side_faces(r, lay):
            _three_stripes(cv, x, _v(r, v0) + 2, _v(r, v1) + 1, COLORS["shorts_trim"])


def _detail_sock(cv: Canvas, r, lay) -> None:
    top = r[1] + r[3]
    for k in (5, 9):
        cv.fill(r[0], top - k - 2, r[0] + r[2], top - k, COLORS["sock_trim"])
    # Tobillo un poco más oscuro (la media arrugada).
    cv.fill(r[0], r[1], r[0] + r[2], r[1] + 3, COLORS["shirt_shade"])


def _detail_boot(cv: Canvas, r, lay) -> None:
    # Suela, puntera y talón de color; tiras en los costados.
    cv.fill(r[0], r[1], r[0] + r[2], r[1] + 4, COLORS["boot_accent"])
    uf = _u(r, lay["u_front"])
    cv.fill(uf - 5, r[1], uf + 5, r[1] + r[3] * 0.5, COLORS["boot_accent"])
    ub = _u(r, lay["u_back"])
    cv.fill(ub - 5, r[1], ub + 5, r[1] + r[3], COLORS["boot_accent"])
    for x in _side_faces(r, lay):
        for k in range(3):
            for t in range(int(r[3] * 0.55)):
                cv.put(int(x - 5 + k * 4 + t * 0.35), int(r[1] + 5 + t), COLORS["boot_accent"])


def atlas_material(rects: dict):
    img = bpy.data.images.new(f"WE_Atlas_{ATLAS_SIZE}", ATLAS_SIZE, ATLAS_SIZE)
    img.pixels = paint_atlas(rects)
    img.pack()
    mat = bpy.data.materials.new("WE_Atlas")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"  # píxeles nítidos, sin filtrado
    tex.location = (-350, 300)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# --- Jugador ------------------------------------------------------------------------

def build_player():
    rects = pack_atlas()
    mat = atlas_material(rects)
    root = link(bpy.data.objects.new("Player", None))
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.3
    objs = {"Player": root}
    for p in PARTS:
        sides = (("L", 1.0), ("R", -1.0)) if p["name"] in MIRRORED else (("", 1.0),)
        for suffix, sx in sides:
            name = f"{p['name']}.{suffix}" if suffix else p["name"]
            obj = make_object(name, p, rects, mat)
            parent = p["parent"]
            if parent in MIRRORED:
                parent = f"{parent}.{suffix}"
            jx, jy, jz = p["joint"]
            # Sin inversa: el origen queda en la articulación, relativo al padre.
            obj.parent = objs[parent]
            obj.location = (jx * sx, jy, jz)
            objs[name] = obj
    return root


def triangle_count() -> int:
    return sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)


def main() -> None:
    clear_scene()
    build_player()
    tris = triangle_count()
    parts = sum(1 for o in bpy.data.objects if o.type == "MESH")
    print(f"MASTER ELEVEN: {parts} piezas, {tris} triángulos (máx. {MAX_TRIS})")
    assert tris <= MAX_TRIS, f"El jugador tiene {tris} triángulos (máximo {MAX_TRIS})"


if __name__ == "__main__":
    main()
