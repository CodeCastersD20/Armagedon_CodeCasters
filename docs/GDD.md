# ARMAGEDDON — Game Design Document

Versión 0.2 (beta) · Motor: Godot 4 (3D, GDScript) · Equipo CodeCasters

Tablero de tarjetas: [Armagedon kanban](https://github.com/orgs/CodeCastersD20/projects/3)

> **Alcance:** desarrollo rápido, menos de un mes. Se hace lo mínimo que sea entretenido y cumpla los requisitos. Todos los números están sujetos a cambios tras pruebas.
>
> Convención: **[PENDIENTE]** = falta definir. **[FUTURO]** = fuera de la beta.

---

## 1. Visión general

**Armageddon** es un roguelike shooter en primera persona de supervivencia por oleadas, con estética low-poly PSX. El jugador es el Arcángel Zahariel, atrapado en el Infierno. Sobrevive a hordas cada vez más fuertes, compra mejoras entre rondas y desciende por los círculos del Infierno hasta enfrentar a Lucifer.

| Campo | Valor |
|---|---|
| Género | Roguelike + shooter en primera persona (fuego y melee) |
| Público | +16 |
| Plataforma | PC |
| Motor | Godot 4, GDScript |
| Referencias | ULTRAKILL, DOOM, Dusk |
| Partida | Rondas sin límite de tiempo (cronómetro ascendente), sin progreso entre partidas, rejugable |

**Pilares**
1. **Movimiento constante** y combate rápido.
2. **Una arma a la vez**, intercambiable en cada descanso.
3. **Builds distintas** por la oferta aleatoria de la tienda.
4. **Estética PSX unificada** con un shader y resolución bajos.
5. **Alcance mínimo**: pocos sistemas, bien hechos.

---

## 2. Historia y ambientación

El Infierno se desbordó y una horda subió a la Tierra. El Cielo envió a sus huestes; la guerra dejó el mundo inhabitable. El Arcángel **Zahariel** limpia lo que queda, pero al avanzar cruza al Infierno mismo y **pierde sus poderes divinos**. Bajo la burla de **Lucifer** y con la ayuda del **Mercante Anónimo**, debe sobrevivir, recuperar su poder y descender hasta derrotar al Infierno desde dentro.

La pérdida de poderes justifica que cada partida empiece casi sin nada.

### 2.1 Los círculos del Infierno

Cada 10 rondas es un círculo. Al iniciar cada tramo se muestra el nombre del círculo.

| Rondas | Círculo | Jefe al final |
|---|---|---|
| 1–10 | 1. Limbo | Ronda 10 |
| 11–20 | 2. Lujuria | Ronda 20 |
| 21–30 | 3. Gula | Ronda 30 |
| 31–40 | 4. Avaricia y Prodigalidad | Ronda 40 |
| 41–50 | 5. Ira y Pereza | Ronda 50 |
| 51–60 | 6. Herejía | Ronda 60 |
| 61–70 | 7. Violencia | Ronda 70 |
| 71–80 | 8. Fraude | Ronda 80 |
| 81–90 | 9. Traición | Ronda 90 |
| 91–99 | **Castillo de Lucifer** (nombre tentativo) | — |
| 100 | Final: **Lucifer** | Lucifer |
| 101+ | **El Vacío (Void)**: rondas infinitas hasta morir | — |

**Nota de alcance:** los círculos con nombre son **[FUTURO]**. En la beta basta con numerar rondas y que cada 10 haya un jefe. Para la beta, un jefe es una versión más grande, con más vida y más daño; Lucifer sigue la misma regla.

---

## 3. Bucle de juego

```
Inicio → cinemática de caída (8 s, omitible)
   ↓
┌→ RONDA (cronómetro ascendente): enemigos aparecen y siguen a Zahariel
│     ↓ (fin de ronda al derrotar a todos)
│  DESCANSO (40 s): aparece el Mercante, tienda y cambio de arma
│     ↓ ([F] o fin del tiempo)
└─ siguiente ronda (más amenaza)
      ↓ (HP = 0)
   Escape: aro de luz → Cielo → pantalla de Score
```

- **Duración de ronda:** sin límite de tiempo; un **cronómetro ascendente** mide cuánto tardas desde `00:00`. La ronda termina únicamente al derrotar a todos los enemigos de la ronda, y entonces inicia el descanso de **40 s**.
- **Recompensa por tiempo de ronda:** al superar la ronda se otorgan un **Score fijo** y **Esquirlas de Alma fijas** modulados por el cronómetro (**a menor tiempo, más puntos y esquirlas; a mayor tiempo, menos**, con un piso mínimo configurable).
- **Ronda con jefe:** aparece el jefe junto con la oleada de la ronda.
- Todos estos valores (`40 s` de descanso, recompensa base de Score/Esquirlas y curva de tiempo) son provisionales y se ajustan durante el desarrollo y la fase de QA.
- **Ronda 10, 20, …:** ronda con jefe.
- **Cuando HP llega a 0:** no es una muerte real. Un **aro de luz** protege a Zahariel y lo lleva de vuelta al Cielo "para que la siguiente vez vuelva mejor". La partida termina y se guarda el mayor Score.
- **Ronda 100:** final contra Lucifer. Aun así el juego continúa en la **101+ (El Vacío)** con rondas infinitas.
- **Progreso entre partidas:** ninguno. Solo se conserva el mejor Score.

---

## 4. Controles

| Acción | Entrada |
|---|---|
| Moverse | WASD |
| Mirar | Mouse |
| Atacar / disparar | Clic izquierdo |
| Cubrirse con el escudo | Clic derecho (mantener) |
| Cambiar arma equipada (fuego ↔ melee) | Q o rueda del mouse |
| Saltar | Espacio |
| Dash | Shift |
| Recargar | R |
| Poderes de Fe | Teclas numéricas (1–4) |
| Saltar el descanso | F |
| Omitir cinemática | Espacio |

Cámara en primera persona, FOV 90°, balanceo ligero de arma y animación de desenfunde al cambiar de arma/escudo (`Q` o rueda).
Slide omnidireccional (`C` en el suelo mientras te mueves, `1.15 s` en `data/player_stats.tres`) con líneas de velocidad PSX en los bordes.

---

## 5. Zahariel (personaje jugable)

| Atributo | Valor |
|---|---|
| Vida | 100 HP |
| Regeneración | Tras varios segundos sin recibir daño, regenera **1 HP cada 1.2 s**. Espera de **5 s** sin recibir daño antes de empezar (ajustable en QA) |
| Estamina | 3 cargas. Cada dash consume **1 carga**; cada carga se recupera en **3 s** (ajustable en QA) |
| Dash | Shift |
| Armas | Una de fuego y una melee; solo una equipada. Ambas se pueden **reemplazar por otra** en cada descanso |
| Arma inicial | Espada + escudo |

### 5.1 Fe
La Fe es la energía de los poderes divinos. Se obtiene **recogiendo esferas azules** que sueltan los enemigos. Los poderes se activan con las teclas numéricas.

### 5.2 Vida
Los enemigos sueltan **esferas rojas** que restauran vida.

---

## 6. Combate y armas

Munición **infinita**: el número de munición es el tamaño del cargador antes de recargar.

### 6.1 Cuerpo a cuerpo

| Arma | Daño | Velocidad de ataque | Notas |
|---|---|---|---|
| Espada | 35 | 1.2 s por ataque | Daña a varios enemigos a la vez (arco frontal) |

**Escudo**
- **Clic derecho:** cubre todo el daño que viene de frente.
- **Pasivo:** mientras se lleve **equipada** la combinación espada + escudo, el daño recibido se reduce un **30%** de forma permanente (no hace falta cubrirse). Cubrirse con clic derecho sigue bloqueando todo el daño frontal. Otras espadas futuras (p. ej. espada larga) no llevarán escudo y no tendrán este pasivo. El 30% es provisional y se ajusta en QA.
- **[FUTURO] Parry de proyectiles:** algunos proyectiles de enemigos podrán ser desviados únicamente haciendo *parry* con el escudo. **[PENDIENTE]** ventana de *parry* y proyectiles reflejables.

**Habilidad única de la espada:** *Tajo a distancia* — ataque a distancia hacia adelante. Cada arma tendrá una habilidad única; por ahora solo está pensada la de la espada.

### 6.2 Armas de fuego

| Arma | Daño | Cargador | Recarga | Cadencia | Notas |
|---|---|---|---|---|---|
| Pistola | 10 | 12 | 2 s | 0.3 s entre disparos (200 RPM) | Arma de fuego inicial |
| Escopeta | 50 (pegada al enemigo) | 6 | 3.5 s | 0.9 s entre disparos (≈67 RPM) | Más daño cerca, menos lejos; golpea a varios enemigos |
| Subfusil | 14 | 30 | 3 s | 0.08 s entre disparos (750 RPM) | |
| Rifle FX-05 | 28 | 60 | 3.5 s | 650 RPM | |

Las armas se desbloquean/cambian en la tienda (ver §8).

### 6.3 Críticos
El crítico solo aumenta el daño; **no afecta el Score**. En la beta el crítico es una **tirada aleatoria** por golpe según la probabilidad. Un disparo a la cabeza **no** es crítico.

Ejemplo propuesto (ajustable):
- Probabilidad base de crítico: **5%**. Multiplicador base: **×2**.
- Espada (35): normal 35, crítico **70**.
- Rifle (28): normal 28, crítico **56**.
- Con mejoras: +10% de probabilidad y +0.5 al multiplicador → 15% de probabilidad y ×2.5 → espada crítica **87**.


---

## 7. Enemigos

**Comportamiento único (beta):** todos siguen a Zahariel y le hacen daño al tocarlo. Solo cambian tamaño, vida y daño.

| Enemigo | HP base | Daño base | Aparece desde |
|---|---|---|---|
| Esqueleto Condenado | 30 | 10 | Ronda 1 |
| Demonio del Averno | 80 | 21 | Ronda 2 |
| The Wrapped | 325 | 30 | Ronda 4 |
| **Jefe** (rondas 10, 20…) | 3,534 | 40 | Cada 10 rondas |
| Lucifer (ronda 100) | 30,000 | 150 | Ronda 100 |

Los stats de la tabla son los de la ronda 1 y escalan con la ronda (§9).

- **Tope de enemigos simultáneos:** 30.
- **Jefe de beta:** un enemigo más grande (`1.5×` la altura del modelo base), con más vida (`3,534 HP`) y más daño (`40`). Lucifer, igual. En las rondas múltiplo de 10 (`BossSpawner`) sale al azar uno de estos 3 modelos (sin repetir el inmediatamente anterior):
  - **Jefe Esqueleto** (`JefeSqueletor.tscn`): versión gigante (`2.7 m` de alto, radio `0.6 m`) del Esqueleto Condenado; `move_speed = 3.0 m/s`, `contact_range = 2.25 m`.
  - **Jefe Demonio** (`JefeDemonio.tscn`): versión gigante (`3.45 m` de alto, radio `0.78 m`) del Demonio del Averno; `move_speed = 3.15 m/s`, `contact_range = 2.76 m`.
  - **Jefe The Wrapped** (`JefeWrapped.tscn`): versión gigante (`3.9 m` de alto, radio `0.9 m`) de The Wrapped; `move_speed = 2.8 m/s`, `contact_range = 3.0 m`.
- **Drops:** esferas azules (Fe), esferas rojas (vida) y Esquirlas de Alma (moneda). **[PENDIENTE]** cantidad y probabilidad por tipo.
- **[FUTURO]** Comportamientos distintos por enemigo, jefes secretos (Malenia, animatrónicos) y eventos especiales. **Por ahora no hay eventos especiales.**

### 7.1 Variantes de enemigos con habilidades [EXPERIMENTO]

Implementadas en `experiment/sandbox` (a validar con playtest antes de pasar a issue). Cada modelo tiene 3 variantes, distinguidas por un **tinte de color** sobre la textura y un modelo un 10 % más grande; todas las variantes con habilidad activa disparan su animación de ataque al ejecutarla. Los valores viven en `data/enemies/variants/*.tres` y son **propuestas** (`TODO(GDD)`).

| Modelo | Variante | Color | Habilidad | Desde ronda |
|---|---|---|---|---|
| Esqueleto Condenado | Tirador | Azul | Proyectil recto (8 de daño, cada 2 s, aviso 0.4 s) | 3 |
| | Invocador | Verde | 2-4 mini esqueletos (40 % vida, 50 % daño, atacan más rápido), cada 8 s | 3 |
| | Kamikaze | Amarillo | Velocidad ×1.8; explota al llegar (radio 4 m, 50 % del daño a enemigos) | 3 |
| Demonio del Averno | Lanzallamas | Rojo | Cono de 5 m; quemadura de 1.5 s, 3 de daño cada 0.5 s | 5 |
| | Escupe-creep | Morado | Proyectil en arco que deja una zona dañina 4 s | 5 |
| | Teletransportador | Cian | Parpadea 0.7 s y reaparece detrás del jugador, cada 6 s | 5 |
| The Wrapped | Cargador | Negro | Aviso de 1 s con línea roja y grito (`Scream_lol`), embestida a `25 m/s` (`Run_Frantic`, 45 de daño); aturde al jugador `0.85 s` (bloquea movimiento, ataque y cámara) y lo empuja (`knockback_speed = 20`); si choca con pared queda aturdido `2.0 s` (`WallSlam_Recover`) | 7 |
| | Blindado | Gris acero | Solo recibe daño por la espalda (arco de 150°); gira muy lento; vida 260 | 7 |
| | Artillero | Naranja | 7 proyectiles rectos (sin gravedad, 12 de daño c/u) disparados uno tras otro cada 0.15 s en abanico de 60° que alterna entre horizontal y vertical; ráfaga cada 3 s | 7 |

Ideas del GDD original sin asignar todavía: **Francotirador de rayo rojo** (2 s de línea de vista y rayo), **Tirador de cono / aro de proyectiles** y las nuevas **Curandero de aura** (cura/buffea enemigos cercanos).

- **Aparición:** cada spawn de un modelo tiene 20 % de ser una variante (si hay alguna disponible esa ronda), con máximo 4 variantes vivas.
- **Campeones:** sistema aparte, combinable con cualquier variante. Corona flotante y aura pequeña; vida ×2.5, daño ×1.5, velocidad ×1.1, tamaño ×1.25. 5 % por spawn desde la ronda 5, máximo 2 vivos. Valores en `data/champion.tres`.

---

## 8. Mercante Anónimo, tienda y mejoras

El Mercante aparece **40 segundos** entre rondas. Al entrar a la tienda:

- **Siempre se ofrecen:** Vida y Fe.
- **Además se sortean 4 opciones** entre armas, mejoras y habilidades.
- Aquí también se puede **reemplazar el arma** equipada (fuego o melee).

Moneda: Esquirlas de Alma. **[PENDIENTE]** confirmar.

### 8.1 Tabla de poderes y mejoras

Los efectos ya están descritos; **precio, valor por nivel y nivel máximo se llenan poco a poco**.

| Nombre | Categoría | Efecto | Precio | Valor por nivel | Nivel máx. |
|---|---|---|---|---|---|
| Vida (curación) | Siempre | Restaura una parte de la vida | | | — |
| Fe (recarga) | Siempre | Restaura una parte de la barra de Fe | | | — |
| Prob. de crítico (melee) | Melee | Aumenta la probabilidad de crítico de la espada | | |  |
| Daño crítico (melee) | Melee | Aumenta el multiplicador de los críticos de la espada | | |  |
| Daño plano (melee) | Melee | Suma daño fijo a cada golpe de la espada | | |  |
| Daño % (melee) | Melee | Aumenta en porcentaje el daño de la espada | | |  |
| Prob. de crítico (fuego) | Fuego | Aumenta la probabilidad de crítico del arma de fuego | | |  |
| Daño crítico (fuego) | Fuego | Aumenta el multiplicador de los críticos del arma de fuego | | |  |
| Daño plano (fuego) | Fuego | Suma daño fijo a cada disparo | | |  |
| Daño % (fuego) | Fuego | Aumenta en porcentaje el daño del arma de fuego | | |  |
| Cadencia | Fuego | Reduce el tiempo entre disparos | | |  |
| Tamaño de cargador | Fuego | Aumenta las balas por cargador | | |  |
| Vida máxima | Personaje | Aumenta los HP máximos | | |  |
| Dash | Personaje | Mejora el dash (más distancia o más cargas de estamina) | | |  |
| Velocidad | Personaje | Aumenta la velocidad de movimiento | | |  |
| Doble salto (alas) | Personaje | Permite un segundo salto en el aire | | |  |
| Dash en el aire | Personaje | Permite usar el dash mientras está en el aire | | |  |
| Bola de fuego | Fe | Poder de Fe: lanza una bola de fuego que daña a los enemigos | | |  |
| Curación pasiva | Fe | Poder de Fe: aumenta la regeneración de vida | | |  |
| Daño extra al arma equipada | Fe | Poder de Fe: suma daño al arma que esté equipada | | |  |
| Tajo a distancia | Habilidad de arma (espada) | Lanza un tajo hacia adelante que daña a distancia | | |  |
| Pistola | Arma de fuego | Reemplaza el arma de fuego equipada por la pistola | | |  |
| Escopeta | Arma de fuego | Reemplaza el arma de fuego equipada por la escopeta | | |  |
| Subfusil | Arma de fuego | Reemplaza el arma de fuego equipada por el subfusil | | |  |
| Rifle FX-05 | Arma de fuego | Reemplaza el arma de fuego equipada por el rifle | | |  |
| Habilidades de otras armas | Habilidad de arma | Una habilidad única por arma (por pensar) | | |  |

Sugerencia: llenar primero precio y valor por nivel de lo que ya está en la tienda inicial, y dejar el resto para después.

---

## 9. Oleadas

- **Cantidad constante:** 12 enemigos simultáneos en todas las rondas (1–100); al morir uno se repone otro. El tope duro de 30 (§17) es un límite de seguridad, no un objetivo de aparición.
- **Escalado de stats:** la vida, el daño y la velocidad de cada enemigo se calculan con `stat = base × (1 + 0.1 × (ronda − 1))`. La velocidad se aplica como multiplicador sobre la velocidad base configurada en `data/`.
- **Composición por rango de rondas:**

  | Rondas | Enemigos en la horda |
  |---|---|
  | 1 | Esqueleto Condenado |
  | 2–3 | Esqueleto Condenado + Demonio del Averno |
  | 4–9 | Esqueleto Condenado + Demonio del Averno + The Wrapped |
  | 10+ (excepto la 100) | La horda anterior; en las rondas múltiplos de 10 se añade el jefe |
  | 100 | La horda anterior y Lucifer en lugar del jefe |

Sobre la horda pueden salir variantes con habilidad y campeones (§7.1). Configuración en `data/horde_config.tres`.

- **Ronda con jefe:** cada 10 rondas aparece el jefe junto a la horda, nunca solo.
- **Eventos especiales:** ninguno por ahora.
- **Arena y puntos de aparición:** coliseo circular (`coliseo.tscn`, radio `25 m`, ver §10) con 4 `SpawnPoints` en `(±16.5, 1, ±16.5)`, pilares en `(±14, 1.75, ±14)`, `HuecoCentral` (radio `5 m`) y `PlataformaMercader` central. En el cielo (`World.tscn`), la luna (`moon_glow.gdshader`) cambia entre 8 fases por ronda y en el círculo de Lucifer (`91–100`) se fuerza luna llena roja.

---

## 10. Arena

### 10.1 Forma y medidas base
- **Geometría:** Coliseo circular poligonal (24 lados, estética PSX) con suelo plano y muralla perimetral cerrada.
- **Radio jugable (suelo):** `25.0 m` (diámetro total `50.0 m`, área ≈ `1,963 m²`).
- **Muralla exterior:** Radio externo `27.0 m` (grosor `2.0 m`), altura `12.0 m`.
- **Punto focal (Norte, `Z = -26 m`):** Aguja de roca elevada (`Height: 24.0 m`, `Radius: 5.0 m`) incrustada en el muro norte, donde se ubica el trono de Lucifer observando la arena.
- **Implementación:** Blockout inicial con CSG (`#52`); versión final con `StaticBody3D` + formas simples (§17.2).

### 10.2 Flujo y capacidad (tope de 30 enemigos)
Diseñada para permitir *kiting* constante sin que el tope de 30 enemigos se trabe en el `NavigationRegion3D` (`#53`):
- **Anillo interior libre:** Pasillo de `7.0 m` entre la zona del Mercante (`r = 5 m`) y el anillo de coberturas (`r = 12 m`).
- **Anillo exterior libre:** Pasillo de `9.0 m` entre las coberturas (`r = 16 m`) y la muralla (`r = 25 m`).
- **Separación mínima entre coberturas:** ≥ `6.0 m` entre cada obstáculo.

### 10.3 Coberturas
- **Cantidad:** `4` pilares / ruinas distribuidos simétricamente en el anillo intermedio (`r = 14.0 m`, ángulos `0°`, `90°`, `180°`, `270°`).
- **Medidas por pilar:** Base de `2.5 m × 2.5 m`, altura de `3.5 m` (corta línea de visión sin tapar el trono de Lucifer).

### 10.4 Puntos de aparición de enemigos (`#54`)
- **Ubicación:** `4` portales/compuertas en la muralla perimetral (`r = 25.0 m`) en las diagonales: **NE (`45°`)**, **NO (`-45°`)**, **SE (`135°`)** y **SO (`-135°`)**.
- **Ancho de salida:** `4.0 m` por portal con `Marker3D` dedicado para evitar atascos al salir en grupo.

### 10.5 Zona del Mercante (`#55`)
- **Ubicación:** Centro exacto de la arena `(0, 0, 0)`.
- **Dimensiones:** Plataforma circular elevadora (`AnimatableBody3D`) de `5.0 m` de radio (`10.0 m` de diámetro).
- **Comportamiento:**
  - *Durante la ronda:* A ras del suelo (`y = 0`) dejando el centro transitable.
  - *Durante el descanso (40 s):* Asciende `+0.5 m` revelando al Mercante Anónimo y su tienda.

## 11. Objetos

| Objeto | Efecto |
|---|---|
| Esfera azul | Restaura Fe |
| Esfera roja | Restaura vida |
| Esquirla de Alma | Moneda para la tienda |

No hay cajas de munición porque la munición es infinita.

---

## 12. Interfaz

**HUD** (parte inferior):
- **HP** (barra roja) y **Fe** (barra azul).
- **Estamina:** 3 cargas.
- **Ranuras de poderes** (centro): íconos de ejemplo, solo boceto (no son necesariamente poderes de Fe).
- **Munición:** cargador (la reserva es infinita).
- **Mira** al centro.
- **Ronda actual** y **cronómetro** (ascendente desde 00:00). **[PENDIENTE]** Score y combo en pantalla.

**Menús:** splash ("Presiona ENTER para descender"), tienda del Mercante. **[PENDIENTE]** pausa, pantalla de escape con Score. **Opciones:** límite de FPS y V-Sync (ver §17.4); el resto de ajustes **[PENDIENTE]**.

---

## 13. Dirección de arte

- Low-poly PSX: modelos de 300–1,200 triángulos, texturas de 256–500 px.
- Resolución interna 640×480 o 320×240, Nearest-Neighbor, vertex snapping, dithering. Detalles de compatibilidad y rendimiento en §17.8 y §17.9.
- Paleta: rojos y negros del Infierno, dorado para Zahariel y lo divino, azul para el Mercante.

| Uso | Autor / Pack | Licencia |
|---|---|---|
| Espada y escudo | Amos — PSX weapon pack | CC0 |
| Brazos y armas de fuego | Kuptchi — PSX-Weapons Assets | Libre sin atribución |
| Esqueleto | Puck — PSX Low Poly Skeleton | CC0 |
| Rifle FX-05 | Puck — PSX Rifle Free | Verificar |
| Demonio del Averno | Max Damage — Zombie low-poly | Requiere atribución |
| The Wrapped | Codyanka — THE WRAPPED | Verificar |

---

## 14. Audio

Efectos a 22.05 kHz / 16 bits.

| Pista | Uso | Estilo |
|---|---|---|
| "Coro de Ceniza" | Menú, splash, créditos | Órgano distorsionado, coros sintéticos |
| "Liturgia del Plomo" | Rondas normales | Industrial metal / dark synth, 145 BPM |
| "Santuario de Azufre" | Descanso con el Mercante | Campanas, viento, clavecín, 80 BPM |
| "Heraldo del Abismo" | Rondas de jefe | Orquesta barroca + breakcore, 165 BPM |

**Efectos:** `SFX_Sword_Slash`, `SFX_Shield_Block`, `SFX_Pistol_Fire`, `SFX_Shotgun_Pump`, `SFX_Rifle_FX05`, `SFX_Mag_Reload`, `SFX_Skeleton_Rattle`, `SFX_Demon_Roar`, `SFX_Wrapped_Scream`, `SFX_Shard_Pickup`, `SFX_Divine_Restore`, `SFX_Bell_Truce`, `SFX_Upgrade_Buy`, `SFX_Fall_Impact`, `SFX_Grace_Shatter`.

**Voz de Lucifer:** sin cuerpo; líneas procesadas (grave, reverb, lo-fi). Baja la música 30% durante 3 s al hablar. Se burla al inicio, anuncia jefes y ríe cuando HP < 20%.

---

## 15. Guión y storyboard

| Escena | Disparador | Cámara | Texto / voz | Audio |
|---|---|---|---|---|
| 1. Splash | Arranque | Cámara lenta orbitando a Zahariel | "ARMAGEDDON — Presiona [ENTER] para descender" | "Coro de Ceniza" |
| 2. Caída | Inicio (8 s, omitible) | De ruinas grises a abismo rojo; el aura dorada se apaga | Narrador: "Purgar la Tierra no bastó. Al cruzar el umbral del Infierno, tu gracia divina se ha extinguido." Lucifer: "Bienvenido a mi reino, Zahariel... Aquí eres solo carne y hierro. ¡Que empiece la cacería!" | Caída, cristal roto, risa |
| 3. Rondas | Ronda activa | FOV 90°, weapon bob | Ronda 4, aparece The Wrapped: "Mis torturadores reclaman tus huesos." | "Liturgia del Plomo" |
| 4. Descanso | Fin de ronda | Aparece el Mercante | "Las almas que siegas pesan en tus manos, Arcángel... Dámelas, y te daré con qué matar a un dios." | Campana, "Santuario de Azufre" |
| 5. Escape (nueva) | HP = 0 | Un aro de luz envuelve a Zahariel y lo eleva al Cielo | **[PENDIENTE]** línea | **[PENDIENTE]** |

**Lámina de storyboard:** [PENDIENTE]

---

## 16. Score

Premia los combos y avanzar de ronda. El crítico **no** afecta el puntaje.

### 16.1 Combo
- Se **inicia** al matar **2 enemigos en ≤ 0.5 s**.
- Cada baja posterior suma al combo y **aumenta el multiplicador de puntaje**.
- Si pasan **1.5 s sin matar a nadie**, el combo termina.

Propuesta de multiplicador: `×(1 + 0.1 · bajas del combo)`, tope **×5**. **[PENDIENTE]** confirmar.

### 16.2 Puntos

| Evento | Puntos base | Notas |
|---|---|---|
| Esqueleto | 50 | × multiplicador de combo |
| Demonio | 120 | × multiplicador de combo |
| The Wrapped | 350 | × multiplicador de combo |
| Jefe | **[PEND.]** | × multiplicador de combo |
| Ronda superada | **[PEND.]** | Puntaje fijo y **Esquirlas de Alma fijas** modulados por el cronómetro (menor tiempo → más recompensa; mayor tiempo → menos) |
| Poder de Fe/divino recuperado | **[PEND.]** | |
| Golpe recibido | **[A CONFIRMAR]** | Antes −50; ¿sigue? ¿reinicia el combo? |

**Rangos:** **[PENDIENTE]** (S = "Arcángel Supremo").
El ejemplo del documento original (46,540 pts) ya no aplica y se recalculará.

---

## 17. Rendimiento y alcance

- Meta: 60 FPS en las 4 PCs (la más modesta: AMD Ryzen 5 serie 7000 + gráficos AMD integrados + 8 GB de RAM).
- Tope de 30 enemigos a la vez.
- **Fuera de alcance de la beta:** multijugador, jefes secretos, eventos especiales, comportamientos distintos por enemigo, guardado entre partidas, círculos con nombre.

Principio: medir antes de optimizar (Profiler y Monitors de Godot, siempre sobre un build exportado, no sobre el editor). Las técnicas de abajo se aplican poco a poco, cuando existe el contenido que las necesita.

### 17.1 Culling (qué se dibuja)

- **Frustum culling:** Godot lo hace **automáticamente**. Consiste en no dibujar lo que está fuera del campo de visión de la cámara. No requiere configuración ni código.
- **Occlusion culling:** no dibujar lo que queda tapado por paredes u obstáculos grandes. Se usa `OccluderInstance3D` y se aplica al diseñar la arena (§10) y su blockout. En una arena muy abierta aporta poco.
- **Visibility range (LOD manual):** `visibility_range_end` en los `GeometryInstance3D` para ocultar o simplificar objetos lejanos. Con modelos low-poly (§13) se usa solo si el Profiler lo pide.

### 17.2 Física y colisiones

- Solo formas simples (cápsula, caja, esfera). **Nunca** mallas trimesh en objetos dinámicos ni en enemigos.
- Capas y máscaras de colisión nombradas en Project Settings (por ejemplo: Player, World, Enemy). Cada objeto colisiona únicamente con las capas que necesita, para no calcular colisiones inútiles. **[PENDIENTE]** tabla final de capas.
- Arena final con `StaticBody3D` + `BoxShape3D`, no con `CSGBox3D` (el CSG es válido solo para el blockout). Paredes y suelo con grosor real, para evitar que raycasts o movimientos rápidos los atraviesen.

### 17.3 IA de enemigos

- Los enemigos **no** calculan su ruta en cada frame. Recalculan el destino con un temporizador de **0.1 a 0.2 s** (actualmente `NAV_UPDATE_INTERVAL = 0.15 s` en `Enemy`, guardando la última dirección en caché entre intervalos).
- El recálculo va **escalonado**: cada enemigo arranca con un desfase aleatorio (`0` a `NAV_UPDATE_INTERVAL`), de modo que no todos recalculan en el mismo frame.
- El tope de 30 enemigos simultáneos (§7) acota el costo total.
- Intervalo configurable en `armagedon/data/`. **[PENDIENTE]** mover `NAV_UPDATE_INTERVAL` a `EnemyData` si hace falta ajustarlo por tipo de enemigo.

### 17.4 Ajustes de rendimiento (opciones del jugador)

- **Límite de FPS:** 30, 60, 144, 180 o ilimitado. **[PENDIENTE]** valor por defecto (propuesta: 60, igual que la meta). Mientras no exista el menú, el autoload `DisplayConfig` (`scripts/Settings/display_config.gd`) aplica 180 FPS y V-Sync activado, y guarda la elección en `user://settings.cfg`.
- **V-Sync:** activado o desactivado.
- Se guardan como preferencia de usuario (archivo de configuración local). No cuentan como progreso entre partidas, así que no contradicen la regla de "sin progreso salvo el mejor Score".
- Viven en el menú de opciones (§12).

### 17.5 Caché, preload y pooling

- **Preload:** las escenas y recursos de uso frecuente (enemigos, trazadores, impactos, efectos, sonidos) se cargan con `preload` y no con `load()` durante la partida.
- **Pooling:** objetos que se crean y destruyen muy seguido se reutilizan en vez de instanciarse y liberarse. Aplica a enemigos (30 fijos), trazadores de disparo, marcas de impacto y números de daño.
- **Caché de modelos y materiales de enemigos:** el modelo y sus materiales se cargan una sola vez y se comparten entre todas las instancias.
- **Armas:** se instancian una vez y se alternan (visibilidad y procesado), no se destruyen y recrean en cada cambio.
- **Precalentamiento de shaders:** al iniciar la partida o la ronda se muestra una vez cada efecto y enemigo fuera de cámara (o tras la pantalla de carga), para que la compilación no cause tirones durante el combate.

### 17.6 Assets

- Solo se importa y versiona lo que el juego usa (§13). Los packs completos sin usar se dejan fuera de `res://` o con `.gdignore`.

### 17.7 Reglas de código de rendimiento

**Regla de calidad (siempre):** todo error o aviso que aparezca en la consola de Godot, en el arranque headless o en `gdlint`/`gdformat` se soluciona; y antes de cada commit y push se comprueba en local que el CI pasará (`godot-ci.yml`: lint, formato, importación y carga del proyecto), y tras el push que los checks del PR estén en verde. El detalle operativo está en `AGENTS.md`.

Reglas que se aplican desde el inicio (la lista operativa vive en `AGENTS.md`, «Rendimiento: reglas desde el inicio»):
- Recursos (mallas, materiales, formas, consultas de física) se crean una vez y se reutilizan; no se crean por disparo, golpe o frame.
- Referencias a nodos (jugador, manager, cámara) se resuelven una vez y se guardan; no se buscan por grupo en cada frame ni en cada ataque.
- El HUD se actualiza por señales y solo reasigna el texto cuando cambia.
- Al guardar un arma se cancelan sus animaciones, tweens y golpes pendientes.
- Los datos de los Resources y los nodos opcionales se validan antes de usarse (divisores en 0, `null`).
- Las ayudas de depuración no corren en el juego exportado.
- Renderer activo: **Compatibility (`gl_compatibility`)** en `project.godot` (ligero para el estilo PSX y compatible con GPUs modestas; pendiente validar QA final #94).

### 17.8 Compatibilidad y costo del shader PSX

- **Multiplataforma:** el shader (`assets/shaders/psx.gdshader`) es shader estándar de Godot 4 (`.gdshader`), sin código específico de plataforma. Godot lo compila para Compatibility (OpenGL/GLES3), Vulkan (Linux) y Direct3D 12 (Windows, ver `project.godot`). No usa extensiones ni texturas especiales.
- **Estado de la verificación:** probado en Linux (AMD RX 7600, OpenGL Compatibility). **[PENDIENTE]** probarlo en Windows y en la PC más modesta (iGPU) antes de cerrar #37.
- **Costo:** el vertex snapping es una multiplicación de matriz, una división y un `floor` por vértice; con modelos de 300–1,200 triángulos es despreciable. El fragment shader (`lambert`, sin especular) es más barato que el material estándar. El costo real en una iGPU está en los píxeles (resolución, sombras, glow, luces), no en el shader.
- **Cómo medirlo:** ejecutar `scenes/Test/psx_test.tscn` (F6) y anotar FPS y tiempo de frame (Debugger → Monitors) con y sin el shader en cada PC. Meta: 60 FPS (16.6 ms por frame).

### 17.9 Optimización (modelos, enemigos y escena)

| Área | Regla |
|---|---|
| Modelos | Respetar 300–1,200 triángulos; sin mallas ocultas ni caras que nunca se ven. |
| Texturas | 256–500 px, sin mipmaps innecesarios, filtro Nearest. Compartir un atlas por familia de enemigos. |
| Materiales | Pocos y compartidos. `PsxStyle.apply()` cachea el `ShaderMaterial` por material original, textura y rejilla: 30 enemigos del mismo tipo comparten un solo material. |
| Resolución | Renderizar a 640×480 o 320×240 (#38): es la mayor ganancia en una iGPU, porque reduce el costo por píxel. |
| Iluminación | Una luz direccional y pocas luces dinámicas. Sombras desactivadas o solo en la luz principal; sin SSAO, SSR ni SDFGI. Revisar el `glow` de `WorldEnvironment`. |
| Enemigos | Tope de 30 simultáneos. Simulación centralizada en `EnemyManager` (un único `_physics_process` y `_process`, física a mitad de tasa para lejanos > 16 m y presupuesto de 10 recálculos de ruta por frame); esqueleto con pocos huesos, **LOD de animación por distancia** (20 Hz media distancia, 8 Hz lejos) y **culling de animación detrás de cámara**; no instanciar ni liberar en cada frame. |
| Pooling | Reutilizar objetos de efectos frecuentes (trazos de disparo, marcas de impacto, números de daño) en vez de crearlos y liberarlos por golpe (ver §17.5). Ya hay pooling de trazadores, impactos y `DamageNumber`; los enemigos se agregan con #58. **[PENDIENTE]** decidir si `DamageNumber` (hoy solo en el muñeco de pruebas) pasa al juego final o se quita. |
| Física e IA | Colisiones con formas simples (cápsula, caja); evitar `ConcavePolygonShape3D` salvo la arena estática. Recalcular rutas del NavMesh con intervalo, no cada frame. |
| Escena | Props y restos repetidos con `MultiMeshInstance3D` (ej. `BonePiece` dibuja hasta 120 piezas en 1 solo draw call); `VisibleOnScreenNotifier`/visibility range para lo lejano; la arena es pequeña, así que el occlusion culling solo si hace falta. |
| Proceso | Medir antes de optimizar (Profiler y Monitors). Probar en la PC más modesta antes de mergear cualquier cambio visual pesado. |

---

## 18. Pendientes consolidados

1. ~~Fin de ronda y aparición del jefe~~ (resuelto, §3 y §9).
2. Nombre definitivo del Castillo de Lucifer (rondas 91–99).
3. ~~Estamina, espera de regeneración~~ (resuelto, §5).
4. ~~Cadencias de pistola, escopeta y subfusil~~ (resuelto, §6.2; valores provisionales).
5. Stats de jefes y Lucifer.
6. Tabla de mejoras (precios y valores) — §8.1.
7. Multiplicador de combo, puntos de jefe/ronda/Fe, golpe recibido, rangos.
8. Drops: cantidad y probabilidad.
9. Arena, boceto y storyboard.
10. Menús (pausa, opciones, pantalla de escape).
11. Confirmar licencias marcadas como "Verificar".
12. Rendimiento (§17): tabla de capas de colisión, intervalo y desfase del recálculo de IA, FPS por defecto.
13. `DamageNumber`: decidir si el número flotante de daño pasa al juego final (ya tiene pooling) o queda solo como depuración del muñeco.
14. Verificar el shader PSX en Windows y en la PC con iGPU (§17.8).
