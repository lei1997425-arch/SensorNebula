import SwiftUI
import SceneKit
import ScreenCaptureKit
import CoreImage
import CoreMedia
import CoreVideo
import OSLog

struct MacBookPoseCard: View {
    let roll: Double
    let pitch: Double
    let yaw: Double
    let lidAngle: Double

    @State private var zeroRoll = 0.0
    @State private var zeroPitch = 0.0
    @State private var zeroYaw = 0.0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MacBookSceneView(
                roll: roll - zeroRoll,
                pitch: pitch - zeroPitch,
                yaw: yaw - zeroYaw,
                lidAngle: lidAngle
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Button {
                zeroRoll = roll
                zeroPitch = pitch
                zeroYaw = yaw
            } label: {
                Label("姿态归零", systemImage: "scope")
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan.opacity(0.75))
            .controlSize(.small)
            .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            Text("前后 \(roll - zeroRoll, specifier: "%+.1f")°   左右 \(pitch - zeroPitch, specifier: "%+.1f")°   转向 \(yaw - zeroYaw, specifier: "%+.1f")°")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}

struct MacBookSceneView: NSViewRepresentable {
    let roll: Double
    let pitch: Double
    let yaw: Double
    let lidAngle: Double

    final class Coordinator: NSObject, SCStreamOutput, @unchecked Sendable {
        let root = SCNNode()
        let hinge = SCNNode()
        var importedScreen: SCNNode?
        var displayMaterial: SCNMaterial?
        var captureStream: SCStream?
        private let imageContext = CIContext(options: [.cacheIntermediates: false])
        private let captureQueue = DispatchQueue(label: "local.codex.sensor-nebula.screen-capture", qos: .userInteractive)
        private let logger = Logger(subsystem: "local.codex.sensor-nebula", category: "ScreenCapture")
        private var frameCount = 0
        private var didRequestPermission = false

        func startScreenCapture() {
            guard captureStream == nil else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    if !CGPreflightScreenCaptureAccess() {
                        guard !didRequestPermission else { return }
                        didRequestPermission = true
                        guard CGRequestScreenCaptureAccess() else {
                            logger.error("Screen capture permission is not available")
                            return
                        }
                    }
                    logger.info("Screen capture permission confirmed")
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else { return }
                    let ownBundleID = Bundle.main.bundleIdentifier
                    let excludedApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
                    let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
                    let configuration = SCStreamConfiguration()
                    configuration.width = min(display.width, 2560)
                    configuration.height = min(display.height, 1600)
                    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                    configuration.queueDepth = 3
                    configuration.pixelFormat = kCVPixelFormatType_32BGRA
                    configuration.showsCursor = true
                    configuration.capturesAudio = false

                    let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
                    captureStream = stream
                    try await stream.startCapture()
                    logger.info("Screen capture stream started")
                } catch {
                    // The original USDZ wallpaper remains visible when screen
                    // recording permission is unavailable or capture fails.
                    captureStream = nil
                    logger.error("Screen capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        func stopScreenCapture() {
            guard let stream = captureStream else { return }
            captureStream = nil
            Task { try? await stream.stopCapture() }
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen,
                  sampleBuffer.isValid,
                  let pixelBuffer = sampleBuffer.imageBuffer else { return }
            frameCount += 1
            if frameCount == 1 { logger.info("First screen frame received") }
            let image = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = imageContext.createCGImage(image, from: image.extent) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let material = self?.displayMaterial else { return }
                if self?.frameCount == 1 { self?.logger.info("First frame applied to display material") }
                material.diffuse.contents = cgImage
                material.diffuse.intensity = 0.92
                material.diffuse.minificationFilter = .linear
                material.diffuse.magnificationFilter = .linear
                // Constant lighting already makes the display self-lit. Using
                // the same frame in emission as well would add it twice and
                // overexpose the image, especially when the model is small.
                material.emission.contents = NSColor.black
                material.emission.intensity = 0
                material.lightingModel = .constant
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = buildScene(context.coordinator)
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        context.coordinator.startScreenCapture()
        return view
    }

    static func dismantleNSView(_ nsView: SCNView, coordinator: Coordinator) {
        coordinator.stopScreenCapture()
    }

    func updateNSView(_ view: SCNView, context: Context) {
        let radians = Float.pi / 180
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.10
        context.coordinator.root.eulerAngles = SCNVector3(
            Float(roll) * radians,
            Float(yaw) * radians,
            -Float(pitch) * radians
        )
        let safeLid = min(145, max(15, lidAngle))
        if let importedScreen = context.coordinator.importedScreen {
            // The downloaded M5 model is authored at approximately 112°.
            // Its screen coordinates use a hinge at y=-11, z=0.
            importedScreen.eulerAngles.x = -CGFloat(safeLid - 112) * CGFloat(radians)
        } else {
            context.coordinator.hinge.eulerAngles.x = -CGFloat(safeLid - 90) * CGFloat(radians)
        }
        SCNTransaction.commit()
    }

    private func buildScene(_ coordinator: Coordinator) -> SCNScene {
        let scene = SCNScene()
        scene.rootNode.addChildNode(coordinator.root)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 25
        camera.camera?.wantsHDR = true
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.bloomIntensity = 0.05
        camera.camera?.exposureOffset = -1.0
        camera.position = SCNVector3(5.3, 3.9, 7.1)
        camera.look(at: SCNVector3(0, 0.65, 0))
        scene.rootNode.addChildNode(camera)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 320
        key.light?.color = NSColor(calibratedWhite: 0.96, alpha: 1)
        key.position = SCNVector3(-3, 5, 4)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.intensity = 230
        rim.light?.color = NSColor(calibratedRed: 0.50, green: 0.72, blue: 0.82, alpha: 1)
        rim.position = SCNVector3(3, 2.5, -3)
        scene.rootNode.addChildNode(rim)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 125
        ambient.light?.color = NSColor(white: 0.5, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        if !buildImportedM5Laptop(in: coordinator) {
            buildLaptop(in: coordinator)
        }
        coordinator.root.eulerAngles = SCNVector3(-0.10, -0.35, 0.04)
        return scene
    }

    @discardableResult
    private func buildImportedM5Laptop(in coordinator: Coordinator) -> Bool {
        let packagedURL = Bundle.main.url(forResource: "MacBook_Pro_14-inch_M5", withExtension: "usdz")
        guard let url = packagedURL ?? Bundle.module.url(forResource: "MacBook_Pro_14-inch_M5", withExtension: "usdz"),
              let imported = try? SCNScene(url: url, options: nil) else { return false }

        let asset = SCNNode()
        for child in imported.rootNode.childNodes {
            asset.addChildNode(child.clone())
        }
        asset.scale = SCNVector3(0.10, 0.10, 0.10)
        asset.position = SCNVector3(0, -0.02, 0.35)
        asset.eulerAngles.y = .pi
        coordinator.root.addChildNode(asset)

        asset.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            if let display = geometry.materials.first(where: { $0.name == "HlQwFCAPWzetDQy" }) {
                coordinator.displayMaterial = display
            }
        }

        guard let screen = asset.childNode(withName: "RcexTyyhpuJYATQ_61", recursively: true) else {
            return true
        }
        // Rebase rotations at the physical hinge while preserving the mesh's
        // authored position and detailed PBR materials.
        screen.pivot = SCNMatrix4MakeTranslation(0, -11.0, 0)
        screen.position = SCNVector3(0, -11.0, 0)
        coordinator.importedScreen = screen
        return true
    }

    private func material(_ color: NSColor, metalness: CGFloat = 0, roughness: CGFloat = 0.45, emission: NSColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.metalness.contents = metalness
        material.roughness.contents = roughness
        if let emission { material.emission.contents = emission }
        return material
    }

    private func roundedBox(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, color: NSColor, metalness: CGFloat = 0.65) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.firstMaterial = material(color, metalness: metalness, roughness: 0.28)
        return SCNNode(geometry: box)
    }

    private func buildLaptop(in coordinator: Coordinator) {
        let black = NSColor(calibratedWhite: 0.105, alpha: 1)
        let edge = NSColor(calibratedWhite: 0.18, alpha: 1)
        let base = roundedBox(width: 3.12, height: 0.12, length: 2.15, radius: 0.09, color: black)
        base.position.y = 0
        coordinator.root.addChildNode(base)

        let deck = roundedBox(width: 3.02, height: 0.018, length: 2.04, radius: 0.06, color: edge, metalness: 0.8)
        deck.position = SCNVector3(0, 0.069, 0)
        coordinator.root.addChildNode(deck)

        let trackpad = SCNBox(width: 1.42, height: 0.012, length: 0.73, chamferRadius: 0.045)
        trackpad.firstMaterial = material(NSColor(calibratedWhite: 0.145, alpha: 1), metalness: 0.8, roughness: 0.22)
        let trackpadNode = SCNNode(geometry: trackpad)
        trackpadNode.position = SCNVector3(0, 0.087, 0.56)
        coordinator.root.addChildNode(trackpadNode)

        // Side details follow the supplied 14-inch reference: MagSafe,
        // two Thunderbolt ports and the 3.5 mm headphone jack on the left.
        let portMaterial = material(NSColor(calibratedWhite: 0.012, alpha: 1), metalness: 0.05, roughness: 0.72)
        let portSpecs: [(CGFloat, CGFloat, Float)] = [
            (0.30, 0.032, -0.70),
            (0.27, 0.040, -0.23),
            (0.27, 0.040, 0.15)
        ]
        for (length, height, z) in portSpecs {
            let port = SCNBox(width: 0.014, height: height, length: length, chamferRadius: height * 0.42)
            port.firstMaterial = portMaterial
            let node = SCNNode(geometry: port)
            node.position = SCNVector3(-1.565, 0.005, z)
            coordinator.root.addChildNode(node)
        }
        let headphone = SCNCylinder(radius: 0.045, height: 0.014)
        headphone.firstMaterial = portMaterial
        let headphoneNode = SCNNode(geometry: headphone)
        headphoneNode.eulerAngles.z = .pi / 2
        headphoneNode.position = SCNVector3(-1.566, 0.005, 0.63)
        coordinator.root.addChildNode(headphoneNode)

        // Right-side HDMI, Thunderbolt and SD-card openings.
        for z: Float in [-0.58, -0.10, 0.52] {
            let opening = SCNBox(width: 0.014, height: z == 0.52 ? 0.022 : 0.038, length: z == 0.52 ? 0.40 : 0.28, chamferRadius: 0.012)
            opening.firstMaterial = portMaterial
            let node = SCNNode(geometry: opening)
            node.position = SCNVector3(1.565, 0.005, z)
            coordinator.root.addChildNode(node)
        }

        let keyboard = SCNNode()
        keyboard.position = SCNVector3(0, 0.088, -0.35)
        coordinator.root.addChildNode(keyboard)
        let keyMaterial = material(NSColor(calibratedWhite: 0.025, alpha: 1), metalness: 0.1, roughness: 0.55)
        for row in 0..<6 {
            let count = row == 5 ? 8 : 14
            let keyWidth: CGFloat = row == 5 ? 0.29 : 0.17
            for column in 0..<count {
                let keyGeometry = SCNBox(width: keyWidth, height: 0.018, length: 0.16, chamferRadius: 0.018)
                keyGeometry.firstMaterial = keyMaterial
                let node = SCNNode(geometry: keyGeometry)
                node.position = SCNVector3(Float(CGFloat(column) - CGFloat(count - 1) / 2) * Float(keyWidth + 0.025), 0, Float(CGFloat(row) - 2.5) * 0.19)
                keyboard.addChildNode(node)
            }
        }

        let speakerMaterial = material(NSColor(calibratedWhite: 0.035, alpha: 1), roughness: 0.8)
        for side: Float in [-1, 1] {
            for row in 0..<9 {
                for column in 0..<3 {
                    let hole = SCNSphere(radius: 0.011)
                    hole.firstMaterial = speakerMaterial
                    let node = SCNNode(geometry: hole)
                    node.position = SCNVector3(side * (1.30 + Float(column) * 0.045), 0.091, -0.70 + Float(row) * 0.17)
                    coordinator.root.addChildNode(node)
                }
            }
        }

        coordinator.hinge.position = SCNVector3(0, 0.03, -1.03)
        coordinator.root.addChildNode(coordinator.hinge)
        let screenBack = roundedBox(width: 3.08, height: 1.92, length: 0.075, radius: 0.09, color: black)
        screenBack.position = SCNVector3(0, 0.96, 0)
        coordinator.hinge.addChildNode(screenBack)

        if let appleImage = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil)?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(paletteColors: [NSColor(calibratedWhite: 0.015, alpha: 1)])
        ) {
            let logo = SCNPlane(width: 0.43, height: 0.52)
            let logoMaterial = SCNMaterial()
            logoMaterial.diffuse.contents = appleImage
            logoMaterial.isDoubleSided = true
            logoMaterial.lightingModel = .constant
            logo.firstMaterial = logoMaterial
            let logoNode = SCNNode(geometry: logo)
            logoNode.position = SCNVector3(0, 0.96, -0.041)
            logoNode.eulerAngles.y = .pi
            coordinator.hinge.addChildNode(logoNode)
        }

        let display = SCNPlane(width: 2.91, height: 1.72)
        display.cornerRadius = 0.055
        display.firstMaterial = material(
            NSColor(calibratedRed: 0.025, green: 0.07, blue: 0.11, alpha: 1),
            roughness: 0.12,
            emission: NSColor(calibratedRed: 0.02, green: 0.16, blue: 0.23, alpha: 1)
        )
        let displayNode = SCNNode(geometry: display)
        displayNode.position = SCNVector3(0, 0.96, 0.039)
        coordinator.hinge.addChildNode(displayNode)

        let notch = SCNBox(width: 0.45, height: 0.075, length: 0.012, chamferRadius: 0.025)
        notch.firstMaterial = material(.black, roughness: 0.7)
        let notchNode = SCNNode(geometry: notch)
        notchNode.position = SCNVector3(0, 1.78, 0.048)
        coordinator.hinge.addChildNode(notchNode)

        let hingeBar = roundedBox(width: 2.55, height: 0.075, length: 0.095, radius: 0.035, color: NSColor(calibratedWhite: 0.06, alpha: 1))
        hingeBar.position = SCNVector3(0, 0.02, -1.01)
        coordinator.root.addChildNode(hingeBar)
    }
}
