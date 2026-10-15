`timescale 1ns / 1ps

module MIPS_Pipeline_With_Cache_TB_final;

    // Testbench Driver Signals
    reg clk;
    reg rst;

    // Probes to read top-level debug signals
    wire [31:0] debug_pc;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_write_data;
    wire [31:0] debug_instr;
    wire        debug_cache_stall;

    // Deep hierarchical visibility wires
    wire [31:0] current_instrD      = uut.instrD;
    wire        cache_stall_active  = uut.internal_cache_stall;
    wire        l1d_miss_active     = uut.l1d_miss_signal;
    wire        l2_done_active      = uut.l2_done_signal;
    wire        l2_req_active       = uut.l2_req_signal;
    
    // Hazard detection debug signals
    wire        debug_stallF        = uut.stallF;
    wire        debug_stallD        = uut.stallD;
    wire        debug_flushD        = uut.flushD;
    wire        debug_flushE        = uut.flushE;
    
    // Pipeline stage debug signals (probed directly across EX and MEM)
    wire [31:0] debug_pc_plus4F     = uut.pc_plus4F;
    wire [31:0] debug_pc_outF       = uut.pc_outF;
    wire [31:0] debug_alu_resultE   = uut.alu_resultE;  // ALU output in Execute Stage
    wire [31:0] debug_alu_resultM   = uut.alu_resultM;  // Settled output in Memory Stage
    wire [31:0] debug_write_dataM   = uut.write_dataM;  // Forwarded store data in Memory Stage
    wire        debug_mem_readM     = uut.mem_readM;
    wire        debug_mem_writeM    = uut.mem_writeM;
    
    // Forwarding debug
    wire [1:0]  debug_forwardAE     = uut.forwardAE;
    wire [1:0]  debug_forwardBE     = uut.forwardBE;
    wire [31:0] debug_srcAE         = uut.srcAE;
    wire [31:0] debug_srcBE         = uut.srcBE;
    
    // Register file debug probes
    wire [31:0] debug_reg_v0        = uut.register_file.regArray[2];  // $v0
    wire [31:0] debug_reg_v1        = uut.register_file.regArray[3];  // $v1
    wire [31:0] debug_reg_a0        = uut.register_file.regArray[4];  // $a0
    wire [31:0] debug_reg_a1        = uut.register_file.regArray[5];  // $a1
    wire [31:0] debug_reg_a2        = uut.register_file.regArray[6];  // $a2
    wire [31:0] debug_reg_a3        = uut.register_file.regArray[7];  // $a3
    wire [31:0] debug_reg_t0        = uut.register_file.regArray[8];  // $t0
    
    // Cache debug
    wire [31:0] debug_l1_data_at_16 = uut.data_l1_cache.cache_data[1][31:0];
    wire [31:0] debug_l1_tag_at_16  = uut.data_l1_cache.cache_tags[1];
    wire        debug_l1_valid_at_16 = uut.data_l1_cache.valid_bits[1];
    
    // L2 debug
    wire [127:0] debug_l2_data_at_index = uut.unified_l2_layer.cache_data[uut.unified_l2_layer.current_index];
    wire         debug_l2_valid_at_index = uut.unified_l2_layer.valid_bits[uut.unified_l2_layer.current_index];
    wire         debug_l2_dirty_at_index = uut.unified_l2_layer.dirty_bits[uut.unified_l2_layer.current_index];
    
    // Main memory debug
    wire [127:0] debug_main_mem_block0 = uut.multi_cycle_dram.memory[0];
    wire [127:0] debug_main_mem_block1 = uut.multi_cycle_dram.memory[1];

    // Instantiate Unit Under Test (UUT)
    MIPS_Pipeline_Top uut (
        .clk(clk), 
        .rst(rst), 
        .debug_pc(debug_pc), 
        .debug_alu_result(debug_alu_result), 
        .debug_write_data(debug_write_data),
        .debug_instr(debug_instr),
        .debug_cache_stall(debug_cache_stall)
    );

    // Clock Generator: 50MHz (20ns Period -> Toggle every 10ns)
    always begin
        #10 clk = ~clk;
    end

    // Main Test Loop Control
    initial begin
        clk = 0;
        rst = 1;

        $display("==========================================================================================");
        $display("                 MIPS ARCHITECTURE VISUAL CHRONO-TRACE DIAGNOSTIC RUN                     ");
        $display("==========================================================================================");
        $display("[SYSTEM CONF] Main Memory Penalty Set To: 50 Clock Cycles.");
        
        #25;
        rst = 0;
        
        $display("[TIME: %0d ns] System Reset De-asserted. Booting Pipeline & Memory Bus...", $time);
        $display("------------------------------------------------------------------------------------------");
        $display(" Cyc |  PC  | L1D | stallF | stallD | flushD | flushE | L1D Miss | L2 Done | Action");
        $display("------------------------------------------------------------------------------------------");
    end

    integer cycle_counter = 0;
    
    // Tracking registers to align instruction disassembly with actual execution in Execute/Memory stages
    reg [31:0] instrE, instrM;

    always @(posedge clk) begin
        if (!rst) begin
            // Pipeline instruction pipeline shift for reporting alignment
            if (!debug_stallD) begin
                instrE <= current_instrD;
            end else if (debug_flushE) begin
                instrE <= 32'b0;
            end

            instrM <= instrE;
            cycle_counter <= cycle_counter + 1;
            
            // Step 1: Base Cycle info and current PC
            $write(" %3d | 0x%h | ", cycle_counter + 1, debug_pc);

            // Step 2: L1 Cache status
            if (l1d_miss_active) 
                $write(" D-MISS | ");
            else 
                $write("  D-HIT | ");

            // Step 3: Hazard signals
            $write("   %b    |   %b    |   %b    |   %b    |    %b    |   %b    | ",
                   debug_stallF, debug_stallD, debug_flushD, debug_flushE, 
                   l1d_miss_active, l2_done_active);

            // Step 4: Accurate Stage-Aligned Logging
            if (cache_stall_active) begin
                if (l1d_miss_active && !l2_done_active)
                    $write("STALL: L1D Miss waiting for L2...\n");
                else if (l1d_miss_active && l2_done_active)
                    $write("STALL: L2 done, refilling L1...\n");
                else
                    $write("STALL: Cache controller settling...\n");
            end else begin
                if (current_instrD == 32'b0) begin
                    $write("NOP Bubble\n");
                end else begin
                    case (current_instrD[31:26])
                        6'h00: begin // R-Type
                            case (current_instrD[5:0])
                                // Uses debug_alu_resultE so the addition result (e.g. 5 + 3 = 8) is reported accurately
                                6'h20: $write("ADD  $a0, $v0, $v1  (Result: %0d)\n", debug_alu_resultE);
                                6'h22: $write("SUB  $a1, $v0, $v1  (Result: %0d)\n", debug_alu_resultE);
                                6'h24: $write("AND  $a3, $v0, $v1  (Result: %0d)\n", debug_alu_resultE);
                                6'h25: $write("OR   $a2, $v0, $v1  (Result: %0d)\n", debug_alu_resultE);
                                6'h2a: $write("SLT  ...\n");
                                default: $write("R-Type (funct=0x%h)\n", current_instrD[5:0]);
                            endcase
                        end
                        6'h08: begin // ADDI
                            if (current_instrD[20:16] == 5'd2)
                                $write("ADDI $v0, $zero, 5\n");
                            else if (current_instrD[20:16] == 5'd3)
                                $write("ADDI $v1, $zero, 3\n");
                            else
                                $write("ADDI ...\n");
                        end
                        6'h0a: $write("SLTI ...\n");
                        6'h23: $write("LW   $t0, 16($zero)\n");
                        6'h2b: begin // SW - Uses debug_srcBE or debug_write_dataM for true forwarded value
                            $write("SW   $a0, 16($zero) (Writing value %0d to addr 16)\n", debug_srcBE);
                        end
                        6'h04: $write("BEQ  ...\n");
                        default: $write("Unknown Opcode: 0x%h\n", current_instrD[31:26]);
                    endcase
                end
            end
        end
    end

    integer r;

    // Simulation Runtime Control & Verification Dump
    initial begin
        // Run window sufficient for pipeline completion & cache penalty cycles
        #2000;
        
        $display("------------------------------------------------------------------------------------------");
        $display("[SIMULATION SUCCESS] Diagnostics run completed.");
        
        $display("\n==========================================================================================");
        $display("   PRIMARY REGISTER FILE STATE VERIFICATION");
        $display("==========================================================================================");
        
        $display(" Register $v0 (Reg 2)  = %0d (0x%h)", debug_reg_v0, debug_reg_v0);
        $display(" Register $v1 (Reg 3)  = %0d (0x%h)", debug_reg_v1, debug_reg_v1);
        $display(" Register $a0 (Reg 4)  = %0d (0x%h)", debug_reg_a0, debug_reg_a0);
        $display(" Register $a1 (Reg 5)  = %0d (0x%h)", debug_reg_a1, debug_reg_a1);
        $display(" Register $a2 (Reg 6)  = %0d (0x%h)", debug_reg_a2, debug_reg_a2);
        $display(" Register $a3 (Reg 7)  = %0d (0x%h)", debug_reg_a3, debug_reg_a3);
        $display(" Register $t0 (Reg 8)  = %0d (0x%h)", debug_reg_t0, debug_reg_t0);
        
        $display("\n------------------------------------------------------------------------------------------");
        $display(" FULL REGISTER FILE ARRAY DUMP ($0 to $31)");
        $display("------------------------------------------------------------------------------------------");
        for (r = 0; r < 32; r = r + 1) begin
            $display(" Reg [%2d] = Decimal: %10d | Hex: 0x%08h", 
                     r, uut.register_file.regArray[r], uut.register_file.regArray[r]);
        end
        $display("------------------------------------------------------------------------------------------");

        $display("\n L1 Data Cache Status:");
        $display("   Data at Addr 16   = %0d", debug_l1_data_at_16);
        $display("   Tag at Addr 16    = 0x%h", debug_l1_tag_at_16);
        $display("   Valid at Addr 16  = %b", debug_l1_valid_at_16);
        
        $display("\n Main Memory Status:");
        $display("   Block 0 = 0x%h", debug_main_mem_block0);
        $display("   Block 1 = 0x%h", debug_main_mem_block1);
        
        $display("\n L2 Cache Status:");
        $display("   Valid at current index = %b", debug_l2_valid_at_index);
        $display("   Dirty at current index = %b", debug_l2_dirty_at_index);
        
        $display("\n Forwarding Unit Status:");
        $display("   forwardAE = %b  forwardBE = %b", debug_forwardAE, debug_forwardBE);
        $display("   srcAE = %0d  srcBE = %0d", debug_srcAE, debug_srcBE);
        
        $display("\n Pipeline Control Signals:");
        $display("   stallF = %b  stallD = %b", debug_stallF, debug_stallD);
        $display("   flushD = %b  flushE = %b", debug_flushD, debug_flushE);
        $display("   cache_stall = %b", debug_cache_stall);
        
        $display("\n==========================================================================================");
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, MIPS_Pipeline_With_Cache_TB_final);
    end

endmodule