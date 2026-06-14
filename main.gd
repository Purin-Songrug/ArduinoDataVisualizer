extends Control

@export_group("Connection")
@export var port_selector: OptionButton
@export var baud_selector: LineEdit
@export var connect_button: Button
@export var refresh_button: Button

var BAUD_RATE: int = 115200
var serial: GdSerial
var is_connected_to_port: bool = false

@export_group("Output")
@export var output_label: Label
@export var scroll_container: ScrollContainer
@export var output_resizer: Button

@export_group("Graph")
@export var x_axis_mover: HScrollBar
@export var graph_2d: Graph2D

var graphRightBound := 10.0
var amountVisible := 10.0
var dataTimePassedInitialMax := false
var data

@export_group("Sidebar")
@export var sidebar: ScrollContainer
@export var middleResizeButton: Button
@export var macrosContainer: GridContainer
@export var macrosCollapseButton: Button
@export var editMacrosButton: Button
@export var addMacroButton: Button
@export var editMacrosContainer: VBoxContainer
@export var variablesContainer: VBoxContainer
@export var variablesCollapseButton: Button
@export var exportContainer: VBoxContainer
@export var exportCollapseButton: Button

var sidebarVisible := true
var macrosVisible := true
var editMacros := false
var variablesVisible := true
var exportVisible := true

const MACRO_BUTTON = preload("uid://dyety4dpsq0b2")
const MACRO_EDIT = preload("uid://d1vyb0a6uehvp")

func _ready() -> void:
	serial = GdSerial.new()
	_refresh_serial_ports()
	
	
	data = graph_2d.add_plot_item("Data", Color.CORAL, 0.5)
	
	#Connect signals
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	connect_button.pressed.connect(_on_connect_toggled)
	x_axis_mover.value_changed.connect(_on_x_axis_mover_value_changed)
	baud_selector.text_changed.connect(_on_baud_selector_text_changed)
	output_resizer.button_down.connect(_on_output_resizer_button_down)
	output_resizer.button_up.connect(_on_output_resizer_button_up)
	
	middleResizeButton.pressed.connect(_on_middle_resize_button_pressed)
	macrosCollapseButton.pressed.connect(_on_collapse_macros_button_pressed)
	editMacrosButton.pressed.connect(_on_edit_macros_button_pressed)
	addMacroButton.pressed.connect(_on_add_macro_button_pressed)
	
	variablesCollapseButton.pressed.connect(_on_collapse_variables_button_pressed)
	exportCollapseButton.pressed.connect(_on_collapse_export_button_pressed)
	
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
			
			# If you want a descriptive drop-down label for your users:
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
var ignoreXMover := false
var TIME := 0.0
func _process(delta: float) -> void:
	if is_connected_to_port:
		# GdSerial non-block-reads data up to the newline delimiter
		var raw_data = serial.readline()
		
		# If data exists in the transaction buffer, clear line endings and print
		if raw_data != "":
			_append_to_terminal(raw_data.strip_edges())
		data.add_point(Vector2(TIME, float(raw_data.strip_edges())))
		
		TIME += delta
		if TIME > graph_2d.x_max and x_axis_mover.value == x_axis_mover.max_value:
			ignoreXMover = true
			x_axis_mover.max_value = snappedf(TIME-6.0, 2.0)
			x_axis_mover.value = snappedf(TIME-6.0, 2.0)
			
			graph_2d.x_max += 6.0
			graphRightBound += 6.0
			graph_2d.x_min += 6.0
			dataTimePassedInitialMax = true
		
		elif TIME > graph_2d.x_max:
			x_axis_mover.max_value = snappedf(TIME-6.0, 2.0)
			
func _append_to_terminal(incoming_text: String) -> void:
	output_label.text += incoming_text + "\n"
	
	# Automatically pin the scroll container viewport down to read newer inputs
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(output_label.size.y)
	
var old_text := ""
func _on_baud_selector_text_changed(new_text: String) -> void:
	if new_text.is_valid_int():
		BAUD_RATE = int(new_text)
	
func _on_x_axis_mover_value_changed(value: float) -> void:
	if not ignoreXMover and dataTimePassedInitialMax:
		graphRightBound = value
		
		# Check if we are moving right or left to avoid plugin clamping
		if value > graph_2d.x_min:
			# Moving Right: Update max first, then min
			graph_2d.x_max = value + amountVisible
			graph_2d.x_min = value
		else:
			# Moving Left: Update min first, then max
			graph_2d.x_min = value
			graph_2d.x_max = value + amountVisible

	else:
		ignoreXMover = false

var is_dragging: bool = false

const min_height: float = 20.0

func _on_output_resizer_button_down() -> void:
	is_dragging = true

func _on_output_resizer_button_up() -> void:
	is_dragging = false

func _input(event: InputEvent) -> void:
	
	# We use global _input so dragging still works if the mouse moves too fast 
	# and leaves the button area for a frame.
	if is_dragging and event is InputEventMouseMotion:
		print(is_dragging)
		# event.relative.y is how many pixels the mouse moved vertically this frame
		var delta_y = event.relative.y
		
		# Calculate what the new height would be
		# Dragging UP means delta_y is negative, so we subtract it to INCREASE height
		var new_height = scroll_container.custom_minimum_size.y - delta_y
		
		if new_height >= min_height and (graph_2d.size.y > graph_2d.custom_minimum_size.y or event.relative.y>0):
			scroll_container.custom_minimum_size.y = new_height

	# Safety check: Stop dragging if the mouse is released outside the window
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			is_dragging = false

func _on_refresh_button_pressed() -> void:
	_refresh_serial_ports()

func _on_middle_resize_button_pressed() -> void:
	if sidebarVisible:
		sidebar.visible = false
		sidebarVisible = false
		middleResizeButton.text = "◀"
	else:
		sidebar.visible = true
		sidebarVisible = true
		middleResizeButton.text = "▶"

func _on_collapse_macros_button_pressed() -> void:
	if macrosVisible:
		macrosContainer.visible = false
		macrosVisible = false
		macrosCollapseButton.text = "▲"
		editMacros = false
		editMacrosContainer.visible = false
	else:
		macrosContainer.visible = true
		macrosVisible = true
		macrosCollapseButton.text = "▼"

func _on_collapse_variables_button_pressed() -> void:
	if variablesVisible:
		variablesContainer.visible = false
		variablesVisible = false
		variablesCollapseButton.text = "▲"
	else:
		variablesContainer.visible = true
		variablesVisible = true
		variablesCollapseButton.text = "▼"

func _on_collapse_export_button_pressed() -> void:
	if exportVisible:
		exportContainer.visible = false
		exportVisible = false
		exportCollapseButton.text = "▲"
	else:
		exportContainer.visible = true
		exportVisible = true
		exportCollapseButton.text = "▼"

func _on_edit_macros_button_pressed() -> void:
	if editMacros:
		editMacrosContainer.visible = false
		editMacros = false
	else:
		editMacrosContainer.visible = true
		editMacros = true
		macrosContainer.visible = true
		macrosVisible = true
		macrosCollapseButton.text = "▼"

func _on_add_macro_button_pressed() -> void:
	var new_macro = MACRO_BUTTON.instantiate()
	macrosContainer.add_child(new_macro)
	var new_edit = MACRO_EDIT.instantiate()
	new_edit.macro_container = macrosContainer
	editMacrosContainer.add_child(new_edit)
	
