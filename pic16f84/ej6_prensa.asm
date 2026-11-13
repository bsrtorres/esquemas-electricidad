;==============================================================================
;  EJERCICIO 6 - PRENSA NEUMATICA
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con el cilindro recogido (a0), al pulsar M el cilindro sale (Q1 = A+)
;  hasta a1 y vuelve (Q2 = A-) hasta a0.
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Cilindro sale                      acciones: Q1
;     X2  Cilindro vuelve                    acciones: Q2
;
;     X0 -> X1   si  M * a0
;     X1 -> X2   si  a1
;     X2 -> X0   si  a0
;
;  CONEXIONES
;     RA0   entrada  M        Pulsador de marcha
;     RA1   entrada  a0       Cilindro dentro
;     RA2   entrada  a1       Cilindro fuera
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;     RB0   salida   Q1       Cilindro sale (A+)
;     RB1   salida   Q2       Cilindro vuelve (A-)
;     RB4   salida   LED etapa X0
;     RB5   salida   LED etapa X1
;     RB6   salida   LED etapa X2
;
;  Entradas activas a nivel ALTO: contacto a +5V y resistencia de 10k a masa.
;  Si una entrada queda al aire, el PIC lee valores al azar.
;==============================================================================

        LIST    P=16F84A
        #include <p16f84a.inc>
        ERRORLEVEL -302             ; quita el aviso de cambio de banco

        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _CP_OFF

;----- Entradas (se leen de las copias ENT_A y ENT_B) -------------------------
#define M         ENT_A,0    ; RA0
#define A0        ENT_A,1    ; RA1
#define A1        ENT_A,2    ; RA2

;----- Variables ----------------------------------------------------------------
        CBLOCK  0x0C
        ETAPA                       ; numero de la etapa activa (0, 1, 2...)
        CONT_T                      ; desbordamientos de TMR0 que faltan (0 = tiempo cumplido)
        ENT_A                       ; copia de PORTA tomada al principio de cada ciclo
        ENT_B                       ; copia de PORTB tomada al principio de cada ciclo
        ENDC

;==============================================================================
        ORG     0x00
        goto    Inicio

        ORG     0x05
;------------------------------------------------------------------------------
;  TABLA DE SALIDAS: con W = numero de etapa devuelve el valor de PORTB.
;  Es la parte 'acciones' del GRAFCET.
;------------------------------------------------------------------------------
TablaSalidas
        addwf   PCL,F
        retlw   b'00010000'         ; X0: ninguna salida + LED X0
        retlw   b'00100001'         ; X1: Q1 + LED X1
        retlw   b'01000010'         ; X2: Q2 + LED X2

;------------------------------------------------------------------------------
;  TABLA DE TIEMPOS: con W = numero de etapa devuelve los desbordamientos
;  de TMR0 que dura su temporizador (0 = la etapa no tiene).
;  Cada desbordamiento dura 65.536 ms  ->  n = segundos / 0.065536
;------------------------------------------------------------------------------
TablaTiempos
        addwf   PCL,F
        retlw   .0                  ; X0: sin temporizador
        retlw   .0                  ; X1: sin temporizador
        retlw   .0                  ; X2: sin temporizador

;==============================================================================
;  BUCLE PRINCIPAL
;  1. Lee las entradas.  2. Descuenta el temporizador.  3. Salta a la etapa
;  activa, que comprueba sus transiciones.  4. Escribe las salidas.
;  Como un automata: las entradas se leen una vez al principio del ciclo, asi
;  todas las transiciones se evaluan con los mismos valores.
;==============================================================================
Bucle
        movf    PORTA,W             ; lectura de entradas
        movwf   ENT_A
        movf    PORTB,W
        movwf   ENT_B
        call    Temporizador
        movf    ETAPA,W
        addwf   PCL,F               ; salta segun la etapa activa
        goto    Etapa0
        goto    Etapa1
        goto    Etapa2

Salidas
        movf    ETAPA,W
        call    TablaSalidas
        movwf   PORTB               ; todas las salidas de una vez
        goto    Bucle

;==============================================================================
;  ETAPAS: en cada una se comprueban sus transiciones (receptividades).
;  Si una se cumple se activa la etapa siguiente y se desactiva la actual,
;  igual que el Set y el Reset de los bloques RS.
;==============================================================================
;----- X0  Reposo  (sin acciones)
Etapa0
        ; X0 -> X1 :  M * a0
        btfss   M                   ; falta M
        goto    Salidas
        btfss   A0                  ; falta a0
        goto    Salidas
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Cilindro sale  (Q1)
Etapa1
        ; X1 -> X2 :  a1
        btfss   A1                  ; falta a1
        goto    Salidas
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas

;----- X2  Cilindro vuelve  (Q2)
Etapa2
        ; X2 -> X0 :  a0
        btfss   A0                  ; falta a0
        goto    Salidas
        movlw   .0
        call    CambiaEtapa         ; activa X0
        goto    Salidas

;==============================================================================
;  CambiaEtapa: activa la etapa que llega en W y arranca su temporizador
;==============================================================================
CambiaEtapa
        movwf   ETAPA
        call    TablaTiempos        ; W = duracion del temporizador
        movwf   CONT_T
        clrf    TMR0                ; empieza a contar desde cero
        bcf     INTCON,T0IF
        return

;  Temporizador: cada desbordamiento de TMR0 resta 1 a CONT_T hasta llegar a 0
Temporizador
        movf    CONT_T,F
        btfsc   STATUS,Z            ; ya esta a 0: nada que contar
        return
        btfss   INTCON,T0IF         ; ha desbordado TMR0?
        return
        bcf     INTCON,T0IF
        decf    CONT_T,F
        return

;==============================================================================
;  INICIO
;==============================================================================
Inicio
        clrf    PORTB               ; salidas apagadas
        bsf     STATUS,RP0          ; banco 1
        movlw   b'00011111'
        movwf   TRISA               ; PORTA: entradas
        movlw   b'00000000'
        movwf   TRISB               ; PORTB: 1 = entrada, 0 = salida
        movlw   b'10000111'
        movwf   OPTION_REG          ; sin pull-ups; TMR0 reloj interno, prescaler 1:256
        bcf     STATUS,RP0          ; banco 0
        clrf    INTCON              ; sin interrupciones
        movlw   .0
        call    CambiaEtapa         ; etapa inicial X0
        goto    Salidas

        END
