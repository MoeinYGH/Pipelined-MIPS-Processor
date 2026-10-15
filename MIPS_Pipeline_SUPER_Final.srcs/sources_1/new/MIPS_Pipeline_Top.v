`timescale 1ns / 1ps

module MIPS_Pipeline_Top(
    input wire clk,
    input wire rst,
    // Debug Outputs to observe program execution in the testbench
    output wire [31:0] debug_pc,
    output wire [31:0] debug_alu_result,
    output wire [31:0] debug_write_data,
    output wire [31:0] debug_instr,
    output wire        debug_cache_stall
);

    // Central Cache System Freeze Line
    wire internal_cache_stall;

    // =========================================================================
    // 1. FETCH (IF) STAGE SIGNALS
    // =========================================================================
    wire [31:0] pc_inF;
    wire [31:0] pc_outF;
    wire [31:0] pc_plus4F;
    wire [31:0] instrF;
    wire stallF;

    // =========================================================================
    // 2. DECODE (ID) STAGE SIGNALS
    // =========================================================================
    wire [31:0] pc_plus4D;
    wire [31:0] instrD;
    wire stallD;
    wire flushD;
    
    wire [4:0]  rsD = instrD[25:21];
    wire [4:0]  rtD = instrD[20:16];
    wire [4:0]  rdD = instrD[15:11];
    wire [5:0]  functD = instrD[5:0];
    wire [15:0] immD = instrD[15:0];

    wire        reg_dstD, alu_srcD, mem_readD, mem_writeD, branchD, reg_writeD, mem_to_regD;
    wire [2:0]  alu_opD;
    wire [31:0] reg_data1D, reg_data2D;
    wire [31:0] sign_ext_immD;
    
    // Early Branch Evaluation Logic in ID Stage
    wire        branch_takenD = branchD && (reg_data1D == reg_data2D);
    wire [31:0] branch_targetD = pc_plus4D + (sign_ext_immD << 2);

    // MUX choosing next Program Counter
    assign pc_inF = (branch_takenD) ? branch_targetD : pc_plus4F;

    // =========================================================================
    // 3. EXECUTE (EX) STAGE SIGNALS
    // =========================================================================
    wire [31:0] pc_plus4E, reg_data1E, reg_data2E, sign_ext_immE;
    wire [4:0]  rsE, rtE, rdE;
    wire [2:0]  alu_opE;
    wire        alu_srcE, reg_dstE, mem_readE, mem_writeE, reg_writeE, mem_to_regE, branchE;
    wire [5:0]  functE;
    wire flushE;

    wire [1:0]  forwardAE, forwardBE;
    reg  [31:0] srcAE, forward_mux_B_out;
    wire [31:0] srcBE;
    wire [3:0]  alu_ctrlE;
    wire [31:0] alu_resultE;
    wire        zeroE;
    wire [4:0]  write_regE = (reg_dstE) ? rdE : rtE;

    // =========================================================================
    // 4. MEMORY (MEM) STAGE SIGNALS
    // =========================================================================
    wire [31:0] alu_resultM, write_dataM;
    wire [4:0]  write_regM;
    wire        mem_readM, mem_writeM, reg_writeM, mem_to_regM;
    wire [31:0] read_dataM;

    // =========================================================================
    // 5. WRITE-BACK (WB) STAGE SIGNALS
    // =========================================================================
    wire [31:0] read_dataW, alu_resultW;
    wire [4:0]  write_regW;
    wire        reg_writeW, mem_to_regW;
    wire [31:0] write_dataW = (mem_to_regW) ? read_dataW : alu_resultW;

    // =========================================================================
    // 6. MULTI-LEVEL CACHE HIERARCHY INTERCONNECT BUSES [Section 4.2]
    // =========================================================================
    // L2 to L1 interfaces
    wire [127:0] l2_block_data_to_l1d;
    wire [127:0] l2_block_data_to_l1i;
    wire         l2_ready_to_l1d;
    wire         l2_ready_to_l1i;
    
    // L1 miss signals
    wire         l1i_miss_signal;
    wire         l1d_miss_signal;
    
    // L1 request signals
    wire         l1i_req_signal;
    wire         l1d_req_signal;
    wire         l1i_grant_signal;
    wire         l1d_grant_signal;
    
    // L2 control signals
    wire         l2_req_signal;
    wire         l2_is_instruction_signal;
    wire         l2_done_signal;
    wire         l2_miss_signal;
    wire [127:0] l2_read_data_signal;
    wire         l2_is_write_signal;
    
    // Main Memory interface
    wire [127:0] main_mem_block_bus;
    wire [31:0]  main_mem_addr_bus;
    wire [127:0] main_mem_write_bus;
    wire         main_mem_ready_flag;
    wire         main_mem_read_cmd;
    wire         main_mem_write_cmd;

    // =========================================================================
    // CORE PIPELINE MODULE INSTANTIATIONS
    // =========================================================================

    // ----------------- FETCH (IF) STAGE -----------------
    PC pc_unit (
        .pc_in(pc_inF), .clk(clk), .rst(rst), 
        .stallF(stallF), .cache_stall(internal_cache_stall), 
        .pc_out(pc_outF)
    );

    pcplus4 pc4_adder (
        .OldPC(pc_outF), .NewPC(pc_plus4F)
    );

    // ----------------- IF/ID PIPELINE REGISTER ----------
    IF_ID_reg if_id_reg_inst (
        .clk(clk), .rst(rst), .stallD(stallD), .flushD(flushD),
        .cache_stall(internal_cache_stall), .pc_plus4F(pc_plus4F), .instrF(instrF),
        .pc_plus4D(pc_plus4D), .instrD(instrD)
    );

    // ----------------- DECODE (ID) STAGE ----------------
    ControlUnit control_unit (
        .op(instrD[31:26]), .EX_RegDst(reg_dstD), .EX_ALUSrc(alu_srcD), .EX_ALUOp(alu_opD),
        .ID_Branch(branchD), .M_MemRead(mem_readD), .M_MemWrite(mem_writeD),
        .WB_RegWrite(reg_writeD), .WB_MemToReg(mem_to_regD)
    );

    // Fixed register file write tracking mapping
    RegisterFile register_file (
        .rs(rsD), .rt(rtD), .rd(write_regW), .WriteData(write_dataW),
        .regWrite(reg_writeW), .clk(clk), .rst(rst),
        .regA(reg_data1D), .regB(reg_data2D)
    );

    SignExtension sign_ext (
        .inp(immD), .out(sign_ext_immD)
    );

    // ----------------- ID/EX PIPELINE REGISTER ----------
    ID_EX_reg id_ex_reg_inst (
        .clk(clk), .rst(rst), .flushE(flushE), .cache_stall(internal_cache_stall),
        .reg_data1D(reg_data1D), .reg_data2D(reg_data2D), .sign_ext_immD(sign_ext_immD),
        .rsD(rsD), .rtD(rtD), .rdD(rdD), .alu_opD(alu_opD), .alu_srcD(alu_srcD),
        .reg_dstD(reg_dstD), .mem_readD(mem_readD), .mem_writeD(mem_writeD),
        .branchD(branchD), .reg_writeD(reg_writeD), .mem_to_regD(mem_to_regD),
        .pc_plus4D(pc_plus4D), .functD(functD),
        .pc_plus4E(pc_plus4E), .functE(functE), .reg_data1E(reg_data1E), .reg_data2E(reg_data2E),
        .sign_ext_immE(sign_ext_immE), .rsE(rsE), .rtE(rtE), .rdE(rdE), .alu_opE(alu_opE),
        .alu_srcE(alu_srcE), .reg_dstE(reg_dstE), .mem_readE(mem_readE), .mem_writeE(mem_writeE),
        .branchE(branchE), .reg_writeE(reg_writeE), .mem_to_regE(mem_to_regE)
    );

    // ----------------- EXECUTE (EX) STAGE ---------------
    // Forwarding MUX A
    always @(*) begin
        case (forwardAE)
            2'b00: srcAE = reg_data1E;
            2'b01: srcAE = write_dataW;
            2'b10: srcAE = alu_resultM;
            default: srcAE = reg_data1E;
        endcase
    end

    // Forwarding MUX B
    always @(*) begin
        case (forwardBE)
            2'b00: forward_mux_B_out = reg_data2E;
            2'b01: forward_mux_B_out = write_dataW;
            2'b10: forward_mux_B_out = alu_resultM;
            default: forward_mux_B_out = reg_data2E;
        endcase
    end

    // ALU Src B Input Selection MUX
    assign srcBE = (alu_srcE) ? sign_ext_immE : forward_mux_B_out;

    ALUControl alu_control_unit (
        .ALUOp(alu_opE), .funct(functE), .ALUCtrl(alu_ctrlE)
    );

    ALU execution_alu (
        .A(srcAE), .B(srcBE), .ALUCtrl(alu_ctrlE), .Result(alu_resultE), .Zero(zeroE)
    );

    Forwarding_Unit forward_unit_inst (
        .rsE(rsE), .rtE(rtE), .write_regM(write_regM), .write_regW(write_regW),
        .reg_writeM(reg_writeM), .reg_writeW(reg_writeW),
        .forwardAE(forwardAE), .forwardBE(forwardBE)
    );

    // ----------------- EX/MEM PIPELINE REGISTER ---------
    EX_MEM_reg ex_mem_reg_inst (
        .clk(clk), .rst(rst), .cache_stall(internal_cache_stall),
        .alu_resultE(alu_resultE), .write_dataE(forward_mux_B_out), .write_regE(write_regE),
        .mem_readE(mem_readE), .mem_writeE(mem_writeE), .reg_writeE(reg_writeE), .mem_to_regE(mem_to_regE),
        .alu_resultM(alu_resultM), .write_dataM(write_dataM), .write_regM(write_regM),
        .mem_readM(mem_readM), .mem_writeM(mem_writeM), .reg_writeM(reg_writeM), .mem_to_regM(mem_to_regM)
    );

    // ----------------- MEM/WB PIPELINE REGISTER ---------
    MEM_WB_reg mem_wb_reg_inst (
        .clk(clk), .rst(rst), .cache_stall(internal_cache_stall),
        .read_dataM(read_dataM), .alu_resultM(alu_resultM), .write_regM(write_regM),
        .reg_writeM(reg_writeM), .mem_to_regM(mem_to_regM),
        .read_dataW(read_dataW), .alu_resultW(alu_resultW), .write_regW(write_regW),
        .reg_writeW(reg_writeW), .mem_to_regW(mem_to_regW)
    );

    // ----------------- HAZARD DETECTION UNIT ------------
    HazardDetection_Unit hazard_detection_inst (
        .rsD(rsD), .rtD(rtD), .branch_takenD(branch_takenD),
        .rtE(rtE), .mem_to_regE(mem_to_regE), .cache_stall(internal_cache_stall),
        .stallF(stallF), .stallD(stallD), .flushD(flushD), .flushE(flushE),
        .pipeline_cache_stall() 
    );

    // =========================================================================
    // DATA-STREAM MEMORY HIERARCHY ARCHITECTURE [Section 4.2]
    // =========================================================================

    // 1. Cache Controller - Now expects l2_done
    Cache_Controller system_cache_fsm (
        .clk(clk), .rst(rst),
        .l1i_miss(l1i_miss_signal), 
        .l1d_miss(l1d_miss_signal),
        .l2_done(l2_done_signal),        // CHANGED
        .l2_req(l2_req_signal),          // CHANGED
        .l2_is_write(l2_is_write_signal), // CHANGED
        .cache_stall(internal_cache_stall)
    );

    // 2. Instruction Cache - Now properly connected to L2
    ICache instruction_l1_cache (
        .clk(clk), .rst(rst),
        .addressF(pc_outF), 
        .l2_block_data(l2_block_data_to_l1i), 
        .l2_ready(l2_ready_to_l1i),
        .instructionF(instrF), 
        .l1i_miss(l1i_miss_signal),
        .l1i_req(l1i_req_signal),
        .l1i_grant(l1i_grant_signal)
    );

    // 3. Data Cache - Now properly connected to L2
    L1_Cache data_l1_cache (
        .clk(clk), .rst(rst),
        .mem_readM(mem_readM), .mem_writeM(mem_writeM),
        .addressM(alu_resultM), .write_dataM(write_dataM),
        .l2_block_data(l2_block_data_to_l1d), 
        .l2_ready(l2_ready_to_l1d),
        .read_dataM(read_dataM), 
        .l1d_miss(l1d_miss_signal),
        .l1d_req(l1d_req_signal),
        .l1d_grant(l1d_grant_signal)
    );

    // 4. L2 Arbiter - Manages access to L2 from both L1 caches
    L2_Arbiter l2_arbiter_inst (
        .clk(clk), .rst(rst),
        .l1i_req(l1i_req_signal), .l1d_req(l1d_req_signal),
        .l1i_addr(pc_outF), .l1d_addr(alu_resultM),
        .l1i_write_data(128'b0), .l1d_write_data({4{write_dataM}}),
        .l1i_is_write(1'b0), .l1d_is_write(mem_writeM),
        .l1i_grant(l1i_grant_signal), .l1d_grant(l1d_grant_signal),
        .l2_req(l2_req_signal), .l2_is_instruction(l2_is_instruction_signal),
        .l2_addr(), .l2_write_data(), .l2_is_write(l2_is_write_signal),
        .l2_done(l2_done_signal), .l2_read_data(l2_read_data_signal),
        .l2_miss(l2_miss_signal)
    );

    // 2. L2 Cache - Simplified interface
    L2_Cache unified_l2_layer (
        .clk(clk), .rst(rst),
        .l2_req(l2_req_signal), 
        .l2_is_write(l2_is_write_signal),
        .address(alu_resultM),
        .write_block_from_l1({4{write_dataM}}),
        .main_mem_block(main_mem_block_bus), 
        .main_mem_ready(main_mem_ready_flag),
        .read_block_to_l1(l2_read_data_signal), 
        .l2_done(l2_done_signal),
        .l2_miss(l2_miss_signal),
        .main_mem_address(main_mem_addr_bus),
        .main_mem_write_block(main_mem_write_bus),
        .main_mem_read(main_mem_read_cmd), 
        .main_mem_write(main_mem_write_cmd)
    );

    // 6. Route L2 response to appropriate L1 cache
    assign l2_block_data_to_l1d = l2_read_data_signal;
    assign l2_block_data_to_l1i = l2_read_data_signal;
    assign l2_ready_to_l1d = l2_done_signal && !l2_is_instruction_signal;
    assign l2_ready_to_l1i = l2_done_signal && l2_is_instruction_signal;

    // 7. High-Latency Main Memory Storage
    Main_Memory multi_cycle_dram (
        .clk(clk), .rst(rst),
        .mem_read(main_mem_read_cmd), .mem_write(main_mem_write_cmd),
        .mem_addr(main_mem_addr_bus), .mem_write_data(main_mem_write_bus),
        .mem_read_data(main_mem_block_bus), .mem_ready(main_mem_ready_flag)
    );

    // =========================================================================
    // LOGICAL SIMULATION DEBUG MAP PROBES
    // =========================================================================
    assign debug_pc         = pc_outF;
    assign debug_alu_result = alu_resultE;
    assign debug_write_data = write_dataW;
    assign debug_instr      = instrF;
    assign debug_cache_stall = internal_cache_stall;

endmodule