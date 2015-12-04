// testbench
module testbench();
  logic clk, reset, sclk, sdi, load, sdo, adcMiso, adcMosi, CS, spiClk, laserControl;
  logic [3:0] stepperWires;
  logic [63:0] action;
  logic [7:0] [7:0] strings;
  logic [7:0] oneString;
  logic [6:0] counter;
  logic [2:0] stringCount, bitInString;
  final_project dut(clk, reset, sclk, sdi, load, sdo, adcMiso, adcMosi, CS, spiClk,
                   stepperWires, laserControl);
  
  initial begin
    action <= 64'h01_02_03_04_05_06_07_08;
	 counter <= 0;
  end  
  
  initial begin
	 load <= 0;
	 reset <= 0; #5;
	 reset <= 1; #160;
	 load <= 1'b1;
	 reset <= 0; #5;
	end
  // generate clock
  initial
    forever begin
      clk = 1'b0; #5;
      clk = 1'b1; #5;
    end
  
  assign {stringCount, bitInString} = counter;
  always @(posedge clk) begin
	 if (reset) begin
		#5; sclk = 1; counter = 0;
		#5; sclk = 0;
		end
    else begin
	 if (counter < 64) begin
      #1; sdi = action[63 - counter];
      #1; sclk = 1; strings[stringCount][7 - bitInString] = sdo;
		#5; sclk = 0;
      counter <= counter + 1;
    end else begin
      load = 1'b0;
    end
	 end
  end
endmodule
