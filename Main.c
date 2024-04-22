#include <stdio.h>
#include <unistd.h>
//#include <pigpio.h>

extern void start();
extern void gpioInitialise();
//the wait functions here are in nanoseconds, and the numbers are too big to store in assembly
void waitFast(){
	usleep(200000);
}
void wait(){
	usleep(500000);
}

int main(void){
	start();
	return(0);
}
