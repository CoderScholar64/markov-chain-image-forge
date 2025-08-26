class_name ColorChanceOption
extends HBoxContainer


signal updated_chance(color_index: int, chance: float)
signal updated_color(color_change_option: ColorChanceOption, old_color: Color)


@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var chance_spin_box:               SpinBox = %ChanceSpinBox
@onready var index_label:             RichTextLabel = %IndexLabel


var _color: Color = Color(1, 1, 1)
var _color_index: int = 0
var _chance: float  = 0.0
var _string: String = ""


func _ready() -> void:
	_string = index_label.text
	chance_spin_box.editable = false
	
	update()


func update() -> void:
	if is_node_ready():
		color_picker_button.color = _color
		index_label.text = _string.format({"index" : _color_index, "color": color_picker_button.color.to_html()})


func set_editable(is_editable: bool) -> void:
	chance_spin_box.editable = is_editable


func set_color(color: Color) -> void:
	_color = color
	
	update()


func get_color() -> Color:
	return _color


func set_color_index(color_index : int) -> void:
	_color_index = color_index
	
	update()


func get_color_index() -> int:
	return _color_index


func set_chance(chance : float) -> void:
	_chance = chance
	chance_spin_box.value = 100.0 * chance


func get_chance() -> float:
	return _chance


func _on_chance_spin_box_value_changed(value: float) -> void:
	_chance = value / 100.0
	updated_chance.emit(_color_index, _chance)


func _on_color_picker_button_popup_closed() -> void:
	# Make sure the Color is downsampled to the same resolution of the pixel format.
	# NOTE: Change this if the texture format is changed.
	color_picker_button.color = Color.hex(color_picker_button.color.to_rgba32())
	
	if _color != color_picker_button.color:
		var old_color := _color
		
		set_color(color_picker_button.color)
		
		assert(_color_index > 0)
		
		updated_color.emit(self, old_color)
