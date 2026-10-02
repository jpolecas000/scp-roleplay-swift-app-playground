import Combine
import Foundation
import SwiftUI

enum Faction: String, CaseIterable, Identifiable {
    case security = "FACILITY SECURITY"
    case researchers = "RESEARCH STAFF"
    case detainees = "DETAINEES"
    case response = "RESPONSE UNIT"
    case raiders = "OUTSIDE RAIDERS"
    case anomalies = "CONTAINMENT SUBJECTS"

    var id: String { rawValue }

    var jobTitle: String {
        switch self {
        case .security: return "Security Officer"
        case .researchers: return "Researcher"
        case .detainees: return "Detainee"
        case .response: return "Response Operative"
        case .raiders: return "Raider"
        case .anomalies: return "Containment Subject"
        }
    }

    var clearance: String {
        switch self {
        case .security, .response: return "LEVEL 3"
        case .researchers: return "LEVEL 2"
        case .detainees, .raiders, .anomalies: return "UNAUTHORIZED"
        }
    }

    var spawnPoint: CGPoint {
        switch self {
        case .security: return CGPoint(x: 105, y: 350)
        case .researchers: return CGPoint(x: 500, y: 155)
        case .detainees: return CGPoint(x: 105, y: 555)
        case .response: return CGPoint(x: 500, y: 555)
        case .raiders: return CGPoint(x: 895, y: 555)
        case .anomalies: return CGPoint(x: 895, y: 155)
        }
    }

    var movementSpeed: CGFloat {
        switch self {
        case .security, .response: return 138
        case .researchers: return 122
        case .detainees: return 132
        case .raiders: return 148
        case .anomalies: return 158
        }
    }

    var accessLevel: Int {
        switch self {
        case .security, .response: return 3
        case .researchers: return 2
        case .detainees, .raiders, .anomalies: return 0
        }
    }

    var color: Color {
        switch self {
        case .security: return Color(red: 0.27, green: 0.76, blue: 0.98)
        case .researchers: return Color(red: 0.44, green: 0.91, blue: 0.65)
        case .detainees: return Color(red: 1.0, green: 0.68, blue: 0.3)
        case .response: return Color(red: 0.43, green: 0.57, blue: 1.0)
        case .raiders: return Color(red: 0.96, green: 0.48, blue: 0.27)
        case .anomalies: return Color(red: 0.84, green: 0.43, blue: 0.96)
        }
    }
}

struct Agent: Identifiable {
    let id: Int
    var faction: Faction
    var position: CGPoint
    var health: CGFloat = 100
    var cooldown: CGFloat = 0
    var respawnTimer: CGFloat = 0
    var isPlayer = false
}

struct ControlPoint: Identifiable {
    let id: Int
    let name: String
    let position: CGPoint
    var owner: Faction?
    var capturingFaction: Faction? = nil
    var progress: CGFloat = 0
}

struct FacilityDoor: Identifiable {
    let id: Int
    let name: String
    let position: CGPoint
    let requiredLevel: Int
    var isOpen = false
}

enum MoveDirection: Hashable {
    case up, down, left, right
}

@MainActor
final class GameModel: ObservableObject {
    static let worldSize = CGSize(width: 1_000, height: 700)

    @Published private(set) var agents: [Agent]
    @Published private(set) var controlPoints = [
        ControlPoint(id: 0, name: "WEST RELAY", position: CGPoint(x: 250, y: 340)),
        ControlPoint(id: 1, name: "RESEARCH WING", position: CGPoint(x: 500, y: 340)),
        ControlPoint(id: 2, name: "EAST RELAY", position: CGPoint(x: 750, y: 340))
    ]
    @Published private(set) var doors = [
        FacilityDoor(id: 0, name: "LAB ACCESS", position: CGPoint(x: 500, y: 260), requiredLevel: 2),
        FacilityDoor(id: 1, name: "CONTAINMENT GATE", position: CGPoint(x: 750, y: 420), requiredLevel: 3),
        FacilityDoor(id: 2, name: "RESPONSE AIRLOCK", position: CGPoint(x: 500, y: 440), requiredLevel: 3)
    ]
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var eliminations = 0
    @Published private(set) var containmentAlert = false
    @Published private(set) var alertMessage = "ALL SECTORS NOMINAL"
    @Published private(set) var accessMessage: String?
    @Published private(set) var ammunition = 12
    @Published private(set) var isReloading = false
    @Published var aimPoint = CGPoint(x: 650, y: 350)
    @Published var isFiring = false
    @Published var isSprinting = false

    var playerHealth: CGFloat {
        agents.first(where: \.isPlayer)?.health ?? 100
    }

    private var joystick = CGVector.zero
    private var keys = Set<MoveDirection>()
    private var shotCooldown: CGFloat = 0
    private var incidentTimer: CGFloat = 25
    private var reloadTimer: CGFloat = 0
    private var accessMessageTimer: CGFloat = 0

    var playerFaction: Faction {
        agents.first(where: \.isPlayer)?.faction ?? .security
    }

    init() {
        var roster: [Agent] = []
        var id = 0
        for faction in Faction.allCases {
            let baseX = faction.spawnPoint.x
            let baseY = faction.spawnPoint.y
            for member in 0..<10 {
                let column = CGFloat(member % 5)
                let row = CGFloat(member / 5)
                roster.append(
                    Agent(
                        id: id,
                        faction: faction,
                        position: CGPoint(
                            x: baseX + (column - 2) * 25,
                            y: baseY + (row - 0.5) * 32
                        )
                    )
                )
                id += 1
            }
        }

        roster.append(
            Agent(
                id: id,
                faction: .security,
            position: Faction.security.spawnPoint,
                isPlayer: true
            )
        )
        agents = roster
    }

    func selectJob(_ faction: Faction) {
        guard let playerIndex = agents.firstIndex(where: \.isPlayer) else { return }
        agents[playerIndex].faction = faction
        agents[playerIndex].position = faction.spawnPoint
        agents[playerIndex].health = 100
        agents[playerIndex].cooldown = 0
        ammunition = 12
        isReloading = false
        isFiring = false
    }

    func setJoystick(_ vector: CGVector) {
        let magnitude = hypot(vector.dx, vector.dy)
        let scale = magnitude > 1 ? 1 / magnitude : 1
        joystick = CGVector(dx: vector.dx * scale, dy: vector.dy * scale)
    }

    func setKey(_ direction: MoveDirection, isPressed: Bool) {
        if isPressed {
            keys.insert(direction)
        } else {
            keys.remove(direction)
        }
    }

    func aim(at point: CGPoint) {
        aimPoint = CGPoint(
            x: min(max(point.x, 0), Self.worldSize.width),
            y: min(max(point.y, 0), Self.worldSize.height)
        )
    }

    func interact() {
        guard let playerIndex = agents.firstIndex(where: \.isPlayer) else { return }
        let playerPosition = agents[playerIndex].position
        if let doorIndex = doors.indices.min(by: {
            distance(playerPosition, doors[$0].position)
                < distance(playerPosition, doors[$1].position)
        }), distance(playerPosition, doors[doorIndex].position) < 62 {
            guard playerFaction.accessLevel >= doors[doorIndex].requiredLevel else {
                showAccessMessage("ACCESS DENIED — LEVEL \(doors[doorIndex].requiredLevel) CLEARANCE REQUIRED")
                return
            }
            doors[doorIndex].isOpen.toggle()
            showAccessMessage(doors[doorIndex].isOpen
                ? "\(doors[doorIndex].name) UNLOCKED"
                : "\(doors[doorIndex].name) SEALED")
            return
        }
        guard let point = controlPoints.indices.min(by: {
            distance(playerPosition, controlPoints[$0].position)
                < distance(playerPosition, controlPoints[$1].position)
        }), distance(playerPosition, controlPoints[point].position) < 95 else { return }
        let isContested = agents.contains {
            $0.health > 0
                && $0.faction != playerFaction
                && distance($0.position, controlPoints[point].position) < 76
        }
        guard !isContested else {
            showAccessMessage("RELAY CONTESTED — CLEAR THE AREA")
            return
        }
        controlPoints[point].owner = playerFaction
        controlPoints[point].capturingFaction = nil
        controlPoints[point].progress = 0
        showAccessMessage("\(controlPoints[point].name) SECURED")
    }

    private func showAccessMessage(_ message: String) {
        accessMessage = message
        accessMessageTimer = 2.5
    }

    func reload() {
        guard !isReloading, ammunition < 12 else { return }
        isFiring = false
        isReloading = true
        reloadTimer = 1.5
    }

    func update(deltaTime: TimeInterval) {
        let dt = CGFloat(min(max(deltaTime, 0), 0.1))
        elapsedTime += TimeInterval(dt)
        shotCooldown = max(0, shotCooldown - dt)
        updateIncident(deltaTime: dt)
        if accessMessage != nil {
            accessMessageTimer -= dt
        }
        if accessMessageTimer <= 0 {
            self.accessMessage = nil
        }

        if isReloading {
            reloadTimer -= dt
            if reloadTimer <= 0 {
                ammunition = 12
                isReloading = false
            }
        }

        guard let playerIndex = agents.firstIndex(where: \.isPlayer) else { return }
        var playerDirection = joystick
        if keys.contains(.left) { playerDirection.dx -= 1 }
        if keys.contains(.right) { playerDirection.dx += 1 }
        if keys.contains(.up) { playerDirection.dy -= 1 }
        if keys.contains(.down) { playerDirection.dy += 1 }
        let directionLength = hypot(playerDirection.dx, playerDirection.dy)
        if directionLength > 1 {
            playerDirection.dx /= directionLength
            playerDirection.dy /= directionLength
        }

        if agents[playerIndex].health > 0 {
            let speed = playerFaction.movementSpeed * (isSprinting ? 1.45 : 1)
            let position = agents[playerIndex].position
            agents[playerIndex].position = playerMovement(
                from: position,
                toward: CGPoint(
                    x: position.x + playerDirection.dx * speed * dt,
                    y: position.y + playerDirection.dy * speed * dt
                )
            )
        }

        for index in agents.indices {
            if agents[index].health <= 0 {
                agents[index].respawnTimer -= dt
                if agents[index].respawnTimer <= 0 {
                    agents[index].health = 100
                    agents[index].position = agents[index].faction.spawnPoint
                }
                continue
            }
            guard !agents[index].isPlayer else { continue }
            agents[index].cooldown = max(0, agents[index].cooldown - dt)

            let enemyIndices = agents.indices.filter {
                agents[$0].health > 0 && agents[$0].faction != agents[index].faction
            }
            if let enemyIndex = enemyIndices.min(by: {
                distance(agents[index].position, agents[$0].position)
                    < distance(agents[index].position, agents[$1].position)
            }), distance(agents[index].position, agents[enemyIndex].position) < 185 {
                let target = agents[enemyIndex].position
                agents[index].position = moved(
                    agents[index].position,
                    toward: target,
                    speed: 31,
                    deltaTime: dt
                )
                if agents[index].cooldown == 0 {
                    agents[enemyIndex].health = max(0, agents[enemyIndex].health - (containmentAlert ? 12 : 9))
                    agents[index].cooldown = 0.75
                    if agents[enemyIndex].health == 0 {
                        agents[enemyIndex].respawnTimer = 4
                    }
                }
            } else if let objective = controlPoints.min(by: {
                distance(agents[index].position, $0.position)
                    < distance(agents[index].position, $1.position)
            }) {
                agents[index].position = moved(
                    agents[index].position,
                    toward: objective.position,
                    speed: 39,
                    deltaTime: dt
                )
            }
        }

        updateControlPoints(deltaTime: dt)
        if isFiring && shotCooldown == 0 && !isReloading {
            firePlayerWeapon()
        }
    }

    private func updateIncident(deltaTime: CGFloat) {
        incidentTimer -= deltaTime
        guard incidentTimer <= 0 else { return }
        containmentAlert.toggle()
        incidentTimer = containmentAlert ? 30 : 65
        alertMessage = containmentAlert
            ? "CONTAINMENT BREACH — LOCKDOWN IN EFFECT"
            : "BREACH CONTAINED — RESUME NORMAL OPERATIONS"
        if containmentAlert {
            for index in doors.indices where doors[index].requiredLevel == 3 {
                doors[index].isOpen = false
            }
        }
    }

    private func updateControlPoints(deltaTime: CGFloat) {
        for pointIndex in controlPoints.indices {
            let pointPosition = controlPoints[pointIndex].position
            let presentFactions = Faction.allCases.filter { faction in
                agents.contains {
                    $0.health > 0
                        && $0.faction == faction
                        && distance($0.position, pointPosition) < 76
                }
            }
            guard presentFactions.count == 1,
                  let capturingFaction = presentFactions.first
            else { continue }

            if controlPoints[pointIndex].owner == capturingFaction {
                continue
            }
            if controlPoints[pointIndex].capturingFaction != capturingFaction {
                controlPoints[pointIndex].capturingFaction = capturingFaction
                controlPoints[pointIndex].progress = 0
            }
            controlPoints[pointIndex].progress += deltaTime * 0.14
            if controlPoints[pointIndex].progress >= 1 {
                controlPoints[pointIndex].owner = capturingFaction
                controlPoints[pointIndex].capturingFaction = nil
                controlPoints[pointIndex].progress = 0
            }
        }
    }

    private func firePlayerWeapon() {
        guard ammunition > 0 else {
            reload()
            return
        }
        guard let playerIndex = agents.firstIndex(where: \.isPlayer) else { return }
        let origin = agents[playerIndex].position
        guard let targetIndex = agents.indices
            .filter({
                agents[$0].health > 0
                    && agents[$0].faction != playerFaction
                    && distance(agents[$0].position, origin) < 260
                    && distance(agents[$0].position, aimPoint) < 70
            })
            .min(by: {
                distance(agents[$0].position, aimPoint)
                    < distance(agents[$1].position, aimPoint)
            })
        else {
            ammunition -= 1
            shotCooldown = 0.22
            return
        }

        agents[targetIndex].health = max(0, agents[targetIndex].health - 24)
        ammunition -= 1
        if agents[targetIndex].health == 0 {
            agents[targetIndex].respawnTimer = 4
        }
        shotCooldown = 0.22
        if agents[targetIndex].health == 0 {
        eliminations += 1
        }
    }

    private func moved(
        _ origin: CGPoint,
        toward target: CGPoint,
        speed: CGFloat,
        deltaTime: CGFloat
    ) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(1, hypot(dx, dy))
        return clamped(CGPoint(
            x: origin.x + dx / length * speed * deltaTime,
            y: origin.y + dy / length * speed * deltaTime
        ))
    }

    private func playerMovement(from origin: CGPoint, toward target: CGPoint) -> CGPoint {
        let destination = clamped(target)
        guard doors.contains(where: { !$0.isOpen && distance(destination, $0.position) < 14 }) else {
            return destination
        }

        let horizontal = clamped(CGPoint(x: destination.x, y: origin.y))
        if !doors.contains(where: { !$0.isOpen && distance(horizontal, $0.position) < 14 }) {
            return horizontal
        }

        let vertical = clamped(CGPoint(x: origin.x, y: destination.y))
        if !doors.contains(where: { !$0.isOpen && distance(vertical, $0.position) < 14 }) {
            return vertical
        }
        return origin
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 25), Self.worldSize.width - 25),
            y: min(max(point.y, 25), Self.worldSize.height - 25)
        )
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
