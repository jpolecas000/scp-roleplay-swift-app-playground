# Containment Shift

A small, original top-down containment-facility action game built with SwiftUI.
It uses procedural vector graphics and has no external assets or dependencies.
The setting and characters are original and are not affiliated with Roblox or
any existing roleplay game.

## Play

Open [`ContainmentShift.swiftpm`](./ContainmentShift.swiftpm) directly in Swift
Playgrounds. Its package manifest declares an iOS app product for iPhone and
iPad. You can also open the repository root as a Swift package in Xcode to run
the desktop version on macOS 14 or later. On GitHub, use **Code → Download ZIP**
to download the repository, then open the `.swiftpm` folder in Swift Playgrounds.

The package manifest is at the repository root, so the repository can also be
cloned and opened directly as a Swift package.

## Controls

- **Mac:** WASD or arrow keys to move, press X to toggle sprint, hold Space to fire,
  press R to reload, and press E at a nearby relay or access panel. Drag across
  the map to aim and fire.
- **iPhone and iPad:** use the on-screen joystick, Fire, Sprint, and Access
  controls; tap Reload when needed. The interface switches to a compact layout
  on narrow screens.
- **All devices:** approach an uncontested relay and press E or Access to secure
  it. AI squads capture relays over time when no rival team is contesting them.

## Game

Pick one of six jobs from the in-game job selector: Security Officer, Researcher,
Detainee, Response Operative, Raider, or Containment Subject. Each team has 10
AI. Teams patrol, contest three control points, and fight nearby hostiles. Jobs
have different movement speeds, spawn areas, and access clearances. Use access
panels to open restricted facility doors; an active breach triggers lockdowns
and seals high-security gates. Closed doors block movement until an authorized
job unlocks them. Firearms have limited magazines and can be reloaded.

This is an original single-player prototype, not an exact recreation of any
Roblox game. It uses simple AI, original facility layouts and characters, and
has no networked or persistent game services.
