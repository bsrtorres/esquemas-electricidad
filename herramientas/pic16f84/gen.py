"""Genera el programa en ensamblador (PIC16F84A) de cada GRAFCET de spec.py."""
import sys
from spec import EJ, TICK, ticks, valor_salida, tris_b

W = 8  # sangría


def ins(op, arg="", com=""):
    s = (" " * W + (f"{op:<8}" if len(op) < 8 else op + " ") + arg).rstrip()
    if com:
        s = f"{s:<36}; {com}"
    return s


def cond_txt(c):
    if isinstance(c, tuple):
        return f"{c[1]} {'>=' if c[0] == 'ge' else '<'} {c[2]}"
    if c == "T":
        return "T (tiempo cumplido)"
    return c


def gen(ej, escala=1):
    n_et = len(ej["etapas"])
    entradas = ej["entradas"]
    nombres_in = [e[0] for e in entradas]
    mem = ej.get("memoria", [])
    cnt = ej.get("contador")
    L = []
    a = L.append
    linea = ";" + "=" * 78

    # ---------------- Cabecera ----------------
    a(linea)
    a(f";  EJERCICIO {ej['n']} - {ej['titulo'].upper()}")
    a(";  GRAFCET para PIC16F84A (cristal de 4 MHz), traducido de los bloques RS de LOGO!Soft")
    a(linea)
    a(";")
    for chunk in _wrap(ej["enunciado"], 74):
        a(";  " + chunk)
    a(";")
    a(";  GRAFCET")
    for e, txt, outs, t in ej["etapas"]:
        acc = " + ".join(outs) if outs else "-"
        a(f";     X{e}  {txt:<34} acciones: {acc}")
    a(";")
    for f, cs, to, _ in ej["trans"]:
        a(f";     X{f} -> X{to}   si  " + " * ".join(cond_txt(c) for c in cs))
    a(";")
    a(";  CONEXIONES")
    for nom, p, d in entradas:
        a(f";     {p:<5} entrada  {nom:<8} {d}")
    a(";     MCLR  RESET    pulsador a masa y resistencia de 10k a +5V (vuelve a X0)")
    if ej["modo"] == "138":
        a(";")
        a(";     RB0, RB1, RB2  ->  A, B, C del decodificador 74HC138")
        a(";     RB3            ->  G1 del 74HC138 (con resistencia de 10k a masa)")
        a(";     G2A y G2B del 74HC138 a masa")
        a(";     Solo hay una salida activa en cada etapa: el PIC envia su numero en")
        a(";     binario y el 74HC138 activa la salida Y correspondiente (a nivel BAJO):")
        for k, (q, d) in enumerate(ej["salidas"]):
            a(f";         {q} {d:<30} = Y{k}   (codigo {k:03b})")
    else:
        for s in ej["salidas"]:
            a(f";     {s[2]:<5} salida   {s[0]:<8} {s[1]}")
        for e, p in sorted(ej.get("leds", {}).items()):
            a(f";     {p:<5} salida   LED etapa X{e}")
    a(";")
    a(";  Entradas activas a nivel ALTO: contacto a +5V y resistencia de 10k a masa.")
    a(";  Si una entrada queda al aire, el PIC lee valores al azar.")
    a(linea)
    a("")
    a(ins("LIST", "P=16F84A"))
    a(ins("#include", "<p16f84a.inc>"))
    a(ins("ERRORLEVEL", "-302", "quita el aviso de cambio de banco"))
    a("")
    a(ins("__CONFIG", "_XT_OSC & _WDT_OFF & _PWRTE_ON & _CP_OFF"))
    a("")
    a(";----- Entradas (se leen de las copias ENT_A y ENT_B) -------------------------")
    for nom, p, d in entradas:
        port = "ENT_A" if p.startswith("RA") else "ENT_B"
        a(f"#define {nom.upper():<10}{port},{p[2]}" + f"{'':<4}; {p}")
    for k, m in enumerate(mem):
        a(f"#define {m:<10}MEM,{k}")
    a("")
    a(";----- Variables ----------------------------------------------------------------")
    a(ins("CBLOCK", "0x0C"))
    a(ins("ETAPA", "", "numero de la etapa activa (0, 1, 2...)"))
    a(ins("CONT_T", "", "desbordamientos de TMR0 que faltan (0 = tiempo cumplido)"))
    a(ins("ENT_A", "", "copia de PORTA tomada al principio de cada ciclo"))
    a(ins("ENT_B", "", "copia de PORTB tomada al principio de cada ciclo"))
    if mem:
        a(ins("MEM", "", "memorias internas (como un RS auxiliar)"))
    if cnt:
        a(ins(cnt, "", "contador de pasadas"))
    a(ins("ENDC"))
    a("")
    a(linea)
    a(ins("ORG", "0x00"))
    a(ins("goto", "Inicio"))
    a("")
    a(ins("ORG", "0x05"))
    a(";------------------------------------------------------------------------------")
    a(";  TABLA DE SALIDAS: con W = numero de etapa devuelve el valor de PORTB.")
    a(";  Es la parte 'acciones' del GRAFCET.")
    a(";------------------------------------------------------------------------------")
    a("TablaSalidas")
    a(ins("addwf", "PCL,F"))
    for e, txt, outs, t in ej["etapas"]:
        v = valor_salida(ej, e)
        if ej["modo"] == "138":
            com = f"X{e}: " + (f"{outs[0]}  (Y{[s[0] for s in ej['salidas']].index(outs[0])})" if outs else "ninguna salida")
        else:
            com = f"X{e}: " + (" + ".join(outs) if outs else "ninguna salida")
            if ej.get("leds") and e in ej["leds"]:
                com += f" + LED X{e}"
        a(ins("retlw", f"b'{v:08b}'", com))
    a("")
    a(";------------------------------------------------------------------------------")
    a(";  TABLA DE TIEMPOS: con W = numero de etapa devuelve los desbordamientos")
    a(f";  de TMR0 que dura su temporizador (0 = la etapa no tiene).")
    a(f";  Cada desbordamiento dura {TICK*1000:.3f} ms  ->  n = segundos / {TICK}")
    a(";------------------------------------------------------------------------------")
    a("TablaTiempos")
    a(ins("addwf", "PCL,F"))
    for e, txt, outs, t in ej["etapas"]:
        n = max(1, ticks(t) // escala) if t else 0
        com = f"X{e}: " + (f"{t} s  ({ticks(t)} x {TICK*1000:.1f} ms = {ticks(t)*TICK:.2f} s)" if t else "sin temporizador")
        a(ins("retlw", f".{n}", com))
    a("")
    a(linea)
    a(";  BUCLE PRINCIPAL")
    a(";  1. Lee las entradas.  2. Descuenta el temporizador.  3. Salta a la etapa")
    a(";  activa, que comprueba sus transiciones.  4. Escribe las salidas.")
    a(";  Como un autómata: las entradas se leen una vez al principio del ciclo, asi")
    a(";  todas las transiciones se evaluan con los mismos valores.")
    a(linea)
    a("Bucle")
    a(ins("movf", "PORTA,W", "lectura de entradas"))
    a(ins("movwf", "ENT_A"))
    a(ins("movf", "PORTB,W"))
    a(ins("movwf", "ENT_B"))
    a(ins("call", "Temporizador"))
    a(ins("movf", "ETAPA,W"))
    a(ins("addwf", "PCL,F", "salta segun la etapa activa"))
    for e in range(n_et):
        a(ins("goto", f"Etapa{e}"))
    a("")
    a("Salidas")
    a(ins("movf", "ETAPA,W"))
    a(ins("call", "TablaSalidas"))
    a(ins("movwf", "PORTB", "todas las salidas de una vez"))
    a(ins("goto", "Bucle"))
    a("")
    a(linea)
    a(";  ETAPAS: en cada una se comprueban sus transiciones (receptividades).")
    a(";  Si una se cumple se activa la etapa siguiente y se desactiva la actual,")
    a(";  igual que el Set y el Reset de los bloques RS.")
    a(linea)
    for e, txt, outs, t in ej["etapas"]:
        acc = " + ".join(outs) if outs else "sin acciones"
        tt = f"   T = {t} s" if t else ""
        a(f";----- X{e}  {txt}  ({acc}){tt}")
        a(f"Etapa{e}")
        trs = [tr for tr in ej["trans"] if tr[0] == e]
        for k, (f, cs, to, acts) in enumerate(trs):
            fallo = f"E{e}_t{k+2}" if k + 1 < len(trs) else "Salidas"
            a(" " * W + f"; X{e} -> X{to} :  " + " * ".join(cond_txt(c) for c in cs))
            for c in cs:
                if isinstance(c, tuple):
                    op, var, val = c
                    a(ins("movlw", f".{val}"))
                    a(ins("subwf", f"{var},W", f"C = 1 si {var} >= {val}"))
                    a(ins("btfss" if op == "ge" else "btfsc", "STATUS,C"))
                    a(ins("goto", fallo))
                elif c == "T":
                    a(ins("movf", "CONT_T,F", "tiempo cumplido si CONT_T = 0"))
                    a(ins("btfss", "STATUS,Z"))
                    a(ins("goto", fallo))
                else:
                    neg = c.startswith("/")
                    nom = c.lstrip("/")
                    sym = nom if nom in mem else nom.upper()
                    a(ins("btfsc" if neg else "btfss", sym, f"{'falta ' + nom + ' = 0' if neg else 'falta ' + nom}"))
                    a(ins("goto", fallo))
            for act in acts:
                if act[0] == "set":
                    a(ins("bsf", act[1], f"memoriza {act[1]}"))
                elif act[0] == "clr":
                    a(ins("bcf", act[1], f"borra {act[1]}"))
                elif act[0] == "inc":
                    a(ins("incf", f"{act[1]},F", f"{act[1]} + 1"))
                elif act[0] == "zero":
                    a(ins("clrf", act[1], f"{act[1]} = 0"))
            a(ins("movlw", f".{to}"))
            a(ins("call", "CambiaEtapa", f"activa X{to}"))
            a(ins("goto", "Salidas"))
            if k + 1 < len(trs):
                a(f"E{e}_t{k+2}")
        a("")
    a(linea)
    a(";  CambiaEtapa: activa la etapa que llega en W y arranca su temporizador")
    a(linea)
    a("CambiaEtapa")
    a(ins("movwf", "ETAPA"))
    a(ins("call", "TablaTiempos", "W = duracion del temporizador"))
    a(ins("movwf", "CONT_T"))
    a(ins("clrf", "TMR0", "empieza a contar desde cero"))
    a(ins("bcf", "INTCON,T0IF"))
    a(ins("return"))
    a("")
    a(";  Temporizador: cada desbordamiento de TMR0 resta 1 a CONT_T hasta llegar a 0")
    a("Temporizador")
    a(ins("movf", "CONT_T,F"))
    a(ins("btfsc", "STATUS,Z", "ya esta a 0: nada que contar"))
    a(ins("return"))
    a(ins("btfss", "INTCON,T0IF", "ha desbordado TMR0?"))
    a(ins("return"))
    a(ins("bcf", "INTCON,T0IF"))
    a(ins("decf", "CONT_T,F"))
    a(ins("return"))
    a("")
    a(linea)
    a(";  INICIO")
    a(linea)
    a("Inicio")
    a(ins("clrf", "PORTB", "salidas apagadas"))
    a(ins("bsf", "STATUS,RP0", "banco 1"))
    a(ins("movlw", "b'00011111'"))
    a(ins("movwf", "TRISA", "PORTA: entradas"))
    tb = tris_b(ej)
    a(ins("movlw", f"b'{tb:08b}'"))
    a(ins("movwf", "TRISB", "PORTB: 1 = entrada, 0 = salida"))
    a(ins("movlw", "b'10000111'"))
    a(ins("movwf", "OPTION_REG", "sin pull-ups; TMR0 reloj interno, prescaler 1:256"))
    a(ins("bcf", "STATUS,RP0", "banco 0"))
    a(ins("clrf", "INTCON", "sin interrupciones"))
    if mem:
        a(ins("clrf", "MEM"))
    if cnt:
        a(ins("clrf", cnt))
    a(ins("movlw", ".0"))
    a(ins("call", "CambiaEtapa", "etapa inicial X0"))
    a(ins("goto", "Salidas"))
    a("")
    a(ins("END"))
    return "\n".join(L) + "\n"


def ascii_txt(t):
    """MPASM trabaja mejor sin acentos: se pasa todo a ASCII."""
    import unicodedata
    t = t.replace("\u2212", "-").replace("\u2192", "->")
    return unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode()


def _wrap(t, w):
    out, cur = [], ""
    for word in t.split():
        if len(cur) + len(word) + 1 > w:
            out.append(cur)
            cur = word
        else:
            cur = (cur + " " + word).strip()
    if cur:
        out.append(cur)
    return out


if __name__ == "__main__":
    import os
    dst = sys.argv[1]
    escala = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    os.makedirs(dst, exist_ok=True)
    for ej in EJ:
        open(os.path.join(dst, ej["clave"] + ".asm"), "w", encoding="ascii", newline="\r\n").write(ascii_txt(gen(ej, escala)))
