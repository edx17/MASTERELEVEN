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
#   2. Arma el cuerpo con "tubos" de pocas caras (anillos), caras planas.
#   3. Pesos rígidos: cada anillo pegado a un hueso (codos, rodillas, cintura
#      y cuello mitad y mitad, para que no se abran al doblar).
#   4. Una ZONA por material. El juego pinta cada zona con los colores del
#      club (los colores de acá son sólo para verlo en Blender):
#        camiseta, manga, ribete_camiseta, short, ribete_short, medias,
#        piel, botines, pelo, manos
#      Para dibujar pelo después: en modo edición seleccioná caras de la
#      cabeza y asignales el material "pelo".
#   5. Exporta assets/models/players/we_definitivo.glb (lo que carga el juego)
#      y guarda tools/blender/we_definitivo.blend (para seguir editándolo a
#      mano; la carpeta tiene .gdignore: Godot no lo importa).
#
# Si editás el .blend a mano, exportá con File > Export > glTF 2.0 (.glb):
# Include > Selected Objects (Armature + WE_Definitivo), Data > Mesh >
# Apply Modifiers, Data > Armature/Skinning activado, Animation desactivado.
#
# Coordenadas: las medidas de abajo están en metros y en ejes del juego
# (x: izquierda del jugador, y: arriba, z: adelante). En Blender eso es
# (x, -z, y): el jugador mira hacia -Y (vista frontal, tecla 1 del numpad).

import math
import os
import sys

import bpy  # (bpy antes que bmesh: así también corre con el módulo bpy de pip)
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
SKELETON_SRC = os.path.join(REPO, "assets", "models", "players", "player_body.gltf")
OUT_GLB = os.path.join(REPO, "assets", "models", "players", "we_definitivo.glb")
OUT_BLEND = os.path.join(HERE, "we_definitivo.blend")
MESH_NAME = "WE_Definitivo"

# Colores de muestra (Francia, como la referencia). El juego usa los del club.
ZONES = {
    "camiseta": (0.08, 0.16, 0.55),
    "manga": (0.08, 0.16, 0.55),
    "ribete_camiseta": (0.92, 0.92, 0.92),
    "short": (0.92, 0.92, 0.92),
    "ribete_short": (0.08, 0.16, 0.55),
    "medias": (0.62, 0.06, 0.08),
    "piel": (0.62, 0.42, 0.28),
    "botines": (0.95, 0.95, 0.95),
    "pelo": (0.05, 0.04, 0.03),
    "manos": (0.62, 0.42, 0.28),
}

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))


def to_blender(v):
    """Ejes del juego (y arriba, z adelante) a Blender (z arriba, -y adelante)."""
    return Vector((v.x, -v.z, v.y))


def ring(c, a, b, bones, mat, sq=0.6):
    """Un anillo de un tubo.
    c: centro (ejes del juego); a, b: medio ancho en los dos ejes del anillo;
    bones: [(hueso, peso), ...]; mat: zona (material) de la franja que empieza
    en este anillo; sq: qué tan "cuadrado" es (1 = elipse, 0.5 = caja con las
    esquinas cortadas)."""
    return {"c": Vector(c), "a": a, "b": b, "bones": bones, "mat": mat, "sq": sq}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.mats = list(ZONES.keys())
        self.groups = []

    def _group(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def _vert(self, p, bones):
        v = self.bm.verts.new(to_blender(p))
        for bone, w in bones:
            v[self.deform][self._group(bone)] = w
        return v

    def tube(self, rings, sides, ea, eb, cap_start=True, cap_end=True):
        """Tubo de `sides` caras entre anillos. ea / eb: ejes del anillo
        (ejes del juego) para los radios a / b."""
        ea = Vector(ea).normalized()
        eb = Vector(eb).normalized()
        loops = []
        for r in rings:
            loop = []
            for k in range(sides):
                t = 2 * math.pi * (k + 0.5) / sides
                ct, st = math.cos(t), math.sin(t)
                # Superelipse: con sq < 1 las caras de adelante, atrás y los
                # costados quedan planas (más "caja" que cilindro).
                px = math.copysign(abs(ct) ** r["sq"], ct) * r["a"]
                py = math.copysign(abs(st) ** r["sq"], st) * r["b"]
                loop.append(self._vert(r["c"] + ea * px + eb * py, r["bones"]))
            loops.append(loop)
        for i in range(len(rings) - 1):
            mat = self.mats.index(rings[i]["mat"])
            core = to_blender((rings[i]["c"] + rings[i + 1]["c"]) * 0.5)
            for k in range(sides):
                k2 = (k + 1) % sides
                f = self.bm.faces.new((loops[i][k], loops[i][k2], loops[i + 1][k2], loops[i + 1][k]))
                f.material_index = mat
                self._outward(f, f.calc_center_median() - core)
        # Tapas: miran hacia afuera del tubo (el juego no dibuja la cara de
        # atrás de los polígonos).
        along = to_blender(rings[-1]["c"]) - to_blender(rings[0]["c"])
        if cap_start:
            f = self.bm.faces.new(loops[0])
            f.material_index = self.mats.index(rings[0]["mat"])
            self._outward(f, -along)
        if cap_end:
            f = self.bm.faces.new(loops[-1])
            f.material_index = self.mats.index(rings[-1]["mat"])
            self._outward(f, along)

    @staticmethod
    def _outward(face, out):
        face.normal_update()
        if face.normal.dot(out) < 0.0:
            face.normal_flip()


def build_body(b):
    # --- Camiseta (torso): ancha y suelta, hombros rectos, cae por encima
    # del short (como en el WE2002).
    torso = [
        ring((0, 1.555, -0.035), 0.062, 0.058, [("neck_01", 0.5), ("spine_03", 0.5)], "ribete_camiseta", 0.8),
        ring((0, 1.525, -0.04), 0.078, 0.07, [("spine_03", 1.0)], "camiseta", 0.8),
        ring((0, 1.50, -0.045), 0.205, 0.12, [("spine_03", 1.0)], "camiseta", 0.55),
        ring((0, 1.40, -0.035), 0.215, 0.145, [("spine_03", 0.6), ("spine_02", 0.4)], "camiseta", 0.55),
        ring((0, 1.26, -0.03), 0.198, 0.138, [("spine_02", 1.0)], "camiseta", 0.55),
        ring((0, 1.12, -0.03), 0.19, 0.13, [("spine_01", 1.0)], "camiseta", 0.55),
        ring((0, 1.005, -0.03), 0.2, 0.134, [("pelvis", 1.0)], "ribete_camiseta", 0.55),
        ring((0, 0.975, -0.03), 0.202, 0.136, [("pelvis", 1.0)], "ribete_camiseta", 0.55),
    ]
    b.tube(torso, 8, X, Z, cap_start=False)
    # --- Cuello y cabeza (pelado y sin cara por ahora: todo piel).
    b.tube([
        ring((0, 1.5, -0.035), 0.052, 0.05, [("spine_03", 0.5), ("neck_01", 0.5)], "piel", 0.8),
        ring((0, 1.6, -0.03), 0.05, 0.05, [("neck_01", 0.5), ("Head", 0.5)], "piel", 0.8),
    ], 6, X, Z, cap_start=False, cap_end=False)
    b.tube([
        ring((0, 1.585, 0.005), 0.05, 0.06, [("Head", 1.0)], "piel", 0.8),
        ring((0, 1.625, 0.0), 0.078, 0.092, [("Head", 1.0)], "piel", 0.8),
        ring((0, 1.70, -0.012), 0.09, 0.105, [("Head", 1.0)], "piel", 0.8),
        ring((0, 1.77, -0.018), 0.08, 0.095, [("Head", 1.0)], "piel", 0.8),
        ring((0, 1.81, -0.022), 0.045, 0.055, [("Head", 1.0)], "piel", 0.8),
    ], 8, X, Z)
    # --- Short: la cadera (caja) y una pierna ancha de cada lado.
    b.tube([
        ring((0, 1.0, -0.03), 0.19, 0.128, [("pelvis", 1.0)], "short", 0.55),
        ring((0, 0.86, -0.03), 0.2, 0.132, [("pelvis", 1.0)], "short", 0.55),
    ], 8, X, Z)
    for side in (1, -1):
        s = "_l" if side > 0 else "_r"
        lx = 0.114 * side
        thigh, calf, foot, ball = "thigh" + s, "calf" + s, "foot" + s, "ball" + s
        upper, lower, hand = "upperarm" + s, "lowerarm" + s, "hand" + s
        clav = "clavicle" + s
        b.tube([
            ring((lx * 0.95, 0.93, -0.035), 0.098, 0.112, [("pelvis", 0.5), (thigh, 0.5)], "short"),
            ring((lx * 1.05, 0.8, -0.035), 0.104, 0.116, [(thigh, 1.0)], "short"),
            ring((lx * 1.1, 0.665, -0.035), 0.104, 0.112, [(thigh, 1.0)], "ribete_short"),
            ring((lx * 1.1, 0.64, -0.035), 0.104, 0.112, [(thigh, 1.0)], "ribete_short"),
        ], 6, X, Z, cap_start=False)
        # Muslo al aire y rodilla.
        b.tube([
            ring((lx, 0.68, -0.035), 0.064, 0.066, [(thigh, 1.0)], "piel"),
            ring((lx, 0.545, -0.03), 0.054, 0.056, [(thigh, 0.5), (calf, 0.5)], "piel"),
            ring((lx, 0.5, -0.032), 0.054, 0.056, [(calf, 1.0)], "piel"),
        ], 6, X, Z, cap_start=False, cap_end=False)
        # Medias hasta abajo de la rodilla (con la pantorrilla marcada).
        b.tube([
            ring((lx, 0.515, -0.034), 0.058, 0.06, [(calf, 1.0)], "medias"),
            ring((lx, 0.4, -0.05), 0.06, 0.066, [(calf, 1.0)], "medias"),
            ring((lx, 0.24, -0.06), 0.044, 0.048, [(calf, 1.0)], "medias"),
            ring((lx, 0.12, -0.07), 0.038, 0.042, [(calf, 0.5), (foot, 0.5)], "medias"),
        ], 6, X, Z, cap_start=False, cap_end=False)
        # Botín: del talón a la punta, en caja.
        b.tube([
            ring((lx, 0.06, -0.115), 0.044, 0.06, [(foot, 1.0)], "botines"),
            ring((lx, 0.07, -0.025), 0.052, 0.07, [(foot, 1.0)], "botines"),
            ring((lx, 0.05, 0.08), 0.052, 0.05, [(foot, 0.5), (ball, 0.5)], "botines"),
            ring((lx, 0.035, 0.165), 0.038, 0.035, [(ball, 1.0)], "botines"),
        ], 6, X, Y)
        # Manga corta, un poco acampanada.
        b.tube([
            ring((0.15 * side, 1.455, -0.06), 0.09, 0.085, [(clav, 1.0)], "manga"),
            ring((0.235 * side, 1.455, -0.062), 0.088, 0.084, [(clav, 0.5), (upper, 0.5)], "manga"),
            ring((0.35 * side, 1.452, -0.064), 0.076, 0.074, [(upper, 1.0)], "manga"),
            ring((0.435 * side, 1.45, -0.066), 0.08, 0.077, [(upper, 1.0)], "ribete_camiseta"),
            ring((0.455 * side, 1.45, -0.066), 0.08, 0.077, [(upper, 1.0)], "ribete_camiseta"),
        ], 6, Y, Z, cap_start=True)
        # Brazo: bíceps, codo, antebrazo y muñeca.
        b.tube([
            ring((0.43 * side, 1.454, -0.068), 0.046, 0.046, [(upper, 1.0)], "piel"),
            ring((0.465 * side, 1.456, -0.072), 0.04, 0.042, [(upper, 0.5), (lower, 0.5)], "piel"),
            ring((0.56 * side, 1.456, -0.07), 0.043, 0.042, [(lower, 1.0)], "piel"),
            ring((0.69 * side, 1.456, -0.066), 0.03, 0.032, [(lower, 0.5), (hand, 0.5)], "piel"),
        ], 6, Y, Z, cap_start=False, cap_end=False)
        # Mano: un bloque (puño), como en el juego original.
        b.tube([
            ring((0.685 * side, 1.454, -0.066), 0.036, 0.034, [(hand, 1.0)], "manos", 0.5),
            ring((0.735 * side, 1.448, -0.062), 0.05, 0.04, [(hand, 1.0)], "manos", 0.5),
            ring((0.79 * side, 1.444, -0.06), 0.042, 0.036, [(hand, 1.0)], "manos", 0.5),
        ], 4, Y, Z)


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

    b = Builder()
    build_body(b)
    mesh = bpy.data.meshes.new(MESH_NAME)
    b.bm.to_mesh(mesh)
    b.bm.free()
    obj = bpy.data.objects.new(MESH_NAME, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for name in b.groups:
        obj.vertex_groups.new(name=name)
    for name, col in ZONES.items():
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*col, 1.0)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*col, 1.0)
            bsdf.inputs["Roughness"].default_value = 1.0
        mesh.materials.append(mat)
    # Caras planas (sin suavizado).
    for p in mesh.polygons:
        p.use_smooth = False
    mesh.validate()
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print("WE_Definitivo: %d vértices, %d triángulos, %d huesos" % (len(mesh.vertices), tris, len(b.groups)))

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True,
        export_animations=False, export_skins=True, export_materials="EXPORT",
        export_apply=False, export_texcoords=False)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    print("Exportado:", OUT_GLB)


if __name__ == "__main__":
    main()
