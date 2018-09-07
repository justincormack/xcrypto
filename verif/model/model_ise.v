//
// SCARV Project
// 
// University of Bristol
// 
// RISC-V Cryptographic Instruction Set Extension
// 
// Reference Implementation
// 
// 

//
// module: model_ise
//
//  A behavioural model of the ISE
//
module model_ise(

//
// Clock and reset interface

input  wire             g_clk           , // Global clock
output wire             g_clk_req       , // Clock request
input  wire             g_resetn        , // Synchronous active low reset.

//
// Input instruction interface
input  wire             cop_insn_valid  , // Instruction valid
input  wire [31:0]      cop_insn_enc    , // Encoded instruction data
input  wire [31:0]      cop_rs1         , // RS1 source data


//
// Output modelling signals.
output reg  [ 2:0]      cop_result      , // Instruction execution result

output reg  [15:0]      cop_cprs_written, // CPR Registers read by instr
output reg  [15:0]      cop_cprs_read   , // CPR Registers written by instr

output reg              cop_rd_wen      , // GPR Write Enable
output reg  [ 4:0]      cop_rd_addr     , // GPR Write Address
output reg  [31:0]      cop_rd_data     , // Data to write to GPR
output reg              cop_insn_finish , // Instruction finished

//
// Memory transaction tracking.
input                   cop_mem_cen     , // Memory transaction 0 enable
input                   cop_mem_wen     , // Transaction 0 write enable
input       [ 3:0]      cop_mem_ben     , // Transaction byte enable
input       [31:0]      cop_mem_addr    , // Transaction 0 address
input       [31:0]      cop_mem_wdata   , // Transaction 0 write enable
input       [31:0]      cop_mem_rdata   , // Transaction 0 write enable
input                   cop_mem_stall   ,
input                   cop_mem_error    
);

//
// Input parameters to the model
// CSR Bit fields: See ISE Spec 4.2
parameter ISE_MCCR_R    = 1; // Feature enable bits.
parameter ISE_MCCR_MP   = 1; // 
parameter ISE_MCCR_SG   = 1; // 
parameter ISE_MCCR_P32  = 1; // 
parameter ISE_MCCR_P16  = 1; // 
parameter ISE_MCCR_P8   = 1; // 
parameter ISE_MCCR_P4   = 1; // 
parameter ISE_MCCR_P2   = 1; // 

parameter ISE_MCCR_S_R  = 1; // Reset value for S bit
parameter ISE_MCCR_U_R  = 1; // Reset Value for U bit

parameter ISE_MCCR_S_W  = 1; // Is S bit writable?
parameter ISE_MCCR_U_W  = 1; // Is U bit writable?

parameter ISE_MCCR_C0_W = 1; // Are the countermeasure enable bits writable?
parameter ISE_MCCR_C1_W = 1; // 
parameter ISE_MCCR_C2_W = 1; // 
parameter ISE_MCCR_C3_W = 1; // 
parameter ISE_MCCR_C4_W = 1; // 
parameter ISE_MCCR_C5_W = 1; // 
parameter ISE_MCCR_C6_W = 1; // 
parameter ISE_MCCR_C7_W = 1; // 

parameter ISE_MCCR_C0_R = 1; // Reset values for countermeasure enable.
parameter ISE_MCCR_C1_R = 1; // 
parameter ISE_MCCR_C2_R = 1; // 
parameter ISE_MCCR_C3_R = 1; // 
parameter ISE_MCCR_C4_R = 1; // 
parameter ISE_MCCR_C5_R = 1; // 
parameter ISE_MCCR_C6_R = 1; // 
parameter ISE_MCCR_C7_R = 1; // 

parameter ISE_RESET_CPRS= 1; // Reset CPRS to zero?
    

//
// Arithmetic pack width operation macro
//
//      Applies "OP" to the right sizes of data type and then writes
//      the results back,
//
`define PACK_WIDTH_ARITH_OPERATION(OP) begin \
    if(!pw_valid) begin \
        model_do_invalid_opcode(); \
    end else if(pw == 32) begin \
        result = crs1 OP crs2; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw == 16) begin \
        result = {crs1[31:16] OP crs2[31:16], \
                  crs1[15: 0] OP crs2[15: 0]}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  8) begin \
        result = {crs1[31:24] OP crs2[31:24], \
                  crs1[23:16] OP crs2[23:16], \
                  crs1[15: 8] OP crs2[15: 8], \
                  crs1[ 7: 0] OP crs2[ 7: 0]}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  4) begin \
        result = {crs1[31:28] OP crs2[31:28], \
                  crs1[27:24] OP crs2[27:24], \
                  crs1[23:20] OP crs2[23:20], \
                  crs1[19:16] OP crs2[19:16], \
                  crs1[15:12] OP crs2[15:12], \
                  crs1[11: 8] OP crs2[11: 8], \
                  crs1[ 7: 4] OP crs2[ 7: 4], \
                  crs1[ 3: 0] OP crs2[ 3: 0]}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  2) begin \
        result = {crs1[31:30] OP crs2[31:30], \
                  crs1[29:28] OP crs2[29:28], \
                  crs1[27:26] OP crs2[27:26], \
                  crs1[25:24] OP crs2[25:24], \
                  crs1[23:22] OP crs2[23:22], \
                  crs1[21:20] OP crs2[21:20], \
                  crs1[19:18] OP crs2[19:18], \
                  crs1[17:16] OP crs2[17:16], \
                  crs1[15:14] OP crs2[15:14], \
                  crs1[13:12] OP crs2[13:12], \
                  crs1[11:10] OP crs2[11:10], \
                  crs1[ 9: 8] OP crs2[ 9: 8], \
                  crs1[ 7: 6] OP crs2[ 7: 6], \
                  crs1[ 5: 4] OP crs2[ 5: 4], \
                  crs1[ 3: 2] OP crs2[ 3: 2], \
                  crs1[ 1: 0] OP crs2[ 1: 0]}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end \
end \

//
// Shift pack width operation macro
//
//      Applies "OP" to the right sizes of data type and then writes
//      the results back,
//
`define PACK_WIDTH_SHIFT_OPERATION(OP,AMNT) begin \
    if(!pw_valid) begin \
        model_do_invalid_opcode(); \
    end else if(pw == 32) begin \
        result = crs1 OP AMNT; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw == 16) begin \
        result = {crs1[31:16] OP AMNT, \
                  crs1[15: 0] OP AMNT}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  8) begin \
        result = {crs1[31:24] OP AMNT, \
                  crs1[23:16] OP AMNT, \
                  crs1[15: 8] OP AMNT, \
                  crs1[ 7: 0] OP AMNT}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  4) begin \
        result = {crs1[31:28] OP AMNT, \
                  crs1[27:24] OP AMNT, \
                  crs1[23:20] OP AMNT, \
                  crs1[19:16] OP AMNT, \
                  crs1[15:12] OP AMNT, \
                  crs1[11: 8] OP AMNT, \
                  crs1[ 7: 4] OP AMNT, \
                  crs1[ 3: 0] OP AMNT}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  2) begin \
        result = {crs1[31:30] OP AMNT, \
                  crs1[29:28] OP AMNT, \
                  crs1[27:26] OP AMNT, \
                  crs1[25:24] OP AMNT, \
                  crs1[23:22] OP AMNT, \
                  crs1[21:20] OP AMNT, \
                  crs1[19:18] OP AMNT, \
                  crs1[17:16] OP AMNT, \
                  crs1[15:14] OP AMNT, \
                  crs1[13:12] OP AMNT, \
                  crs1[11:10] OP AMNT, \
                  crs1[ 9: 8] OP AMNT, \
                  crs1[ 7: 6] OP AMNT, \
                  crs1[ 5: 4] OP AMNT, \
                  crs1[ 3: 2] OP AMNT, \
                  crs1[ 1: 0] OP AMNT}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end \
end \

//
// Rotate pack width operation macro
//
//      Applies "OP" to the right sizes of data type and then writes
//      the results back,
//
`define PACK_WIDTH_ROTATE_LEFT_OPERATION(AMNT) begin \
    if(!pw_valid) begin \
        model_do_invalid_opcode(); \
    end else if(pw == 32) begin \
        result = (crs1 << AMNT) | (crs1 >> (32-AMNT)); \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw == 16) begin \
        result = {(crs1[31:16] << AMNT) | (crs1[31:16] >> (16-AMNT)), \
                  (crs1[15: 0] << AMNT) | (crs1[15: 0] >> (16-AMNT))}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  8) begin \
        result = {(crs1[31:24] << AMNT) | (crs1[31:24] >> (8-AMNT)), \
                  (crs1[23:16] << AMNT) | (crs1[23:16] >> (8-AMNT)), \
                  (crs1[15: 8] << AMNT) | (crs1[15: 8] >> (8-AMNT)), \
                  (crs1[ 7: 0] << AMNT) | (crs1[ 7: 0] >> (8-AMNT))}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  4) begin \
        result = {(crs1[31:28] << AMNT) | (crs1[31:28] >> (4-AMNT)), \
                  (crs1[27:24] << AMNT) | (crs1[27:24] >> (4-AMNT)), \
                  (crs1[23:20] << AMNT) | (crs1[23:20] >> (4-AMNT)), \
                  (crs1[19:16] << AMNT) | (crs1[19:16] >> (4-AMNT)), \
                  (crs1[15:12] << AMNT) | (crs1[15:12] >> (4-AMNT)), \
                  (crs1[11: 8] << AMNT) | (crs1[11: 8] >> (4-AMNT)), \
                  (crs1[ 7: 4] << AMNT) | (crs1[ 7: 4] >> (4-AMNT)), \
                  (crs1[ 3: 0] << AMNT) | (crs1[ 3: 0] >> (4-AMNT))}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end else if(pw ==  2) begin \
        result = {(crs1[31:30] << AMNT) | (crs1[31:30] >> (4-AMNT)), \
                  (crs1[29:28] << AMNT) | (crs1[29:28] >> (4-AMNT)), \
                  (crs1[27:26] << AMNT) | (crs1[27:26] >> (4-AMNT)), \
                  (crs1[25:24] << AMNT) | (crs1[25:24] >> (4-AMNT)), \
                  (crs1[23:22] << AMNT) | (crs1[23:22] >> (4-AMNT)), \
                  (crs1[21:20] << AMNT) | (crs1[21:20] >> (4-AMNT)), \
                  (crs1[19:18] << AMNT) | (crs1[19:18] >> (4-AMNT)), \
                  (crs1[17:16] << AMNT) | (crs1[17:16] >> (4-AMNT)), \
                  (crs1[15:14] << AMNT) | (crs1[15:14] >> (4-AMNT)), \
                  (crs1[13:12] << AMNT) | (crs1[13:12] >> (4-AMNT)), \
                  (crs1[11:10] << AMNT) | (crs1[11:10] >> (4-AMNT)), \
                  (crs1[ 9: 8] << AMNT) | (crs1[ 9: 8] >> (4-AMNT)), \
                  (crs1[ 7: 6] << AMNT) | (crs1[ 7: 6] >> (4-AMNT)), \
                  (crs1[ 5: 4] << AMNT) | (crs1[ 5: 4] >> (4-AMNT)), \
                  (crs1[ 3: 2] << AMNT) | (crs1[ 3: 2] >> (4-AMNT)), \
                  (crs1[ 1: 0] << AMNT) | (crs1[ 1: 0] >> (4-AMNT))}; \
        model_do_write_cpr(dec_arg_crd, result[31:0]); \
    end \
end \


// Instruction result codes
localparam ISE_RESULT_SUCCESS           = 3'b000;
localparam ISE_RESULT_ABORT             = 3'b001;
localparam ISE_RESULT_DECODE_EXCEPTION  = 3'b010;
localparam ISE_RESULT_LOAD_ADDR_MISALIGN= 3'b100;
localparam ISE_RESULT_STOR_ADDR_MISALIGN= 3'b101;
localparam ISE_RESULT_LOAD_ACCESS_FAULT = 3'b110;
localparam ISE_RESULT_STOR_ACCESS_FAUKT = 3'b111;

// ------------------------------------------------------------------------

// Input to the generated decoder, gated by whether the input instruction
// is valid or not.
wire [31:0] encoded = cop_insn_enc & {32{cop_insn_valid}};

//
// Include the generated decoder. Exposes two classes of signal:
//  - dec_* for each instruction
//  - dec_arg_* for each possible instruction argument field.
//
//  This file is expected to be found in the $COP_WORK directory.
//
`include "ise_decode.v"

// ------------------------------------------------------------------------

//
// ISE State
//
//  These registers hold the complete state of the ISE.
//

reg  [31:0] model_cprs [15:0];

wire [31:0] model_cpr_c0  = model_cprs[ 0];
wire [31:0] model_cpr_c1  = model_cprs[ 1];
wire [31:0] model_cpr_c2  = model_cprs[ 2];
wire [31:0] model_cpr_c3  = model_cprs[ 3];
wire [31:0] model_cpr_c4  = model_cprs[ 4];
wire [31:0] model_cpr_c5  = model_cprs[ 5];
wire [31:0] model_cpr_c6  = model_cprs[ 6];
wire [31:0] model_cpr_c7  = model_cprs[ 7];
wire [31:0] model_cpr_c8  = model_cprs[ 8];
wire [31:0] model_cpr_c9  = model_cprs[ 9];
wire [31:0] model_cpr_c10 = model_cprs[10];
wire [31:0] model_cpr_c11 = model_cprs[11];
wire [31:0] model_cpr_c12 = model_cprs[12];
wire [31:0] model_cpr_c13 = model_cprs[13];
wire [31:0] model_cpr_c14 = model_cprs[14];
wire [31:0] model_cpr_c15 = model_cprs[15];

reg        model_mccr_c0 = ISE_MCCR_C0_R;
reg        model_mccr_c1 = ISE_MCCR_C1_R;
reg        model_mccr_c2 = ISE_MCCR_C2_R;
reg        model_mccr_c3 = ISE_MCCR_C3_R;
reg        model_mccr_c4 = ISE_MCCR_C4_R;
reg        model_mccr_c5 = ISE_MCCR_C5_R;
reg        model_mccr_c6 = ISE_MCCR_C6_R;
reg        model_mccr_c7 = ISE_MCCR_C7_R;
reg        model_mccr_s  = ISE_MCCR_S_R; 
reg        model_mccr_u  = ISE_MCCR_U_R; 

// Bit indicating an instruction will take more than one cycle for
// the model to produce a result. This is mostly used for memory
// access instructions.
reg        model_multi_cycle = 0;

// ------------------------------------------------------------------------

//
// Utility Functions
//

//
// Applies the reset function to all of the ISE state.
//
task model_do_reset;
begin

    $display("ISE> reset");

    model_mccr_c0 = ISE_MCCR_C0_R;
    model_mccr_c1 = ISE_MCCR_C1_R;
    model_mccr_c2 = ISE_MCCR_C2_R;
    model_mccr_c3 = ISE_MCCR_C3_R;
    model_mccr_c4 = ISE_MCCR_C4_R;
    model_mccr_c5 = ISE_MCCR_C5_R;
    model_mccr_c6 = ISE_MCCR_C6_R;
    model_mccr_c7 = ISE_MCCR_C7_R;
    model_mccr_s  = ISE_MCCR_S_R; 
    model_mccr_u  = ISE_MCCR_U_R; 

    if (ISE_RESET_CPRS) begin
        model_cprs[ 0] = 0;
        model_cprs[ 1] = 0;
        model_cprs[ 2] = 0;
        model_cprs[ 3] = 0;
        model_cprs[ 4] = 0;
        model_cprs[ 5] = 0;
        model_cprs[ 6] = 0;
        model_cprs[ 7] = 0;
        model_cprs[ 8] = 0;
        model_cprs[ 9] = 0;
        model_cprs[10] = 0;
        model_cprs[11] = 0;
        model_cprs[12] = 0;
        model_cprs[13] = 0;
        model_cprs[14] = 0;
        model_cprs[15] = 0;
    end

    model_do_clear_outputs();

end endtask


//
// Resets all outputs of the model so they do not carry to the next
// instruction and polute the results.
task model_do_clear_outputs;
begin
    
    cop_insn_finish  = 0;
    cop_result       = 0;

    cop_cprs_written = 0; // CPR Registers read by instr
    cop_cprs_read    = 0; // CPR Registers written by instr
    
    cop_rd_wen       = 0; // GPR Write Enable
    cop_rd_addr      = 0; // GPR Write Address
    cop_rd_data      = 0; // Data to write to GPR

end endtask


//
// Implements ISE functionality when we encounter an invalid opcode.
//
task model_do_invalid_opcode;
begin

    model_do_instr_result(ISE_RESULT_DECODE_EXCEPTION);
    cop_insn_finish = 1'b1;
    $display("ISE> Invalid Opcode: %h", encoded);

end endtask 


//
// Write a GPR with a particular value.
//
task model_do_write_gpr;
    input  [ 4:0] gpr_addr;
    input  [31:0] gpr_data;
begin
    if(cop_rd_wen) begin
        $display("ISE> WARNING: cop_rd_wen already set for this instruction");
    end
    cop_rd_wen  = 1'b1;
    cop_rd_addr = gpr_addr;
    cop_rd_data = gpr_data;
end endtask


//
// Write a CPR with a particular value.
//
task model_do_write_cpr;
    input  [ 3:0] cpr_addr;
    input  [31:0] cpr_data;
begin
    model_cprs[cpr_addr] = cpr_data;
    cop_cprs_written[cpr_addr] = 1'b1;
end endtask


//
// Read the value in a CPR
//
task model_do_read_cpr;
    input  [ 3:0] cpr_addr;
    output [31:0] cpr_data;
begin
    cpr_data = model_cprs[cpr_addr];
    cop_cprs_read[cpr_addr] = 1'b1;
end endtask


//
// Decode a register address pair for a multi-precision instruction.
//
task model_do_decode_rdm;
    output [ 3:0]   rd2;
    output [ 3:0]   rd1;
begin
    rd1 = {dec_arg_crdm,2'b00};
    rd2 = {dec_arg_crdm,2'b01};
end endtask

//
// Set the result of an instruction execution.
//
task model_do_instr_result;
    input  [ 2:0]   result;
begin
    cop_result      = result;
    cop_insn_finish = 1'b1;
end endtask


//
// Decode and return the decode pack width for an instruction.
//
task model_decode_pack_widths;
    output [ 5:0]   width;
    output          valid;
begin : t_model_decode_pack_widths
    reg a,b,c;
    a = cop_insn_enc[24];
    b = cop_insn_enc[19];
    c = cop_insn_enc[11];
    if         ({a,b,c} == 3'b000 && ISE_MCCR_P32) begin
        width = 32;
        valid = 1;
    end else if({a,b,c} == 3'b001 && ISE_MCCR_P16) begin
        width = 16;
        valid = 1;
    end else if({a,b,c} == 3'b010 && ISE_MCCR_P8 ) begin
        width = 8;
        valid = 1;
    end else if({a,b,c} == 3'b011 && ISE_MCCR_P4 ) begin
        width = 4;
        valid = 1;
    end else if({a,b,c} == 3'b100 && ISE_MCCR_P2 ) begin
        width = 2;
        valid = 1;
    end else begin
        width = 0;
        valid = 0;
    end
end endtask

//
// Utility wires / registers for monitoring the memory transaction
// snoop interface.

reg         p_cen   ;
reg [31:0]  p_addr  ;
reg [ 3:0]  p_ben   ;
reg         p_wen   ;
reg [31:0]  p_wdata ;

always @(posedge g_clk) p_cen   <= cop_mem_cen  ;
always @(posedge g_clk) if(cop_mem_cen) p_wen   <= cop_mem_wen  ;
always @(posedge g_clk) if(cop_mem_cen) p_ben   <= cop_mem_ben  ;
always @(posedge g_clk) if(cop_mem_cen) p_addr  <= cop_mem_addr ;
always @(posedge g_clk) if(cop_mem_cen) p_wdata <= cop_mem_wdata;

//
// Monitors the input memory bus and returns when a transaction
// completes.
//
task model_do_get_mem_transaction;
    output        wen  ;
    output [ 3:0] ben  ;
    output [31:0] addr ;
    output [31:0] rdata;
    output [31:0] wdata;
    output        error;
begin : t_model_get_mem_txn
    
    $display("%d getmem 1", $time);
    
    wait(p_cen && !cop_mem_stall);

    $display("%d getmem 2", $time);
    wen   = p_wen   ;
    ben   = p_ben   ;
    addr  = p_addr  ;
    wdata = p_wdata ;
    rdata = cop_mem_rdata   ;
    error = cop_mem_error   ;

end endtask

// ------------------------------------------------------------------------

//
// Instruction Implementations
//


//
// Implementation function for the mv2gpr instruction.
//
task model_do_mv2gpr;
begin: t_model_mv2gpr
    reg  [31:0] crs1;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_write_gpr(dec_arg_rd, crs1);
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> mv2gpr x%0d, c%0d",dec_arg_rd,dec_arg_crs1);
end endtask


//
// Implementation function for the mv2cop instruction.
//
task model_do_mv2cop;
begin: t_model_mv2cop
    model_do_write_cpr(dec_arg_crd, cop_rs1);
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> mv2cop c%0d, x%0d",dec_arg_crd, dec_arg_rs1);
end endtask


//
// Implementation function for the add.px instruction.
//
task model_do_add_px;
begin: t_model_add_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_ARITH_OPERATION(+)
end endtask


//
// Implementation function for the sub.px instruction.
//
task model_do_sub_px;
begin: t_model_sub_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_ARITH_OPERATION(-)
end endtask


//
// Implementation function for the mul.px instruction.
//
task model_do_mul_px;
begin: t_model_mul_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_ARITH_OPERATION(*)
end endtask


//
// Implementation function for the sll.px instruction.
//
task model_do_sll_px;
begin: t_model_sll_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_SHIFT_OPERATION(<<, crs2[4:0])
end endtask


//
// Implementation function for the srl.px instruction.
//
task model_do_srl_px;
begin: t_model_srl_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_SHIFT_OPERATION(>>, crs2[4:0])
end endtask


//
// Implementation function for the rot.px instruction.
//
task model_do_rot_px;
begin: t_model_rot_px
    reg  [31:0] crs1, crs2;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_ROTATE_LEFT_OPERATION(crs2[4:0])
end endtask


//
// Implementation function for the slli.px instruction.
//
task model_do_slli_px;
begin: t_model_slli_px
    reg  [31:0] crs1;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_SHIFT_OPERATION(<<, dec_arg_cshamt)
end endtask


//
// Implementation function for the srli.px instruction.
//
task model_do_srli_px;
begin: t_model_srli_px
    reg  [31:0] crs1;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_SHIFT_OPERATION(>>, dec_arg_cshamt)
end endtask


//
// Implementation function for the roti.px instruction.
//
task model_do_roti_px;
begin: t_model_roti_px
    reg  [31:0] crs1;
    reg  [31:0] result;
    reg  [ 5:0] pw;
    reg         pw_valid;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_decode_pack_widths(pw,pw_valid);
    `PACK_WIDTH_ROTATE_LEFT_OPERATION(dec_arg_cshamt)
end endtask


//
// Implementation function for the rseed.cr instruction.
//
task model_do_rseed_cr;
begin: t_model_rseed_cr
    reg  [31:0] crs1;
    model_do_read_cpr(dec_arg_crs1, crs1);
    $display("ISE> ERROR: Instruction rseed.cr not implemented");
end endtask


//
// Implementation function for the rsamp.cr instruction.
//
task model_do_rsamp_cr;
begin: t_model_rsamp_cr
    $display("ISE> ERROR: Instruction rsamp.cr not implemented");
end endtask


//
// Implementation function for the cmov.cr instruction.
//
task model_do_cmov_cr;
begin: t_model_cmov_cr
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    if(crs2 == 0) begin
        model_do_write_cpr(dec_arg_crd,crs1);
    end else begin
        // Do nothing
    end
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> cmov.cr %d, %d, %d", 
        dec_arg_crd, dec_arg_crs1,dec_arg_crs2);
end endtask


//
// Implementation function for the cmovn.cr instruction.
//
task model_do_cmovn_cr;
begin: t_model_cmovn_cr
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    if(crs2 == 0) begin
        // Do nothing
    end else begin
        model_do_write_cpr(dec_arg_crd,crs1);
    end
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> cmovn.cr %d, %d, %d", 
        dec_arg_crd, dec_arg_crs1,dec_arg_crs2);
end endtask


//
// Implementation function for the scatter.b instruction.
//
task model_do_scatter_b;
begin: t_model_scatter_b
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction scatter.b not implemented");
end endtask


//
// Implementation function for the gather.b instruction.
//
task model_do_gather_b;
begin: t_model_gather_b
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction gather.b not implemented");
end endtask


//
// Implementation function for the scatter.h instruction.
//
task model_do_scatter_h;
begin: t_model_scatter_h
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction scatter.h not implemented");
end endtask


//
// Implementation function for the gather.h instruction.
//
task model_do_gather_h;
begin: t_model_gather_h
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction gather.h not implemented");
end endtask


//
// Implementation function for the lmix.cr instruction.
//
task model_do_lmix_cr;
begin: t_model_lmix_cr
    reg  [31:0] crs1, crs2, crd;
    reg  [31:0] result;
    reg  [31:0] t0;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crd , crd );
    t0      = (crs1 >> dec_arg_lut4) | (crs1 << (32-dec_arg_lut4));
    result  = (~crs2 & crd) | (crs2 & t0);
    $display("ISE> lmix.cr c%d, c%d, c%d, %d",
        dec_arg_crd, dec_arg_crs1, dec_arg_crs2, dec_arg_lut4);
end endtask


//
// Implementation function for the hmix.cr instruction.
//
task model_do_hmix_cr;
begin: t_model_hmix_cr
    reg  [31:0] crs1, crs2, crd;
    reg  [31:0] result;
    reg  [31:0] t0;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crd , crd );
    t0      = (crs1 >> (16+dec_arg_lut4)) | (crs1 << (32-(16+dec_arg_lut4)));
    result  = (~crs2 & crd) | (crs2 & t0);
    $display("ISE> hmix.cr c%d, c%d, c%d, 16+%d",
        dec_arg_crd, dec_arg_crs1, dec_arg_crs2, dec_arg_lut4);
end endtask


//
// Implementation function for the bop.cr instruction.
//
task model_do_bop_cr;
begin: t_model_bop_cr
    reg  [31:0] crs1, crs2;
    integer i;
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    for(i = 0; i < 32; i = i + 1)
        result[i] = dec_arg_lut4[{crs1[i],crs2[2]}];
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> bop.cr %d, %d, %d, %4b", dec_arg_crd,
        dec_arg_crs1, dec_arg_crs2, dec_arg_lut4[3:0]);
end endtask


//
// Implementation function for the equ.mp instruction.
//
task model_do_equ_mp;
begin: t_model_equ_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction equ.mp not implemented");
end endtask


//
// Implementation function for the ltu.mp instruction.
//
task model_do_ltu_mp;
begin: t_model_ltu_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction ltu.mp not implemented");
end endtask


//
// Implementation function for the gtu.mp instruction.
//
task model_do_gtu_mp;
begin: t_model_gtu_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction gtu.mp not implemented");
end endtask


//
// Implementation function for the add3.mp instruction.
//
task model_do_add3_mp;
begin: t_model_add3_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction add3.mp not implemented");
end endtask


//
// Implementation function for the add2.mp instruction.
//
task model_do_add2_mp;
begin: t_model_add2_mp
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction add2.mp not implemented");
end endtask


//
// Implementation function for the sub3.mp instruction.
//
task model_do_sub3_mp;
begin: t_model_sub3_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction sub3.mp not implemented");
end endtask


//
// Implementation function for the sub2.mp instruction.
//
task model_do_sub2_mp;
begin: t_model_sub2_mp
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction sub2.mp not implemented");
end endtask


//
// Implementation function for the slli.mp instruction.
//
task model_do_slli_mp;
begin: t_model_slli_mp
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction slli.mp not implemented");
end endtask


//
// Implementation function for the sll.mp instruction.
//
task model_do_sll_mp;
begin: t_model_sll_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction sll.mp not implemented");
end endtask


//
// Implementation function for the srli.mp instruction.
//
task model_do_srli_mp;
begin: t_model_srli_mp
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction srli.mp not implemented");
end endtask


//
// Implementation function for the srl.mp instruction.
//
task model_do_srl_mp;
begin: t_model_srl_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction srl.mp not implemented");
end endtask


//
// Implementation function for the acc2.mp instruction.
//
task model_do_acc2_mp;
begin: t_model_acc2_mp
    reg  [31:0] crs1, crs2;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction acc2.mp not implemented");
end endtask


//
// Implementation function for the acc1.mp instruction.
//
task model_do_acc1_mp;
begin: t_model_acc1_mp
    reg  [31:0] crs1;
    model_do_read_cpr(dec_arg_crs1, crs1);
    $display("ISE> ERROR: Instruction acc1.mp not implemented");
end endtask


//
// Implementation function for the mac.mp instruction.
//
task model_do_mac_mp;
begin: t_model_mac_mp
    reg  [31:0] crs1, crs2, crs3;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crs2, crs2);
    model_do_read_cpr(dec_arg_crs3, crs3);
    $display("ISE> ERROR: Instruction mac.mp not implemented");
end endtask


//
// Implementation function for the lbu.cr instruction.
//
task model_do_lbu_cr;
begin: t_model_lbu_cr
    $display("ISE> ERROR: Instruction lbu.cr not implemented");
end endtask


//
// Implementation function for the lhu.cr instruction.
//
task model_do_lhu_cr;
begin: t_model_lhu_cr
    $display("ISE> ERROR: Instruction lhu.cr not implemented");
end endtask


//
// Implementation function for the lw.cr instruction.
//
task model_do_lw_cr;
begin: t_model_lw_cr
    reg [31:0] exp_addr;
    reg        wen  ;
    reg [ 3:0] ben  ;
    reg [31:0] addr ;
    reg [31:0] rdata;
    reg [31:0] wdata;
    reg        error;
    exp_addr = cop_rs1 + {{21{dec_arg_imm11[10]}},dec_arg_imm11};
    if(exp_addr[1:0] == 2'b00) begin
        model_do_get_mem_transaction(wen,ben,addr,rdata,wdata,error);
        if(error) begin
            model_do_instr_result(ISE_RESULT_LOAD_ACCESS_FAULT);
        end else begin
            if(addr != exp_addr) begin
                $display("t=%0d ERROR: lw.cr address expected %h got %h.",
                    $time, exp_addr, addr);
                #40 $finish;
            end
            model_do_write_cpr(dec_arg_crd, rdata);
            $display("ISE> lw.cr %d <- MEM[%h] (%h)",
                dec_arg_crd, exp_addr,rdata);
        end
    end else begin
        model_do_instr_result(ISE_RESULT_LOAD_ADDR_MISALIGN);
        $display("ISE> lw.cr %d <- MEM[%h] bad addr",
            dec_arg_crd, exp_addr,rdata);
    end
end endtask


//
// Implementation function for the lui.cr instruction.
//
task model_do_lui_cr;
begin: t_model_lui_cr
    reg  [31:0] crsd;
    reg  [15:0] imm;
    reg  [31:0] wdata;
    model_do_read_cpr(dec_arg_crd, crsd);
    imm   = {dec_arg_imm11,dec_arg_imm5};
    wdata = {imm,crsd[15:0]};
    model_do_write_cpr(dec_arg_crd, wdata);
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> lui.cr %d, %h", dec_arg_crd, imm);
end endtask


//
// Implementation function for the lli.cr instruction.
//
task model_do_lli_cr;
begin: t_model_lli_cr
    reg  [31:0] crsd;
    reg  [15:0] imm;
    reg  [31:0] wdata;
    model_do_read_cpr(dec_arg_crd, crsd);
    imm   = {dec_arg_imm11,dec_arg_imm5};
    wdata = {crsd[31:16],imm};
    model_do_write_cpr(dec_arg_crd, wdata);
    model_do_instr_result(ISE_RESULT_SUCCESS);
    $display("ISE> lli.cr %d, %h", dec_arg_crd, imm);
end endtask


//
// Implementation function for the twid.b instruction.
//
task model_do_twid_b;
begin: t_model_twid_b
    reg  [31:0] crs1;
    reg  [ 7:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    split[3] = crs1[31:24];    split[2] = crs1[23:16];
    split[1] = crs1[15: 8];    split[0] = crs1[ 7: 0];
    result   = {split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.b c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.n0 instruction.
//
task model_do_twid_n0;
begin: t_model_twid_n0
    reg  [31:0] crs1;
    reg  [ 3:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    split[3] = crs1[15:12];    split[2] = crs1[11: 8];
    split[1] = crs1[ 7: 4];    split[0] = crs1[ 3: 0];
    result   = {crs1[31:16],
                split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.n0 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.n1 instruction.
//
task model_do_twid_n1;
begin: t_model_twid_n1
    reg  [31:0] crs1;
    reg  [ 3:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    split[3] = crs1[31:28];    split[2] = crs1[27:24];
    split[1] = crs1[23:20];    split[0] = crs1[19:16];
    result   = {split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0],
                crs1[15:0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.n1 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.c0 instruction.
//
task model_do_twid_c0;
begin: t_model_twid_c0
    reg  [31:0] crs1;
    reg  [ 7:0] ibyte;
    reg  [ 1:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    ibyte    = crs1[7:0];
    split[3] = ibyte[ 7: 6]; split[2] = ibyte[ 5: 4];
    split[1] = ibyte[ 3: 2]; split[0] = ibyte[ 1: 0];
    result   = {crs1[31:8],
                split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.c0 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.c1 instruction.
//
task model_do_twid_c1;
begin: t_model_twid_c1
    reg  [31:0] crs1;
    reg  [ 7:0] ibyte;
    reg  [ 1:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    ibyte    = crs1[15:8];
    split[3] = ibyte[ 7: 6]; split[2] = ibyte[ 5: 4];
    split[1] = ibyte[ 3: 2]; split[0] = ibyte[ 1: 0];
    result   = {crs1[31:16],
                split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0],
                crs1[7:0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.c1 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.c2 instruction.
//
task model_do_twid_c2;
begin: t_model_twid_c2
    reg  [31:0] crs1;
    reg  [ 7:0] ibyte;
    reg  [ 1:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    ibyte    = crs1[23:16];
    split[3] = ibyte[ 7: 6]; split[2] = ibyte[ 5: 4];
    split[1] = ibyte[ 3: 2]; split[0] = ibyte[ 1: 0];
    result   = {crs1[31:24],
                split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0],
                crs1[15:0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.c2 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the twid.c3 instruction.
//
task model_do_twid_c3;
begin: t_model_twid_c3
    reg  [31:0] crs1;
    reg  [ 7:0] ibyte;
    reg  [ 1:0] split[3:0];
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    ibyte    = crs1[31:24];
    split[3] = ibyte[ 7: 6]; split[2] = ibyte[ 5: 4];
    split[1] = ibyte[ 3: 2]; split[0] = ibyte[ 1: 0];
    result   = {split[dec_arg_b3], split[dec_arg_b2],
                split[dec_arg_b1], split[dec_arg_b0],
                crs1[23:0]};
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> twid.c3 c%0d, c%0d, %d, %d, %d, %d",
        dec_arg_crd,dec_arg_crs1,dec_arg_b3,dec_arg_b2, dec_arg_b1,
        dec_arg_b0);
end endtask


//
// Implementation function for the ins.cr instruction.
//
task model_do_ins_cr;
begin: t_model_ins_cr
    reg  [31:0] crs1;
    reg  [31:0] crd ;
    reg  [5:0]  s;
    reg  [5:0]  l;
    reg  [31:0] mask;
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    model_do_read_cpr(dec_arg_crd , crd );
    s = {dec_arg_cs, 1'b0};
    l = {dec_arg_cl, 1'b0};
    mask = (~(32'hFFFF_FFFF << l)) << s;
    result = (mask & (crs1 << s)) | ((~mask)&crd);
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> ins.cr %d, %d[%d:%d]", dec_arg_crd, dec_arg_crs1,
        s+l,s);
end endtask


//
// Implementation function for the ext.cr instruction.
//
task model_do_ext_cr;
begin: t_model_ext_cr
    reg  [31:0] crs1;
    reg  [5:0]  s;
    reg  [5:0]  l;
    reg  [31:0] result;
    model_do_read_cpr(dec_arg_crs1, crs1);
    s = {dec_arg_cs, 1'b0};
    l = {dec_arg_cl, 1'b0};
    result = (crs1 >> s) & (~(32'hFFFF_FFFF << l));
    model_do_write_cpr(dec_arg_crd, result);
    $display("ISE> ext.cr %d, %d[%d:%d]", dec_arg_crd, dec_arg_crs1,
        s+l,s);
end endtask


//
// Implementation function for the sb.cr instruction.
//
task model_do_sb_cr;
begin: t_model_sb_cr
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction sb.cr not implemented");
end endtask


//
// Implementation function for the sh.cr instruction.
//
task model_do_sh_cr;
begin: t_model_sh_cr
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction sh.cr not implemented");
end endtask


//
// Implementation function for the sw.cr instruction.
//
task model_do_sw_cr;
begin: t_model_sw_cr
    reg  [31:0] crs2;
    model_do_read_cpr(dec_arg_crs2, crs2);
    $display("ISE> ERROR: Instruction sw.cr not implemented");
end endtask




// ------------------------------------------------------------------------

//
// Model Control
//
//  This process implements the main model control loop. It runs once every
//  clock tick, and models a single instruction or action every cycle.
//
always @(posedge g_clk) begin : p_model_control

    if(!g_resetn) begin
        
        model_do_reset();

    end else if(cop_insn_valid && !model_multi_cycle) begin

        // Reset model outputs ready for new instruction.
        model_do_clear_outputs();
        
        if (dec_invalid_opcode) model_do_invalid_opcode();
        else if (dec_mv2gpr     ) model_do_mv2gpr     ();
        else if (dec_mv2cop     ) model_do_mv2cop     ();
        else if (dec_add_px     ) model_do_add_px     ();
        else if (dec_sub_px     ) model_do_sub_px     ();
        else if (dec_mul_px     ) model_do_mul_px     ();
        else if (dec_sll_px     ) model_do_sll_px     ();
        else if (dec_srl_px     ) model_do_srl_px     ();
        else if (dec_rot_px     ) model_do_rot_px     ();
        else if (dec_slli_px    ) model_do_slli_px    ();
        else if (dec_srli_px    ) model_do_srli_px    ();
        else if (dec_roti_px    ) model_do_roti_px    ();
        else if (dec_rseed_cr   ) model_do_rseed_cr   ();
        else if (dec_rsamp_cr   ) model_do_rsamp_cr   ();
        else if (dec_cmov_cr    ) model_do_cmov_cr    ();
        else if (dec_cmovn_cr   ) model_do_cmovn_cr   ();
        else if (dec_scatter_b  ) model_do_scatter_b  ();
        else if (dec_gather_b   ) model_do_gather_b   ();
        else if (dec_scatter_h  ) model_do_scatter_h  ();
        else if (dec_gather_h   ) model_do_gather_h   ();
        else if (dec_lmix_cr    ) model_do_lmix_cr    ();
        else if (dec_hmix_cr    ) model_do_hmix_cr    ();
        else if (dec_bop_cr     ) model_do_bop_cr     ();
        else if (dec_equ_mp     ) model_do_equ_mp     ();
        else if (dec_ltu_mp     ) model_do_ltu_mp     ();
        else if (dec_gtu_mp     ) model_do_gtu_mp     ();
        else if (dec_add3_mp    ) model_do_add3_mp    ();
        else if (dec_add2_mp    ) model_do_add2_mp    ();
        else if (dec_sub3_mp    ) model_do_sub3_mp    ();
        else if (dec_sub2_mp    ) model_do_sub2_mp    ();
        else if (dec_slli_mp    ) model_do_slli_mp    ();
        else if (dec_sll_mp     ) model_do_sll_mp     ();
        else if (dec_srli_mp    ) model_do_srli_mp    ();
        else if (dec_srl_mp     ) model_do_srl_mp     ();
        else if (dec_acc2_mp    ) model_do_acc2_mp    ();
        else if (dec_acc1_mp    ) model_do_acc1_mp    ();
        else if (dec_mac_mp     ) model_do_mac_mp     ();
        else if (dec_lbu_cr     ) model_do_lbu_cr     ();
        else if (dec_lhu_cr     ) model_do_lhu_cr     ();
        else if (dec_lw_cr      ) model_do_lw_cr      ();
        else if (dec_lui_cr     ) model_do_lui_cr     ();
        else if (dec_lli_cr     ) model_do_lli_cr     ();
        else if (dec_twid_b     ) model_do_twid_b     ();
        else if (dec_twid_n0    ) model_do_twid_n0    ();
        else if (dec_twid_n1    ) model_do_twid_n1    ();
        else if (dec_twid_c0    ) model_do_twid_c0    ();
        else if (dec_twid_c1    ) model_do_twid_c1    ();
        else if (dec_twid_c2    ) model_do_twid_c2    ();
        else if (dec_twid_c3    ) model_do_twid_c3    ();
        else if (dec_ins_cr     ) model_do_ins_cr     ();
        else if (dec_ext_cr     ) model_do_ext_cr     ();
        else if (dec_sb_cr      ) model_do_sb_cr      ();
        else if (dec_sh_cr      ) model_do_sh_cr      ();
        else if (dec_sw_cr      ) model_do_sw_cr      ();
        else begin
            $display("ERROR: We should never reach here!");
        end

    end

end

endmodule
