module file_reader (
    input clk,
    input reset,
    input [18:0] addr_i,
    output [7:0] pixel_o
);
    assign pixel_o = addr_i[17:10];

    reg[7:0] str;
    integer fd;
    integer chars;

    initial begin
        fd = $fopen("frame_0.bmp", "rb");

        // Keep reading lines until EOF is found
        while (! $feof(fd)) begin

  	    // Get current line into the variable 'str'
            chars = $fgets(str, fd);

            // Display contents of the variable
            $display("%0s", str);
        end
        $fclose(fd);
    end

endmodule
