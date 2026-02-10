WAVEFORM    := wave
TESTFILE    := testbench.vcd
TESTBENCH   := simProvidedTest.v
VFILES      := ../mem2vga.v
DEPENDENCIES:= ../axi_manager.v ../sync_manager.v ../mem2vga.v ./bridge.v ../file_reader.v
CREATED     := $(WAVEFORM) $(TESTFILE) frame_0.bmp

# create waveform file (left) using given files and testbench (right)
$(WAVEFORM) : $(TESTBENCH) $(VFILES) $(DEPENDENCIES)
	iverilog -o $@ $^
	vvp $@

all: clean $(WAVEFORM) test simulate 

simulate :
	gtkwave $(TESTFILE)

test :
	echo "This is a makefile test"

clean :
	rm -f $(CREATED)
