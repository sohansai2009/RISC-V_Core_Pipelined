`default_nettype none

module tt_um_yarp_core (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Internal wires connecting the wrapper to your core
    wire        instr_mem_req;
    wire [31:0] instr_mem_addr;
    logic [31:0] instr_mem_rd_data;
    wire [8:0]  retire_count;

    // Instantiate your top module
    yarp_top #(
        .RESET_PC(32'h1000)
    ) u_yarp_top (
        .clk                 (clk),
        .reset_n             (rst_n),
        .instr_mem_req_o     (instr_mem_req),
        .instr_mem_addr_o    (instr_mem_addr),
        .instr_mem_rd_data_i (instr_mem_rd_data),
        .retire_count        (retire_count)
    );

    // --------------------------------------------------------
    // Internal Instruction ROM
    // --------------------------------------------------------
    // Option 1: Yosys/OpenLane synthesis supports $readmemh. 
    // You can load your existing instruction.hex file directly into the silicon.
    
    logic [31:0] imem [0:255];
    
    initial begin
        // Ensure this path matches where instruction.hex is located 
        // relative to the Tiny Tapeout synthesis execution directory.
        $readmemh("instruction.hex", imem); 
    end
    
    // Using bits [9:2] to match your testbench's word-aligned addressing
    assign instr_mem_rd_data = imem[instr_mem_addr[9:2]];

    /* 
    // Option 2: If $readmemh fails during the Tiny Tapeout GitHub Actions flow, 
    // use a hardcoded combinational case statement instead:
    
    always_comb begin
        case (instr_mem_addr)
            32'h1000: instr_mem_rd_data = 32'h00000013; // NOP (addi x0, x0, 0)
            32'h1004: instr_mem_rd_data = 32'h00100093; // addi x1, x0, 1
            32'h1008: instr_mem_rd_data = 32'h00200113; // addi x2, x0, 2
            32'h100c: instr_mem_rd_data = 32'h002081B3; // add x3, x1, x2
            default:  instr_mem_rd_data = 32'h00000013; // Default to NOP
        endcase
    end
    */

    // --------------------------------------------------------
    // Pin Mappings
    // --------------------------------------------------------
    // Output the lower 8 bits of the retire count so you can observe 
    // the processor making progress on the physical chip.
    assign uo_out = retire_count[7:0];

    // Tie off unused bidirectional pins to 0 (input mode)
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0; 

    // Suppress linter warnings for unused Tiny Tapeout signals
    wire _unused = &{ena, ui_in, uio_in, retire_count[8], instr_mem_req};

endmodule
