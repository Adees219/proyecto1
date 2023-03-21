; Archivo: Generador de funciones.s
; Dispositivo: PIC16F887
; Autor: Anderson Daniel Eduardo Escobar Sandoval
; Compilador: pic-as (v2.4), MPLABX V6.05
; 
; Programa: Generador de funciones
; Hardware: Leds, displays, botones, transistores, resistencias
; 
; Creado: 27 febrero, 2023
; Última modificación: 20 marzo, 2023

processor 16F887
#include <xc.inc>
      
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSC oscillator: CLKOUT function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
  
  
  
  

;------------------------------------------macros------------------------------------------- 
 reinicio_tmr0 macro 
    banksel PORTA
    movf frecuencia, W ;con el valor de la variable frecuencia, lo ingresa en el tmr0 para el retraso
    movwf TMR0
    bcf T0IF		;termina con la interrupcion
endm 
 
    
sel_prescaler macro 
    banksel OPTION_REG
    movf preescalador, W ;con el valor de la variable preescalador, lo ingresa en el option register para seleccionar el preescalador
    movwf OPTION_REG
endm 
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    
    
    
    
;------------------------------------------variables-----------------------------------------------
      
PSECT udata_shr ;variables que se protegen los bits de status 

//variables para interrupcion (push-pop)
W_TEMP: DS 1	    
STATUS_TEMP: DS 1  

//variables para control de frecuencia
ctrlFR: DS 1	    ; contador general (controlador FRecuencia), determina cuando se cambia el prescalador y los valores que devuelve para tmr0 
		    ;para lograr una variacion de 100 Hz entre cada cambio

frecuencia: DS 1    ;valor que ingresa al tmr0
preescalador: DS 1  ;valor que ingresa al PS (prescaler)
    
//variables de interfaz
var: DS 1	    ;contador para el valor los displays
flags: DS 1	    ;selector del multiplexado	
display_var: DS 3   ;valor transformado que se muestra en los displays  
  
    
;variables que guardan el valor para cada display   
CERO: DS 1     ;como el incremento es de 100 en 100 en la frecuencia, significa que podemos tratar al contador en unidades y decenas
		; y colocar dos ceros hasta la derecha
UNIDAD: DS 1	
DECENA: DS 1
    
//variables mapeo ondas
pendiente: DS 1		;determina en la onda triangular si incrementa (pendiente positiva) o si decrementa (pendiente negativa)
nivel_pendiente: DS 1   ; bandera para comprobar si se hace el cambio en la bandera pendiente, lleva la cuenta de la salida mostrada en la onda
			;triangular
mode: DS 1		;cambia el tipo de onda
    
    
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    
    
    
PSECT resVect, class=CODE, abs, delta=2
     
;------------------------vector reset----------------
ORG 00h
resetVec:
    PAGESEL setup 
    goto setup ;rutina de configuracion

 ;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
 
    
PSECT code, delta=2, abs
 
;------------------------------------interrupciones--------------------------------------
 ORG 04h
push:
    movwf W_TEMP ; copia W al registro temporal
    swapf STATUS, W ; intercambio de nibbles y guarda en W
    movwf STATUS_TEMP; guarda status en el registro temporal
 
isr: ; rutina de interrupcion
   
   
   btfsc T0IF	   ;comprueba la bandera de tmr0
   call	generador   ; si hay una interrupcion llama a la subrutina generador
 
      
pop: 
    swapf STATUS_TEMP, W ;intercambio nibbles y guarda en W
    movwf STATUS	 ;mueve W a STATUS
    swapf W_TEMP, F	;intercambio nibbles y guarda en W temporal
    swapf W_TEMP, W	;intervambio nibbles y guarda en W
   
    retfie ;salida de la interrupcion

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    

    
    
;-----------------------------------------------setup------------------------------------------
org 100h
setup:
    call config_io	    ;configuracion de entradas/salidas
    call config_reloj	    ;configuracion de la frecuencia del reloj
    call config_int_enable  ;configuracion de interrupciones
    call config_tmr0	    ;configuracion del tmr0
     
    //condiciones iniciales para onda triangular
    movlw 254
    movwf nivel_pendiente
 ;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++   

 
 
banksel PORTA   
 
;----------------------------------------------LOOP----------------------------------------
loop:
    call seteo_freq	    ;subrutina que determina el valor del TMR0 (256-N) para el tiempo de interrupcion
    call seteo_prescaler    ;subrutina que determina el valor a enviar al prescaler
    movwf preescalador	    ;el valor obtenido se mueve a la variable prescalador para utilizarla luego en la macro
      
    btfss PORTB, 0	    ;verifica si el RB0 devuelve 0 (presionado)
    call change_mode	    ;subrutina que cambia la onda a mostrar (cuadrada-triangular)
    
    btfss PORTB, 1	    ;verifica si el RB1 devuelve 0 (presionado)
    call incr_freq	    ;subrutina que incrementa la variable ctrlFR (controlador FRecuencia)
   
    btfss PORTB, 2	    ;verifica si el RB2 devuelve 0 (presionado)
    call dec_freq	    ;subrutina que decrementa la variable ctrlFR (controlador FRecuencia)
   
    
    movf ctrlFR, W	    ;el valor del ctrlFR lo pasamos al working register para sumarle 1, ya que el caso inicial es de los 100 Hz
    addlw 1
    movwf var		    ;se mueve el valor del working register (ctrlFR + 1) a la variable var    
    
    call conv_decena	    ;se llama a la funcion que separa el valor de var en decenas
    call conv_unidad	    ; realiza lo mismo pero con sus unidades
    
    call valor_displays	    ;subrutina que le asigna el valor individual (decena, unidad, cero) a cada display
       
    ;limpieza de las variables
    CLRF UNIDAD		    ;limpiamos las variables de valor individual para la siguiente vuelta
    CLRF DECENA
    
    goto loop ;reinicio del loop
    
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++    
    
 
    
    
    
;------------------------------------------subrutinas loop---------------------------------------------------
    
    
;~~~~~~~~~~~~~~~configuracion_frecuencia~~~~~~~~~~~~~~~~~ 
 seteo_freq:
    movlw 0x32       ;50 en hexadecimal
    andwf ctrlFR, W  ;AND con ctrlFR (control FRecuencia), resultado se almacena en W
    call tabla_tmr0  ;llama a la tabla que devuelve N
    movwf frecuencia  
return

    
seteo_prescaler:


//logica:
 ;mover el valor del ctrlFR (controlador FRecuencia) a W
 ;restarle N
 ;chequeo del bit borrow en el OPTION REGISTER, skip if cero donde
 ;cero: W>N    uno: W<N
 ;verdadero: retorna valor a cargar en la variable preescalador  
 ;falso: salta a la siguiente comparacion 

 
 //comparador prescaler 128  (caso: 0-2)
movf ctrlFR, W 
sublw 3
btfsc STATUS, 0	    
retlw 0b01010110    
		    

//comparador presacaler 64  (caso: 3-5)
movf ctrlFR, W 
sublw 6
btfsc STATUS, 0 
retlw 0b01010101  
   
//comparador presacaler 32  (caso: 6-8)
movf ctrlFR, W 
sublw 9
btfsc STATUS, 0 
retlw 0b01010100  
    
//comparador presacaler 16  (caso:9-12)
movf ctrlFR, W 
sublw 13
btfsc STATUS, 0 
retlw 0b01010011  

//comparador presacaler 8  (caso:13-15)
movf ctrlFR, W 
sublw 16
btfsc STATUS, 0 
retlw 0b01010010 
   
//comparador presacaler 4  (caso:16-28)
movf ctrlFR, W 
sublw 29
btfsc STATUS, 0 
retlw 0b01010001  
   
//comparador presacaler 2  (caso:29-49)
retlw 0b01010000  

    
    
;~~~~~~~~~~~~~~~~~~~~~~~botones~~~~~~~~~~~~~~~~~~~~~~~
change_mode: //(RB0 = 0)
    btfss PORTB, 0  
    goto $-1
    movlw 0x01
    xorwf mode, F 
    clrf PORTA
return
  
      
incr_freq: //(RB1 = 0)
    btfss PORTB, 1 ; (anti-rebote)comprueba si el boton que llamo a la rutina dejo de ser presionado
    goto $-1	    ;vuelve a la línea anterior
    incf ctrlFR	; incrementa el valor del puerto A 
return	;sale de la subrutina y regresa al loop

    
dec_freq: //(RB2 = 0)
    btfss PORTB, 2 ; (anti-rebote)comprueba si el boton que llamo a la rutina dejo de ser presionado
    goto $-1	    ;vuelve a la línea anterior
    decf ctrlFR	; incrementa el valor del puerto A 
return	;sale de la subrutina y regresa al loop
 
    
    
;~~~~~~~~~~~~~~~~~~~~~~~~~~~interfaz~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
       
 conv_decena:
    movlw 10	    ;W recibe 10
    subwf var, F    ;restamos el valor var con W
    incf DECENA	    ;incremento variable decena
    btfsc STATUS, 0 ;verificación bit borrow
    goto $-4	    ;si carry=1 :vuelve al inicio de la subrutina
    decf DECENA	    ;si carry=0 : decrementa la variable decena (soluciona el overflow)
    movlw 10	    
    addwf var, F    ;restituye el valor de var 
    return
    
 conv_unidad:
    movlw 1	    ;W recibe 1
    subwf var, F    ;restamos el valor var con W
    incf UNIDAD	    ;incremento variable decena
    btfsc STATUS, 0 ;verificación bit borrow
    goto $-4	    ;si carry=1 :vuelve al inicio de la subrutina
    decf UNIDAD	    ;si carry=0 : decrementa la variable decena (soluciona el overflow)
    movlw 1
    addwf var, F    ;restituye el valor de var
    return
    
valor_displays:
    movf CERO, W	;se mueve el valor individual a W
    call tabla		;manda el valor a la subrutina tabla
    movwf display_var	;el valor que retorna la subrutina se almacena en display_var
    
    movf UNIDAD, W
    call tabla
    movwf display_var+1
    
    movf DECENA, W
    call tabla
    movwf display_var+2
    
    return

    
    
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    
 
    
    
   
;-----------------------------------------subrutina interrupción--------------------------------------------------

generador:
    call signal		    ;subrutina que determina la señal a mapear
    call selector_display   ;subrutina encargada del multiplexeado
    sel_prescaler	    ;macro para el valor del prescaler
    reinicio_tmr0	    ;macro para el valor del TMR0 
    return

  
signal:
    ;testeo de la variable mode
    ;1:cuadrada	    ;0:triangular
    btfsc mode,0    
    call cuadrada
    btfss mode,0
    call triangular
    return

cuadrada: 
   comf PORTA ;complemento del puerto 8b0 ? 8b1
   return
    
triangular:
    ;testeo de la variable pendiente
    ;0:incrementa la pendiente ;1:decrementa la pendiente
   btfss pendiente,0 
   call t_inc
   btfsc pendiente,0
   call t_dec
   return

 t_inc:  //triangular incremento
    incf PORTA	    ;incremento del puerto
    movf PORTA, W   ;mueve el valor del puerto a W
    sublw 255	    ;le resta 255
    btfss STATUS, 2 ;si el bit ZERO se enciende indica que el puerto ha llegado a su valor máximo, por lo que tiene que cambiar la pendiente
    goto $+3	    ; si no se enciende el bit ZERO, retorna
   
    //cambio de la variable pendiente
    movlw 0x01	    
    xorwf pendiente, F  

   return
   
t_dec:// triangular decremento
    decf PORTA		    ;decrementa el puerto
    decf nivel_pendiente    ;decrementa la variable nivel pendiente
    btfss STATUS, 2	    ;testeo si la variable ya llego a cero, si el bit ZERO se enciende, indica que llego a su valor minimo, toca cambiar la pendiente
    goto $+5		    ; si no se enciende el bit ZERO, retorna
   
    //reinicio de variable
    movlw 254
    movwf nivel_pendiente
    
    //cambio de la variable pendiente
    movlw 0x01
    xorwf pendiente, F  //cambia bandera

   return

   
selector_display:
    clrf PORTD		;apagar los displays
    
    btfss flags,1	;testea si el bit1 esta encendido, sino: se descarta la combinacion 11
    goto $+3
    btfsc flags, 0	;testea si el bit0 esta encendido, sino: salta a comprobar si la combinacion es la correcta
    goto display_3    //11
    btfsc flags, 1	;testea si el bit1 esta encendido, sino: se descartan las combinaciones 11 y 10
    goto display_2    //10	 
    btfsc flags, 0	;testea si el bit0 esta encendido, sino: descarta la combinacion 01, entra a la 00 por defecto
    goto display_1    //01
    goto display_0    //00
 
    return

;00
display_0:
    movf display_var, W	    ;W recibe el valor del display+1 (una localidad mayor)
    movwf PORTC		    ;recibe el puerto c el valor de W
    bsf PORTD, 0	    ;bit0 del multiplexeado enciende
    bsf flags, 0
    bcf flags, 1	    ;bandera = 01
    return

;01
display_1:  
    movf display_var, W	    ;W recibe el valor del display
    movwf PORTC		    ;recibe el puerto c el valor de W
    bsf PORTD, 1	    ;bit1 del multiplexeado enciende
    bcf flags, 0
    bsf flags, 1	    ; bandera = 10
    return

;10
display_2:
    movf display_var+1, W   ;W recibe el valor del display+2 (una localidad mayor)
    movwf PORTC		    ;recibe el puerto c el valor de W
    bsf PORTD, 2	     ;bit2 del multiplexeado enciende
    bsf flags, 0
    bsf flags, 1	    ;bandera = 11 
    return
    
;11    
display_3: 
    movf display_var+2, W   ;W recibe el valor del display+2 (una localidad mayor)
    movwf PORTC		    ;recibe el puerto c el valor de W
    bsf PORTD, 3	    ;bit3 del multiplexeado enciende
    bcf flags, 0
    bcf flags, 1	    ;bandera = 00 
    return

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++    

    
    
    
;--------------------------------------------subrutinas setup---------------------------------------
 config_io:
    banksel ANSEL
    clrf ANSEL	    
    clrf ANSELH	 ;puerto digitales
    
    banksel TRISA
    clrf TRISA	 ;puerto A ? salida DAC
    clrf TRISC	 ;pierto C ? salida display
    
    ;puerto D ? salidas para multiplexeado
    bcf TRISD, 0
    bcf TRISD, 1
    bcf TRISD, 2
    bcf TRISD, 3
    
    ;config pullup 
    bcf OPTION_REG, 7	;habilita los pull-ups del puerto B
    bsf WPUB0		;pull-ups internos 1: enabled
    bsf WPUB1
   
    
    bsf TRISB, 0  ;boton modo triangular/rectangular
    bsf TRISB, 1  ;boton + frecuencia
    bsf TRISB, 2  ;boton - frecuencia
    bsf TRISB, 3  ;boton modo Hz/KHz
    
   //limpieza 
    banksel PORTA
    clrf PORTA
    clrf PORTB
    clrf PORTC
    clrf PORTD
    clrf frecuencia
    clrf preescalador 
    return
    
    
    
 config_tmr0:
    banksel OPTION_REG
    bcf T0CS	;mode: temporizador
    bcf PSA	;prescaler para temporizador  
    return
    
config_reloj:
    banksel OSCCON
    bsf IRCF2
    bsf IRCF1
    bcf IRCF0	;4MHz
    bsf SCS	;reloj interno
    return
    

config_int_enable:
    bsf GIE	;global interrupt enable
    bsf T0IE	; tmr0 interrupt enable
    bcf T0IF	; bandera interrupcion
    return
    
    
    
;-----------------------------------TABLAS-------------------------------------------------
org 200h 
tabla: 
    CLRF PCLATH
    BcF PCLATH, 0
    BsF PCLATH, 1   ;cambio de pagina
    ANDLW 0X09	    ;restriccion para que no exceda el valor 9
    ADDWF PCL	    ;PCL + PCLATH (W con PCL) PCL adquiere ese nuevo valor y salta a esa linea
    
    ;valores que regresa:
    
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;A
    retlw 01111100B ;B
    retlw 00111001B ;C
    retlw 01011110B ;D
    retlw 01111001B ;E
    retlw 01110001B ;F
    
    
 tabla_tmr0: 
    CLRF PCLATH
    BcF PCLATH, 0
    BsF PCLATH, 1   ;cambio de pagina 
    ANDLW 0X32	    ;restriccion para que no exceda el valor 9
    ADDWF PCL	    ;PCL + PCLATH (W con PCL) PCL adquiere ese nuevo valor y salta a esa linea
    
    ;valores que regresa:
    
    ;prescaler 1:128
    retlw 178 ;100
    retlw 217 ;200
    retlw 230 ;300
    
    ;prescaler 1:64
    retlw 217 ;400
    retlw 225 ;500
    retlw 230 ;600
    
    ;prescaler 1:32
    retlw 212 ;700
    retlw 217 ;800
    retlw 221 ;900
    
    ;prescaler 1:16
    retlw 194 ;1000
    retlw 199 ;1100
    retlw 204 ;1200
    retlw 208 ;1300
    
    ;prescaler 1:8
    retlw 167 ;1400
    retlw 173 ;1500
    retlw 178 ;1600
    
    ;prescaler 1:4
    retlw 109 ;1700
    retlw 117 ;1800
    retlw 125 ;1900
    retlw 131 ;2000
    retlw 137 ;2100
    retlw 142 ;2200
    retlw 147 ;2300
    retlw 152 ;2400
    retlw 156 ;2500
    retlw 160 ;2600
    retlw 163 ;2700
    retlw 167 ;2800
    retlw 170 ;2900
    
    ;prescaler 1:2
    retlw 89 ;3000
    retlw 95 ;3100
    retlw 100 ;3200
    retlw 104 ;3300
    retlw 109 ;3400
    retlw 113 ;3500
    retlw 117 ;3600
    retlw 121 ;3700
    retlw 124 ;3800
    retlw 128 ;3900
    retlw 131 ;4000
    retlw 134 ;4100
    retlw 137 ;4200
    retlw 140 ;4300
    retlw 142 ;4400
    retlw 145 ;4500
    retlw 147 ;4600
    retlw 150 ;4700
    retlw 152 ;4800
    retlw 154 ;4900
    retlw 156 ;5000
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    
END