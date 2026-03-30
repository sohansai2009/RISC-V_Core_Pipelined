// --------------------------------------------------------
// YARP: Top
//
// Designing the top module for the YARP core. This would
// instantiate and connect all the sub-modules together
// completing the entire processor.
// --------------------------------------------------------

// --------------------------------------------------------
// Yet Another RISC-V Processor - Top
// --------------------------------------------------------

module yarp_top import yarp_pkg::*; #(
  parameter RESET_PC = 32'h1000
)(
  input   logic          clk,
  input   logic          reset_n,

  // Instruction memory interface
  output  logic          instr_mem_req_o,
  output  logic [31:0]   instr_mem_addr_o,
  input   logic [31:0]   instr_mem_rd_data_i,
  output logic [8:0] retire_count


);

  //define all the internal registers
  logic [31:0] alu_op1;
  logic [31:0] imem_dec_instr1;
  logic reset_q; //flop to store the first reset
  logic [31:0] pc_q,next_pc,next_pc_seq;
  logic [4:0] dec_rf_rs1;
  logic [4:0] dec_rf_rs2;
  logic [4:0] dec_rf_rd;
  logic [6:0] dec_ctrl_op;
  logic [2:0] dec_ctrl_funct3;
  logic [7:0] dec_ctrl_funct7;
  logic dec_ctrl_r;
  logic dec_ctrl_i;
  logic dec_ctrl_s;
  logic dec_ctrl_b;
  logic dec_ctrl_u;
  logic dec_ctrl_j;
  logic [31:0] dec_imm;
  logic [31:0] rf_rs1_data,rf_rs2_data;
  logic [31:0] data_mem_rd_data;
  logic ctrl_pc_sel;
  logic ctrl_op1_sel;
  logic ctrl_op2_sel;
  logic ctrl_data_req;
  logic ctrl_data_wr;
  logic [1:0] ctrl_data_byte;
  logic ctrl_zero_extnd;
  logic ctrl_wr_en;
  logic [1:0] ctrl_rf_wr_data;
  logic [3:0] ctrl_alu_func;
  logic b_branch_taken;
  logic [31:0] opr_a_sel;
  logic [31:0] opr_b_sel;
  always_ff @(posedge clk or negedge reset_n)
    begin
      if(!reset_n)
        reset_q <= 0;
      else
        reset_q <= 1;
    end
  
  //value for seq_pc
  assign next_pc_seq=pc_q+32'h4;
  assign next_pc = (ctrl_pc_sel | b_branch_taken)?{alu_op1[31:1],1'b0}:next_pc_seq;  //if branch_taken, go to target address calculated by alu else go to next_pc loc
  
  always_ff @(posedge clk or negedge reset_n)
    begin
      if(!reset_n)
        pc_q <= RESET_PC;
      else if(reset_q) //if first reset is captured, update the  value
        pc_q<=next_pc;
    end

  logic [31:0] instr_if_id;
  // --------------------------------------------------------
  // Instruction Memory
  // --------------------------------------------------------
  yarp_instr_mem u_yarp_instr_mem (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .instr_mem_pc_i           (pc_q),  //pc_address
    .instr_mem_req_o          (instr_mem_req_o),
    .instr_mem_addr_o         (instr_mem_addr_o), //pc output address (will go into the 
    .mem_rd_data_i            (instr_mem_rd_data_i),
    .instr_mem_instr_o        (instr_if_id)  //instruction which goes to the decode stage
  );


  logic [31:0] id_instr_i; //will go as input to decode
  logic [31:0] id_pc_in; //will go as input to decode

  // IF/ID Pipeline
  if_id_pipeline u_yarp_if_id (
   .clk (clk),
   .reset_n(reset_n),
   .if_instr_in (instr_if_id),
   .if_pc_in (instr_mem_addr_o),
   .id_instr_out (id_instr_i),
   .id_pc_out (id_pc_in),
   .if_id_en (1'b1) );


  
  
  // --------------------------------------------------------
  // Instruction Decode
  // --------------------------------------------------------
  logic [31:0] dec_pc;
  yarp_decode u_yarp_decode (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .pc_addr                  (id_pc_in),//from if/id pipeline
    .instr_i                  (id_instr_i), //coming from pipeline
    .rs1_o                    (dec_rf_rs1), //decode -> rf(we will take the data present at the rs1 loc in rf
    .rs2_o                    (dec_rf_rs2),
    .rd_o                     (dec_rf_rd),
    .op_o                     (dec_ctrl_op),  //opcode goes from decode to control
    .funct3_o                 (dec_ctrl_funct3),
    .funct7_o                 (dec_ctrl_funct7),
    .r_type_instr_o           (dec_ctrl_r),
    .i_type_instr_o           (dec_ctrl_i),
    .s_type_instr_o           (dec_ctrl_s),
    .b_type_instr_o           (dec_ctrl_b),
    .u_type_instr_o           (dec_ctrl_u),
    .j_type_instr_o           (dec_ctrl_j),
    .instr_imm_o              (dec_imm),
    .next_pc_seq (dec_pc) //for j type
  );

  // --------------------------------------------------------
  // Register File
  // --------------------------------------------------------
  
  //for reg_file, wr_en_i will come from the control unit
  //wr_data_i (data to be written will come from the 4:1 mux, which will decide what type of data to be written)
  //wr_data_i can be any value from alu,mem,updated_pc,imm

  // --------------------------------------------------------
  // Control Unit
  // -------------------------------------------------------- 
 
  //logic to decide the pc_sel signal
  yarp_control u_yarp_control (
    .instr_funct3_i           (dec_ctrl_funct3),
    .instr_funct7_bit5_i      (dec_ctrl_funct7[5]),
    .instr_opcode_i           (dec_ctrl_op),
    .is_r_type_i              (dec_ctrl_r),
    .is_i_type_i              (dec_ctrl_i),
    .is_s_type_i              (dec_ctrl_s),
    .is_b_type_i              (dec_ctrl_b),
    .is_u_type_i              (dec_ctrl_u),
    .is_j_type_i              (dec_ctrl_j),
    .pc_sel_o                 (ctrl_pc_sel),
    .op1sel_o                 (ctrl_op1_sel),
    .op2sel_o                 (ctrl_op2_sel),
    .data_req_o               (ctrl_data_req),
    .data_wr_o                (ctrl_data_wr),
    .data_byte_o              (ctrl_data_byte),
    .zero_extnd_o             (ctrl_zero_extnd),
    .rf_wr_en_o               (ctrl_wr_en),
    .rf_wr_data_o             (ctrl_rf_wr_data),  //decides what data to write to rf
    .alu_func_o               (ctrl_alu_func)
  );


  //id_ex_pipeline
  logic [31:0] id_ex_pc;
  logic [31:0] id_ex_imm;
  logic [31:0] id_ex_rs2_data;
  logic [31:0] id_ex_rs1_data;
  logic id_ex_rf_wr_en;
  logic id_ex_mem_zero_extnd;
  logic id_ex_mem_data_wr;
  logic [1:0] id_ex_mem_data_type;
  logic id_ex_mem_req;
  logic [1:0] id_ex_rf_wr_data;
  logic [31:0] id_ex_alu_func_o;
  logic id_ex_op1_sel;
  logic id_ex_op2_sel;
  logic [4:0] id_ex_rd_addr_out;
  id_ex_pipeline u_yarp_id_ex_pipeline(
  .clk (clk),
  .reset_n (reset_n),
  .ctrl_op1_sel (ctrl_op1_sel),
  .ctrl_op2_sel (ctrl_op2_sel),
  .ctrl_alu_func (ctrl_alu_func),
  .ctrl_rf_wr_data (ctrl_rf_wr_data),
  .ctrl_data_req (ctrl_data_req),
  .ctrl_data_byte (ctrl_data_byte),
  .rd_addr (dec_rf_rd),
  .ctrl_data_wr (ctrl_data_wr),
  .ctrl_zero_extnd (ctrl_zero_extnd),
  .ctrl_rf_wr_en (ctrl_wr_en),
  .rf_rs1_data(rf_rs1_data),
  .rf_rs2_data(rf_rs2_data),
  .id_ex_en (1'b1),
  .imm (dec_imm),
  .pc_id (dec_pc),
  .ex_op1_sel (id_ex_op1_sel), //will help in deciding which value to send to execute
  .ex_op2_sel (id_ex_op2_sel),
  .ex_alu_func (id_ex_alu_func_o), //input to alu/execute
  .wb_rf_wr_data (id_ex_rf_wr_data),
  .mem_data_req (id_ex_mem_req),
  .mem_data_byte (id_ex_mem_data_type),
  .mem_data_wr (id_ex_mem_data_wr),
  .mem_zero_extnd (id_ex_mem_zero_extnd),
  .wb_rf_wr_en (id_ex_rf_wr_en),
  .ex_rs1_data (id_ex_rs1_data),
  .ex_rs2_data (id_ex_rs2_data),
  .imm_o (id_ex_imm),
  .pc_ex (id_ex_pc),
  .rd_addr_out (id_ex_rd_addr_out));
  
  
  // --------------------------------------------------------
  // Branch Control
  // --------------------------------------------------------
  yarp_branch_control u_yarp_branch_control (
    .opr_a_i                  (rf_rs1_data),
    .opr_b_i                  (rf_rs2_data),
    .is_b_type_ctl_i          (dec_ctrl_b),
    .instr_func3_ctl_i       (dec_ctrl_funct3),
    .branch_taken_o           (b_branch_taken)
  );

  // --------------------------------------------------------
  // Execute Unit
  // --------------------------------------------------------
  //we need muxes to implement
  //opr_a_i will be pc if branch type instr else it will be rs1_data
  assign opr_a_sel= (id_ex_op1_sel)?id_ex_pc:id_ex_rs1_data; //we need to use id_ex_pc as input to alu. this is mainly for auipc. we need to add pc (at the time when instr was fetched) to immediate value
  
  assign opr_b_sel=(id_ex_op2_sel)?id_ex_imm:id_ex_rs2_data;

  logic [1:0] ex_mem_wr_data;
  logic ex_mem_data_req;
  logic [1:0] ex_mem_data_type;
  logic ex_mem_data_wr;
  logic ex_mem_zero_extnd;
  logic ex_mem_wb_rf_wr_en;
  logic [31:0] ex_mem_imm;
  logic [31:0] ex_mem_pc;
  logic [4:0] ex_mem_rd_addr_in;
  logic [31:0] ex_mem_rs2_wr_data;
  yarp_execute u_yarp_execute (
    .clk                      (clk),
    .reset_n                  (reset_n), 
    //inputs coming from the id/ex pipeline
    .opr_a_i                  (opr_a_sel),
    .opr_b_i                  (opr_b_sel),
    .op_sel_i                 (id_ex_alu_func_o),
    .wb_rf_wr_data (id_ex_rf_wr_data), 
    .mem_data_req (id_ex_mem_req),
    .mem_data_type (id_ex_mem_data_type),
    .mem_data_wr (id_ex_mem_data_wr),
    .mem_zero_extnd (id_ex_mem_zero_extnd),
    .wb_rf_wr_en (id_ex_rf_wr_en),
    .imm_in (id_ex_imm),
    .pc_in (id_ex_pc),
    .rd_addr_in (id_ex_rd_addr_out),
    .rs2_mem_wr_data(rf_rs2_data),
    //below are the outputs, they have to go to the ex/mem pipeline
    .wb_rf_wr_data_o (ex_mem_wr_data),
    .mem_data_req_o (ex_mem_data_req),
    .mem_data_type_o (ex_mem_data_type),
    .mem_data_wr_o(ex_mem_data_wr),
    .mem_zero_extnd_o (ex_mem_zero_extnd),
    .wb_rf_wr_en_o (ex_mem_wb_rf_wr_en),
    .imm_o (ex_mem_imm),
    .pc_o (ex_mem_pc),
    .rd_addr_out (ex_mem_rd_addr_in),
    .alu_res_o (alu_op1),
    .ex_mem_rs2_wr_data(ex_mem_rs2_wr_data)
  );


  //ex_mem pipeline
  logic [31:0] mem_addr;
  logic [1:0] mem_wb_rf_wr_data;
  logic mem_data_req;
  logic mem_data_type;
  logic mem_data_wr;
  logic mem_zero_extnd;
  logic mem_wb_rf_wr_en;
  logic [31:0] mem_imm_in;
  logic [31:0] mem_pc_in;
  logic [4:0] ex_mem_rd_addr;
  logic [31:0] mem_wr_data;
  
  ex_mem_pipeline u_yarp_ex_mem_pipeline(
  .clk (clk),
  .reset_n (reset_n),
  //define the inputs to the pipeline
  .ex_result (alu_op1),
  .ex_wb_rf_wr_data (ex_mem_wr_data),
  .mem_data_req (ex_mem_data_req),
  .mem_data_type (ex_mem_data_type),
  .mem_data_wr (ex_mem_data_wr),
  .mem_zero_extnd (ex_mem_zero_extnd),
  .wb_rf_wr_en (ex_mem_wb_rf_wr_en),
  .ex_mem_en (1'b1), //pipeline enable signal
  .imm_dec_in (ex_mem_imm),
  .pc_ex (ex_mem_pc),
  .ex_rd_addr (ex_mem_rd_addr_in),
  .ex_mem_wr_data (ex_mem_rs2_wr_data),
  //define the outputs
  .ex_result_o (mem_addr),
  .mem_wb_rf_wr_data (mem_wb_rf_wr_data),
  .mem_data_req_o (mem_data_req),
  .mem_data_type_o (mem_data_type),
  .mem_data_wr_o (mem_data_wr),
  .mem_zero_extnd_o (mem_zero_extnd),
  .wb_rf_wr_en_o (mem_wb_rf_wr_en),
  .imm_dec_out (mem_imm_in),
  .pc_mem (mem_pc_in) ,
  .ex_rd_addr_out (ex_mem_rd_addr),
   .mem_wr_data (mem_wr_data));
  

  // --------------------------------------------------------
  // Data Memory
  // --------------------------------------------------------
  logic [1:0] mem_wb_rf_wr_data_in;
  logic mem_wb_rf_wr_en_in;
  logic [31:0] mem_wb_imm;
  logic [31:0] mem_wb_pc;
  logic mem_wb_data;
  logic mem_wb_comp;
  logic [31:0] mem_wb_ex_res;
  logic [4:0] mem_rd_addr_out;
  data_mem u_yarp_data_mem (
  .clk (clk),
  .reset_n (reset_n),
  //inputs to the memory
  .ex_res_in (mem_addr),
  .mem_wb_rf_wr_data(mem_wb_rf_wr_data),
  .mem_data_req(mem_data_req),
  .mem_data_type (mem_data_type),
  .mem_data_wr (mem_data_wr),
  .mem_zero_extnd (mem_zero_extnd),
  .wb_rf_wr_en (mem_wb_rf_wr_en),
  .imm_dec_in (mem_imm_in),
  .pc_in (mem_pc_in),
  .mem_rd_addr_in (ex_mem_rd_addr),
  .data_mem_wr_data(mem_wr_data),
  
  //output signals, have to go to mem/wb pipeline
  .mem_wb_rf_wr_data_o(mem_wb_rf_wr_data_in),
  .wb_rf_wr_en_o(mem_wb_rf_wr_en_in),
  .imm_dec_o (mem_wb_imm),
  .pc_o (mem_wb_pc),
  .mem_data_out (mem_wb_data), //output of load operations
  .mem_comp_out (mem__wb_comp),
  .ex_out (mem_wb_ex_res) ,
  .mem_rd_addr_out (mem_rd_addr_out));


  /*yarp_regfile u_yarp_regfile (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .rs1_addr_i               (dec_rf_rs1),
    .rs2_addr_i               (dec_rf_rs2),
    .rd_addr_i                (dec_rf_rd),
    .wr_en_i                  (ctrl_wr_en),
    .wr_data_i                (rf_wr_data),
    .rs1_data_o               (rf_rs1_data),
    .rs2_data_o               (rf_rs2_data),
  );*/
  //mem_wb pipeline
  logic [31:0] rf_data_in;
  logic rf_wr_en;
  logic [1:0] rf_wr_data;
  logic [31:0] rf_alu_op;
  logic [31:0] rf_imm;
  logic [31:0] rf_pc;
  logic [4:0] rf_rd_addr_in;
  
  logic retire_rf;
  mem_wb_pipeline u_yarp_mem_wb_pipeline(
  .clk (clk),
  .reset_n (reset_n),
  //define the inputs
  .mem_data (mem_wb_data),
  .mem_rf_wr_en (mem_wb_rf_wr_en_in),
  .mem_rf_wr_data (mem_wb_rf_wr_data_in), //decided which data to write to reg_file
  .ex_result_in (mem_wb_ex_res),
  .imm_in (mem_wb_imm),
  .pc_mem (mem_wb_pc),
  .mem_wb_en (1'b1),
  .wb_rd_addr_in(mem_rd_addr_out),
  
  //define the outputs
  .wb_mem_data_out (rf_data_in), //load data
  .wb_rf_wr_en (rf_wr_en),
  .wb_rf_wr_data (rf_wr_data), //which data has to be written to the reg_file
  .wb_ex_result_in (rf_alu_op), //alu output
  .wb_imm (rf_imm), //immedtaie value
  .wb_pc (rf_pc),
  .wb_rd_addr_out (rf_rd_addr_in),
  .instr_ready_to_retire(retire_rf) 
  ); //pc value
  
   logic [31:0] reg_file_data_in;
   logic retire_done;
    assign reg_file_data_in = (rf_wr_data==Alu) ? rf_alu_op:
    (rf_wr_data==Mem)?rf_data_in:
    (rf_wr_data==Imm)?rf_imm:
    rf_pc;
    
  yarp_regfile u_yarp_regfile (
    .clk                      (clk),
    .reset_n                  (reset_n),
    .rs1_addr_i               (dec_rf_rs1),
    .rs2_addr_i               (dec_rf_rs2),
    .rd_addr_i                (rf_rd_addr_in), //the rd_address has to come from the wb pipeline, as it is used during the wb stage
    .wr_en_i                  (rf_wr_en), //this is the write back signal, so it has to come from the mem/wb pipeline
    .wr_data_i                (reg_file_data_in), //this is the write back signal, so it has to come from the mem/wb pipeline
    .ready_retire (retire_rf),
    .retire (retire_done),
    .rs1_data_o               (rf_rs1_data),
    .rs2_data_o               (rf_rs2_data)
  );
  
  always_ff @(posedge clk)
  begin
  if(!reset_n)
  retire_count<=0;
  else if(retire_done)
  retire_count<=retire_count+1;
  else
  retire_count<=retire_count;
  end
  
endmodule
