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

.text
.global start

.extern printf
.extern wait
.extern waitFast

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