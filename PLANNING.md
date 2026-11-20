# STRADIO App — Refactor & MVP Implementation Plan

Dokumen ini merangkum rencana tindak lanjut (**follow-up refactor**) setelah migrasi awal Flutter dari repo eksperimen (`chore/migrate-app`), sekaligus peta jalan implementasi frontend sesuai spesifikasi di [`docs/PRD-MVP.md`](docs/PRD-MVP.md), [`docs/EXPERIENCE.md`](docs/EXPERIENCE.md), [`docs/DESIGN.md`](docs/DESIGN.md), dan mockup interaktif di [`docs/mockups/daylight-minimal-screens.html`](docs/mockups/daylight-minimal-screens.html).

> **Prinsip Eksekusi:** Setiap fase dikerjakan pada **PR terpisah** (bukan di PR migrasi awal) agar diff tetap bersih, mudah di-review, dan terverifikasi oleh CI (`flutter analyze` & `flutter test`).

---

## Status Saat Ini (PR #1 — `chore/migrate-app`)

- [x] Migrasi scaffold Flutter (`lib/`, `test/`, `android/`, `.github/`, `assets/images/`, `pubspec.yaml`, `analysis_options.yaml`) tanpa mengubah fitur/logic.
- [x] Gabung `.gitignore` dan pastikan 0 file sensitif (`.env`, `*.keystore`) ter-commit.
- [x] Registrasi `shaders/liquid_glass.frag` dan 13 file audio aktif (`.mp3` + `hoenn_island_loop.mp4`, hemat ~45 MB dari `.wav` & `.md`) di `pubspec.yaml`.
- [x] Update nama aset rilis APK di `.github/workflows/auto-release.yml` menjadi `stradio-*` + setup 5 GitHub Actions Secrets baru.
- [x] Verifikasi `flutter pub get`, `flutter analyze` (0 issues), dan `flutter test` (53/53 passed).

---

## Phase 1 — Housekeeping, Identitas Package & Privasi (UU PDP)

**Target Branch:** `chore/cleanup-and-privacy`

1. **Identitas Package & Android App ID**
   - [x] Rename package di `pubspec.yaml` dari `smartphone_step_detection_experiment` menjadi `stradio_app` dan perbarui seluruh `import 'package:...'` di `lib/` dan `test/`.
   - [x] Ubah `namespace` dan `applicationId` di `android/app/build.gradle.kts` dari `com.example.flutter_application_1` ke `com.stradio.app`, serta pindahkan `MainActivity.kt` ke `com/stradio/app/`.
2. **Penyatuan Sumber Algoritma (Single Source of Truth)**
   - [x] Pastikan `lib/algorithms/step_detector.dart` menjadi satu-satunya *source of truth* untuk algoritma **Adaptive Midpoint + Gravity (A1)**.
   - [x] Hapus folder duplikat `algorithm_reference/` serta hapus pengecualian `- algorithm_reference/**` di `analysis_options.yaml`.
3. **Kepatuhan UU PDP (UU No. 27/2022) untuk PostHog Analytics**
   - [x] Ubah default `analyticsEnabled` dari `true` (opt-out) menjadi **`false` (opt-in)** di `lib/models/experiment_models.dart` dan `lib/services/posthog_service.dart`.
   - [x] Matikan perekaman IP pada `PostHogEventRecord.toPostHogJson` dengan menambahkan `r'$ip': null` **dan** aktifkan *"Discard client IP data"* di PostHog Project Settings.
   - [x] Rapikan wiring toggle analytics agar konsisten memanggil `PostHogTelemetryService.setEnabled()` dan tetap dapat diakses user di Settings (serta tetap terjaga setelah `OnboardingScreen` lama dipangkas di Phase 3).
4. **Pemangkasan Kode Riset Lama**
   - [x] Hapus screen eksperimen lama yang tidak dipakai di MVP (`dashboard_screen.dart`, `setup_screen.dart`, `live_recording_screen.dart`, `results_screen.dart`, `export_screen.dart`, `sensor_labs_sheet.dart`, serta `StepDetectionApp`) beserta test terkait (`test/widget_test.dart`), sambil mengekstrak `StradioLabSettings` ke `lib/models/experiment_models.dart`.
5. **Kebersihan Aset Repo (Opsional — Ditunda ke Pasca Phase 2.3)**
   - [ ] Pindahkan `assets/audio/_raw_sources/` (~65 MB master `.wav`, tidak ter-bundle di APK) ke cloud storage tim setelah verifikasi *gapless loop* `.mp3`/`.ogg` di Phase 2.3 selesai.

---

## Phase 2 — Core Audio Engine & Background Pocket Mode

**Target Branch:** `feat/audio-engine`

1. **Arsitektur Audio 2 Layer (`docs/PRD-MVP.md` FR-3)**
   - [x] **Layer 1 (Background Loop):** Implementasi via `audioplayers` (`AudioplayersLoopBackend`, `PlayerMode.mediaPlayer`) dengan *gapless looping*, fade-in/fade-out 800 ms, dan hysteresis lockout (`>= 130 SPM` masuk Jogging Zone, `< 120 SPM` selama 3 detik keluar).
   - [x] **Layer 2 (Step SFX):** Implementasi via `audioplayers` (`AudioplayersSfxBackend`, `PlayerMode.lowLatency` — memakai native Android `SoundPool` di balik layar). *Catatan teknis:* menggantikan package `soundpool` (`2.4.1`) yang berstatus `discontinued` di pub.dev agar kompatibel penuh dengan AGP 8+ tanpa menurunkan kualitas/latensi audio.
2. **Orkestrasi 6 Sound Pack (`README.md` & `docs/PRD-MVP.md` FR-4)**
   - [x] `BREAKBEAT_FVNKY`: `Full_Fade_NoKick_BG.mp3` (>= 130 SPM) + `drums_1_step.mp3` per langkah.
   - [x] `LARI_NGACIR`: Dual-stem sinkron 140 BPM (`lari_ngacir_layer1_walk.mp3` + `lari_ngacir_layer2_jog.mp3` bar-aligned fade-in, Step SFX off).
   - [x] `GBA_SAND_HOP`: `hoenn_island_loop.mp4` dengan dynamic playback rate (`clamp(SPM / 132.5, 0.90, 1.18)`) + round-robin `gba_sand_01..03.mp3`.
   - [x] `SQUID` & `SPONGE`: Alternating left/right step SFX (`squid_1/2.MP3`, `sponge_1/2.mp3`).
   - [x] `RUBBER_BOUNCY`: `rubber_01.mp3` dengan micro-pitch alternation (1.00 / 1.03).
   - [x] Dukung **zero-interruption switching** (ganti pack saat lari tanpa reset step/timer) via `StradioAudioEngine.switchPack()` dan pemilih Sound Pack di `ActiveRunScreen`.
3. **Verifikasi Seamless Loop `LARI_NGACIR` di Perangkat Android *(Dipindahkan ke Phase 4)***
   - [ ] Uji apakah versi `.mp3` 320k sudah *gapless* tanpa klik di titik loop 72-bar saat uji HP Android fisik (Phase 4). Jika ditemukan jeda/padding MP3, convert dari `.wav` master di `assets/audio/_raw_sources/` ke `.ogg` (Vorbis/Opus).
4. **Pocket Mode (Foreground Service)**
   - [x] Hubungkan step detector + `StradioAudioEngine` ke `flutter_foreground_task` agar tetap sinkron (start, pause, resume, stop, dan tombol notifikasi `Stop run` + tampilan Sound Pack aktif).

---

## Phase 3 — Frontend Refactor ke Daylight Liquid Glass

**Target Branch:** `feat/ui-daylight-liquid-glass` (Phase 3A: Design System + P0 & P1; Phase 3B: 6 Template P2)  
**Referensi Utama:** [`docs/DESIGN.md`](docs/DESIGN.md), [`docs/EXPERIENCE.md`](docs/EXPERIENCE.md), [`docs/mockups/daylight-minimal-screens.html`](docs/mockups/daylight-minimal-screens.html)

### 3.1 Design System & Shader Foundation (`lib/theme/` & `lib/widgets/`)
- [x] Terapkan palet tetap **Daylight Instrument Minimalism**: Canvas `#F5F0E8` (*Warm Ivory*), Recessed `#EAE4DC`, Card `#FAF7F2`, Glass `rgba(250, 247, 242, 0.72)`, Solid Dock `#191923` (*Midnight*), Aksen `#FF765F` (*Sonic Coral*), `#B53D28` (*Deep Coral* AA), `#A995DB` (*Rhythm Violet*), `#46509E` (*Twilight Plum*).
- [x] Bundle 4 font statis resmi `Sora` (500/600) + `Inter` (400/500) di `assets/fonts/` dengan *tabular figures* (`tnum`).
- [x] Bangun widget reusable **`LiquidGlassLens`** menggunakan `FragmentProgram` + `shaders/liquid_glass.frag` (dengan fallback untuk *high contrast / reduced transparency* & *reduced motion*).
- [x] Pastikan seluruh *touch target* $\ge 48\ \text{dp}$ ($56\ \text{dp}$ untuk primary dock pill) dan pangkas 6 screen shell 5-tab lama (`onboarding`, `root_navigation_shell`, `home`, `library`, `activity`, `settings`) beserta `stradio-reference-1..3.png`.

### 3.2 Core MVP Surfaces (Mapping dari 12 Layar Mockup Stitch)
| Prioritas | Status | Layar Mockup (`daylight-minimal-screens.html`) | Fungsi di Flutter MVP |
| :--- | :---: | :--- | :--- |
| **P0 (Core)** | [x] | **Audio Device Recommendation** | Modal *first-launch* (`340px` Daylight Cream card + vektor headphone `CustomPainter`, persist `has_seen_audio_recommendation` di `SharedPreferences`). |
| **P0 (Core)** | [x] | **Pre-Run Ignition** | **Surface 1:** Zero-friction launch (<3 detik), 1 `LiquidGlassLens` tray 6 Sound Pack, solid Midnight pill `Swipe to start`, tombol Settings ringkas (UU PDP opt-in). |
| **P0 (Core)** | [x] | **Active Run Instrument** | **Surface 2:** Dual-tone header (`Stride / Rhythm`), Circular Acoustic Dial + `LiquidGlassLens` yang bereaksi <30 ms per langkah, 2 borderless metrics (`Steps`, `Cadence`), bottom dock `LiquidGlassLens` + `Hold 1.5s to end`. |
| **P0 (Core)** | [x] | **Cadence Summary** | **Surface 3:** Hero Glass Circle (SPM ring), 3 frosted metric pills (Distance, Duration, Pace), 3.5px cadence stems + filter Active/Walking, audio footer pill, `Export IG Story` & `Start new run`. |
| **P1 (Support)** | [x] | **Sensor Calibration** | Sheet kalibrasi & fallback jujur jika izin/stream akselerometer belum tersedia (`SensorCalibrationSheet`). |
| **P1 (Share)** | [x] | **Share Rhythm Modal / Studio** | Halaman penuh `ShareStudioScreen` dengan 2 mode (*Transparent Sticker* & *Photo Glass*), 1-tap `Save to Gallery` (`gal`), & `Share` (`share_plus`). |
| **P2 (Phase 3B)** | [x] | **Photo Glass (3x):** *Classic Wave*, *Orbital Nexus*, *Topo Shard* | Template overlay foto 9:16 (`image_picker` Galeri + Kamera + 3 preset ambient) + auto-tint RGB dinamis + *drag-to-reposition*. |
| **P2 (Phase 3B)** | [x] | **9:16 Story (3x):** *Aura Wave*, *Sonic Dial*, *Minimal Stride* | Template stiker transparan siap export PNG resolusi tinggi tanpa foto latar. |

---

## Phase 4 — Validasi Perangkat Fisik & Kesiapan Rilis

**Target Branch:** `chore/release-readiness`

- [ ] Uji di HP Android fisik (tangan & saku celana, layar mati, TWS Bluetooth) untuk memverifikasi latensi deteksi <30 ms, latensi audio <50 ms, dan 0 *false steps* saat diam.
- [ ] Uji alur CI/CD rilis otomatis dengan tag `v*` di `.github/workflows/auto-release.yml` dan verifikasi ukuran APK split-ABI (`stradio-v*-arm64-v8a.apk` & `armeabi-v7a.apk`).
- [ ] Siapkan dokumen **Privacy Policy** dan pengisian **Google Play Data Safety** (jika dipublikasikan ke Play Store).
