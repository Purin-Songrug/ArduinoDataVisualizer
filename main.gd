extends Control

@export_group("Connection")
@export var port_selector: OptionButton
@export var baud_selector: LineEdit
@export var connect_button: Button
@export var refresh_button: Button

#Default baud rate
var BAUD_RATE: int = 115200
var serial: GdSerial
var is_connected_to_port: bool = false

@export_group("Output")
@export var output_label: Label
@export var scroll_container: ScrollContainer
@export var output_resizer: Button
@export var message_input: LineEdit
@export var send_button: Button

@export_group("Graph")
@export var x_axis_mover: HScrollBar
@export var graph_2d: Graph2D
@export var data_chooser: OptionButton
@export var y_min_input: LineEdit
@export var y_max_input: LineEdit

#Graph variables
var graph_right_bound := 10.0
var amount_visible := 10.0
var move_amount := 6.0
var data_time_passed_initial_max := false
var data

@export_group("Sidebar")
@export var sidebar: Panel
@export var middle_resize_button: Button
@export var macros_container: GridContainer
@export var macros_collapse_button: Button
@export var edit_macros_button: Button
@export var add_macro_button: Button
@export var edit_macros_container: VBoxContainer
@export var variables_container: VBoxContainer
@export var variables_collapse_button: Button
@export var export_container: VBoxContainer
@export var export_collapse_button: Button
@export var export_csv_button: Button
@export var export_start: LineEdit
@export var export_end: LineEdit

var sidebar_visible := true
var macros_visible := true
var edit_macros := false
var variables_visible := true
var export_visible := true

const MACRO_BUTTON = preload("uid://dyety4dpsq0b2")
const MACRO_EDIT = preload("uid://d1vyb0a6uehvp")

@export var no_variables_text: RichTextLabel
const VARIABLE_MONITOR = preload("uid://cvb3dob0vvbf7")
var TRACKED_VARIABLES_NAMES: Array[String]
var VARIABLE_INSTANCES: Array

var graphed_variable_name: String
var graphed_variable_value: float

#Pre-compile the regex once at the top of the script
var packet_regex: RegEx = RegEx.new()

var CSV_EXPORT: Array[Array] = [["Time","Raw Data"]]
var CSV_PATH := "user://data.csv"

func _ready() -> void:
	serial = GdSerial.new()
	
	_refresh_serial_ports()
	
	packet_regex.compile("^\\[\\]([a-zA-Z0-9_]+):(.+)$")
	
	data = graph_2d.add_plot_item("", Color.CORAL, 0.5)
	
	#Connect signals
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	connect_button.pressed.connect(_on_connect_toggled)
	x_axis_mover.value_changed.connect(_on_x_axis_mover_value_changed)
	baud_selector.text_changed.connect(_on_baud_selector_text_changed)
	data_chooser.item_selected.connect(_on_data_chooser_select)
	y_min_input.text_submitted.connect(_on_y_min_changed)
	y_max_input.text_submitted.connect(_on_y_max_changed)
	output_resizer.button_down.connect(_on_output_resizer_button_down)
	output_resizer.button_up.connect(_on_output_resizer_button_up)
	send_button.pressed.connect(_on_send_button_pressed)
	
	middle_resize_button.pressed.connect(_on_middle_resize_button_pressed)
	macros_collapse_button.pressed.connect(_on_collapse_macros_button_pressed)
	edit_macros_button.pressed.connect(_on_edit_macros_button_pressed)
	add_macro_button.pressed.connect(_on_add_macro_button_pressed)
	export_csv_button.pressed.connect(_on_export_CSV_button_pressed)
	variables_collapse_button.pressed.connect(_on_collapse_variables_button_pressed)
	export_collapse_button.pressed.connect(_on_collapse_export_button_pressed)
	
func _refresh_serial_ports() -> void:
	port_selector.clear()
	var ports = serial.list_ports()
	
	print("GDSerial detected ports structure: ", ports)
	
	if ports.is_empty():
		output_label.text = "System Check: No active serial ports detected.\n"
		connect_button.disabled = true
		return
		
	# Iterate through the inner dictionaries
	for key in ports:
		var port_info = ports[key]
		if port_info.has("port_name"):
			var visual_label = port_info["port_name"]
			
			if port_info.has("device_name") and port_info["device_name"] != "":
				visual_label = port_info["device_name"]
			
			# Add item to dropdown
			var current_idx = port_selector.get_item_count()
			port_selector.add_item(visual_label)
			
			# Store the underlying system port name (e.g., "COM3") as hidden item metadata
			port_selector.set_item_metadata(current_idx, port_info["port_name"])
			
	if port_selector.get_item_count() == 0:
		output_label.text = "System Check: No valid port configurations parsed.\n"
		connect_button.disabled = true
	else:
		connect_button.disabled = false

func _on_connect_toggled() -> void:
	if not is_connected_to_port:
		var selected_idx = port_selector.selected
		
		# Pull the specific system string token back out of the metadata container
		var target_port = port_selector.get_item_metadata(selected_idx)
		
		if target_port == null or target_port == "":
			output_label.text = "Connection Failure: Selected option does not contain valid port metadata.\n"
			return
		if baud_selector.text.is_valid_int():
			BAUD_RATE = int(baud_selector.text)
		else:
			BAUD_RATE = 115200
			baud_selector.text = "115200"
			
		serial.set_port(target_port)
		serial.set_baud_rate(BAUD_RATE)
		
		if serial.open():
			is_connected_to_port = true
			connect_button.text = "Disconnect"
			output_label.text = "Successfully connected to %s\n" % target_port
		else:
			output_label.text = "Connection Failure: Unable to open %s. Is it in use elsewhere?\n" % target_port
	else:
		serial.close()
		is_connected_to_port = false
		connect_button.text = "Connect"
		output_label.text += "Serial stream safely terminated.\n"

var ignoreXMover := false #Don't allow movement of x axis initially until more data is collected
var TIME := 0.0

func _process(delta: float) -> void:
	if is_connected_to_port:
		# GdSerial non-block-reads data up to the newline delimiter
		var raw_data = serial.readline()
		
		if graphed_variable_name == "Raw Data":
			# If data exists in the transaction buffer, clear line endings and print
			if raw_data != "":
				_append_to_terminal(raw_data.strip_edges())
			data.add_point(Vector2(TIME, float(raw_data.strip_edges())))
		else:
			data.add_point(Vector2(TIME, graphed_variable_value))
			_append_to_terminal(str(graphed_variable_value))
		_manage_variables(raw_data.strip_edges(), TIME)
		
		TIME += delta
		if TIME > graph_2d.x_max and x_axis_mover.value == x_axis_mover.max_value:
			ignoreXMover = true
			x_axis_mover.max_value = snappedf(TIME-move_amount, 2.0)
			x_axis_mover.value = snappedf(TIME-move_amount, 2.0)
			
			graph_2d.x_max += move_amount
			graph_right_bound += move_amount
			graph_2d.x_min += move_amount
			data_time_passed_initial_max = true
		
		elif TIME > graph_2d.x_max:
			x_axis_mover.max_value = snappedf(TIME-move_amount, 2.0)
			
func _append_to_terminal(incoming_text: String) -> void:
	output_label.text += incoming_text + "\n"
	
	# Automatically pin the scroll container viewport down to read newer inputs
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(output_label.size.y)
	
func _on_baud_selector_text_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		BAUD_RATE = int(new_text)
	
func _on_x_axis_mover_value_changed(value: float) -> void:
	if not ignoreXMover and data_time_passed_initial_max:
		graph_right_bound = value
		
		# Check if moving right or left to avoid plugin clamping
		if value > graph_2d.x_min:
			#Right
			graph_2d.x_max = value + amount_visible
			graph_2d.x_min = value
		else:
			#Left
			graph_2d.x_min = value
			graph_2d.x_max = value + amount_visible

	else:
		ignoreXMover = false

var is_dragging: bool = false

const min_height: float = 20.0

func _on_output_resizer_button_down() -> void:
	is_dragging = true

func _on_output_resizer_button_up() -> void:
	is_dragging = false

func _manage_variables(line: String, time: float) -> void:
	line = line.strip_edges()

	var result = packet_regex.search(line)
	if not result:
		return #Bad data
		
	# Get clean data from the regex capture groups
	var variable_name: String = result.get_string(1)
	var variable_value: String = result.get_string(2)
	var set_text: String = variable_name + ":" + variable_value

	# Update or Create UI elements
	if TRACKED_VARIABLES_NAMES.has(variable_name):
		var variable_index = TRACKED_VARIABLES_NAMES.find(variable_name)
		VARIABLE_INSTANCES[variable_index].get_child(0).text = set_text
		
		
		var save_index = CSV_EXPORT[0].find(variable_name)
		var append = []
		append.append(time)
		append.append(line)
		for i in range(save_index-2):
			append.append("")
		append.append(variable_value)
		for i in range(CSV_EXPORT[0].size()-save_index-1):
			append.append("")
		
		CSV_EXPORT.append(append)
	else:
		print("Registered new variable: ", variable_name) 
		
		TRACKED_VARIABLES_NAMES.append(variable_name)
		var new = VARIABLE_MONITOR.instantiate()
		new.get_child(0).text = set_text
		variables_container.add_child(new)
		VARIABLE_INSTANCES.append(new)
		
		data_chooser.clear()
		data_chooser.add_item("Raw Data")
		for item in TRACKED_VARIABLES_NAMES:
			data_chooser.add_item(item)
		data_chooser.selected = 1
		graphed_variable_name = data_chooser.get_item_text(1)
		
		CSV_EXPORT[0].append(variable_name)
	
	#Show no variable dialouge if none
	if TRACKED_VARIABLES_NAMES.size() > 0:
		no_variables_text.visible = false
	else:
		no_variables_text.visible = true
	
	#Update graph
	if graphed_variable_name == variable_name:
		graphed_variable_value = float(variable_value)
	
func _delete_variable(delete: String) -> void:
	
	var variable_name : String

	# Split by the colon and take the first part
	variable_name = delete.split(":")[0]
	
	var index = TRACKED_VARIABLES_NAMES.find(variable_name)
	TRACKED_VARIABLES_NAMES.remove_at(index)
	VARIABLE_INSTANCES[index].queue_free()
	VARIABLE_INSTANCES.remove_at(index)
	
	var selected_text = data_chooser.get_item_text(data_chooser.selected)
	data_chooser.clear()
	data_chooser.add_item("Raw Data")
	for item in TRACKED_VARIABLES_NAMES:
		data_chooser.add_item(item)
	data_chooser.selected = _get_item_index_by_text(data_chooser, selected_text)
	graphed_variable_name = selected_text
	
func _get_item_index_by_text(button: OptionButton, text_to_find: String) -> int:
	for i in range(button.item_count):
		if button.get_item_text(i) == text_to_find:
			return i # Returns the index
			
	return 0 # Not found

func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseMotion:
		var delta_y = event.relative.y
		
		# Calculate what the new height would be
		var new_height = scroll_container.custom_minimum_size.y - delta_y
		
		if new_height >= min_height and (graph_2d.size.y > graph_2d.custom_minimum_size.y or event.relative.y>0):
			scroll_container.custom_minimum_size.y = new_height

	# Stop dragging if the mouse is released outside the window
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			is_dragging = false

func _on_refresh_button_pressed() -> void:
	_refresh_serial_ports()

func _on_middle_resize_button_pressed() -> void:
	if sidebar_visible:
		sidebar.visible = false
		sidebar_visible = false
		middle_resize_button.text = "◀"
	else:
		sidebar.visible = true
		sidebar_visible = true
		middle_resize_button.text = "▶"

func _on_collapse_macros_button_pressed() -> void:
	if macros_visible:
		macros_container.visible = false
		macros_visible = false
		macros_collapse_button.text = "▲"
		edit_macros = false
		edit_macros_container.visible = false
	else:
		macros_container.visible = true
		macros_visible = true
		macros_collapse_button.text = "▼"

func _on_collapse_variables_button_pressed() -> void:
	if variables_visible:
		variables_container.visible = false
		variables_visible = false
		variables_collapse_button.text = "▲"
	else:
		variables_container.visible = true
		variables_visible = true
		variables_collapse_button.text = "▼"

func _on_collapse_export_button_pressed() -> void:
	if export_visible:
		export_container.visible = false
		export_visible = false
		export_collapse_button.text = "▲"
	else:
		export_container.visible = true
		export_visible = true
		export_collapse_button.text = "▼"

func _on_edit_macros_button_pressed() -> void:
	if edit_macros:
		edit_macros_container.visible = false
		edit_macros = false
	else:
		edit_macros_container.visible = true
		edit_macros = true
		macros_container.visible = true
		macros_visible = true
		macros_collapse_button.text = "▼"

func _on_add_macro_button_pressed() -> void:
	var new_macro = MACRO_BUTTON.instantiate()
	macros_container.add_child(new_macro)
	var new_edit = MACRO_EDIT.instantiate()
	new_edit.macro_container = macros_container
	edit_macros_container.add_child(new_edit)
	
func _macro_pressed(macro_action) -> void:
	serial.writeline(str(macro_action))

func _on_send_button_pressed() -> void:
	serial.writeline(str(message_input.text))

func _on_data_chooser_select(index: int) -> void:
	graphed_variable_name = data_chooser.get_item_text(index)

func _on_y_min_changed(text: String) -> void:
	graph_2d.y_min = float(text)
	
func _on_y_max_changed(text: String) -> void:
	graph_2d.y_max = float(text)

# Connect button to open the FileDialog
func _on_export_CSV_button_pressed() -> void:
	var file_dialog = FileDialog.new()
	
	file_dialog.use_native_dialog = true 
	
	# Configure the dialog for saving a file
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM 
	file_dialog.filters = PackedStringArray(["*.csv ; CSV Files"]) 
	file_dialog.current_file = "export.csv" 
	
	# Connect and show
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	add_child(file_dialog)
	file_dialog.popup()


# This function runs AFTER the user picks a location and hits "Save"
func _on_file_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file:
		for row in CSV_EXPORT:
			var start_condition := export_start.text == "" or float(row[0]) > float(export_start.text)
			var end_condition := export_end.text == "" or float(row[0]) < float(export_end.text)
			
			if start_condition and end_condition:
				file.store_csv_line(row)
			
		file.close()
		print("CSV successfully exported to: ", path)
	else:
		var error = FileAccess.get_open_error()
		print("Failed to export CSV. Error code: ", error)
