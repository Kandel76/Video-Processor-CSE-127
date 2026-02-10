/// Verilog test fixture created to test sync signals
//  Instructions:
// 1. Add to your project as a simulation source.
// 2. Adjust instantiation of the UUT (line 48) which is your top module.
// 3. Comment out lines 117 and 145 if your outputs are not run through FFs.
// 4. Run Simulator.
// 5. Add SERRORS and RGBERRORS to the waveform viewer (these signals are under GUT and RUT).
// 6. Reset simulation time to 0.
// 7. Set step size to 17ms, and step through frames. OR set the NUM_FRAMES parameter and run all.
// 8. Simulate one step (may take several minutes, or more if you have more components).
// 9. If SERRORs or RGBERRORS is not 0 find where they changed: there's a problem there or earlier.
//    Check for transitions on "oops" and rgb_oops" to find out where.
//10. Otherwise simulate one more step and check them again. 
//
//   Dustin Feb 2025 (version with frame image generation)
//   - A .bmp image is now generated for each frame.
`timescale 1ns / 1ps

module testSyncs();

   // Run the simulation for NUM_FRAMES
   //    Note: you can also just step through frames
   parameter NUM_FRAMES = 1;

   // Inputs
   reg btnC,btnD,btnU,btnL,btnR;
   reg [15:0] sw;
   reg clkin;
   reg greset;

   // Outputs
   wire [3:0] an;
   wire dp;
   wire [6:0] seg;
   wire [15:0] led;
   wire HS;
   wire [3:0] vgaBlue;
   wire [3:0] vgaGreen;
   wire [3:0] vgaRed;
   wire VS;
   wire oops;
   wire rgb_oops;


   // Instantiate your UUT
   bridge UUT (
      .btnU(btnU),  
      .btnD(btnD),      // btnD is used for design extra credit
      .btnC(greset),    // btnC is greset
      .btnR(btnR),  
      .btnL(btnL),  
      .clkin(clkin), 
      .seg(seg), 
      .dp(dp), 
      .an(an),
      .vgaBlue(vgaBlue),
      .vgaRed(vgaRed),
      .vgaGreen(vgaGreen),        
      .Vsync(VS), 
      .Hsync(HS), 
      .sw(sw), 
      .led(led)
   );
 
   // Generate Basys3 clock
   parameter PERIOD = 40;
   parameter real DUTY_CYCLE = 0.5;
   parameter OFFSET = 2;
   initial
   begin
      clkin = 1'b0;
      #OFFSET
      clkin = 1'b1;
      forever
      begin
         #(PERIOD-(PERIOD*DUTY_CYCLE)) clkin = ~clkin;
      end
   end

   // Design inputs may be set here   
   initial 
   begin 
      sw = 16'h23_00;
      btnU = 1'b0;
      btnC = 1'b0;
      btnD = 1'b0;
      btnL = 1'b0;
      btnR = 1'b0;
      greset = 1'b0;
      #600 greset = 1'b1;
      #80 greset = 1'b0;
      // Optional: set new inputs if needed
      // Caution: debugging on the VGA monitor will be better for
      //    object movements over several frames.
   end
   
   // Registers used for checks
   reg good_HS;
   reg good_VS;
   reg activeH;
   reg activeV;
   reg frames_active;
   
   // Process to generate correct values for HS and activeH
   initial
   begin
      #OFFSET;
      #1;
      activeH = 1'b1;
      good_HS = 1'b1;
      #880;
      #700; // to get past gsr pulse and clock delay
      
      // comment out the line below if your HSync is not passed through a
      //    DFF before leaving the FPGA
      #40;

      forever 
      begin
         activeH = 1'b1;
         #(640*40);
         activeH = 1'b0;
         #(15*40);
         good_HS = 1'b0;
         #((96)*40);
         good_HS = 1'b1;
         #(49*40);
      end
   end

   //correct values for VS and activeV
   initial
   begin
      frames_active = 0;
      #OFFSET;
      #1;
      activeV = 1'b1;
      good_VS = 1'b1;
      #880;
      #700; // to get past gsr and DCM clock delay

      // comment out the line below if your HSync is not passed through a
      //    DFF before leaving the FPGA
      #40;
      
      forever 
      begin
         frames_active = 1;
         activeV = 1'b1;
         #(480*800*40);
         activeV=1'b0;               
         #(9*800*40); 
         good_VS = 1'b0;
         #(2*800*40);
         good_VS = 1'b1;
         #(34*800*40);
      end
   end

////////////////////////////////////////////////////////////////////////
///////////////////////  DO NOT EDIT BELOW HERE  ///////////////////////
////////////////////////////////////////////////////////////////////////
   // VGA monitor resolution
   parameter WIDTH = 640;
   parameter HEIGHT = 480;

   // Image pixel data (each pixel is expanded to 24-bit RGB)
   reg [23:0] image_data [0:WIDTH*HEIGHT-1];
   reg [7:0] bmp_header[0:53];
   integer i, j, index, file, frame_cnt;
   reg [8*25:0] file_str;

   initial begin
      frame_cnt = 0;
      #4;

      // Construct BMP Header
      bmp_header[0]  = 8'h42; bmp_header[1]  = 8'h4D; // 'BM'
      bmp_header[2]  = 8'h36; bmp_header[3]  = 8'h6C; bmp_header[4]  = 8'h09; bmp_header[5]  = 8'h00; // File size (640*480*3 + 54 = 921654)
      bmp_header[6]  = 8'h00; bmp_header[7]  = 8'h00;
      bmp_header[8]  = 8'h00; bmp_header[9]  = 8'h00;
      bmp_header[10] = 8'h36; bmp_header[11] = 8'h00; bmp_header[12] = 8'h00; bmp_header[13] = 8'h00; // Pixel data offset (54)
      bmp_header[14] = 8'h28; bmp_header[15] = 8'h00; bmp_header[16] = 8'h00; bmp_header[17] = 8'h00; // Header size (40)
      bmp_header[18] = 8'h80; bmp_header[19] = 8'h02; bmp_header[20] = 8'h00; bmp_header[21] = 8'h00; // Width (640)
      bmp_header[22] = 8'hE0; bmp_header[23] = 8'h01; bmp_header[24] = 8'h00; bmp_header[25] = 8'h00; // Height (480)
      bmp_header[26] = 8'h01; bmp_header[27] = 8'h00; // Planes (1)
      bmp_header[28] = 8'h18; bmp_header[29] = 8'h00; // Bits per pixel (24)
      bmp_header[30] = 8'h00; bmp_header[31] = 8'h00; bmp_header[32] = 8'h00; bmp_header[33] = 8'h00; // Compression (0)
      bmp_header[34] = 8'h00; bmp_header[35] = 8'h6C; bmp_header[36] = 8'h09; bmp_header[37] = 8'h00; // Image size (640*480*3)
      bmp_header[38] = 8'h13; bmp_header[39] = 8'h0B; bmp_header[40] = 8'h00; bmp_header[41] = 8'h00; // X Pixels Per Meter (2835)
      bmp_header[42] = 8'h13; bmp_header[43] = 8'h0B; bmp_header[44] = 8'h00; bmp_header[45] = 8'h00; // Y Pixels Per Meter (2835)
      bmp_header[46] = 8'h00; bmp_header[47] = 8'h00; bmp_header[48] = 8'h00; bmp_header[49] = 8'h00; // Colors Used (0)
      bmp_header[50] = 8'h00; bmp_header[51] = 8'h00; bmp_header[52] = 8'h00; bmp_header[53] = 8'h00; // Important Colors (0)

      forever 
      begin
         while(!frames_active) #40;
         for (i = 0; i < WIDTH*HEIGHT; i = i + 1) 
         begin
            while(!(activeV && activeH)) #40;
            image_data[i] = {{vgaBlue},{vgaGreen},{vgaRed}};
            #40;
         end
         $swrite(file_str, "./frame_%0d.bmp", frame_cnt);
         file = $fopen(file_str, "wb");
         if (file == 0) 
         begin
            $display("Error opening file!");
            $finish;
         end

         // Write BMP Header
         for (i = 0; i < 54; i = i + 1)
            $fwrite(file, "%c", bmp_header[i]);

         // Write pixel data (BMP stores pixels bottom-up)
         for (j = 479; j >= 0; j = j - 1)
         begin
            for (i = 0; i < 640; i = i + 1) 
            begin
                index = j * 640 + i;
                $fwrite(file, "%c%c%c", 
                    {image_data[index][11:8], image_data[index][11:8]},
                    {image_data[index][7:4], image_data[index][7:4]},
                    {image_data[index][3:0], image_data[index][3:0]}
                );
            end
         end

         // Close file
         $fclose(file);
         frame_cnt = frame_cnt + 1;
      end
   end

   // Process to run for some number of frames
   initial begin
      forever @(frame_cnt)
         if(frame_cnt >= NUM_FRAMES) begin
            #40;
            $stop();
         end
   end

   // Instantiate the module comparing good and actual sync signals
   check_the_sync_signals GUT (
      .myHS(HS), 
      .myVS(VS), 
      .correct_HS(good_HS), 
      .correct_VS(good_VS),
      .clk(clkin),
      .greset(greset),
      .sync_error(oops)
   );
       
   // Instantiate the module checking RGB signals are 
   // low outside the active region
   check_the_rgb_signals RUT (
      .VB(vgaBlue), 
      .VG(vgaGreen),
      .VR(vgaRed),
      .activeH(activeH), 
      .activeV(activeV),
      .clk(clkin),
      .greset(greset),
      .rgb_error(rgb_oops)
   );       

endmodule

module check_the_sync_signals(
   input myHS,
   input myVS,
   input correct_HS,
   input correct_VS,
   input clk,
   input greset,
   output sync_error);
 
   // sync_error is high when actual and expected sync signals differ
   assign sync_error = (myHS^correct_HS)|(myVS^correct_VS);

   // SERRORS is incremented when sync_error is high at the rising edge of betterclk 
   integer SERRORS; 

   always @(posedge clk)
   begin
      SERRORS  <= SERRORS + sync_error;   // non-blocking assignment
   end

   // reset SERRORS on rising edge of gsr
   always @(posedge greset)
   begin
      SERRORS <= 32'b0;   //  non-blocking assignment 
   end

endmodule

module check_the_rgb_signals(
   VB, 
   VG, 
   VR, 
   activeH, 
   activeV, 
   clk, 
   greset, 
   rgb_error);

   input [3:0] VB, VG, VR;
   input activeH, activeV;
   input clk, greset;
   output rgb_error;
 
   // rgb_error is high when any RGB output is high outside the active region
   assign rgb_error = ((|VR)|(|VB)|(|VG))&~(activeH*activeV);

   // RGBERRORS is incremented when rgb_error is high at the rising edge of betterclk 
   integer RGBERRORS; 

   always @(posedge clk)
   begin
      RGBERRORS  <= RGBERRORS + rgb_error;   // non-blocking assignment
   end

   // reset SERRORS on rising edge of gsr
   always @(posedge greset)
   begin
      RGBERRORS <= 32'b0;   //  non-blocking assignment 
   end
 
endmodule

////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
