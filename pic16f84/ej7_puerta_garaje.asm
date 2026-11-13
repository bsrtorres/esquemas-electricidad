;==============================================================================
;  EJERCICIO 7 - PUERTA DE GARAJE
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con la puerta cerrada (Fc_C), al pulsar el mando M el motor abre (Q1)
;  hasta Fc_A, espera 5 s (T1) y cierra (Q2) hasta Fc_C.
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Abrir                              acciones: Q1
;     X2  Espera (T1 = 5 s)                  acciones: -
;     X3  Cerrar                             acciones: Q2
;
;     X0 -> X1   si  M * Fc_C
;     X1 -> X2   si  Fc_A
;     X2 -> X3   si  T (tiempo cumplido)
;     X3 -> X0   si  Fc_C
;
;  CONEXIONES
;     RA0   entrada  M        Mando / pulsador
;     RA1   entrada  Fc_C     Puerta cerrada
;     RA2   entrada  Fc_A     Puerta abierta
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;     RB0   salida   Q1       Motor abrir
;     RB1   salida   Q2       Motor cerrar
;     RB4   salida   LED etapa X0
;     RB5   salida   LED etapa X1
;     RB6   salida   LED etapa X2
;     RB7   salida   LED etapa X3
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
#define FC_C      ENT_A,1    ; RA1
#define FC_A      ENT_A,2    ; RA2

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
        retlw   b'01000000'         ; X2: ninguna salida + LED X2
        retlw   b'10000010'         ; X3: Q2 + LED X3

;------------------------------------------------------------------------------
;  TABLA DE TIEMPOS: con W = numero de etapa devuelve los desbordamientos
;  de TMR0 que dura su temporizador (0 = la etapa no tiene).
;  Cada desbordamiento dura 65.536 ms  ->  n = segundos / 0.065536
;------------------------------------------------------------------------------
TablaTiempos
        addwf   PCL,F
        retlw   .0                  ; X0: sin temporizador
        retlw   .0                  ; X1: sin temporizador
        retlw   .76                 ; X2: 5 s  (76 x 65.5 ms = 4.98 s)
        retlw   .0                  ; X3: sin temporizador

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
        goto    Etapa3

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
        ; X0 -> X1 :  M * Fc_C
        btfss   M                   ; falta M
        goto    Salidas
        btfss   FC_C                ; falta Fc_C
        goto    Salidas
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Abrir  (Q1)
Etapa1
        ; X1 -> X2 :  Fc_A
        btfss   FC_A                ; falta Fc_A
        goto    Salidas
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas

;----- X2  Espera (T1 = 5 s)  (sin acciones)   T = 5 s
Etapa2
        ; X2 -> X3 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas

;----- X3  Cerrar  (Q2)
Etapa3
        ; X3 -> X0 :  Fc_C
        btfss   FC_C                ; falta Fc_C
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
