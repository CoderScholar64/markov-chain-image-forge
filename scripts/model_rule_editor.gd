extends Control


@export var main_control: MCIGenerator
@export var color_chance_option: PackedScene


@onready var color_combo_label:                     RichTextLabel = %ColorComboLabel
@onready var color_chances_list:                    VBoxContainer = %VBoxContainer
@onready var markov_condition_container: MarkovConditionContainer = %MarkovConditionContainer
@onready var missing_rule_color_picker:         ColorPickerButton = %MissingRuleColorPicker
@onready var get_last_empty_button:                        Button = %GetLastEmptyButton
@onready var get_next_empty_button:                        Button = %GetNextEmptyButton


var _color_combo_label_string: String
var _position_index_to_color_index: Array[int]


func _ready() -> void:
	_color_combo_label_string = color_combo_label.text


func update(new_markov_chain: bool = false) -> void:
	if !main_control.model_data:
		return
	
	missing_rule_color_picker.color = main_control.model_data["invalid_color"]
	
	markov_condition_container.update_invalid_color(main_control.model_data["invalid_color"])
	markov_condition_container.update_colors_conditional(
		main_control.model_data["cursor_positions"],
		main_control.model_data["unique_colors"], main_control.model_data["invalid_color"])
	
	var children: Array[Node] = color_chances_list.get_children()
	
	if new_markov_chain:
		for i in children:
			color_chances_list.remove_child(i)
			i.queue_free()
		
		var counter: int = 1
		
		for color in main_control.model_data["unique_colors"]:
			var instance: ColorChanceOption = color_chance_option.instantiate()
			
			instance.set_color_index(counter)
			instance.set_color(color)
			instance.updated_color.connect(_on_color_changed)
			
			color_chances_list.add_child(instance)
			
			counter += 1
			
		_position_index_to_color_index = main_control.model_data["checked_position_defaults"]
	else:
		var counter: int = 0
		
		if main_control.model_data["markov_matrix"].has(_position_index_to_color_index):
			for index in len(children):
				children[index].set_editable(true)
				children[index].set_color( main_control.model_data["unique_colors"][counter] )
				children[index].set_chance(main_control.model_data["markov_matrix"][_position_index_to_color_index][index])
				counter += 1
		else:
			for index in len(children):
				children[index].set_editable(true)
				children[index].set_color( main_control.model_data["unique_colors"][counter] )
				children[index].set_chance(0.0)
				counter += 1
		
		markov_condition_container.update_selection(_position_index_to_color_index)
	
	var known_combinations := len(main_control.model_data["markov_matrix"])
	var estimated_posiable_combinations := len(main_control.model_data["unique_colors"]) ** len(main_control.model_data["cursor_positions"])
	var is_or_not: String = ""
	
	if !main_control.model_data["markov_matrix"].has(_position_index_to_color_index):
		is_or_not = "not "
	
	color_combo_label.text = _color_combo_label_string.format({
		"0": known_combinations,
		"1": estimated_posiable_combinations,
		"2": "%3.2f" % [100.0 * known_combinations / estimated_posiable_combinations],
		"3": is_or_not
	})
	
	get_last_empty_button.disabled = known_combinations == estimated_posiable_combinations
	get_next_empty_button.disabled = known_combinations == estimated_posiable_combinations


func _on_markov_condition_container_option_selected(_checked_positions: Array[Vector2i], position_index_to_color_index: Array[int]) -> void:
	_position_index_to_color_index = position_index_to_color_index
	
	main_control.update()


func _on_previous_combo_button_pressed() -> void:
	if _position_index_to_color_index.is_empty():
		return
	
	var next_position_index_to_color_index : Array[int] = _position_index_to_color_index.duplicate()
	
	next_position_index_to_color_index[0] -= 1
	
	var i := 0
	
	while len(next_position_index_to_color_index) > i and\
		  next_position_index_to_color_index[i] == -1:
		next_position_index_to_color_index[i] = len(main_control.model_data["unique_colors"]) - 1
		if len(next_position_index_to_color_index) > i + 1:
			next_position_index_to_color_index[i + 1] -= 1
		i += 1
	
	_position_index_to_color_index = next_position_index_to_color_index
	
	main_control.update()


func _on_next_combo_button_pressed() -> void:
	if _position_index_to_color_index.is_empty():
		return
	
	var next_position_index_to_color_index : Array[int] = _position_index_to_color_index.duplicate()
	
	next_position_index_to_color_index[0] += 1
	
	var i := 0
	
	while len(next_position_index_to_color_index) > i and\
		  next_position_index_to_color_index[i] == len(main_control.model_data["unique_colors"]):
		next_position_index_to_color_index[i] = 0
		if len(next_position_index_to_color_index) > i + 1:
			next_position_index_to_color_index[i + 1] += 1
		i += 1
	
	_position_index_to_color_index = next_position_index_to_color_index
	
	main_control.update()


func _on_update_chances_button_pressed() -> void:
	var array_chances: Array[float] = []
	var sum: float = 0.0
	
	for child in color_chances_list.get_children():
		array_chances.append( child.get_chance() )
		
		assert(child.get_chance() >= 0)
		
		sum += absf(array_chances.back())
	
	if sum != 1.0 and sum != 0.0:
		for i in len(array_chances):
			array_chances[i] *= 1.0 / sum
	
	main_control.edit_rule(_position_index_to_color_index, PackedFloat32Array(array_chances))
	
	main_control.update()


func _on_normalize_chances_button_pressed() -> void:
	var sum: float = 0.0
	
	for child in color_chances_list.get_children():
		assert(child.get_chance() >= 0)
		sum += absf(child.get_chance())
	
	if sum == 0.0:
		return
	
	for child in color_chances_list.get_children():
		child.set_chance((1.0 / sum) * child.get_chance())


func _on_image_generator_missing_rule(missing_rule: Array[int], _image: Image, _coordinates: Vector2i) -> void:
	_position_index_to_color_index = missing_rule
	
	main_control.update()


func _on_color_changed(color_chance_option_item: ColorChanceOption, old_color: Color) -> void:
	if !main_control.edit_unique_color(color_chance_option_item.get_color_index() - 1, color_chance_option_item.get_color()):
		color_chance_option_item.set_color(old_color)


func _on_missing_rule_color_picker_popup_closed() -> void:
	if !main_control.edit_invalid_color(missing_rule_color_picker.color):
		missing_rule_color_picker.color = main_control.model_data["invalid_color"]
