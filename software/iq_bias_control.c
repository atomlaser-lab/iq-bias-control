#include <stdio.h>
#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include "iq_bias_control.h"

int start_fifo(void *cfg) {
  //Disable FIFO
  *((uint32_t *)(cfg + FIFO_CONTROL_LOC)) = 0;
  //Reset FIFO
  *((uint32_t *)(cfg + 0)) = (1 << 2);
  usleep(100);
  //Enable FIFO
  *((uint32_t *)(cfg + FIFO_CONTROL_LOC)) = 1;
  return 0;
}

int stop_fifo(void *cfg) {
  *((uint32_t *)(cfg + FIFO_CONTROL_LOC)) = 0;
  return 0;
}

int write_to_bias_pwm(void *cfg,uint16_t V1,uint16_t V2,uint16_t V3) {
  *((uint32_t *)(cfg + PWM_LOC)) = (uint32_t) V1;
  *((uint32_t *)(cfg + PWM_LOC + 4)) = (uint32_t) V2;
  *((uint32_t *)(cfg + PWM_LOC + 8)) = (uint32_t) V3;
  return 0;
}

int write_to_phase_pwm(void *cfg,uint16_t V) {
  *((uint32_t *)(cfg + PWM_LOC + 0xC)) = (uint32_t) V;
}
