// Lisa Yin and Marc Finzi
// E155 Microprocessors Final Project, 12/7/15

// Main FPGA module for laser harp
module final_project(input logic clk, reset, sclk, load,
							output logic sdo,
							input logic adcMiso, 
							output logic adcMosi, CS, spiClk,
                    output logic [3:0] stepperWires,
						  output logic laserControl,
						  output logic [3:0] leds);
		logic [2:0] currentNote;
		logic [7:0] [7:0] strings;
		logic trigger;

		spi_raspi_slave2 srs(load, sclk, sdo, strings); // SPI->PI connection
		oscillateMirror2 om(clk, reset, stepperWires, currentNote, trigger, laserControl); // Controls Motor, Laser
		updateStrings un(clk, reset, adcMiso, adcMosi, CS, spiClk, trigger, currentNote, strings); // Fills out strings
		assign leds[3:0] = {currentNote,trigger}; // Debug Leds for adc trigger timing
endmodule



// SPI interface to send out data to PI
// When master drives sck and load is asserted,
// adc readings for each string are shifted out one by one in order,
// starting with string 0 bit 7 and ending with string 7 bit 0
module spi_raspi_slave2(input logic load, sck,
			  output logic sdo, // note to send back
			  input logic [7:0] [7:0] strings); // calculated by other modules
		logic [2:0] stringState;
		logic [2:0] whichBit;
		always_ff @(posedge sck) begin
			if (!load)
				{stringState,whichBit} <= 6'b0;
			else
				{stringState,whichBit} <= {stringState,whichBit} + 1'b1;
		end  // We want MSB first, not LSB so we start at bit 7
		assign sdo = strings[stringState][7-whichBit];
endmodule

// Module moves the motor through 8 positions forward and back repeatedly, stops at each
// one to turn on the Laser and trigger the ADC, each position is seperated by 2 steps
module oscillateMirror2(input logic clk, reset,
						  output logic [3:0] stepperWires,
						  output logic [2:0] currentNote,
						  output logic ADCload,
						  output logic laserControl);

	logic [18:0] counter;
	logic [3:0] turns; // 4 stepper motor
	logic [2:0] stepCount; // 8 notes
	logic forward;
	logic moving;
	logic [18:0] nextCounter;
	
	always_ff @(posedge clk) begin
		nextCounter = counter +1'b1;
		if (reset) begin // Reset all registers to default
			turns <= 4'b0001;
			stepCount = 3'b0;
			forward = 1'b1; // Note blocking equals
			moving<=1'b0;
			nextCounter = 19'b0;
		end
		
		// Take steps at two different points along the time interval
		if (moving&&((counter[17:0] == 18'h18000)||(counter[17:0] == 18'h02000))) begin
			turns <= forward ? {turns[2:0], turns[3]} : {turns[0], turns[3:1]};
		end
		// Once we hit end travel time, switch to hold mode
		if (moving&&(counter[17:0] == 18'h2F000)) begin
			nextCounter = 0; // We need blocking
			moving <= 1'b0;
			stepCount = forward? stepCount + 1'b1:stepCount - 1'b1;
			if ((stepCount == 7)||(stepCount==0)) begin 
			forward = ~forward; // Reverse if on one of the endpoints of travel
			end
		end
		// Once we have held position for long enough, switch back to moving
		if ((~moving)&&(counter==19'h3E000)) begin
			moving <= 1'b1;
			nextCounter = 0; // Blocking
		end
		counter <= nextCounter; // Take either counter+1 or 0, depending on above conditions
	end
	
	assign stepperWires = turns; // Output to H-Bridge
	assign currentNote = stepCount[2:0]; // Which of 8 positions we are at
	assign laserControl = ~moving && (counter > 19'h00FFF && counter < 19'h4F000); // When stopped
	assign ADCload = ~moving && (counter>200000)&&(counter<200010); // Sometime while we are stopped
endmodule



// Everytime dataready goes high, strings gets updated.
module updateStrings(input logic clk, reset, miso,
							output logic mosi, CS, spiClk,
							input logic trigger,
							input logic [2:0] stringToCheck,
							output logic [7:0] [7:0] strings);
	logic [18:0] counter; // care must be taken with interactions with oscillateMirror.
	logic [9:0] adcReading;
	logic dataReady; // Flag from adc signalling that data in adcReading is good
	ADCreader ar(clk,reset,trigger,miso,mosi,CS,spiClk,adcReading,dataReady);
	logic [2:0] holdStringToCheck;
	
	always_ff @(posedge clk) begin
		if (trigger) holdStringToCheck <= stringToCheck;
		// Gets the most significant 8 bits of the 10
		if (dataReady&~trigger) strings[holdStringToCheck] <= adcReading[9:2]; 
	end
endmodule


// Module implements a synchronous pulse that is high once per 315kHz cycle
// Also contains the spiClk used to communicate with the ADC
module spiPulseGen(input clk,
						output spiTrigger, spiClk);
	logic [6:0] cnt;
	always_ff @(posedge clk)
	begin
		cnt<=cnt+1'b1;
	end
	assign spiTrigger = (cnt==7'b1000000);
	assign spiClk = cnt[6];
endmodule

// Module used for testing of updateStrings module to generate the trigger
module testAdcTrigger(input logic clk,
						output logic reducedClk);
	logic [13:0] cnt;
	always_ff @(posedge clk)
	begin
		cnt<=cnt+1'b1;
	end
	assign reducedClk = (cnt[13:2]==12'b100000000000);
endmodule

/// SPI ADC read module, assert start to begin communication
// Then bring start low, wait for dataReady flag to go high (~2300clk cycles)
// Then, valid data will be in dataReady and communication can begin again
module ADCreader(input logic clk, reset, start,
						input logic miso,
						output logic mosi, CS, spiClk,
						output logic [9:0] adcReading,
						output logic dataReady);

	logic spiClkTrigger, moduleOn,spiClkGen;
	spiPulseGen spg(clk,spiClkTrigger,spiClkGen);
	assign spiClk = spiClkGen;//&moduleOn;
	
	logic [3:0] spiBitCounter; // Counts up to 15 then back to zero
	logic [15:0] shiftOut,shiftIn;
	// The module be turned on when start is asserted, and off when data is ready
	always_ff @(posedge clk) 
	begin
		if (reset) begin 
			spiBitCounter <= 4'b1111;
			moduleOn <= 1'b0;
			shiftOut <= 16'hFF;
		end
		else begin
			if(start) moduleOn<=1'b1;
			else moduleOn <= (dataReady&spiClkGen? 1'b0:moduleOn);
			spiBitCounter <= (spiClkTrigger && moduleOn)?(spiBitCounter+1'b1):spiBitCounter;
			// While the module is on, and we hit the trigger, shift out the trigger
			if (spiClkTrigger && moduleOn) begin
				shiftOut[15:0] <= {shiftOut[0],shiftOut[15:1]};
				shiftIn[15:0] <= {shiftIn[14:0],miso};
			end
		end
	end
	assign dataReady = (spiBitCounter == 4'b1111);	// Endstate
	assign CS = ~moduleOn;
	assign mosi = 1'b1; // We don't need to switch channels anyway
	assign adcReading = shiftIn[10:1];
endmodule


