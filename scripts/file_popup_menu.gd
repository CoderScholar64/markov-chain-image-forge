extends PopupMenu


@export var main_control: MCIGenerator


@onready var confirm_exit_dialog: ConfirmationDialog = %ExitWithoutSavingDialog
@onready var open_model_dialog:           FileDialog = %OpenModelDialog
@onready var save_as_popup_menu_download:     Window = %SaveAsPopupMenuDownload
@onready var save_as_popup_menu_browser:  FileDialog = %SaveAsModelDialog
@onready var open_model_from_image_window:    Window = %ModelFromImageWindow


const OPEN_MODEL_FROM_IMAGE_ID := 0
const OPEN_A_MODEL_FILE_ID := 1
const SAVE_ID := 2
const SAVE_AS_ID := 3
const QUIT_ID := 4


func _ready() -> void:
	get_tree().root.close_requested.connect(Callable(self, "_on_close_event"))
	
	# Disable file browsing if using web based builds.
	# TODO Figure out how to support broswing and uploading.
	if OS.has_feature("web"):
		set_item_disabled(get_item_index(OPEN_A_MODEL_FILE_ID), true)
		set_item_tooltip(get_item_index(OPEN_A_MODEL_FILE_ID), "Sorry, for now browsing for files is not support this web build.\nYou must drag the file instead or use the Desktop builds.")


func update() -> void:
	if main_control.model_data and main_control.model_data is Dictionary:
		set_item_disabled(get_item_index(SAVE_AS_ID), false)
	else:
		set_item_disabled(get_item_index(SAVE_AS_ID), true)
	
	if main_control.model_save_path and main_control.model_save_path is String and main_control.model_save_path != "":
		set_item_disabled(get_item_index(SAVE_ID), false)
	else:
		set_item_disabled(get_item_index(SAVE_ID), true)
		


func _on_id_pressed(id: int) -> void:
	match id:
		QUIT_ID:
			_on_close_event()
		OPEN_A_MODEL_FILE_ID:
			open_model_dialog.show()
		OPEN_MODEL_FROM_IMAGE_ID:
			open_model_from_image_window.show_up()
		SAVE_ID:
			main_control._on_save_as_model_dialog_file_selected(main_control.model_save_path)
		SAVE_AS_ID:
			if OS.has_feature("web"):
				save_as_popup_menu_download.show()
			else:
				save_as_popup_menu_browser.show()
		_:
			push_warning("FilePopupMenu lacks support for \"{text}\" or {id}".format( {"text" : get_item_text(get_item_index(id)), "id" : id} ) )


func _on_close_event() -> void:
	if main_control.has_unsaved_data:
		confirm_exit_dialog.show()
	else:
		_on_exit_without_saving_dialog_confirmed()


func _on_exit_without_saving_dialog_confirmed() -> void:
	get_tree().quit(0)
