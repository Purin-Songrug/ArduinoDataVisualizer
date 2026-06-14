
# Arduino Serial Data Visualizer

A dashboard to send and receive serial data for Arduinos, ESP32s, and other microcontrollers/serial devices.


## Acknowledgements

 - [GD Serial](https://github.com/SujithChristopher/gdserial)
 - [Graph 2d](https://github.com/LD2Studio/godot4-graph2d)

## Features

- Line graph of incoming data
- Serial output
- Serial messager
- Customizable macros
- Variable monitor
- Export data to CSV 


## Screenshots

![App Screenshot](https://github.com/user-attachments/assets/7e51997d-65c2-42fd-99b2-77d1863069ee)


## Usage/Examples

To read a variable in the variable monitor:

```cpp
value = 43
Serial.print(F("[]VariableName:"));
Serial.println(Value);
```

- Tracks a variable named "VariableName" and gives it a value of 43

The "[]" denotes to track it and the ":" separates the name from the value

It will read any normal println as well:

```cpp
Serial.println(Value);
```

- Can graph this when it is set to "Raw Data" and print in the output as well
