@compile using C library
@gcc -Wall -pthread -o prog Main.c GameCtrl.s -lpigpio -lrt
.data
.balign 4
string: .asciz "%d\n"
begin: .asciz "Start\n"
coords: .asciz "(%d,%d)\n"
pinVal: .asciz "Pin%d: %d\n"

@top-left, top-right, bottom-left, bottom-right etc.
led: .int 21,20,16,12,26,19,13,6
.equ maxX, 4
.equ maxY, 2
@left,right,down,up
input: .int 17,4,3,2
inputVals: .space 16
.equ inputSize, 4
.equ exitButton, 23

@this was for custom GPIO library, which did not work
/*
@----MEMORY VARIABLES----
@ mmap part taken from by https://bob.cs.sonoma.edu/IntroCompOrg-RPi/sec-gpio-mem.html
@ Args for mmap
.equ    OFFSET_FILE_DESCRP, 0   @ file descriptor
.equ    mem_fd_open, 3
.equ    BLOCK_SIZE, 4096        @ Raspbian memory page
.equ    ADDRESS_ARG, 3          @ device address
@ Constant program data
    .section .rodata
device:
    .asciz  "/dev/gpiomem"

@ The following are defined in /usr/include/asm-generic/mman-common.h:
.equ    MAP_SHARED,1    @ share changes with other processes
.equ    PROT_RDWR,0x3   @ PROT_READ(0x1)|PROT_WRITE(0x2)

.equ    GPCLR0, 0x28    @ clear register offset
.equ    GPSET0, 0x1c    @ set register offset
memAddr: .space 4
*/

.text
.global start

.extern printf
.extern wait
.extern waitFast

/*
.extern gpioInitialise
.extern gpioSetMode
.extern gpioSetPullUpDown
.extern gpioWrite
.extern gpioRead
*/

start:
	push {ip, lr}
	@initalize the gpio pin
	bl gpioInitialise
	bl initLEDs
	bl initInputs
	bl initExitButton
	
	bl testLEDs
	bl game
	pop {ip, pc}
game:
	push {ip, lr}
	ldr r0, =begin
	bl printf
	
	ldr r8, =input
	ldr r9, =led
	@location of player, starts in top left
	@x and y coordinates, r5=x, r6=y
	mov r5, #0
	mov r6, #0
	
	@start with inital position
	bl getLED
	mov r1, #1
	bl gpioWrite

	bl wait
	
	mainLoop:
		@check if exit button has been pressed
		mov r0, #exitButton
		bl gpioRead
		mov r1, #0
		cmp r0,r1
		bEQ exitGame
		
		
		@turn off the current LED of the player
		bl getLED
		@turn off this led
		mov r1, #0
		bl gpioWrite
		
		@print coords
		ldr r0, =coords
		mov r1, r5
		mov r2, r6
		bl printf
	
		@get next input from buttons
		bl getInput
		@input values are stored in the array
		
		@check which direction was sent
		ldr r4, =inputVals
		
		ldr r1, [r4]
		mov r2, #0
		cmp r1, r2
		bNE rightCheck
		@check if out of would be bounds
		cmp r5, #0
		bEQ oveflowX
		@else subtract 1 from x
		sub r5, #1
		b rightCheck
		oveflowX:
			mov r0, #maxX
			mov r1, #1
			sub r0, r0, r1
			mov r5, r0
			
			mov r2, r6
			mov r1, r5
			ldr r0, =coords
			bl printf
		
		rightCheck:
		ldr r1, [r4,#4]
		mov r2, #0
		cmp r1, r2
		bNE downCheck
		@add 1 to x
		add r5, #1
		@check if out of bounds
		cmp r5, #maxX
		bLT downCheck
		mov r5, #0
		
		downCheck:
		ldr r1, [r4,#8]
		mov r2, #0
		cmp r1, r2
		bNE upCheck
		@add 1 to y
		add r6, #1
		@check if out of bounds
		cmp r6, #maxY
		bLT upCheck
		mov r6, #0
		
		upCheck:
		ldr r1, [r4,#12]
		mov r2, #0
		cmp r1, r2
		bNE doneDir
		@check if out of would be bounds
		cmp r6, #0
		bEQ oveflowY
		@else subtract 1 from y
		sub r6, #1
		b doneDir
		oveflowY:
			mov r0, #maxY
			mov r1, #1
			sub r0, r0, r1
			mov r6, r0
		doneDir:
		
		@print coords
		ldr r0, =coords
		mov r1, r5
		mov r2, r6
		bl printf
		
		
		bl getLED
		@turn turn on this led
		mov r1, #1
		bl gpioWrite
		
		@wait a bit so the player can see gamestate
		bl wait
		
		b mainLoop
	exitGame:
		bl clearLEDs
		
		@do an outro led display
		@loop counter
		mov r4, #0
		outroLoop:
			@get the beginning of leds
			ldr r0, [r9, r4]
			mov r1, #1		
			bl gpioWrite
			
			@get end of leds
			sub r1, r10, r4
			sub r1, #4
			ldr r0, [r9,r1]
			mov r1, #1
			bl gpioWrite
			
			bl wait
			
			@increment counter
			add r4, #4
			mov r0, #maxX
			mov r1, #4
			mul r0, r0, r1
			cmp r4, r0
			BLE outroLoop
		
		bl wait
		bl clearLEDs
	pop {ip, pc}
getLED:
	push {ip, lr}
	
	
	@assuming r5=x and r6=y
	@(maxX)*y + x
	mov r1, #maxX
	mul r0, r1, r6
	add r0, r0, r5
	
	
	@load the pin obtained from the mapping function
	@move over 4 bits per element
	mov r1, #4
	mul r0, r0, r1
	ldr r0, [r9,r0]
	
	pop {ip, pc}
getInput:
	push {ip, lr}
	@total byte size of array
	mov r0, #inputSize
	mov r1, #4
	mul r10, r0, r1
	
	@loop counter
	mov r4, #0
	loopInputs:
		@get the next pin 
		ldr r0, [r8, r4]
		bl gpioRead
		@save the value to the value array
		ldr r1, =inputVals
		str r0, [r1,r4]
		
		ldr r2, [r1,r4]
		ldr r1, [r8, r4]
		ldr r0, =pinVal
		bl printf
		
		@increment counter
		add r4, #4
		@repeat until all the size of the array has been iterated
		cmp r4, r10
		BLT loopInputs
	pop {ip, pc}

initLEDs:
	push {ip, lr}
	@load the LEDs
	ldr r5, =led
	
	@total byte size of array
	mov r1, #maxX
	mov r2, #maxY
	mul r0, r1, r2
	mov r1, #4
	mul r9, r0, r1
	
	@loop counter
	mov r8, #0
	loopLED:
		@get the next pin
		ldr r0, [r5, r8]
		
		@set to output mode
		mov r1, #1
		bl gpioSetMode
		
		@turn off led in case its already on
		ldr r0, [r5, r8]
		mov r1, #0
		bl gpioWrite
		
		@increment counter
		add r8, #4
		@repeat until all the size of the array has been iterated
		cmp r8, r9
		BLT loopLED
	pop {ip, pc}
initInputs:
	push {ip, lr}
	@load the inputs
	ldr r6, =input
	@total byte size of array
	mov r0, #inputSize
	mov r1, #4
	mul r9, r0, r1
	
	@loop counter
	mov r8, #0
	loopIn:
		@get the next pin 
		ldr r0, [r6, r8]
		
		@set to input mode
		mov r1, #0
		bl gpioSetMode
		
		@set the internal resistor
		ldr r0, [r6, r8]
		@PI_PUD_UP = 2
		mov r1, #2
		bl gpioSetPullUpDown
		
		
		@increment counter
		add r8, #4
		@repeat until all the size of the array has been iterated
		cmp r8, r9
		BLT loopIn
	pop {ip, pc}
initExitButton:
	push {ip, lr}
	mov r0, #exitButton
	mov r1, #0
	bl gpioSetMode
	mov r0, #exitButton
	mov r1, #2
	bl gpioSetPullUpDown
	pop {ip, pc}
clearLEDs:
	push {ip, lr}
	@clear the screen
	@total byte size of array
	mov r1, #maxX
	mov r2, #maxY
	mul r0, r1, r2
	mov r1, #4
	mul r10, r0, r1
	
	@loop counter
	mov r4, #0
	clearLoop:
		@get the next pin 
		ldr r0, [r9, r4]
		mov r1, #0
		bl gpioWrite
		@increment counter
		add r4, #4
		@repeat until all the size of the array has been iterated
		cmp r4, r10
			BLT clearLoop
	pop {ip, pc}
testLEDs:
	push {ip, lr}
	@total byte size of array
	mov r1, #maxX
	mov r2, #maxY
	mul r0, r1, r2
	mov r1, #4
	mul r9, r0, r1
	@load the LEDs
	ldr r6, =led
	@loop counter
	mov r8, #0
	loopTest:
		@get the next pin 
		ldr r0, [r6, r8]
		bl flashLED
		@increment counter
		add r8, #4
		@repeat until all the size of the array has been iterated
		cmp r8, r9
		BLT loopTest
	pop {ip, pc}
flashLED:
	push {ip, lr}
	@r0 has pin number
	@save the gpio pin
	mov r5, r0
	mov r1, #1
	bl gpioWrite
	mov r0, #1
	bl waitFast
	mov r0, r5
	mov r1, #0
	bl gpioWrite

	pop {ip, pc}

@custom pin I/O code (not funtioning, use gcc -Wall -pthread -o prog Main.c GameCtrl.s -lpigpio -lrt to compile with library instead)
/*
gpioInitialise:
	push {ip, lr}
	@ Open /dev/gpiomem for read/write and syncing
    ldr     r1, O_RDWR_O_SYNC   @ flags for accessing device
    ldr     r0, mem_fd          @ address of /dev/gpiomem
    bl      open   
    mov     r4, r0              @ use r4 for file descriptor

	@ Map the GPIO registers to a main memory location so we can access them
	@ mmap(addr[r0], length[r1], protection[r2], flags[r3], fd[r4])
    str     r4, [sp, #OFFSET_FILE_DESCRP]   @ r4=/dev/gpiomem file descriptor
    mov     r1, #BLOCK_SIZE                 @ r1=get 1 page of memory
    mov     r2, #PROT_RDWR                  @ r2=read/write this memory
    mov     r3, #MAP_SHARED                 @ r3=share with other processes
    mov     r0, #mem_fd_open                @ address of /dev/gpiomem
    ldr     r0, GPIO_BASE                   @ address of GPIO
    str     r0, [sp, #ADDRESS_ARG]          @ r0=location of GPIO
    bl      mmap
    @mov     r5, r0           @ save the virtual memory address in r5
	@save to array instead
	@ldr r1, =memAddr
	@str r0, [r1]
	ldr r0, =string
	bl printf
	pop {ip, pc}

gpioSetMode:
	push {ip, lr}
	
	@r0 has pin number, save it
	mov r6, r0
	@r1 has mode number, save it
	mov r8, r1
	
	@GPFSEL
	@1-9
	cmp r6, #10
	bGE next1
	mov r5, #0x02 
	@this is for calculating the output mask
	mov r2, r6
	b gpioOffsetDone
	
	@10-19
	next1:
	cmp r6, #20
	bGE next2
	mov r5, #0x04 
	sub r2, r6, #10
	b gpioOffsetDone
	
	@20-29
	next2:
	@no cmp needed since its the only other case for our purposes
	mov r5, #0x08 
	sub r2, r6, #20
	
	gpioOffsetDone:
	@GPFSEL is in r5
	
	@MASK
	@r4 is output or input mask
	mov r4, #1
	@every set has 9 pins, so check how many bits we need to move over to get to the correct one
	@this was calculated previously in r2
	@keep going up by powers of 2 until we get the correct bit
	
	@we are only going to go up to a power just before the answer so we can use this in the mask section
	sub r2, #1
	
	mov r0, #2
	maskLoop:
		cmp r4, r2
		bEQ maskLoopDone
		mul r4, r4, r0
		b maskLoop
	maskLoopDone:
	mov r1, r2
	mul r4, r4, r0
	@check if this is input. If so, just set it all to zero
	cmp r8, #0
	bNE nextMask
	mov r4, #0
	@GPFSEL_GPIO_MASK is in r4
	
	
	nextMask:
	@we now need to set this and the next to bits to build our 
	@to get this number, we can multiply the mask number by 2 two times and subtract 1 to get all 1's behind us
	@Subtracting the mask number divided by 2 from here gives us the 3 bits we need
	mov r0, #4
	mul r3, r4, r0
	sub r3, #1
	@we now have all 1s. Now, to get the 3 bits alone
	sub r3, r2
	
	@MAKE_GPIO_OUTPUT is in r3
	
	
	@ Set up the GPIO pin funtion register in programming memory
	ldr r8, =memAddr
	ldr r8, [r8]
    add     r0, r8, r5           @ calculate address for GPFSEL2
    ldr     r2, [r0]                    @ get entire GPFSEL2 register
    bic     r2, r2, r4@ clear pin field
    orr     r2, r2, r3 @ enter function code
    str     r2, [r0]                    @ update register
	pop {ip, pc}

gpioWrite:
	push {ip, lr}
	@save pin in r4
	mov r4, r0
	@check if its on or off write
	cmp r1, #0
	@get the memory address
	ldr r1, =memAddr
	ldr r1, [r1]
	bEQ turnOff
    add     r0, r1, #GPSET0 @ calc GPSET0 address

    mov     r3, #1          @ turn on bit
    lsl     r3, r3, r4    @ shift bit to pin position
    orr     r2, r2, r3      @ set bit
    str     r2, [r0]        @ update register
	pop {ip, pc}
	turnOff:
		add     r0, r1, #GPCLR0 @ calc GPCLR0 address

		mov     r3, #1          @ turn off bit
		lsl     r3, r3, r4    @ shift bit to pin position
		orr     r2, r2, r3      @ set bit
		str     r2, [r0]        @ update register
	pop {ip, pc}
gpioRead:
	push {ip, lr}
	@save pin in r4
	mov r4, r0
	@get the memory address
	ldr r1, =memAddr
	ldr r1, [r1]
	add r0, r1, #GPSET0 @ calc GPSET0 address
	push {ip, pc}

gpioSetPullUpDown:
	push {ip,lr}
	@there is nothing to do here, this is just to make this file and the C library to be interchangable
	pop {ip, pc}
	
@-----Other------
GPIO_BASE:
    .word   0xfe200000  @GPIO Base address Raspberry pi 4
mem_fd:
    .word   device
O_RDWR_O_SYNC:
    .word   2|256       @ O_RDWR (2)|O_SYNC (256).
*/
