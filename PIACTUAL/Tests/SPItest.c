#include <wiringPiSPI.h>
#include <wiringPi.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char*argv[]){
	unsigned char * a;//pointer to a
	a = malloc(2*sizeof(unsigned char));//allocating memory on stack to a 
	wiringPiSetupGpio();
	pinMode(12,OUTPUT);//output pin
	wiringPiSPISetup(0,500000);//speed
	

	while(1) {
		int inputone;
		int inputtwo;
		printf("Enter input 1 and 2\n");
		scanf("%x",&inputone);
		scanf("%x", &inputtwo);
		//was used to test user input for fpga testing
		a[0] = (unsigned char)inputone; a[1] = (unsigned char)inputtwo;
		digitalWrite(12,0);//write to output pin 
		wiringPiSPIDataRW(0,a,2);
		usleep(100000);//slow down  
	}
	free(a);
	return 0;}
