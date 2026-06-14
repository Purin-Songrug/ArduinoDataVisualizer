extends HBoxContainer

@onready var label: Label = $Label

func _on_delete_button_pressed() -> void:
	get_tree().get_first_node_in_group("Root")._delete_variable(label.text)
