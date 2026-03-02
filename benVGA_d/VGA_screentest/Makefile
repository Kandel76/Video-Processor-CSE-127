
all :
	verilator -Wall --cc --exe simulator.cpp display.v -LDFLAGS -lglut -LDFLAGS -lGLU -LDFLAGS -lGL
	make -j -C obj_dir -f Vdisplay.mk Vdisplay
	obj_dir/Vdisplay

obj_dir : simulator.cpp display.v
	verilator -Wall --cc --exe simulator.cpp display.v -LDFLAGS -lglut -LDFLAGS -lGLU -LDFLAGS -lGL
	make -j -C obj_dir -f Vdisplay.mk Vdisplay

run : 
	obj_dir/Vdisplay

clean :
	rm -r obj_dir/
