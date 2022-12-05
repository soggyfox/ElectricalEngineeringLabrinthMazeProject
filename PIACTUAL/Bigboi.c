#include <unistd.h> 
#include <stdio.h> 
#include <sys/stat.h> 
#include <fcntl.h>
#include <wiringPiSPI.h>
#include <wiringPi.h>
#include <stdlib.h>
#include <math.h>
#include <stdlib.h>
#include <wiringPiI2C.h>
#include <unistd.h>
#include <stdio.h>
#include <math.h>
/*
 Find address through i2cdetect
 */
 //defining i2c constants
#define DEVICE_ID 0x1d

/* PMOD ADXL345 uses registers found in the following datasheet page 23:
https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL345.pdf
*/

#define POWER_CTL 0x2D
#define DATAX0 0x32
#define DATAX1 0x33
#define DATAY0 0x34
#define DATAY1 0x35
#define DATAZ0 0x36
#define DATAZ1 0x37
// Write a data value to power ctl to start communication. From testing it was found that this binary constant b1000 works for writing when using reg8.
int data = 0b1000;

//end i2c constants

struct data_in {
	float x;
	float y;
	float z;
};

//used to cap the acceleration at 9.8 or -9.8
float check(float in) {
	float out;
	if (in > 9.8) {
		out = 9.8;
	}
	else if (in < -9.8) {
		out = -9.8;
	}
	else {
		out = in;
	}
	return out;
}

// calculates the degree of tilt for Python
float calculate(float x) {
	float val, res;
	int out;
	val = 180.0 / 3.14159265;
	res =(asin(check(x)/9.8) * val);
	if (res > 30) {
		res = 30;
	} else if (res <-30) {
		res = -30;
	}
	return res;
};

// calculates the degree of tilt for I2C
float calculateI2C(float x) {
	float val, res, out;
	val = 180.0 / 3.14159265;
	if (x > 5000) {
		res = x - 65536;
	} else {
		res = x;
	}
	
	if( res > 256) {
		res = 256;
	} else if (res < -256) {
		res = -256;
	}
	out =(asin(res/256) * val) * -1;
	
	
	return out;
};

// compare the tilt degree between the phone and the Board
float diff(float p, float i) {
	float res;
	res = p - i;
	return res;
}

// convert into data that the fpga understands
float cal(float value) {
	float step,micro,degree,temp1,res;
	step = 1.8;
	micro = 128.0;
	degree = (value/1.8)*micro;
	if (degree == 0.0) {
		temp1 = 0.0;
	} else {
		temp1 = 0.1/degree;
	}
	res = temp1 * 40000;
	if (res > 0.0 && res < 2.0) {
		res = 2.0;
	} else if (res < 0.0 && res > -2.0) {
		res = -2.0;
	}
	return res;
}


void main(int argc, char* argv[]) {
	//general setup, gpio initializations and allocations
	
	mkfifo("fifo", 0666); 
	int fd = -1; 
	unsigned char * a;
	a = malloc(4*sizeof(int16_t));
	wiringPiSetupGpio();
	pinMode(12,OUTPUT);
	wiringPiSPISetup(0,500000);
	fd = open("fifo", O_RDONLY); 
	
	// Setup I2C communication
    int fdi2c = wiringPiI2CSetup(DEVICE_ID);
    // file descriptor error message
    if (fdi2c == -1) {
        printf("Failed to init I2C communication. \n Usage: Connect pins GND VCC SDA SCL from accelerometer to pi: GND, 1,3,5 ");
    }
    // Switch device to measurement mode
    
    wiringPiI2CWriteReg8(fdi2c, POWER_CTL, 0b00001000);
    
    
    
	
	while(1) {
		struct data_in buffer;
		read(fd, (void*)(&buffer), sizeof(struct data_in));
		
		//i2c --------communication-------//////
		float dataX = wiringPiI2CReadReg16(fdi2c, DATAX0);

        float dataY = wiringPiI2CReadReg16(fdi2c, DATAY0);


		float degreeXI= calculateI2C((float) dataX);
		
		//invert signal to invert control, might change at demo
		float degreeYI= -1*calculateI2C((float) dataY);
		
		
		//calculate difference between board and phone angle
		float diffX = diff(calculate(buffer.x), degreeXI);
		float diffY = diff(calculate(buffer.y), degreeYI);
		
		//calculate it into useful data for motor and driver
		float calX = cal(diffX);
		float calY = cal(diffY);
		printf("Calx: %f  Caly: %f\n", calX, calY);
		if ((void*)(&buffer) != 0){
			//send data to fpga through spi with pin 11, pin 12 for slave select for fpga
			a[0] = (int16_t) calX;
			a[1] = (int16_t) calY;
			digitalWrite(12,0);
			wiringPiSPIDataRW(0,a,2);
			digitalWrite(12,1);
			usleep(100000);
		}
        sleep(0.1);
		}
		close(fd);
		close(fdi2c);
		free(a);
}
