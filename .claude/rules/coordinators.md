---
paths:
  - "CookSavvy/Coordinators/**"
---

# Coordinator Hierarchy

- `AppCoordinator`: Root coordinator managing tab-level coordinators via lazy factory methods
- Feature coordinators: `DiscoverCoordinator`, `JourneyCoordinator`, `SettingsCoordinator`
- `DiscoverCoordinator`: Discover landing/results flow, recipe detail, recipe list, cook mode (full screen cover), camera, create recipe, upgrade
- `JourneyCoordinator`: My Kitchen navigation for saved recipes, recent cooks, shopping list, stats, recipe detail, recipe list, settings, create recipe, upgrade
- Each coordinator owns its navigation stack and sheet presentations
- ViewModels hold weak references to coordinators for navigation

## File Map

```
Coordinators/
├── Coordinator.swift              — Base protocol
├── AppCoordinator.swift           — Root coordinator (Discover + Journey)
├── DiscoverCoordinator.swift      — Discover tab navigation
├── JourneyCoordinator.swift       — Journey tab navigation
└── SettingsCoordinator.swift
```
