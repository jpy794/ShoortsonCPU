all: sim

wave: sim
	gtkwave DivU.vcd

sim: compile
	./obj_dir/DivU

compile:
	verilator --cc ../DivU.sv --exe --build DivU_tb.cpp -o DivU --trace -Wall