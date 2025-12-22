# Parksy Axis

박씨 좌표 - Broadcast stage indicator overlay

## Math Model

```
state: ℤ₅ (mod 5)
tap(): s → (s+1) mod 5

Domain: {tap} → {0,1,2,3,4}
Codomain: {Capture, Note, Build, Test, Publish}
```

## Structure

```
[Idea]
├─ Capture  (0)
├─ Note     (1)
├─ Build    (2)
├─ Test     (3)
└─ Publish  (4)
```

## Interaction

- Single tap: next state
- Cyclic: Publish → Capture

## Status

- [x] Session 1: Scaffold
- [x] Session 2: FSM Logic
- [x] Session 3: Overlay UI
- [x] Session 4: Android Config
- [x] Session 5: Build + Deploy

## Download

[APK Download](https://nightly.link/dtslib1979/dtslib-apk-lab/workflows/build-parksy-axis/main/parksy-axis-debug.zip)
