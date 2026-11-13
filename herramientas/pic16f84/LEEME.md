# Generador de los programas PIC16F84

`spec.py` describe cada GRAFCET (entradas, salidas, etapas, tiempos y transiciones). A partir de esa descripción:

- `python3 build_web.py ../..` regenera `pic16f84.html` y los `.asm`, `.hex` y `.zip` de `pic16f84/` (necesita `gpasm`, del paquete gputils).
- `python3 test.py` simula cada programa instrucción a instrucción y comprueba, con miles de combinaciones de entradas, que el PIC pasa por las mismas etapas y activa las mismas salidas que el GRAFCET, y mide la duración real de cada temporizador.

Para cambiar un ejercicio, edita `spec.py` y vuelve a ejecutar los dos scripts.
