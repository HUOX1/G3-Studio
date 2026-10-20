@tool
extends EditorPlugin

var importer
var animated_importer
var preview

func _enter_tree() -> void:
	# Avoid typed native class annotations so a missing GDExtension shows a clear error
	# instead of "Unable to load addon plugin script".
	if not ClassDB.class_exists(&"ResourceImporterGIFTexture"):
		push_error("Godot Animated Image: GDExtension failed to load (native classes missing). Check bin/godot_animated_image.gdextension (no UTF-8 BOM) and windows x86_64 DLL.")
		return

	importer = ClassDB.instantiate(&"ResourceImporterGIFTexture")
	add_import_plugin(importer)

	animated_importer = ClassDB.instantiate(&"ResourceImporterAnimatedImage")
	add_import_plugin(animated_importer)

	preview = ClassDB.instantiate(&"ResourcePreviewGIFTexture")
	EditorInterface.get_resource_previewer().add_preview_generator(preview)

func _exit_tree() -> void:
	if importer:
		remove_import_plugin(importer)
		importer = null
	if animated_importer:
		remove_import_plugin(animated_importer)
		animated_importer = null
	if preview:
		EditorInterface.get_resource_previewer().remove_preview_generator(preview)
		preview = null
