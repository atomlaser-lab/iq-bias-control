CC=gcc

iqmake: saveData.o savePhaseData.o fetchRAM.o analyze_biases.o analyze_jump_response.o iq_bias_control.o analyze_phase_jump.o analyze_phase_lock.o iq_bias_control.h
	$(CC) -o saveData saveData.o iq_bias_control.o
	$(CC) -o savePhaseData savePhaseData.o iq_bias_control.o
	$(CC) -o fetchRAM fetchRAM.o iq_bias_control.o
	$(CC) -o analyze_biases analyze_biases.o iq_bias_control.o -lm
	$(CC) -o analyze_jump_response analyze_jump_response.o iq_bias_control.o
	$(CC) -o analyze_phase_jump analyze_phase_jump.o iq_bias_control.o
	$(CC) -o analyze_phase_lock analyze_phase_lock.o iq_bias_control.o
