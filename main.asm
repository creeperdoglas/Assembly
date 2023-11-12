;
; Labb1 IR.asm
;
; Created: 2023-11-08 16:06:56
; Author : boren
;

Delay:
sbi PORTB,7    ;bit 7=1  

delayYttreLoop:
ldi r17, 255

delayInreLopp:
dec r17
brne delayInreLoop
dec r16
brne delayYttreLoop
cbi PORTB, 7        ;bit 7=0
ret

DelayHalf:
ldi r16,5
call delay
ret

DelayFull:
ldi r16,10
call delay
ret

