#include <stdlib.h>
#include <wiringPiI2C.h>
#include <unistd.h>
#include <stdio.h>

/*
 Find address through i2cdetect
 */
 
#define DEVICE_ID 0x1d

/* PMOD ADXL345 uses registers found in the following datasheet page 23:
https://www.analog.com/media/en/technical-documentation/data-sheets/ADXL345.pdf
*/

#define POWER_CTL   0x2D
#define DATAX0 0x32
#define DATAX1 0x33
#define DATAY0 0x34
#define DATAY1 0x35
#define DATAZ0 0x36
#define DATAZ1 0x37
// Write a data value to power ctl to start communication. From testing it was found that this binary constant b1000 works for writing when using reg8.
int data = 0b1000;

int main (int argc, char **argv)
{
    // Setup I2C communication
    int fd = wiringPiI2CSetup(DEVICE_ID);
    // file descriptor error message
    if (fd == -1) {
        printf("Failed to init I2C communication. \n Usage: Connect pins GND VCC SDA SCL from accelerometer to pi: GND, 1,3,5 ");
        return -1;
    }
    printf("I2C connection succesfully establshed \n");
    // Switch device to measurement mode
    
    wiringPiI2CWriteReg8(fd, POWER_CTL, 0b00001000);

    while (1) {
        int8_t dataX = wiringPiI2CReadReg16(fd, DATAX0);

        int8_t dataY = wiringPiI2CReadReg16(fd, DATAY0);

        int8_t dataZ = wiringPiI2CReadReg16(fd, DATAZ0);

        printf("x: %d, y: %d , z: %d \n", dataX,dataY,dataZ);
        sleep(1);
    }

    return 0;
}
