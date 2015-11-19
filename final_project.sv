// I'm too lazy to write everything in quartus rn, so just brainstorming
// what to write for each module.

module final_project(input logic clk, reset,
                    output logic [3:0] stepperWires,
						  output logic laserControl);
		oscillateMirror om(clk, reset, stepperWires, laserControl);
endmodule

// The motor moves around 0.9 degrees per
// clock cycle.
module oscillateMirror(input logic clk, reset,
		       output logic [3:0] stepperWires,
		       output logic laserControl);
  logic [17:0] counter; //15 is max
  logic [3:0] turns;
  logic [31:0] cycleCount;
  logic forward;
  always_ff @(posedge clk)
  begin
    if (reset)
    begin
      turns <= 4'b0001;
      counter <= 32'b0;
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
		cycleCount <= cycleCount + 1'b1;
    end
    counter <= counter + 1'b1;
  end

  // Turn off the laser when the motor is turning.
//  assign laserControl = (counter[15] == 1);
  assign laserControl = (counter[9]);
  assign stepperWires = turns;
  
endmodule



// TODO: Implement SPI between PI and FPGA

// Mopule implements a synchronous trigger that is high once per 315kHz cycle
module spiPulseGen(input clk,
						output spiTrigger, spiClk);
	logic [6:0] cnt;
	always_ff @(posedge clk)
	begin
		cnt<=cnt+1;
	end
	assign spiTrigger = (cnt==7'b1000000);
	assign spiClk = cnt[6];
endmodule


/// SPI ADC read module, assert start to begin communication
// Then bring start low, wait for dataReady flag to go high (~2300clk cycles)
// Then, valid data will be in dataReady and communication can begin again
module ADCreader(input clk, reset, start,
						input miso,
						output mosi, CSLow, spiClk,
						output [11:0] adcReading,
						output dataReady);

	logic spiClkTrigger, moduleOn;
	spiPulseGen spg(clk,spiClkTrigger,spiClk);
	
	// The module be turned on when start is asserted, and off when data is ready
	always_ff @(posedge clk) 
		moduleOn <= (dataReady? start:moduleOn)&(~reset);
		
	
	logic [3:0] spiBitCounter; // Counts up to 15 then back to zero
	logic [15:0] shiftOut,shiftIn;
	
	always_ff @(posedge clk) if (spiClkTrigger && moduleOn)
	begin
		spiBitCounter <= reset?0:spiBitCounter+1; 
		shiftOut <= reset? 16'h7000:{shiftOut[0],shiftOut[15:1]}; //7000 for channel 0
		shiftIn <= {shiftIn[15:1],miso};
	end
	assign dataReady = (spiBitCounter == 4'b1111);	
	assign CSLow = moduleOn;
	assign mosi = shiftOut[0];
	assign adcReading = shiftIn[10:1];
		
endmodule
	
		
		
	
// TODO: Laser multiplexing + motor movement

// TODO: Determine which "string" was hit

// STRETCH: Receive note and duration played
// STRETCH: Switch between play mode vs playback mode
// STRETCH: Play only note received
