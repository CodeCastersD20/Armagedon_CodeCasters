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
| Partida | Rondas de 3:30, sin progreso entre partidas, rejugable |

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
┌→ RONDA (3:30): enemigos aparecen y siguen a Zahariel
│     ↓ (fin de ronda)
│  DESCANSO (40 s): aparece el Mercante, tienda y cambio de arma
│     ↓ ([F] o fin del tiempo)
└─ siguiente ronda (más amenaza)
      ↓ (HP = 0)
   Escape: aro de luz → Cielo → pantalla de Score
```

- **Duración de ronda:** 3 min 30 s. **[PENDIENTE]** ¿la ronda termina al agotarse el tiempo, al matar a todos, o lo que ocurra primero?
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

Cámara en primera persona, FOV 90°, balanceo ligero de arma.

---

## 5. Zahariel (personaje jugable)

| Atributo | Valor |
|---|---|
| Vida | 100 HP |
| Regeneración | Tras varios segundos sin recibir daño, regenera **1 HP cada 1.2 s**. **[PENDIENTE]** cuántos segundos de espera (propuesta: 5 s) |
| Estamina | 3 cargas (el dash consume carga). **[PENDIENTE]** consumo y tiempo de recarga por carga |
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
- **Pasivo:** llevar espada y escudo reduce el daño recibido un **60%**. **[PENDIENTE]** confirmar que este 60% aplica siempre y no solo cubriéndose.

**Habilidad única de la espada:** *Tajo a distancia* — ataque a distancia hacia adelante. Cada arma tendrá una habilidad única; por ahora solo está pensada la de la espada.

### 6.2 Armas de fuego

| Arma | Daño | Cargador | Recarga | Cadencia | Notas |
|---|---|---|---|---|---|
| Pistola | 10 | 12 | 2 s | **[PEND.]** | Arma de fuego inicial |
| Escopeta | 50 (pegada al enemigo) | 6 | 3.5 s | **[PEND.]** | Más daño cerca, menos lejos; golpea a varios enemigos |
| Subfusil | 14 | 30 | 3 s | **[PEND.]** | |
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
| Demonio del Averno | 80 | 20 | Ronda 2 |
| The Wrapped | 250 | 35 | Ronda 4 |
| **Jefe** (rondas 10, 20…) | **[PEND.]** mayor | **[PEND.]** mayor | Cada 10 rondas |
| Lucifer (ronda 100) | **[PEND.]** | **[PEND.]** | Ronda 100 |

Los stats de la tabla son los de la ronda 1 y escalan con la ronda (§9).

- **Tope de enemigos simultáneos:** 30.
- **Jefe de beta:** un enemigo más grande, con más vida y más daño. Lucifer, igual.
- **Drops:** esferas azules (Fe), esferas rojas (vida) y Esquirlas de Alma (moneda). **[PENDIENTE]** cantidad y probabilidad por tipo.
- **[FUTURO]** Comportamientos distintos por enemigo, jefes secretos (Malenia, animatrónicos) y eventos especiales. **Por ahora no hay eventos especiales.**

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

- **La cantidad de enemigos no crece con las rondas.** Lo que crece son los **stats de todos los enemigos** (vida, daño y velocidad). **[PENDIENTE]** fórmula de escalado (propuesta: `stat = base × (1 + 0.1 × (ronda − 1))`) y qué enemigos salen en cada rango de rondas.
- **Tope simultáneo:** 30 enemigos; al morir uno se repone otro. **[PENDIENTE]** cantidad objetivo en pantalla.
- **Ronda con jefe:** cada 10 rondas aparece el jefe; **[PENDIENTE]** si aparece solo o junto a la horda.
- **Eventos especiales:** ninguno por ahora.
- **Arena y puntos de aparición:** **[PENDIENTE]** la arena aún no se ha diseñado.

---

## 10. Arena

**[PENDIENTE]** Aún no se ha diseñado. Se definirá después de cerrar el núcleo de combate.

---

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
- **Ronda actual** y **cronómetro** (3:30). **[PENDIENTE]** Score y combo en pantalla.

**Menús:** splash ("Presiona ENTER para descender"), tienda del Mercante. **[PENDIENTE]** pausa, opciones, pantalla de escape con Score.

---

## 13. Dirección de arte

- Low-poly PSX: modelos de 300–1,200 triángulos, texturas de 256–500 px.
- Resolución interna 640×480 o 320×240, Nearest-Neighbor, vertex snapping, dithering.
- Paleta: rojos y negros del Infierno, dorado para Zahariel y lo divino, azul para el Mercante.

| Uso | Autor / Pack | Licencia |
|---|---|---|
| Espada y escudo | Amos — PSX weapon pack | CC0 |
| Brazos y armas de fuego | Kuptchi — PSX-Weapons Assets | Libre sin atribución |
| Esqueleto | Puck — PSX Low Poly Skeleton | CC0 |
| Rifle FX-05 | Puck — PSX Rifle Free | Verificar |
| Demonios | Elbolilloduro — Characters PSX | Verificar |
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
| Ronda superada | **[PEND.]** | + bono por tiempo restante (de los 3:30) |
| Poder de Fe/divino recuperado | **[PEND.]** | |
| Golpe recibido | **[A CONFIRMAR]** | Antes −50; ¿sigue? ¿reinicia el combo? |

**Rangos:** **[PENDIENTE]** (S = "Arcángel Supremo").
El ejemplo del documento original (46,540 pts) ya no aplica y se recalculará.

---

## 17. Rendimiento y alcance

- Meta: 60 FPS en las 4 PCs (la más modesta: AMD Ryzen 5 serie 7000 + gráficos AMD integrados + 8 GB de RAM).
- Tope de 30 enemigos a la vez.
- **Fuera de alcance de la beta:** multijugador, jefes secretos, eventos especiales, comportamientos distintos por enemigo, guardado entre partidas, círculos con nombre.

---

## 18. Pendientes consolidados

1. Fin de ronda (tiempo / matar todos) y cuándo aparece el jefe.
2. Nombre definitivo del Castillo de Lucifer (rondas 91–99).
3. Estamina: consumo y recarga; espera de la regeneración de vida.
4. Cadencias de pistola, escopeta y subfusil.
5. Stats de jefes y Lucifer.
6. Tabla de mejoras (precios y valores) — §8.1.
7. Fórmula de escalado de stats por ronda y cantidad de enemigos en pantalla.
8. Multiplicador de combo, puntos de jefe/ronda/Fe, golpe recibido, rangos.
9. Drops: cantidad y probabilidad.
10. Arena, boceto y storyboard.
11. Menús (pausa, opciones, pantalla de escape).
12. Confirmar licencias marcadas como "Verificar".
