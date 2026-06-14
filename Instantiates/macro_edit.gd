extends VBoxContainer

@export var macro_name: String
@export var macro_action: String

@onready var macro_name_input: LineEdit = $"Name and Delete Container/Macro Name"
@onready var macro_action_input: LineEdit = $"Macro Action"
@onready var send_types_input: OptionButton = $"HBoxContainer/Send Types"

#assinged by instantiator
@export var macro_container: GridContainer

func _ready() -> void:
	_setup("Name"+str(get_index()),"Action"+str(get_index()))
	_update_macro_button()

func _on_macro_name_text_changed(new_text: String) -> void:
	macro_name = new_text
	_update_macro_button()

func _on_macro_action_text_changed(new_text: String) -> void:
	macro_action = new_text
	_update_macro_button()

func _setup(new_name: String, new_action: String) -> void:
	send_types_input.selected = 0
	macro_name = new_name
	macro_name_input.text = new_name
	macro_action = new_action
	macro_action_input.text = new_action

func _update_macro_button() -> void:
	print(get_index()-1)
	var macro = macro_container.get_child(get_index()-1)
	
	macro._set_macro(macro_name, macro_action)

func _on_delete_button_pressed() -> void:
	macro_container.get_child(get_index()-1).queue_free()
	queue_free()
