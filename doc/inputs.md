# Joysticks
By default JTFRAME supports two joysticks only and will try to connect to game modules based on this assumption. For games that need four joysticks, define the macro **JTFRAME_4PLAYERS**.
Note that the registers containing the coin and start button inputs are always passed as 4 bits, but the game can just ignore the 2 MSB if it only supports two players.

Analog controllers are not connected to the game module by default. In order to get them connected, define the macro **JTFRAME_ANALOG** and then these input ports:

```
    input   [15:0]  joystick_analog_0,
    input   [15:0]  joystick_analog_1,
```

Support for 4-way joysticks (instead of 8-way joysticks) is enabled by setting high bit 1 of core_mod. See MOD BYTE.