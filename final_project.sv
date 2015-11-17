// I'm too lazy to write everything in quartus rn, so just brainstorming
// what to write for each module.

module final_project(input clk, reset,
                    output [3:0] stepperWires,
						  output laserControl);
		oscillateMirror om(clk, reset, stepperWires, laserControl);
endmodule

// The motor moves around 0.9 degrees per
// clock cycle.
module oscillateMirror(input clk, reset,
						  output [3:0] stepperWires,
						  output laserControl);
  logic [15:0] counter;
  logic [3:0] turns;
  logic [31:0] cycleCount;
  logic forward;
  always_ff @(posedge clk)
  begin
    if (reset)
    begin
      turns <= 4'b0001;
      counter <= 16'b0;
      cycleCount <= 32'b0;
		forward <= 1;
    end
	 
	 // This is the value you want to change if you want the mirror to move
	 // through a bigger angle
	 if (cycleCount == 8) begin
			cycleCount <= 0;
			forward <= ~forward;
	 end
    
    if (counter == 0)
    begin
		//turns <= {turns[2:0], turns[3]};
      turns <= forward ? {turns[2:0], turns[3]}: {turns[0], turns[3:1]};
      // If msb of turns is 1, then the cycle is about to repeat
      // debatable how we want to count cycleCount.
      // right now, if motor is moving forward, cycleCount will
      // increase. (maybe rename to degreesMoved)
      //cycleCount <= forward ? cycleCount + 1: cycleCount - 1;
		counter <= 16'b0;
		cycleCount <= cycleCount + 1'b1;
    end
    counter <= counter + 1'b1;
  end

  // Turn off the laser when the motor is turning.
  assign laserControl = ~(counter == 0);
  assign stepperWires = turns;
  
endmodule



// TODO: Implement SPI between PI and FPGA

// TODO: Implement SPI between ADC and FPGA

// TODO: Laser multiplexing + motor movement

// TODO: Determine which "string" was hit

// STRETCH: Receive note and duration played
// STRETCH: Switch between play mode vs playback mode
// STRETCH: Play only note received
