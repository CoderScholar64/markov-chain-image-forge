class_name MarkovConditionContainer
extends GridContainer


signal option_selected(checked_positions: Array[Vector2i], position_index_to_color_index: Array[int])
signal option_selected_single(relative_position: Vector2i, position_index: int, color_index: int)


func update_colors(color_array: Array[Color], invalid_color: Color) -> void:
	var children := get_children()
	
	for child in children:
		if !child.ready:
			await child.ready
		
		if child is ConditionSelectButton:
			child.setup_possiable_colors(color_array, invalid_color)


func update_colors_conditional(enabled_positions: Array[Vector2i], color_array: Array[Color], invalid_color: Color) -> void:
	var children := get_children()
	var blank_color_array: Array[Color] = []
	
	for child in children:
		if !child.ready:
			await child.ready
		
		if child is ConditionSelectButton:
			var condition_selection: ConditionSelectButton = child
			
			if enabled_positions.has( condition_selection.position_relative_to_cursor ):
				condition_selection.setup_possiable_colors(color_array, invalid_color, false)
			else:
				condition_selection.setup_possiable_colors(blank_color_array, invalid_color)


func update_selection(position_index_to_color_index: Array[int]) -> void:
	var children := get_children()
	var index := 0
	
	for child_index in len(children):
		if children[child_index] is ConditionSelectButton:
			var condition_selection: ConditionSelectButton = children[child_index]
			
			if !condition_selection.is_queued_for_deletion() and condition_selection.has_color_check():
				condition_selection.set_color_index(1 + position_index_to_color_index[index])
				index += 1


func update_invalid_color(invalid_color: Color) -> void:
	var children := get_children()
	
	for child in children:
		if !child.ready:
			await child.ready
		
		if child is ConditionSelectButton:
			child.update_invalid_color(invalid_color)


func _on_option_selected(sender: ConditionSelectButton) -> void:
	var checked_positions: Array[Vector2i] = []
	var checked_position_defaults: Array[int] = []
	
	var children := get_children()
	
	for child in children:
		if child is ConditionSelectButton:
			var condition_selection: ConditionSelectButton = child
			
			if condition_selection.has_color_check():
				checked_position_defaults.append( condition_selection.get_color_index() )
				checked_positions.append(condition_selection.position_relative_to_cursor)
			
			if sender == condition_selection:
				option_selected_single.emit(condition_selection.position_relative_to_cursor, len(checked_positions) - 1, condition_selection.get_color_index())
	
	option_selected.emit(checked_positions, checked_position_defaults)
