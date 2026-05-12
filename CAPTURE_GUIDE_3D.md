# Guia Completa de Captura para Modelado 3D

Esta guia esta pensada para usar la app `proyecto_3d` en Android/iOS y obtener un set de fotos util para reconstruccion 3D.

## 1) Preparacion del entorno

- Coloca el objeto sobre una base estable.
- Usa iluminacion difusa y uniforme (evita sombras duras y reflejos fuertes).
- Evita fondos brillantes, espejos o superficies con patrones muy agresivos.
- Si el objeto es muy liso (metal/plastico brillante), agrega marcadores visuales suaves alrededor (cinta de papel, textura de apoyo) para mejorar puntos de referencia.

Checklist rapido antes de iniciar:
- Lente limpia.
- Bateria > 30%.
- Objeto completamente visible desde 360 grados.
- Sin movimiento en la escena.

## 2) Configuracion recomendada en la app

La app ya aplica estas optimizaciones:
- Camara trasera.
- Resolucion maxima disponible del dispositivo.
- Enfoque y exposicion en automatico antes de cada toma.
- Bloqueo de disparo cuando la escena esta inestable.

Modo Captura Profesional 3D (perfiles):
- `rapido`: para objetos faciles y sesiones cortas. Menor espera entre fotos.
- `estable`: balance recomendado para la mayoria de objetos.
- `maxima_calidad`: prioriza consistencia, estabilidad y cobertura robusta.

Cuando usar cada perfil:
- Usa `rapido` si ya tienes buena luz, objeto con textura y poco riesgo de blur.
- Usa `estable` como opcion por defecto para reconstruccion confiable.
- Usa `maxima_calidad` en objetos complejos, brillantes o cuando buscas malla mas solida.

## 3) Estrategia de captura (paso a paso)

### Fase A: Anillo medio (base)
- Rodea el objeto en 360 grados.
- Toma fotos cada 10-15 grados.
- Mantiene distancia constante.

Objetivo: 16 a 24 fotos.

### Fase B: Anillo alto
- Sube ligeramente el angulo de camara (20-35 grados hacia abajo al objeto).
- Repite 360 grados.

Objetivo: 12 a 18 fotos.

### Fase C: Anillo bajo
- Baja la camara (20-35 grados hacia arriba al objeto).
- Repite 360 grados.

Objetivo: 12 a 18 fotos.

Total recomendado:
- Minimo util: 30 fotos.
- Ideal: 45 a 60 fotos.

## 4) Regla de oro de calidad por toma

Cada foto debe cumplir:
- Nitidez visible en bordes/relieves.
- Exposicion equilibrada (ni quemada ni oscura).
- Cobertura nueva del objeto (evita duplicados casi identicos).
- Superposicion con fotos vecinas ~60%-80%.

Si una foto sale movida o fuera de foco:
- Repite esa toma en el mismo sector antes de avanzar.

## 5) Estabilidad en la toma (muy importante)

- Sujeta el telefono con ambas manos.
- Exhala suave y dispara al final de la exhalacion.
- Espera un instante entre disparos para evitar vibracion por toque.
- No cambies bruscamente distancia o altura entre tomas consecutivas.

Tip practico:
- Moverte alrededor del objeto suele ser mejor que girar el objeto.

## 6) Objetos dificiles y como tratarlos

- Objetos brillantes: reduce reflejos con luz difusa lateral, evita flash.
- Objetos oscuros: sube iluminacion global, no subas ISO en exceso.
- Objetos con simetria extrema: agrega referencias externas discretas en la base/fondo.
- Objetos delgados: toma mas fotos en perfiles laterales.

## 7) Revision antes de exportar/procesar

Antes de cerrar sesion verifica:
- Cobertura completa de 360 grados.
- Al menos 3 alturas (baja/media/alta).
- Sin huecos grandes de angulo.
- Sin bloques de fotos borrosas consecutivas.

Si detectas huecos:
- Captura solo los sectores faltantes, no repitas toda la sesion.

## 8) Errores comunes que bajan la calidad 3D

- Tomar pocas fotos (<20).
- Cambiar mucho la distancia entre disparos.
- Mezclar fotos con distinta iluminacion fuerte.
- Usar zoom digital.
- Fondo sin textura y objeto sin detalles visuales.

## 9) Como evitar modelos de puntos y acercarte a modelo solido

- Evita grandes saltos de angulo entre tomas consecutivas.
- Asegura superposicion visual fuerte entre fotos vecinas.
- Captura los tres niveles: bajo, medio y alto.
- Repite sectores donde la app marque advertencias de nitidez o similitud.
- Si el resultado parece nube de puntos incompleta, agrega tomas en zonas con huecos y mas variacion de altura.

## 10) Flujo recomendado para resultados consistentes

1. Prepara escena y luz.
2. Captura anillo medio completo.
3. Captura anillo alto.
4. Captura anillo bajo.
5. Revisa nitidez y cobertura.
6. Corrige sectores debiles.
7. Exporta/procesa.

Si mantienes este flujo, la reconstruccion suele mejorar mucho en completitud y estabilidad de malla.
