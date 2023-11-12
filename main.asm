;
; IR LABB.asm
;
; Created: 2023-11-12 16:24:50
; Author : Melker Gustafsson
;


; Initiera systemet
Start:
    ldi r16, 0xFF
    out DDRB, r16          ; S�tt PORTB som utg�ng
    ldi r16, HIGH(RAMEND)
    out SPH, r16           ; S�tt h�ga pekaren
    ldi r16, LOW(RAMEND)
    out SPL, r16           ; S�tt l�ga pekaren

; V�nta p� startbit
WaitForStart:
    sbis PINA, 0
    rjmp WaitForStart

; L�s och bearbeta data
ReadData:
    ldi r16, 4             ; R�knare f�r databitar
ProcessLoop:
    call Delay
    lsl r20                ; Skifta r20 �t v�nster
    sbic PINA, 0
    inc r20                ; �ka r20 om PINA.0 �r h�g
    dec r16
    brne ProcessLoop

; Skicka ut data
    out PORTB, r20         ; Skicka bearbetade data till PORTB

; �terst�ll och upprepa
    rjmp Start              ; Upprepa processen

; F�rdr�jningsrutin
Delay:
    
    ret
