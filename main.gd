extends Control

@export var port_selector: OptionButton
@export var baud_selector: LineEdit
@export var connect_button: Button
@export var output_label: Label
@export var scroll_container: ScrollContainer

@export var x_axis_mover: HScrollBar
var graphRightBound := 10.0

var amountVisible := 10.0

var data
@export var graph_2d: Graph2D

var BAUD_RATE: int = 115200
var serial: GdSerial
var is_connected: bool = false

func _ready() -> void:
	serial = GdSerial.new()
	_refresh_serial_ports()
	connect_button.pressed.connect(_on_connect_toggled)
	
	data = graph_2d.add_plot_item("Data", Color.CORAL, 0.5)
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
	if not is_connected:
		var selected_idx = port_selector.selected
		
		# Pull the specific system string token back out of the metadata container
		var target_port = port_selector.get_item_metadata(selected_idx)
		
		if target_port == null or target_port == "":
			output_label.text = "Connection Failure: Selected option does not contain valid port metadata.\n"
			return
		
		var selected_baud_rate = int(baud_selector.text)
		
		serial.set_port(target_port)
		serial.set_baud_rate(BAUD_RATE)
		
		if serial.open():
			is_connected = true
			connect_button.text = "Disconnect"
			output_label.text = "Successfully connected to %s\n" % target_port
		else:
			output_label.text = "Connection Failure: Unable to open %s. Is it in use elsewhere?\n" % target_port
	else:
		serial.close()
		is_connected = false
		connect_button.text = "Connect"
		output_label.text += "Serial stream safely terminated.\n"
var ignoreXMover := false
var TIME := 0.0
func _process(delta: float) -> void:
	if is_connected:
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
	if not ignoreXMover:
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

		print("Target Min: ", value)
		print("Target Max: ", value + amountVisible)
		print("Actual Min: ", graph_2d.x_min)
		print("Actual Max: ", graph_2d.x_max)
		print("-----")
	else:
		ignoreXMover = false
