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

`include "fml_pack_widths.vh"

//
// Checker for bit packed multiply instruction.
// - Only checks cases where pack width >= 4
//
`VTX_CHECKER_MODULE_BEGIN(instr_pmul_l)

// Pack width of the instruction
wire [2:0] pw = `VTX_INSTR_PACK_WIDTH;

// Compute expected result into register called "result". See
// `verif/formal/fml_pack_widths.vh` for macro definition.
`PACK_WIDTH_ARITH_OPERATION_RESULT(*,0)

// Only check pmul_l instructions
always @(posedge `VTX_CLK_NAME) if(vtx_valid) restrict(dec_pmul_l);

//
// pmul_l
//
`VTX_CHECK_INSTR_BEGIN(pmul_l) 

    restrict(pw != SCARV_COP_PW_1 && pw != SCARV_COP_PW_2);

    // Correct pack width encoding value or instruction gives in bad
    // opcode result.
    `VTX_ASSERT_PACK_WIDTH_CORRECT

    // Result comes from the PACK_WIDTH_ARITH_OPERATION_RESULT macro.
    if(vtx_instr_result == SCARV_COP_INSN_SUCCESS) begin
        `VTX_ASSERT_CRD_VALUE_IS(result)
        `VTX_COVER(pw == SCARV_COP_PW_4 );
        `VTX_COVER(pw == SCARV_COP_PW_8 );
        `VTX_COVER(pw == SCARV_COP_PW_16);
    end

    // Never causes writeback to GPRS
    `VTX_ASSERT_WEN_IS_CLEAR

`VTX_CHECK_INSTR_END(pmul_l)

`VTX_CHECKER_MODULE_END
