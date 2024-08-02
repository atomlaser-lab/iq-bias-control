CC=gcc

iqmake: saveData.o savePhaseData.o fetchRAM.o analyze_biases.o analyze_jump_response.o iq_bias_control.h
	$(CC) -o saveData saveData.o
	$(CC) -o savePhaseData savePhaseData.o
	$(CC) -o fetchRAM fetchRAM.o
	$(CC) -o analyze_biases analyze_biases.o -lm
	$(CC) -o analyze_jump_response analyze_jump_response.o