/*This is a test to see if we can pipe the python sript to C.
 * First run "python3 Phone.py" and make sure you have flask_sockets installed
 * Then run CPipetest and see that the data from the phones accelerometer goes
 * to python and finally C.  
*/
#include <unistd.h> 
#include <stdio.h> 
#include <sys/stat.h> 
#include <fcntl.h>

struct data_in {
	int data;
}

main(int argc, char* argv[]) {
	mkfifo("pipe_test", 0666); 
	int fd = -1; 

	fd = open("fifo", O_RDONLY); 
	while(1) {
		struct data_in buffer;
		read(fd, (void*)(&buffer), sizeof(struct data_in));
		if ((void*)(&buffer) != 0){
			printf("data: %d\n", buffer.data);
			sleep(0.1);
		}
    	}
    	close(fd);
}
