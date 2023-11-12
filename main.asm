;
; IR LABB.asm
;
; Created: 2023-11-12 16:24:50
; Author : Melker Gustafsson
;


; Initiera systemet
Start:
    ldi r16, 0xFF
    out DDRB, r16          ; Sätt PORTB som utgång
    ldi r16, HIGH(RAMEND)
    out SPH, r16           ; Sätt höga stack pekaren
    ldi r16, LOW(RAMEND)
    out SPL, r16           ; Sätt låga stack pekaren

; Vänta på startbit
WaitForStart:
    sbis PINA, 0
    rjmp WaitForStart

; Läs och bearbeta data
ReadData:
    ldi r16, 4             ; Räknare för databitar

ProcessLoop:
    call Delay
    lsl r20                ; Skifta r20 åt vänster
    sbic PINA, 0
    inc r20                ; Öka r20 om PINA.0 är hög
    dec r16
    brne ProcessLoop

; Skicka ut data
    out PORTB, r20         ; Skicka bearbetade data till PORTB

; Återställ och upprepa
    rjmp Start              ; Upprepa processen

; Fördröjningsrutin
Delay:
sbi PORTB,7    ;bit 7=1  

DelayYttreLoop:
ldi r17, 255

DelayInreLoop:
dec r17
brne DelayInreLoop
dec r16
brne DelayYttreLoop
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
