all: sim

wave: sim
	gtkwave Div.vcd
	gtkwave Mul.vcd

sim: compile
	./obj_dir/Div
	./obj_dir/Mul

compile:
	verilator --cc ../Div.sv --exe --build Div_tb.cpp -o Div --trace -Wall
	verilator --cc ../Mul.sv --exe --build Mul_tb.cpp -o Mul --trace -Wall