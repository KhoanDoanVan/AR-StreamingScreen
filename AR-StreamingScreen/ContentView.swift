//
//  ContentView.swift
//  AR-StreamingScreen
//
//  Created by Đoàn Văn Khoan on 27/2/25.
//

import SwiftUI
import ARKit
import RealityKit


class Coordinator: NSObject, ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[ARSession] ❌ Error: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("[ARSession] ⚠️ Session was interrupted.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("[ARSession] 🔄 Session resumed.")
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var udpReceiver: UDPReceiver

    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        
        print("[ARView] 🚀 Initialized ARView...")

        guard ARWorldTrackingConfiguration.isSupported else {
            print("[ARView] ❌ Device not supported AR.")
            return arView
        }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        arView.session.run(config)
        print("[ARView] ✅ AR session started successfully.")

        return arView
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
        if uiView.session.configuration == nil {
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            
            if uiView.session.configuration != nil {
                uiView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                print("[ARView] 🔄 Restarted AR session")
            }
        }
        
        if let receivedImage = udpReceiver.receivedImage {
            print("[ARView] 🔄 Updating ARView with new image")
            Task {
                await self.addUIImageToScene(arView: uiView, image: receivedImage)
            }
        }
        
//        if let receivedPixelBuffer = udpReceiver.receivedPixelBuffer {
//            print("[ARView] 🔄 Updating ARView with new pixel buffer")
//            Task {
//                await self.addPixelBufferToScene(arView: uiView, pixelBuffer: receivedPixelBuffer)
//            }
//        }
        
    }
    
    /// Pixel Buffer
    private func addPixelBufferToScene(arView: ARView, pixelBuffer: CVPixelBuffer) async {
        print("[ARView] 📹 Processing received CVPixelBuffer...")

        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("[ARView] ❌ Failed to create CGImage from pixel buffer.")
            return
        }

        do {
            let textureResource = try await TextureResource(image: cgImage, options: .init(semantic: .hdrColor))
            print("[ARView] ✅ Successfully created texture from pixel buffer.")

            var material = UnlitMaterial()
            material.color = .init(texture: MaterialParameters.Texture(textureResource))

            let aspectRatio: Float = 16.0 / 9.0
            let width: Float = 1.5
            let height: Float = width / aspectRatio  /// Ensures 16:9 ratio

            let plane = ModelEntity(mesh: .generatePlane(width: width, height: height), materials: [material])

            plane.position = [0, -0.7, -1.5]

            let anchor = AnchorEntity(plane: .horizontal)
            
            anchor.addChild(plane)

            arView.scene.anchors.removeAll()
            arView.scene.anchors.append(anchor)

        } catch {
            print("[ARView] ❌ Failed to create TextureResource: \(error.localizedDescription)")
        }
        
    }
    

    /// UIImage
    private func addUIImageToScene(arView: ARView, image: UIImage) async {
        print("[ARView] 🖼 Loading received image...")

        do {
            let textureResource = try await loadTexture(from: image)
            print("[ARView] ✅ Loaded texture successfully.")

            var material = SimpleMaterial()
            material.color = .init(texture: MaterialParameters.Texture(textureResource))
            
            let plane = ModelEntity(mesh: .generatePlane(width: 1.5, height: 1.05), materials: [material])
//            plane.position = [0, -0.7, -1.5]
//            let anchor = AnchorEntity(plane: .horizontal)
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1.5))
            anchor.addChild(plane)
            
            arView.scene.anchors.removeAll()
            arView.scene.anchors.append(anchor)
            
        } catch {
            print("[ARView] ❌ Failed to load image: \(error.localizedDescription)")
        }
    }
    
    private func loadTexture(from image: UIImage) async throws -> TextureResource {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ARView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Cannot convert UIImage to CGImage"])
        }

        let textureResource = try await TextureResource(image: cgImage, options: .init(semantic: .hdrColor))
        return textureResource
    }
}

struct ContentView: View {
    @StateObject private var udpReceiver = UDPReceiver()

    var body: some View {
        ZStack {
            ARViewContainer(udpReceiver: udpReceiver)
        }
        .onAppear {
            udpReceiver.startListening()
        }
//        .onChange(of: udpReceiver.receivedPixelBuffer) { oldValue, newValue in
//            print("[ContentView] 🎭 Detected new pixel buffer update")
//        }
        .onChange(of: udpReceiver.receivedImage) { oldValue, newValue in
            print("[ContentView] 🎭 Detected new image update")
        }
    }
}
