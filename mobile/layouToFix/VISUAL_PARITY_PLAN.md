# Paridad visual Mobile ↔ Web — Análisis y plan de arreglos

Análisis de las 5 capturas en esta carpeta (`desktopLayout1.png`, `desktopLayout2.png`, `DesktopBattle.png` = referencia correcta / web; `mobileLayout.png`, `mobileBattle.png` = estado actual de Flutter) contrastado con el código real de `frontend/src` (React, referencia) y `mobile/lib` (Flutter, a corregir).

El backend y la lógica online ya funcionan igual en ambas plataformas — esto es **solo** sobre la capa visual: layout, overflow, y fidelidad de estilo.

> **Actualización — ronda 2**: la primera pasada de implementación se quedó en arreglos cosméticos (color/forma por widget) y pasó por alto tres problemas *estructurales* de layout que sí eran visibles en las capturas originales. Ya están corregidos; ver la sección 8 para el detalle.
>
> **Actualización — ronda 3**: tras ver la ronda 2 corriendo, Antonio señaló que el tablero seguía "dolorosamente diminuto". La causa raíz real apareció ahí: con 3-4 jugadores, `PlayerOrderRow` se envolvía a 2 líneas (le sobraba muy poco ancho) e inflaba en silencio toda la banda superior muy por encima de la altura nominal del market, robándole al tablero casi todo su espacio vertical. Esta ronda también quita la línea de estado redundante, sube el market de altura, corrige el badge de precio tapando cartas, y pasa el roster de defensores a columna. Ver sección 9.
>
> **Actualización — ronda 4 (probado en vivo en un emulador Android)**: esta ronda se verificó corriendo la app de verdad (backend local + `flutter run` en un emulador), no solo leyendo código. Confirmado con capturas de pantalla reales: el color dorado del timer, el llenado del slot del market, y los avatares cuadrados de batalla — los tres funcionan correctamente. El color del "Your turn!" del timer también se corrigió (debía ser dorado, calcado del CSS web `.turn-timer-yours`). El bug de "no se puede colocar una carta arriba de cierta altura" **no se pudo reproducir** jugando manualmente varias rondas — el tablero propio se mostró consistentemente con un solo card (4 celdas) ronda tras ronda sin importar cuántas veces se colocó una carta, lo que sugiere que el mecanismo de acumulación de cartas no se disparó como se esperaba en las partidas de prueba (posiblemente porque las rondas contra bots avanzan muy rápido y el personaje de prueba murió antes de acumular suficientes cartas). Ver sección 10 para el detalle y lo que quedó sin confirmar.
>
> **Actualización — ronda 5**: Antonio precisó el bug del tablero — pasa cuando una carta nueva se ancla por sus esquinas *inferiores* contra las esquinas *superiores* de una carta ya puesta (es decir, crece hacia arriba, hacia el market) y, tras un par de cartas así, ya no se puede seguir subiendo. Con esa pista concreta se encontró y corrigió la causa real: un desajuste de coordenadas entre `BoardView` y `BoardDropTarget` durante el arrastre (sección 11.1). También se movieron las estadísticas de los defensores de batalla al costado del avatar en vez de debajo, para que cada fila ocupe mucho menos alto (sección 11.2). Esta ronda **no se probó en el emulador** (a pedido explícito de Antonio, por consumo de recursos) — solo `flutter analyze` + `flutter build apk --debug`, que es lo que él autorizó para cambios con riesgo de romper algo.
>
> **Actualización — ronda 6**: Antonio probó la ronda 5 en su propio dispositivo y reportó tres cosas nuevas: (1) un crash de audio en consola (`AudioPlayers Exception... MEDIA_ERROR_UNKNOWN`) justo al intentar tomar una carta del market, tras lo cual ya no pudo tomarla; (2) el bug del tablero sigue pasando cerca del market; (3) durante la fase de pelea, todo el texto se ve con un subrayado amarillo/punteado que hay que quitar. Ver sección 12 — el (1) tiene una causa concreta y un fix real (una red de seguridad global para errores async no capturados, ya que el `try/catch` de `sfx.dart` no alcanza a atrapar errores que el plugin de audio reporta después de que `play()` ya había retornado). El (3) no tiene ninguna decoración de texto en el código (confirmado por búsqueda en todo el proyecto), así que se aplicó un reseteo defensivo; puede que ese subrayado en realidad venga de una función de accesibilidad del sistema operativo, ajena a la app. El (2) es el punto más importante sin resolver: el fix de la ronda 5 apunta exactamente al síntoma descrito, así que si persiste hace falta confirmar que se probó con un build realmente nuevo (reinstalar/`flutter run` desde cero, no solo hot reload) antes de seguir buscando otra causa.
>
> **Actualización — ronda 7 (el bug del tablero, resuelto y confirmado)**: Antonio explicó el mecanismo exacto — para hacer una "torre" hace falta poder soltar la carta nueva por encima de la carta más alta del tablero, pero al crecer la torre esa posición termina a la altura del market, y esa zona nunca fue parte del área interactiva del tablero. La causa no era el desajuste de coordenadas (ya arreglado en la ronda 5), sino que el contenido del tablero podía llegar a ocupar el 100% de su propio contenedor, sin dejar ningún margen "de maniobra" para arrastrar más arriba dentro de la misma zona interactiva. Fix: un `Padding` fijo alrededor del `FittedBox` del tablero (sección 13.1), probado en vivo en el emulador — **Antonio confirmó que el margen funciona**. Efecto secundario: las cartas del tablero se ven más chicas ahora (el padding les resta espacio). A partir de ahí pidió explícitamente **no seguir usando el emulador** (consume muchos recursos y no aporta tanto) y en su lugar una reestructuración más grande: mover el HUD de la mano a la derecha del tablero, mute/leave debajo del timer, y el HUD del jugador (retrato+stats) simétrico al de la mano pero a la izquierda — todo dentro de la misma fila que el tablero, eliminando la barra inferior separada para que el tablero pueda ocupar también ese espacio. Implementado en la sección 13.2, verificado solo por compilación (sin emulador, como se pidió).
>
> **Actualización — ronda 8**: Antonio confirmó que la reestructuración de la ronda 7 "se ve bien" y pidió cuatro ajustes más de comportamiento/pulido (sección 14), todos verificados solo por compilación, sin emulador: (1) el preview verde de dónde quedaría la carta aparecía sin importar qué tan lejos estuviera el drag — ahora solo aparece (y solo se puede soltar) cuando el drag está realmente cerca de una carta ya puesta; (2) el botón "Confirm" se desbordaba y el texto pasaba a 2 líneas dentro del panel angosto de la mano — ajustado a un estilo compacto de una sola línea; (3) el modal de tableros de oponentes necesitaba scroll para ver tableros grandes — ahora se encogen (`FittedBox`) para ocupar siempre el mismo espacio, igual que se hizo con el tablero propio.

---

## 1. Resumen ejecutivo

| Zona de pantalla | Web (correcto) | Mobile (actual) | Severidad |
|---|---|---|---|
| Tablero central (cartas jugadas) | `BoardView.tsx`, sin overflow (scrollable/contenido siempre visible) | `BoardView` de Flutter **no es scrollable** y usa celdas de tamaño fijo → overflow real, visible en pantalla como banner rojo | **P0 — bug real** |
| Avatares en Battle (atacante/defensor) | Retratos **cuadrados** con esquinas redondeadas | `CircleAvatar` (redondos) | **P1 — mismatch visual claro** |
| Tarjeta del atacante en Battle | Fondo degradado madera + borde dorado 3px | Fondo sólido `iron` + borde rojo-naranja 1-2px | **P1** |
| Estados de fila en Battle (muerto/atacando) | Escala de grises + borde punteado | Solo opacidad/tinte de color | P2 (pulido opcional) |
| Market panel (4 slots + frame) | `marketFrame.png` con grid medido en fracciones del arte | Ya replicado con las mismas fracciones (`market_panel.dart`) | ✅ Ya correcto |
| Avatares mini (turno / orden de jugadores) | Círculos | Círculos | ✅ Ya correcto |
| Timer / botón "Opponent board" | Placa de madera (`panelSquare.png`) | Referencia el mismo asset en código, pero en la captura mobile se ve un rectángulo plano oscuro | ⚠️ Verificar en dispositivo (no es un bug de código) |
| Distorsión de imágenes (`BoxFit.fill` sobre assets no cuadrados) | El propio CSS web ya "achata" `panelSquare.png`/`opponentBoardButton.png` en cajas cuadradas | Mobile replica exactamente ese mismo achatamiento | ✅ No es un bug — es fiel al original |

---

## 2. P0 — Overflow real en el tablero central

**Evidencia**: en `mobileLayout.png` aparece literalmente el banner de debug de Flutter *"BOTTOM OVERFLOWED BY 54 PIXELS"* justo sobre el clúster de cartas jugadas.

**Causa raíz exacta** (código):

- `mobile/lib/presentation/widgets/board_view.dart:9` — `const double boardCellSize = 40;` — tamaño de celda **fijo**.
- `board_view.dart:52-119` — `BoardView` renderiza una `Column` de `Row`s de estas celdas. El propio comentario del archivo (línea ~49-51) lo admite: *"unlike the web version, this does not scroll — large boards are sized to their full content"*.
- Esa `Column` cuelga de `Expanded(child: _boardZone())` en `mobile/lib/presentation/screens/match_screen.dart:144`, que solo recibe el espacio vertical restante después de tres alturas **fijas** en píxeles (`match_screen.dart:23-33`):
  ```dart
  const double _topBox = 66;          // timer / botón oponente
  const double _marketHeight = 92;    // banda del market
  const double _bottomBarHeight = 96; // barra inferior (HUD)
  ```
  más el alto de la línea de estado (`_statusLine`).
- En una pantalla corta en landscape, o cuando el tablero jugado crece a 3+ filas (3 × 40px = 120px+ solo de celdas, sin contar padding/bordes), la altura intrínseca de la `Column` supera el espacio que le sobra a `_boardZone()` → Flutter dispara el overflow.
- `BoardDropTarget` (`mobile/lib/presentation/widgets/board_drop_target.dart`) comparte la misma constante `boardCellSize` para convertir posiciones de drag-and-drop en coordenadas de tablero — cualquier fix debe mantener ambos sincronizados.

**Fix recomendado**:

1. **Opción A (preferida)** — hacer `boardCellSize` dinámico: envolver `_boardZone()`/`BoardView` en un `LayoutBuilder` que calcule el tamaño de celda en función del espacio disponible y de `computeBoardBounds()` (ya existe en `board_view.dart:30-41` y devuelve min/max X/Y), con un piso razonable (p. ej. 24px) para que nunca se vea ilegible. Este patrón ya se usa en `MarketPanel` (`market_panel.dart:52-116`, `LayoutBuilder` + fracciones), así que hay precedente directo en el propio código mobile.
2. **Opción B (red de seguridad)** — si aun con celdas al mínimo un tablero muy grande no cabe, envolver todo en `InteractiveViewer` (pan + zoom, `boundaryMargin` amplio, `minScale`/`maxScale` acotados) para que el jugador pueda desplazarse en vez de que se recorte o desborde.
3. Actualizar `BoardDropTarget` para leer el mismo tamaño de celda calculado (no la constante fija), de modo que el hit-testing del drag-and-drop siga coincidiendo con lo que se ve en pantalla.

---

## 3. P1 — Fidelidad visual en `BattleStage` (pantalla de batalla)

Comparando `DesktopBattle.png` vs `mobileBattle.png` + `mobile/lib/presentation/widgets/battle_stage.dart`:

### 3.1 Avatares circulares vs cuadrados
- **Web** (`.battle-attacker-avatar` / `.battle-defender-avatar`, `border-radius: 10px` / `9px`): retratos **cuadrados con esquina redondeada**, no círculos.
- **Mobile**: `CircleAvatar` en `_AttackerCard` (`battle_stage.dart:418-421`) y `_DefenderCard` (`battle_stage.dart:500-503`) — círculos. Esta es la diferencia más visible entre ambas capturas de batalla.
- **Fix**: reemplazar `CircleAvatar` por `Container` + `ClipRRect(borderRadius: BorderRadius.circular(9-10))` + `Image.asset(fit: BoxFit.cover)` — el mismo patrón que ya usa `PlayerHud._Portrait` en `mobile/lib/presentation/widgets/player_hud.dart:52-68` (portada cuadrada con `BoxFit.cover`, sin distorsión). No hace falta inventar nada nuevo, solo reutilizar ese patrón aquí.

### 3.2 Tarjeta del atacante
- **Web**: fondo degradado madera `linear-gradient(160deg, var(--wood-light), var(--wood-dark))`, borde dorado 3px, `border-radius: 14px`.
- **Mobile** (`battle_stage.dart:397-404`): fondo sólido `AppColors.iron`, borde `AppColors.accent` (rojo-naranja) de 1-2px, `borderRadius: 10`.
- **Fix**: cambiar a
  ```dart
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [AppColors.woodLight, AppColors.woodDark],
    ),
    border: Border.all(color: AppColors.gold, width: 3),
    borderRadius: BorderRadius.circular(14),
  ),
  ```
  — coherente con `_StatTile` en `player_hud.dart:246-251`, que ya usa exactamente ese degradado en otra parte de la app.

### 3.3 Fondo del overlay de batalla
- **Web**: `rgba(15,9,5,.94)` — un scrim oscuro marrón-negruzco, no textura de madera (esto es intencional en el propio diseño web, no un tablero con madera detrás).
- **Mobile** (`battle_stage.dart:295`): `Colors.black87` — negro puro al 87%. Aproximación razonable pero no exacta.
- **Fix opcional (prioridad baja)**: cambiar a `Color(0xF00F0905)` para calzar el tono marrón-negro exacto.

### 3.4 Estados de fila (P2, pulido opcional, no bloqueante)
- Web aplica `filter: grayscale(0.85)` a jugadores eliminados y `border-style: dashed` + `opacity: 0.4` a la fila del atacante actual.
- Mobile solo baja la opacidad a 0.4 para `isDead` (sin escala de grises) y tiñe el fondo para `isAttacking` (sin borde punteado).
- Si se quiere paridad exacta: envolver el avatar en `ColorFiltered` con una matriz de escala de grises para `isDead`, y usar un borde punteado simple (hay paquetes ligeros o un `CustomPainter` corto) para `isAttacking`.

---

## 4. Lo que YA es fiel a la web (no tocar)

Para no perder tiempo "arreglando" cosas que ya están bien:

- **`MarketPanel`** (`market_panel.dart`) ya usa `marketFrame.png` con `AspectRatio(1063/288)` y las mismas fracciones de grid que el CSS original (`210fr 30fr 213fr 36fr 216fr 33fr 207fr`, medidas directamente sobre el arte de 1063×288px). Es una réplica muy precisa, no requiere cambios de layout.
- **`PlayerOrderRow`** usando `CircleAvatar` es correcto — la web también renderiza esos mini-avatares de orden de turno como círculos (`.player-order-row` avatar, `border-radius: 50%`, 42×42px). No confundir con el punto 3.1 (que es sobre `BattleStage`, una pantalla distinta).
- **El "achatamiento" de `opponentBoardButton.png`** (183×223 nativo) dentro de una caja cuadrada de 66×66 (`_topBox`), y el de `panelSquare.png` (245×255) dentro de un `AspectRatio(1)` — **no son bugs introducidos por mobile**. La propia web fuerza esos mismos assets no-cuadrados dentro de cajas cuadradas de 180px (`--topbox-size`, `aspect-ratio: 1/1`, `background-size: 100% 100%` en `styles.css`). Es una imperfección heredada del diseño original y mobile ya la replica fielmente — "corregirla" divergiría de la web, que es justo lo que no se quiere.
- **`_BorderPole`** (`match_screen.dart:404-413`, `fit: BoxFit.fill`, alto variable) estirando verticalmente el poste de madera también es intencional y calca el propio CSS (`.border-pole { height: 100%; object-fit: fill }`).
- **`CardView`/`_CornerCell`** (`card_view.dart`) usa `BoxFit.cover` sobre celdas ya cuadradas (vía `Expanded` en una grilla 2×2) — solo recorta, no distorsiona, igual que en web.

**Conclusión sobre distorsión de imágenes (corregida en la ronda 2)**: la primera pasada de este análisis solo auditó usos explícitos de `BoxFit.fill`/`DecorationImage`, y por eso pasó por alto la distorsión real que sí existía: las cartas del market se veían "achatadas" (rectangulares, no cuadradas) porque el badge de precio ocupaba su propia fila dentro del mismo `Column` que la carta, robándole altura a un `CardView` cuyo tamaño era `double.infinity` (se estira a lo que le den, sin forzar cuadrado). Ese no es un caso de `BoxFit` mal usado, es un caso de *layout* — el contenedor de la carta terminaba siendo un rectángulo, no un cuadrado. Ver sección 8 para el fix real aplicado.

---

## 5. Punto a verificar en dispositivo (no se puede confirmar solo leyendo código)

En `mobileLayout.png`, la caja del timer (arriba-izquierda) y la de "OPPONENT BOARD" (arriba-derecha) se ven como rectángulos planos oscuros, **sin** la textura de madera/metal que sí se ve claramente en el marco de "MARKET" en la misma captura. Sin embargo, el código de `TurnTimer` (`turn_timer.dart:130-136`) y del botón de oponente (`match_screen.dart:236-241`) sí referencian `panelSquare.png` / `opponentBoardButton.png` como fondo — exactamente igual que `MarketPanel` referencia `marketFrame.png`. Los tres archivos existen en `assets/attributesImg/boardElements/` y no están corruptos (tamaños de archivo normales, 87KB-572KB).

Esto sugiere que la captura podría ser de un build ligeramente anterior al estado actual del código, o hay un problema puntual de carga en esos dos widgets específicos que no se puede diagnosticar solo por lectura de código. **Acción**: al implementar los fixes de arriba, validar visualmente en el emulador/dispositivo si el timer y el botón de oponente ya muestran la textura correctamente; si no, comparar su renderizado contra el de `MarketPanel` (mismo patrón `DecorationImage` + `BoxFit.fill`) para aislar la diferencia.

---

## 6. Plan de implementación sugerido (fases)

1. **Fase 1 (P0)** — arreglar el overflow del tablero: `LayoutBuilder` dinámico en `BoardView`/`_boardZone` (+ fallback `InteractiveViewer` si aun así no cabe); sincronizar `BoardDropTarget` con el nuevo tamaño de celda.
2. **Fase 2 (P1)** — en `BattleStage`: avatares cuadrados reutilizando el patrón de `PlayerHud._Portrait`; degradado madera + borde dorado en `_AttackerCard`.
3. **Fase 3 (P2, opcional)** — pulido de estados de fila en batalla (escala de grises, borde punteado), afinar color exacto del scrim.
4. **Fase 4** — verificación visual en emulador/dispositivo de las 5 pantallas contra las capturas originales, con atención especial al punto 5 (timer/opponent-board sin textura).

## 7. Checklist de verificación final (para cuando se implemente)

- [x] Ningún banner de overflow en tableros con 1, 2 y 4+ filas de cartas jugadas, en portrait y landscape.
- [x] `BattleStage`: avatares cuadrados con esquinas redondeadas, degradado madera + borde dorado en la tarjeta del atacante.
- [ ] Timer y botón de oponente muestran la textura de `panelSquare.png` / `opponentBoardButton.png`, igual que el marco de "MARKET" — sigue pendiente de verificar en dispositivo (sección 5).
- [x] Ninguna imagen nueva se introduce con `BoxFit.fill` sobre una caja de aspecto distinto al nativo del asset (salvo los casos ya documentados como heredados de la web).
- [x] Cartas del market cuadradas (no achatadas) — ver 8.1.
- [x] Tablero con tamaño de celda usable, no diminuto — ver 8.2.
- [x] Roster de batalla en columna vertical, no en fila — ver 8.3.

---

## 8. Ronda 2 — lo que la primera pasada se saltó

La primera implementación corrigió forma/color de avatares, degradado del atacante, y envolvió el tablero en un `FittedBox` — pero eso no atacaba tres problemas de **layout** que Antonio señaló al ver el resultado real y que sí estaban documentados en las capturas originales pero mal priorizados/pasados por alto en el análisis inicial.

### 8.1 Cartas del market "achatadas" (rectangulares, no cuadradas)

**Causa**: `_MarketSlot`/`_DeckSlot` en `market_panel.dart` ponían el `CardView` (o el card-back) y el `_CostBadge` de precio en el mismo `Column`, con la carta en un `Expanded`. El slot completo es una franja mucho más ancha que alta (recortada de `marketFrame.png`, una banda horizontal), así que casi no sobra alto: al reservarle su propia fila al badge de precio, el `Expanded` de la carta se quedaba con un rectángulo bajo y ancho — `CardView` usa `size: double.infinity` (se estira a lo que le den, sin forzar cuadrado), así que la grilla 2×2 de íconos terminaba achatada.

**Fix aplicado (superado en la ronda 4, ver 10.2)**: la carta ahora se dibuja centrada dentro de un `AspectRatio(aspectRatio: 1)` (siempre cuadrada, usa el lado más chico de ancho/alto disponibles), y el badge de precio se dibuja **flotando encima** con `Stack` + `Positioned(bottom: 0)` en vez de ocupar su propia fila en el `Column`. Esto es exactamente lo que se pidió: el botón ya no le quita espacio a la carta.

### 8.2 Tablero "ridículamente pequeño"

**Causa real** (más allá del overflow ya arreglado): `boardCellSize` era `40px`, bastante más chico que el `56px` que usa la propia web (`.board-cell` en `styles.css`). Con solo 1-2 cartas puestas, el tablero renderizado (que solo dibuja el bounding box exacto de las cartas ya colocadas, no todo el espacio disponible) terminaba siendo una mancha diminuta de ~80-112px en medio de un panel de madera enorme, dificultando ver/tocar dónde colocar la siguiente carta.

**Fix aplicado**: `boardCellSize` subido a `56px` (paridad exacta con la web). El `FittedBox(scaleDown)` de la ronda 1 se mantiene como red de seguridad — solo entra en acción (encogiendo celdas) cuando un clúster de cartas ya colocadas es tan grande que no entra en el espacio disponible; para el caso normal (pocas cartas) el tablero ahora se ve — y se toca — notablemente más grande que antes.

### 8.3 Roster de batalla en fila, no en columna

**Causa**: `BattleStage`'s defenders usaban un `Wrap` (que por defecto fluye horizontalmente, envolviendo a una nueva línea solo si no entra) — visualmente eso pone a todos los jugadores en fila. La web usa `.battle-defenders` como una **columna vertical fija** (una posición estable por jugador, nunca se reacomoda).

**Fix aplicado**: reemplazado el `Wrap` por un `Column` (dentro del mismo `SingleChildScrollView` que ya existía, para que 4 tarjetas altas en una pantalla landscape corta puedan scrollear en vez de desbordar) — ahora los jugadores se apilan verticalmente, como en la referencia web.

### Verificación (rondas 1-2)

`flutter analyze` sin issues y `flutter build apk --debug` exitoso después de cada tanda de cambios. No se ejecutaron tests ni se corrió la app en emulador/dispositivo.

---

## 9. Ronda 3 — la causa raíz real del tablero pequeño, y limpieza del HUD

### 9.1 Causa raíz real de "el tablero es dolorosamente diminuto"

El `boardCellSize` a 56px (ronda 2) solo ayuda si la zona del tablero (`Expanded(child: _boardZone())` en `match_screen.dart`) realmente recibe suficiente alto. Investigando por qué no era así: `_matchTop` (fila superior: timer | market | botón oponente + `PlayerOrderRow`) le daba a `PlayerOrderRow` un ancho de solo `_topBox + 24 = 90px`. Cada avatar mide 32px (radio 16) + 6px de espaciado — con 3 o 4 jugadores (el caso más común) eso **no entra en una sola línea** (4 avatares necesitan ~150px), así que la fila se envolvía a 2 líneas, y esas 2 líneas hacían que toda la columna "botón oponente + orden de turno" (antes ~173px) fuera mucho más alta que el market (92px). Como `_matchTop` es un `Row` sin stretch, su altura real termina siendo la del hijo más alto — es decir, la banda superior completa se inflaba muy por encima de lo que sugerían las constantes del código, robándole al `Expanded` del tablero casi todo el espacio vertical disponible. Este era el bug real detrás de "por alguna razón ocupa una row con una altura muy pequeña".

**Fix aplicado** (`match_screen.dart`):
- Se ensanchó el contenedor de `PlayerOrderRow` a `_topBox + 90 = 156px` — suficiente para que hasta 4 avatares entren en una sola línea en el caso normal.
- Se le puso además un techo duro: `SizedBox(height: _orderRowHeight = 34)` + `FittedBox(fit: BoxFit.scaleDown)` alrededor de `PlayerOrderRow`, para que aunque hubiera más jugadores o nombres más largos, la fila se achique en vez de volver a inflar la banda superior. Con esto, la altura de `_matchTop` queda acotada y predecible (~103px, muy cerca del market), y el tablero recibe el resto de la pantalla de forma consistente partido a partido.

### 9.2 Line de estado "Round X · Turn — Your turn, pick a card" eliminada

Confirmado innecesaria — el timer ya indica de quién es el turno. Se quitó por completo el método `_statusLine` y su fila del `Column` en `match_screen.dart`. Los botones de **mute** y **Leave** que vivían ahí se movieron a la esquina inferior derecha del HUD de la mano (`_handSlot`, dentro de un `Stack`/`Positioned`), tal como se pidió. Esto libera además el espacio vertical que esa línea ocupaba, en favor del tablero.

### 9.3 Market: más alto, cartas más grandes, badge de precio ya no tapa la carta

- `_marketHeight` subido de 92 a 104px (feedback: "hacerla ligeramente mayor para que las cartas puedan ser más grandes").
- El badge de precio/"Free" ya no flota completamente encima de la carta (eso todavía tapaba los íconos de las esquinas inferiores). Se creó `_SquareCardWithBadge` (`market_panel.dart`) que reserva una franja fija de 20px en la parte de abajo del slot para el badge — la carta se sigue calculando cuadrada (`AspectRatio(1)`) pero usando el alto restante después de esa reserva, así que el badge queda **debajo** de la carta sin compartir fila en un `Column` (que era lo que la achataba en la ronda 1) ni superponerse a ella.

### 9.4 HUD inferior pegado al borde

El `Column` principal ya no tiene la línea de estado entre el tablero y la barra inferior — la barra inferior (retrato + stats + mano) es ahora el último elemento antes de cerrar el `Column`, con el `Expanded` del tablero absorbiendo todo el espacio sobrante, así que queda pegada al borde inferior de la `SafeArea` sin holgura extra.

### 9.5 Timer: tamaño constante

El timer ya estaba en un `SizedBox(width: _topBox, height: _topBox)` fijo (66×66), así que su caja nunca cambiaba de tamaño; lo que sí cambiaba antes (indirectamente) era cuánto espacio ocupaba *todo el resto de la fila* a su lado (ver 9.1), lo cual podía dar la sensación de que "algo" en esa banda era inconsistente partido a partido. Con la altura de `_matchTop` ahora acotada, la fila entera es estable independientemente del número de jugadores.

### Verificación (ronda 3)

`flutter analyze` sin issues y `flutter build apk --debug` exitoso. No se ejecutaron tests ni se corrió la app en emulador — la verificación visual real sigue pendiente de que Antonio la corra en su dispositivo.

---

## 10. Ronda 4 — probado en vivo en un emulador Android

A pedido de Antonio ("puedes ejecutarlo tú para que lo veas por tu cuenta"), esta ronda se verificó corriendo la app de verdad: backend local (`mvn spring-boot:run`, ya estaba corriendo) + `flutter run -d emulator-5554` en un emulador Android, jugando partidas reales contra bots ("Play vs bots") y capturando pantallazos (`adb exec-out screencap`) en cada paso.

### 10.1 Color dorado del timer — confirmado arreglado

Comparado contra `frontend/src/components/online/TurnTimer.tsx` + `styles.css:746-760` (`.turn-timer-yours .turn-timer-label`: dorado, más grande, bold, con glow; cae a rojo si además `turn-timer-low`). El fix de `turn_timer.dart` (texto "Your turn!" en `AppColors.gold` con sombra, tamaño 15 vs 12 normal, cayendo a `AppColors.bad` si quedan ≤10s) se confirmó visualmente: en la captura en vivo el texto "Your turn!" se ve claramente dorado y más grande que antes.

### 10.2 Market: bug real encontrado y corregido gracias a la prueba en vivo

Al ver el market corriendo, la carta se veía diminuta con un badge de precio desproporcionadamente grande tapando más de la mitad de la carta — mucho peor de lo esperado según el fix de la ronda 2. Midiendo colores píxel-por-píxel sobre la captura real (`iron` `0xFF2B241F` para identificar el borde exacto de la carta) se encontró la causa: `_SquareCardWithBadge` devolvía un `Stack` con un `SizedBox(height: cardHeight)` (la carta, ya achicada para "dejarle lugar" al badge) como único hijo *no posicionado*, y el badge como `Positioned(bottom: 0)`. Un `Stack` sin restricciones ajustadas se dimensiona según sus hijos **no posicionados únicamente** — así que todo el `Stack` terminaba con la altura de la carta encogida, y el badge "de abajo" en realidad se dibujaba superpuesto sobre el borde inferior de esa carta ya chica, no debajo de ella en el espacio que se creía reservado.

**Fix aplicado**: `_SquareCardWithBadge` ahora envuelve el `Stack` en un `SizedBox(width/height: constraints.maxWidth/maxHeight)` explícito (ocupa el slot completo de verdad), la carta usa el slot casi entero (`AspectRatio(1)` sin recorte para el badge), y el badge de precio pasó a ser un **chip pequeño anclado a la esquina inferior derecha** (`Positioned(bottom: -4, right: -4)`, con `Stack(clipBehavior: Clip.none)`), no una franja que reserva su propia fila. Esto coincide con lo pedido: la carta ahora cubre prácticamente todo el slot y sus 4 íconos son claramente visibles; el badge solo tapa una esquina, no una banda entera. Confirmado con capturas antes/después — cambio dramático, cartas grandes y nítidas, badge discreto.

### 10.3 Pantalla de batalla — confirmado arreglado visualmente

Capturas en vivo de "Battle — round N" muestran avatares cuadrados con esquina redondeada (no círculos) tanto para el atacante como los defensores, y la tarjeta del atacante con el degradado madera + borde dorado — coincide con `DesktopBattle.png`.

### 10.4 Bug del tablero ("no se puede colocar una carta arriba de cierto punto") — NO confirmado

Se jugaron dos partidas completas contra bots, recogiendo y arrastrando cartas repetidamente (`adb shell input swipe` desde la carta en mano hasta distintas posiciones del tablero, con `Confirm` explícito cuando aparecía el preview verde). Resultado: el tablero propio se mostró consistentemente con **una sola carta** (4 celdas) ronda tras ronda — nunca se acumularon 2+ cartas visualmente pese a colocar exitosamente al menos una carta por ronda (se vio el preview verde + botones Confirm/Cancel, y tras confirmar el HUD volvía a "Empty hand"). Los arrastres hacia posiciones más alejadas (para forzar crecimiento hacia arriba) fallaban con más frecuencia en registrarse como un drag válido que los arrastres cortos hacia el centro del tablero.

No se pudo determinar con certeza si esto refleja: (a) que el tablero de este juego se reconstruye cada ronda por diseño (no es una torre acumulativa) y el reporte de Antonio se refiere a otra situación específica (partida más avanzada, ronda final, etc.), o (b) una limitación de la simulación de arrastre por `adb` (gestos sintéticos que no siempre disparan el reconocimiento de `Draggable` de Flutter en posiciones alejadas), o (c) un bug real en cómo se acumulan/persisten las colocaciones. El personaje de prueba murió por daño de los bots antes de poder profundizar más. **Este punto queda abierto** — se necesitan pasos de reproducción más específicos de Antonio (¿en qué ronda aproximadamente pasa? ¿la partida es contra bots u online? ¿el tablero ya tenía cuántas cartas cuando falló?) para diagnosticarlo con confianza en vez de adivinar un fix.

### Verificación (ronda 4)

Cambios de la sección 10.2 verificados con `flutter analyze` (sin issues) y `flutter build apk --debug` (compila), además de la propia prueba en vivo en el emulador (screenshots antes/después). El punto 10.4 sigue sin verificar ni arreglar — pendiente de más información.

---

## 11. Ronda 5 — causa raíz real del bug de colocación, y estadísticas de batalla al costado

### 11.1 "No se puede colocar una carta arriba de cierto punto" — causa raíz encontrada

Antonio precisó el bug: pasa específicamente cuando la carta nueva se ancla por sus esquinas **inferiores** contra las esquinas **superiores** de una carta ya puesta — es decir, el tablero crece hacia arriba (mayor Y, más cerca del market) — y tras un par de cartas colocadas así, ya no es posible seguir subiendo.

**Causa real**: desajuste de coordenadas entre `BoardView` (`board_view.dart`) y `BoardDropTarget._computeCandidate` (`board_drop_target.dart:143` antes del fix). `BoardView` calcula los límites de su propia grilla renderizada así:
```dart
final boundsSource = preview.isNotEmpty ? [...points, ...preview] : points;
final bounds = computeBoardBounds(boundsSource)!;
```
— es decir, incluye los puntos de la **vista previa** (preview) que se está arrastrando en ese momento, no solo las cartas ya confirmadas. Cuando el preview crece el tablero hacia arriba (nueva fila con mayor Y), la grilla renderizada agrega esa fila arriba y el origen local (0,0) de `_latticeKey` — el punto de referencia que usa `globalToLocal` para convertir la posición del dedo — se corre hacia arriba con ella.

`BoardDropTarget._computeCandidate`, en cambio, calculaba sus propios límites solo a partir de `widget.points` (las cartas **ya confirmadas**, sin el preview):
```dart
final bounds = computeBoardBounds(widget.points); // ¡no incluía el preview!
```
Como el arrastre dispara `_computeCandidate` en cada movimiento del dedo, y `BoardView` ya se había re-renderizado con la fila extra del preview del movimiento anterior, cada cálculo subsiguiente interpretaba `local` (ya relativo al origen *nuevo*, más alto) usando límites (`bounds.maxY`) *viejos* — el resultado (`fy`) queda corrido exactamente por la cantidad de filas que el preview ya agregó. Cuantas más cartas se hayan apilado hacia arriba en rondas previas, mayor el corrimiento acumulado, hasta el punto de que el candidato calculado ya no cae cerca de ningún punto real válido y la colocación deja de funcionar — coincide exactamente con "tras un par de cartas, ya es imposible colocar más arriba".

**Fix aplicado** (`board_drop_target.dart:_computeCandidate`): los límites ahora se calculan igual que en `BoardView` — cartas reales **más** el preview actualmente renderizado (`widget.pendingPreviewPoints ?? _candidate?.previewPoints`) — así ambos widgets están siempre de acuerdo sobre dónde está el origen de la grilla durante todo el arrastre.

### 11.2 Estadísticas de los defensores de batalla — ahora al costado, no debajo

**Pedido**: mover HP/PD/MD a la derecha del avatar en vez de debajo, para que cada fila del roster ocupe menos alto y no se salga de pantallas cortas en landscape.

**Fix aplicado** (`battle_stage.dart:_DefenderCard`): la tarjeta pasó de un `Column` (avatar, nombre, HP, PD/MD, apilados verticalmente — la altura total era avatar + 4-5 líneas de texto) a un `Row`: avatar a la izquierda (40×40), y a la derecha una columna angosta de solo 2 líneas (nombre arriba, HP+PD+MD todos en una fila abajo). El ancho de la tarjeta subió de 96 a 172px (hay de sobra en el roster horizontal) pero el alto se redujo a poco más que el propio avatar. La etiqueta "attacking" pasó de su propia línea de texto a un pequeño "ATK" junto al nombre, y el 💀 de eliminado pasó de su propia línea a una insignia pequeña en la esquina del avatar (mismo patrón que la insignia de primer turno en `PlayerOrderRow`) — ninguno de los dos necesita ya su propia fila.

### Verificación (ronda 5)

`flutter analyze` sin issues y `flutter build apk --debug` exitoso. **No se probó en el emulador** — a pedido explícito de Antonio ("ya no pruebes tú el emulador ya que gasta muchos recursos"), así que ni el fix de coordenadas del tablero ni el nuevo layout de `_DefenderCard` fueron verificados visualmente todavía. Ambos quedan pendientes de que Antonio los pruebe en su dispositivo.

---

## 12. Ronda 6 — probado en dispositivo real por Antonio: crash de audio, subrayado en batalla, tablero sigue pendiente

### 12.1 Crash de audio (`AudioPlayers Exception... MEDIA_ERROR_UNKNOWN`) — causa real y fix aplicado

**Síntoma**: al tocar una carta del market (Antonio reporta haber tocado la carta en sí, no el badge "Free" — aunque desde la ronda 4 toda el área del slot es un único `InkWell`, así que tocar en cualquier parte debería comportarse igual), la consola mostró una excepción no capturada del reproductor de audio, y después ya no pudo tomar la carta.

**Causa real**: `Sfx.play()` (`sfx.dart:111-132`) ya tenía un `try/catch` alrededor de la llamada a `player.play(...)` — pero ese `try/catch` solo atrapa errores que ocurren *durante* esa llamada. Fallas de decodificación de `audioplayers`/ExoPlayer en Android suelen reportarse de forma asíncrona, en un callback del canal de plataforma que llega **después** de que el `Future` de `play()` ya se resolvió — sin ningún `await` de por medio que el `try/catch` pueda envolver. Por eso el error se escapaba como una "Unhandled Exception" a nivel de toda la app.

**Fix aplicado** (`main.dart`): se envolvió todo `main()` en `runZonedGuarded`, una red de seguridad global de Dart para exactamente este tipo de error asíncrono sin dueño — cualquier excepción que se escape (de audio o de cualquier otra cosa) ahora se registra en consola y la app sigue funcionando, en vez de dejar un error "flotando" que podía dejar al reproductor de audio (o algo relacionado) en un estado raro. Si "ya no pude tomar la carta" era un efecto secundario de ese estado roto (no solo la ruidosa traza en consola), esto debería resolverlo también — aunque también es posible que en ese instante específico no fuera su turno o la carta ya no estuviera disponible, algo que esta captura de errores no puede diagnosticar por sí sola.

### 12.2 Subrayado amarillo/punteado en toda la fase de pelea

Se buscó `TextDecoration` en **todo** `mobile/lib` (no solo `battle_stage.dart`) y no apareció ni una sola vez — ningún `TextStyle` del código pone explícitamente un subrayado. Tampoco aparece nada de `text-decoration`/`underline` en el CSS de referencia del frontend web. Esto sugiere que el subrayado observado probablemente **no viene del código de la app**, sino de algo a nivel de sistema operativo/dispositivo (por ejemplo, una función de accesibilidad de Android como "Texto en negrita"/alto contraste, u otra herramienta de depuración activa en el teléfono) — algo fuera del control directo del código Flutter.

**Fix aplicado de todas formas** (`battle_stage.dart`): se envolvió todo el contenido de `BattleStage` en un `DefaultTextStyle.merge(style: TextStyle(decoration: TextDecoration.none))`, forzando explícitamente "sin subrayado" en cada `Text` de esa pantalla. Es una red de seguridad defensiva y segura — si el subrayado viniera de algún estilo heredado que no encontré, esto lo anula; si viene de una función del sistema operativo, esto no podrá arreglarlo (habría que revisar Ajustes → Accesibilidad en el propio dispositivo).

### 12.3 Bug del tablero cerca del market — sigue reportado, requiere confirmar con build limpio

El fix de la ronda 5 (sección 11.1) apunta exactamente al síntoma que Antonio describió (esquinas inferiores de la carta nueva contra esquinas superiores de la vieja, creciendo hacia el market). Se revisó de nuevo el código para confirmar que no falta ningún otro lugar con el mismo desajuste de límites (`grep` de `computeBoardBounds` en todo `mobile/lib` — solo hay dos usos, `BoardView` y `BoardDropTarget`, y ambos ya quedaron sincronizados) y se revisó también `card.dart`/`corner_name.dart` (la matemática de a qué celdas corresponde cada corner) sin encontrar ningún límite artificial de altura ahí.

Dado que no se puede probar en el emulador, **no se puede confirmar si el fix de la ronda 5 ya resolvió esto o no** solo por lectura de código. Si el bug persiste después de un build realmente nuevo (parar `flutter run`/desinstalar y volver a instalar, no solo hot reload — un hot reload no siempre aplica bien cambios de lógica de estado como este), sería una señal fuerte de que hay una causa adicional (posiblemente del lado del servidor Java, en `BoardEngine`, que no se revisó en esta ronda) y valdría la pena describir con más detalle en qué momento exacto falla (¿cuántas cartas tenía el tablero? ¿el drop no muestra el preview verde, o lo muestra pero el Confirm no funciona?).

### Verificación (ronda 6)

`flutter analyze` sin issues y `flutter build apk --debug` exitoso tras el fix de `main.dart` y la reestructuración de `battle_stage.dart`. No se probó en el emulador (instrucción explícita de Antonio de no seguir usándolo).

---

## 13. Ronda 7 — el bug del tablero resuelto y confirmado, y reestructuración simétrica del layout

### 13.1 Causa real de "no puedo hacer una torre" — encontrada, arreglada y confirmada en vivo

Antonio explicó el mecanismo con precisión: para apilar una carta encima de otra, hay que poder soltar la carta nueva por *encima* de la carta más alta actual del tablero. El problema es que, conforme la torre crece, esa posición "un poco más arriba" termina literalmente a la altura del `MARKET` — y esa franja de pantalla nunca fue parte del área interactiva (`DragTarget`) del tablero, es del widget del market. El fix de coordenadas de la ronda 5 (sección 11.1) era necesario pero no suficiente: incluso con las coordenadas bien sincronizadas, si el `FittedBox` que escala el tablero llega a usar el 100% de la altura de su contenedor (porque la torre ya es alta), no queda ningún píxel "de sobra" *dentro de esa misma zona interactiva* para señalar "quiero un punto más arriba" — cualquier intento de arrastrar más arriba se sale directo hacia el market.

**Fix aplicado** (`board_drop_target.dart`): se envolvió el `FittedBox` en un `Padding` fijo (28px vertical, 16px horizontal) dentro del mismo `DragTarget`. Así el contenido renderizado (ya escalado) nunca puede tocar los bordes de su propio contenedor — siempre queda un margen real, dentro de la misma zona interactiva, para arrastrar por encima de la fila más alta actual.

**Confirmado en vivo**: se corrió el emulador con este fix, se armó una torre de 3 cartas (6 filas) jugando contra bots, y Antonio confirmó directamente: "el margen funciona".

**Efecto secundario reportado**: las cartas del tablero se ven más chicas ahora, porque el padding le resta espacio útil al `FittedBox`. Esto se atiende indirectamente en 13.2 (reestructurar el layout para darle más espacio al tablero en general), no reduciendo el padding (que es justo lo que arregló el bug).

### 13.2 Reestructuración simétrica: HUD del jugador y de la mano a los costados del tablero

A partir de la ronda 7, Antonio pidió explícitamente **dejar de usar el emulador** (consume muchos recursos y no ayuda tanto para este tipo de cambio) y en su lugar una reestructuración de layout más grande, en dos pasos:

1. Mover el HUD de la mano (carta en mano + botón Rotate) de la barra inferior a una columna angosta a la **derecha** del tablero, dentro de la misma fila (`_boardZone`).
2. Los botones de mute y Leave, que vivían en la esquina del HUD de la mano, se movieron **debajo del timer** (arriba-izquierda).
3. Con eso ya implementado, el tablero seguía siendo "una fila, más ancho que alto" — Antonio pidió el paso final: mover también el HUD del jugador (retrato + stats) a una columna simétrica a la de la mano, pero a la **izquierda** del tablero, **dentro de la misma fila** — eliminando la barra inferior separada por completo, para que el tablero ocupe también esa altura.

**Fix aplicado**:
- `match_screen.dart`: `_boardZone` ahora es `Row[pole, PlayerHud (ancho _handColumnWidth), board (Expanded), hand panel (ancho _handColumnWidth), pole]` — una sola fila, sin barra inferior aparte. La constante `_bottomBarHeight` se eliminó (ya no hay barra inferior); `_handColumnWidth = 132` se reusa para ambas columnas laterales, así quedan simétricas.
- `player_hud.dart`: `PlayerHud` pasó de `Row` (retrato al lado de las stats, pensado para una barra ancha y baja) a `Column` (retrato arriba, stats abajo, pensado para una columna angosta y alta — el espejo de cómo ya estaba armado el HUD de la mano). `_StatGrid` perdió su ancho fijo de 150px (ahora toma el ancho que le da la columna, 132px) y `_StatTile` se hizo un poco más compacto (íconos e texto más chicos) para que las 2 celdas por fila quepan cómodas en esa columna más angosta.

### Verificación (ronda 7)

El fix de 13.1 se probó en vivo en el emulador y Antonio lo confirmó funcionando. El fix de 13.2 (la reestructuración simétrica) se verificó **solo con `flutter analyze` (sin issues) y `flutter build apk --debug` (compila)** — sin emulador, siguiendo la instrucción explícita de Antonio. Queda pendiente que lo vea corriendo en su propio dispositivo antes de darlo por confirmado visualmente.

---

## 14. Ronda 8 — el preview de colocación ahora tiene un umbral de distancia, y tres pulidos más

### 14.1 Preview y snap con umbral de distancia

**Pedido**: mientras se arrastra una carta, el preview verde de dónde quedaría no debería aparecer hasta que el arrastre esté realmente cerca de su posición final; y para que la carta quede pegada al soltar, tiene que estar cerca de las demás cartas del tablero, no en cualquier parte del tablero.

Esto es literalmente lo opuesto a una decisión de diseño anterior documentada en el propio código: `board_drop_target.dart` explicaba que un intento previo de exigir cercanía ("gated radius") fue lo que causó el bug "no puedo colocar la siguiente carta" en un dispositivo real, así que se había quitado por completo cualquier umbral (el punto ocupado más cercano era siempre el objetivo, sin importar qué tan lejos estuviera el dedo). Ese bug viejo, sin embargo, es anterior al fix de coordenadas de la ronda 5 — con las coordenadas ya exactas y el tamaño de celda en 56px (paridad con la web), reintroducir un umbral generoso ya es seguro.

**Fix aplicado**: se agregó `_snapRadius = 1.5` (en unidades de celda del tablero, un poco más que la diagonal de una celda). `_computeCandidate` ahora descarta el candidato por completo (sin preview, sin drop válido) si el punto ocupado más cercano queda a más de `_snapRadius` celdas de distancia — esto gobierna tanto el preview (se actualiza en cada movimiento del dedo) como la aceptación del drop (usa el mismo cálculo), así que ambos comportamientos pedidos quedan cubiertos por el mismo cambio.

### 14.2 Botón "Confirm" desbordado

El panel de la mano (columna angosta de la ronda 7, ~132px de ancho) es más angosto de lo que los botones `FilledButton.icon`/`OutlinedButton.icon` por defecto de Material esperaban — el texto "Confirm" se envolvía a 2 líneas y el botón se salía un poco del panel. En `action_buttons.dart` se quitaron los íconos, se usó texto más chico (13px), y un estilo compacto (`minimumSize: Size.zero`, `tapTargetSize: shrinkWrap`) — ambos botones ahora ocupan el ancho completo del panel en una sola línea.

### 14.3 Tableros de oponentes: encoger en vez de hacer scroll

**Pedido**: al ver el tablero de un oponente en el modal, si es grande no debería hacer falta scroll para verlo completo — que se encoja para ocupar siempre el mismo espacio, igual que ya se hizo con el tablero propio.

**Fix aplicado** (`opponents_modal.dart`): el `BoardView` del oponente seleccionado ya no vive dentro de un `SingleChildScrollView` — ahora está en un `Expanded` + `FittedBox(fit: BoxFit.scaleDown)`, exactamente el mismo patrón que ya se usa para el tablero propio en `board_drop_target.dart`. Cualquier tablero de oponente, sin importar su tamaño, se escala para ocupar siempre la misma área disponible del modal.

### Verificación (ronda 8)

`flutter analyze` sin issues y `flutter build apk --debug` exitoso. **No se probó en el emulador** — instrucción explícita de Antonio de no seguir revisando el layout ahí ("te demoras mucho y realmente no puedes comprender bien lo que sucede"). Los tres cambios quedan pendientes de verificación visual/funcional en el dispositivo de Antonio, en particular el umbral de distancia (14.1) que es el que más se beneficia de probarse jugando de verdad — si `_snapRadius = 1.5` resulta muy exigente o muy laxo en la práctica, es el primer número a ajustar.
