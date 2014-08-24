//
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
//

`include "defines.v"

//
// Storage for control registers, special purpose locations that control processor operation
// (for example, enabling threads)
//

module control_registers
	#(parameter core_id_t CORE_ID = 0)
	(input                                  clk,
	input                                   reset,
	
	// Control signals to various stages
	output thread_bitmap_t                  cr_thread_enable,
	
	// From writeback stage
	input                                   wb_fault,
	input fault_reason_t                    wb_fault_reason,
	input scalar_t                          wb_fault_pc,
	input thread_idx_t                      wb_fault_thread_idx,
	
	// From dcache_data_stage (dd_ signals are unregistered.  dt_thread_idx represents thread
	// going into dcache_data_stage)
	input thread_idx_t                      dt_thread_idx,
	input                                   dd_creg_write_en,
	input                                   dd_creg_read_en,
	input control_register_t                dd_creg_index,
	input scalar_t                          dd_creg_write_val,
	
	// To writeback_stage
	output scalar_t                         cr_creg_read_val,
	output thread_bitmap_t                  cr_interrupt_en);
	
	scalar_t fault_pc[`THREADS_PER_CORE];
	fault_reason_t fault_reason[`THREADS_PER_CORE];
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			cr_thread_enable <= 1;
			cr_interrupt_en <= 0;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
				fault_reason[i] <= FR_RESET;
		end
		else
		begin
			// Ensure a read and write don't occur in the same cycle
			assert(!(dd_creg_write_en && dd_creg_read_en));
		
			if (wb_fault)
			begin
				fault_reason[wb_fault_thread_idx] <= wb_fault_reason;
				fault_pc[wb_fault_thread_idx] <= wb_fault_pc;
				cr_interrupt_en[wb_fault_thread_idx] <= 0;	// Disable interrupts for this thread
			end
			
			if (dd_creg_write_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ENABLE: cr_thread_enable <= dd_creg_write_val;
					CR_HALT_THREAD: cr_thread_enable[dt_thread_idx] <= 0;
					CR_INTERRUPT_ENABLE: cr_interrupt_en[dt_thread_idx] <= 1;
					CR_HALT: cr_thread_enable <= 0;
				endcase
			end
			
			if (dd_creg_read_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ID: cr_creg_read_val <= { CORE_ID, dt_thread_idx };
					CR_FAULT_PC: cr_creg_read_val <= fault_pc[dt_thread_idx];
					CR_FAULT_REASON: cr_creg_read_val <= fault_reason[dt_thread_idx];
				endcase
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
	
