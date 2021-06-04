# Compilation

All JT arcade cores depend on JTFRAME for compilation:

* [CAPCOM arcades prior to CPS1](https://github.com/jotego/jt_gng)
* [CAPCOM SYSTEM](https://github.com/jotego/jtcps1)
* [Technos Double Dragon 1 & 2](https://github.com/jotego/jtdd) arcade games
* [Konami Contra](https://github.com/jotego/jtcontra)
* [Nintendo Popeye](https://github.com/jotego/jtpopeye)
* etc.

These are the compilation steps:

1. You need linux. I use Ubuntu mate but any linux will work
2. You need 32-bit support if you're going to compile MiST/SiDi cores
3. There are some linux dependencies that you can sort out with `sudo apt install`, I will eventually list them
4. Populate the arcade core repository including submodules recursively. I believe in using submodules to break up tasks and sometimes submodules may have their own submodules. So be sure to populate the repository recursively. Be sure to understand how git submodules work
5. Now jtframe should be located in `core-folder/modules/jtframe` go there and enter the `cc` folder. Run `make`. Make sure all files compile correctly and install whatever you need to make them compile. All should be in your standard linux software repository. Nothing fancy is needed
6. Now go to the `core-folder` and run `source setprj.sh`
7. Now you can compile the core using the `jtcore` script.

The complete list of possible verilog macros is in [here](doc/macros.md).

## jtcore

jtcore is the script used to compile the cores. It does a lot of stuff and it does it very well. Taking as an example the [CPS0 games](https://github.com/jotego/jt_gng), these are some commands:

`jtcore gng -sidi`

Compiles Ghosts'n Goblins core for SiDi.

`jtcore tora -mister`

Compiles Tiger Road core for MiSTer.

Some cores, particularly if they only produce one RBF file, may alias jtcore. For [CPS1](https://github.com/jotego/jtcps1) do:

`jtcore -mister`

And that will produce the MiSTer version.

jtcore can also program the FPGA (MiST or MiSTer) with the ```-p``` option. In order to use an USB Blaster cable in Ubuntu you need to setup two urules files. The script **jtblaster** does that for you.

