# The Second Shadow - animación propia del abrazo del final oculto.
# Uso: en Blender, importa SKM_Player02 (Mono) y SKM_Six con el addon PSK/PSA,
# abre este archivo en el editor de texto y pulsa «Run Script». Crea las
# acciones ANIM_SecretHug_Mono y ANIM_SecretHug_Six sobre un origen común y
# las exporta como FBX junto al .blend. Ajusta POSES si algún hueso gira al revés.
import bpy, math, os

MONO = 'SKM_Player02'      # nombre del armature de Mono tras importar
SIX = 'SKM_Six'            # nombre del armature de Six tras importar
FPS = 30
# Tiempos (segundos): llegar, abrazar, sostener y aflojar al final.
REACH, HUG, HOLD, END = 1.2, 2.4, 6.4, 7.6
DISTANCE = 30.0            # separación en cm; debe coincidir con N.customHug.distance del mod
SCALE = 0.01               # el import PSK suele usar 1 cm = 0.01 m

# Partes del cuerpo -> palabras que suelen aparecer en el nombre del hueso.
PARTS = {
    'spine': ['spine_02', 'spine2', 'spine_01', 'spine1', 'spine'],
    'neck': ['neck'],
    'head': ['head'],
    'clav_l': ['clavicle_l', 'l_clavicle', 'leftshoulder', 'shoulder_l'],
    'clav_r': ['clavicle_r', 'r_clavicle', 'rightshoulder', 'shoulder_r'],
    'arm_l': ['upperarm_l', 'l_upperarm', 'leftarm', 'arm_l'],
    'arm_r': ['upperarm_r', 'r_upperarm', 'rightarm', 'arm_r'],
    'fore_l': ['lowerarm_l', 'forearm_l', 'l_forearm', 'leftforearm'],
    'fore_r': ['lowerarm_r', 'forearm_r', 'r_forearm', 'rightforearm'],
    'thigh_l': ['thigh_l', 'l_thigh', 'leftupleg'],
    'thigh_r': ['thigh_r', 'r_thigh', 'rightupleg'],
    'calf_l': ['calf_l', 'l_calf', 'leftleg'],
    'calf_r': ['calf_r', 'r_calf', 'rightleg'],
}

# Rotaciones (grados, X/Y/Z locales del hueso) en el momento del abrazo.
# Mono está de rodillas y agotado; Six le rodea el cuello con los brazos.
POSES = {
    MONO: {
        'spine': (18, 0, 0), 'neck': (10, 0, 0), 'head': (12, 0, -10),
        'clav_l': (0, 0, 12), 'clav_r': (0, 0, -12),
        'arm_l': (-20, 0, 55), 'arm_r': (-20, 0, -55),
        'fore_l': (0, 0, 70), 'fore_r': (0, 0, -70),
        'thigh_l': (-95, 0, 0), 'thigh_r': (-95, 0, 0),
        'calf_l': (120, 0, 0), 'calf_r': (120, 0, 0),
    },
    SIX: {
        'spine': (14, 0, 0), 'neck': (8, 0, 0), 'head': (10, 0, 14),
        'clav_l': (0, 0, 18), 'clav_r': (0, 0, -18),
        'arm_l': (-55, 0, 40), 'arm_r': (-55, 0, -40),
        'fore_l': (0, 0, 95), 'fore_r': (0, 0, -95),
        'thigh_l': (-70, 0, 0), 'thigh_r': (-70, 0, 0),
        'calf_l': (90, 0, 0), 'calf_r': (90, 0, 0),
    },
}


def find_bone(arm, words):
    names = [b.name for b in arm.pose.bones]
    for word in words:
        for name in names:
            if word in name.lower():
                return arm.pose.bones[name]
    return None


def key_pose(arm, pose, frame, amount, sway=0.0):
    for part, angles in pose.items():
        bone = find_bone(arm, PARTS[part])
        if not bone:
            continue
        bone.rotation_mode = 'XYZ'
        x, y, z = (math.radians(a * amount) for a in angles)
        if part in ('spine', 'head'):
            z += math.radians(sway)
        bone.rotation_euler = (x, y, z)
        bone.keyframe_insert('rotation_euler', frame=frame)


def build(arm, name, pose):
    arm.animation_data_create()
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    for bone in arm.pose.bones:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler = (0, 0, 0)
    f = lambda s: int(round(s * FPS)) + 1
    key_pose(arm, pose, f(0), 0.15)
    key_pose(arm, pose, f(REACH), 0.6)
    key_pose(arm, pose, f(HUG), 1.0)
    # Respiración y balanceo suave mientras se sostienen.
    t = HUG
    while t < HOLD:
        t = min(HOLD, t + 0.8)
        key_pose(arm, pose, f(t), 0.97 + 0.03 * math.sin(t * 2.2), sway=2.0 * math.sin(t * 1.3))
    key_pose(arm, pose, f(END), 0.85)
    missing = [p for p in pose if not find_bone(arm, PARTS[p])]
    print(name, 'sin huesos para:', missing or 'ninguno')
    print(name, 'huesos del esqueleto:', [b.name for b in arm.pose.bones][:60])
    return action


def export(arm, action, path):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for child in arm.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = arm
    arm.animation_data.action = action
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, add_leaf_bones=False,
                             bake_anim=True, bake_anim_use_all_actions=False,
                             bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0.0,
                             object_types={'ARMATURE', 'MESH'})


scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 1, int(round(END * FPS)) + 1
mono, six = bpy.data.objects[MONO], bpy.data.objects[SIX]
# Vista previa en Blender: Six enfrente de Mono. En el juego el mod la coloca igual.
mono.location = (0, 0, 0)
mono.rotation_euler = (0, 0, 0)
six.location = (0, DISTANCE * SCALE, 0)
six.rotation_euler = (0, 0, math.pi)
mono_action = build(mono, 'ANIM_SecretHug_Mono', POSES[MONO])
six_action = build(six, 'ANIM_SecretHug_Six', POSES[SIX])
folder = os.path.dirname(bpy.data.filepath) or os.path.expanduser('~')
export(mono, mono_action, os.path.join(folder, 'ANIM_SecretHug_Mono.fbx'))
export(six, six_action, os.path.join(folder, 'ANIM_SecretHug_Six.fbx'))
print('Listo: FBX exportados en', folder)
