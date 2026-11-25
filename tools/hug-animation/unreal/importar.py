# The Second Shadow - importa los FBX del final oculto en el proyecto Helios (UE 4.24).
# Se ejecuta sin abrir el editor:
#   UE4Editor-Cmd.exe Helios.uproject -run=pythonscript -script="<ruta>\importar.py"
# Lee importar.json y los FBX de la carpeta fbx\ junto a este archivo.
import json
import os
import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = json.load(open(os.path.join(HERE, 'importar.json'), encoding='utf-8'))
FBX = os.path.join(HERE, 'fbx')
tools = unreal.AssetToolsHelpers.get_asset_tools()
assets = unreal.EditorAssetLibrary


def log(text):
    unreal.log('[SecondShadow] ' + text)


def run(filename, folder, name, options):
    task = unreal.AssetImportTask()
    task.filename = filename
    task.destination_path = folder
    task.destination_name = name
    task.automated = True
    task.replace_existing = True
    task.save = True
    task.options = options
    tools.import_asset_tasks([task])
    return list(task.imported_object_paths or [])


def skeleton_for(entry):
    target = entry['esqueleto']
    folder, leaf = target.rsplit('/', 1)
    if assets.does_asset_exist(target):
        return unreal.load_asset(target)
    ui = unreal.FbxImportUI()
    ui.import_mesh = True
    ui.import_as_skeletal = True
    ui.import_animations = False
    ui.import_materials = False
    ui.import_textures = False
    ui.mesh_type_to_import = unreal.FBXImportType.FBXIT_SKELETAL_MESH
    mesh_name = 'MOD_' + os.path.splitext(entry['malla'])[0]
    imported = run(os.path.join(FBX, entry['malla']), folder, mesh_name, ui)
    log('malla importada: %s' % imported)
    mesh = unreal.load_asset(folder + '/' + mesh_name)
    skeleton = mesh.get_editor_property('skeleton')
    # El esqueleto debe quedar en la misma ruta que el del juego.
    assets.rename_asset(skeleton.get_path_name().split('.')[0], target)
    skeleton = unreal.load_asset(target)
    bounds = mesh.get_bounds()
    log('esqueleto %s; tamano de la malla %s' % (target, bounds.box_extent))
    return skeleton


for entry in CONFIG['personajes']:
    skeleton = skeleton_for(entry)
    ui = unreal.FbxImportUI()
    ui.import_mesh = False
    ui.import_as_skeletal = True
    ui.import_animations = True
    ui.skeleton = skeleton
    ui.mesh_type_to_import = unreal.FBXImportType.FBXIT_ANIMATION
    data = ui.anim_sequence_import_data
    data.set_editor_property('animation_length', unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME)
    data.set_editor_property('import_bone_tracks', True)
    data.set_editor_property('remove_redundant_keys', False)
    imported = run(os.path.join(FBX, entry['animacion']), CONFIG['destino'], entry['nombre'], ui)
    anim = unreal.load_asset(CONFIG['destino'] + '/' + entry['nombre'])
    if not anim:
        raise RuntimeError('no se importo ' + entry['animacion'])
    log('animacion %s: %.2f s' % (entry['nombre'], anim.get_editor_property('sequence_length')))

assets.save_directory('/Game', only_if_is_dirty=False, recursive=True)
log('listo')
