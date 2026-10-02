import Combine
import SwiftUI

private enum GameStyle {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let panel = Color(red: 0.055, green: 0.085, blue: 0.11)
    static let border = Color.white.opacity(0.1)
    static let muted = Color(red: 0.52, green: 0.62, blue: 0.68)
    static let accent = Color(red: 0.33, green: 0.85, blue: 0.8)
}

struct GameView: View {
    @StateObject private var game = GameModel()
    @State private var previousUpdate = Date()
    @FocusState private var isGameplayFocused: Bool
    private let gameTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 760

            ZStack {
                GameStyle.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(compact: compact)
                    if compact {
                        compactStatus
                    }
                    incidentBanner
                    battlefield
                        .padding(compact ? 8 : 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !isTouchPlatform && !compact {
                        desktopFooter
                    }
                }
                .overlay(alignment: .bottom) {
                    if compact || isTouchPlatform {
                        touchControls
                            .padding(.horizontal, 18)
                            .padding(.bottom, 20)
                    }
                }
            }
            .onReceive(gameTimer) { now in
                game.update(deltaTime: now.timeIntervalSince(previousUpdate))
                previousUpdate = now
            }
            .onKeyPress(phases: [.down, .up]) { press in
                handleKey(press)
            }
            .focusable()
            .focused($isGameplayFocused)
            .onAppear { isGameplayFocused = true }
        }
        .ignoresSafeArea(.keyboard)
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(GameStyle.accent)
                .frame(width: 38, height: 38)
                .background(GameStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text("CONTAINMENT SHIFT")
                    .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
                    .tracking(1.2)
                Text("SECTOR 04  /  NIGHT WATCH")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(GameStyle.muted)
            }

            Spacer(minLength: 4)

            jobPicker(compact: compact)

            HStack(spacing: 6) {
                Circle().fill(Color(red: 0.36, green: 0.9, blue: 0.62)).frame(width: 7, height: 7)
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.045), in: Capsule())
        }
        .padding(.horizontal, compact ? 14 : 24)
        .padding(.vertical, compact ? 11 : 15)
        .background(GameStyle.panel)
        .overlay(alignment: .bottom) { GameStyle.border.frame(height: 1) }
    }

    private func jobPicker(compact: Bool) -> some View {
        Menu {
            ForEach(Faction.allCases) { faction in
                Button {
                    game.selectJob(faction)
                } label: {
                    Label("\(faction.jobTitle) · \(faction.clearance)", systemImage: "person.crop.circle")
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                if !compact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.playerFaction.jobTitle.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Text(game.playerFaction.clearance)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(GameStyle.muted)
                    }
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(game.playerFaction.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(game.playerFaction.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
        }
        .accessibilityLabel("Select job. Current job: \(game.playerFaction.jobTitle)")
    }

    private var compactStatus: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Faction.allCases) { faction in
                    HStack(spacing: 5) {
                        Circle().fill(faction.color).frame(width: 6, height: 6)
                        Text(faction.rawValue.components(separatedBy: " ").first ?? "")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(faction.color)
                        Text("\(game.agents.filter { $0.faction == faction && $0.health > 0 }.count)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer(minLength: 0)
                Text(timeLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 9)
        .background(GameStyle.background)
    }

    private var incidentBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: game.accessMessage != nil
                ? "info.circle.fill"
                : (game.containmentAlert ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"))
            Text(game.accessMessage ?? game.alertMessage)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(game.isReloading ? "RELOADING" : "\(game.ammunition)/12")
                .lineLimit(1)
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(
            game.accessMessage?.hasPrefix("ACCESS DENIED") == true || game.containmentAlert
                ? Color.orange
                : Color(red: 0.44, green: 0.91, blue: 0.65)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((game.containmentAlert ? Color.orange : Color.green).opacity(0.09))
    }

    private var battlefield: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    drawMap(in: context, size: size)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            game.aim(at: worldPoint(value.location, in: geometry.size))
                            game.isFiring = true
                        }
                        .onEnded { value in
                            game.aim(at: worldPoint(value.location, in: geometry.size))
                            game.isFiring = false
                        }
                )
                .onTapGesture(count: 2) { location in
                    game.aim(at: worldPoint(location, in: geometry.size))
                    game.isFiring = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        game.isFiring = false
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("LIVE TACTICAL MAP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                    Text("SEC-04  •  \(game.agents.filter { $0.health > 0 }.count) ACTIVE")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(GameStyle.muted)
                }
                .padding(10)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .padding(12)
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("DRAG TO AIM + FIRE")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.38))
                            .padding(9)
                    }
                }
                .allowsHitTesting(false)
            }
            .background(Color(red: 0.055, green: 0.09, blue: 0.095))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(GameStyle.border, lineWidth: 1)
            }
        }
        .aspectRatio(1.43, contentMode: .fit)
        .frame(maxHeight: .infinity)
    }

    private var desktopFooter: some View {
        HStack(alignment: .center, spacing: 22) {
            HStack(spacing: 9) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.38))
                VStack(alignment: .leading, spacing: 3) {
                    Text("VITALS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(GameStyle.muted)
                    Text("\(Int(game.playerHealth))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
            .frame(width: 75, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: game.isReloading ? "arrow.triangle.2.circlepath" : "square.stack.3d.up")
                    .foregroundStyle(game.isReloading ? .orange : GameStyle.accent)
                Text(game.isReloading ? "RELOADING" : "AMMO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameStyle.muted)
                Text(game.isReloading ? "···" : "\(game.ammunition)/12")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundStyle(GameStyle.accent)
                Text("ELIMINATIONS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameStyle.muted)
                Text("\(game.eliminations)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }

            objectiveSummary

            Spacer(minLength: 8)

            Text("W A S D  MOVE    X  SPRINT    SPACE  FIRE    R  RELOAD    E  ACCESS")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                game.interact()
            } label: {
                Label("INTERACT  [E]", systemImage: "hand.tap")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(GameStyle.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                    .foregroundStyle(GameStyle.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(GameStyle.panel)
        .overlay(alignment: .top) { GameStyle.border.frame(height: 1) }
    }

    private var objectiveSummary: some View {
        HStack(spacing: 9) {
            ForEach(game.controlPoints) { point in
                HStack(spacing: 4) {
                    Circle()
                        .fill(point.owner?.color ?? GameStyle.muted.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(point.name.replacingOccurrences(of: " ", with: "\n"))
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(point.owner?.color ?? GameStyle.muted)
                        .lineLimit(2)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var touchControls: some View {
        HStack(alignment: .bottom) {
            Joystick { game.setJoystick($0) }
            Spacer()
            VStack(spacing: 9) {
                HStack(spacing: 9) {
                    Button {
                        game.interact()
                    } label: {
                        controlButton("ACCESS", symbol: "hand.tap", color: GameStyle.accent, size: 62)
                    }
                    .buttonStyle(.plain)

                    Button {
                        game.isSprinting.toggle()
                    } label: {
                        controlButton(
                            "SPRINT",
                            symbol: "figure.run",
                            color: game.isSprinting ? .yellow : .white,
                            size: 62
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 9) {
                    Button {
                        game.reload()
                    } label: {
                        controlButton(
                            "RELOAD",
                            symbol: "arrow.triangle.2.circlepath",
                            color: game.isReloading ? .orange : .white,
                            size: 62
                        )
                    }
                    .buttonStyle(.plain)

                    controlButton("FIRE", symbol: "scope", color: .red, size: 72)
                        .onLongPressGesture(minimumDuration: 0, pressing: { game.isFiring = $0 }, perform: {})
                }
            }
        }
        .padding(.bottom, 9)
    }

    private func controlButton(_ title: String, symbol: String, color: Color, size: CGFloat) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
            Text(title)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(0.7)
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .background(.black.opacity(0.72), in: Circle())
        .overlay { Circle().stroke(color.opacity(0.4), lineWidth: 1) }
    }

    private func worldPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x / max(size.width, 1) * GameModel.worldSize.width,
            y: point.y / max(size.height, 1) * GameModel.worldSize.height
        )
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let pressed = press.phase == .down
        switch press.key {
        case .upArrow: game.setKey(.up, isPressed: pressed)
        case .downArrow: game.setKey(.down, isPressed: pressed)
        case .leftArrow: game.setKey(.left, isPressed: pressed)
        case .rightArrow: game.setKey(.right, isPressed: pressed)
        default:
            switch press.characters.lowercased() {
            case "w": game.setKey(.up, isPressed: pressed)
            case "s": game.setKey(.down, isPressed: pressed)
            case "a": game.setKey(.left, isPressed: pressed)
            case "d": game.setKey(.right, isPressed: pressed)
            case "e" where pressed: game.interact()
            case "x" where pressed: game.isSprinting.toggle()
            case "r" where pressed: game.reload()
            case " ":
                game.isFiring = pressed
            default: return .ignored
            }
        }
        return .handled
    }

    private var timeLabel: String {
        let total = Int(game.elapsedTime)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var isTouchPlatform: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private func drawMap(in context: GraphicsContext, size: CGSize) {
        let sx = size.width / GameModel.worldSize.width
        let sy = size.height / GameModel.worldSize.height
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: x * sx, y: y * sy, width: width * sx, height: height * sy)
        }
        func point(_ position: CGPoint) -> CGPoint {
            CGPoint(x: position.x * sx, y: position.y * sy)
        }

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.055, green: 0.09, blue: 0.095)))
        var grid = Path()
        for x in stride(from: CGFloat(0), through: GameModel.worldSize.width, by: 50) {
            grid.move(to: point(CGPoint(x: x, y: 0)))
            grid.addLine(to: point(CGPoint(x: x, y: GameModel.worldSize.height)))
        }
        for y in stride(from: CGFloat(0), through: GameModel.worldSize.height, by: 50) {
            grid.move(to: point(CGPoint(x: 0, y: y)))
            grid.addLine(to: point(CGPoint(x: GameModel.worldSize.width, y: y)))
        }
        context.stroke(grid, with: .color(.white.opacity(0.035)), lineWidth: 1)

        let rooms: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (25, 50, 210, 210), (30, 445, 210, 205),
            (275, 45, 190, 210), (535, 45, 190, 210),
            (765, 50, 210, 210), (765, 445, 210, 205),
            (275, 445, 190, 205), (535, 445, 190, 205)
        ]
        for room in rooms {
            let roomRect = rect(room.0, room.1, room.2, room.3)
            context.fill(Path(roundedRect: roomRect, cornerRadius: 8), with: .color(Color(red: 0.075, green: 0.12, blue: 0.13)))
            context.stroke(
                Path(roundedRect: roomRect, cornerRadius: 8),
                with: .color(Color(red: 0.2, green: 0.33, blue: 0.33).opacity(0.55)),
                lineWidth: 1.3
            )
        }

        for (x, y, label) in [
            (60.0, 68.0, "SECURITY"), (298.0, 63.0, "LAB 01"),
            (558.0, 63.0, "LAB 02"), (788.0, 68.0, "CONTAINMENT"),
            (60.0, 465.0, "ARMORY"), (298.0, 465.0, "ARCHIVE"),
            (558.0, 465.0, "MEDICAL"), (788.0, 465.0, "ACCESS")
        ] {
            context.draw(
                Text(label).font(.system(size: max(6, 8 * sx), weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35)),
                at: point(CGPoint(x: x, y: y))
            )
        }

        for objective in game.controlPoints {
            let center = point(objective.position)
            let radius: CGFloat = max(14, 25 * sx)
            let halo = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: halo), with: .color((objective.owner?.color ?? GameStyle.accent).opacity(0.12)))
            context.stroke(Path(ellipseIn: halo), with: .color((objective.owner?.color ?? GameStyle.accent).opacity(0.7)), lineWidth: 1.5)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                with: .color(objective.owner?.color ?? .white.opacity(0.65))
            )
            context.draw(
                Text(objective.name).font(.system(size: max(6, 8 * sx), weight: .bold, design: .monospaced))
                    .foregroundColor(objective.owner?.color ?? GameStyle.accent),
                at: CGPoint(x: center.x, y: center.y + radius + 9)
            )
        }

        for door in game.doors {
            let center = point(door.position)
            let doorRect = CGRect(x: center.x - 9, y: center.y - 4, width: 18, height: 8)
            let color: Color = door.isOpen ? .green : .orange
            context.fill(Path(roundedRect: doorRect, cornerRadius: 2), with: .color(color.opacity(0.8)))
            context.stroke(Path(roundedRect: doorRect, cornerRadius: 2), with: .color(.white.opacity(0.5)), lineWidth: 1)
            context.draw(
                Text("L\(door.requiredLevel)").font(.system(size: max(6, 7 * sx), weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75)),
                at: CGPoint(x: center.x, y: center.y + 12)
            )
        }

        for agent in game.agents where agent.health > 0 {
            let center = point(agent.position)
            let radius: CGFloat = agent.isPlayer ? max(5, 8 * sx) : max(3.5, 5.5 * sx)
            let agentRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let factionColor = agent.faction.color
            context.fill(Path(ellipseIn: agentRect.insetBy(dx: -2, dy: -2)), with: .color(factionColor.opacity(0.2)))
            context.fill(Path(ellipseIn: agentRect), with: .color(factionColor))
            if agent.isPlayer {
                context.stroke(Path(ellipseIn: agentRect.insetBy(dx: -2, dy: -2)), with: .color(.white), lineWidth: 1.5)
            }
        }
    }
}

private struct Joystick: View {
    let onChange: (CGVector) -> Void
    @State private var knobOffset = CGSize.zero
    private let radius: CGFloat = 53

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.62))
                .frame(width: radius * 2, height: radius * 2)
                .overlay { Circle().stroke(.white.opacity(0.2), lineWidth: 1) }
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 45, height: 45)
                .overlay { Circle().stroke(.white.opacity(0.3), lineWidth: 1) }
                .offset(knobOffset)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = value.location.x - radius
                    let y = value.location.y - radius
                    let length = hypot(x, y)
                    let scale = length > radius ? radius / length : 1
                    knobOffset = CGSize(width: x * scale, height: y * scale)
                    onChange(CGVector(dx: knobOffset.width / radius, dy: knobOffset.height / radius))
                }
                .onEnded { _ in
                    knobOffset = .zero
                    onChange(.zero)
                }
        )
    }
}
