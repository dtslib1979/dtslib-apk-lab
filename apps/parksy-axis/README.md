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
- [ ] Session 2: FSM Logic
- [ ] Session 3: Overlay UI
- [ ] Session 4: Android Config
- [ ] Session 5: Build + Deploy
