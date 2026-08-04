# Engine Architecture Specification v1.0

## Purpose

This document defines the permanent architectural principles of the
Bomberman Engine.

## Philosophy

> The game does not depend on Godot. Godot depends on the game.

## Architecture

``` text
Presentation (Godot)
        │
        ▼
Input → Commands
        │
        ▼
GameManager
        │
        ▼
Tick Loop
        │
        ▼
Systems
        │
        ▼
Domain
        │
        ▼
Events
        │
        ▼
Presentation
```

## Layers

### Domain

Pure game state. Entities contain state only.

### Systems

Contain gameplay rules. Systems are RefCounted.

### Core

GameManager, GameState, TickLoop, EventBus, GameBalance.

### Infrastructure

Networking, Steam, Replay, Serialization.

### Presentation

Rendering, UI, Audio, Camera.

## Responsibilities

-   GameManager coordinates systems.
-   GameState stores global match state.
-   Systems own their entities.

## Commands

Immutable intent objects.

## Events

Immutable facts.

## Dependency Injection

Dependencies are created only at the application root.

## Code Conventions

### Naming

-   Classes: PascalCase
-   Methods/variables: snake_case
-   Constants: UPPER_SNAKE_CASE

### RefCounted

Use for Domain, Systems, Commands, Events.

### Node

Use only for rendering, UI, audio, camera and scene composition.

### Rules

-   No get_node() in gameplay logic.
-   No absolute paths.
-   No gameplay singletons.
-   One owner per piece of data.
-   Prefer Events over direct system calls.
-   Gameplay runs only on ticks.

## Golden Rules

1.  The game does not depend on Godot.
2.  Entities contain state.
3.  Systems contain behavior.
4.  Presentation never changes gameplay.
5.  Tick-based simulation.
6.  Commands express intent.
7.  Events express facts.
8.  Dependencies are injected.
9.  Systems stay independent.
10. Architecture before implementation.
