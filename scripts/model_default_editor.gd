extends Control


@export var main_control: MCIGenerator


@onready var markov_condition_container: MarkovConditionContainer = %MarkovConditionContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func update(_markov_chain_changed: bool) -> void:
	markov_condition_container.update_colors(
		main_control.model_data["unique_colors"], main_control.model_data["invalid_color"])
	
	markov_condition_container.update_colors_conditional(
		main_control.model_data["cursor_positions"],
		main_control.model_data["unique_colors"], main_control.model_data["invalid_color"])
	
	markov_condition_container.update_selection(main_control.model_data["checked_position_defaults"])


func _on_markov_condition_container_option_selected_single(_relative_position: Vector2i, position_index: int, color_index: int) -> void:
	main_control.edit_default_color(position_index, color_index)
