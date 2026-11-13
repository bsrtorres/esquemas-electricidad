# Especificación de los GRAFCET (fuente única para el código del PIC, las pruebas y la web)
#
# Condiciones de una transición:
#   "Fc1"   entrada a 1          "/S_Lav"  entrada a 0
#   "T"     temporizador de la etapa cumplido
#   "MEM_P1" / "MEM_P2"  bits de memoria interna
#   ("ge","C1",2) / ("lt","C1",2)  comparación del contador
# Acciones al franquear:  ("set",bit) ("clr",bit) ("inc","C1") ("zero","C1")

TICK = 0.065536  # s por desbordamiento de TMR0 (4 MHz, prescaler 1:256)

EJ = []

EJ.append(dict(
    n=1, clave="ej1_clasificadora", titulo="Clasificadora de piezas", web="grafcet/ejercicio1-clasificadora.html",
    modo="138",
    enunciado="Al pulsar M con el carro en Fc0 avanza la cinta (Q1). Una pieza metálica (S_Metal) va por el desviador izquierdo (Q2 hasta Fc1) y su empujador (Q3 hasta Fc2); una de plástico (S_Plast) por el derecho (Q4 hasta Fc3, Q5 hasta Fc4). Después se sella la caja (Q6 hasta Fc5) y el carro vuelve (Q7 hasta Fc0).",
    entradas=[("M","RA0","Pulsador de marcha"),("Fc0","RA1","Carro en origen"),("S_Metal","RA2","Sensor de pieza metálica"),
              ("S_Plast","RA3","Sensor de pieza de plástico"),("Fc1","RA4","Desviador izquierdo abierto"),
              ("Fc2","RB4","Fin empujador izquierdo"),("Fc3","RB5","Desviador derecho abierto"),
              ("Fc4","RB6","Fin empujador derecho"),("Fc5","RB7","Fin de sellado")],
    salidas=[("Q1","Cinta principal"),("Q2","Desviador izquierdo"),("Q3","Empujador izquierdo"),("Q4","Desviador derecho"),
             ("Q5","Empujador derecho"),("Q6","Sellado de caja"),("Q7","Retorno del carro")],
    etapas=[(0,"Reposo",[],0),(1,"Cinta principal",["Q1"],0),(2,"Desviador izquierdo",["Q2"],0),(3,"Desviador derecho",["Q4"],0),
            (4,"Empujador izquierdo",["Q3"],0),(5,"Empujador derecho",["Q5"],0),(6,"Sellado",["Q6"],0),(7,"Retorno del carro",["Q7"],0)],
    trans=[(0,["M","Fc0"],1,[]),(1,["S_Metal"],2,[]),(1,["S_Plast"],3,[]),(2,["Fc1"],4,[]),(3,["Fc3"],5,[]),
           (4,["Fc2"],6,[]),(5,["Fc4"],6,[]),(6,["Fc5"],7,[]),(7,["Fc0"],0,[])],
))

EJ.append(dict(
    n=2, clave="ej2_mezcladora", titulo="Mezcladora y dosificadora", web="grafcet/ejercicio2-mezcladora.html",
    modo="138",
    enunciado="Con el depósito vacío (B0) al pulsar M se llena con producto A (Q1 hasta B1) y B (Q2 hasta B2). Con S_Lav = 0 (producción) agita 5 s (Q3), calienta hasta S_Temp (Q4) y dosifica hasta Fc_Env (Q5). Con S_Lav = 1 (limpieza CIP) inyecta vapor 4 s (Q6) y aclara 3 s (Q7). En ambos casos vacía (Q8) hasta B0.",
    entradas=[("M","RA0","Pulsador de marcha"),("B0","RA1","Nivel: depósito vacío"),("B1","RA2","Nivel 1"),("B2","RA3","Nivel 2"),
              ("S_Lav","RA4","Selector producción (0) / limpieza (1)"),("S_Temp","RB4","Termostato: temperatura alcanzada"),
              ("Fc_Env","RB5","Envase lleno")],
    salidas=[("Q1","Válvula producto A"),("Q2","Válvula producto B"),("Q3","Agitador"),("Q4","Calefacción"),
             ("Q5","Dosificador de envase"),("Q6","Vapor (CIP)"),("Q7","Aclarado"),("Q8","Vaciado")],
    etapas=[(0,"Reposo",[],0),(1,"Llenado producto A",["Q1"],0),(2,"Llenado producto B",["Q2"],0),(3,"Agitado (T1 = 5 s)",["Q3"],5),
            (4,"Calentamiento",["Q4"],0),(5,"Dosificado",["Q5"],0),(6,"Vapor (T2 = 4 s)",["Q6"],4),(7,"Aclarado (T3 = 3 s)",["Q7"],3),
            (8,"Vaciado",["Q8"],0)],
    trans=[(0,["M","B0"],1,[]),(1,["B1"],2,[]),(2,["B2","/S_Lav"],3,[]),(2,["B2","S_Lav"],6,[]),(3,["T"],4,[]),
           (4,["S_Temp"],5,[]),(5,["Fc_Env"],8,[]),(6,["T"],7,[]),(7,["T"],8,[]),(8,["B0"],0,[])],
))

EJ.append(dict(
    n=3, clave="ej3_taladradora", titulo="Taladradora automática", web="grafcet/ejercicio3-taladradora.html",
    modo="138",
    enunciado="Con mordaza abierta (Fc0), broca arriba (Fc2) y pieza (S_Pieza), al pulsar M cierra la mordaza (Q1 hasta Fc1) y baja rápido con el husillo en marcha (Q2 hasta Fc3). Taladrado simple (S_Prof = 0): baja en avance (Q3) hasta Fc4. Profundo (S_Prof = 1): baja hasta Fc4, sube a desahogar (Q4) hasta Fc3 y vuelve a bajar (Q3) hasta Fc5. Al final sube (Q5 hasta Fc2) y abre la mordaza (Q6 hasta Fc0).",
    entradas=[("M","RA0","Pulsador de marcha"),("S_Pieza","RA1","Pieza colocada"),("S_Prof","RA2","Selector simple (0) / profundo (1)"),
              ("Fc0","RA3","Mordaza abierta"),("Fc1","RA4","Mordaza cerrada"),("Fc2","RB4","Broca arriba"),
              ("Fc3","RB5","Broca en aproximación"),("Fc4","RB6","Broca a media carrera"),("Fc5","RB7","Broca en el fondo")],
    salidas=[("Q1","Cerrar mordaza"),("Q2","Husillo y bajada rápida"),("Q3","Bajada en avance de trabajo"),
             ("Q4","Subida de desahogo"),("Q5","Subida de la broca"),("Q6","Abrir mordaza")],
    etapas=[(0,"Reposo",[],0),(1,"Cerrar mordaza",["Q1"],0),(2,"Bajada rápida",["Q2"],0),(3,"Taladrado simple",["Q3"],0),
            (4,"Taladrado hasta media carrera",["Q3"],0),(5,"Desahogo de viruta",["Q4"],0),(6,"Taladrado hasta el fondo",["Q3"],0),
            (7,"Subir broca",["Q5"],0),(8,"Abrir mordaza",["Q6"],0)],
    trans=[(0,["M","Fc0","Fc2","S_Pieza"],1,[]),(1,["Fc1"],2,[]),(2,["Fc3","/S_Prof"],3,[]),(2,["Fc3","S_Prof"],4,[]),
           (3,["Fc4"],7,[]),(4,["Fc4"],5,[]),(5,["Fc3"],6,[]),(6,["Fc5"],7,[]),(7,["Fc2"],8,[]),(8,["Fc0"],0,[])],
))

EJ.append(dict(
    n=4, clave="ej4_montacargas", titulo="Montacargas de 3 plantas", web="grafcet/ejercicio4-montacargas.html",
    modo="138",
    enunciado="Con la cabina en planta baja (Fc_P0), una llamada a planta 1 (B_P1) o 2 (B_P2) se memoriza y la cabina cierra su puerta (Q1 hasta Fc_PC), sube (Q2) hasta la planta pedida, abre la puerta de esa planta (Q3 o Q4), descarga con la cinta 4 s (Q5), cierra la puerta (Q1) y baja (Q6) hasta Fc_P0.",
    entradas=[("B_P1","RA0","Llamada a planta 1"),("B_P2","RA1","Llamada a planta 2"),("Fc_P0","RA2","Cabina en planta 0"),
              ("Fc_P1","RA3","Cabina en planta 1"),("Fc_P2","RA4","Cabina en planta 2"),("Fc_PC","RB4","Puerta de cabina cerrada"),
              ("Fc_PA1","RB5","Puerta planta 1 abierta"),("Fc_PA2","RB6","Puerta planta 2 abierta")],
    salidas=[("Q1","Cerrar puerta de cabina"),("Q2","Subir"),("Q3","Abrir puerta planta 1"),("Q4","Abrir puerta planta 2"),
             ("Q5","Cinta de descarga"),("Q6","Bajar")],
    memoria=["MEM_P1","MEM_P2"],
    etapas=[(0,"Reposo",[],0),(1,"Cerrar puerta",["Q1"],0),(2,"Subir a planta 1",["Q2"],0),(3,"Abrir puerta planta 1",["Q3"],0),
            (4,"Subir a planta 2",["Q2"],0),(5,"Abrir puerta planta 2",["Q4"],0),(6,"Descarga (T1 = 4 s)",["Q5"],4),
            (7,"Cerrar puerta",["Q1"],0),(8,"Bajar a planta 0",["Q6"],0)],
    trans=[(0,["B_P1","Fc_P0"],1,[("set","MEM_P1"),("clr","MEM_P2")]),(0,["B_P2","Fc_P0"],1,[("set","MEM_P2"),("clr","MEM_P1")]),
           (1,["Fc_PC","MEM_P1"],2,[]),(1,["Fc_PC","MEM_P2"],4,[]),(2,["Fc_P1"],3,[]),(3,["Fc_PA1"],6,[]),
           (4,["Fc_P2"],5,[]),(5,["Fc_PA2"],6,[]),(6,["T"],7,[]),(7,["Fc_PC"],8,[]),
           (8,["Fc_P0"],0,[("clr","MEM_P1"),("clr","MEM_P2")])],
))

EJ.append(dict(
    n=5, clave="ej5_tunel_lavado", titulo="Túnel de lavado", web="grafcet/ejercicio5-tunel-lavado.html",
    modo="directo",
    enunciado="Con el puente en origen (Fc_Ini) y el coche colocado (B_Coche), al pulsar M aplica remojo 3 s (Q1). Hace 2 pasadas de cepillos (Q2): avance (Q3) hasta Fc_Fin y retroceso (Q4) hasta Fc_Ini, contando con C1. Después aclara 4 s (Q5), seca 5 s (Q6) y abre la barrera (Q7) hasta que sale el coche.",
    entradas=[("M","RA0","Pulsador de marcha"),("B_Coche","RA1","Coche en posición"),("Fc_Ini","RA2","Puente en origen"),
              ("Fc_Fin","RA3","Puente al final")],
    salidas=[("Q1","Remojo","RB0"),("Q2","Giro de cepillos","RB1"),("Q3","Avance del puente","RB2"),("Q4","Retroceso del puente","RB3"),
             ("Q5","Aclarado","RB4"),("Q6","Secado","RB5"),("Q7","Barrera de salida","RB6")],
    contador="C1",
    etapas=[(0,"Reposo",[],0),(1,"Remojo (T1 = 3 s)",["Q1"],3),(2,"Cepillos: avance",["Q2","Q3"],0),(3,"Cepillos: retroceso",["Q2","Q4"],0),
            (4,"Cuenta pasada (C1 + 1)",[],0),(5,"Aclarado (T2 = 4 s)",["Q5"],4),(6,"Secado (T3 = 5 s)",["Q6"],5),(7,"Barrera abierta",["Q7"],0)],
    trans=[(0,["M","Fc_Ini","B_Coche"],1,[("zero","C1")]),(1,["T"],2,[]),(2,["Fc_Fin"],3,[]),(3,["Fc_Ini"],4,[("inc","C1")]),
           (4,[("lt","C1",2)],2,[]),(4,[("ge","C1",2)],5,[]),(5,["T"],6,[]),(6,["T"],7,[]),(7,["/B_Coche"],0,[])],
))

EJ.append(dict(
    n=6, clave="ej6_prensa", titulo="Prensa neumática", web=None,
    modo="directo",
    enunciado="Con el cilindro recogido (a0), al pulsar M el cilindro sale (Q1 = A+) hasta a1 y vuelve (Q2 = A−) hasta a0.",
    entradas=[("M","RA0","Pulsador de marcha"),("a0","RA1","Cilindro dentro"),("a1","RA2","Cilindro fuera")],
    salidas=[("Q1","Cilindro sale (A+)","RB0"),("Q2","Cilindro vuelve (A−)","RB1")],
    leds={0:"RB4",1:"RB5",2:"RB6"},
    etapas=[(0,"Reposo",[],0),(1,"Cilindro sale",["Q1"],0),(2,"Cilindro vuelve",["Q2"],0)],
    trans=[(0,["M","a0"],1,[]),(1,["a1"],2,[]),(2,["a0"],0,[])],
))

EJ.append(dict(
    n=7, clave="ej7_puerta_garaje", titulo="Puerta de garaje", web=None,
    modo="directo",
    enunciado="Con la puerta cerrada (Fc_C), al pulsar el mando M el motor abre (Q1) hasta Fc_A, espera 5 s (T1) y cierra (Q2) hasta Fc_C.",
    entradas=[("M","RA0","Mando / pulsador"),("Fc_C","RA1","Puerta cerrada"),("Fc_A","RA2","Puerta abierta")],
    salidas=[("Q1","Motor abrir","RB0"),("Q2","Motor cerrar","RB1")],
    leds={0:"RB4",1:"RB5",2:"RB6",3:"RB7"},
    etapas=[(0,"Reposo",[],0),(1,"Abrir",["Q1"],0),(2,"Espera (T1 = 5 s)",[],5),(3,"Cerrar",["Q2"],0)],
    trans=[(0,["M","Fc_C"],1,[]),(1,["Fc_A"],2,[]),(2,["T"],3,[]),(3,["Fc_C"],0,[])],
))


def ticks(seg):
    return round(seg / TICK)


def valor_salida(ej, etapa, escala=1):
    """Valor que se escribe en PORTB en una etapa."""
    _, _, outs, _ = ej["etapas"][etapa]
    if ej["modo"] == "138":
        if not outs:
            return 0
        assert len(outs) == 1
        k = [s[0] for s in ej["salidas"]].index(outs[0])
        return k | 0x08          # A,B,C = n.º de salida - 1 ; G1 (RB3) = 1
    v = 0
    pin = {s[0]: int(s[2][2]) for s in ej["salidas"]}
    for q in outs:
        v |= 1 << pin[q]
    if ej.get("leds") and etapa in ej["leds"]:
        v |= 1 << int(ej["leds"][etapa][2])
    return v


def tris_b(ej):
    v = 0
    for _, p, _ in ej["entradas"]:
        if p.startswith("RB"):
            v |= 1 << int(p[2])
    return v
