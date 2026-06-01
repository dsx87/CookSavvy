---
paths:
  - "CookSavvyUITests/**"
---

# UI Tests

> **DO NOT run UI tests** — UITests are disabled in all test plans and must not be executed by Claude or any automated tool. They require manual execution only.

## Launch Arguments

- `--uitesting` — enables deterministic UI-test bootstrapping
- `--skip-onboarding` — skips onboarding unless paired with `--fresh-install`
- `--fresh-install` — forces first-launch onboarding
- `--premium-user` — boots with premium entitlements via `MockSubscriptionService`
- `--with-cooking-history` — seeds deterministic cooking sessions
- `--with-favorites` — seeds favorite recipes
- `--with-shopping-items` — seeds shopping list rows
- `--empty-db` — skips DB seeding for empty-state coverage
- `--large-dataset` — adds a larger deterministic recipe set
- `--camera-limit-reached` — preloads free-tier camera usage to the weekly cap
- `--signed-in-apple` — boots with a mock Apple-authenticated session (non-anonymous)

## File Map

```
CookSavvyUITests/
├── Helpers/
│   ├── AccessibilityID.swift     — shared UI test identifiers
│   ├── BaseUITest.swift          — base classes for common launch configurations
│   └── XCUIApplication+Helpers.swift
└── *.swift                       — feature-oriented XCUITest suites
```
