// A public wrapper may only report sleep after every outbound transfer drains.
module core_sleep_gate (
    input  logic i_core_sleep,
    input  logic i_instruction_busy,
    input  logic i_data_busy,
    output logic o_core_sleep
);

    assign o_core_sleep =
        i_core_sleep && !i_instruction_busy && !i_data_busy;

endmodule
