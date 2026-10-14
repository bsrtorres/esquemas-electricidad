// Menú común de la web. Cada página lo carga con <script src="(ruta)/menu.js" defer></script>.
// Para añadir una ficha o una página nueva basta con añadirla aquí.
(function () {
  const BASE = new URL(".", document.currentScript.src);
  const MENU = [
    {t: "Inicio", href: "index.html"},
    {t: "Simuladores", items: [
      {t: "Todos los simuladores", href: "simuladores.html"},
      {t: "Conmutadas, cruzamiento y telerruptor", href: "simulador.html"},
      {t: "Cuadro general de mando y protección", href: "cuadro.html"},
    ]},
    {t: "Cálculos", items: [
      {t: "Todos los cálculos", href: "calculos.html"},
      {t: "Circuitos de la vivienda (C1 a C11)", href: "calculos/calculo_circuitos_vivienda.html"},
      {t: "Tomas de uso general (C2)", href: "calculos/calculo_tomas_C2.html"},
      {t: "Ejemplo: toma del C2 a 12 m", href: "calculos/ejemplo_toma_C2_12m.html"},
      {t: "Teoría del cálculo de secciones (PDF)", href: "calculos/teoria_calculo_secciones_vivienda.pdf"},
    ]},
    {t: "Fichas", items: [
      {t: "Todas las fichas", href: "fichas.html"},
      {h: "A4"},
      {t: "001 · Interruptor, conmutador, pulsador y timbre", href: "pdf/A4/esquema-001-A4.pdf"},
      {t: "002 · Conmutada, interruptor y enchufe", href: "pdf/A4/esquema-002-A4.pdf"},
      {t: "003 · Cruzamiento, pulsador y timbre", href: "pdf/A4/esquema-003-A4.pdf"},
      {t: "004 · Dos interruptores, pulsador y timbre", href: "pdf/A4/esquema-004-A4.pdf"},
      {t: "005 · Conmutada, conmutador y enchufe", href: "pdf/A4/esquema-005-A4.pdf"},
      {t: "006 · Dos interruptores y una conmutada", href: "pdf/A4/esquema-006-A4.pdf"},
      {t: "013 · Telerruptor y 2 lámparas en paralelo", href: "pdf/A4/esquema-013-A4.pdf"},
      {t: "013 · Solución", href: "pdf/A4/esquema-013-A4-solucion.pdf"},
      {t: "001–006 juntas", href: "pdf/esquemas-001-006-A4.pdf"},
      {h: "A3"},
      {t: "007 · Conmutada, interruptor, timbre y enchufe", href: "pdf/A3/esquema-007-A3.pdf"},
      {t: "008 · Doble cruzamiento y 2 enchufes", href: "pdf/A3/esquema-008-A3.pdf"},
      {t: "009 · Conmutador, interruptor, timbre y enchufe", href: "pdf/A3/esquema-009-A3.pdf"},
      {t: "010 · Cruzamiento, conmutada y enchufe", href: "pdf/A3/esquema-010-A3.pdf"},
      {t: "011 · Timbre con dos pulsadores, interruptor y conmutada", href: "pdf/A3/esquema-011-A3.pdf"},
      {t: "012 · Cruzamiento y dos interruptores", href: "pdf/A3/esquema-012-A3.pdf"},
      {t: "007–012 juntas", href: "pdf/esquemas-007-012-A3.pdf"},
    ]},
    {t: "Domótica", items: [
      {t: "Ecosistema domótico Shelly (aula de cocina)", href: "ecosistema-domotico.html"},
    ]},
    {t: "Normativa", href: "normativa.html"},
  ];

  const css = `
  .mnu { position: sticky; top: 0; z-index: 1000; background: #1d1d1f; color: #fff;
         font-family: Calibri, "Segoe UI", Arial, sans-serif; font-size: 18px; line-height: 1.4;
         box-shadow: 0 2px 6px rgba(0,0,0,.2); }
  .mnu * { box-sizing: border-box; }
  .mnu-in { max-width: 1400px; margin: 0 auto; padding: 0 16px; display: flex; align-items: center; gap: 4px; min-height: 52px; flex-wrap: wrap; }
  .mnu-brand { color: #fff; font-weight: bold; text-decoration: none; margin-right: 12px; padding: 8px 0; white-space: nowrap; }
  .mnu-toggle { display: none; margin-left: auto; font: inherit; color: #fff; background: transparent;
                border: 2px solid #fff; border-radius: 8px; padding: 4px 12px; cursor: pointer; }
  .mnu-list { display: flex; gap: 4px; list-style: none; margin: 0; padding: 0; flex-wrap: wrap; }
  .mnu-list > li { position: relative; }
  .mnu-top { display: block; font: inherit; color: #fff; background: transparent; border: 0; border-radius: 8px;
             padding: 8px 12px; cursor: pointer; text-decoration: none; white-space: nowrap; }
  .mnu-top:hover, .mnu-top:focus-visible, .mnu-top[aria-expanded="true"] { background: #3a3a3f; outline: none; }
  .mnu-top.cur { box-shadow: inset 0 -3px 0 #ffb27a; }
  .mnu-top .car { display: inline-block; margin-left: 6px; font-size: 12px; transition: transform .15s; }
  .mnu-top[aria-expanded="true"] .car { transform: rotate(180deg); }
  .mnu-drop { display: none; position: absolute; left: 0; top: calc(100% + 4px); min-width: 380px; max-width: 92vw;
              max-height: 75vh; overflow-y: auto; background: #fff; color: #1d1d1f; border-radius: 10px;
              box-shadow: 0 6px 24px rgba(0,0,0,.25); padding: 6px; list-style: none; margin: 0; }
  .mnu-drop.open { display: block; }
  .mnu-list > li:nth-last-child(-n+2) .mnu-drop { left: auto; right: 0; }
  .mnu-drop a { display: block; color: #1d1d1f; text-decoration: none; padding: 7px 10px; border-radius: 6px; }
  .mnu-drop a:hover, .mnu-drop a:focus-visible { background: #f1ece3; color: #b4471a; outline: none; }
  .mnu-drop a.cur { font-weight: bold; color: #b4471a; }
  .mnu-drop .mnu-h { font-size: 14px; font-weight: bold; color: #5d5d63; padding: 8px 10px 2px; text-transform: uppercase; letter-spacing: .05em; }
  .mnu-drop .pdf { font-size: 13px; color: #5d5d63; margin-left: 6px; }
  @media (max-width: 760px) {
    .mnu-toggle { display: block; }
    .mnu-list { display: none; flex-direction: column; width: 100%; padding: 0 0 10px; }
    .mnu.open .mnu-list { display: flex; }
    .mnu-top { width: 100%; text-align: left; }
    .mnu-drop { position: static; min-width: 0; max-width: none; max-height: none; box-shadow: none; margin: 2px 0 6px; }
  }
  @media print { .mnu { display: none; } }`;

  const here = location.href.split("#")[0].split("?")[0];
  const abs = h => new URL(h, BASE).href;
  const isCur = h => abs(h) === here || (h === "index.html" && here === BASE.href);
  const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

  let html = `<div class="mnu-in"><a class="mnu-brand" href="${abs("index.html")}">Esquemas de electricidad</a>`
    + `<button class="mnu-toggle" aria-expanded="false" aria-controls="mnu-list">Menú</button><ul class="mnu-list" id="mnu-list">`;
  MENU.forEach((g, i) => {
    if (g.href) {
      html += `<li><a class="mnu-top ${isCur(g.href) ? "cur" : ""}" href="${abs(g.href)}" ${isCur(g.href) ? 'aria-current="page"' : ""}>${esc(g.t)}</a></li>`;
      return;
    }
    const cur = g.items.some(it => it.href && isCur(it.href));
    html += `<li><button class="mnu-top ${cur ? "cur" : ""}" aria-expanded="false" aria-controls="mnu-d${i}">${esc(g.t)}<span class="car" aria-hidden="true">▼</span></button>`
      + `<ul class="mnu-drop" id="mnu-d${i}">`
      + g.items.map(it => it.h ? `<li class="mnu-h">${esc(it.h)}</li>`
        : `<li><a href="${it.ext ? it.href : abs(it.href)}" ${it.ext ? 'target="_blank" rel="noopener"' : ""} class="${isCur(it.href) ? "cur" : ""}" ${isCur(it.href) ? 'aria-current="page"' : ""}>${esc(it.t)}${/\.pdf$/.test(it.href) ? '<span class="pdf">PDF</span>' : ""}</a></li>`).join("")
      + `</ul></li>`;
  });
  html += `</ul></div>`;

  const style = document.createElement("style"); style.textContent = css; document.head.appendChild(style);
  const nav = document.createElement("nav"); nav.className = "mnu"; nav.setAttribute("aria-label", "Menú principal");
  nav.innerHTML = html;
  document.body.prepend(nav);

  const closeAll = except => nav.querySelectorAll(".mnu-drop.open").forEach(d => {
    if (d === except) return;
    d.classList.remove("open"); nav.querySelector(`[aria-controls="${d.id}"]`).setAttribute("aria-expanded", "false");
  });
  nav.querySelectorAll("button.mnu-top").forEach(b => b.addEventListener("click", () => {
    const d = document.getElementById(b.getAttribute("aria-controls"));
    const open = !d.classList.contains("open");
    closeAll(d); d.classList.toggle("open", open); b.setAttribute("aria-expanded", open);
  }));
  const tg = nav.querySelector(".mnu-toggle");
  tg.addEventListener("click", () => { const o = nav.classList.toggle("open"); tg.setAttribute("aria-expanded", o); });
  document.addEventListener("click", e => { if (!nav.contains(e.target)) closeAll(); });
  document.addEventListener("keydown", e => {
    if (e.key !== "Escape") return;
    const open = nav.querySelector(".mnu-drop.open");
    if (open) { closeAll(); nav.querySelector(`[aria-controls="${open.id}"]`).focus(); }
  });
})();
