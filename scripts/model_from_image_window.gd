extends Window


signal markov_chain_submit(dictionary: Dictionary)

var cursor_positions: Array[Vector2i]
var checked_position_defaults: Array[int]
var unique_colors: Array[Color]
var mci_ruleset_candidate: MarkovChainImageScanlineRules
var original_texture: Texture2D
var original_invalid_color: Color = Color(1, 0, 1)
var information_text: String = ""
var make_model_dialog_text: String = ""

@onready var open_image_seed_dialog:                   FileDialog = %ModelFromImageDialog
@onready var texture_rect:                            TextureRect = $Control/TextureRect
@onready var information_text_label:                RichTextLabel = %InformationText
@onready var markov_condition_container: MarkovConditionContainer = $Control/MarkovConditionContainer
@onready var invalid_color_picker:              ColorPickerButton = $Control/ColorPickerButton
@onready var make_model_dialog:                ConfirmationDialog = %MakeModelDialog
@onready var accept_dialog:                          AcceptDialog = %AcceptDialog
@onready var browse_file_button:                           Button = %BrowseFileButton
@onready var setup_button:                                 Button = $Control/SetupModel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	information_text       = information_text_label.text
	make_model_dialog_text = make_model_dialog.dialog_text
	original_texture       = texture_rect.texture
	original_invalid_color = invalid_color_picker.color
	markov_condition_container.update_colors([], invalid_color_picker.color)
	
	# Disable file browsing if using web based builds.
	# TODO Figure out how to support broswing and uploading.
	if OS.has_feature("web"):
		browse_file_button.disabled = true
		browse_file_button.tooltip_text = "Sorry, for now browsing for files is not support this web build.\nYou must drag the file instead or use the Desktop builds."
	
	update()


func show_up() -> void:
	show()
	get_tree().root.files_dropped.connect(_on_files_dropped)


func update() -> void:
	
	information_text_label.text = information_text.format( {
		"0" : len(unique_colors),
		"1" : len(checked_position_defaults),
		"2" : len(unique_colors) ** len(checked_position_defaults)})
	
	setup_button.disabled = cursor_positions.is_empty()
	
	if unique_colors.has(invalid_color_picker.color):
		setup_button.disabled = true


func _on_close_requested() -> void:
	hide()
	get_tree().root.files_dropped.disconnect(_on_files_dropped)
	
	texture_rect.texture = original_texture
	invalid_color_picker.color = original_invalid_color
	markov_condition_container.update_colors([], invalid_color_picker.color)
	update()


func _on_browse_file_button_pressed() -> void:
	open_image_seed_dialog.show()


func _on_model_from_image_dialog_file_selected(path: String) -> void:
	var loaded_image := Image.load_from_file(path)
	
	if !loaded_image:
		accept_dialog.dialog_text = 'Error "' + path + '" did not load!'
		accept_dialog.show()
		return
	
	# This makes sure that crashes related to color precission does not happen.
	match loaded_image.get_format():
		Image.Format.FORMAT_L8,       \
		Image.Format.FORMAT_LA8,      \
		Image.Format.FORMAT_R8,       \
		Image.Format.FORMAT_RG8,      \
		Image.Format.FORMAT_RGB8,     \
		Image.Format.FORMAT_RGBA8,    \
		Image.Format.FORMAT_RGBA4444, \
		Image.Format.FORMAT_RGB565:
			pass
		_:
			accept_dialog.dialog_text = \
				'Error "' + path + '" color format is not compatible.\n'+\
				"The color bit depth per component must be equal to or under 8 bits.\n" +\
				"This is an editor limitation but then again 8 bits per channel\n" +\
				"for RBGA would have 4 billion unique colors.\n" +\
				"In addition, the color format must be a lossless format.\n" +\
				"A lossy format could have more unique pixels then a lossless format."
			accept_dialog.show()
			return
	
	texture_rect.texture = ImageTexture.create_from_image(loaded_image)
	
	unique_colors = MarkovChainImageScanlineRules.extract_unique_colors(loaded_image)
	
	markov_condition_container.update_colors(unique_colors, invalid_color_picker.color)
	
	update()


func _on_files_dropped(files: PackedStringArray) -> void:
	if len(files) == 1:
		_on_model_from_image_dialog_file_selected(files[0])


func _on_color_picker_button_color_changed(color: Color) -> void:
	# Make sure the Color is downsampled to the same resolution of the pixel format.
	# NOTE: Change this if the texture format is changed.
	invalid_color_picker.color = Color.hex(invalid_color_picker.color.to_rgba32())
	
	markov_condition_container.update_invalid_color(invalid_color_picker.color)
	
	update()


func _on_markov_condition_container_option_selected(checked_positions_param: Array[Vector2i], checked_position_defaults_param: Array[int]) -> void:
	cursor_positions = checked_positions_param
	checked_position_defaults = checked_position_defaults_param
	
	update()


func _on_setup_model_pressed() -> void:
	if !texture_rect.texture or !texture_rect.texture.get_image():
		return
		
	var source_image := texture_rect.texture.get_image()
	
	mci_ruleset_candidate = MarkovChainImageScanlineRules.create_rules(
			source_image, cursor_positions, checked_position_defaults, invalid_color_picker.color)
	
	make_model_dialog.dialog_text = make_model_dialog_text.format( {
		"0" : mci_ruleset_candidate.get_num_states(),
		"1" : mci_ruleset_candidate.get_max_states(),
		"2" : "%3.2f" % [100.0 * mci_ruleset_candidate.get_known_state_factor()],
		"3" : mci_ruleset_candidate.get_max_states() - mci_ruleset_candidate.get_num_states()})
	
	make_model_dialog.show()


func _on_make_model_dialog_confirmed() -> void:
	var error_rules_string := mci_ruleset_candidate.get_error_string()
	
	if !error_rules_string.is_empty():
		accept_dialog.dialog_text = error_rules_string
		accept_dialog.show()
		mci_ruleset_candidate = null
		return
	
	if !mci_ruleset_candidate.does_color_format_work(Image.Format.FORMAT_RGBA8):
		accept_dialog.dialog_text = "The colors are not distinct enough from each other. " +\
			"To fix this change the invalid color to a color more distinct.\n"+\
			"If that does not work then you should fix the seed image so the pixels are more distinct "+\
			"from each other."
		accept_dialog.show()
		mci_ruleset_candidate = null
		return
	
	var markov_chain_data: Dictionary = {
		"cursor_positions":          mci_ruleset_candidate.cursor_positions,
		"checked_position_defaults": mci_ruleset_candidate.checked_position_defaults,
		"unique_colors":             mci_ruleset_candidate.unique_colors,
		"invalid_color":             mci_ruleset_candidate.invalid_color,
		"markov_matrix":             mci_ruleset_candidate.markov_matrix,
	}
	
	markov_chain_submit.emit(markov_chain_data)
	
	make_model_dialog.hide()
	_on_close_requested()
