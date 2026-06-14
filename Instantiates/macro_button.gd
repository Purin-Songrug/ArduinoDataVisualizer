extends Button

@export var macro_name: String
@export var macro_action: String

func _set_macro(new_name: String, new_action: String) -> void:
	macro_name = new_name
	text = new_name
	macro_action = new_action

func _on_pressed() -> void:
	get_tree().get_first_node_in_group("Root")._macro_pressed(macro_action)
