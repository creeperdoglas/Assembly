;
; Spel.asm
;
; Created: 2023-12-10 10:42:33
; Author : Melker Gustafsson

;TIMER0_INIT och ADC_INIT är initialiseringsrutiner för timer och ADC.
;ISR_TIMER0: En avbrottsrutin som körs vid Timer0-överflöd.
;JOYSTICK, GET_POS, JOY_LIM: Hanterar joystickläsning och rörelsebegränsning.
;MUX, ERASE_VMEM, UPDATE: Hanterar uppdatering av video-minnet och skärmutskrift.
;BEEP, DELAY, DELAY_500: Ljudgenerering och fördröjningsrutiner.
;SETPOS och SETBIT: Används för att uppdatera skärminnehållet baserat på spelarens och målets position.
;POS_LIM: Begränsar rörelsen så att den inte går utanför definierade gränser.
;LIMITS: Använder POS_LIM för att begränsa både X- och Y-koordinater.



	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 7		; AD-prescaler value
	.equ	BEEP_PITCH  = 100	; Victory beep pitch
	.equ	BEEP_LENGTH = 100	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random
	.cseg

.org 0x00
jmp SETUP

.org 0x12
jmp ISR_TIMER0


.org 0x30



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initialisera stackpekaren, portar och funktioner
	; Aktivera avbrott
SETUP: 

	ldi	r16, HIGH(RAMEND)
	out	SPH, r16
	ldi	r16, LOW(RAMEND)
	out	SPL, r16

	ldi r16, 0xFF
	out DDRB, r16

	ldi r16, 0x07
	out DDRD, r16

	call TIMER0_INIT
	call ADC_INIT
	call ERASE_VMEM
	call CLEAR_JOYSTICK
	
	call WARM
	sei
	rjmp MAIN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Rensa joystickdata i minnet
CLEAR_JOYSTICK:
	push ZL
	push ZH

	ldi ZL, LOW(SRAM_START)
	ldi ZH, HIGH(SRAM_START)

CLEAR_JOYSTICK_LOOP:	
	ld r16, Z
	clr r16
	st Z+, r16	
	cpi ZL, LINE
	brne CLEAR_JOYSTICK_LOOP

	pop ZH
	pop ZL

	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Huvudloop: Läs joystick, rensa skärm, uppdatera status
	; Eventuellt anropa fördröjning och ljudsignal (kanske får se när jag testar i labb)
MAIN:
	call JOYSTICK
	call ERASE_VMEM
	call UPDATE
	call DELAY_500
	call CHECK_HIT
	//call BEEP
	rjmp MAIN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Initialisera Timer0 med prescaler 256
TIMER0_INIT:
	ldi r16, (0<<CS02)|(1<<CS01)|(0<<CS00) // Prescaler 256
	out TCCR0, r16	
	in r16, TIMSK
	ori r16, (1<<TOIE0)
	out TIMSK, r16

	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initialisera ADC och vänta på konverteringsklar signal
ADC_INIT:
	
	ldi r16, (0<<REFS1)|(0<<REFS0)|(0<<ADLAR)
	out ADMUX, r16

	ldi r16, (1<< ADEN)|(0<<ADIE)|(0<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	out ADCSRA, r16

	sbi ADCSRA, ADSC
wait:
	sbic ADCSRA, ADSC
	rjmp wait

	in r16, ADCH

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Avbrottsrutin för Timer0
ISR_TIMER0:
	push r16
	in r16,SREG //RÄDDAR FLAGGOR
	push r16

	call MUX
	lds r16, SEED
    inc r16
    sts SEED, r16

	pop r16
	out SREG,r16
	pop r16
	reti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Läs joystick och uppdatera position
JOYSTICK:
	;push r16
	push YH
	push YL

	ldi YH, HIGH(POSX)
	ldi YL, LOW(POSX)
	
	//ldi r16, (AD_CHAN_X<<) KANSKE, tror ej
	cbi ADMUX, MUX0
	call GET_POS
	inc YL
	sbi ADMUX, MUX0
	call GET_POS

	call JOY_LIM
	pop YL
	pop YH
	;pop r16
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Hämta position från ADC och justera om nödvändigt
GET_POS:
	push r16
	ld  r16, Y

	sbi ADCSRA, ADSC
WAIT_FOR_AD:
	sbic ADCSRA, ADSC
	rjmp WAIT_FOR_AD

	in r17, ADCH

	cpi r17, 0x03
	breq INC_POS
	cpi r17, 0x00
	breq DEC_POS
	rjmp DONE_WITH_INPUT
INC_POS:
	inc r16
	rjmp DONE_WITH_INPUT

DEC_POS:
	dec r16

DONE_WITH_INPUT:
	st Y,r16

	pop r16
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Multiplexera display och uppdatera skärmen
MUX:
    push r16
    push ZL
    push ZH
    
    ; Läs nuvarande radnummer
    ldi ZL, LOW(LINE)
    ldi ZH, HIGH(LINE)
    ld r16, Z
    
    ; Rensa PORTB innan vi byter rad för att undvika blödning
    clr r17
    out PORTB, r17

    ; Välj nuvarande rad på PORTD
    out PORTD, r16
    
    ; Ladda motsvarande raddata från VMEM och skriv till PORTB
    ldi ZL, LOW(VMEM)
    ldi ZH, HIGH(VMEM)
    add ZL, r16
    ld r16, Z
    out PORTB, r16

    ; Uppdatera radnumret för nästa avbrott
    ldi ZL, LOW(LINE)
    ldi ZH, HIGH(LINE)
    ld r16, Z
    inc r16
    cpi r16, VMEM_SZ
    brne MUX_DONE
    clr r16

MUX_DONE:
	st Z, r16
	pop ZH
	pop ZL
	pop r16
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CHECK_HIT:
	lds r16, POSX
	lds r17, TPOSX
	cp  r16, r17
	brne NOT_HIT ; Om de inte matchar, hoppa över BEEP

	lds r16, POSY
	lds r17, TPOSY
	cp  r16, r17
	brne NOT_HIT ; Om de inte matchar, hoppa över BEEP

	; Om vi är här, har POSX/POSY matchat TPOSX/TPOSY och vi har en träff
	call BEEP

	
	rjmp setup
	; Här skulle du lägga till kod för att återställa spelet eller göra något annat när en träff detekteras

NOT_HIT:
	; Fortsätt med spelets normala flöde om det inte var en träff
	ret

; --- WARM start. Set up a new game
WARM:
    cli             ; Stäng av avbrott under initialiseringen
    ldi r16, 6      ; Välj längsta till höger position för x (POSX)
    sts POSX, r16
    ldi r16, 2      ; Välj en mittenposition för y (POSY),
    sts POSY, r16
	push r16
	push r16
    call RANDOM     ; Sätt en slumpmässig position för målet
	pop r16
	sts TPOSX, r16
	pop r16
	sts TPOSY, r16
    call ERASE_VMEM ; Rensa videominnet
    sei             ; Aktivera avbrott igen
    ret
; --- RANDOM generate TPOSX, TPOSY in variables passed on stack.
RANDOM:

    in r16, SPH
    mov ZH, r16
    in r16, SPL
    mov ZL, r16

    lds r16, SEED          ; Ladda det inkrementerade värdet av SEED
    inc r16                ; Inkrementera SEED
    sts SEED, r16          ; Spara det inkrementerade värdet tillbaka till SEED
    andi r16, 0x03         ; Använd endast de två lägsta bitarna
    cpi r16, 3             ; Kontrollera om resultatet är 3
    brlo STORE_X           ; Om det är mindre än 3, fortsätt
    dec r16                ; Justera neråt till 2 om det var 3
STORE_X:
  ; sts TPOSX, r16         ; Spara x-koordinaten för målet
  std Z+3, r16
   
    lds r16, SEED          ; Ladda SEED igen
    inc r16                ; Inkrementera SEED igen
    sts SEED, r16          ; Spara det inkrementerade värdet tillbaka till SEED
    andi r16, 0x07         ; Använd de tre lägsta bitarna
    cpi r16, 5            ; Kontrollera om resultatet är 5 eller högre
    brlo STORE_Y           ; Om det är mindre än 5, fortsätt
    subi r16, 5            ; Justera ner till ett värde mellan 0 och 4
STORE_Y:
    ;sts TPOSY, r16         ; Spara y-koordinaten för målet
	
	std Z+4, r16
    ret


ERASE_VMEM:
	push ZL
	push ZH

	ldi ZL, LOW(VMEM)
	ldi ZH, HIGH(VMEM)

ERASE_VMEM_LOOP:	
	ld r16, Z
	clr r16
	st Z+, r16	
	cpi ZL, VMEM+VMEM_SZ
	brne ERASE_VMEM_LOOP



	pop ZH
	pop ZL
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Generera ljudsignal för träff
BEEP:
	ldi		r16,BEEP_LENGTH 
BEEP_LOOP:
	sbi		PORTB, 7
	call	DELAY
	cbi		PORTB, 7
	call	DELAY
	dec		r16
	brne	BEEP_LOOP
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Generell fördröjningsfunktion
DELAY:
	push	r16
	ldi		r16,BEEP_PITCH 
DELAY_LOOP:
	dec		r16
	brne	DELAY_LOOP

	pop		r16
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Specifik fördröjning på 500 millisekunde (var det drog ned fördjröjning så det passade bättre)
DELAY_500:
	ldi  r18, 1.5
    ldi  r19, 138
    ldi  r20, 86
L1: dec  r20
    brne L1
    dec  r19
    brne L1
    dec  r18
    brne L1
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begränsa joystickens rörelser
JOY_LIM:
	call	LIMITS		; don't fall off world!
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17
	; Begränsa koordinater för att inte gå utanför gränserna
LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
	; Uppdatera skärminnehållet med spelarens och målets positioner
	UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
	; Ställ in bitmönster i VMEM baserat på position
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call	SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
	; Ställ in specifik bit baserat på given position
SETBIT:
	ldi	r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret		
