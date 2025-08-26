class_name FileDownloadDialog
extends Window


signal file_selected(path: String)


@export var fliters: PackedStringArray


@onready var       line_edit:     LineEdit = %LineEdit
@onready var   option_button: OptionButton = %OptionButton
@onready var download_button:       Button = %DownloadButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if fliters.is_empty():
		option_button.hide()
	else:
		option_button.clear()
		
		for i in fliters:
			var comma_loc_0 := i.find(";")
			var comma_loc_1 := -1
			
			if comma_loc_0 != -1 and len(i) > comma_loc_0:
				comma_loc_1 = i.find(";", comma_loc_0 + 2)
			
			var regex: String = i.substr(0, comma_loc_0)
			
			if comma_loc_0 == -1:
				option_button.add_item(regex)
				continue
				
			var description: String = i.substr(comma_loc_0 + 1, comma_loc_1 - comma_loc_0 - 1)
			#var identifier:  String = i.substr(comma_loc_1 + 1)
			
			option_button.add_item(regex + " (" + description + ")")
			
		option_button.select(0)


func _on_close_requested() -> void:
	hide()


func _on_cancel_button_pressed() -> void:
	hide()


func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		download_button.disabled = true
	else:
		download_button.disabled = false


func _on_download_button_pressed() -> void:
	assert(!line_edit.text.is_empty())
	
	# Clean away the line edits text first
	var cleaned_string: String = line_edit.text.validate_filename()
	
	if option_button.item_count != 0:
		var regex := RegEx.new()
		regex.compile("\\*\\.\\w+;")
		
		var search := regex.search(fliters[option_button.get_item_index(option_button.get_selected_id())])
		
		if search and cleaned_string.get_extension() != search.strings[0].substr(2, len(search.strings[0]) - 3):
			# Strip out the extensions
			cleaned_string = cleaned_string.get_basename().get_file()
			
			# Give a new extension
			cleaned_string += "." + search.strings[0].substr(2, len(search.strings[0]) - 3)
	
	if line_edit.text != cleaned_string:
		line_edit.text = cleaned_string
		return # Give the user a chance to see the new file name.
		
	
	file_selected.emit(line_edit.text)
	hide()
