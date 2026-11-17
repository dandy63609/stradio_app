# STRADIO App: Workspace

This is the central workspace containing product specifications, curated sound packs, design systems, and validated step-detection algorithms for the **STRADIO MVP (Mobile Application)**.

---

## Workspace Directory Structure

```
stradio_app/
├── docs/
│   ├── PRD-MVP.md                 # Product Requirements Document (PRD-Light)
│   ├── EXPERIENCE.md              # Interaction, state, & accessibility specs
│   ├── DESIGN.md                  # Visual identity tokens & typography specs
│   └── mockups/                   # Interactive HTML prototypes & visual tests
├── assets/
│   ├── audio/                     # 6 Curated Sound Packs & Stems
│   │   ├── breakbeat_fvnky/       # DDHANNi Indonesian Breakbeat (Step kick + BG)
│   │   ├── lari_ngacir/           # DDHANNi Dual-Stem Progression (Walk + Jog)
│   │   ├── gba_sand_hop/          # 16-Bit Route 104 Chiptune Loop + Sand SFX
│   │   ├── squid/                 # Squidward Hollow Suction Clunks (Left/Right)
│   │   ├── sponge/                # SpongeBob Wet Cartoon Squelches (Left/Right)
│   │   ├── rubber_bouncy/         # Elastic Cartoon Shoes (Micro-pitch mod)
│   │   └── _raw_sources/          # Archive of un-trimmed master deliverables
│   └── design/                    # Brand identity assets, ribbons & SVG curves
├── algorithm_reference/
│   ├── step_detector.dart         # Validated A1 Adaptive Midpoint algorithm
│   └── step_detection_test.dart   # 14 passing unit & stationary noise tests
├── shaders/
│   └── liquid_glass.frag          # Flutter GLSL shader for liquid glass refraction
├── notes/
│   └── WhatsApp Chat...txt        # Team coordination & decision log
├── PRODUCT.md                     # Impeccable product schema
└── AGENTS.md                      # Project context & behavioral instructions
```

---

## Active Sound Pack Lineup (6 Packs)

| Pack ID | Identity & Artist | Layer 1 (Background) | Layer 2 (Step SFX) |
| :--- | :--- | :--- | :--- |
| **BREAKBEAT_FVNKY** | Indonesian Breakbeat (DDHANNi) | `Full_Fade_NoKick_BG.mp3` (>= 130 SPM) | `drums_1_step.mp3` (punchy kick) |
| **LARI_NGACIR** | Dual-Stem Progression (DDHANNi) | `lari_ngacir_layer1_walk` + `layer2_jog` | Disabled (pure music flow) |
| **GBA_SAND_HOP** | 16-Bit Nostalgia (Chiptune) | `hoenn_island_loop.mp4` (tempo-synced) | `gba_sand_01..03.mp3` (round-robin) |
| **SQUID** | Classic Squidward Stride | Silent | `squid_1` / `squid_2` (bipedal alt) |
| **SPONGE** | Classic SpongeBob Stride | Silent | `sponge_1` / `sponge_2` (bipedal alt) |
| **RUBBER_BOUNCY** | Elastic Cartoon Shoe | Silent | `rubber_01.mp3` (L/R pitch mod) |

---

## Current Status & Next Steps

1. **Algorithm:** Validated on **Adaptive Midpoint + Gravity (A1)** with 1.2 m/s² stationary noise gate.
2. **Product & UX Specifications:** Locked in [`docs/PRD-MVP.md`](docs/PRD-MVP.md), [`docs/EXPERIENCE.md`](docs/EXPERIENCE.md), and [`docs/DESIGN.md`](docs/DESIGN.md).
3. **Audio Architecture:** Audio stems trimmed, normalized, and categorized across all 6 sound packs.
4. **Current Phase:** Architecture handoff to **Winston** (`bmad-architecture`) to scaffold the Flutter application structure and define service contracts.
