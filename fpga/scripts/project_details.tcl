# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
#
# Description:
# Project detiles required for generate_bitstream.tcl
# Make sure that project_name, top_module and target are correct.
# Provide paths to all the files required for synthesis and implementation.
# Depending on the file type, it should be added in the corresponding section.
# If the project does not use files of some type, leave the corresponding section commented out.

#-----------------------------------------------------#
#                   Project details                   #
#-----------------------------------------------------#
# Project name                                  -- EDIT
set project_name game_project

# Top module name                               -- EDIT
set top_module top_vga_basys3

# FPGA device
set target xc7a35tcpg236-1

#-----------------------------------------------------#
#                    Design sources                   #
#-----------------------------------------------------#
# Specify .xdc files location                   -- EDIT
set xdc_files {
    constraints/top_vga_basys3.xdc
}

# Specify SystemVerilog design files location   -- EDIT
set sv_files {
    ../rtl/ai/top_sensor.sv
    ../rtl/ai/ring_buffer.sv   
    ../rtl/bjack_fsm/bjack_fsm_pkg.sv
    ../rtl/bjack_fsm/bjack_fsm.sv    
    ../rtl/spi/lsm6dso_ctrl.sv
    ../rtl/spi/lsm6dso_pkg.sv
    ../rtl/spi/spi_ce_gen.sv
    ../rtl/spi/spi_master.sv
    ../rtl/top_game.sv
    rtl/top_vga_basys3.sv
}

# Specify Verilog design files location         -- EDIT
# set verilog_files {
# }

# Specify VHDL design files location            -- EDIT
# set vhdl_files {
# }

# Specify files for a memory initialization     -- EDIT
# set mem_files {
#    path/to/file.data
# }
