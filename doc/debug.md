# Debugging

If JTFRAME_RELEASE is not defined, the debug features can be used.

## GFX Enable Bus

keys F7-F10 will toggle bits in the gfx_en bus. After reset all bits are high. These bits are meant to be used to enable/disable graphic layers.

## Generic 8-bit Debug bus

If JTFRAME_DEBUG is defined, keys + and - (in a Spanish keyboard layout) will increase and decrease the 8-bit debug_bus.

The game module must define the debug_bus input if JTFRAME_DEBUG is used.