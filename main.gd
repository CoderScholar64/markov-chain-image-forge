class_name MCIGenerator
extends Control

@onready var file_popup_menu:            PopupMenu = %FilePopupMenu
@onready var edit_popup_menu:            PopupMenu = %EditPopupMenu
@onready var save_as_popup_menu:        FileDialog = %SaveAsModelDialog
@onready var startup_instructions:           Panel = %StartupInstructions
@onready var tab_container:           TabContainer = %TabContainer
@onready var model_defaults_editor:        Control = %Defaults
@onready var model_rule_editor:            Control = %Model
@onready var image_generator:              Control = %Generator
@onready var open_model_error_dialog: AcceptDialog = %OpenModelErrorDialog


var model_save_path: String ## This is the model save path. If set then the project can be automatically saved.
var model_data: Dictionary ## This is the primary data structure of the project.
var has_unsaved_data: bool = false ## This is used to indicate if the user should be warned about lost data.


var _undo_history: Array[Dictionary] = []
var _undo_history_index: int = -1
const _UNDO_HISTORY_LIMIT: int = 1024

var _title_backup: String


func _ready() -> void:
	_title_backup = get_tree().root.title
	
	get_tree().root.files_dropped.connect(_on_files_dropped)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("undo") and is_undo_possiable():
		undo_action()
		
		update()
	if event.is_action_pressed("redo") and is_redo_possiable():
		redo_action()
		
		update()


func update(new_markov_chain: bool = false) -> void:
	var title_name := ""
	
	if has_unsaved_data:
		title_name = "*"
	
	if model_save_path and model_save_path != "":
		title_name += "[" + model_save_path.get_file() + "] - "
	else:
		title_name += "[unsaved] - "
	
	title_name += _title_backup
	
	get_tree().root.title = title_name
	
	if !model_data.is_empty():
		if startup_instructions.visible:
			startup_instructions.hide()
			get_tree().root.files_dropped.disconnect(_on_files_dropped)
		tab_container.show()
	
	file_popup_menu.update()
	edit_popup_menu.update()
	image_generator.update(new_markov_chain)
	model_rule_editor.update(new_markov_chain)
	model_defaults_editor.update(new_markov_chain)


func _on_files_dropped(files: PackedStringArray) -> void:
	if %ModelFromImageWindow.visible:
		return
	
	if len(files) == 1:
		_on_open_model_dialog_file_selected(files[0])


func set_model_data(dictionary: Dictionary) -> bool:
	if dictionary.has("color_index_count"):
		dictionary.erase("color_index_count")
	
	if !dictionary.has("cursor_positions") or dictionary["cursor_positions"] is not Array[Vector2i]\
		or dictionary["cursor_positions"].is_empty():
		return false
	if !dictionary.has("checked_position_defaults") or dictionary["checked_position_defaults"] is not Array[int]\
		or len(dictionary["checked_position_defaults"]) != len(dictionary["cursor_positions"]):
		return false
	if !dictionary.has("unique_colors") or dictionary["unique_colors"] is not Array[Color]:
		return false
	if !dictionary.has("invalid_color") or dictionary["invalid_color"] is not Color\
		or dictionary["unique_colors"].has(dictionary["invalid_color"]):
		return false
	if !dictionary.has("markov_matrix") or dictionary["markov_matrix"] is not Dictionary[Array, PackedFloat32Array]:
		return false
	
	for input in dictionary["markov_matrix"]:
		if input is not Array[int] or len(input) != len(dictionary["cursor_positions"]):
			return false
		
		var output_chances: PackedFloat32Array = dictionary["markov_matrix"][input]
		if output_chances is not PackedFloat32Array or\
			len(output_chances) != len(dictionary["unique_colors"]):
			return false
		
		for output_probability in output_chances:
			if output_probability is not float:
				return false
	
	model_data = dictionary
	
	return true


func clear_history() -> void:
	_undo_history = []
	_undo_history_index = -1


func is_undo_possiable() -> bool:
	return (!_undo_history.is_empty() and _undo_history_index > -1)


func undo_action() -> void:
	assert(!_undo_history.is_empty())
	assert(_undo_history_index > -1)
	assert(_undo_history_index < len(_undo_history))
	
	var funct: Callable = _undo_history[_undo_history_index]["func"]
	
	assert(funct is Callable)
	
	funct.call(_undo_history[_undo_history_index]["undo_args"])
	
	_undo_history_index -= 1


func is_redo_possiable() -> bool:
	return (!_undo_history.is_empty() and len(_undo_history) != _undo_history_index + 1)


func redo_action() -> void:
	assert(!_undo_history.is_empty())
	assert(len(_undo_history) != _undo_history_index + 1)
	
	var funct: Callable = _undo_history[_undo_history_index]["func"]
	
	assert(funct is Callable)
	
	funct.call(_undo_history[_undo_history_index]["redo_args"])
	
	_undo_history_index += 1


func append_history(funct: Callable, redo_args: Array, undo_args: Array) -> Array:
	assert(len(redo_args) == len(undo_args))
	
	var undo_entry := {
		"func": funct,
		"redo_args": redo_args,
		"undo_args": undo_args}
	
	if undo_entry["undo_args"] != undo_entry["redo_args"]:
		# If a redo operation is done and you made an edit. Discard the history.
		# NOTE: This will destory the history permentently.
		if !_undo_history.is_empty() and (_undo_history_index + 1) != len(_undo_history):
			_undo_history = _undo_history.slice(0, _undo_history_index + 1)
		
		# If the limit gets exceeded then remove the history.
		if _UNDO_HISTORY_LIMIT <= len(_undo_history):
			_undo_history.remove_at(0)
		
		# Finally append the entry to the array.
		_undo_history.append(undo_entry)
		
		# The history index should point to the latest entry.
		_undo_history_index = len(_undo_history) - 1
		
	return redo_args


func edit_rule(key: Array[int], answer: PackedFloat32Array) -> bool:
	assert(len(key)    == len(model_data["cursor_positions"]))
	assert(len(answer) == len(model_data["unique_colors"]))
	
	var undo_args: Array
	
	if model_data["markov_matrix"].has(key):
		undo_args = [key, model_data["markov_matrix"][key]]
	else:
		var empty: PackedFloat32Array = []
		
		for i in len(answer):
			empty.append(0.0)
			
		undo_args = [key, empty]
	
	# Finally edit the rules
	return _edit_rule_action(append_history(_edit_rule_action, [key, answer], undo_args))


func _edit_rule_action(args: Array) -> bool:
	assert(len(args) == 2)
	
	var key: Array[int] = []
	
	for i in args[0]:
		assert(i is int)
		key.append(i)
	
	var answer: PackedFloat32Array = args[1]
	
	assert(len(key)    == len(model_data["cursor_positions"]))
	assert(len(answer) == len(model_data["unique_colors"]))
	
	var has_probablity: bool = false
	
	for prob in answer:
		if prob != 0.0:
			has_probablity = true
			break
	
	if has_probablity:
		has_unsaved_data = true
		
		if !model_data["markov_matrix"].has(key):
			model_data["markov_matrix"][key.duplicate()] = answer
		else:
			model_data["markov_matrix"][key] = answer
		
		return model_data.has(key)
	else:
		if !model_data["markov_matrix"].has(key):
			return true
		else:
			has_unsaved_data = true
			return model_data["markov_matrix"].erase(key)


func edit_unique_color(color_index: int, new_color: Color) -> bool:
	var redo_args := [color_index, new_color]
	var undo_args := [color_index, model_data["unique_colors"][color_index]]
	
	if _edit_unique_color_action(redo_args):
		append_history(_edit_unique_color_action, redo_args, undo_args)
		return true
	
	return false


func _edit_unique_color_action(args: Array) -> bool:
	assert(len(args) == 2)
	assert(args[0] is int)
	assert(args[1] is Color)
	
	var color_index: int = args[0]
	var new_color: Color = args[1]
	
	var unique_colors: Array[Color] = model_data["unique_colors"]
	var invalid_color:        Color = model_data["invalid_color"]
	
	assert(!unique_colors.is_empty())
	
	if unique_colors.has(new_color):
		print("User Error: Colors must be unique!")
		return false
	
	if invalid_color == new_color:
		print("User Error: Use a different color other than the invalid color.")
		return false
		
	unique_colors[color_index] = new_color
	
	has_unsaved_data = true
	
	update()
	
	return true


func edit_default_color(index_of_default: int, color_index: int) -> bool:
	var redo_args := [index_of_default, color_index]
	var undo_args := [index_of_default, model_data["checked_position_defaults"][index_of_default]]
	
	if _edit_default_color(redo_args):
		append_history(_edit_default_color, redo_args, undo_args)
		return true
	return false


func _edit_default_color(args: Array) -> bool:
	assert(len(args) == 2)
	assert(args[0] is int)
	assert(args[1] is int)
	
	var index_of_default: int = args[0]
	var color_index:      int = args[1]
	
	if index_of_default >= len(model_data["checked_position_defaults"]):
		return false
	
	if color_index >= len(model_data["unique_colors"]):
		return false
	
	model_data["checked_position_defaults"][index_of_default] = color_index
	
	has_unsaved_data = true
	
	update()
	
	return true


func edit_invalid_color(invalid_color: Color) -> bool:
	var redo_args := [invalid_color]
	var undo_args := [model_data["invalid_color"]]
	
	if _edit_invalid_color_action(redo_args):
		append_history(_edit_invalid_color_action, redo_args, undo_args)
		return true
	
	return false


func _edit_invalid_color_action(args: Array) -> bool:
	assert(len(args) == 1)
	assert(args[0] is Color)
	
	var invalid_color: Color = args[0]
	
	if model_data["unique_colors"].has(invalid_color):
		return false
	
	# Update if invalid color is unique
	model_data["invalid_color"] = invalid_color
	
	has_unsaved_data = true
	
	update()
	
	return true


func _on_model_from_image_submit(dictionary: Dictionary) -> void:
	if !set_model_data( dictionary ):
		printerr("Internal Error. The data structure created by the create \"model from image\" is maliformed. This is most likely a bug.")
		return
	
	model_save_path = ""
	
	has_unsaved_data = true
	
	clear_history()
	
	update(true)


func _on_save_as_model_dialog_file_selected(path: String) -> void:
	var file: FileAccess
	
	match path.get_extension():
		"json":
			var value = JSON.from_native(model_data)
			
			if !value:
				printerr("Model exporting had failed!")
			
			file = FileAccess.open(path, FileAccess.WRITE)
			
			if file.is_open():
				file.store_line(JSON.stringify(value, "", true, true))
			
		"bin":
			file = FileAccess.open(path, FileAccess.WRITE)
			
			if file.is_open():
				file.store_var(model_data)
			
		"tres", "res":
			var markov_gen := MarkovChainImageScanlineRules.new()
			markov_gen.cursor_positions          = model_data["cursor_positions"]
			markov_gen.checked_position_defaults = model_data["checked_position_defaults"]
			markov_gen.unique_colors             = model_data["unique_colors"]
			markov_gen.invalid_color             = model_data["invalid_color"]
			markov_gen.markov_matrix             = model_data["markov_matrix"]
			
			ResourceSaver.save(markov_gen, path)
			
		_:
			printerr("{file_name} is not supported {file_extension}".format({"file_name":path.get_basename(), "file_extension":path.get_file()}))
		
	if file and file.is_open():
		
		model_save_path = path
		has_unsaved_data = false
		
		file.close()
		
		update()


func _on_open_model_dialog_file_selected(path: String) -> void:
	var dictionary: Dictionary = {}
	var error_dialog: String = ""
	
	match path.get_extension():
		"json":
			var file_string := FileAccess.get_file_as_string(path)
			
			var parsed_string = JSON.parse_string(file_string)
			
			if parsed_string == null:
				if file_string == "":
					
					var error_code := FileAccess.get_open_error()
					
					error_dialog = "{file_name} failed to be read. Error Code: {error_code}, Error: {error_string}".format({
						"file_name":path.get_file(),
						"error_code":error_code,
						"error_string":error_string(error_code)})
					
					printerr(error_dialog)
				else:
					error_dialog = "{file_name} is not encoded in a JSON format compatiable for this program.".format({"file_name":path.get_file()})
					
					printerr(error_dialog)
			else:
				var unknown_data = JSON.to_native(parsed_string)
				
				if unknown_data is Dictionary:
					dictionary = unknown_data
				else:
					error_dialog = "{file_name} is not a json model file.".format({"file_name":path.get_file()})
					
					printerr(error_dialog)
		"bin":
			var file := FileAccess.open(path, FileAccess.READ)
			
			if file.is_open():
				var unknown_data = file.get_var()
				
				if unknown_data is Dictionary:
					dictionary = unknown_data
				else:
					error_dialog = "{file_name} is not a serialized(.bin) model file.".format({"file_name":path.get_file()})
					
					printerr(error_dialog)
				
				file.close()
			
		"tres", "res":
			var markov_gen: MarkovChainImageScanlineRules = load(path)
			
			dictionary["cursor_positions"]          = markov_gen.cursor_positions
			dictionary["checked_position_defaults"] = markov_gen.checked_position_defaults
			dictionary["unique_colors"]             = markov_gen.unique_colors
			dictionary["invalid_color"]             = markov_gen.invalid_color
			dictionary["markov_matrix"]             = markov_gen.markov_matrix
			
		_:
			error_dialog = "{file_extension} is not supported {file_name}".format({"file_name":path.get_file(), "file_extension":path.get_file().get_extension()})
			printerr(error_dialog)
	
	if error_dialog != "":
		open_model_error_dialog.dialog_text = error_dialog
		open_model_error_dialog.show()
	
	if !set_model_data( dictionary ):
		printerr("Error this resource is not a valid markov chain image generator file! \"{path}\" failed".format({"path": path}) )
		return
	else:
		model_save_path = path
		
		clear_history()
		
		update(true)
