;==============================================================================
;  EJERCICIO 2 - MEZCLADORA Y DOSIFICADORA
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con el deposito vacio (B0) al pulsar M se llena con producto A (Q1 hasta
;  B1) y B (Q2 hasta B2). Con S_Lav = 0 (produccion) agita 5 s (Q3), calienta
;  hasta S_Temp (Q4) y dosifica hasta Fc_Env (Q5). Con S_Lav = 1 (limpieza
;  CIP) inyecta vapor 4 s (Q6) y aclara 3 s (Q7). En ambos casos vacia (Q8)
;  hasta B0.
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Llenado producto A                 acciones: Q1
;     X2  Llenado producto B                 acciones: Q2
;     X3  Agitado (T1 = 5 s)                 acciones: Q3
;     X4  Calentamiento                      acciones: Q4
;     X5  Dosificado                         acciones: Q5
;     X6  Vapor (T2 = 4 s)                   acciones: Q6
;     X7  Aclarado (T3 = 3 s)                acciones: Q7
;     X8  Vaciado                            acciones: Q8
;
;     X0 -> X1   si  M * B0
;     X1 -> X2   si  B1
;     X2 -> X3   si  B2 * /S_Lav
;     X2 -> X6   si  B2 * S_Lav
;     X3 -> X4   si  T (tiempo cumplido)
;     X4 -> X5   si  S_Temp
;     X5 -> X8   si  Fc_Env
;     X6 -> X7   si  T (tiempo cumplido)
;     X7 -> X8   si  T (tiempo cumplido)
;     X8 -> X0   si  B0
;
;  CONEXIONES
;     RA0   entrada  M        Pulsador de marcha
;     RA1   entrada  B0       Nivel: deposito vacio
;     RA2   entrada  B1       Nivel 1
;     RA3   entrada  B2       Nivel 2
;     RA4   entrada  S_Lav    Selector produccion (0) / limpieza (1)
;     RB4   entrada  S_Temp   Termostato: temperatura alcanzada
;     RB5   entrada  Fc_Env   Envase lleno
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;
;     RB0, RB1, RB2  ->  A, B, C del decodificador 74HC138
;     RB3            ->  G1 del 74HC138 (con resistencia de 10k a masa)
;     G2A y G2B del 74HC138 a masa
;     Solo hay una salida activa en cada etapa: el PIC envia su numero en
;     binario y el 74HC138 activa la salida Y correspondiente (a nivel BAJO):
;         Q1 Valvula producto A             = Y0   (codigo 000)
;         Q2 Valvula producto B             = Y1   (codigo 001)
;         Q3 Agitador                       = Y2   (codigo 010)
;         Q4 Calefaccion                    = Y3   (codigo 011)
;         Q5 Dosificador de envase          = Y4   (codigo 100)
;         Q6 Vapor (CIP)                    = Y5   (codigo 101)
;         Q7 Aclarado                       = Y6   (codigo 110)
;         Q8 Vaciado                        = Y7   (codigo 111)
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
#define B0        ENT_A,1    ; RA1
#define B1        ENT_A,2    ; RA2
#define B2        ENT_A,3    ; RA3
#define S_LAV     ENT_A,4    ; RA4
#define S_TEMP    ENT_B,4    ; RB4
#define FC_ENV    ENT_B,5    ; RB5

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
        retlw   b'00000000'         ; X0: ninguna salida
        retlw   b'00001000'         ; X1: Q1  (Y0)
        retlw   b'00001001'         ; X2: Q2  (Y1)
        retlw   b'00001010'         ; X3: Q3  (Y2)
        retlw   b'00001011'         ; X4: Q4  (Y3)
        retlw   b'00001100'         ; X5: Q5  (Y4)
        retlw   b'00001101'         ; X6: Q6  (Y5)
        retlw   b'00001110'         ; X7: Q7  (Y6)
        retlw   b'00001111'         ; X8: Q8  (Y7)

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
        retlw   .76                 ; X3: 5 s  (76 x 65.5 ms = 4.98 s)
        retlw   .0                  ; X4: sin temporizador
        retlw   .0                  ; X5: sin temporizador
        retlw   .61                 ; X6: 4 s  (61 x 65.5 ms = 4.00 s)
        retlw   .46                 ; X7: 3 s  (46 x 65.5 ms = 3.01 s)
        retlw   .0                  ; X8: sin temporizador

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
        goto    Etapa8

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
        ; X0 -> X1 :  M * B0
        btfss   M                   ; falta M
        goto    Salidas
        btfss   B0                  ; falta B0
        goto    Salidas
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Llenado producto A  (Q1)
Etapa1
        ; X1 -> X2 :  B1
        btfss   B1                  ; falta B1
        goto    Salidas
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas

;----- X2  Llenado producto B  (Q2)
Etapa2
        ; X2 -> X3 :  B2 * /S_Lav
        btfss   B2                  ; falta B2
        goto    E2_t2
        btfsc   S_LAV               ; falta S_Lav = 0
        goto    E2_t2
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas
E2_t2
        ; X2 -> X6 :  B2 * S_Lav
        btfss   B2                  ; falta B2
        goto    Salidas
        btfss   S_LAV               ; falta S_Lav
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X3  Agitado (T1 = 5 s)  (Q3)   T = 5 s
Etapa3
        ; X3 -> X4 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .4
        call    CambiaEtapa         ; activa X4
        goto    Salidas

;----- X4  Calentamiento  (Q4)
Etapa4
        ; X4 -> X5 :  S_Temp
        btfss   S_TEMP              ; falta S_Temp
        goto    Salidas
        movlw   .5
        call    CambiaEtapa         ; activa X5
        goto    Salidas

;----- X5  Dosificado  (Q5)
Etapa5
        ; X5 -> X8 :  Fc_Env
        btfss   FC_ENV              ; falta Fc_Env
        goto    Salidas
        movlw   .8
        call    CambiaEtapa         ; activa X8
        goto    Salidas

;----- X6  Vapor (T2 = 4 s)  (Q6)   T = 4 s
Etapa6
        ; X6 -> X7 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X7  Aclarado (T3 = 3 s)  (Q7)   T = 3 s
Etapa7
        ; X7 -> X8 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .8
        call    CambiaEtapa         ; activa X8
        goto    Salidas

;----- X8  Vaciado  (Q8)
Etapa8
        ; X8 -> X0 :  B0
        btfss   B0                  ; falta B0
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
        movlw   b'00110000'
        movwf   TRISB               ; PORTB: 1 = entrada, 0 = salida
        movlw   b'10000111'
        movwf   OPTION_REG          ; sin pull-ups; TMR0 reloj interno, prescaler 1:256
        bcf     STATUS,RP0          ; banco 0
        clrf    INTCON              ; sin interrupciones
        movlw   .0
        call    CambiaEtapa         ; etapa inicial X0
        goto    Salidas

        END
