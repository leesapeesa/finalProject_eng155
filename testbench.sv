// testbench
module testbench();
  logic clk, reset, sclk, sdi, load, sdo, adcMiso, adcMosi, CS, spiClk, laserControl;
  logic [3:0] stepperWires;
  logic [7:0] input;
  logic [7:0] [7:0] strings;
  logic [5:0] counter;
  final_project dut(clk, reset, sclk, sdi, load, sdo, adcMiso, adcMosi, CS, spiClk,
                   stepperWires, laserControl);
  
  initial begin
    input <= 8'h01;
    load <= 1'b1;
  end  
  
  // generate clock
  initial
    forever begin
      clk = 1'b0; #5;
      clk = 1'b1; #5;
    end
  
  assign {stringCount, bitInString} = counter;
  always @(posedge clk) begin
    if (counter < 64) begin
      #1; sdi = input[7 - counter];
      #1; sclk = 1;
      #1; strings[stringCount][7 - bitInString] = sdo;
      #4; sclk = 0;
      counter = counter + 1;
    end else if (i == 64) begin
      load = 1'b0;
    end
  end
endmodule
