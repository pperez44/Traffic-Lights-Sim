;
; traffic_lights.asm
; 
; Created: 4/24/2025 8:41:26 PM
; Author: Paul Perez, Derek Mesa, Philippe Lucien
; Desc: final project that uses timer1 & interrupts to simulate
;          a traffic light cycle with a crosswalk button/LED
; ------------------------------------------------------------
.include "m328pdef.inc"

; equates pins for LEDs + buttons for compatibility as per m328pdef.inc
.equ RED_LED = PB0            ; pin 8
.equ YELLOW_LED = PB1         ; pin 9
.equ GREEN_LED = PB2          ; pin 10
.equ WALK_LED = PB3           ; pin 11
.equ BUTTON = PD3             ; pin 3

.equ CLK_NO = (1<<CS10)                    ; 0       0         0         clk (No Prescaling)
.equ CLK_8 = (1<<CS11)                     ; 0       0         1         clk / 8
.equ CLK_64 = (1<<CS11)|(1<<CS10)          ; 0       1         1         clk / 64
.equ CLK_256 = (1<<CS12)                   ; 1       0         0         clk / 256
.equ CLK_1024 = (1<<CS12)|(1<<CS10)        ; 1       0         1         clk / 1024

; states for LEDs
.equ STATE_GREEN = 0
.equ STATE_YELLOW = 1
.equ STATE_RED = 2

; global
.def temp = r16               ; misc use temp register
.def state = r17              ; global state register ( G = 0, Y = 1, R = 2 )
.def timer_count = r18        ; timer count register ( seconds that have passed )
.def walk_req = r19           ; walk LED requirement ( 1 = requirement met )

.org 0x0000         ; reset vector / execute following line on startup 
    rjmp INIT       ; jump to INIT label

.org OC1Aaddr       ; set up Timer/Counter1 Compare Match A
    rjmp TIMER1_COMPA_ISR

INIT:     ; initializes all LEDs, buttons, and timers 
    ; LEDs output
    ldi temp, (1<<RED_LED)|(1<<YELLOW_LED)|(1<<GREEN_LED)|(1<<WALK_LED)         ; temp is filled with 00001111
    out DDRB, temp            ; sets pins 8-11 as output for LEDs

    ; configure button for pull up
    cbi DDRD, BUTTON          ; make BUTTON input
    sbi PORTD, BUTTON         ; make BUTTON pull up

    ; timer1 setup 1 second
    ldi temp, (1<<WGM12)| CLK_1024 ;(1<<CS12)|(1<<CS10) ; turn on CTC mode bit and 1024 prescaler bits
    sts TCCR1B, temp          ;

    ldi temp, 0x3D            ; Desired = 1s      prescaler = 1024	OCR1AH	OCR1AL	
    sts OCR1AH, temp          ; OCR1A:	15624	(Value-1)		0x3D	0x08	
    ldi temp, 0x08
    sts OCR1AL, temp
                              ; Timer/Counter Interrupt Mask Register 1 = TIMSK1
    ldi temp, (1<<OCIE1A)     ;-	-	ICIE1	-	-	OCIE1B	0CIE1A	TOIE1
                              ;0	0	0	0	0	0	1	0 
                                                       
    sts TIMSK1, temp          ; Timer/Counter1 Output CompareA Match Interrupt Enable

    sei                       ; enable global interrupts

    clr state                 
    clr timer_count           
    clr walk_req              

main:                         ; main program
    call CHECK_BUTTON         ; call check_button function
    rjmp main                 ; loop back to main (keeps loop going forever)

TIMER1_COMPA_ISR:             ; interrupt service routine for when 1 second passes in timer 1
    inc timer_count           ; timer_count ++ 

    ; green
    cpi state, STATE_GREEN    ; check we're in green state
    brne CHECK_YELLOW         ; if NOT, branch to check yellow --------       
    cpi timer_count, 6        ; if timer_count < 6  {                 |
    brlo END_ISR              ; branch to END_ISR   }                 |
                              ;         else                          |
    cbi PORTB, GREEN_LED      ; turn off green LED                    |
    sbi PORTB, YELLOW_LED     ; turn on yellow LED                    |
    clr timer_count           ; reset timer count                     |
    ldi state, STATE_YELLOW   ; load yellow state (1) into state      |
    rjmp END_ISR              ;                                       |
                              ;                                       V
CHECK_YELLOW:
    cpi state, STATE_YELLOW   ; check that we're in yellow state
    brne CHECK_RED            ; if NOT, branch to check red    --------      
    cpi timer_count, 2        ; if timer_count < 2  {                 |
    brlo END_ISR              ; branch to END_ISR   }                 |
                              ;         else                          |
    cbi PORTB, YELLOW_LED     ; turn off YELLOW LED                   |
    sbi PORTB, RED_LED        ; turn on RED LED                       |
    clr timer_count           ; reset timer count                     |
    ldi state, STATE_RED      ; load red state (2) into state         |
    rjmp END_ISR              ;                                       |
                              ;                                       V
CHECK_RED:
    cpi state, STATE_RED      ; check we're in red state
    brne END_ISR              ; if not in red state, branch to END_ISR
                              ;         else continue

    ; walk led
    tst walk_req              ; test walk_req for zero
    breq SKIP_WALK            ; if zero then branch to skip_walk (walk requirement not met)

    cpi timer_count, 2        ; if timer_count = 2 ( 2 seconds have passed )
    breq WALK_ON              ; branch to WALK_ON
    cpi timer_count, 7        ; if timer_count = 7 ( 7 seconds have passed )
    breq WALK_OFF             ; branch to WALK_OFF

SKIP_WALK:
    cpi timer_count, 8        ; if 8 seconds havent passed
    brlo END_ISR              ; branch to END_ISR
                              
                              ;         else

    cbi PORTB, RED_LED        ; turn off RED_LED
    sbi PORTB, GREEN_LED      ; turn on GREEN_LED
    clr timer_count           ; clear timer count
    clr walk_req              ; clear walk led requirement
    ldi state, STATE_GREEN    ; turn state to green state
    rjmp END_ISR              

WALK_ON:
    sbi PORTB, WALK_LED       ; turn on walk LED
    rjmp END_ISR

WALK_OFF:
    cbi PORTB, WALK_LED       ; turn off walk LED
    rjmp END_ISR              

END_ISR:
    reti                      ; do nothing and exit interrupt routine

CHECK_BUTTON:
    in temp, PIND             ; read port D bits into temp
    sbrs temp, BUTTON         ; skip next line if button not pressed
                              ;         else, button is pressed
    ldi walk_req, 1           ;         therefore walk requirement is met
    ret
