; Archivo:	LAB06_MICROS.s
; Dispositivo:	PIC16F887
; Autor:	Alba Rodas
; Compilador:	pic-as (v2.35), MPLABX V6.00
;                
; Programa:	con TMR0, se muestran valores en displays, con TMR1 se incrementan los segundos (contador en display y LEDS), con TMR2 enciendo la LED intermitente.
; Hardware:	LED, PIC, RESISTENCIAS, TRANSISTORES PNP.
;    
; Creado:	26-02-2022
; Última modificación: 04-02-2022
    
PROCESSOR 16F887
 #include <xc.inc>
 
 ;CONFIGURATION WORD 1
CONFIG FOSC=INTRC_NOCLKOUT //oscilador interno --> reloj interno..
  CONFIG WDTE=OFF // WDT disables  (reinicia repetitivamente el PIC)
  CONFIG PWRTE=ON // PWRT enabled (se espera 72ms al empezar el funcionamiento)
  CONFIG MCLRE=OFF // El pin MCLR de utiliza como INPUT/OUTPUT
  CONFIG CP=OFF // Sin proteccion de codigo
  CONFIG CPD=OFF // Sin protección de datos
  CONFIG BOREN=OFF //Se desabilita/OFF para que cuando exista una baja de voltaje <4V, no haya reinicio
  CONFIG IESO=OFF // Se establece un reinicio sin cambiar del reloj interno al externo
  CONFIG FCMEN=OFF // Si existiera un fallo, se configura el cambio de reloj de externo a interno
  CONFIG LVP=ON // Se permite el desarrollo de la programacion, incluso en bajo voltaje
 
 ;CONFIGURATION WORD 2
 CONFIG WRT=OFF // Se programa como desactivada la protección de autoescritura 
 CONFIG BOR4V=BOR40V // Se programa reinicio cuando el voltaje sea menor a 4V
 
 reset_tmr0 macro
    banksel PORTA
    movlw   131		; INGRESAMOS UN VALOR DE PRESCALER PARA OBTENER SALTOS DE2ms
    movwf   TMR0	; ALMACENAMOS UN VALOR INICIAL EN EL TMR0
    bcf	    INTCON, 2	; LIMPIAMOS BANDERA DEL OVERFLOW
    endm
 ;N=256-((1000ms)(500kHz)/4*256)
 reset_tmr1 macro
    movlw   0x85	    ; INGRESAMOS VALOR DE 1s, '0x85EE' al TIMER1
    movwf   TMR1H
    movlw   0xEE
    movwf   TMR1L  
    bcf	    TMR1IF	    ; LIMPIAMOS BANDERA DE OVERFLOW
    endm
 
 dividir macro	divisor, cociente, residuo, dividendo
    movwf   dividendo
    clrf    dividendo+1
    incf    dividendo+1
    movlw   divisor
    subwf   dividendo, F
    btfsc   STATUS,0
    goto    $-4
    decf    dividendo+1, w
    movwf   cociente
    movlw   divisor
    addwf   dividendo, w
    movwf   residuo		; HACEMOS DIVISION ENTRE 100
    endm

 PSECT udata_bank0 ; common memory
    dividendo:			DS  3	; TAMAÑO: 1 byte
    segundos:			DS  1	; TAMAÑO: 1 byte
    counter:			DS  1	; TAMAÑO: 1 byte
    cambio:			DS  1	; TAMAÑO: 1 byte
    cociente_display_0:		DS  1	; TAMAÑO: 1 byte
    residuo_display_1:		DS  1	; TAMAÑO: 1 byte
    show_display_0:		DS  1	; TAMAÑO: 1 byte
    show_display_1:		DS  1	; TAMAÑO: 1 byte
    
 PSECT udata_shr  //PSECT udata_shr ; common memory --> udata_shr vista en clase.
    W_TEMP:		DS  1	; TAMAÑO: 1 byte --> 'temporary holding registers'
    STATUS_TEMP:	DS  1	; TAMAÑO: 1 byte --> 'temporary holding registers'
    
 ;------------------RESET--------------------
 PSECT resVect, class=CODE, abs, delta=2
 ORG 00h	; posicion 0000h para vector de reset
 resetVec:
     PAGESEL main
     goto main
     
;-------------VECTOR DE INTERRUPCION--------------     
 PSECT intVect, class=CODE, abs, delta=2
 ORG 04h	; posición 0004h para interrupciones
 
 push:
    movwf	W_TEMP	    ; Copio W al registro 'TEMP' 
    swapf	STATUS, W   ; Swap status, se guarda en W.
    movwf	STATUS_TEMP ; Guardo el STATUS en el banco 00 del STATUS_TEMP register.
   
    // -----------------------------TÉRMINOS USADOS--------------------------  
    // w = 'working register' (accumulador). 
 isr:
    btfsc	TMR1IF		; REVISAMOS BANDERA DE OVERFLOW, SI ESTÁN EN 1, PASO A INT. TIMER1
    call	interrupt_timer1
    btfsc	TMR2IF		; REVISAMOS BANDERA DE OVERFLOW, SI ESTÁN EN 1, PASO A INT. TIMER2
    call	interrupt_timer2
    btfsc	TMR0IF		; REVISAMOS BANDERA DE OVERFLOW, SI ESTÁN EN 1, PASO A INT. TIMER0
    call	interrupt_timer0
    
 pop:
    swapf	STATUS_TEMP, W
    movwf	STATUS		; Muevo W al registro de STATUS --> (Devuelve al banco a su esstado original)
    swapf	W_TEMP, F	; Swap W_TEMP
    swapf	W_TEMP, W	; Swap W_TEMP en W
    retfie			; W HACE 'POP' CUANDO SE LLAMA A UN RETURN, RETLW O UN RETFIE.

    // -----------------------------TÉRMINOS USADOS--------------------------
    // RETFIE = 'Return from interrupt'
    // SWAPF = 'Swap nibbles in f'
    // MOVWF = Move W TO f
    
 ;--------------------- subrutinas de interrupcion ---------------------
 interrupt_timer0:
    reset_tmr0			; REINICIAMOS TRM0 Y LIMPIAMOS BANDERAS
    clrf    PORTD		; LIMPIO LAS SALIDAS DEL DISPLAY
    btfsc   cambio, 0		; HAGO BIT TEST Y SI ESTÁN EN 0, ME VOY A MOSTRAR EL 'DISPLAY 1'
    goto    display_1
 display_0:			; DEFINO EL DISPLAY EN DONDE SE MUESTRAN LAS DECENAS	
    movf    show_display_0, w	; MUEVO EL VALOR A ENSEÑAR EN EL DISPLAY A 'W'
    movwf   PORTC		; PARA ´PODER MOSTRARLO PASO 'W' A 'PORTC'
    bsf	    PORTD,0		; EN '0' ENCIENDO EL DISPLAY
    goto    next_display	; ACTUALIZO EL OTRO DISPLAY, ACTUALIZANDO EL PRIMERO 'UNIDADES/SEGUNDOS'
 display_1:			; 
    movf    show_display_1, w	; MUEVO EL VALOR A MOSTRAR A 'W'
    movwf   PORTC		; MUEVO LO QUE ESTÉ EN 'W' AL 'PORTC'
    bsf	    PORTD,1		; ENCIENDO EL DISPLAY 1
    goto    next_display	; ACTUALIZO EL OTRO DISPLAY, ACTUALIZANDO EL PRIMERO 'UNIDADES/SEGUNDOS'
 next_display:			; INVIERTO EL VALOR DE 'CAMBIO' PARA PODER CAMBIAR DE DISPLAY
    movlw   1
    xorwf   cambio, F		; CAMBIO EL VALOR DE CAMBIO
    return
    
 interrupt_timer1:
    reset_tmr1			; LLAMAMOS AL MACRO
    incf	segundos	; INCREMENTO DE VARIABELS AUXILIARES 'SEGUNDOS'
    return
    
 interrupt_timer2:
    bcf		TMR2IF
    incf	counter		; INCREMENTO MI VARIABLE AUXILIAR
    return
 
 ;-------------------------------------------------------------------------
 PSECT code, delta=2, abs
 ORG 100h			; DEFINO DIRECCION PARA EL CODIGO
;-------------------------------values----------------------------------   
 values:
    clrf    PCLATH
    bsf	    PCLATH, 0	; PCLATH = 01	PCL = 02
    andlw   0x0f
    addwf   PCL		; PC = PCLATH + PCL + w
    retlw   00111111B	; 0
    retlw   00000110B	; 1
    retlw   01011011B	; 2
    retlw   01001111B	; 3
    retlw   01100110B	; 4
    retlw   01101101B	; 5
    retlw   01111101B	; 6
    retlw   00000111B	; 7
    retlw   01111111B	; 8
    retlw   01101111B	; 9
    retlw   01110111B	; A
    retlw   01111100B	; B
    retlw   00111001B	; C
    retlw   01011110B	; D
    retlw   01111001B	; E
    retlw   01110001B	; F

;-------------------------------CODIGO----------------------------------   
;-------------CONFIGURACION------------------
 main:		; LLAMO A TODAS MIS CONFIGURACIONES AL MAIN
    call	config_ins_outs
    call	config_clk
    call	config_tmr0
    call	config_tmr1
    call	config_tmr2
    call	config_int_enable
    banksel	PORTA
    
 ;-------------loop principal-----------------
 loop:
    movf	segundos, w	    ; PASO LA VARIABLE INCREMENTADA AL PORTB
    movwf	PORTB		    ; ESTO, PARA PODER VISULIZAR LOS CAMBIOS QUE ESE INCREMENTO REPRESENTA
    
    movf	counter, w	    ; PASO MI VARIABLE AUMENTADA AL PORTA
    movwf	PORTA		    ; ESTO, PARA PODER VISULIZAR LOS CAMBIOS QUE ESE INCREMENTO REPRESENTA
    
    movf	segundos, w	    ; PASO LO QUE ESTÉ EN 'SEGUNDOS' A 'W'
    movwf	dividendo
    dividir	10, cociente_display_0, residuo_display_1, dividendo	; HAGO LA DIVISION
    call	prep_displays	    ; CONVIERTO UN NÚMERO A VALORES DE DENSIDAD
    
    movlw	60
    subwf	segundos, w
    btfsc	STATUS,2	    ; SI EL RESULTADO ANTERIOR NO ES 0, SALTO
    clrf	segundos	    ; LIMPIO MI VARIABLE SEGUNDOS (REINICIO MIS CONTADORES, DESPUES DE 60 UNIDADES)
    clrw			    ; LIMPIO 'W' PARA INICIAR DESDE CERO
    goto	loop
 
 ;--------------------------CONFIGURACIONES-----------------------------
 ;--------------------------CONFIGURAION DE ENTRADAS Y SALIDAS-------------------------------
 config_ins_outs:	    ; DEFINO QUE PUERTOS SON ENTRADAS Y CUALES SON SALIDAS
    banksel	ANSEL
    clrf	ANSEL
    clrf	ANSELH	    ; DEFINO QUE QUIERO ENTRADAS/SALIDAS DIGITALES
    
    banksel	TRISB
    bcf		TRISA,0	    ; DEFINO EL PORTA CON SALIDA DIGITAL
    
    clrf	TRISB	    ; DEFINO EL PORTB CON SALIDA DIGITAL
    clrf	TRISC	    ; DEFINO EL PORTC CON SALIDA DIGITAL
    
    bcf		TRISD,0
    bcf		TRISD,1	    ; DEFINO EL PORTD CON SALIDA DIGITAL
    
    banksel	PORTB
    bcf		PORTA,0	    ; LIMPIO EL PORTA
    
    clrf	PORTB	    ; LIMPIO EL PORTB
    clrf	PORTC	    ; LIMPIO EL PORTC
    
    bcf		PORTD,0
    bcf		PORTD,1	    ; LIMPIO EL PORTD
    return
 ;--------------------------CONFIGURACION DEL RELOJ-------------------------------
 config_clk:		    ; configurar velocidad de oscilador
    banksel	OSCCON
    bcf		OSCCON, 6
    bsf		OSCCON, 5
    bsf		OSCCON, 4   ; NECESITO UN OSCILADOR 'PEQUEÑO', PARA PODER INCREMENTAR EL VALOR DE PRESCALER Y OBTENER UN DELAY DE 500ms
    bsf		OSCCON, 0   ; ENCIENDO EL RELOJ INTERNO
    return
  ;BIT 4, EN 1 --> BIT MENOS SIGNIFICATIVO. 
  ;BIT 5, EN 1
  ;BIT 6, EN 0
  //USO PINES 4, 5, 6 ya que me permiten configurar la frecuencia de oscilación
   //UTILIZO RELOJ INTERNO CON UNA FRECUENCIA DE 500kHz (011).
 ;--------------------------configuracion tmr0--------------------------------
 config_tmr0:		    ; CONFIGURO INTERRUPCIONES AL TIMER0
    banksel OPTION_REG
    bcf		T0CS	    ; bsf = HABILITAR EL RELOJ INTERNO
    bcf		PSA	    ; HABILITO EL PRESCALER
    bcf		PS2
    bcf		PS1
    bcf		PS0	    ; ELIJO UN PRESCALER DE 1:256
    reset_tmr0
    return
 ;--------------------------configuracion tmr1-------------------------------
 config_tmr1:		    ; CONFIGURO INTERRUPCIONES AL TIMER1
    banksel	T1CON
    bcf		TMR1GE	    ; DEFINO QUE QUIERO QUE EL TIMER1 ESTÉ SIEMPRE CONTANDO
    bsf		T1CKPS1
    bcf		T1CKPS0	    ; ELIJO UN PRESCALER DE 1:4
    bcf		T1OSCEN	    ; APAGO EL OSCILADOR LP
    bcf		TMR1CS	    ; DEFINO EL RELOJ INTERNO
    bsf		TMR1ON	    ; bsf = HABILITAR EL RELOJ INTERNO
    reset_tmr1
    return
 ;--------------------------configuracion tmr2--------------------------------
 config_tmr2:		    ; CONFIGURO INTERRUPCIONES AL TIMER1
    banksel	PORTA
    bsf		TOUTPS3
    bsf		TOUTPS2
    bsf		TOUTPS1
    bsf		TOUTPS0	    ; ELIJO UN PRESCALER DE 1:16
    bsf		TMR2ON	    ; bsf = HABILITAR EL TMR2
    bsf		T2CKPS1
    bsf		T2CKPS0	    ; ELIJO UN PRESCALER DE 16
    
    banksel	TRISA
    movlw	244	    
    movwf	PR2
    clrf	TMR2	    ; LIMPIO EL TIMER2
    bcf		TMR2IF	    ; LIMPIO MIS BANDERAS
    return
 ;------------------------CONFIGURACION DE INTERRUPCIONES---------------------------
 config_int_enable:	    ; HABILITO MIS INTERRUPCIONES AQUI
    banksel	TRISA
    bsf		TMR1IE	    ; ACTIVO INTERRUPCIONES DEL TIMER1
    bsf		TMR2IE	    ; ACTIVO INTERRUPCIONES DEL TIMER2
    banksel	T1CON
    bsf		GIE	    ; HABILITO INTERRUPCIONES GLOBALES --> VITAL PARA PODER TRABAJAR CON INTERRUPCIONES.
    bsf		PEIE	    ; HABILITO LAS INTERRUPCIONES PERIFERICAS
    bsf		T0IE	    ; ACTIVO INTERRUPCIONES DEL TIMER0
    bcf		TMR1IF	    ; LIMPIO BANDERAS DE OVERFLOW DEL TIMER1
    bcf		TMR2IF	    ; LIMPIO BANDERAS DE OVERFLOW DEL TIMER2
    return
 ;------------------------PREPARO LOS DISPLAYS---------------------------
 prep_displays:
    movf	cociente_display_0, w	    ; PASO EL CONCIENTE A 'W'
    call	values			    ; CONVIERTO EL VALOR YA EN 'W', A UN VALOR EN HEX POR MEDIO DE 'VALUES'
    movwf	show_display_0		    ; PASO 'W' EN HEX, A UN REGISTRO EN DONDE SE USARÁN LAS INTERRUPCIONES
    
    movf	residuo_display_1, w	    ; PASO EL RESIDUO A 'W'
    call	values			    ; LLAMO A MI TABLA DE VALORES EN BINARIO 'VALUES'
    movwf	show_display_1		    ; PASO 'W' EN HEX, A UN REGISTRO EN DONDE SE USARÁN LAS INTERRUPCIONES
    return
 END