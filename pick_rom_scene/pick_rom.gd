extends Control


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://infinite_mario_64.cfg") == OK:
		var saved_path: String = cfg.get_value("rom", "last_path", "")
		if not saved_path.is_empty():
			if LibSM64Global.load_rom_file(saved_path):
				get_tree().change_scene_to_file("res://overlay_main.tscn")
				return


func _on_prompt_rom_button_pressed() -> void:
	%RomPickerDialog.pick_rom()


func _on_rom_picker_dialog_rom_loaded() -> void:
	get_tree().change_scene_to_file("res://overlay_main.tscn")
