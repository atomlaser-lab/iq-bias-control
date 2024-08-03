CC=gcc
OBJ_S = saveData.o savePhaseData.o fetchRAM.o
OBJ_A = analyze_biases.o analyze_jump_response.o analyze_phase_jump.o analyze_phase_lock.o
OBJ_H = iq_bias_control.o iq_bias_control.h

all: savers analyzers clean

savers: $(OBJ_S) $(OBJ_H)
	$(CC) -o saveData saveData.o iq_bias_control.o
	$(CC) -o savePhaseData savePhaseData.o iq_bias_control.o
	$(CC) -o fetchRAM fetchRAM.o iq_bias_control.o
	
analyzers: $(OBJ_A) $(OBJ_H)
	$(CC) -o analyze_biases analyze_biases.o iq_bias_control.o -lm
	$(CC) -o analyze_jump_response analyze_jump_response.o iq_bias_control.o
	$(CC) -o analyze_phase_jump analyze_phase_jump.o iq_bias_control.o
	$(CC) -o analyze_phase_lock analyze_phase_lock.o iq_bias_control.o

.PHONY: clean

clean:
	rm ./*.o
