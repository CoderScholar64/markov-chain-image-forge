class_name ConditionSelectButton
extends ColorRect


signal option_selected(selfy : ConditionSelectButton)


@export var position_relative_to_cursor: Vector2i


@onready var option_button: OptionButton = $OptionButton


var colors_array: Array[Color]
var color_index: int
var invalid_color := Color(1, 0, 1)

func setup_possiable_colors(array_of_colors: Array[Color], error_color: Color, has_no_selection_option: bool = true) -> void:
	colors_array = array_of_colors
	invalid_color = error_color
	
	if array_of_colors.is_empty():
		option_button.disabled = true
	else:
		option_button.disabled = false
	
	option_button.clear()
	option_button.add_item("N")
	
	for i in len(colors_array):
		option_button.add_item("{0}".format({"0" : (i + 1)}))
	
	if !has_no_selection_option:
		option_button.remove_item(0) # Remove "N" or no item selected
		color_index = 1
		color = array_of_colors[0]
	else:
		color_index = 0
		color = invalid_color
	
	option_button.selected = 0


func update_invalid_color(error_color: Color) -> void:
	invalid_color = error_color
	
	if !has_color_check():
		color = invalid_color


func has_color_check() -> bool:
	if color_index != 0:
		return true
	return false


func get_color_index() -> int:
	return color_index - 1


func set_color_index(option_index: int) -> void:
	color_index = option_index
	
	if color_index == 0:
		color = invalid_color
	else:
		color = colors_array[color_index - 1]
	
	option_button.select(option_button.get_item_index(color_index))


func _on_option_button_item_selected(index: int) -> void:
	color_index = option_button.get_item_id(index)
	
	if color_index == 0:
		color = invalid_color
	else:
		color = colors_array[color_index - 1]
	
	option_selected.emit(self)
