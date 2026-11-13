;==============================================================================
;  EJERCICIO 4 - MONTACARGAS DE 3 PLANTAS
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Con la cabina en planta baja (Fc_P0), una llamada a planta 1 (B_P1) o 2
;  (B_P2) se memoriza y la cabina cierra su puerta (Q1 hasta Fc_PC), sube
;  (Q2) hasta la planta pedida, abre la puerta de esa planta (Q3 o Q4),
;  descarga con la cinta 4 s (Q5), cierra la puerta (Q1) y baja (Q6) hasta
;  Fc_P0.
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Cerrar puerta                      acciones: Q1
;     X2  Subir a planta 1                   acciones: Q2
;     X3  Abrir puerta planta 1              acciones: Q3
;     X4  Subir a planta 2                   acciones: Q2
;     X5  Abrir puerta planta 2              acciones: Q4
;     X6  Descarga (T1 = 4 s)                acciones: Q5
;     X7  Cerrar puerta                      acciones: Q1
;     X8  Bajar a planta 0                   acciones: Q6
;
;     X0 -> X1   si  B_P1 * Fc_P0
;     X0 -> X1   si  B_P2 * Fc_P0
;     X1 -> X2   si  Fc_PC * MEM_P1
;     X1 -> X4   si  Fc_PC * MEM_P2
;     X2 -> X3   si  Fc_P1
;     X3 -> X6   si  Fc_PA1
;     X4 -> X5   si  Fc_P2
;     X5 -> X6   si  Fc_PA2
;     X6 -> X7   si  T (tiempo cumplido)
;     X7 -> X8   si  Fc_PC
;     X8 -> X0   si  Fc_P0
;
;  CONEXIONES
;     RA0   entrada  B_P1     Llamada a planta 1
;     RA1   entrada  B_P2     Llamada a planta 2
;     RA2   entrada  Fc_P0    Cabina en planta 0
;     RA3   entrada  Fc_P1    Cabina en planta 1
;     RA4   entrada  Fc_P2    Cabina en planta 2
;     RB4   entrada  Fc_PC    Puerta de cabina cerrada
;     RB5   entrada  Fc_PA1   Puerta planta 1 abierta
;     RB6   entrada  Fc_PA2   Puerta planta 2 abierta
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;
;     RB0, RB1, RB2  ->  A, B, C del decodificador 74HC138
;     RB3            ->  G1 del 74HC138 (con resistencia de 10k a masa)
;     G2A y G2B del 74HC138 a masa
;     Solo hay una salida activa en cada etapa: el PIC envia su numero en
;     binario y el 74HC138 activa la salida Y correspondiente (a nivel BAJO):
;         Q1 Cerrar puerta de cabina        = Y0   (codigo 000)
;         Q2 Subir                          = Y1   (codigo 001)
;         Q3 Abrir puerta planta 1          = Y2   (codigo 010)
;         Q4 Abrir puerta planta 2          = Y3   (codigo 011)
;         Q5 Cinta de descarga              = Y4   (codigo 100)
;         Q6 Bajar                          = Y5   (codigo 101)
;
;  Entradas activas a nivel ALTO: contacto a +5V y resistencia de 10k a masa.
;  Si una entrada queda al aire, el PIC lee valores al azar.
;==============================================================================

        LIST    P=16F84A
        #include <p16f84a.inc>
        ERRORLEVEL -302             ; quita el aviso de cambio de banco

        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _CP_OFF

;----- Entradas (se leen de las copias ENT_A y ENT_B) -------------------------
#define B_P1      ENT_A,0    ; RA0
#define B_P2      ENT_A,1    ; RA1
#define FC_P0     ENT_A,2    ; RA2
#define FC_P1     ENT_A,3    ; RA3
#define FC_P2     ENT_A,4    ; RA4
#define FC_PC     ENT_B,4    ; RB4
#define FC_PA1    ENT_B,5    ; RB5
#define FC_PA2    ENT_B,6    ; RB6
#define MEM_P1    MEM,0
#define MEM_P2    MEM,1

;----- Variables ----------------------------------------------------------------
        CBLOCK  0x0C
        ETAPA                       ; numero de la etapa activa (0, 1, 2...)
        CONT_T                      ; desbordamientos de TMR0 que faltan (0 = tiempo cumplido)
        ENT_A                       ; copia de PORTA tomada al principio de cada ciclo
        ENT_B                       ; copia de PORTB tomada al principio de cada ciclo
        MEM                         ; memorias internas (como un RS auxiliar)
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
        retlw   b'00001001'         ; X4: Q2  (Y1)
        retlw   b'00001011'         ; X5: Q4  (Y3)
        retlw   b'00001100'         ; X6: Q5  (Y4)
        retlw   b'00001000'         ; X7: Q1  (Y0)
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
        retlw   .61                 ; X6: 4 s  (61 x 65.5 ms = 4.00 s)
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
        ; X0 -> X1 :  B_P1 * Fc_P0
        btfss   B_P1                ; falta B_P1
        goto    E0_t2
        btfss   FC_P0               ; falta Fc_P0
        goto    E0_t2
        bsf     MEM_P1              ; memoriza MEM_P1
        bcf     MEM_P2              ; borra MEM_P2
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas
E0_t2
        ; X0 -> X1 :  B_P2 * Fc_P0
        btfss   B_P2                ; falta B_P2
        goto    Salidas
        btfss   FC_P0               ; falta Fc_P0
        goto    Salidas
        bsf     MEM_P2              ; memoriza MEM_P2
        bcf     MEM_P1              ; borra MEM_P1
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Cerrar puerta  (Q1)
Etapa1
        ; X1 -> X2 :  Fc_PC * MEM_P1
        btfss   FC_PC               ; falta Fc_PC
        goto    E1_t2
        btfss   MEM_P1              ; falta MEM_P1
        goto    E1_t2
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas
E1_t2
        ; X1 -> X4 :  Fc_PC * MEM_P2
        btfss   FC_PC               ; falta Fc_PC
        goto    Salidas
        btfss   MEM_P2              ; falta MEM_P2
        goto    Salidas
        movlw   .4
        call    CambiaEtapa         ; activa X4
        goto    Salidas

;----- X2  Subir a planta 1  (Q2)
Etapa2
        ; X2 -> X3 :  Fc_P1
        btfss   FC_P1               ; falta Fc_P1
        goto    Salidas
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas

;----- X3  Abrir puerta planta 1  (Q3)
Etapa3
        ; X3 -> X6 :  Fc_PA1
        btfss   FC_PA1              ; falta Fc_PA1
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X4  Subir a planta 2  (Q2)
Etapa4
        ; X4 -> X5 :  Fc_P2
        btfss   FC_P2               ; falta Fc_P2
        goto    Salidas
        movlw   .5
        call    CambiaEtapa         ; activa X5
        goto    Salidas

;----- X5  Abrir puerta planta 2  (Q4)
Etapa5
        ; X5 -> X6 :  Fc_PA2
        btfss   FC_PA2              ; falta Fc_PA2
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X6  Descarga (T1 = 4 s)  (Q5)   T = 4 s
Etapa6
        ; X6 -> X7 :  T (tiempo cumplido)
        movf    CONT_T,F            ; tiempo cumplido si CONT_T = 0
        btfss   STATUS,Z
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X7  Cerrar puerta  (Q1)
Etapa7
        ; X7 -> X8 :  Fc_PC
        btfss   FC_PC               ; falta Fc_PC
        goto    Salidas
        movlw   .8
        call    CambiaEtapa         ; activa X8
        goto    Salidas

;----- X8  Bajar a planta 0  (Q6)
Etapa8
        ; X8 -> X0 :  Fc_P0
        btfss   FC_P0               ; falta Fc_P0
        goto    Salidas
        bcf     MEM_P1              ; borra MEM_P1
        bcf     MEM_P2              ; borra MEM_P2
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
        movlw   b'01110000'
        movwf   TRISB               ; PORTB: 1 = entrada, 0 = salida
        movlw   b'10000111'
        movwf   OPTION_REG          ; sin pull-ups; TMR0 reloj interno, prescaler 1:256
        bcf     STATUS,RP0          ; banco 0
        clrf    INTCON              ; sin interrupciones
        clrf    MEM
        movlw   .0
        call    CambiaEtapa         ; etapa inicial X0
        goto    Salidas

        END
