"""Genera pic16f84.html y la carpeta pic16f84/ de la web a partir de spec.py."""
import os, sys, shutil, subprocess, zipfile, html
from spec import EJ, TICK, ticks, valor_salida
from gen import gen, ascii_txt

REPO = sys.argv[1]
DST = os.path.join(REPO, "pic16f84")
e = html.escape

# ---------------------------------------------------------------- programas
os.makedirs(DST, exist_ok=True)
for ej in EJ:
    asm = os.path.join(DST, ej["clave"] + ".asm")
    with open(asm, "w", encoding="ascii", newline="\r\n") as f:
        f.write(ascii_txt(gen(ej)))
    subprocess.run(["gpasm", "-q", asm], cwd=DST, check=True)
    for ext in (".lst", ".cod"):
        os.remove(asm[:-4] + ext)
zp = os.path.join(DST, "pic16f84-grafcet.zip")
with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED) as z:
    for ej in EJ:
        for ext in (".asm", ".hex"):
            z.write(os.path.join(DST, ej["clave"] + ext), ej["clave"] + ext)

# ---------------------------------------------------------------- utilidades
PINES_IZQ = [(1, "RA2"), (2, "RA3"), (3, "RA4"), (4, "MCLR"), (5, "VSS"), (6, "RB0"), (7, "RB1"), (8, "RB2"), (9, "RB3")]
PINES_DER = [(18, "RA1"), (17, "RA0"), (16, "OSC1"), (15, "OSC2"), (14, "VDD"), (13, "RB7"), (12, "RB6"), (11, "RB5"), (10, "RB4")]
NUM = {p: n for n, p in PINES_IZQ + PINES_DER}
P138 = {"A": 1, "B": 2, "C": 3, "G2A": 4, "G2B": 5, "G1": 6, "Y7": 7, "GND": 8, "Y6": 9, "Y5": 10, "Y4": 11,
        "Y3": 12, "Y2": 13, "Y1": 14, "Y0": 15, "VCC": 16}


def conexiones(ej):
    """dict pin -> (texto, tipo) tipo: in / out / pwr / free"""
    c = {"MCLR": ("RESET (10k a +5V, pulsador a masa)", "pwr"), "VSS": ("Masa (0 V)", "pwr"), "VDD": ("+5 V", "pwr"),
         "OSC1": ("Cristal 4 MHz", "pwr"), "OSC2": ("Cristal 4 MHz", "pwr")}
    for nom, p, d in ej["entradas"]:
        c[p] = (f"{nom} · {d}", "in")
    if ej["modo"] == "138":
        for k, (pin, s) in enumerate([("RB0", "A"), ("RB1", "B"), ("RB2", "C")]):
            c[pin] = (f"74HC138 · {s} (pin {P138[s]})", "out")
        c["RB3"] = ("74HC138 · G1 (pin 6) + 10k a masa", "out")
    else:
        for q, d, pin in ej["salidas"]:
            c[pin] = (f"{q} · {d}", "out")
        for et, pin in ej.get("leds", {}).items():
            c[pin] = (f"LED etapa X{et}", "out")
    return c


def svg_pic(ej):
    c = conexiones(ej)
    W, H = 900, 392
    cx, cw, top, step = 340, 220, 40, 38
    s = [f'<svg class="pin" viewBox="0 0 {W} {H}" role="img" aria-label="Conexiones del PIC16F84A en el ejercicio {ej["n"]}">']
    s.append(f'<rect x="{cx}" y="{top-20}" width="{cw}" height="{9*step+12}" rx="8" class="chip"/>')
    s.append(f'<path d="M{cx+cw/2-14} {top-20} a14 14 0 0 0 28 0" class="notch"/>')
    s.append(f'<text x="{cx+cw/2}" y="{top+152}" class="chipt" transform="rotate(-90 {cx+cw/2} {top+152})" dominant-baseline="middle">PIC16F84A</text>')
    for side, lista in (("L", PINES_IZQ), ("R", PINES_DER)):
        for i, (n, p) in enumerate(lista):
            y = top + i * step
            txt, tipo = c.get(p, ("libre", "free"))
            if side == "L":
                s.append(f'<line x1="{cx-40}" y1="{y}" x2="{cx}" y2="{y}" class="leg"/>')
                s.append(f'<text x="{cx+8}" y="{y+5}" class="pn">{n} {p}</text>')
                s.append(f'<text x="{cx-48}" y="{y+5}" class="cn {tipo}" text-anchor="end">{e(txt)}</text>')
            else:
                s.append(f'<line x1="{cx+cw}" y1="{y}" x2="{cx+cw+40}" y2="{y}" class="leg"/>')
                s.append(f'<text x="{cx+cw-8}" y="{y+5}" class="pn" text-anchor="end">{p} {n}</text>')
                s.append(f'<text x="{cx+cw+48}" y="{y+5}" class="cn {tipo}">{e(txt)}</text>')
    s.append("</svg>")
    return "".join(s)


def cond_html(cs):
    out = []
    for c in cs:
        if isinstance(c, tuple):
            out.append(f"{c[1]} {'≥' if c[0]=='ge' else '&lt;'} {c[2]}")
        elif c == "T":
            out.append("T cumplido")
        elif c.startswith("/"):
            out.append(f'<span class="ov">{e(c[1:])}</span>')
        else:
            out.append(e(c.replace("MEM_", "Mem_")))
    return " · ".join(out)


def ficha(ej):
    n_in = len(ej["entradas"])
    n_out = len(ej["salidas"])
    n_led = len(ej.get("leds", {}))
    modo = ej["modo"]
    pines_out = 4 if modo == "138" else n_out + n_led
    h = []
    h.append(f'<section class="card" id="ej{ej["n"]}">')
    h.append(f'<h2>Ejercicio {ej["n"]} · {e(ej["titulo"])}</h2>')
    h.append(f'<p>{e(ej["enunciado"])}</p>')
    tags = [f"{n_in} entradas", f"{n_out} salidas"]
    if modo == "138":
        tags.append("salidas por 74HC138")
    else:
        tags.append("salidas directas")
    if n_led:
        tags.append(f"{n_led} LED de etapa")
    tmp = [et for et in ej["etapas"] if et[3]]
    if tmp:
        tags.append("temporizador" + ("es" if len(tmp) > 1 else ""))
    if ej.get("contador"):
        tags.append("contador")
    if ej.get("memoria"):
        tags.append("memoria interna")
    h.append('<p class="tags">' + "".join(f"<span>{t}</span>" for t in tags) + "</p>")
    h.append('<p class="dl">'
             f'<a class="big" href="pic16f84/{ej["clave"]}.hex" download>Programa .hex</a> '
             f'<a class="big alt" href="pic16f84/{ej["clave"]}.asm" download>Código .asm</a>'
             + (f' <a href="{ej["web"]}">Ejercicio con bloques RS de LOGO!</a>' if ej["web"] else "") + "</p>")

    # GRAFCET
    h.append("<h3>GRAFCET en el PIC</h3>")
    h.append('<div class="tw"><table><thead><tr><th>Etapa</th><th>Acciones</th><th>Tiempo</th><th>Pasa a</th></tr></thead><tbody>')
    for num, txt, outs, t in ej["etapas"]:
        sal = []
        for tr in ej["trans"]:
            if tr[0] == num:
                sal.append(f"X{tr[2]} si {cond_html(tr[1])}")
        acc = " + ".join(outs) if outs else "—"
        tt = f"{t} s → {ticks(t)} × 65,5 ms" if t else ""
        extra = ""
        for tr in ej["trans"]:
            if tr[0] == num and tr[3]:
                pass
        h.append(f"<tr><td class='n'>X{num}</td><td><b>{acc}</b> <span class='mut'>{e(txt)}</span></td><td>{tt}</td><td>{'<br>'.join(sal)}</td></tr>")
    h.append("</tbody></table></div>")
    notas = []
    if ej.get("memoria"):
        notas.append("La llamada pulsada se guarda en dos bits de memoria (Mem_P1 y Mem_P2) al pasar de X0 a X1, como el RS auxiliar de LOGO!, y se borran al volver a X0.")
    if ej.get("contador"):
        notas.append("El contador C1 es una variable: se pone a 0 al arrancar el ciclo y suma 1 al llegar a X4. X4 no tiene acciones y dura un solo ciclo de programa.")
    for nt in notas:
        h.append(f'<p class="note">{e(nt)}</p>')

    # Pines
    h.append("<h3>Conexiones del PIC</h3>")
    h.append(f'<p class="mut">Entradas en verde, salidas en naranja. Usa {n_in} de las 13 patillas como entradas y {pines_out} como salidas.</p>')
    h.append(f'<div class="svgw">{svg_pic(ej)}</div>')
    if modo == "138":
        h.append("<h3>Salidas a través del 74HC138</h3>")
        h.append("<p>En cada etapa solo hay una salida activa. El PIC envía su número en binario por RB0, RB1 y RB2 y pone RB3 (G1) a 1; el 74HC138 activa esa salida poniéndola a <b>0 V</b>. En reposo, RB3 = 0 y todas quedan apagadas.</p>")
        h.append('<div class="tw"><table><thead><tr><th>Salida</th><th>Función</th><th>RB2 RB1 RB0</th><th>Patilla del 74HC138</th></tr></thead><tbody>')
        for k, (q, d) in enumerate(ej["salidas"]):
            h.append(f"<tr><td class='n'>{q}</td><td>{e(d)}</td><td><code>{k:03b}</code></td><td>Y{k} · pin {P138['Y'+str(k)]}</td></tr>")
        h.append("</tbody></table></div>")

    # Componentes Proteus
    h.append("<h3>Componentes en Proteus</h3>")
    botones = [x[0] for x in ej["entradas"] if x[0] in ("M", "B_P1", "B_P2")]
    comp = [("PIC16F84A", 1, "Microcontrolador. Program File: <code>" + ej["clave"] + ".hex</code>"),
            ("BUTTON", len(botones) + 1, "Pulsador" + ("es " if len(botones) > 1 else " ") + ", ".join(botones) + " y pulsador de RESET"),
            ("SWITCH", n_in - len(botones), "Finales de carrera, sensores y selectores (o LOGICSTATE)"),
            ("RES 10k", n_in + 1 + (1 if modo == "138" else 0), "Resistencias a masa de las entradas" + (", pull-up de MCLR y la de G1" if modo == "138" else " y pull-up de MCLR")),
            ("LED-YELLOW / LED-GREEN", n_out + n_led, "Una por salida" + (" y por etapa" if n_led else "")),
            ("RES 330", n_out + n_led, "Una por LED")]
    if modo == "138":
        comp.insert(1, ("74HC138", 1, "Decodificador de 3 a 8 líneas"))
    h.append('<div class="tw"><table><thead><tr><th>Nombre en la librería</th><th>Cant.</th><th>Para qué</th></tr></thead><tbody>')
    for nom, cant, uso in comp:
        h.append(f"<tr><td><code>{nom}</code></td><td>{cant}</td><td>{uso}</td></tr>")
    h.append("</tbody></table></div>")
    if modo == "138":
        h.append("<p class='note'>Los LED de salida del 74HC138 se conectan al revés que los del PIC: +5 V → 330 Ω → LED → patilla Y. El LED luce cuando la Y está a 0 V. G2A y G2B van a masa; VCC (16) a +5 V y GND (8) a masa.</p>")
    h.append("</section>")
    return "\n".join(h)


resumen = []
for ej in EJ:
    n_in = len(ej["entradas"]); n_out = len(ej["salidas"])
    pins = n_in + (4 if ej["modo"] == "138" else n_out + len(ej.get("leds", {})))
    resumen.append(f"<tr><td class='n'><a href='#ej{ej['n']}'>{ej['n']}</a></td><td><b>{e(ej['titulo'])}</b></td>"
                   f"<td>{n_in}</td><td>{n_out}</td><td>{'74HC138' if ej['modo']=='138' else 'Directas'}</td><td>{pins} de 13</td></tr>")

PAGE = f"""<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PIC16F84 y Proteus · Taller de Electricidad y Electrónica</title>
<style>
  :root {{ --bg: #f6f4ef; --panel: #fff; --ink: #1d1d1f; --muted: #5d5d63; --accent: #b4471a; --in: #0b7a43; --out: #c2410c; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: var(--bg); color: var(--ink);
         font-family: Calibri, "Segoe UI", Arial, sans-serif; font-size: 19px; line-height: 1.5; }}
  .wrap {{ max-width: 1000px; margin: 0 auto; padding: 24px 16px 40px; }}
  h1 {{ font-size: 32px; margin: 0 0 4px; }}
  h2 {{ font-size: 24px; margin: 0 0 12px; }}
  h3 {{ font-size: 20px; margin: 22px 0 8px; }}
  p.lead {{ color: var(--muted); margin: 0 0 24px; }}
  .card {{ background: var(--panel); border-radius: 12px; padding: 20px; margin-bottom: 20px;
          box-shadow: 0 1px 4px rgba(0,0,0,.08); scroll-margin-top: 70px; }}
  .card p {{ margin: 0 0 12px; }}
  .big {{ display: inline-block; padding: 10px 18px; border-radius: 10px; background: var(--ink);
         color: #fff; text-decoration: none; font-weight: bold; margin: 0 6px 6px 0; }}
  .big.alt {{ background: #fff; color: var(--ink); box-shadow: inset 0 0 0 2px var(--ink); }}
  .tw {{ overflow-x: auto; }}
  table {{ width: 100%; border-collapse: collapse; }}
  th, td {{ text-align: left; padding: 7px 6px; border-bottom: 1px solid #eee; vertical-align: top; }}
  th {{ font-size: 16px; color: var(--muted); font-weight: normal; }}
  td.n {{ width: 60px; font-weight: bold; white-space: nowrap; }}
  a {{ color: var(--accent); }}
  code {{ font-family: Consolas, "Courier New", monospace; font-size: 17px; background: #f1ece3; padding: 1px 5px; border-radius: 4px; }}
  .mut {{ color: var(--muted); }}
  .ov {{ text-decoration: overline; }}
  .note {{ background: #fff8e6; border-left: 4px solid #ffc83d; padding: 8px 12px; border-radius: 6px; }}
  .tags span {{ display: inline-block; font-size: 15px; background: #eef2f7; color: #17335e; border-radius: 99px; padding: 2px 10px; margin: 0 6px 6px 0; }}
  ol.steps li {{ margin-bottom: 10px; }}
  .svgw {{ overflow-x: auto; }}
  svg.pin {{ width: 100%; min-width: 720px; height: auto; display: block; font-family: Calibri, "Segoe UI", Arial, sans-serif; }}
  svg .chip {{ fill: #2b2d33; }}
  svg .notch {{ fill: #555a63; }}
  svg .chipt {{ fill: #fff; font-size: 20px; font-weight: bold; text-anchor: middle; }}
  svg .leg {{ stroke: #9aa0a6; stroke-width: 3; }}
  svg .pn {{ fill: #fff; font-size: 15px; }}
  svg .cn {{ font-size: 15px; fill: var(--muted); }}
  svg .cn.in {{ fill: var(--in); font-weight: bold; }}
  svg .cn.out {{ fill: var(--out); font-weight: bold; }}
  svg .cn.free {{ fill: #b0b0b5; font-style: italic; }}
  @media print {{ .card {{ break-inside: avoid; box-shadow: none; border: 1px solid #ddd; }} }}
</style>
<script src="menu.js?v=17" defer></script>
</head>
<body>
<div class="wrap">
  <h1>PIC16F84 y Proteus</h1>
  <p class="lead">Los GRAFCET de la sección GRAFCET, programados en un microcontrolador PIC16F84A en lugar del LOGO!. Cada ejercicio tiene su programa listo para cargar (.hex), el código comentado (.asm), las conexiones del PIC y los componentes para simularlo en Proteus antes de montarlo.</p>

  <section class="card">
    <h2>Los siete ejercicios</h2>
    <p>El PIC16F84A tiene 13 patillas de entrada y salida. Cada ejercicio va en su propio PIC. Los cuatro que necesitan más patillas usan un decodificador 74HC138 para las salidas.</p>
    <div class="tw"><table>
      <thead><tr><th>N.º</th><th>Ejercicio</th><th>Entradas</th><th>Salidas</th><th>Cómo salen</th><th>Patillas usadas</th></tr></thead>
      <tbody>
        {''.join(resumen)}
      </tbody>
    </table></div>
    <p style="margin-top:14px"><a class="big" href="pic16f84/pic16f84-grafcet.zip" download>Descargar los 7 programas (.zip)</a></p>
  </section>

  <section class="card">
    <h2>Del LOGO! al PIC</h2>
    <p>El programa sigue la misma idea que los bloques RS: en cada momento hay una sola etapa activa y solo se pasa a la siguiente cuando se cumple su receptividad.</p>
    <div class="tw"><table>
      <thead><tr><th>En LOGO!Soft</th><th>En el PIC</th></tr></thead>
      <tbody>
        <tr><td>Un bloque RS por etapa</td><td>La variable <code>ETAPA</code> guarda el número de la etapa activa</td></tr>
        <tr><td>Set de la etapa siguiente y Reset de la actual</td><td><code>movlw</code> con el número de la etapa siguiente y <code>call CambiaEtapa</code></td></tr>
        <tr><td>Salidas Q unidas a las etapas</td><td><code>TablaSalidas</code>: una línea <code>retlw</code> por etapa con el valor de PORTB</td></tr>
        <tr><td>Temporizador con retardo a la conexión</td><td><code>TablaTiempos</code> y el TMR0: cada desbordamiento dura 65,536 ms (5 s = 76 desbordamientos)</td></tr>
        <tr><td>Contador y RS auxiliares</td><td>Una variable (<code>C1</code>) o un bit de memoria (<code>MEM</code>)</td></tr>
        <tr><td>Entrada de RESET (I4, I9, I10)</td><td>La patilla MCLR: al pulsar, el PIC se reinicia y vuelve a X0</td></tr>
        <tr><td>Lectura de entradas en cada ciclo</td><td>Al principio de cada vuelta se copian PORTA y PORTB en <code>ENT_A</code> y <code>ENT_B</code></td></tr>
      </tbody>
    </table></div>
    <p class="note">Para cambiar un tiempo, edita su línea en <code>TablaTiempos</code>: desbordamientos = segundos ÷ 0,065536 (máximo 255, unos 16,7 s).</p>
  </section>

  <section class="card">
    <h2>Simularlo en Proteus</h2>
    <ol class="steps">
      <li><b>Coloca el PIC.</b> En <i>Pick Devices</i> busca <code>PIC16F84A</code>. Sus patillas de alimentación (VDD y VSS) están ocultas y Proteus las conecta solas a +5 V y masa.</li>
      <li><b>Carga el programa.</b> Doble clic en el PIC: en <i>Program File</i> elige el archivo <code>.hex</code> del ejercicio y en <i>Processor Clock Frequency</i> pon <code>4MHz</code>. En la simulación no hace falta dibujar el cristal ni sus condensadores.</li>
      <li><b>Conecta MCLR.</b> Resistencia de 10 kΩ de MCLR a +5 V (terminal <i>POWER</i>) y un <code>BUTTON</code> de MCLR a masa (<i>GROUND</i>). Si MCLR queda al aire, el PIC no arranca.</li>
      <li><b>Pon las entradas.</b> Cada entrada: un <code>BUTTON</code> o un <code>SWITCH</code> de +5 V a la patilla, y una resistencia de 10 kΩ de la patilla a masa. El pulsador de marcha es un BUTTON. Los finales de carrera y selectores van mejor con SWITCH, porque se quedan en la posición en que los dejas. Para ir más rápido puedes usar <code>LOGICSTATE</code>, que da 0 o 1 sin resistencias.</li>
      <li><b>Pon las salidas.</b> Patilla → resistencia de 330 Ω → LED → masa. En los ejercicios con 74HC138, al revés: +5 V → 330 Ω → LED → patilla Y.</li>
      <li><b>Simula el proceso a mano.</b> Pulsa ▶ y actúa como la máquina: pulsa M, y cuando se encienda una salida activa el final de carrera que la para. Antes de empezar, pon los sensores de la posición inicial (por ejemplo Fc0 o Fc_C). Deja cada final de carrera como estaría en la máquina: cuando el actuador sale de una posición, desactívalo; si se queda activado, una etapa posterior que lo espere pasará sin esperar.</li>
      <li><b>Mira la etapa activa.</b> Con la simulación en pausa: <i>Debug → Watch Window</i>, clic derecho, <i>Add Items (By Address)</i>, dirección <code>0x0C</code>, nombre <code>ETAPA</code>. Verás el número de la etapa en cada momento.</li>
    </ol>
    <p class="note">Para modificar el código hace falta un ensamblador MPASM: MPLAB X hasta la versión 5.35 o el antiguo MPLAB IDE 8.92. Las versiones nuevas de MPLAB X ya no lo traen. Para solo simular basta con el .hex.</p>
  </section>

  <section class="card">
    <h2>Del simulador al montaje real</h2>
    <ul>
      <li><b>Cristal:</b> 4 MHz entre las patillas 15 y 16, con dos condensadores de 22 pF a masa. Alimentación: patilla 14 a +5 V y patilla 5 a masa, con un condensador de 100 nF cerca del PIC.</li>
      <li><b>Sensores sin tensión</b> (finales de carrera, reed, pulsadores, relé del receptor de un mando): contacto a +5 V y 10 kΩ a masa, como en Proteus.</li>
      <li><b>Sensores de 12 o 24 V</b> (inductivos, fotocélulas): nunca directos al PIC. Pasa cada uno por un optoacoplador PC817.</li>
      <li><b>Salidas:</b> una patilla del PIC da unos 20 mA. Para relés o motores, usa un transistor o un ULN2803. Con el 74HC138 las salidas son activas a nivel bajo: el 74HC238, versión con salidas a nivel alto, se conecta directamente a un ULN2803.</li>
      <li><b>Programar el PIC:</b> con un programador tipo PICkit y el mismo archivo .hex.</li>
    </ul>
  </section>

{''.join(ficha(ej) for ej in EJ)}

  <section class="card">
    <h2>Qué más se puede simular en Proteus</h2>
    <div class="tw"><table>
      <thead><tr><th>Apartado de la web</th><th>¿En Proteus?</th></tr></thead>
      <tbody>
        <tr><td>Electrónica PB1–PB17 (reguladores, transistor, relé, optoacoplador, 555, LM741, LM393)</td><td>Sí. Todos los componentes están en sus librerías y con el osciloscopio virtual se ven las señales del 555.</td></tr>
        <tr><td>Electrónica PB18–PB20 (ESP32 y WiFi)</td><td>No. Proteus no simula el ESP32; se pueden rehacer con Arduino o con un PIC.</td></tr>
        <tr><td>Automatismos con contactores (014–023)</td><td>Solo el circuito de mando, usando relés como contactores. La potencia a 400 V y el motor trifásico se simulan mejor en CADe_SIMU.</td></tr>
        <tr><td>Instalaciones de vivienda y cuadro de protección</td><td>No es lo suyo: mejor los simuladores de esta web.</td></tr>
      </tbody>
    </table></div>
  </section>

</div>
</body>
</html>
"""
open(os.path.join(REPO, "pic16f84.html"), "w", encoding="utf-8").write(PAGE)
print("ok")
