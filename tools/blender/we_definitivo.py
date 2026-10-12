# Diseño Definitivo WE: jugador de pocos polígonos (estilo ForeverEleven /
# Winning Eleven 2002) armado sobre el esqueleto del juego.
#
# Uso (Blender 4.2 o más nuevo):
#   - Desde la consola:
#       blender --background --python tools/blender/we_definitivo.py
#   - Desde Blender: pestaña Scripting > Abrir este archivo > Run Script.
#
# Qué hace:
#   1. Importa el esqueleto del juego (assets/models/players/player_body.gltf)
#      y descarta su malla (sólo se usa el Armature: mismos huesos y misma pose
#      T de reposo, así funcionan las animaciones del juego y las que hagas vos).
#   2. Arma el cuerpo con "tubos" de pocas caras (anillos), caras planas:
#      cabeza con mandíbula, mentón, nariz y orejas; camiseta suelta, short
#      abierto, medias, botines en bloque y puños.
#   3. Peinados en bloques, cada uno un objeto aparte (WE_Pelo_corto,
#      WE_Pelo_rastas, WE_Pelo_afro); el juego elige uno según el jugador.
#   4. Pesos rígidos: cada anillo pegado a un hueso (codos, rodillas, cintura
#      y cuello mitad y mitad, para que no se abran al doblar).
#   5. Una ZONA por material. El juego pinta cada zona con los colores del
#      club (los colores de acá son sólo para verlo en Blender):
#        camiseta, manga, ribete_camiseta, short, ribete_short, medias,
#        piel, botines, pelo, manos
#   6. UV ordenado (cada tubo desenrollado en un rectángulo, ver UV abajo y
#      docs/KIT_UV.md) y una textura de detalle en pixel art de 256x256
#      (we_definitivo_detalle.png): pliegues, costuras, cara, suela,
#      cordones. Canales: R = sombreado (128 = neutro; más oscuro = pliegue),
#      G = cuánto se pinta encima, B = gris de esa pintura (ojos, suela).
#      Va ENCIMA de los colores del club, así sirve para todos los equipos.
#   7. Exporta assets/models/players/we_definitivo.glb (lo que carga el juego)
#      y guarda tools/blender/we_definitivo.blend (para seguir editándolo a
#      mano; la carpeta tiene .gdignore: Godot no lo importa).
#
# Si editás el .blend a mano, exportá con File > Export > glTF 2.0 (.glb):
# Data > Armature/Skinning activado, Animation desactivado, Material >
# Images: None (la textura de detalle va aparte).
#
# Coordenadas: las medidas de abajo están en metros y en ejes del juego
# (x: izquierda del jugador, y: arriba, z: adelante). En Blender eso es
# (x, -z, y): el jugador mira hacia -Y (vista frontal, tecla 1 del numpad).

import math
import os
import struct
import zlib

import bpy  # (bpy antes que bmesh: así también corre con el módulo bpy de pip)
import bmesh
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
SKELETON_SRC = os.path.join(REPO, "assets", "models", "players", "player_body.gltf")
OUT_GLB = os.path.join(REPO, "assets", "models", "players", "we_definitivo.glb")
OUT_TEX = os.path.join(REPO, "assets", "models", "players", "we_definitivo_detalle.png")
OUT_BLEND = os.path.join(HERE, "we_definitivo.blend")
BODY_NAME = "WE_Definitivo"
HAIR_NAMES = ("corto", "rastas", "afro")
TEX = 256

# Colores de muestra (Francia, como la referencia). El juego usa los del club.
ZONES = {
    "camiseta": (0.08, 0.16, 0.55),
    "manga": (0.08, 0.16, 0.55),
    "ribete_camiseta": (0.92, 0.92, 0.92),
    "short": (0.92, 0.92, 0.92),
    "ribete_short": (0.08, 0.16, 0.55),
    "medias": (0.62, 0.06, 0.08),
    "piel": (0.62, 0.42, 0.28),
    "botines": (0.85, 0.3, 0.55),
    "pelo": (0.05, 0.04, 0.03),
    "manos": (0.62, 0.42, 0.28),
}

# Regiones de la textura [u0, v0, u1, v1] (v hacia abajo, como la imagen).
# La ropa sigue docs/KIT_UV.md (sirve también para las camisetas con textura).
UV = {
    "torso": (0.0, 0.0, 0.5, 0.5),
    "manga_l": (0.5, 0.0, 0.75, 0.25), "manga_r": (0.75, 0.0, 1.0, 0.25),
    "cadera": (0.5, 0.25, 0.75, 0.5), "pelo": (0.75, 0.25, 1.0, 0.5),
    "short_l": (0.0, 0.5, 0.25, 0.75), "short_r": (0.25, 0.5, 0.5, 0.75),
    "media_l": (0.5, 0.5, 0.75, 0.75), "media_r": (0.75, 0.5, 1.0, 0.75),
    "cabeza": (0.0, 0.75, 0.5, 1.0),
    "botin_l": (0.5, 0.75, 0.625, 0.875), "botin_r": (0.625, 0.75, 0.75, 0.875),
    "mano_l": (0.5, 0.875, 0.5625, 1.0), "mano_r": (0.5625, 0.875, 0.625, 1.0),
    "piel": (0.625, 0.875, 0.75, 1.0),
    "brazo_l": (0.75, 0.75, 0.875, 1.0), "brazo_r": (0.875, 0.75, 1.0, 1.0),
}

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))


def to_blender(v):
    """Ejes del juego (y arriba, z adelante) a Blender (z arriba, -y adelante)."""
    return Vector((v.x, -v.z, v.y))


def ring(c, a, b, bones, mat, sq=0.6, back=None, tilt=0.0):
    """Un anillo de un tubo.
    c: centro (ejes del juego); a: medio ancho; b: medio largo hacia adelante
    (back: hacia atrás, si es distinto); bones: [(hueso, peso), ...]; mat:
    zona de la franja que empieza en este anillo; sq: qué tan "cuadrado" es
    (1 = elipse, 0.5 = caja con las esquinas cortadas); tilt: inclina el
    anillo (adelante más alto que atrás, para el pelo)."""
    return {"c": Vector(c), "a": a, "b": b, "back": b if back is None else back,
            "bones": bones, "mat": mat, "sq": sq, "tilt": tilt}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.uv = self.bm.loops.layers.uv.verify()
        self.mats = list(ZONES.keys())
        self.groups = []
        # Tubos con nombre: dónde cae cada anillo en la textura (para pintar).
        self.tubes = {}

    def _group(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def _vert(self, p, bones):
        v = self.bm.verts.new(to_blender(p))
        for bone, w in bones:
            v[self.deform][self._group(bone)] = w
        return v

    def face(self, items, mat, point=None, direction=None):
        """Cara con [(vértice, uv), ...] mirando hacia afuera (desde `point` o
        hacia `direction`, en Blender): el juego no dibuja la cara de atrás."""
        f = self.bm.faces.new([v for v, _ in items])
        f.material_index = self.mats.index(mat)
        f.normal_update()
        out = direction if direction is not None else f.calc_center_median() - point
        if f.normal.dot(out) < 0.0:
            f.normal_flip()
        uvs = {v: uv for v, uv in items}
        for loop in f.loops:
            loop[self.uv].uv = uvs[loop.vert]
        return f

    def tube(self, name, rings, sides, ea, eb, region=None, cap_start=True, cap_end=True):
        """Tubo de `sides` caras entre anillos. ea / eb: ejes del anillo
        (ejes del juego) para los radios a / b. UV: u = la vuelta, v = a lo
        largo, dentro de la región de la textura."""
        region = region or name
        ea = Vector(ea).normalized()
        eb = Vector(eb).normalized()
        loops = []
        for r in rings:
            ebr = (eb + Y * r["tilt"]).normalized() if r["tilt"] else eb
            loop = []
            for k in range(sides):
                t = 2 * math.pi * (k + 0.5) / sides
                ct, st = math.cos(t), math.sin(t)
                # Superelipse: con sq < 1 las caras de adelante, atrás y los
                # costados quedan planas (más "caja" que cilindro).
                px = math.copysign(abs(ct) ** r["sq"], ct) * r["a"]
                py = math.copysign(abs(st) ** r["sq"], st) * (r["b"] if st >= 0 else r["back"])
                loop.append(self._vert(r["c"] + ea * px + ebr * py, r["bones"]))
            loops.append(loop)
        dist = [0.0]
        for i in range(1, len(rings)):
            dist.append(dist[-1] + (rings[i]["c"] - rings[i - 1]["c"]).length)
        vs = [d / (dist[-1] or 1.0) for d in dist]
        self.tubes[name] = {"sides": sides, "cs": [r["c"] for r in rings], "vs": vs,
                            "as": [r["a"] for r in rings], "sq": rings[0]["sq"], "region": region}
        u0, v0, u1, v1 = UV[region]

        def uv(j, v):
            u = 1.0 - j / sides
            return (u0 + u * (u1 - u0), 1.0 - (v0 + v * (v1 - v0)))

        for i in range(len(rings) - 1):
            core = to_blender((rings[i]["c"] + rings[i + 1]["c"]) * 0.5)
            for k in range(sides):
                k2 = (k + 1) % sides
                self.face([(loops[i][k], uv(k, vs[i])), (loops[i][k2], uv(k + 1, vs[i])),
                           (loops[i + 1][k2], uv(k + 1, vs[i + 1])), (loops[i + 1][k], uv(k, vs[i + 1]))],
                          rings[i]["mat"], point=core)
        along = to_blender(rings[-1]["c"]) - to_blender(rings[0]["c"])
        if cap_start:
            self.face([(v, uv(k, vs[0])) for k, v in enumerate(loops[0])], rings[0]["mat"], direction=-along)
        if cap_end:
            self.face([(v, uv(k, vs[-1])) for k, v in enumerate(loops[-1])], rings[-1]["mat"], direction=along)

    def to_object(self, name, arm, materials):
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for g in self.groups:
            obj.vertex_groups.new(name=g)
        for m in materials:
            mesh.materials.append(m)
        for p in mesh.polygons:
            p.use_smooth = False  # caras planas
        mesh.validate()
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        return obj


# --- Cuerpo ------------------------------------------------------------------

HEAD_RINGS = [
    # y, ancho, adelante, atrás (mentón angosto y adelantado; nuca más alta).
    (1.572, 0.036, 0.078, 0.02),
    (1.598, 0.066, 0.088, 0.058),
    (1.635, 0.079, 0.093, 0.085),
    (1.675, 0.086, 0.095, 0.1),
    (1.71, 0.089, 0.093, 0.105),
    (1.745, 0.087, 0.09, 0.105),
    (1.78, 0.077, 0.078, 0.095),
    (1.803, 0.055, 0.05, 0.07),
    (1.815, 0.025, 0.02, 0.035),
]
HEAD_Z = -0.015


def build_body(b):
    # Camiseta (torso): ancha y suelta, hombros rectos, cae por encima del
    # short y se abre un poco abajo.
    b.tube("torso", [
        ring((0, 1.555, -0.035), 0.062, 0.058, [("neck_01", 0.5), ("spine_03", 0.5)], "ribete_camiseta", 0.8),
        ring((0, 1.525, -0.04), 0.078, 0.07, [("spine_03", 1.0)], "camiseta", 0.8),
        ring((0, 1.50, -0.045), 0.205, 0.12, [("spine_03", 1.0)], "camiseta", 0.55),
        ring((0, 1.40, -0.035), 0.215, 0.145, [("spine_03", 0.6), ("spine_02", 0.4)], "camiseta", 0.55),
        ring((0, 1.26, -0.03), 0.198, 0.138, [("spine_02", 1.0)], "camiseta", 0.55),
        ring((0, 1.12, -0.03), 0.19, 0.13, [("spine_01", 1.0)], "camiseta", 0.55),
        ring((0, 1.005, -0.03), 0.205, 0.138, [("pelvis", 1.0)], "ribete_camiseta", 0.55),
        ring((0, 0.972, -0.03), 0.214, 0.146, [("pelvis", 1.0)], "ribete_camiseta", 0.55),
    ], 8, X, Z, cap_start=False)
    b.tube("cuello", [
        ring((0, 1.5, -0.035), 0.052, 0.05, [("spine_03", 0.5), ("neck_01", 0.5)], "piel", 0.8),
        ring((0, 1.6, -0.03), 0.05, 0.05, [("neck_01", 0.5), ("Head", 0.5)], "piel", 0.8),
    ], 6, X, Z, region="piel", cap_start=False, cap_end=False)
    # Cabeza: mandíbula, mentón y nuca (pelada: el pelo es un objeto aparte).
    b.tube("cabeza", [ring((0, y, HEAD_Z), a, f, [("Head", 1.0)], "piel", 0.8, back=bk)
                      for y, a, f, bk in HEAD_RINGS], 8, X, Z)
    # Nariz: una cuña sobre la cara.
    hb = [("Head", 1.0)]
    top = b._vert(Vector((0, 1.704, 0.076)), hb)
    bl = b._vert(Vector((0.016, 1.652, 0.079)), hb)
    br = b._vert(Vector((-0.016, 1.652, 0.079)), hb)
    tip = b._vert(Vector((0, 1.658, 0.101)), hb)
    nuv = (0.6875, 1.0 - 0.9375)
    for tri, d in (((top, tip, bl), (1, -0.6, 0)), ((top, br, tip), (-1, -0.6, 0)), ((bl, tip, br), (0, -0.3, -1))):
        b.face([(v, nuv) for v in tri], "piel", direction=Vector(d))
    # Short: la cadera (caja) y una pierna ancha de cada lado, abierta abajo.
    b.tube("cadera", [
        ring((0, 1.0, -0.03), 0.19, 0.128, [("pelvis", 1.0)], "short", 0.55),
        ring((0, 0.86, -0.03), 0.2, 0.132, [("pelvis", 1.0)], "short", 0.55),
    ], 8, X, Z)
    for side in (1, -1):
        s = "_l" if side > 0 else "_r"
        lx = 0.114 * side
        thigh, calf, foot, ball = "thigh" + s, "calf" + s, "foot" + s, "ball" + s
        upper, lower, hand = "upperarm" + s, "lowerarm" + s, "hand" + s
        clav = "clavicle" + s
        b.tube("short" + s, [
            ring((lx * 0.95, 0.93, -0.035), 0.098, 0.112, [("pelvis", 0.5), (thigh, 0.5)], "short"),
            ring((lx * 1.05, 0.8, -0.035), 0.106, 0.118, [(thigh, 1.0)], "short"),
            ring((lx * 1.15, 0.68, -0.035), 0.115, 0.125, [(thigh, 1.0)], "ribete_short"),
            ring((lx * 1.2, 0.645, -0.035), 0.12, 0.13, [(thigh, 1.0)], "ribete_short"),
        ], 6, X, Z, cap_start=False)
        # Muslo al aire y rodilla.
        b.tube("muslo" + s, [
            ring((lx, 0.69, -0.035), 0.064, 0.066, [(thigh, 1.0)], "piel"),
            ring((lx, 0.545, -0.03), 0.054, 0.056, [(thigh, 0.5), (calf, 0.5)], "piel"),
            ring((lx, 0.5, -0.032), 0.054, 0.056, [(calf, 1.0)], "piel"),
        ], 6, X, Z, region="piel", cap_start=False, cap_end=False)
        # Medias hasta abajo de la rodilla (con la pantorrilla marcada).
        b.tube("media" + s, [
            ring((lx, 0.515, -0.034), 0.058, 0.06, [(calf, 1.0)], "medias"),
            ring((lx, 0.4, -0.05), 0.06, 0.066, [(calf, 1.0)], "medias"),
            ring((lx, 0.24, -0.06), 0.044, 0.048, [(calf, 1.0)], "medias"),
            ring((lx, 0.12, -0.07), 0.038, 0.042, [(calf, 0.5), (foot, 0.5)], "medias"),
        ], 6, X, Z, cap_start=False, cap_end=False)
        # Botín: del talón a la punta, en caja (u: 90° arriba, 270° la suela).
        b.tube("botin" + s, [
            ring((lx, 0.06, -0.115), 0.044, 0.06, [(foot, 1.0)], "botines"),
            ring((lx, 0.07, -0.025), 0.052, 0.07, [(foot, 1.0)], "botines"),
            ring((lx, 0.05, 0.08), 0.052, 0.05, [(foot, 0.5), (ball, 0.5)], "botines"),
            ring((lx, 0.035, 0.165), 0.038, 0.035, [(ball, 1.0)], "botines"),
        ], 6, X, Y)
        # Manga corta: costura del hombro, un pliegue y el puño abierto.
        b.tube("manga" + s, [
            ring((0.15 * side, 1.455, -0.06), 0.09, 0.085, [(clav, 1.0)], "manga"),
            ring((0.235 * side, 1.455, -0.062), 0.088, 0.084, [(clav, 0.5), (upper, 0.5)], "manga"),
            ring((0.3 * side, 1.453, -0.063), 0.079, 0.077, [(upper, 1.0)], "manga"),
            ring((0.37 * side, 1.452, -0.064), 0.08, 0.078, [(upper, 1.0)], "manga"),
            ring((0.43 * side, 1.45, -0.066), 0.087, 0.083, [(upper, 1.0)], "ribete_camiseta"),
            ring((0.455 * side, 1.45, -0.066), 0.09, 0.086, [(upper, 1.0)], "ribete_camiseta"),
        ], 6, Y, Z)
        # Brazo: bíceps, codo, antebrazo y muñeca.
        b.tube("brazo" + s, [
            ring((0.43 * side, 1.454, -0.068), 0.046, 0.046, [(upper, 1.0)], "piel"),
            ring((0.465 * side, 1.456, -0.072), 0.04, 0.042, [(upper, 0.5), (lower, 0.5)], "piel"),
            ring((0.56 * side, 1.456, -0.07), 0.043, 0.042, [(lower, 1.0)], "piel"),
            ring((0.69 * side, 1.456, -0.066), 0.03, 0.032, [(lower, 0.5), (hand, 0.5)], "piel"),
        ], 6, Y, Z, cap_start=False, cap_end=False)
        # Mano: un bloque (puño), como en el juego original.
        b.tube("mano" + s, [
            ring((0.685 * side, 1.454, -0.066), 0.036, 0.034, [(hand, 1.0)], "manos", 0.5),
            ring((0.735 * side, 1.448, -0.062), 0.05, 0.04, [(hand, 1.0)], "manos", 0.5),
            ring((0.79 * side, 1.444, -0.06), 0.042, 0.036, [(hand, 1.0)], "manos", 0.5),
        ], 4, Y, Z)
        # Oreja: una caja chata al costado de la cabeza.
        b.tube("oreja" + s, [
            ring((0.08 * side, 1.684, -0.025), 0.026, 0.015, [("Head", 1.0)], "piel", 0.6),
            ring((0.1 * side, 1.686, -0.028), 0.024, 0.013, [("Head", 1.0)], "piel", 0.6),
        ], 4, Y, Z, region="piel", cap_start=False)


# --- Pelo (bloques) ------------------------------------------------------------

def hair_cap(b, name, rings):
    hb = [("Head", 1.0)]
    b.tube(name, [ring((0, y, z), a, f, hb, "pelo", 0.8, back=bk, tilt=t) for y, z, a, f, bk, t in rings],
           8, X, Z, region="pelo", cap_start=False)


CAP_SHORT = [
    # y, z, ancho, adelante, atrás, inclinación (frente alto, nuca baja).
    (1.712, -0.016, 0.094, 0.108, 0.113, 0.55),
    (1.755, -0.017, 0.095, 0.1, 0.114, 0.25),
    (1.79, -0.019, 0.084, 0.086, 0.1, 0.0),
    (1.815, -0.022, 0.058, 0.056, 0.072, 0.0),
    (1.828, -0.022, 0.026, 0.022, 0.032, 0.0),
]


def build_hair(name):
    b = Builder()
    if name == "afro":
        hair_cap(b, "pelo_afro", [
            (1.712, -0.016, 0.1, 0.108, 0.118, 0.55),
            (1.77, -0.018, 0.128, 0.118, 0.138, 0.2),
            (1.835, -0.02, 0.125, 0.112, 0.132, 0.0),
            (1.88, -0.022, 0.09, 0.08, 0.095, 0.0),
            (1.897, -0.022, 0.045, 0.04, 0.05, 0.0),
        ])
        return b
    hair_cap(b, "pelo_" + name, CAP_SHORT)
    if name == "rastas":
        # Trenzas en bloque que caen por atrás y a los costados.
        y, z, a, f, bk, tilt = CAP_SHORT[1]
        ebr = (Z + Y * tilt).normalized()
        hb = [("Head", 1.0)]
        for i, deg in enumerate((185, 205, 225, 248, 270, 292, 315, 335, 355)):
            t = math.radians(deg)
            ct, st = math.cos(t), math.sin(t)
            p0 = Vector((0, y, z)) + X * math.copysign(abs(ct) ** 0.8, ct) * a \
                + ebr * math.copysign(abs(st) ** 0.8, st) * (f if st >= 0 else bk)
            out = Vector((p0.x, 0, p0.z - z)).normalized()
            tang = Vector((-out.z, 0, out.x))
            end_y = 1.6 if 215 <= deg <= 325 else 1.64
            p1 = Vector((p0.x, end_y, p0.z)) + out * 0.03
            pm = (p0 + p1) * 0.5 + out * 0.012
            b.tube("trenza%d" % i, [ring(p, 0.012, 0.012, hb, "pelo", 0.5) for p in (p0, pm, p1)],
                   4, tang, out, region="pelo", cap_start=False)
    return b


# --- Textura de detalle (pixel art) ------------------------------------------

def v_at(tb, value, comp):
    """Posición v (0..1 a lo largo del tubo) de una medida (y, z o |x|)."""
    def get(c):
        return abs(c.x) if comp == "ax" else getattr(c, comp)
    cs, vs = tb["cs"], tb["vs"]
    for i in range(len(cs) - 1):
        a, b = get(cs[i]), get(cs[i + 1])
        if a != b and (a - value) * (b - value) <= 0:
            return vs[i] + (vs[i + 1] - vs[i]) * (value - a) / (b - a)
    return vs[0] if abs(get(cs[0]) - value) < abs(get(cs[-1]) - value) else vs[-1]


class Atlas:
    def __init__(self, tubes):
        self.tubes = tubes
        self.img = np.zeros((TEX, TEX, 3), np.float32)
        self.img[..., 0] = 0.5

    def xy(self, name, deg, value, comp):
        """Píxel de un punto de un tubo: ángulo alrededor (0° = +a, 90° = +b)
        y medida a lo largo."""
        tb = self.tubes[name]
        n = tb["sides"]
        j = (deg / 360.0 * n - 0.5) % n
        u = 1.0 - j / n
        v = v_at(tb, value, comp)
        u0, v0, u1, v1 = UV[tb["region"]]
        x = min(max(int((u0 + u * (u1 - u0)) * TEX), int(u0 * TEX)), int(u1 * TEX) - 1)
        y = min(max(int((v0 + v * (v1 - v0)) * TEX), int(v0 * TEX)), int(v1 * TEX) - 1)
        return x, y

    def set(self, x, y, shade=None, paint=None):
        if 0 <= x < TEX and 0 <= y < TEX:
            if shade is not None:
                self.img[y, x, 0] = shade
            if paint is not None:
                self.img[y, x, 1] = 1.0
                self.img[y, x, 2] = paint

    def line(self, name, p0, p1, comp, **kw):
        for i in range(97):
            f = i / 96.0
            self.set(*self.xy(name, p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f, comp), **kw)

    def ring_line(self, name, value, comp, **kw):
        self.line(name, (0, value), (359.9, value), comp, **kw)

    def rect(self, name, deg0, deg1, val0, val1, comp, **kw):
        for i in range(61):
            val = val0 + (val1 - val0) * i / 60.0
            self.line(name, (deg0, val), (deg1, val), comp, **kw)

    def stamp(self, name, deg, value, comp, rows, keys):
        """Dibujo de píxeles centrado en un punto (rows: filas de letras)."""
        cx, cy = self.xy(name, deg, value, comp)
        h, w = len(rows), len(rows[0])
        for ry, row in enumerate(rows):
            for rx, ch in enumerate(row):
                if ch in keys:
                    self.set(cx - w // 2 + rx, cy - h // 2 + ry, **keys[ch])

    def save(self, path):
        arr = (np.clip(self.img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
        h, w, _ = arr.shape
        raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) \
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
        with open(path, "wb") as fh:
            fh.write(png)


def head_deg(tb, dx, y):
    """Ángulo alrededor de la cabeza de un punto de la cara a dx del centro."""
    cs, aa = tb["cs"], tb["as"]
    a = aa[-1]
    for i in range(len(cs) - 1):
        if cs[i].y <= y <= cs[i + 1].y:
            a = aa[i] + (aa[i + 1] - aa[i]) * (y - cs[i].y) / (cs[i + 1].y - cs[i].y)
    ang = math.degrees(math.acos(min(abs(dx) / a, 1.0) ** (1.0 / tb["sq"])))
    return ang if dx > 0 else 180.0 - ang


def paint(tubes):
    A = Atlas(tubes)
    T = "torso"
    # Camiseta: costuras, sombra del cuello, tapeta, pecho, pliegues.
    A.rect(T, 55, 125, 1.43, 1.3, "y", shade=0.55)
    A.line(T, (0, 1.5), (0, 1.0), "y", shade=0.42)
    A.line(T, (180, 1.5), (180, 1.0), "y", shade=0.42)
    A.ring_line(T, 1.518, "y", shade=0.4)
    A.line(T, (90, 1.525), (90, 1.47), "y", shade=0.42)
    for st, d in ((30, 1), (150, -1)):
        A.line(T, (st, 1.4), (st + d * 28, 1.25), "y", shade=0.43)
        A.line(T, (st - d * 5, 1.33), (st + d * 20, 1.21), "y", shade=0.44)
    for st, d in ((200, 1), (340, -1)):
        A.line(T, (st, 1.43), (st + d * 35, 1.29), "y", shade=0.43)
    A.line(T, (240, 1.4), (300, 1.4), "y", shade=0.45)
    A.ring_line(T, 1.07, "y", shade=0.45)
    A.line(T, (75, 1.06), (82, 1.0), "y", shade=0.44)
    A.line(T, (105, 1.06), (98, 1.0), "y", shade=0.44)
    A.ring_line(T, 1.012, "y", shade=0.44)
    # Short (cadera y piernas).
    H = "cadera"
    A.ring_line(H, 0.985, "y", shade=0.44)
    A.line(H, (90, 0.98), (90, 0.885), "y", shade=0.42)
    A.line(H, (90, 0.885), (70, 0.862), "y", shade=0.43)
    A.line(H, (90, 0.885), (110, 0.862), "y", shade=0.43)
    for s in ("l", "r"):
        outer = 0 if s == "l" else 180

        def inner(o):
            return 180 - o if s == "l" else o
        S = "short_" + s
        A.line(S, (outer, 0.93), (outer, 0.66), "y", shade=0.43)
        A.line(S, (inner(25), 0.9), (inner(55), 0.78), "y", shade=0.42)
        A.line(S, (inner(10), 0.86), (inner(40), 0.72), "y", shade=0.43)
        A.line(S, (90, 0.8), (90, 0.69), "y", shade=0.46)
        A.ring_line(S, 0.672, "y", shade=0.44)
        # Manga: costura del hombro, pliegues de la axila, arriba del puño.
        M = "manga_" + s
        A.rect(M, 160, 200, 0.26, 0.42, "ax", shade=0.46)
        A.ring_line(M, 0.235, "ax", shade=0.44)
        A.line(M, (150, 0.27), (205, 0.34), "ax", shade=0.42)
        A.line(M, (160, 0.34), (200, 0.4), "ax", shade=0.43)
        A.ring_line(M, 0.425, "ax", shade=0.45)
        # Medias: elástico y arrugas del tobillo.
        Md = "media_" + s
        for yy in np.arange(0.47, 0.17, -0.016):
            A.ring_line(Md, float(yy), "y", shade=0.47)
        A.ring_line(Md, 0.135, "y", shade=0.43)
        A.ring_line(Md, 0.125, "y", shade=0.45)
        # Botín: talón y puntera oscuros, suela, cordones.
        B = "botin_" + s
        A.rect(B, 0, 359.9, -0.115, -0.085, "z", shade=0.36)
        A.rect(B, 0, 359.9, 0.14, 0.17, "z", shade=0.42)
        A.rect(B, 215, 325, -0.13, 0.2, "z", paint=0.03)
        A.line(B, (205, -0.12), (205, 0.17), "z", paint=0.05)
        A.line(B, (335, -0.12), (335, 0.17), "z", paint=0.05)
        for zz in np.arange(-0.02, 0.075, 0.02):
            A.line(B, (72, float(zz)), (108, float(zz) + 0.01), "z", paint=0.9)
            A.line(B, (108, float(zz)), (72, float(zz) + 0.01), "z", paint=0.9)
        # Mano: nudillos y dedos (adelante = 90°).
        Hn = "mano_" + s
        A.line(Hn, (50, 0.755), (130, 0.755), "ax", shade=0.4)
        A.line(Hn, (90, 0.755), (90, 0.79), "ax", shade=0.42)
        # Brazo: pliegue del codo, muñeca.
        Bz = "brazo_" + s
        A.line(Bz, (65, 0.465), (115, 0.465), "ax", shade=0.42)
        A.line(Bz, (270, 0.45), (270, 0.48), "ax", shade=0.45)
        A.ring_line(Bz, 0.69, "ax", shade=0.46)
    # Cara (pixel art): ojos, cejas, sombra de la nariz, boca, mentón.
    C = "cabeza"
    tb = tubes[C]
    keys = {"D": {"paint": 0.03}, "W": {"paint": 0.85}, "b": {"paint": 0.04},
            "s": {"shade": 0.36}, "m": {"shade": 0.2}, "l": {"shade": 0.6}}
    for dx in (0.034, -0.034):
        A.stamp(C, head_deg(tb, dx, 1.70), 1.70, "y", [".DDDDD.", "WWDDDWW", ".WWDWW."], keys)
        A.stamp(C, head_deg(tb, dx, 1.727), 1.727, "y", ["bbbbbbb"], keys)
    A.stamp(C, 90, 1.649, "y", ["sssss"], keys)
    A.stamp(C, 90, 1.624, "y", ["mmmmmmm", ".lllll."], keys)
    A.line(C, (50, 1.59), (130, 1.59), "y", shade=0.45)
    A.line(C, (60, 1.64), (60, 1.6), "y", shade=0.46)
    A.line(C, (120, 1.64), (120, 1.6), "y", shade=0.46)
    # Pelo: mechones (franjas a lo largo, sin repetir).
    u0, v0, u1, v1 = UV["pelo"]
    rng = np.random.default_rng(7)
    for x in range(int(u0 * TEX), int(u1 * TEX)):
        base = 0.4 + 0.16 * rng.random()
        if x % 3 == 0:
            base = 0.34
        for y in range(int(v0 * TEX), int(v1 * TEX)):
            A.img[y, x, 0] = base + 0.04 * (rng.random() - 0.5) * (y % 4 == 0)
    return A


# --- Materiales (para verlo en Blender igual que en el juego) -----------------

def _sock(sockets, name, kind):
    return next(s for s in sockets if s.name == name and s.type == kind)


def make_material(name, col, img):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*col, 1.0)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(tex.outputs["Color"], sep.inputs["Color"])
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 2.0
    links.new(sep.outputs["Red"], mul.inputs[0])
    shade = nodes.new("ShaderNodeCombineColor")
    paint_c = nodes.new("ShaderNodeCombineColor")
    for ch in ("Red", "Green", "Blue"):
        links.new(mul.outputs[0], shade.inputs[ch])
        links.new(sep.outputs["Blue"], paint_c.inputs[ch])
    m1 = nodes.new("ShaderNodeMix")
    m1.data_type = "RGBA"
    m1.blend_type = "MULTIPLY"
    _sock(m1.inputs, "Factor", "VALUE").default_value = 1.0
    _sock(m1.inputs, "A", "RGBA").default_value = (*col, 1.0)
    links.new(shade.outputs["Color"], _sock(m1.inputs, "B", "RGBA"))
    m2 = nodes.new("ShaderNodeMix")
    m2.data_type = "RGBA"
    links.new(sep.outputs["Green"], _sock(m2.inputs, "Factor", "VALUE"))
    links.new(_sock(m1.outputs, "Result", "RGBA"), _sock(m2.inputs, "A", "RGBA"))
    links.new(paint_c.outputs["Color"], _sock(m2.inputs, "B", "RGBA"))
    links.new(_sock(m2.outputs, "Result", "RGBA"), bsdf.inputs["Base Color"])
    return mat


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SKELETON_SRC)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.name = "Armature"
    for o in list(bpy.data.objects):
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    arm.data.display_type = "STICK"
    arm.show_in_front = True

    body = Builder()
    build_body(body)
    hairs = {n: build_hair(n) for n in HAIR_NAMES}
    paint(body.tubes).save(OUT_TEX)
    img = bpy.data.images.load(OUT_TEX)
    img.colorspace_settings.name = "Non-Color"
    materials = [make_material(n, c, img) for n, c in ZONES.items()]

    obj = body.to_object(BODY_NAME, arm, materials)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("WE_Definitivo: %d vértices, %d triángulos" % (len(obj.data.vertices), tris))
    for n, hb in hairs.items():
        ho = hb.to_object("WE_Pelo_" + n, arm, materials)
        # En Blender se ve uno solo (los otros, ocultos); se exportan todos.
        ho.hide_viewport = ho.hide_render = n != "corto"

    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=False, use_visible=False,
        export_yup=True, export_animations=False, export_skins=True,
        export_materials="EXPORT", export_image_format="NONE", export_apply=False)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    print("Exportado:", OUT_GLB, OUT_TEX)


if __name__ == "__main__":
    main()
