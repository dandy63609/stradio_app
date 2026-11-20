# AGENTS.md

# STRADIO: Project Context & Agent Instructions

> **Project:** STRADIO  
> **Tagline:** Run the Vibe.  
> **Category:** Movement-Powered Music Experience  
> **Core Concept:** Movement becomes music.  
> **Name Origin:** Stride + Audio

---

# 1. Project Overview

## 1.1 What is STRADIO?

STRADIO is a mobile application that transforms physical movement into an interactive audio experience, primarily designed for runners.

Using smartphone motion sensors, STRADIO detects running steps and translates movement into audio interactions, creating a more immersive and engaging running experience.

Unlike conventional fitness applications that primarily focus on distance, pace, calories, and performance statistics, STRADIO focuses on the relationship between human movement and sound.

**The central idea: Your movement influences your listening experience.**

STRADIO aims to make running more engaging by creating a dynamic connection between physical activity and audio.

## 1.2 Product Positioning

STRADIO is not intended to be:
- A conventional fitness tracker.
- A generic step-counter application.
- A music streaming platform.
- A traditional running performance dashboard.

STRADIO is:
- A movement-powered music experience.
- An interactive audio companion for runners.
- A technology-driven digital lifestyle application.
- An experience where physical movement influences sound.

All product and technical decisions should reinforce this positioning.

## 1.3 Product Vision

Build an experience where running and music feel connected rather than functioning as two separate activities.

STRADIO should make users feel that their movement contributes to the audio experience.

---

# 2. Project Objectives

The initial development objective is to build and validate a functional Minimum Viable Product (MVP).

The MVP must demonstrate that:

1. A smartphone can reliably detect running steps.
2. Detected movement can trigger audio interactions.
3. Audio feedback can happen with sufficiently low latency.
4. The experience remains enjoyable during continuous running.
5. Users find the movement-responsive audio experience valuable enough to use repeatedly.

Prioritize product validation over unnecessary complexity.

Do not build features simply because conventional fitness applications have them.

---

# 3. Target Users

## Primary Target Audience

People who enjoy running, particularly:
- Beginner and intermediate runners.
- Recreational runners.
- People who regularly listen to music while running.
- People looking for a more engaging running experience.
- Younger, digitally connected users interested in technology and music.

## User Problems to Explore

Potential problems STRADIO aims to address:
- Running can become repetitive and monotonous.
- Conventional music listening is relatively passive.
- Music does not necessarily respond to physical movement.
- Runners may want a more immersive experience.
- Maintaining motivation during longer running sessions can be difficult.

These are product hypotheses, not proven facts. Do not treat them as validated research findings without evidence.

---

# 4. MVP Scope

The MVP should remain focused on the core movement-to-audio experience.

## 4.1 Core Features

### A. Running Session

Users should be able to start, pause, resume, and finish a running session.

The interface should clearly communicate the current session state.

### B. Step Detection

Use smartphone motion sensors to detect individual running steps.

The system should:
- Collect accelerometer data.
- Process acceleration signals.
- Identify potential step events.
- Calculate steps per minute (SPM).
- Handle variations in running rhythm.
- Minimize false-positive and false-negative detections.

### C. Movement-to-Audio Interaction

Detected steps should trigger or influence audio feedback.

The interaction should feel responsive and natural.

Avoid unnecessary delays between detected movement and audio output.

### D. Background Audio

Provide continuous background music that complements the running experience.

Background music should not compete with movement-triggered sound effects.

### E. Session Summary

After completing a session, provide relevant information such as:
- Total steps.
- Session duration.
- Average steps per minute.
- Other measurements only when they can be reliably collected.

Do not fabricate measurements or display inaccurate statistics.

## 4.2 Features Not Prioritized Initially

Unless explicitly requested, do not prioritize:
- Social networking.
- Competitive leaderboards.
- Complex achievement systems.
- AI coaching.
- Advanced route mapping.
- Calorie estimation.
- Subscription systems.
- Large-scale music streaming integrations.
- Complex user profiles.

These features can be considered after the core experience has been validated.

---

# 5. Technical Stack

## 5.1 Primary Technology

| Layer | Technology |
|---|---|
| Mobile framework | Flutter |
| Programming language | Dart |
| Motion detection | Smartphone accelerometer |
| Audio interaction | Flutter-compatible audio implementation |
| Development environment | VS Code |
| Initial platform | Android |

Flutter is the established development direction.

Do not migrate the application to another framework or programming language without explicit approval.

## 5.2 Existing Development Context

The project has previously experimented with:
- Accelerometer-based step detection.
- Acceleration magnitude calculations.
- Sampling around 100 Hz.
- Adaptive Midpoint + Gravitation step-detection approach.
- Minimum step intervals.
- Steps-per-minute calculations.
- CSV-based experiment data collection.
- Event matching for evaluating detection performance.

Previously discussed experimental parameters include:
- Sampling frequency: approximately 100 Hz.
- Minimum step interval: approximately 250–300 ms.
- Acceleration magnitude: `sqrt(x*x + y*y + z*z)`.

These are experimental references, not immutable production requirements.

## 6.2 Selected Algorithm: Adaptive Midpoint + Gravitation

The project has selected **Adaptive Midpoint + Gravitation** as its step-detection approach. This supersedes generic adaptive thresholding as the stated algorithm direction.

Agents must:
- Preserve this selected algorithm direction when working on step detection.
- Inspect the current implementation, research notes, and experiment results before modifying it.
- Avoid replacing it with a different detection approach without explicit approval.
- Keep the algorithm modular and testable.
- Validate changes against recorded sensor data and real-device running tests.

The exact mathematical formulation, midpoint update rules, gravitation model, parameter values, and tuning strategy must come from the project's implementation or technical documentation. **Do not invent or assume these details** if they are not documented.

Always inspect the existing implementation and experiment results before changing algorithm parameters.

---

# 6. Step Detection Principles

Step detection is one of STRADIO's most important technical components.

Poor detection accuracy directly damages the listening experience.

## 6.1 Acceleration Magnitude

A basic approach is to calculate the magnitude of three-axis acceleration:

```dart
magnitude = sqrt(x * x + y * y + z * z);
```

This provides a combined signal that can be analyzed for movement patterns.

## 6.2 Detection Considerations

The selected Adaptive Midpoint + Gravitation algorithm should be evaluated against:
- Sensor noise.
- Gravity contribution.
- Different running intensities.
- Irregular running patterns.
- Phone orientation.
- Phone placement.
- Walking versus running.
- Duplicate step events.
- Missing step events.

## 6.3 Algorithm Design

Prefer a modular approach.

Potential responsibilities:
- Sensor data collection.
- Signal preprocessing.
- Filtering.
- Peak or event detection.
- Step validation.
- SPM calculation.
- Detection evaluation.

Do not combine every responsibility into one large class.

## 6.4 Evaluation

Evaluate detection performance using actual experimental data.

Useful metrics include:
- Precision.
- Recall.
- F1-score.
- Detection latency.
- False positives.
- False negatives.

Test different phone positions, particularly:
- Hand-held.
- Trouser pocket.

Do not claim that an algorithm is accurate without supporting experimental evidence.

---

# 7. Audio Experience

Audio is not merely an additional feature. It is a fundamental part of STRADIO's identity.

## 7.1 Two Audio Layers

The intended experience contains two complementary audio layers.

**Layer 1: Background Music**
- Continuous playback.
- Cinematic and atmospheric direction.
- Suitable for longer running sessions.
- Avoid unnecessarily crowded arrangements.
- Maintain a consistent listening experience.

**Layer 2: Movement-Triggered Sound Effects**
- Triggered by detected steps or movement events.
- Deep, mellow, punchy bass character.
- Responsive playback.
- Complement the background music.

## 7.2 Audio Engineering Priorities

Prioritize:
1. Low playback latency.
2. Consistent playback.
3. Minimal audio interruptions.
4. Appropriate sound layering.
5. Smooth audio transitions.
6. Efficient resource consumption.

Avoid creating an experience where every detected step produces an excessively loud or repetitive sound.

The audio should feel intentional, not mechanically annoying.

## 7.3 Audio Copyright

Do not introduce copyrighted music or sound recordings without appropriate authorization.

Use original, licensed, or otherwise legally permitted audio assets.

Do not assume that publicly accessible audio is free to use.

---

# 8. Brand Identity & Design Direction

Every agent working on the interface or visual assets must understand STRADIO's brand identity.

## 8.1 Brand Foundation

- **Brand Name:** STRADIO
- **Tagline:** Run the Vibe.
- **Brand Essence:** Movement becomes music.
- **Product Category:** Movement-Powered Music Experience.

## 8.2 Visual Direction

The selected visual direction is **A. Original Sonic Expression**.

The visual identity should communicate sound, movement, rhythm, and physical energy through distinctive visual elements.

Key characteristics:
- Abstract sonic expression.
- Flowing forms.
- Movement-inspired geometry.
- Layered textures.
- Distinctive visual composition.
- Modern digital aesthetics.
- Premium but accessible presentation.

## 8.3 Logo Direction

The finalized logo direction uses an expressive S-shaped symbol.

The design incorporates:
- Three-dimensional visual characteristics.
- Textured surfaces.
- Flowing and organic forms.
- Sound-inspired visual elements.

The logo should remain recognizable and should not be unnecessarily redesigned.

Do not replace the established logo with generic running icons, headphones, or soundwave symbols.

## 8.4 Color Palette

The finalized color palette is based on the approved STRADIO logo and brand identity.

Important instructions:
- Inspect the existing brand assets before selecting colors.
- Reuse approved brand colors.
- Maintain consistent contrast.
- Avoid introducing unrelated colors.
- Do not independently redefine the brand palette.

The actual logo and color references in the repository take precedence over descriptive interpretations in this document.

## 8.5 Typography

Typography should support the brand's modern, expressive, and digital character.

Prioritize:
- Readability.
- Clear hierarchy.
- Consistent typography.
- Appropriate mobile font sizing.
- Strong numerical readability for running-session information.

Do not introduce excessive font families.

---

# 9. UI/UX Design Principles

The application should prioritize the running experience.

Users may interact with STRADIO while moving, so the interface must be understandable at a glance.

## 9.1 General Principles

- Mobile-first design.
- Minimal cognitive load.
- Clear visual hierarchy.
- Large and accessible touch targets.
- High readability.
- Consistent spacing.
- Intuitive navigation.
- Minimal unnecessary interaction.

## 9.2 Running Interface

The running interface deserves particular attention.

Users should be able to understand:
- Whether a session is active.
- Whether movement is being detected.
- Current running rhythm or SPM.
- Whether audio is playing.
- How to pause or finish the session.

Avoid overcrowding the running screen with unnecessary metrics.

## 9.3 Design Consistency

Use reusable components rather than implementing every screen independently.

Maintain consistency across:
- Buttons.
- Cards.
- Navigation.
- Typography.
- Icons.
- Spacing.
- Colors.
- Interactive states.

Follow the existing design system when one is available.

Do not introduce new UI patterns without a clear reason.

---

# 10. Software Architecture

The codebase should remain modular, maintainable, and easy to extend.

## 10.1 Architectural Principles

- Separation of concerns.
- Single responsibility.
- Reusable components.
- Clear naming conventions.
- Explicit data flow.
- Testable business logic.
- Minimal unnecessary dependencies.

## 10.2 Suggested Responsibility Separation

The application should maintain clear boundaries between:

**Presentation Layer**
- Screens.
- Widgets.
- UI components.
- Navigation.

**Business Logic Layer**
- Running-session management.
- Step detection coordination.
- SPM calculations.
- Audio interaction decisions.

**Data and Service Layer**
- Accelerometer access.
- Audio playback.
- Session persistence.
- CSV export.
- External integrations, when required.

This is a conceptual separation, not an instruction to introduce an unnecessarily complicated architecture.

Inspect the existing repository before deciding how to organize files.

## 10.3 Dependency Management

Before installing a new package:
1. Check whether an existing dependency already provides the functionality.
2. Evaluate package maintenance and compatibility.
3. Consider Android support.
4. Consider application size and performance.
5. Avoid unnecessary dependencies.

Never install a package just because it appears convenient.

---

# 11. Development Rules for AI Agents

These instructions apply to every coding agent working on STRADIO.

## 11.1 Inspect Before Modifying

Before making changes:
1. Inspect the repository structure.
2. Read the existing README and documentation.
3. Inspect relevant source files.
4. Understand existing implementation decisions.
5. Identify dependencies and their versions.
6. Determine whether the requested functionality already exists.

Do not assume the repository is empty or that the architecture matches your expectations.

## 11.2 Preserve Existing Functionality

Do not unnecessarily:
- Rewrite working modules.
- Delete existing features.
- Rename files without justification.
- Replace existing libraries.
- Change project configuration.
- Modify unrelated components.
- Remove existing experimental implementations.

Prefer targeted modifications over unnecessary rewrites.

## 11.3 No Unrequested Scope Expansion

Implement the requested functionality without inventing additional features.

If a task requires changing the architecture or introducing a significant dependency, explain the reason before making substantial changes.

Do not silently make product decisions on behalf of the project owner.

## 11.4 Code Quality

All code should be:
- Readable.
- Modular.
- Maintainable.
- Consistent with existing conventions.
- Properly structured.
- Appropriately documented.

Avoid:
- Unnecessary abstractions.
- Giant classes.
- Duplicate logic.
- Hardcoded magic values.
- Unused dependencies.
- Placeholder implementations presented as complete functionality.

## 11.5 Error Handling

Consider real-world mobile conditions:
- Sensor access unavailable.
- Permissions denied.
- Audio initialization failures.
- Interrupted playback.
- Application backgrounding.
- Device resource limitations.
- Unexpected session termination.

Handle errors explicitly and provide understandable feedback.

Never silently pretend that an operation succeeded.

---

# 12. Testing & Validation

Testing is essential because STRADIO depends on real-time sensor and audio interactions.

## 12.1 Required Testing Priorities

Test:
- Step detection.
- Detection accuracy.
- Duplicate step prevention.
- SPM calculations.
- Audio trigger responsiveness.
- Audio continuity.
- Session state transitions.
- Permission handling.
- Application lifecycle behavior.

## 12.2 Real-Device Testing

Do not rely exclusively on emulators.

Accelerometer behavior and audio performance should be validated on physical Android devices.

## 12.3 Regression Testing

After modifying existing functionality:
1. Run relevant tests.
2. Check for compilation errors.
3. Check for runtime exceptions.
4. Verify that existing functionality still works.
5. Report any remaining limitations.

Do not claim tests passed if they were not executed.

---

# 13. Performance & Resource Management

STRADIO should be suitable for student-budget development and ordinary consumer smartphones.

Prioritize:
- Efficient sensor processing.
- Low memory consumption.
- Efficient audio resource management.
- Battery-conscious background behavior.
- Minimal unnecessary network requests.
- Smooth UI rendering.

Avoid computationally expensive solutions when simpler alternatives provide equivalent results.

Performance should be evaluated on actual devices.

---

# 14. Privacy & Data Handling

Treat user movement data as personal information.

Development principles:
- Request only necessary permissions.
- Explain sensor usage clearly.
- Do not collect unnecessary personal information.
- Avoid transmitting sensor data without a legitimate requirement.
- Keep experimental data collection transparent.
- Do not hardcode API keys or secrets.
- Never expose credentials in source code or logs.

Prefer local processing for movement detection when practical.

Any cloud integration must have a clear product justification.

---

# 15. Agent Workflow

Every agent should follow this workflow when receiving a development task.

### Step 1 — Understand

Read the task and identify the intended outcome.

### Step 2 — Inspect

Examine relevant repository files and existing implementations.

### Step 3 — Plan

Determine:
- Files that need modification.
- Dependencies involved.
- Potential risks.
- Testing requirements.

For substantial tasks, present a concise implementation plan before making changes.

### Step 4 — Implement

Make the smallest reasonable set of changes that achieves the objective.

Follow existing conventions.

### Step 5 — Verify

Run appropriate tests, analyzers, or builds.

Check for regressions.

### Step 6 — Report

Provide a concise summary containing:
- What was implemented.
- Which files were changed.
- Important technical decisions.
- Tests executed and their results.
- Known limitations.
- Any follow-up work required.

Never claim completion without verifying the implementation.

---

# 16. Decision-Making Priorities

When making technical or product decisions, prioritize the following in order:

1. **Core Experience:** Does this improve the relationship between movement and sound?
2. **Reliability:** Does this work consistently in real-world running conditions?
3. **Responsiveness:** Does this maintain an enjoyable low-latency audio experience?
4. **Simplicity:** Is there a simpler implementation?
5. **Maintainability:** Can future agents understand and extend the implementation?
6. **Performance:** Is it efficient on ordinary smartphones?
7. **Scalability:** Can the implementation accommodate future features without unnecessary complexity?

Do not prioritize scalability over a functional MVP.

Do not prioritize visual polish over a reliable core experience.

Do not prioritize feature quantity over product quality.

---

# 17. Current Project Status

This section describes the known project context and should be updated as the project evolves.

| Area | Known Status |
|---|---|
| Product concept | Established |
| MVP direction | Established |
| Flutter development | Established |
| Step detection experiments | Started |
| Audio experience concept | Defined |
| Brand name | Established |
| Logo | Finalized |
| Brand color direction | Established |
| Brand design brief | In progress |
| UI/UX architecture | To be developed |
| UI design system | To be developed |
| UI PRD | To be developed |
| MVP implementation | Requires repository verification |
| User validation | Future milestone |

Important: The actual repository is the source of truth for implementation status. This document may contain historical context that has not yet been implemented in code.

---

# 18. Final Instructions

Every agent working on STRADIO must understand the following:

**STRADIO is an experience-first product.**

The objective is not to build the largest possible fitness application.

The objective is to create a meaningful relationship between physical movement and sound.

Every feature, design decision, architectural choice, and technical implementation should contribute to that experience.

When uncertain:
- Inspect before assuming.
- Ask before making major product decisions.
- Prefer simple and reliable solutions.
- Preserve existing working functionality.
- Validate with real-world testing.
- Document important decisions.

**Build the experience first. Optimize the technology around it.**

---

# 19. STRADIO Website (`stradio_web`) Context & Instructions

When working on the **STRADIO Website** (`stradio_web/`), agents **MUST** read the dedicated website instructions and specifications inside `stradio_web/`:

- [`stradio_web/AGENTS.md`](stradio_web/AGENTS.md) — Website-specific guardrails & Design-First Workflow (Canva + Figma + Pencil `pen.dev` before React code).
- [`stradio_web/docs/01-brand-system.md`](stradio_web/docs/01-brand-system.md) — Locked color palette (`#191923` Midnight, `#F5F0EB` Warm Ivory, `#FF7A59` Sonic Coral, `#A995DB` Rhythm Violet, `#4B3D8E` Supporting Violet), typography (`Sora` + `Inter`), and UI styling rules.
- [`stradio_web/docs/02-storyboard-scenes.md`](stradio_web/docs/02-storyboard-scenes.md) — Scene 01 (Light Start), Scene 02 (Dark Transformation + Game-Loading-Screen VFX + Pitch), and Scene 03 (Purely Visual 2-Layer Audio & Adaptive Midpoint + Gravitation Sensor Science).
- [`stradio_web/docs/03-motion-vfx-specs.md`](stradio_web/docs/03-motion-vfx-specs.md) — Scroll choreography, Dual-Video VFX Handoff, and exported Frame 135 keyframe (`stradio_web/docs/references/frame_135_midnight_base.png`).
- [`stradio_web/docs/04-implementation-perf.md`](stradio_web/docs/04-implementation-perf.md) — Website directory architecture (`sections/`, `animations/`, `components/`, `hooks/`) and Android 60fps performance budget.

---

*End of STRADIO Project Context & Agent Instructions.*

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read these installed skill files directly (use these paths even if a same-named global skill exists):
- Core filter, always on: `antislop`: `.agents/skills/antislop/SKILL.md`
- UI / visual: `antislop-ui`: `.agents/skills/antislop-ui/SKILL.md`
- Mobile / responsive: `antislop-layoutmobile`: `.agents/skills/antislop-layoutmobile/SKILL.md`
Before starting, follow the core's "Two Usage Modes" section in strict order: explicit session instruction first, then global preference, then ask. A session instruction always wins. For a resolved mode, say `antislop active: <mode> (session override).` or `antislop active: <mode> (global preference).` once before presenting findings or making edits, using the actual mode and source. Acknowledging the user's request without naming the source does not replace this notice.
Only an explicit choice of antislop during or after selects a session mode. A request to review, audit, or avoid file edits does not select a mode; read the global preference in that case. Another skill's mode does not select antislop's mode.
If the mode is unresolved, ask during/after and end the response; wait for the answer before any UI review, planning, or concept. For read-only tasks, put the active-mode notice only at the start of the final answer, never in progress messages. For editing tasks, announce before the first edit and omit it from the final answer.
To update antislop later: `npx antislop-ai --update`, or run `npx antislop-ai` and pick Overwrite them.
<!-- antislop:end -->
