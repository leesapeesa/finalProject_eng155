// I'm too lazy to write everything in quartus rn, so just brainstorming
// what to write for each module.

module final_project(input clk, reset,
                    output [3:0] stepperWires);
endmodule

// The motor moves around 0.9 degrees per
// clock cycle.
module motorControl(input clk, reset, forward,
                    input [8:0] period,
                    output [3:0] stepperWires,
                    output [31:0] cycleCount);
  logic [9:0] counter;
  logic [3:0] turns;
  always_ff @(posedge clk)
  begin
    if (reset)
    begin
      turns <= 4'b0001;
      counter <= 10'b0;
      cycleCount <= 32'b0;
    end
    
    if (counter == period)
    begin
      turns <= forward ? {turns[2:0], turns[3]}: {turns[0], turns[3:1]};
      // If msb of turns is 1, then the cycle is about to repeat
      // debatable how we want to count cycleCount.
      // right now, if motor is moving forward, cycleCount will
      // increase. (maybe rename to degreesMoved)
      cycleCount <= forward ? cycleCount + 1: cycleCount - 1;
    end
    counter <= counter + 1'b1;
  end

  assign stepperWires = turns;
endmodule

// TODO: Implement SPI between PI and FPGA

// TODO: Implement SPI between ADC and FPGA

// TODO: Laser multiplexing + motor movement

// TODO: Determine which "string" was hit

// STRETCH: Receive note and duration played
// STRETCH: Switch between play mode vs playback mode
// STRETCH: Play only note received
