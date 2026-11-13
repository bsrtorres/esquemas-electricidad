;==============================================================================
;  EJERCICIO 1 - CLASIFICADORA DE PIEZAS
;  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft
;==============================================================================
;
;  Al pulsar M con el carro en Fc0 avanza la cinta (Q1). Una pieza metalica
;  (S_Metal) va por el desviador izquierdo (Q2 hasta Fc1) y su empujador (Q3
;  hasta Fc2); una de plastico (S_Plast) por el derecho (Q4 hasta Fc3, Q5
;  hasta Fc4). Despues se sella la caja (Q6 hasta Fc5) y el carro vuelve (Q7
;  hasta Fc0).
;
;  GRAFCET
;     X0  Reposo                             acciones: -
;     X1  Cinta principal                    acciones: Q1
;     X2  Desviador izquierdo                acciones: Q2
;     X3  Desviador derecho                  acciones: Q4
;     X4  Empujador izquierdo                acciones: Q3
;     X5  Empujador derecho                  acciones: Q5
;     X6  Sellado                            acciones: Q6
;     X7  Retorno del carro                  acciones: Q7
;
;     X0 -> X1   si  M * Fc0
;     X1 -> X2   si  S_Metal
;     X1 -> X3   si  S_Plast
;     X2 -> X4   si  Fc1
;     X3 -> X5   si  Fc3
;     X4 -> X6   si  Fc2
;     X5 -> X6   si  Fc4
;     X6 -> X7   si  Fc5
;     X7 -> X0   si  Fc0
;
;  CONEXIONES
;     RA0   entrada  M        Pulsador de marcha
;     RA1   entrada  Fc0      Carro en origen
;     RA2   entrada  S_Metal  Sensor de pieza metalica
;     RA3   entrada  S_Plast  Sensor de pieza de plastico
;     RA4   entrada  Fc1      Desviador izquierdo abierto
;     RB4   entrada  Fc2      Fin empujador izquierdo
;     RB5   entrada  Fc3      Desviador derecho abierto
;     RB6   entrada  Fc4      Fin empujador derecho
;     RB7   entrada  Fc5      Fin de sellado
;     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)
;
;     RB0, RB1, RB2  ->  A, B, C del decodificador 74HC138
;     RB3            ->  G1 del 74HC138 (con resistencia de 10k a masa)
;     G2A y G2B del 74HC138 a masa
;     Solo hay una salida activa en cada etapa: el PIC envia su numero en
;     binario y el 74HC138 activa la salida Y correspondiente (a nivel BAJO):
;         Q1 Cinta principal                = Y0   (codigo 000)
;         Q2 Desviador izquierdo            = Y1   (codigo 001)
;         Q3 Empujador izquierdo            = Y2   (codigo 010)
;         Q4 Desviador derecho              = Y3   (codigo 011)
;         Q5 Empujador derecho              = Y4   (codigo 100)
;         Q6 Sellado de caja                = Y5   (codigo 101)
;         Q7 Retorno del carro              = Y6   (codigo 110)
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
#define FC0       ENT_A,1    ; RA1
#define S_METAL   ENT_A,2    ; RA2
#define S_PLAST   ENT_A,3    ; RA3
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
        retlw   b'00001011'         ; X3: Q4  (Y3)
        retlw   b'00001010'         ; X4: Q3  (Y2)
        retlw   b'00001100'         ; X5: Q5  (Y4)
        retlw   b'00001101'         ; X6: Q6  (Y5)
        retlw   b'00001110'         ; X7: Q7  (Y6)

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
        ; X0 -> X1 :  M * Fc0
        btfss   M                   ; falta M
        goto    Salidas
        btfss   FC0                 ; falta Fc0
        goto    Salidas
        movlw   .1
        call    CambiaEtapa         ; activa X1
        goto    Salidas

;----- X1  Cinta principal  (Q1)
Etapa1
        ; X1 -> X2 :  S_Metal
        btfss   S_METAL             ; falta S_Metal
        goto    E1_t2
        movlw   .2
        call    CambiaEtapa         ; activa X2
        goto    Salidas
E1_t2
        ; X1 -> X3 :  S_Plast
        btfss   S_PLAST             ; falta S_Plast
        goto    Salidas
        movlw   .3
        call    CambiaEtapa         ; activa X3
        goto    Salidas

;----- X2  Desviador izquierdo  (Q2)
Etapa2
        ; X2 -> X4 :  Fc1
        btfss   FC1                 ; falta Fc1
        goto    Salidas
        movlw   .4
        call    CambiaEtapa         ; activa X4
        goto    Salidas

;----- X3  Desviador derecho  (Q4)
Etapa3
        ; X3 -> X5 :  Fc3
        btfss   FC3                 ; falta Fc3
        goto    Salidas
        movlw   .5
        call    CambiaEtapa         ; activa X5
        goto    Salidas

;----- X4  Empujador izquierdo  (Q3)
Etapa4
        ; X4 -> X6 :  Fc2
        btfss   FC2                 ; falta Fc2
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X5  Empujador derecho  (Q5)
Etapa5
        ; X5 -> X6 :  Fc4
        btfss   FC4                 ; falta Fc4
        goto    Salidas
        movlw   .6
        call    CambiaEtapa         ; activa X6
        goto    Salidas

;----- X6  Sellado  (Q6)
Etapa6
        ; X6 -> X7 :  Fc5
        btfss   FC5                 ; falta Fc5
        goto    Salidas
        movlw   .7
        call    CambiaEtapa         ; activa X7
        goto    Salidas

;----- X7  Retorno del carro  (Q7)
Etapa7
        ; X7 -> X0 :  Fc0
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
