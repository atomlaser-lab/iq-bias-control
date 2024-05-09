//These are libraries which contain useful functions
#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <math.h>
#include <time.h>

#define MAP_SIZE  262144UL
#define MEM_LOC   0x40000000
#define DATA_LOC 0x00000088
#define FIFO_LOC  0x00000084
#define PWM_LOC   0x00000050

int start_fifo(void *cfg) {
  //Disable FIFO
  *((uint32_t *)(cfg + FIFO_LOC)) = 0;
  //Reset FIFO
  *((uint32_t *)(cfg + 0)) = (1 << 2);
  usleep(1);
  //Enable FIFO
  *((uint32_t *)(cfg + FIFO_LOC)) = 1;
  return 0;
}

int stop_fifo(void *cfg) {
  *((uint32_t *)(cfg + FIFO_LOC)) = 0;
  return 0;
}

int write_to_pwm(void *cfg,uint16_t V1,uint16_t V2,uint16_t V3) {
  *((uint32_t *)(cfg + PWM_LOC)) = (uint32_t) V1;
  *((uint32_t *)(cfg + PWM_LOC + 4)) = (uint32_t) V2;
  *((uint32_t *)(cfg + PWM_LOC + 8)) = (uint32_t) V3;
  return 0;
}
 
int main(int argc, char **argv)
{
  int fd;		        //File identifier
  int num_samples;      //Number of samples to acquire
  void *cfg;		    //A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource
  uint16_t Vx = 320;
  uint16_t Vy = 320;
  uint16_t Vz = 320;
  uint16_t Vjump = 64;
  uint8_t jump_index = 0;

  uint32_t i, incr = 0;
  uint8_t saveType = 2;
  uint32_t saveFactor = 4;
  uint8_t allow_jump = 1;
  uint32_t tmp;
  uint32_t *data;
  uint8_t debugFlag = 0;
  FILE *ptr;

  clock_t start, stop;

  /*
   * Parse the input arguments
   */
  int c;
  while ((c = getopt(argc,argv,"s:j:n:x:y:z:i:f")) != -1) {
    switch (c) {
        case 's':
            saveFactor = atoi(optarg);
            break;
        case 'j':
            Vjump = atoi(optarg);
            break;
        case 'i':
            jump_index = atoi(optarg);
            break;
        case 'n':
            num_samples = atoi(optarg);
            break;
        case 'x':
            Vx = atoi(optarg);
            break;
        case 'y':
            Vy = atoi(optarg);
            break;
        case 'z':
            Vz = atoi(optarg);
            break;
        case 'f':
            debugFlag = 1;
            break;

        case '?':
            if (isprint (optopt))
                fprintf (stderr, "Unknown option `-%c'.\n", optopt);
            else
                fprintf (stderr,
                        "Unknown option character `\\x%x'.\n",
                        optopt);
            return 1;

        default:
            abort();
        break;
    }
  }


  uint32_t data_size = saveFactor*num_samples;
  data = (uint32_t *) malloc(data_size * sizeof(uint32_t));
  if (!data) {
    printf("Error allocating memory for data");
    return -1;
  }

  //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }

  /*mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.*/
  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);
 
  // Set voltages
  write_to_pwm(cfg,Vx,Vy,Vz);
  sleep(1);
  // Record data
  start_fifo(cfg);
  for (i = 0;i < data_size;i += saveFactor) {
    if ((i >= (data_size >> 2)) & (allow_jump == 1)) {
        allow_jump = 0;
        switch (jump_index) {
            case 1:
                write_to_pwm(cfg,Vx + Vjump,Vy,Vz);
                break;
            case 2:
                write_to_pwm(cfg,Vx,Vy + Vjump,Vz);
                break;
            case 3:
                write_to_pwm(cfg,Vx,Vy,Vz + Vjump);
                break;
            default:
                break;
        }
        
    }
    for (incr = 0;incr < saveFactor;incr++) {
        *(data + i + incr) = *((uint32_t *)(cfg + DATA_LOC + (incr << 2)));
    }
  }
  stop_fifo(cfg);
  write_to_pwm(cfg,Vx,Vy,Vz);

  ptr = fopen("SavedData.bin","wb");
  fwrite(data,4,(size_t)(data_size),ptr);
  fclose(ptr);
  free(data);

  //Unmap cfg from pointing to the previous location in memory
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
