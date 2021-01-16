# Macros for FPGA Synthesis

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_180SHIFT         | MiSTer  | Use DDIO cell instead of PLL to create the SDRAM phase shift
JTFRAME_4PLAYERS         |         | Extra inputs for 4 players
JTFRAME_ANALOG           |         | Enables analog sticks
JTFRAME_ARX              | MiSTer  | Defines aspect ratio
JTFRAME_ARY              | MiSTer  | Defines aspect ratio
JTFRAME_AVATARS          |         | Enables avatars on credits screen
JTFRAME_CLK24            |         | Adds an additional clock input
JTFRAME_CLK48            |         | Adds an additional clock input
JTFRAME_CLK6             |         | Adds an additional clock input
JTFRAME_CLK96            |         | Adds an additional clock input
JTFRAME_CREDITS          |         | Adds credits screen
JTFRAME_CREDITS_AON      |         | credits screen is always on
JTFRAME_CREDITS_PAGES    |         | number of pages of credits text
JTFRAME_DONTSIM_SCAN2X   |         | Internal. Do not define externally
JTFRAME_DUAL_RAM_DUMP    |         | Enables dumping of RAM contents in simulation
JTFRAME_DWNLD_PROM_ONLY  |         | Quick download sim with only PROM contents
JTFRAME_FLIP_RESET       |         | Varying the flip DIP setting causes a reset
JTFRAME_INTERLACED       |         | Support for interlaced games
JTFRAME_MIST_DIPBASE     | MiST    | Starting base in status word for MiST dip switches
JTFRAME_MIST_DIRECT      | MiST    | On by default. Define as 0 to disable. Fast ROM load
JTFRAME_MRA_DIP          |         | DIPs are in an MRA file
JTFRAME_MR_FASTIO        | MiSTer  | 16-bit ROM load in MiSTer
JTFRAME_NOHOLDBUS        |         | Reduces bus noise (non-interleaved SDRAM controller)
JTFRAME_OSDCOLOR         |         | Sets the OSD colour
JTFRAME_OSD_FLIP         |         | flip option on OSD
JTFRAME_OSD_NOCREDITS    |         | No credits option on OSD
JTFRAME_OSD_NOLOAD       |         | No load option on OSD
JTFRAME_OSD_SND_EN       |         | OSD option to enable/disable FX and FM channels
JTFRAME_OSD_VOL          |         | Show FX volume control on OSD
JTFRAME_OSD_TEST         |         | Test option on OSD
JTFRAME_RELEASE          |         | Disables gfx_en control via keyboard
JTFRAME_SAVESDRAM        |         | Saves SDRAM contents at the end of each frame (slow)
JTFRAME_SCAN2X_NOBLEND   | MiST    | Disables pixel blending
JTFRAME_SDRAM96          |         | SDRAM is clocked at 96MHz and the clk input of game is 96MHz
JTFRAME_SDRAM_ADQM       | MiSTer  | A12 and A11 are equal to DQMH/L
JTFRAME_SDRAM_BANKS      |         | Game module ports will support interleaved bank access
JTFRAME_SDRAM_BWAIT      |         | Adds a wait cycle in the SDRAM
JTFRAME_SDRAM_CHECK      |         | Double check SDRAM data through modules (slow)
JTFRAME_SDRAM_DEBUG      |         | Outputs debug messages for SDRAM during simulation
JTFRAME_SDRAM_MUXLATCH   |         | Extra latch for SDRAM mux for <64MHz operation
JTFRAME_SDRAM_NO_DWNRFSH |         | No refresh during download (non-interleaved SDRAM controller)
JTFRAME_SDRAM_REPACK     |         | Extra latch stage at SDRAM mux output
JTFRAME_SDRAM_STATS      |         | Produce SDRAM usage data during simulation
JTFRAME_VERTICAL         |         | Enables support for vertical games

# Simulation-only Macros

The following macros only have an effect if SIMULATION is defined.

Macro                    | Target  |  Usage
-------------------------|---------|---------------------------------------------
JTFRAME_SIM_ROMRQ_NOCHECK|         | Disable protocol checking of romrq
JTFRAME_SIM_DIPS         |         | Define DIP switch values during simulation
JTFRAME_SIM_LOAD_EXTRA   |         | Extra wait time when transferring ROM in simulation
JTFRAME_SIM_SCAN2X       |         | Enables scan doubler simulation
SIMULATION               |         | Enables simulation features
LOADROM                  |         | Sends ROM data via serial interface
DUMP_VIDEO               |         | Enables video dump to a file
DUMP_VIDEO_FNAME         |         | Internal. Do not assign.
VIDEO_START              |         | First frame for which video output is provided
                         |         | use it to prevent a split first frame