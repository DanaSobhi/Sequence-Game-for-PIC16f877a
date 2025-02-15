PROCESSOR 16F877
; Clock = XT 4MHz, standard fuse settings
__CONFIG 0x3731

; LABEL EQUATES
INCLUDE "P16F877A.INC"

Cursor EQU 28
Timer EQU 39
Char EQU 30 
Index EQU 46
Characters EQU 48
Current_char EQU 47
BlinkCount EQU 49 ; Counting blinks

LED_States EQU 50 ; Register to store LED states
Seed EQU 51 ; Randomization seed (must be non-zero)
RandomCounter EQU 52 ; Counter for randomization
Score EQU 53 ; Register to store user score

; user input
TEMP1 EQU 54 ; Temporary register for the first input LED


; Random leds 
SEQ1 EQU 10 ;Temporary register for the 1st random LED

Wrong EQU 64
Lives EQU 63 
Count EQU 0x52
InputCount EQU 0x54
CurrentInputIndex EQU 0x55
SequencePointer EQU 0x56
UserInput EQU 0x57
timerCounter EQU 62

BLUE_LED EQU 0 ; RA0 for blue LED
GREEN_LED EQU 1 ; RA1 for green LED
RED_LED EQU 2 ; RA2 for red LED
YELLOW_LED EQU 3 ; RA3 for yellow LED

; Button pin definitions
BLUE_BTN EQU 1 ; RB1 for blue button
GREEN_BTN EQU 2 ; RB2 for green button
RED_BTN EQU 3 ; RB3 for red button
YELLOW_BTN EQU 4 ; RB4 for yellow button

RS EQU 1 ; Register select output bit
E EQU 2 ; Display data strobe

; Program Begins ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ORG 0 ; Default start address
	NOP ; Required for ICD mode
	GOTO INITIALIZE

INITIALIZE:
    ; Configure Timer0 and related settings in Bank1
    BANKSEL OPTION_REG
    BCF     OPTION_REG, T0CS   ; Timer0 clock source = internal
    BCF     OPTION_REG, PSA    ; Prescaler assigned to Timer0
    BSF     OPTION_REG, PS2    ; Set prescaler to 1:256
    BSF     OPTION_REG, PS1
    BSF     OPTION_REG, PS0
    BCF     OPTION_REG, NOT_RBPU ; Enable PORTB pull-ups

    ; Configure I/O directions in Bank1
    MOVLW   B'11110000'        ; RA0-RA3 as outputs for LEDs
    MOVWF   TRISA
    MOVLW   B'11111111'        ; PORTB as input
    MOVWF   TRISB
    CLRF    PORTA              ; Clear all LEDs initially
	; LCD 
	BANKSEL TRISC ; Select bank 1
	MOVLW B'11110000' ; Keypad direction code
	MOVWF TRISC
	CLRF TRISD ; Display port is output
	CLRF PORTD ; Clear display outputs

	BANKSEL TRISB          ; Switch to Bank 1
	MOVLW   b'11111110'    ; RB0 = output (if needed), RB1-RB4 = inputs
	MOVWF   TRISB
	BANKSEL PORTB          ; Return to Bank 0
	CLRF    PORTB          ; Initialize PORTB outputs to 0

    ; Initialize ports and variables in Bank0
    BANKSEL PORTC
    MOVLW   0xFF
    MOVWF   PORTC              ; Set keypad outputs high
    CLRF    PORTD              ; Clear display outputs
    CLRF    PORTA              ; Clear all LEDs initially
    MOVLW   0x1
    MOVWF   Seed               ; Initialize random seed (non-zero)
    CLRF    LED_States         ; Clear LED states
    CLRF    RandomCounter      ; Initialize randomization counter
    CLRF    Score             

	MOVLW D'1' 
	MOVWF Score   ; Initialize score
	MOVLW D'3'
	MOVWF Lives ; give user 3 lives

    GOTO    WaitForButtonPress ; Wait for the first button press

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Main program
WaitForButtonPress:
    ; Wait until any button is pressed
	CALL inid ; Initialize the display
	MOVLW 3 ; Set initial blink count to 3
	MOVWF BlinkCount


BlinkLoop:
	MOVF BlinkCount, F ; Check if BlinkCount is zero
	BTFSC STATUS, Z ; Skip next instruction if BlinkCount is not zero
	GOTO WaitLoop ; If count is zero, move to next step
	CALL DisplayMessage ; Show the message
	CALL OneSecondDelay ; Wait 1 second with message shown
	CALL ClearDisplay ; Clear the display
	CALL DisplayMessage ; Show the message
	DECF BlinkCount, F ; Decrease blink counter
	GOTO BlinkLoop ; Repeat the process

    BANKSEL PORTB
WaitLoop:
    BTFSS   PORTB, BLUE_BTN
    GOTO    StartLevel1
    BTFSS   PORTB, GREEN_BTN
    GOTO    StartLevel1
    BTFSS   PORTB, RED_BTN
    GOTO    StartLevel1
    BTFSS   PORTB, YELLOW_BTN
    GOTO    StartLevel1
    GOTO    WaitLoop

StartLevel1:
    ; Level 1: Start 3 LED random sequence
    CALL DisplayLevel         ; Display "LEVEL 1" on the LCD
    CALL RandomLEDSequence     ; Generate and display the random LED sequence
    CALL CheckUserInput
    GOTO WaitForButtonPress    ; Return to waiting for button press

NextLeveL:
    ;Next level for all levels:
    CALL DisplayLevel         ; Display "LEVEL" on the LCD
	CALL onesecond
	CALL DisplayStart
    CALL RandomLEDSequence     ; Generate and display the random LED sequence
    CALL CheckUserInput
    GOTO WaitForButtonPress    ; Return to waiting for button press
	GOTO NextLeveL ;keep looping after every level


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RandomLEDSequence:
    BANKSEL SEQ1          ; Select bank where SEQ1 is located
    MOVLW   SEQ1
    MOVWF   FSR           ; Set FSR to point to SEQ1
    MOVLW   D'3'          ; Initial 3 LEDs
    MOVWF   Count
GenerateInitial:
    CALL    UpdateSeed
    CALL    GetRandomLED
    MOVWF   INDF          ; Store the value at the address pointed by FSR
    INCF    FSR, F        ; Move to the next memory location
    CALL    LightUpLED
    DECFSZ  Count, 1
    GOTO    GenerateInitial

    ; Determine additional LEDs based on Score
    MOVLW   2             ; Check if Score >= 2
    SUBWF   Score, W      ; W = Score - 2
    BNC     NoAddition    ; If Score < 2, branch to NoAddition
    DECF    Score, W      ; Calculate additional LEDs (Score - 1)
    MOVWF   Count         ; Set loop counter

    ; Reset FSR to the end of the initial sequence
    MOVLW   SEQ1
    ADDLW   D'3'          ; Point to the end of the initial 3 LEDs
    MOVWF   FSR

GenerateAdditional:
    CALL    UpdateSeed
    CALL    GetRandomLED
    MOVWF   INDF          ; Store the value at the address pointed by FSR
    INCF    FSR, F        ; Move to the next memory location
    CALL    LightUpLED
    DECFSZ  Count, 1
    GOTO    GenerateAdditional

NoAddition:
    RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CheckUserInput:
    CALL    TurnOffLED    ; Ensure LEDs are off
    CALL    displayPlay   ; Display "PLAY"
    MOVLW   0x00
    MOVWF   timerCounter  ; Reset timer counter
	MOVLW   0x00 
	MOVWF   Wrong

    ; Calculate required inputs (Score + 2)
    MOVF    Score, W
    ADDLW   D'2'          ; WREG = Score + 2
    MOVWF   InputCount    ; Store required input count

    ; Initialize pointers and counters
    CLRF    CurrentInputIndex ; Reset input counter
    MOVLW   SEQ1              ; Point to start of sequence
    MOVWF   SequencePointer   ; Store sequence start address

InputCheckLoop:
    ; Debug: Display current sequence value
    MOVF    SequencePointer, W
    MOVWF   FSR
    MOVF    INDF, W

    ; Check if all inputs have been verified
    MOVF    CurrentInputIndex, W
    SUBWF   InputCount, W     ; InputCount - CurrentInputIndex
    BTFSS   STATUS, Z         ; Skip if CurrentInputIndex == InputCount
    GOTO    WaitForInput      ; Continue checking inputs
    GOTO    CheckinputSequence  ; Exit loop when all inputs are correct

WaitForInput:
    ; Only check timer if it's not the last input
    MOVF    CurrentInputIndex, W
    SUBWF   InputCount, W     ; InputCount - CurrentInputIndex
    ;BTFSC   STATUS, Z         ; Skip if CurrentInputIndex == InputCount (last input)
    ;GOTO    SkipTimerCheck    ; Skip timer check for the last input
    CALL    CheckTimer1       ; Handle timer checks (only for non-last inputs)

SkipTimerCheck:
    CALL    checkWhichbutton  ; Check for button press (result in W)
    ANDLW   0xFF              ; Test if any button pressed
    BTFSC   STATUS, Z         ; If no button pressed, keep checking
    GOTO    WaitForInput

    ; Process valid input
    MOVWF   UserInput         ; Store button press value
    MOVWF   PORTA             ; Light up corresponding LED
    CALL    OneSecondDelay
    CALL    TurnOffLED

    ; Verify against sequence
    MOVF    SequencePointer, W ; Get current sequence address
    MOVWF   FSR               ; Point FSR to sequence element
    MOVF    INDF, W           ; Get sequence value
    XORWF   UserInput, W      ; Compare with user input
    BTFSS   STATUS, Z         ; Check for match
    GOTO    WrongInput   ; Handle incorrect input

Continue:
    ; If input matches, check if it's the last input
    INCF    CurrentInputIndex, F ; Increment input counter
    MOVF    CurrentInputIndex, W ; Load current input index
    SUBWF   InputCount, W     ; InputCount - CurrentInputIndex
    BTFSS   STATUS, Z         ; Skip if CurrentInputIndex == InputCount (last input)
    GOTO    MoveToNextInput   ; Not the last input, continue checking

    ; If it's the last input go check
    GOTO    CheckinputSequence

WrongInput:
	MOVLW   0x01 
	MOVWF   Wrong
	GOTO Continue

CheckinputSequence:
	MOVF    Wrong, W            ; Load Wrong flag into W
    ANDLW   0xFF                ; Test if Wrong flag is non-zero
    BTFSS   STATUS, Z           ; Skip next instruction if Wrong == 0
    GOTO    DisplayTryagain     ; Go to "TRY AGAIN" if any error was detected
	;if not
	GOTO    AllInputsCorrect

MoveToNextInput:
    ; Move to next sequence element
    INCF    SequencePointer, F ; Next sequence address
    MOVLW   0x00
    MOVWF   timerCounter       ; Reset timer for next input
    GOTO    InputCheckLoop     ; Continue checking inputs

AllInputsCorrect:
    CALL    DisplayCongratulation
    CALL    IncrementScore     ; Advance to next level
    GOTO    NextLeveL

checkWhichbutton:
	BANKSEL PORTB
	; Check Blue Button (RB1)
	BTFSS PORTB, BLUE_BTN
    RETLW   b'00000001'
	; Check Green Button (RB2)
	BTFSS PORTB, GREEN_BTN
    RETLW   b'00000010'
	; Check Red Button (RB3)
	BTFSS PORTB, RED_BTN
    RETLW   b'00000100'
	; Check Yellow Button (RB4)
	BTFSS PORTB, YELLOW_BTN
    RETLW   b'00001000'
	; no button checked
	RETLW 0x00 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckTimer1:
	    incf timerCounter, F	;increment the timer
		MOVLW	D'250'		; Load count 
		CALL	xms
		; min is 60000ms 
    	MOVLW   D'230'           ; 230 iterations
		xorwf timerCounter, W  ;check if timer reached limit
		btfsc STATUS, Z ; when res is zero Z = 1
		call DisplayTimeover  ; do this when equal 

   		MOVLW   0x00       ; Set W to 0
		GOTO checkWhichbutton
    	ANDLW   0xFF       ; AND W with 0xFF (no change to W, but sets Z flag)
    	BTFSC   STATUS, Z  ; Skip next instruction if Z is clear (W != 0)
    	GOTO    CheckTimer1
		
		RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IncrementScore:
    ; Increment the user's score
    INCF Score, 1
    RETURN

UpdateSeed:
    ; Dynamically update the Seed value based on Timer0
    BANKSEL TMR0
    MOVF    TMR0, W
    ADDWF   Seed, F
    SWAPF   Seed, F
    COMF    Seed, F
    RETURN

GetRandomLED:
    ; Use the updated Seed value to generate a random number
    MOVF    Seed, W
    ANDLW   0x03               ; Mask to get values 0-3
    ADDWF   PCL, F
    RETLW   b'00000001'        ; Blue LED (RA0)
    RETLW   b'00000010'        ; Green LED (RA1)
    RETLW   b'00000100'        ; Red LED (RA2)
    RETLW   b'00001000'        ; Yellow LED (RA3)

LightUpLED:
    ; Light up the LED corresponding to the value in W
    MOVWF   PORTA              ; Turn on the selected LED
    CALL    OneSecondDelay     ; Wait for 1 second (ON period)
    CLRF    PORTA              ; Turn off all LEDs
    CALL    OneSecondDelay     ; Wait for 1 second (OFF period)
    RETURN

TurnOffLED:
    CLRF PORTA      ; Clear PORTA to turn off LEDs
    RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DisplayLevel:
	CALL ClearDisplay
	MOVLW 0x80 ; Position to first row
	BCF Select, RS ; Command mode
	CALL send
	BSF Select, RS ; Data mode
	
	MOVLW 'L'
	CALL send
	MOVLW 'E'
	CALL send
	MOVLW 'V'
	CALL send
	MOVLW 'E'
	CALL send
	MOVLW 'L'
	CALL send
	
	MOVLW ' '
	CALL send

	MOVF   Score, W   ; Load the value of Score into W
	ADDLW  D'48'      ; Add 48 (decimal) = 0x30 (hex) to W (convert to ASCII)
	CALL   send       ; Send the ASCII value to the display		
	RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DisplayTryagain:

	CALL ClearDisplay
	MOVLW 0x80 ; Position to first row
	BCF Select, RS ; Command mode
	CALL send
	BSF Select, RS ; Data mode
	
    MOVLW   'T'
    CALL    send
    MOVLW   'r'
    CALL    send    
    MOVLW   'y'
    CALL    send       
    MOVLW   ' '
    CALL    send   
    MOVLW   'a'
    CALL    send
    MOVLW   'g'
    CALL    send   
    MOVLW   'a'
    CALL    send  
    MOVLW   'i'
    CALL    send   
    MOVLW   'n'
    CALL    send	

	MOVLW ' '
	CALL send

	MOVF   Lives, W   ; Load the value of Lives into W
	ADDLW  D'48'      ; Add 48 (decimal) = 0x30 (hex) to W (convert to ASCII)
	CALL   send       ; Send the ASCII value to the display		
    ; Wait for 3 seconds
    MOVLW   D'3'
    CALL    xseconds
    
   
    ; Check if Lives is 0
    MOVF    Lives, W        ; Load Lives into W register
    BTFSC   STATUS, Z       ; Check if Lives == 0 (Zero flag set)
    GOTO    DisplayGameover ; If Lives == 0, go to DisplayGameover

	MOVLW D'1'              ; Load the literal value 1 into W
	SUBWF Lives, F          ; Subtract W from Lives (Lives = Lives - 1) 

    ; Check if Score == 1
    MOVF    Score, W        ; Load Score into W register
    SUBLW   D'1'            ; Subtract 1 from Score (W = 1 - Score)
    BTFSC   STATUS, Z       ; Check if the result is zero (Score == 1)
    GOTO    StartLevel1     ; If Score == 1, go to StartLevel1
    ; Check if Score > 1
    MOVF    Score, W        ; Load Score into W register
    SUBLW   D'1'            ; Subtract 1 from Score (W = 1 - Score)
    BTFSS   STATUS, C       ; Check if Carry flag is set (Score > 1)
    GOTO    NextLeveL       ; If Score > 1, go to NextLevel
    ; Default case (shouldn't reach here unless something unexpected happens)
		

    GOTO    StartLevel1     ; Default behavior: go to StartLevel1

; Display "Game Over" and restart the game
DisplayGameover:
	CALL ClearDisplay
	MOVLW 0x80 ; Position to first row
	BCF Select, RS ; Command mode
	CALL send
	BSF Select, RS ; Data mode

    MOVLW   'G'
    CALL    send
    MOVLW   'a'
    CALL    send    
    MOVLW   'm'
    CALL    send       
    MOVLW   'e'
    CALL    send   
    MOVLW   ' '
    CALL    send
    MOVLW   'o'
    CALL    send   
    MOVLW   'v'
    CALL    send  
    MOVLW   'e'
    CALL    send   
    MOVLW   'r'
    CALL    send
    ; Wait for 3 seconds
    MOVLW   D'3'
    CALL    xseconds

	MOVLW D'3'
	MOVWF Lives ; give user 3 lives in each reset

    GOTO StartLevel1        ; Restart the game

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DisplayCongratulation:
    CALL ClearDisplay       ; Clear the display
    MOVLW   0x80       ; Position to first row
    BCF     Select, RS ; Command mode
    CALL    send
    BSF     Select, RS ; Data mode
    MOVLW   'C'
    CALL    send
    MOVLW   'o'
    CALL    send    
    MOVLW   'n'
    CALL    send       
    MOVLW   'g'
    CALL    send   
    MOVLW   'r'
    CALL    send
    MOVLW   'a'
    CALL    send   
    MOVLW   't'
    CALL    send  
    MOVLW   'u'
    CALL    send   
    MOVLW   'l'
    CALL    send	
    MOVLW   'a'
    CALL    send     
    MOVLW   'i'
    CALL    send 
    MOVLW   'n'
    CALL    send 
    MOVLW   's'
    CALL    send 
	MOVLW   D'3'
	CALL xseconds
    RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
displayPlay:
    CALL ClearDisplay       ; Clear the display
    MOVLW   0x80       ; Position to first row
    BCF     Select, RS ; Command mode
    CALL    send
    BSF     Select, RS ; Data mode
    MOVLW   'P'
    CALL    send
    MOVLW   'l'
    CALL    send    
    MOVLW   'a'
    CALL    send       
    MOVLW   'y'
    CALL    send   
    RETURN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DisplayTimeover:
	CALL ClearDisplay       ; Clear the display
    MOVLW   0x80       ; Position to first row
    BCF     Select, RS ; Command mode
    CALL    send
    BSF     Select, RS ; Data mode
    MOVLW   'T'
    CALL    send
    MOVLW   'i'
    CALL    send    
    MOVLW   'm'
    CALL    send       
    MOVLW   'e'
    CALL    send   
    MOVLW   ' '
    CALL    send
    MOVLW   'o'
    CALL    send   
    MOVLW   'v'
    CALL    send  
    MOVLW   'e'
    CALL    send   
    MOVLW   'r'
    CALL    send	

	MOVLW   D'3'
	CALL xseconds
    GOTO WaitForButtonPress

DisplayStart:
    MOVLW   0x80       ; Position to first row
    BCF     Select, RS ; Command mode
    CALL    send
    BSF     Select, RS ; Data mode
    MOVLW   ' '
    CALL    send
    MOVLW   'S'
    CALL    send    
    MOVLW   't'
    CALL    send       
    MOVLW   'a'
    CALL    send   
    MOVLW   'r'
    CALL    send 
    MOVLW   't'
    CALL    send 
	RETURN

ClearDisplay:
	MOVLW 0x01 ; Clear display command
	BCF Select, RS ; Command mode
	CALL send
	RETURN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DisplayMessage:
	MOVLW 0x80 ; Position to first row
	BCF Select, RS ; Command mode
	CALL send
	BSF Select, RS ; Data mode
	; First line: "Press any button"
	MOVLW 'P'
	CALL send
	MOVLW 'r'
	CALL send
	MOVLW 'e'
	CALL send
	MOVLW 's'
	CALL send
	MOVLW 's'
	CALL send
	MOVLW ' '
	CALL send
	MOVLW 'a'
	CALL send
	MOVLW 'n'
	CALL send
	MOVLW 'y'
	CALL send
	MOVLW ' '
	CALL send
	MOVLW 'b'
	CALL send
	MOVLW 'u'
	CALL send
	MOVLW 't'
	CALL send
	MOVLW 't'
	CALL send
	MOVLW 'o'
	CALL send
	MOVLW 'n'
	CALL send
	
	MOVLW 0xC0 ; Position to second row
	BCF Select, RS ; Command mode
	CALL send
	BSF Select, RS ; Data mode
	
	; Second line: "to start"
	MOVLW 't'
	CALL send
	MOVLW 'o'
	CALL send
	MOVLW ' '
	CALL send
	MOVLW 's'
	CALL send
	MOVLW 't'
	CALL send
	MOVLW 'a'
	CALL send
	MOVLW 'r'
	CALL send
	MOVLW 't'
	CALL send
	
	RETURN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OneSecondDelay:
    ; Delay for approximately 1 second
    MOVLW 0xA
    MOVWF Index
DelayOuter:
    MOVLW 0x3E8
    MOVWF Current_char
DelayMiddle:
    MOVLW 0x190
    MOVWF Timer
DelayInner:
    NOP
    DECFSZ Timer, F
    GOTO DelayInner
    DECFSZ Current_char, F
    GOTO DelayMiddle
    DECFSZ Index, F
    GOTO DelayOuter
    RETURN
INCLUDE "LCDIS.INC"
END