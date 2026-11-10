# ARMAGEDDON

> Roguelike shooter en primera persona por oleadas, estética low-poly PSX. Hecho en **Godot 4** (GDScript).

Universidad Tecnológica de Hermosillo, Sonora — TI, Desarrollo y Gestión de Software Multiplataforma.
Equipo: **CodeCasters**.

## Resumen

El Infierno se desbordó y la Tierra quedó inhabitable. Eres el Arcángel **Zahariel**: al cruzar al Infierno pierdes tus poderes divinos y quedas atrapado en la Arena del Abismo, bajo la burla de **Lucifer** y con la sola ayuda del **Mercante Anónimo**. Sobrevive a las oleadas, compra mejoras con Esquirlas de Alma y recupera tu poder.

- **Género:** roguelike + shooter en primera persona (melee y fuego), muerte permanente.
- **Público:** +16.
- **Motor:** Godot Engine 4 (3D), Blender para ajustar modelos, Git + Git LFS + GitHub Projects.
- **Arena única:** "El Foso de los Caídos" — plataforma central, pilares, fosos de lava, santuario del Mercante.
- **Enemigos:** Esqueletos Condenados, Demonios del Averno, The Wrapped; jefes secretos (Malenia, animatrónicos) con 0.5% de aparición desde la Oleada 10.

## Equipo

| Integrante | GitHub | Rol | Hardware |
|---|---|---|---|
| Sadrach Juan Diego García Flores | [@Sadrach34](https://github.com/Sadrach34) | Programación principal, shaders PSX, armas, builds | Ryzen 5 5500 / 16 GB / RX 7600 |
| Adrián Eduardo Santos Rosales | [@AdrianS-127](https://github.com/AdrianS-127) | Arena, oleadas/IA, modelos 3D | Ryzen 5 5500 / 16 GB / RX 7600 |
| Erick Daniel Arvayo Avilés | [@Ddarielz](https://github.com/Ddarielz) | UI/Score, tienda, audio, QA | Core i5 10ª gen / 16 GB / GTX 1650 |

## Documentación

- Propuesta (Documento Técnico + GDD Lean): [`docs/Portafolio_GDD_Armageddon.docx`](docs/Portafolio_GDD_Armageddon.docx)
- Tablero de tarjetas (GitHub Projects): _pendiente — enlace por agregar_
- [Issues T01–T12](https://github.com/CodeCastersD20/Armagedon_CodeCasters/issues)

## Plan de trabajo

| ID | Tarea | Responsable |
|---|---|---|
| T01 | Repo, .gitignore, Git LFS, README | Sadrach |
| T02 | Documento técnico y GDD Lean | Adrián, Erick |
| T03 | Boceto de arena, splash y storyboard | Adrián |
| T04 | Controlador FPS de Zahariel + shader PSX | Sadrach |
| T05 | Arsenal de armas | Sadrach |
| T06 | Arena y santuario del Mercante | Adrián |
| T07 | IA de enemigos | Adrián |
| T08 | Director de oleadas y jefe secreto | Adrián, Sadrach |
| T09 | Tienda, mejoras y Score | Erick |
| T10 | Voz de Lucifer, música y SFX | Erick |
| T11 | HUD, menú y QA en las 3 PCs | Erick |
| T12 | Release v1.0 | Todo el equipo |

## Flujo de Git

- `main`: solo entregas estables. `develop`: integración vía Pull Request con revisión cruzada.
- Una rama por tarjeta: `feature/T04-zahariel-fps`, `art/…`, `audio/…`, `docs/…`, `fix/…`, `chore/…`, `release/…`.
- Commits semánticos ligados a la tarjeta: `feat(#T05): integra espada de Amos`.
- Binarios (`*.fbx *.glb *.gltf *.blend *.png *.wav *.ogg`) con Git LFS. `.godot/` ignorado.

## Créditos de assets (itch.io)

- Amos — [PSX weapon pack](https://amos-makes.itch.io/psx-weapon-pack) (CC0)
- Kuptchi — [PSX-Weapons Assets](https://kuptchi.itch.io/f)
- Puck — [Skeleton](https://puszke.itch.io/psx-low-poly-skeleton) (CC0), [Rifle](https://puszke.itch.io/psx-rifle), [Malenia](https://puszke.itch.io/psx-elden-ring-malenia), [FNAF models](https://puszke.itch.io/retro-fnaf-models) (uso académico; licencia por confirmar)
- Elbolilloduro — [Characters PSX](https://elbolilloduro.itch.io/characters-psx)
- Codyanka — [The Wrapped](https://codyanka.itch.io/the-wrapped)
