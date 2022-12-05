/*start Phone.py before running this and it will
 *pipe the data from python to C and send to fpga via SPI interface
  */
#include <unistd.h> 
#include <stdio.h> 
#include <sys/stat.h> 
#include <fcntl.h>
#include <wiringPiSPI.h>
#include <wiringPi.h>
#include <stdlib.h>
#include <unistd.h>
struct data_in {
	int data;
}

main(int argc, char* argv[]) {
	mkfifo("pipe_test", 0666); //creates a pipe that lives on the file system NOT A FILE but listed in directory
	int fd = -1; //file descriptor
	unsigned char * a;
	a = malloc(4*sizeof(unsigned char));//memory allocation
	wiringPiSetupGpio(); //setup GPIO pins with library wiringpi
	pinMode(12,OUTPUT);//output pin
	wiringPiSPISetup(0,500000);//speed

	fd = open("fifo", O_RDONLY); //opens fifo to read only 
	while(1) {//prints data in buffer (accelerometer data) to terminal
		struct data_in buffer;
		read(fd, (void*)(&buffer), sizeof(struct data_in));
		if ((void*)(&buffer) != 0){
			printf("data: %d\n", buffer.data);
			sleep(0.1);
		}
		int inputone = buffer.data;
		a[0] = (unsigned char)inputone; //a[1] = (unsigned char)inputone;
		digitalWrite(12,0);
		wiringPiSPIDataRW(0,a,4);
		usleep(100000);
	}
	free(a);//free up memory pointed by pointer 
    close(fd);
}

