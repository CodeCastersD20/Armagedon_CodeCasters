# ARMAGEDDON

> Roguelike shooter en primera persona por oleadas, estética low-poly PSX. Hecho en **Godot 4** (GDScript).

Universidad Tecnológica de Hermosillo, Sonora — TI, Desarrollo y Gestión de Software Multiplataforma.
Equipo: **CodeCasters**.

## Resumen

El Infierno se desbordó y la Tierra quedó inhabitable. Eres el Arcángel **Zahariel**: al cruzar al Infierno pierdes tus poderes divinos y quedas atrapado en el Infierno, bajo la burla de **Lucifer** y con la sola ayuda del **Mercante Anónimo**. Sobrevive a las oleadas, compra mejoras con Esquirlas de Alma y recupera tu poder.

- **Género:** roguelike + shooter en primera persona (melee y fuego), sin progreso entre partidas.
- **Público:** +16.
- **Motor:** Godot Engine 4 (3D), Blender para ajustar modelos, Git + GitHub Projects.
- **Estructura:** rondas de 3:30, descanso de 40 s con el Mercante, 9 círculos del Infierno y munición infinita.
- **Enemigos:** Esqueletos Condenados, Demonios del Averno, The Wrapped; jefe cada 10 rondas, Lucifer en la ronda 100 y el Vacío (rondas infinitas) después.

## Equipo

| Integrante | GitHub | Rol | Hardware |
|---|---|---|---|
| Sadrach Juan Diego García Flores | [@Sadrach34](https://github.com/Sadrach34) | Programación principal, jugador, shaders PSX, armas, rondas, builds | Ryzen 5 5500 / 16 GB / RX 7600 |
| Adrián Eduardo Santos Rosales | [@AdrianS-127](https://github.com/AdrianS-127) | Enemigos/IA, spawner, jefes, drops | Ryzen 5 5500 / 16 GB / RX 7600 |
| Erick Daniel Arvayo Avilés | [@Ddarielz](https://github.com/Ddarielz) | Arena, tienda y poderes, menús, QA | Core i5 10ª gen / 16 GB / GTX 1650 |
| Jesús Adriana Martínez Trillas (Alfion) | [@Alfion72](https://github.com/Alfion72) | Audio, Score/combo, HUD, arte conceptual, armas secundarias | AMD Ryzen 5 serie 7000 / 8 GB / gráficos AMD integrados |

## Documentación

- **GDD (fuente de verdad):** [`docs/GDD.md`](docs/GDD.md)
- Propuesta original (Documento Técnico + GDD Lean): [`docs/Portafolio_GDD_Armageddon.docx`](docs/Portafolio_GDD_Armageddon.docx)
- Guía para agentes de IA: [`AGENTS.md`](AGENTS.md)
- Tablero de tarjetas (GitHub Projects): _pendiente — enlace por agregar_
- [Issues T01–T13](https://github.com/CodeCastersD20/Armagedon_CodeCasters/issues)

## Plan de trabajo

Cada épica (T01–T13) tiene sub-issues pequeñas. Ver [Issues](https://github.com/CodeCastersD20/Armagedon_CodeCasters/issues).

| ID | Épica | Responsable |
|---|---|---|
| T01 | Repositorio, ramas, agentes y proyecto Godot | Sadrach |
| T02 | Documentación y pendientes del GDD | Adrián, Erick, Alfion |
| T03 | Arte conceptual (splash, storyboard, bocetos) | Alfion |
| T04 | Jugador FPS y shader PSX | Sadrach |
| T05 | Sistema de armas | Sadrach, Alfion, Adrián |
| T06 | Arena | Erick |
| T07 | Enemigos y drops | Adrián |
| T08 | Rondas, jefes y flujo de partida | Adrián, Sadrach |
| T09 | Mercante, mejoras y poderes de Fe | Erick |
| T10 | Audio | Alfion |
| T11 | HUD, menús y QA | Erick |
| T12 | Release v1.0 | Todo el equipo |
| T13 | Score y combo | Alfion |

## Flujo de Git

- `main` y `develop` se mantienen a la par (ambas estables). Cada tarea sale de `develop` y vuelve por Pull Request con revisión cruzada.
- Rama por issue, creada y vinculada a ella: `tipo/numero-alcance-descripcion` (ej. `feat/35-player-dash-estamina`).
- Commits: `<tipo>(<zona>): <descripción>` (ej. `feat(player): añade dash con shift`).
- Los assets van directo en el repo (sin Git LFS). `.godot/` ignorado.

## Créditos de assets (itch.io)

- Amos — [PSX weapon pack](https://amos-makes.itch.io/psx-weapon-pack) (CC0)
- Kuptchi — [PSX-Weapons Assets](https://kuptchi.itch.io/f)
- Puck — [Skeleton](https://puszke.itch.io/psx-low-poly-skeleton) (CC0), [Rifle](https://puszke.itch.io/psx-rifle)
- Elbolilloduro — [Characters PSX](https://elbolilloduro.itch.io/characters-psx)
- Codyanka — [The Wrapped](https://codyanka.itch.io/the-wrapped)
