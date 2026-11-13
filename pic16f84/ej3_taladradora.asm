;==============================================================================
;  EJERCICIO 3 - TALADRADORA AUTOMATICA
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con mordaza abierta (Fc0), broca arriba (Fc2) y pieza (S_Pieza), al pulsar
;  M cierra la mordaza (Q1 hasta Fc1) y baja rapido con el husillo en marcha
;  (Q2 hasta Fc3). Taladrado simple (S_Prof = 0): baja en avance (Q3) hasta
;  Fc4. Profundo (S_Prof = 1): baja hasta Fc4, sube a desahogar (Q4) hasta
;  Fc3 y vuelve a bajar (Q3) hasta Fc5. Al final sube (Q5 hasta Fc2) y abre
;  la mordaza (Q6 hasta Fc0).
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Cerrar mordaza                     acciones: Q1
;     X2  Bajada rapida                      acciones: Q2
;     X3  Taladrado simple                   acciones: Q3
;     X4  Taladrado hasta media carrera      acciones: Q3
;     X5  Desahogo de viruta                 acciones: Q4
;     X6  Taladrado hasta el fondo           acciones: Q3
;     X7  Subir broca                        acciones: Q5
;     X8  Abrir mordaza                      acciones: Q6
;
;     X0 -> X1   si  M * Fc0 * Fc2 * S_Pieza
;     X1 -> X2   si  Fc1
;     X2 -> X3   si  Fc3 * /S_Prof
;     X2 -> X4   si  Fc3 * S_Prof
;     X3 -> X7   si  Fc4
;     X4 -> X5   si  Fc4
;     X5 -> X6   si  Fc3
;     X6 -> X7   si  Fc5
;     X7 -> X8   si  Fc2
;     X8 -> X0   si  Fc0
;
;  CONEXIONES
;     RA0   entrada  M        Pulsador de marcha
;     RA1   entrada  S_Pieza  Pieza colocada
;     RA2   entrada  S_Prof   Selector simple (0) / profundo (1)
;     RA3   entrada  Fc0      Mordaza abierta
;     RA4   entrada  Fc1      Mordaza cerrada
;     RB4   entrada  Fc2      Broca arriba
;     RB5   entrada  Fc3      Broca en aproximacion
;     RB6   entrada  Fc4      Broca a media carrera
;     RB7   entrada  Fc5      Broca en el fondo
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;
;     RB0, RB1, RB2  ->  A, B, C del decodificador 74HC138
;     RB3            ->  G1 del 74HC138 (con resistencia de 10k a masa)
;     G2A y G2B del 74HC138 a masa
;     Solo hay una salida activa en cada etapa: el PIC envia su numero en
;     binario y el 74HC138 activa la salida Y correspondiente (a nivel BAJO):
;         Q1 Cerrar mordaza                 = Y0   (codigo 000)
;         Q2 Husillo y bajada rapida        = Y1   (codigo 001)
;         Q3 Bajada en avance de trabajo    = Y2   (codigo 010)
;         Q4 Subida de desahogo             = Y3   (codigo 011)
;         Q5 Subida de la broca             = Y4   (codigo 100)
;         Q6 Abrir mordaza                  = Y5   (codigo 101)
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
#define S_PIEZA   ENT_A,1    ; RA1
#define S_PROF    ENT_A,2    ; RA2
#define FC0       ENT_A,3    ; RA3
#define FC1       ENT_A,4    ; RA4
#define FC2       ENT_B,4    ; RB4
#define FC3       ENT_B,5    ; RB5
#define FC4       ENT_B,6    ; RB6
#define FC5       ENT_B,7    ; RB7

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
        retlw   b'00001010'         ; X4: Q3  (Y2)
        retlw   b'00001011'         ; X5: Q4  (Y3)
        retlw   b'00001010'         ; X6: Q3  (Y2)
        retlw   b'00001100'         ; X7: Q5  (Y4)
        retlw   b'00001101'         ; X8: Q6  (Y5)

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
        retlw   .0                  ; X3: sin temporizador
        retlw   .0                  ; X4: sin temporizador
        retlw   .0                  ; X5: sin temporizador
        retlw   .0                  ; X6: sin temporizador
        retlw   .0                  ; X7: sin temporizador
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
        ; X0 -> X1 :  M * Fc0 * Fc2 * S_Pieza
        btfss   M                   ; falta M
        goto    Salidas
        btfss   FC0                 ; falta Fc0
        goto    Salidas
        btfss   FC2                 ; falta Fc2
        goto    Salidas
        btfss   S_PIEZA             ; falta S_Pieza
        goto    Salidas
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Cerrar mordaza  (Q1)
Etapa1
        ; X1 -> X2 :  Fc1
        btfss   FC1                 ; falta Fc1
        goto    Salidas
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas

;----- X2  Bajada rapida  (Q2)
Etapa2
        ; X2 -> X3 :  Fc3 * /S_Prof
        btfss   FC3                 ; falta Fc3
        goto    E2_t2
        btfsc   S_PROF              ; falta S_Prof = 0
        goto    E2_t2
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas
E2_t2
        ; X2 -> X4 :  Fc3 * S_Prof
        btfss   FC3                 ; falta Fc3
        goto    Salidas
        btfss   S_PROF              ; falta S_Prof
        goto    Salidas
        movlw   .4
        call    CambiaEtapa         ; activa X4
        goto    Salidas

;----- X3  Taladrado simple  (Q3)
Etapa3
        ; X3 -> X7 :  Fc4
        btfss   FC4                 ; falta Fc4
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X4  Taladrado hasta media carrera  (Q3)
Etapa4
        ; X4 -> X5 :  Fc4
        btfss   FC4                 ; falta Fc4
        goto    Salidas
        movlw   .5
        call    CambiaEtapa         ; activa X5
        goto    Salidas

;----- X5  Desahogo de viruta  (Q4)
Etapa5
        ; X5 -> X6 :  Fc3
        btfss   FC3                 ; falta Fc3
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X6  Taladrado hasta el fondo  (Q3)
Etapa6
        ; X6 -> X7 :  Fc5
        btfss   FC5                 ; falta Fc5
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X7  Subir broca  (Q5)
Etapa7
        ; X7 -> X8 :  Fc2
        btfss   FC2                 ; falta Fc2
        goto    Salidas
        movlw   .8
        call    CambiaEtapa         ; activa X8
        goto    Salidas

;----- X8  Abrir mordaza  (Q6)
Etapa8
        ; X8 -> X0 :  Fc0
        btfss   FC0                 ; falta Fc0
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
        movlw   b'11110000'
        movwf   TRISB               ; PORTB: 1 = entrada, 0 = salida
        movlw   b'10000111'
        movwf   OPTION_REG          ; sin pull-ups; TMR0 reloj interno, prescaler 1:256
        bcf     STATUS,RP0          ; banco 0
        clrf    INTCON              ; sin interrupciones
        movlw   .0
        call    CambiaEtapa         ; etapa inicial X0
        goto    Salidas

        END
