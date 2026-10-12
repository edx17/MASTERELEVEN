"""MASTER ELEVEN - jugador base estilo Winning Eleven 2002 (PS1).

Ejecutar en Blender (Scripting > Run Script). Probado en Blender 4.2.

Genera un jugador modular de menos de 300 triángulos:
  - Piezas separadas, sin skinning: Torso, Head, UpperArm/LowerArm/Hand,
    Thigh/Calf/Boot (.L y .R). En la animación sólo rotan y se atraviesan.
  - Origen de cada pieza en su articulación (cadera, hombro, codo, muñeca,
    rodilla, tobillo, cuello) y jerarquía FK:
        Player (Empty, en el piso)
        └─ Torso (origen: pelvis)
           ├─ Head (cuello)
           ├─ UpperArm.L/R (hombro) ─ LowerArm (codo) ─ Hand (muñeca)
           └─ Thigh.L/R (cadera) ─ Calf (rodilla) ─ Boot (tobillo)
  - Cabeza, manos y botines exagerados para leerse con cámara lejana.
  - Shade Flat, un solo material con un atlas de 256x256 (filtrado Closest,
    pixel art) y Smart UV Project de todas las piezas juntas: comparten el
    espacio UV del atlas sin pisarse.

Convención de Blender: Z arriba, el jugador mira hacia -Y (vista Front,
numpad 1) y su izquierda es +X (.L). Unidades: metros (~1,70 m de alto).
Para Godot: exportar glTF 2.0 (+Y Up) con "Apply Modifiers" y sin "Skinning".
"""

import math

import bmesh
import bpy

# --- Parámetros ---------------------------------------------------------------

ATLAS_SIZE = 256          # 128 o 256
LIMB_SIDES = 6            # lados de brazos y piernas (6 a 8)
HEAD_SIDES = 8            # lados de la cabeza
MAX_TRIS = 300

# Alturas de las articulaciones (m, desde el piso).
HIP_Z = 0.88              # cadera (origen del torso y de los muslos)
NECK_Z = 1.40             # cuello (origen de la cabeza)
SHOULDER_Z = 1.33
SHOULDER_X = 0.25
HIP_X = 0.10
THIGH_LEN = 0.41
CALF_LEN = 0.37           # tobillo a 0,10 m: el botín apoya en el piso
UPPER_ARM_LEN = 0.28
LOWER_ARM_LEN = 0.25


# --- Escena -------------------------------------------------------------------

def clear_scene() -> None:
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)


def link(obj: bpy.types.Object) -> bpy.types.Object:
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Primitivas (bmesh, con el origen ya en la articulación) ------------------

def lathe(name: str, sides: int, rings: list) -> bpy.types.Object:
    """Prisma de `sides` lados con anillos [(z, radio_x, radio_y)] relativos
    al origen. Una cara plana mira al frente (-Y). Tapas en las puntas."""
    bm = bmesh.new()
    loops = []
    for z, rx, ry in rings:
        ring = []
        for i in range(sides):
            a = 2.0 * math.pi * i / sides + math.pi / sides - math.pi / 2.0
            ring.append(bm.verts.new((math.cos(a) * rx, math.sin(a) * ry, z)))
        loops.append(ring)
    for r0, r1 in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(loops[0])
    bm.faces.new(list(reversed(loops[-1])))
    return _finish(name, bm)


def tapered_box(name: str, bottom: tuple, top: tuple) -> bpy.types.Object:
    """Caja de 8 vértices: cada tapa es (z, ancho, profundidad, centro_y)."""
    bm = bmesh.new()
    rects = []
    for z, w, d, cy in (bottom, top):
        hw, hd = w / 2.0, d / 2.0
        rects.append([bm.verts.new(v) for v in (
            (-hw, cy - hd, z), (hw, cy - hd, z), (hw, cy + hd, z), (-hw, cy + hd, z))])
    b, t = rects
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((b[i], b[j], t[j], t[i]))
    bm.faces.new(list(reversed(b)))
    bm.faces.new(t)
    return _finish(name, bm)


def _finish(name: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False  # Shade Flat
    return link(bpy.data.objects.new(name, mesh))


def limb(name: str, length: float, r_top: float, r_bottom: float, sides: int = LIMB_SIDES) -> bpy.types.Object:
    """Brazo o pierna colgando hacia -Z desde la articulación (origen)."""
    return lathe(name, sides, [(0.0, r_top, r_top * 0.9), (-length, r_bottom, r_bottom * 0.9)])


def attach(child: bpy.types.Object, parent: bpy.types.Object, local: tuple) -> bpy.types.Object:
    """Emparenta sin inversa: `local` es la articulación en el espacio del padre."""
    child.parent = parent
    child.location = local
    return child


# --- Jugador ------------------------------------------------------------------

def build_player() -> bpy.types.Object:
    root = link(bpy.data.objects.new("Player", None))
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.3

    # Torso: origen en la pelvis; más ancho en los hombros (camiseta) que en
    # la cintura (short).
    torso = tapered_box("Torso", (-0.06, 0.30, 0.18, 0.0), (NECK_Z - HIP_Z, 0.46, 0.22, 0.0))
    attach(torso, root, (0.0, 0.0, HIP_Z))

    # Cabeza grande: mentón angosto, ancha en los pómulos, frente un poco menor.
    head = lathe("Head", HEAD_SIDES, [
        (0.00, 0.075, 0.075),
        (0.15, 0.135, 0.13),
        (0.30, 0.11, 0.11),
    ])
    attach(head, torso, (0.0, 0.0, NECK_Z - HIP_Z))

    for side, sx in (("L", 1.0), ("R", -1.0)):
        upper = limb(f"UpperArm.{side}", UPPER_ARM_LEN, 0.058, 0.046)
        attach(upper, torso, (sx * SHOULDER_X, 0.0, SHOULDER_Z - HIP_Z))
        lower = limb(f"LowerArm.{side}", LOWER_ARM_LEN, 0.046, 0.038)
        attach(lower, upper, (0.0, 0.0, -UPPER_ARM_LEN))
        # Mano exagerada (casi del tamaño del antebrazo de ancho).
        hand = tapered_box(f"Hand.{side}", (-0.13, 0.10, 0.065, 0.0), (0.0, 0.075, 0.055, 0.0))
        attach(hand, lower, (0.0, 0.0, -LOWER_ARM_LEN))

        thigh = limb(f"Thigh.{side}", THIGH_LEN, 0.088, 0.066)
        attach(thigh, torso, (sx * HIP_X, 0.0, 0.0))
        calf = limb(f"Calf.{side}", CALF_LEN, 0.064, 0.044)
        attach(calf, thigh, (0.0, 0.0, -THIGH_LEN))
        # Botín grande: la suela apoya en el piso y la punta va hacia -Y.
        ankle_z = HIP_Z - THIGH_LEN - CALF_LEN
        boot = tapered_box(f"Boot.{side}", (-ankle_z, 0.14, 0.32, -0.07), (0.035, 0.11, 0.15, -0.01))
        attach(boot, calf, (0.0, 0.0, -CALF_LEN))
    return root


# --- Material, UV y verificación ------------------------------------------------

def atlas_material() -> bpy.types.Material:
    img = bpy.data.images.new(f"WE_Atlas_{ATLAS_SIZE}", ATLAS_SIZE, ATLAS_SIZE)
    img.generated_type = "UV_GRID"  # grilla de prueba; reemplazar por el pixel art
    mat = bpy.data.materials.new("WE_Atlas")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"  # sin filtrado: píxeles nítidos estilo PS1
    tex.location = (-350, 300)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def meshes() -> list:
    return [o for o in bpy.data.objects if o.type == "MESH"]


def smart_uv_all() -> None:
    """Smart UV Project de todas las piezas a la vez (edición multiobjeto):
    las islas se reparten en un único espacio 0-1, el del atlas."""
    parts = meshes()
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=1.5 / ATLAS_SIZE)
    bpy.ops.object.mode_set(mode="OBJECT")


def triangle_count() -> int:
    return sum(len(p.vertices) - 2 for o in meshes() for p in o.data.polygons)


def main() -> None:
    clear_scene()
    build_player()
    mat = atlas_material()
    for o in meshes():
        o.data.materials.append(mat)
    smart_uv_all()
    tris = triangle_count()
    print(f"MASTER ELEVEN: {len(meshes())} piezas, {tris} triángulos (máx. {MAX_TRIS})")
    assert tris <= MAX_TRIS, f"El jugador tiene {tris} triángulos (máximo {MAX_TRIS})"


if __name__ == "__main__":
    main()
