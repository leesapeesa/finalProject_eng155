module final_project(input logic clk, reset, sclk, sdi,
							output logic sdo,
							input logic adcMiso, 
							output logic adcMosi, CS, spiClk,
                    output logic [3:0] stepperWires,
						  output logic laserControl);
		logic [7:0] action;
		logic [2:0] currentNote;
		logic [7:0] [7:0] strings;
		logic [7:0] [7:0] fakeStrings;
		always_ff @(posedge clk) begin if(reset) begin
			for (int i=0; i<8; i++) begin
				fakeStrings[i] <= i;
			end
			end
		end
		logic dataReady, trigger;
		//scaledClk skk(clk,trigger);
		spi_raspi_slave2 srs(reset, sclk, sdi, sdo, fakeStrings, action);
		oscillateMirror om(clk, reset, stepperWires, currentNote, trigger, laserControl);
		updateStrings un(clk, reset, adcMiso, adcMosi, CS, spiClk, trigger, currentNote, strings);
endmodule



// SPI interface for our final project.
// After reset has been hit at some point, when master drives sck,
// adc readings for each string are shifted out one by one in order,
// starting with string 0 bit 7 and ending with string 7 bit 0
// The last 8 bits of any communication are held in action
module spi_raspi_slave2(input logic reset, sck,
			  input logic sdi,
			  output logic sdo, // note to send back
			  input logic [7:0] [7:0] strings, // calculated by other modules
			  output logic [7:0] action); // action for the FPGA to do (last 8 bits sent)
		logic [2:0] stringState;
		logic [2:0] whichBit;
		always_ff @(posedge sck, posedge reset) begin
			if (reset) begin
				{stringState,whichBit} <= 6'b0;
				action <= 1'b0;
			end
			else begin 
				{stringState,whichBit} <= {stringState,whichBit} + 1'b1;
				action <= {action[6:0], sdi};
			end
		end  // We want MSB first, not LSB so we start at bit 7
		assign sdo = strings[stringState][7-whichBit]; 
endmodule

// Moves one step at 152 hz when counter size is 18.
module oscillateMirror(input logic clk, reset,
						  output logic [3:0] stepperWires,
						  output logic [2:0] currentNote,
						  output logic ADCload,
						  output logic laserControl);

	logic [17:0] counter; //15 is max
	logic [3:0] turns; // 4 stepper motor
	logic [2:0] notes; // Currently only 8 notes.
	logic [4:0] stepCount;
	logic forward;
	always_ff @(posedge clk) begin
		if (reset) begin
			turns <= 4'b0001;
			stepCount <= 5'b0;
			counter <= 18'b0;
			notes <= 3'b001;
			forward <= 1;
		end
		
		if (stepCount == 16) begin
			stepCount <= 5'b0;
			forward <= ~forward;
		end
		
		// We slow down the clock using counter.
		if (counter == 0) begin
			turns <= forward ? {turns[2:0], turns[3]} : {turns[0], turns[3:1]};
			stepCount <= stepCount + 1'b1;
		end
		
		// Every four step counts, we want to turn on the laser.
		// essentially checking for mod 4.     
		if (stepCount[1:0] == 0) begin
			//laserControl <= (counter > 2 && counter < 1000);
			// ADC can't be help for too long.
			//ADCload <= (counter > 2 && counter < 1000);
			notes <= forward ? notes + 1'b1 : notes - 1'b1;
		end
		counter <= counter + 1'b1;
	end
	
	assign stepperWires = turns;
	assign currentNote = notes;
	assign laserControl = ~((stepCount[1:0] == 2'b0) && (counter > 2 && counter < 200000));
	assign ADCload = (stepCount[1:0] == 2'b0) && (counter > 2 && counter < 200000);
endmodule

// Sends a done signal at 76 Hz ~~ What is done for?
// Everytime readADC is high, strings gets updated.
module updateStrings(input logic clk, reset, miso,
							output logic mosi, CS, spiClk,
							input logic trigger,
							input logic [2:0] stringToCheck,
							output logic [7:0] [7:0] strings);
	logic [18:0] counter; // has to be bigger than the clk divider for oscillateMirror.
	logic [9:0] adcReading;
	logic dataReady;
	ADCreader ar(clk,reset,trigger,miso,mosi,CS,spiClk,adcReading,dataReady);
	logic [2:0] holdStringToCheck;
	
	always_ff @(posedge clk) begin
		holdStringToCheck <= trigger? stringToCheck:holdStringToCheck;
		// Gets the most significant 8 bits
		if (dataReady&~trigger) strings[holdStringToCheck] <= adcReading[9:2]; 
	end
endmodule

// TODO: Implement SPI between PI and FPGA

// TODO: Implement SPI between ADC and FPGA

// Module implements a synchronous trigger that is high once per 315kHz cycle
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

module scaledClk(input logic clk,
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
	assign spiClk = spiClkGen&moduleOn;
	
	logic [3:0] spiBitCounter; // Counts up to 15 then back to zero
	logic [15:0] shiftOut,shiftIn;
	// The module be turned on when start is asserted, and off when data is ready
	always_ff @(posedge clk) 
	begin
		if (reset) 
		begin 
			spiBitCounter <= 4'b1111;
			moduleOn <= 1'b0;
			shiftOut <= 16'h000F;
		end
		else
		begin
			if(start) moduleOn<=1'b1;
			else moduleOn <= (dataReady&spiClkGen? 1'b0:moduleOn);
			spiBitCounter <= (spiClkTrigger && moduleOn)?(spiBitCounter+1'b1):spiBitCounter;
			if (spiClkTrigger && moduleOn)
			begin
				shiftOut[15:0] <= {shiftOut[0],shiftOut[15:1]}; //7000 for channel 0
				shiftIn[15:0] <= {shiftIn[14:0],miso};
			end
		end
	end
	assign dataReady = (spiBitCounter == 4'b1111);	
	assign CS = ~moduleOn;
	assign mosi = shiftOut[0];
	assign adcReading = shiftIn[10:1];
		
endmodule


// TODO: Determine which "string" was hit

// STRETCH: Receive note and duration played
// STRETCH: Switch between play mode vs playback mode
// STRETCH: Play only note received
