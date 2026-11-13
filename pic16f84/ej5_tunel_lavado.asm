;==============================================================================
;  EJERCICIO 5 - TUNEL DE LAVADO
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con el puente en origen (Fc_Ini) y el coche colocado (B_Coche), al pulsar
;  M aplica remojo 3 s (Q1). Hace 2 pasadas de cepillos (Q2): avance (Q3)
;  hasta Fc_Fin y retroceso (Q4) hasta Fc_Ini, contando con C1. Despues
;  aclara 4 s (Q5), seca 5 s (Q6) y abre la barrera (Q7) hasta que sale el
;  coche.
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Remojo (T1 = 3 s)                  acciones: Q1
;     X2  Cepillos: avance                   acciones: Q2 + Q3
;     X3  Cepillos: retroceso                acciones: Q2 + Q4
;     X4  Cuenta pasada (C1 + 1)             acciones: -
;     X5  Aclarado (T2 = 4 s)                acciones: Q5
;     X6  Secado (T3 = 5 s)                  acciones: Q6
;     X7  Barrera abierta                    acciones: Q7
;
;     X0 -> X1   si  M * Fc_Ini * B_Coche
;     X1 -> X2   si  T (tiempo cumplido)
;     X2 -> X3   si  Fc_Fin
;     X3 -> X4   si  Fc_Ini
;     X4 -> X2   si  C1 < 2
;     X4 -> X5   si  C1 >= 2
;     X5 -> X6   si  T (tiempo cumplido)
;     X6 -> X7   si  T (tiempo cumplido)
;     X7 -> X0   si  /B_Coche
;
;  CONEXIONES
;     RA0   entrada  M        Pulsador de marcha
;     RA1   entrada  B_Coche  Coche en posicion
;     RA2   entrada  Fc_Ini   Puente en origen
;     RA3   entrada  Fc_Fin   Puente al final
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;     RB0   salida   Q1       Remojo
;     RB1   salida   Q2       Giro de cepillos
;     RB2   salida   Q3       Avance del puente
;     RB3   salida   Q4       Retroceso del puente
;     RB4   salida   Q5       Aclarado
;     RB5   salida   Q6       Secado
;     RB6   salida   Q7       Barrera de salida
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
#define B_COCHE   ENT_A,1    ; RA1
#define FC_INI    ENT_A,2    ; RA2
#define FC_FIN    ENT_A,3    ; RA3

;----- Variables ----------------------------------------------------------------
        CBLOCK  0x0C
        ETAPA                       ; numero de la etapa activa (0, 1, 2...)
        CONT_T                      ; desbordamientos de TMR0 que faltan (0 = tiempo cumplido)
        ENT_A                       ; copia de PORTA tomada al principio de cada ciclo
        ENT_B                       ; copia de PORTB tomada al principio de cada ciclo
        C1                          ; contador de pasadas
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
        retlw   b'00000000'         ; X0: ninguna salida
        retlw   b'00000001'         ; X1: Q1
        retlw   b'00000110'         ; X2: Q2 + Q3
        retlw   b'00001010'         ; X3: Q2 + Q4
        retlw   b'00000000'         ; X4: ninguna salida
        retlw   b'00010000'         ; X5: Q5
        retlw   b'00100000'         ; X6: Q6
        retlw   b'01000000'         ; X7: Q7

;------------------------------------------------------------------------------
;  TABLA DE TIEMPOS: con W = numero de etapa devuelve los desbordamientos
;  de TMR0 que dura su temporizador (0 = la etapa no tiene).
;  Cada desbordamiento dura 65.536 ms  ->  n = segundos / 0.065536
;------------------------------------------------------------------------------
TablaTiempos
        addwf   PCL,F
        retlw   .0                  ; X0: sin temporizador
        retlw   .46                 ; X1: 3 s  (46 x 65.5 ms = 3.01 s)
        retlw   .0                  ; X2: sin temporizador
        retlw   .0                  ; X3: sin temporizador
        retlw   .0                  ; X4: sin temporizador
        retlw   .61                 ; X5: 4 s  (61 x 65.5 ms = 4.00 s)
        retlw   .76                 ; X6: 5 s  (76 x 65.5 ms = 4.98 s)
        retlw   .0                  ; X7: sin temporizador

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
        goto    Etapa4
        goto    Etapa5
        goto    Etapa6
        goto    Etapa7

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
        ; X0 -> X1 :  M * Fc_Ini * B_Coche
        btfss   M                   ; falta M
        goto    Salidas
        btfss   FC_INI              ; falta Fc_Ini
        goto    Salidas
        btfss   B_COCHE             ; falta B_Coche
        goto    Salidas
        clrf    C1                  ; C1 = 0
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Remojo (T1 = 3 s)  (Q1)   T = 3 s
Etapa1
        ; X1 -> X2 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas

;----- X2  Cepillos: avance  (Q2 + Q3)
Etapa2
        ; X2 -> X3 :  Fc_Fin
        btfss   FC_FIN              ; falta Fc_Fin
        goto    Salidas
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas

;----- X3  Cepillos: retroceso  (Q2 + Q4)
Etapa3
        ; X3 -> X4 :  Fc_Ini
        btfss   FC_INI              ; falta Fc_Ini
        goto    Salidas
        incf    C1,F                ; C1 + 1
        movlw   .4
        call    CambiaEtapa         ; activa X4
        goto    Salidas

;----- X4  Cuenta pasada (C1 + 1)  (sin acciones)
Etapa4
        ; X4 -> X2 :  C1 < 2
        movlw   .2
        subwf   C1,W                ; C = 1 si C1 >= 2
        btfsc   STATUS,C
        goto    E4_t2
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas
E4_t2
        ; X4 -> X5 :  C1 >= 2
        movlw   .2
        subwf   C1,W                ; C = 1 si C1 >= 2
        btfss   STATUS,C
        goto    Salidas
        movlw   .5
        call    CambiaEtapa         ; activa X5
        goto    Salidas

;----- X5  Aclarado (T2 = 4 s)  (Q5)   T = 4 s
Etapa5
        ; X5 -> X6 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X6  Secado (T3 = 5 s)  (Q6)   T = 5 s
Etapa6
        ; X6 -> X7 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X7  Barrera abierta  (Q7)
Etapa7
        ; X7 -> X0 :  /B_Coche
        btfsc   B_COCHE             ; falta B_Coche = 0
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
        clrf    C1
        movlw   .0
        call    CambiaEtapa         ; etapa inicial X0
        goto    Salidas

        END
