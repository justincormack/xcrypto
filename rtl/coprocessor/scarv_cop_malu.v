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
// module: scarv_cop_malu
//
//  Multi-precision arithmetic and shift module.
//
module scarv_cop_malu (
input  wire         g_clk            , // Global clock
input  wire         g_resetn         , // Synchronous active low reset.

input  wire         malu_ivalid      , // Valid instruction input
output wire         malu_idone       , // Instruction complete

input  wire [31:0]  malu_rs1         , // Source register 1
input  wire [31:0]  malu_rs2         , // Source register 2
input  wire [31:0]  malu_rs3         , // Source register 3

input  wire [31:0]  id_imm           , // Source immedate
input  wire [ 2:0]  id_class         , // Instruction class
input  wire [ 3:0]  id_subclass      , // Instruction subclass

output wire [ 3:0]  malu_cpr_rd_ben  , // Writeback byte enable
output wire [31:0]  malu_cpr_rd_wdata  // Writeback data
);

`include "scarv_cop_common.vh"

//
// Individual instruction decoding.
//

wire is_equ_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_EQU_MP ;
wire is_ltu_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_LTU_MP ;
wire is_gtu_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_GTU_MP ;
wire is_add3_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_ADD3_MP;
wire is_add2_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_ADD2_MP;
wire is_sub3_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SUB3_MP;
wire is_sub2_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SUB2_MP;
wire is_slli_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SLLI_MP;
wire is_sll_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SLL_MP ;
wire is_srli_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SRLI_MP;
wire is_srl_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_SRL_MP ;
wire is_acc2_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_ACC2_MP;
wire is_acc1_mp = malu_ivalid && id_subclass == SCARV_COP_SCLASS_ACC1_MP;
wire is_mac_mp  = malu_ivalid && id_subclass == SCARV_COP_SCLASS_MAC_MP ;

//
// MP instructions take two or three cycles
reg  [1:0] mp_fsm;
wire [1:0] n_mp_fsm = mp_fsm + 1;

always @(posedge g_clk) begin
    if(!g_resetn || malu_idone)
        mp_fsm <= 0;
    else if(malu_ivalid && !malu_idone) begin
        mp_fsm <= n_mp_fsm;
    end
end

assign malu_idone = 
    mp_fsm == 1 && (is_add2_mp) ||
    mp_fsm == 2;

// 64 bit result of all MALU instructions.
wire [63:0] malu_result = 0;

// writeback the high word or low word of the result?
wire wb_hi = 
    mp_fsm == 3 && is_add3_mp ||
    mp_fsm == 1 && is_add2_mp ;

// Write byte enable and write data selection,
assign malu_cpr_rd_ben   = 
    {4{malu_idone || malu_ivalid}};

assign malu_cpr_rd_wdata = 
    wb_hi ? malu_result[63:32] : malu_result[31: 0];


//
// Utility wires for controlling the number of operators we implement.
//

wire [63:0] adder1_lhs;
wire [63:0] adder1_rhs;
wire [64:0] adder1_result = adder1_lhs + adder1_rhs;

reg  [33:0] malu_intermediate;

assign ld_intermediate = mp_fsm == 1 && is_add3_mp;

always @(posedge g_clk) begin
    if(ld_intermediate) begin
        malu_intermediate <= adder1_result[33:0];
    end
end

assign adder1_lhs = {32'b0,malu_rs1};
assign adder1_rhs = {32'b0,malu_rs2};

endmodule
