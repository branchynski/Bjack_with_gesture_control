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
    constraints/clk_wiz_0.xdc
    constraints/clk_wiz_0_late.xdc
}

# Specify SystemVerilog design files location   -- EDIT
set sv_files {
    ../rtl/vga/vga_pkg.sv
    ../rtl/bjack_fsm/bjack_pkg.sv
    ../rtl/ai/ai_type_pkg.sv
    ../rtl/ai/sliding_window_buffer.sv
    ../rtl/ai/ring_buffer.sv
    ../rtl/vga/vga_if.sv
    ../rtl/vga/vga_timing.sv
    ../rtl/vga/draw_bg.sv
    ../rtl/vga/top_vga.sv
    ../rtl/vga/card_generator.sv
    ../rtl/vga/draw_start.sv
    ../rtl/vga/string/delay.sv
    ../rtl/vga/string/char_rom.sv
    ../rtl/vga/string/font_rom.sv
    ../rtl/vga/string/draw_rect_char.sv
    ../rtl/vga/string/top_string.sv
    ../rtl/vga/top_menu.sv
    ../rtl/bjack_fsm/bjack_fsm.sv
    ../rtl/bjack_fsm/bjack_datapath.sv
    ../rtl/bjack_fsm/bjack_money.sv
    ../rtl/card_drawing/card_drawing.sv
    ../rtl/uart/uart_protocol_ctrl.sv
    ../rtl/gesture_monitor.sv
    ../rtl/ai/top_sensor.sv
    ../rtl/spi/lsm6dso_ctrl.sv
    ../rtl/spi/lsm6dso_pkg.sv
    ../rtl/spi/spi_ce_gen.sv
    ../rtl/spi/spi_master.sv
    ../rtl/top_game.sv
    ../rtl/ai/top_gesture.sv
    ../rtl/ai/model_controller_fsm.sv
    ../rtl/gesture_tdebug.sv
    rtl/top_vga_basys3.sv
}

# Specify Verilog design files location         -- EDIT
set verilog_files {
    rtl/clk_wiz_0_clk_wiz.v
    rtl/clk_wiz_0.v
    ../rtl/ai/ml_sensor.v
    ../rtl/ai/ml_net/myproject.v
    ../rtl/ai/ml_net/myproject_compute_output_buffer_1d_array_array_ap_fixed_16_6_5_3_0_8u_config2_s.v 
    ../rtl/ai/ml_net/myproject_compute_output_buffer_1d_array_array_ap_fixed_16_6_5_3_0_8u_config6_s.v 
    ../rtl/ai/ml_net/myproject_compute_output_buffer_1d_array_array_config2_Pipeline_KernelShiftWidth.v 
    ../rtl/ai/ml_net/myproject_compute_output_buffer_1d_array_array_config6_Pipeline_KernelShiftWidth.v 
    ../rtl/ai/ml_net/myproject_conv_1d_cl_array_ap_fixed_6u_array_ap_fixed_16_6_5_3_0_8u_config2_s.v 
    ../rtl/ai/ml_net/myproject_conv_1d_cl_array_ap_fixed_8u_array_ap_fixed_16_6_5_3_0_8u_config6_s.v 
    ../rtl/ai/ml_net/myproject_conv_1d_cl_array_ap_int_16_6u_array_ap_fixed_16_6_5_3_0_8u_config2_s.v 
    ../rtl/ai/ml_net/myproject_dense_array_ap_fixed_32u_array_ap_fixed_16_6_5_3_0_3u_config15_s.v 
    ../rtl/ai/ml_net/myproject_dense_array_ap_fixed_8u_array_ap_fixed_16_6_5_3_0_32u_config12_s.v 
    ../rtl/ai/ml_net/myproject_dense_array_array_ap_fixed_16_6_5_3_0_32u_config12_Pipeline_DataPrepare.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_gt_nin_rem0_ap_fixed_ap_fixed_16_6_5_3_0_config15_s.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_gt_nin_rem0_ap_fixed_ap_fixed_16_6_5_3_0_config15_s_outidx_eOg.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_gt_nin_rem0_ap_fixed_ap_fixed_16_6_5_3_0_config15_s_w15_ROMfYi.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config12_s.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config12_s_w12_ROM_NP_dEe.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config2_mult_s.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config2_mult_s_w2_ROM_bkb.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config6_mult_s.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_fixed_ap_fixed_16_6_5_3_0_config6_mult_s_w6_ROM_cud.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_int_16_ap_fixed_16_6_5_3_0_config2_mult_s.v 
    ../rtl/ai/ml_net/myproject_dense_resource_rf_leq_nin_ap_int_16_ap_fixed_16_6_5_3_0_config2_mult_s_w2_ROMbkb.v 
    ../rtl/ai/ml_net/myproject_fifo_w128_d102_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w128_d25_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w256_d1_S.v 
    ../rtl/ai/ml_net/myproject_fifo_w320_d1_S.v
    ../rtl/ai/ml_net/myproject_fifo_w512_d1_S.v 
    ../rtl/ai/ml_net/myproject_fifo_w64_d102_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w64_d12_S.v 
    ../rtl/ai/ml_net/myproject_fifo_w64_d25_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w64_d51_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w80_d102_A.v 
    ../rtl/ai/ml_net/myproject_fifo_w80_d25_A.v 
    ../rtl/ai/ml_net/myproject_flow_control_loop_pipe.v 
    ../rtl/ai/ml_net/myproject_flow_control_loop_pipe_sequential_init.v 
    ../rtl/ai/ml_net/myproject_hls_deadlock_detection_unit.v 
    ../rtl/ai/ml_net/myproject_hls_deadlock_idx0_monitor.v 
    ../rtl/ai/ml_net/myproject_mul_10s_8s_18_1_1.v 
    ../rtl/ai/ml_net/myproject_mul_16s_10s_16_1_1.v 
    ../rtl/ai/ml_net/myproject_mul_16s_16s_16_1_1.v 
    ../rtl/ai/ml_net/myproject_mul_16s_6ns_20_1_1.v 
    ../rtl/ai/ml_net/myproject_mul_16s_7ns_20_1_1.v 
    ../rtl/ai/ml_net/myproject_mul_16s_8s_20_1_1.v 
    ../rtl/ai/ml_net/myproject_normalize_array_ap_fixed_32u_array_ap_fixed_10_5_5_3_0_32u_config13_s.v 
    ../rtl/ai/ml_net/myproject_normalize_array_ap_fixed_8u_array_ap_fixed_10_5_5_3_0_8u_config3_s.v 
    ../rtl/ai/ml_net/myproject_normalize_array_ap_fixed_8u_array_ap_fixed_10_5_5_3_0_8u_config7_s.v 
    ../rtl/ai/ml_net/myproject_pooling1d_cl_array_ap_fixed_8u_array_ap_fixed_8_4_5_3_0_8u_config5_s.v 
    ../rtl/ai/ml_net/myproject_pooling1d_cl_array_ap_fixed_8u_array_ap_fixed_8_4_5_3_0_8u_config9_s.v 
    ../rtl/ai/ml_net/myproject_regslice_both.v 
    ../rtl/ai/ml_net/myproject_sparsemux_193_7_8_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_49_5_8_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_61_5_16_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_61_5_8_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_65_5_8_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_7_2_12_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_9_2_16_1_1.v 
    ../rtl/ai/ml_net/myproject_sparsemux_9_2_8_1_1.v 
    ../rtl/ai/ml_net/myproject_start_for_conv_1d_cl_array_ap_fixed_8u_array_ap_fixed_16_6_5_3_0_8u_config6_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_dense_array_ap_fixed_32u_array_ap_fixed_16_6_5_3_0_3u_config15_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_dense_array_ap_fixed_8u_array_ap_fixed_16_6_5_3_0_32u_config12_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_normalize_array_ap_fixed_32u_array_ap_fixed_10_5_5_3_0_32u_config13ibs.v 
    ../rtl/ai/ml_net/myproject_start_for_normalize_array_ap_fixed_8u_array_ap_fixed_10_5_5_3_0_8u_config3_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_normalize_array_ap_fixed_8u_array_ap_fixed_10_5_5_3_0_8u_config7_U0.v
    ../rtl/ai/ml_net/myproject_start_for_pooling1d_cl_array_ap_fixed_8u_array_ap_fixed_8_4_5_3_0_8u_config5_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_pooling1d_cl_array_ap_fixed_8u_array_ap_fixed_8_4_5_3_0_8u_config9_U0.v 
    ../rtl/ai/ml_net/myproject_start_for_thresholded_relu_array_ap_fixed_array_ap_fixed_8u_thresholdedrelu_cg8j.v 
    ../rtl/ai/ml_net/myproject_start_for_thresholded_relu_array_ap_fixed_array_ap_fixed_8u_thresholdedrelu_chbi.v 
    ../rtl/ai/ml_net/myproject_start_for_thresholded_relu_array_ap_fixed_array_thresholdedrelu_config14_U0.v 
    ../rtl/ai/ml_net/myproject_thresholded_relu_array_ap_fixed_array_ap_fixed_8u_thresholdedrelu_config4_s.v 
    ../rtl/ai/ml_net/myproject_thresholded_relu_array_ap_fixed_array_ap_fixed_8u_thresholdedrelu_config8_s.v 
    ../rtl/ai/ml_net/myproject_thresholded_relu_array_ap_fixed_array_thresholdedrelu_config14_s.v
    ../rtl/ai/ml_net/myproject_mul_16s_10s_26_1_1.v
    ../rtl/ai/ml_net/myproject_mul_16s_16s_26_1_1.v
    ../rtl/uart/uart.v
    ../rtl/uart/uart_tx.v
    ../rtl/uart/uart_rx.v
    ../rtl/uart/fifo.v
    ../rtl/uart/mod_m_counter.v
}

# Specify VHDL design files location            -- EDIT
# set vhdl_files {
# }

# Specify files for a memory initialization     -- EDIT
#set mem_files {
#    ../rtl/ml_net/image_rom.data
#   path/to/file.data
#}
