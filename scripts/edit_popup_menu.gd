extends PopupMenu


@export var main_control: MCIGenerator


const UNDO_ID := 0
const REDO_ID := 1


func update() -> void:
	set_item_disabled(get_item_index(UNDO_ID), !main_control.is_undo_possiable())
	set_item_disabled(get_item_index(REDO_ID), !main_control.is_redo_possiable())


func _on_id_pressed(id: int) -> void:
	match id:
		UNDO_ID:
			main_control.undo_action()
		REDO_ID:
			main_control.redo_action()
		_:
			push_warning("EditPopupMenu lacks support for \"{text}\" or {id}".format( {"text" : get_item_text(get_item_index(id)), "id" : id} ) )
	
	main_control.update()
