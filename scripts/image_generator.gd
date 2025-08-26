extends Control


signal on_missing_rule(missing_rule: Array[int], image: Image, coordinates: Vector2i)


@export var main_control: MCIGenerator


@onready var image_display:                         TextureRect = %ImageDisplay
@onready var generate_image_button:                      Button = %GenerateImageButton
@onready var new_seed_button:                            Button = %NewSeedButton
@onready var width_spin_box:                            SpinBox = %WidthSpinBox
@onready var height_spin_box:                           SpinBox = %HeightSpinBox
@onready var repeat_line_spin_box:                      SpinBox = %RepeatLineSpinBox
@onready var seed_edit:                                LineEdit = %SeedEdit
@onready var save_generated_dialog:                  FileDialog = %SaveGeneratedDialog
@onready var save_generated_download_dialog: FileDownloadDialog = %SaveGeneratedDownloadDialog
@onready var save_generated_err_dialog:            AcceptDialog = %SaveGeneratedErrorDialog


var _random_number_seed: int
var _random_number_state: int
var prev_args_gen_image: Array

const INT_BASE64_DEGIT := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


static func INT_TO_BASE64ISH(number: int) -> String:
	var base64_result: String = ""
	
	var is_negative: bool = number < 0
	
	if is_negative:
		base64_result = "/"
		number = -int(number + 1)
	else:
		base64_result = "+"
	
	var number_work = number
	
	for i in 11:
		base64_result += INT_BASE64_DEGIT[number_work % len(INT_BASE64_DEGIT)]
		
		@warning_ignore("integer_division")
		number_work = int(number_work / len(INT_BASE64_DEGIT))
	
	return base64_result.reverse()


static func BASE64ISH_VALID(password: String) -> bool:
	assert(7 == INT_BASE64_DEGIT.find('H'))
	
	if len(password) != 12:
		return false
	if INT_BASE64_DEGIT.find(password[0]) > 7:
		return false
	
	for c in password:
		if INT_BASE64_DEGIT.find(c) == -1:
			return false
	
	return true


static func BASE64ISH_TO_INT(password: String) -> int:
	var number: int = 0
	
	for i in 11:
		number  = int(number * len(INT_BASE64_DEGIT))
		number += INT_BASE64_DEGIT.find(password[i])
	
	if password[11] == "/":
		number  = -number
		number -= 1
	
	return number


func _update_seed_edit() -> void:
	var  seed_password := INT_TO_BASE64ISH(_random_number_seed)
	var state_password := INT_TO_BASE64ISH(_random_number_state)
	
	assert(!BASE64ISH_VALID("")) # No length
	assert(!BASE64ISH_VALID("IJ+vYL4N20z")) # Too Short by one
	assert(!BASE64ISH_VALID("IJ+vYL4N20z+T")) # Too Long by one
	assert(!BASE64ISH_VALID("IJ+vYL4N20z+")) # Too big
	assert(!BASE64ISH_VALID("GJ+vYL4N20z%")) # Invalid character at end
	assert(BASE64ISH_VALID("H//////////+")) # Max Positive
	assert(BASE64ISH_VALID("H///////////")) # Max Negative
	
	assert(BASE64ISH_VALID( seed_password))
	assert(BASE64ISH_VALID(state_password))
	assert(BASE64ISH_TO_INT( seed_password) ==  _random_number_seed)
	assert(BASE64ISH_TO_INT(state_password) == _random_number_state)
	
	seed_edit.text = seed_password + state_password


func _ready() -> void:
	var random_number_gen := RandomNumberGenerator.new()
	random_number_gen.randomize()
	_random_number_seed  = random_number_gen.seed
	_random_number_state = random_number_gen.state
	
	_update_seed_edit()


func update(new_markov_chain: bool = false) -> void:
	if !main_control.model_data:
		return
	
	if !new_markov_chain:
		return
	
	prev_args_gen_image = []
	
	prev_args_gen_image.append(Vector2i(int(width_spin_box.value), int(height_spin_box.value)))
	prev_args_gen_image.append(_random_number_seed)
	prev_args_gen_image.append(_random_number_state)
	prev_args_gen_image.append(int(repeat_line_spin_box.value))
	prev_args_gen_image.append(false)
	
	_generate_image_action(prev_args_gen_image)


func _on_generate_image_button_pressed() -> void:
	generate_image(
		Vector2i(int(width_spin_box.value), int(height_spin_box.value)),
		_random_number_seed, _random_number_state,
		int(repeat_line_spin_box.value), true)


func generate_image(image_size: Vector2i, random_seed: int, random_state: int, repeat_limit: int, autoset_missing: bool) -> void:
	var redo_args: Array = [image_size, random_seed, random_state, repeat_limit, autoset_missing]
	
	_generate_image_action(main_control.append_history(_generate_image_action, redo_args, prev_args_gen_image))
	
	prev_args_gen_image = redo_args
	
	main_control.update()
	

func _generate_image_action(args: Array) -> void:
	assert(len(args) == 5)
	
	var   image_size: Vector2i = args[0]
	var  random_seed:      int = args[1]
	var random_state:      int = args[2]
	var repeat_limit:      int = args[3]
	var autoset_missing:  bool = args[4]
	
	width_spin_box.value       = image_size.x
	height_spin_box.value      = image_size.y
	repeat_line_spin_box.value = repeat_limit
	
	_random_number_seed  = random_seed
	_random_number_state = random_state
	_update_seed_edit()
	
	var random_number_gen := RandomNumberGenerator.new()
	random_number_gen.seed  = _random_number_seed
	random_number_gen.state = _random_number_seed
	
	var markov_gen := MarkovChainImageScanlineRules.new()
	markov_gen.cursor_positions          = main_control.model_data["cursor_positions"]
	markov_gen.checked_position_defaults = main_control.model_data["checked_position_defaults"]
	markov_gen.unique_colors             = main_control.model_data["unique_colors"]
	markov_gen.invalid_color             = main_control.model_data["invalid_color"]
	markov_gen.markov_matrix             = main_control.model_data["markov_matrix"]
	
	if autoset_missing:
		for connection in on_missing_rule.get_connections():
			markov_gen.on_missing_rule.connect(connection["callable"])
	
	var result := markov_gen.generate_image(image_size, Image.Format.FORMAT_RGBA8, repeat_limit, random_number_gen)
	
	assert(result.has("image"), "The rules are not valid")
	
	image_display.texture = ImageTexture.create_from_image(result["image"])


func _on_new_seed_button_pressed() -> void:
	var random_number_gen := RandomNumberGenerator.new()
	random_number_gen.randomize()
	_random_number_seed  = random_number_gen.seed
	_random_number_state = random_number_gen.state
	
	_update_seed_edit()
	_on_generate_image_button_pressed()


func _on_image_display_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print(image_display.get_rect())
		print("Button: ", event.button_index, ", Position: ", event.position)


func _on_seed_edit_text_submitted(new_text: String) -> void:
	if len(new_text) != 24:
		_update_seed_edit()
		return
	
	var  seed_password: String = new_text.substr( 0, 12)
	var state_password: String = new_text.substr(12, 12)
	
	if !BASE64ISH_VALID(seed_password) or !BASE64ISH_VALID(state_password):
		_update_seed_edit()
		return
	
	_random_number_seed  = BASE64ISH_TO_INT( seed_password)
	_random_number_state = BASE64ISH_TO_INT(state_password)


func _on_export_image_button_pressed() -> void:
	if OS.has_feature("web"):
		save_generated_download_dialog.show()
	else:
		save_generated_dialog.show()


func _on_save_generated_dialog_file_selected(path: String) -> void:
	if image_display.texture == null:
		return
	
	if image_display.texture.get_image() == null:
		return
		
	var error_code: Error
	
	match path.get_extension():
		"exr":
			error_code = image_display.texture.get_image().save_exr(path)
		"png":
			error_code = image_display.texture.get_image().save_png(path)
		"webp":
			error_code = image_display.texture.get_image().save_webp(path)
		_:
			print_debug("Minor bug extension ", path.get_extension, " is not supported for path: ", path)
			error_code = image_display.texture.get_image().save_png(path.get_basename() + ".png")
	
	if error_code != Error.OK:
		save_generated_err_dialog.dialog_text = "'{file_name}' had failed to write to disk with error code {error_code} with message: {error}".format(
			{"file_name": path.get_file(),
			"error_code": error_code,
			"error": error_string(error_code)})
		
		printerr( save_generated_err_dialog.dialog_text )
		
		save_generated_err_dialog.show()
