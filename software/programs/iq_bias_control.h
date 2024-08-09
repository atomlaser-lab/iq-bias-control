#ifndef CNSTS_H_
#define CNSTS_H_

#define MAP_SIZE                    3145728UL
#define MEM_LOC                     0x40000000
#define FIFO_CONTROL_LOC            0x00100000
#define FIFO_BIAS_DATA_START_LOC    0x00100004
#define FIFO_PHASE_DATA_START_LOC   0x00100014
#define RAM_DATA_LOC                0x41000000

#define PWM_LOC                     0x00000100
#define DAC_LOC                     0x00000020

int start_fifo(void *cfg);
int stop_fifo(void *cfg);
int write_to_bias_pwm(void *cfg,uint16_t V1,uint16_t V2,uint16_t V3);
int write_to_phase_pwm(void *cfg,uint16_t V);
int write_to_aux_dac(void *cfg,uint16_t V);
#endif
