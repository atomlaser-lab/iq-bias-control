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
#define DATA_LOC1 0x00000088
#define DATA_LOC2 0x0000008C
#define DATA_LOC3 0x00000090
#define DATA_LOC4 0x00000094
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
  int numVoltages;	    //Number of voltages to scan over
  int numAvgs;          //Number of averages to use
  void *cfg;		    //A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource
  uint16_t Vmax = 160;

  uint32_t i, incr = 0;
  uint8_t saveType = 2;
  uint32_t saveFactor = 4;
  uint32_t tmp;
  uint32_t *raw_data;
  int *data;
  uint8_t debugFlag = 0;
  FILE *ptr;

  clock_t start, stop;

  /*
   * Parse the input arguments
   */
  int c;
  while ((c = getopt(argc,argv,"n:a:m:f")) != -1) {
    switch (c) {
      case 'n':
        numVoltages = atoi(optarg);
        break;
      case 'a':
        numAvgs = atoi(optarg);
        break;
      case 'm':
        Vmax = atoi(optarg);
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


  uint32_t raw_data_size = saveFactor*numAvgs;
  raw_data = (uint32_t *) malloc(raw_data_size * sizeof(uint32_t));
  if (!raw_data) {
    printf("Error allocating memory for raw data");
    return -1;
  }

  uint32_t data_size = (uint32_t) saveFactor*pow((double) numVoltages,3);
  data = (int *) malloc(data_size * sizeof(int));
  if (!raw_data) {
    printf("Error allocating memory for saved data");
    return -1;
  }

  //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }

  /*mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.*/
  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);

  /*
   * Start looping through voltage values
   */
  int linear_index = 0;
  int offset_index = (int) pow((double) numVoltages,3);
  uint16_t Vx, Vy, Vz;
  for (int xx = 0;xx < numVoltages; xx++) {
    Vx = xx*(Vmax/numVoltages);
    for (int yy = 0;yy < numVoltages; yy++) {
      Vy = yy*(Vmax/numVoltages);
      for (int zz = 0;zz < numVoltages; zz++) {
        Vz = zz*(Vmax/numVoltages);
        // Set PWM values
        write_to_pwm(cfg,Vx,Vy,Vz);
/*        if ((xx == 0) || (yy == 0) || (zz == 0)) {
          sleep(1);
        } else {
          usleep(100);
        }
*/
        usleep(10000);
        // Record raw data
        start_fifo(cfg);
        for (i = 0;i < raw_data_size;i += saveFactor) {
          incr = 0;
          *(raw_data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC1));
          *(raw_data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC2));
          *(raw_data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC3));
          *(raw_data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC4));
        }
        stop_fifo(cfg);
        // Average raw data
        linear_index = xx + yy*numVoltages + zz*numVoltages*numVoltages;
        *(data + linear_index) = 0;
        *(data + linear_index + offset_index) = 0;
        *(data + linear_index + 2*offset_index) = 0;
        *(data + linear_index + 3*offset_index) = 0;
        for (i = 0;i < raw_data_size;i += saveFactor) {
          *(data + linear_index) += (int) *(raw_data + i);
          *(data + linear_index + offset_index) += (int) *(raw_data + i + 1);
          *(data + linear_index + 2*offset_index) += (int) *(raw_data + i + 2);
          *(data + linear_index + 3*offset_index) += (int) *(raw_data + i + 3);
        }
        *(data + linear_index) /= numAvgs;
        *(data + linear_index + offset_index) /= numAvgs;
        *(data + linear_index + 2*offset_index) /= numAvgs;
        *(data + linear_index + 3*offset_index) /= numAvgs;
      }
    }
  }

  ptr = fopen("SavedData.bin","wb");
  fwrite(data,4,(size_t)(data_size),ptr);
  fclose(ptr);
  free(data);
  free(raw_data);

  //Unmap cfg from pointing to the previous location in memory
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
