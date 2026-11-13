"""Simulador de PIC16F84A (instrucciones de rango medio) + pruebas de cada GRAFCET
contra un modelo del GRAFCET escrito a partir de spec.py."""
import random, sys, subprocess, os, tempfile
from spec import EJ, TICK, ticks, valor_salida
from gen import gen, ascii_txt


class PIC:
    def __init__(self, hexfile):
        self.prog = {}
        for l in open(hexfile):
            l = l.strip()
            n, a, t = int(l[1:3], 16), int(l[3:7], 16), int(l[7:9], 16)
            if t:
                continue
            for i in range(0, n, 2):
                self.prog[(a + i) // 2] = int(l[9+2*i:11+2*i], 16) | int(l[11+2*i:13+2*i], 16) << 8
        self.ram = [0] * 256
        self.ram[0x81] = 0xFF
        self.ram[0x85] = 0x1F
        self.ram[0x86] = 0xFF
        self.W = 0; self.pc = 0; self.cyc = 0; self.pre = 0; self.stack = []
        self.pa = 0; self.pb = 0  # niveles externos en los pines de entrada
        self.bucle = getattr(PIC, "bucle_global", None)

    def a(self, f):
        if f == 0:
            f = self.ram[4]
        if self.ram[3] & 0x20 and f in (1, 5, 6, 8, 9):
            return f | 0x80
        return f if f >= 0x0C or f in (1, 5, 6, 8, 9) else (f & 0x7F)

    def rd(self, f):
        f = self.a(f)
        if f == 5:
            tr = self.ram[0x85]
            return (self.pa & tr) | (self.ram[5] & ~tr & 0x1F)
        if f == 6:
            tr = self.ram[0x86]
            return (self.pb & tr) | (self.ram[6] & ~tr & 0xFF)
        if f == 2:
            return self.pc & 0xFF
        return self.ram[f]

    def wr(self, f, v):
        f = self.a(f); v &= 0xFF
        if f == 2:
            self.pc = (self.ram[0x0A] << 8 | v) & 0x3FF
            self.jumped = True
            return
        if f == 1:
            self.pre = 0
        if f in (3, 0x0A, 0x0B):
            self.ram[f] = v; self.ram[f ^ 0x80 if f < 0x80 else f] = v
            self.ram[f | 0x80] = v
            return
        self.ram[f] = v

    def z(self, v):
        self.ram[3] = (self.ram[3] & ~4) | (4 if (v & 0xFF) == 0 else 0)
        self.ram[0x83] = self.ram[3]

    def setc(self, c):
        self.ram[3] = (self.ram[3] & ~1) | (1 if c else 0)
        self.ram[0x83] = self.ram[3]

    def tick(self, n):
        self.cyc += n; self.pre += n
        while self.pre >= 256:
            self.pre -= 256
            self.ram[1] = (self.ram[1] + 1) & 0xFF
            if self.ram[1] == 0:
                self.ram[0x0B] |= 4; self.ram[0x8B] = self.ram[0x0B]

    def step(self):
        op = self.prog[self.pc]; self.pc += 1; self.jumped = False
        f = op & 0x7F; d = op >> 7 & 1; b = op >> 7 & 7; n = 1
        top6 = op >> 8
        def res(v, flagz=True):
            if flagz: self.z(v)
            if d: self.wr(f, v)
            else: self.W = v & 0xFF
        if op >> 11 == 5:      # goto
            self.pc = op & 0x7FF; n = 2
        elif op >> 11 == 4:    # call
            self.stack.append(self.pc); self.pc = op & 0x7FF; n = 2
            assert len(self.stack) <= 8, "desbordamiento de pila"
        elif op == 0x0008:     # return
            self.pc = self.stack.pop(); n = 2
        elif op >> 10 == 0xD:  # retlw
            self.W = op & 0xFF; self.pc = self.stack.pop(); n = 2
        elif op >> 10 == 0xC:  # movlw
            self.W = op & 0xFF
        elif op >> 10 == 4: self.wr(f, self.rd(f) & ~(1 << b))
        elif op >> 10 == 5: self.wr(f, self.rd(f) | (1 << b))
        elif op >> 10 == 6:
            if not self.rd(f) >> b & 1: self.pc += 1; n = 2
        elif op >> 10 == 7:
            if self.rd(f) >> b & 1: self.pc += 1; n = 2
        elif top6 == 0 and d: self.wr(f, self.W)           # movwf
        elif top6 == 0 and op == 0: pass                     # nop
        elif top6 == 1 and d: self.wr(f, 0); self.z(0)      # clrf
        elif top6 == 8: res(self.rd(f))                      # movf
        elif top6 == 0x0E:                                   # swapf
            v = self.rd(f); res((v << 4 | v >> 4) & 0xFF, False)
        elif top6 == 0x0A: res(self.rd(f) + 1)               # incf
        elif top6 == 0x03: res(self.rd(f) - 1)               # decf
        elif top6 == 0x07:                                   # addwf
            s = self.rd(f) + self.W; self.setc(s > 255); res(s)
        elif top6 == 0x02:                                   # subwf
            s = self.rd(f) - self.W; self.setc(s >= 0); res(s)
        elif top6 == 0x0B:                                   # decfsz
            v = (self.rd(f) - 1) & 0xFF; res(v, False)
            if v == 0: self.pc += 1; n = 2
        else:
            raise SystemExit("opcode no soportado %04x en %03x" % (op, self.pc - 1))
        if self.jumped: n = 2
        self.tick(n)

    def run_us(self, us):
        end = self.cyc + us
        while self.cyc < end:
            self.step()

    def set_in(self, ej, vals):
        # las entradas cambian justo al empezar un ciclo (antes de leerlas)
        if getattr(self, "bucle", None) is not None:
            while self.pc != self.bucle:
                self.step()
        self.pa = 0; self.pb = 0
        for nom, p, _ in ej["entradas"]:
            if vals[nom]:
                if p.startswith("RA"): self.pa |= 1 << int(p[2])
                else: self.pb |= 1 << int(p[2])


class Modelo:
    def __init__(self, ej):
        self.ej = ej; self.x = 0; self.mem = {m: 0 for m in ej.get("memoria", [])}
        self.c = 0; self.t_ok = False

    def cumple(self, cs, vals):
        for c in cs:
            if isinstance(c, tuple):
                ok = self.c >= c[2] if c[0] == "ge" else self.c < c[2]
            elif c == "T": ok = self.t_ok
            elif c.startswith("/"): ok = not vals[c[1:]]
            elif c in self.mem: ok = bool(self.mem[c])
            else: ok = bool(vals[c])
            if not ok: return False
        return True

    def evoluciona(self, vals):
        for _ in range(20):
            for f, cs, to, acts in self.ej["trans"]:
                if f == self.x and self.cumple(cs, vals):
                    for act in acts:
                        if act[0] == "set": self.mem[act[1]] = 1
                        elif act[0] == "clr": self.mem[act[1]] = 0
                        elif act[0] == "inc": self.c += 1
                        elif act[0] == "zero": self.c = 0
                    self.x = to; self.t_ok = False
                    break
            else:
                return
        raise AssertionError("bucle infinito en el modelo")


def build(ej, escala, d):
    asm = os.path.join(d, ej["clave"] + ".asm")
    open(asm, "w").write(ascii_txt(gen(ej, escala)))
    subprocess.run(["gpasm", "-q", asm], cwd=d, check=True)
    import re
    for l in open(asm[:-4] + ".lst", encoding="latin-1"):
        m = re.match(r"^([0-9A-F]{4})\s+[0-9A-F]{4}\s+\d+\s+movf\s+PORTA,W", l)
        if m: PIC.bucle_global = int(m.group(1), 16)
    return asm[:-4] + ".hex"


def prueba(ej, iters=2000, semilla=1):
    rnd = random.Random(semilla)
    ESC = 16
    d = tempfile.mkdtemp()
    pic = PIC(build(ej, ESC, d)); m = Modelo(ej)
    noms = [e[0] for e in ej["entradas"]]
    vals = {k: 0 for k in noms}
    pic.set_in(ej, vals); pic.run_us(2000)
    visit = set(); trans_hechas = set()
    def comprobar(txt):
        assert pic.ram[0x0C] == m.x, f"{txt}: PIC en X{pic.ram[0x0C]}, modelo en X{m.x}"
        esperado = valor_salida(ej, m.x)
        assert pic.ram[6] == esperado, f"{txt}: PORTB={pic.ram[6]:08b} esperado {esperado:08b} en X{m.x}"
    comprobar("inicio")
    for it in range(iters):
        visit.add(m.x)
        posibles = [tr for tr in ej["trans"] if tr[0] == m.x]
        modo = rnd.random()
        if modo < 0.5:
            vals = {k: rnd.random() < 0.3 for k in noms}          # entradas al azar
        else:
            tr = rnd.choice(posibles)                               # forzar una transicion
            vals = {k: rnd.random() < 0.3 for k in noms}
            for c in tr[1]:
                if isinstance(c, str) and c != "T" and c not in m.mem:
                    vals[c.lstrip("/")] = not c.startswith("/")
        import copy
        prob = copy.deepcopy(m)
        try:
            prob.evoluciona(vals)
        except AssertionError:
            continue          # con estas entradas el GRAFCET daria vueltas sin parar
        x_antes = m.x
        t_et = ej["etapas"][m.x][3]
        if t_et and any("T" in tr[1] for tr in posibles):
            n = max(1, ticks(t_et) // ESC)
            pic.set_in(ej, vals); pic.run_us(int((n - 0.6) * TICK * 1e6))
            m.evoluciona(vals); comprobar(f"it {it} antes de cumplir T")   # aun no ha pasado el tiempo
            lim = pic.cyc + int(1.2 * TICK * 1e6)
            while pic.ram[0x0C] == x_antes and pic.cyc < lim:
                pic.run_us(200)
            pic.run_us(300)
            m.t_ok = True
            m.evoluciona(vals); comprobar(f"it {it} tras cumplir T")
        else:
            pic.set_in(ej, vals); pic.run_us(1500)
            m.evoluciona(vals); comprobar(f"it {it} desde X{x_antes} con {[k for k in vals if vals[k]]}")
        if m.x != x_antes: trans_hechas.add((x_antes, m.x))
    pares = {(f, t) for f, _, t, _ in ej["trans"]}
    falta = pares - trans_hechas
    # transiciones instantaneas (p. ej. X4 del tunel) no se ven como par directo
    return visit, falta


def tiempo_real(ej, semilla=3):
    """Mide la duracion real de cada temporizador con el programa definitivo (escala 1)."""
    d = tempfile.mkdtemp()
    hexf = build(ej, 1, d)
    noms = [x[0] for x in ej["entradas"]]
    res = []
    for e, txt, outs, t in ej["etapas"]:
        if not t: continue
        rnd = random.Random(semilla)
        pic = PIC(hexf); m = Modelo(ej)
        pic.set_in(ej, {k: 0 for k in noms}); pic.run_us(2000)
        for _ in range(200):
            if m.x == e: break
            tr = rnd.choice([tr for tr in ej["trans"] if tr[0] == m.x])
            vals = {k: 0 for k in noms}
            for c in tr[1]:
                if isinstance(c, str) and c != "T" and c not in m.mem:
                    vals[c.lstrip("/")] = not c.startswith("/")
            pic.set_in(ej, vals)
            if "T" in tr[1]:
                x0 = m.x
                while pic.ram[0x0C] == x0: pic.run_us(5000)
                m.t_ok = True
            else:
                pic.run_us(2000)
            m.evoluciona(vals)
            assert pic.ram[0x0C] == m.x
        assert m.x == e
        # medir desde la entrada en la etapa: repetir la ultima transicion no es posible,
        # asi que se mide desde ahora (el PIC lleva <= 2 ms en la etapa)
        t0 = pic.cyc - 2000
        while pic.ram[0x0C] == e:
            pic.run_us(500)
        res.append((e, t, (pic.cyc - t0) / 1e6))
    return res


if __name__ == "__main__":
    for ej in EJ:
        visit, falta = prueba(ej)
        print(f"{ej['clave']:<20} etapas visitadas {sorted(visit)}  transiciones no vistas {sorted(falta) or 'ninguna'}")
        for e, t, med in tiempo_real(ej):
            print(f"      X{e}: T = {t} s  medido {med:.3f} s")
