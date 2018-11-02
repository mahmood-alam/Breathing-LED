;****************** main.s ***************
; Program written by: Mahmood Alam and Shehryar Ahmed
; Date Created: 2/4/2017
; Last Modified: 2/14/2017
; Brief description of the program
;   The LED toggles at 8 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE0 is LED output (1 activates external9 LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE0 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 8Hz,
;      which is 8 times per second with a duty-cycle of 20%.
;      Therefore, the LED is ON for (0.2*1/8)th of a second
;      and OFF for (0.8*1/8)th of a second.
;   3) When the button on (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 20% to 40% to 60%
;      to 80% to 100%(ON) to 0%(Off) to 20% to 40% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 8Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 20%.
;      TIP: debugging the breathing LED algorithm and feel on the simulator is impossible.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C	
	
; PortF device registers
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_PORTF_PCTL_R  EQU 0x4002552C
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C

SYSCTL_RCGCGPIO_R  EQU 0x400FE608
	
delay EQU 0x3D090 ; 250,000
change EQU 0xC350 ; 50,000
	
bdelay EQU 0x2710 ; 10,000
bchange EQU 0x3E8 ; 1000
		
       IMPORT  TExaS_Init
       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB
       EXPORT  Start
Start
 ; TExaS_Init sets bus clock at 80 MHz
      BL  TExaS_Init ; voltmeter, scope on PD3
      CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
	  
; INITIALIZATION (Port F)
	; turn on Port F clock (bit 5)
	LDR R1, =SYSCTL_RCGCGPIO_R      
    LDR R0, [R1]                 
    ORR R0, R0, #0x20               
    STR R0, [R1]     
	
	; delay for clock
    NOP
    NOP       
	
	; unlock Port F lock register
    LDR R1, =GPIO_PORTF_LOCK_R      
    LDR R0, =0x4C4F434B             
    STR R0, [R1]               
	
	; enable Port F commit register
    LDR R1, =GPIO_PORTF_CR_R        
    MOV R0, #0xFF                   
    STR R0, [R1]           

	; Port F GPIO
    LDR R1, =GPIO_PORTF_PCTL_R      
    MOV R0, #0x00000000             
    STR R0, [R1]     
		
	; Port F direction register 
    LDR R1, =GPIO_PORTF_DIR_R       
    MOV R0,#0x00                    
    STR R0, [R1]    

	; regular port function
    LDR R1, =GPIO_PORTF_AFSEL_R     
    MOV R0, #0                      
    STR R0, [R1]                    
	
	; pull up for pin 4
    LDR R1, =GPIO_PORTF_PUR_R       
    MOV R0, #0x10                   
    STR R0, [R1]
		
	; Port F digital I/O
    LDR R1, =GPIO_PORTF_DEN_R       
    MOV R0, #0xFF                   
    STR R0, [R1]            

; INITIALIZATION (Port E)
	; turn on Port E clock (bit 4)
	LDR R1, =SYSCTL_RCGCGPIO_R      
    LDR R0, [R1]                 
    ORR R0, R0, #0x10               
    STR R0, [R1]     
	
	; delay for clock
    NOP
    NOP                          

	; Port E direction register (pin 0 is output) 
    LDR R1, =GPIO_PORTE_DIR_R       
    MOV R0,#0x01                    
    STR R0, [R1]    

	; regular port function
    LDR R1, =GPIO_PORTE_AFSEL_R     
    MOV R0, #0                      
    STR R0, [R1]                    
		
	; Port E digital I/O
    LDR R1, =GPIO_PORTE_DEN_R       
    MOV R0, #0xFF                   
    STR R0, [R1] 

; Initial Duty Cycle 
	MOV R4, #1 ; 0= 0% duty cycle, 1= 20%, 2= 40%, 3= 60%, 4= 80%, 5= 100%

loop

; R2 = time-on, R3 = time-off
	MOV R2, #0 ;time1
	LDR R3, =delay ; time2
	
; Set time-on based on duty cycle
	MOVS R1, R4
	LDR R0, =change
increment	BEQ on1
	ADD R2, R2, R0
	SUBS R1, R1, #1
	B increment
	
; check if duty cycle = 0%
on1	ADDS R2,R2, #0
	BEQ off1

; LED on and delay
	BL LEDon 
	BL delay1 
	
; Set time-off based on duty cycle	
	MOVS R1, R4
	LDR R0, =change
decrement	BEQ off1
	SUBS R3, R3, R0
	SUBS R1, R1, #1
	B decrement
	
; check if duty cycle = 100%
off1	ADDS R3,R3, #0
	BEQ press
	
; LED off and delay
	BL LEDoff 
	BL delay2 
	
; check if PE1 is pressed and released (R5 has previous PE1 value)
press	LDR R1, =GPIO_PORTE_DATA_R 
    LDR R0, [R1]               
    AND R0,R0,#0x02
	ADDS R0, R0, #0
	BNE update
	AND R6, R5, #0x02 ;(if current PE1 is 0: check if R5 is 1)
	ADDS R6, R6, #0
	BNE changeDuty;(if R5 is 1, checkDuty)
update MOV R5, R0 ;(if R5 is not 1 or R0 not 0, then R5 = R0)

; branch to breathing if PF4 is pressed
	LDR R1, =GPIO_PORTF_DATA_R 
	LDR R0, [R1] 
	AND R0, R0, #0x10
	ADDS R0, R0, #0
	BEQ breathing
	
	  B    loop

; delay for LED on
delay1 
	MOV R0,#10
wait1 SUBS R0,R0,#0x01
    BNE wait1
    SUBS R2,R2,#0x01
	BNE delay1
    BX lr

; delay for LED off
delay2 
	MOV R0,#10
wait2 SUBS R0,R0,#0x01
    BNE wait2
    SUBS R3,R3,#0x01
	BNE delay2
    BX lr

; change Duty cycle if PE1 is pressed and released
changeDuty
	SUBS R6, R4, #5
	BEQ resetDuty
	ADD R4, R4, #1
	B return
resetDuty AND R4, R4, #0
return	B update

LEDon
	LDR R1, =GPIO_PORTE_DATA_R 
    MOV R0, #0x01                   
	STR R0, [R1] 
	BX lr
	
LEDoff
	LDR R1, =GPIO_PORTE_DATA_R 
    EOR R0, R1, R1                   
	STR R0, [R1]  
	BX lr

breathing 
	MOV R6, #0 ; duty cycle 
	MOV R9, #1 ; increasing or decreasing
	MOV R11, #350 ; delay for each duty cycle
	
; branch back to loop if PF4 is released
bloop	LDR R1, =GPIO_PORTF_DATA_R 
	LDR R0, [R1] 
	AND R0, R0, #0x10
	ADDS R0, R0, #0
	BNE loop

; delay times
	MOV R7, #0 ; delay1 time
	LDR R8, =bdelay ; delay2 time
	
; set time-on based on duty-cycle
	MOVS R1, R6
	LDR R0, =bchange
increment2	BEQ on2
	ADD R7, R7, R0
	SUBS R1, R1, #1
	B increment2
	
; check if duty cycle = 0%
on2	ADDS R7,R7, #0
	BEQ off2
	
	BL LEDon  ; LED on
	
; delay 1
	MOV R0,R7
wait3 SUBS R0,R0,#0x01
    BNE wait3
	
; Set time-off based on duty cycle	
	MOVS R1, R6
	LDR R0, =bchange
decrement2	BEQ off2
	SUBS R8, R8, R0
	SUBS R1, R1, #1
	B decrement2
	
; check if duty cycle = 100%
off2	ADDS R8,R8, #0
	BEQ check
	
	BL LEDoff ; LED off
	
; delay 2
	MOV R0,R8
wait4 SUBS R0,R0,#0x01
    BNE wait4

; delay for each duty cycle
	SUBS R11, R11, #1
	BNE bloop
	MOV R11, #350
	
; changes duty cycle
check ADDS R10, R6, #0 ; if 0%, then start increasing duty
	BEQ increasing
	B d100
increasing MOV R9, #1
d100	SUBS R10, R6, #5 ; if 100%, then start decreasing duty
	BEQ decreasing
	B someduty
decreasing MOV R9, #0
someduty	ADDS R9, R9, #0 ; if neither, then add or subtract based on increasing/decreasing
	BEQ sub1
	ADD R6, R6, #1
	B bloop
sub1 SUB R6, R6, #1
	B bloop
	
      ALIGN      ; make sure the end of this section is aligned
      END        ; end of file
