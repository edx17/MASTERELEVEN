# Fotos del Diseño Definitivo WE (para revisar el modelo sin abrir Blender):
# de frente, 3/4, costado y espalda en pose T, y una pose de carrera como la
# del WE2002 (rodilla adelante a 90°, codos a 90°) para ver cómo se dobla.
#
#   blender --background --python tools/blender/we_preview.py
#
# Guarda los PNG en tools/blender/preview/.

import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
BLEND = os.path.join(HERE, "we_definitivo.blend")
OUT = os.path.join(HERE, "preview")


def setup():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = False
    sc.render.resolution_x = 360
    sc.render.resolution_y = 640
    for name, energy, rot in (("sol", 3.0, (50, 0, -30)), ("relleno", 1.2, (60, 0, 160))):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        o = bpy.data.objects.new(name, light)
        sc.collection.objects.link(o)
        o.rotation_euler = Euler([math.radians(a) for a in rot])
    world = bpy.data.worlds.new("fondo")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.35, 0.36, 0.38, 1)
    bg.inputs[1].default_value = 0.9
    bpy.data.objects["Armature"].hide_render = True
    cam_data = bpy.data.cameras.new("camara")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("camara", cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def shoot(sc, cam, name, angle_deg):
    # El jugador mira hacia -Y; 0° = de frente, 90° = desde su derecha.
    a = math.radians(angle_deg)
    cam.location = Vector((math.sin(a) * 5, -math.cos(a) * 5, 0.95))
    cam.rotation_euler = Euler((math.radians(90), 0, a))
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def rotate(arm, bone, axis, deg):
    """Gira un hueso alrededor de su base con un eje del mundo."""
    pb = arm.pose.bones[bone]
    m = arm.matrix_world @ pb.matrix
    loc = m.to_translation()
    r = Matrix.Rotation(math.radians(deg), 4, axis)
    pb.matrix = arm.matrix_world.inverted() @ (Matrix.Translation(loc) @ r @ Matrix.Translation(-loc) @ m)
    bpy.context.view_layer.update()


def run_pose(arm):
    x, y = Vector((1, 0, 0)), Vector((0, 1, 0))
    rotate(arm, "spine_02", x, 10)
    rotate(arm, "upperarm_l", y, 75)
    rotate(arm, "upperarm_r", y, -75)
    rotate(arm, "upperarm_r", x, -45)
    rotate(arm, "upperarm_l", x, 40)
    rotate(arm, "lowerarm_r", x, -85)
    rotate(arm, "lowerarm_l", x, -80)
    rotate(arm, "thigh_l", x, -90)
    rotate(arm, "calf_l", x, 95)
    rotate(arm, "thigh_r", x, 25)
    rotate(arm, "calf_r", x, 40)


def main():
    os.makedirs(OUT, exist_ok=True)
    sc, cam = setup()
    for name, angle in (("frente", 0), ("tres_cuartos", 35), ("costado", 90), ("espalda", 180)):
        shoot(sc, cam, name, angle)
    run_pose(bpy.data.objects["Armature"])
    shoot(sc, cam, "carrera_tres_cuartos", 35)
    shoot(sc, cam, "carrera_costado", -70)


if __name__ == "__main__":
    main()
