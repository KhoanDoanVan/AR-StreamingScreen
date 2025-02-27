//
//  ContentView.swift
//  AR-StreamingScreen
//
//  Created by Đoàn Văn Khoan on 27/2/25.
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    
    let imageName: String

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        print("[ARView] 🚀 Khởi tạo ARView...")

        // Kiểm tra thiết bị có hỗ trợ AR không
        guard ARWorldTrackingConfiguration.isSupported else {
            print("[ARView] ❌ Thiết bị không hỗ trợ AR.")
            return arView
        }

        // Cấu hình AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal] // Phát hiện mặt phẳng ngang
        arView.session.run(config)

        // Đợi ARView sẵn sàng rồi thêm ảnh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                let success = await self.addImageToScene(arView: arView, imageName: imageName)
                print(success ? "[ARView] ✅ Ảnh đã được thêm thành công vào AR." : "[ARView] ❌ Lỗi khi thêm ảnh vào AR.")
            }
        }

        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}

    /// 📌 Load texture từ UIImage thay vì dùng TextureResource(named:) trực tiếp
    private func loadTexture(imageName: String) async throws -> TextureResource {
        guard let uiImage = UIImage(named: imageName) else {
            throw NSError(domain: "ARView", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ảnh \(imageName)"])
        }
        
        // ✅ Chuyển đổi UIImage thành CGImage an toàn
        guard let cgImage = uiImage.cgImage else {
            throw NSError(domain: "ARView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể chuyển đổi ảnh \(imageName) sang CGImage"])
        }

        // ✅ Tạo TextureResource từ CGImage
        let textureResource = try await TextureResource(image: cgImage, options: .init(semantic: .hdrColor))
        
        return textureResource
    }

    /// 🖼 Thêm ảnh vào AR Scene
    private func addImageToScene(arView: ARView, imageName: String) async -> Bool {
        print("[ARView] 🖼 Bắt đầu load ảnh: \(imageName)")
        
        do {
            let textureResource = try await loadTexture(imageName: imageName)
            print("[ARView] ✅ Load texture thành công.")

            var material = SimpleMaterial()
            material.color = .init(texture: MaterialParameters.Texture(textureResource))
            
            let plane = ModelEntity(mesh: .generatePlane(width: 0.7, height: 0.5), materials: [material])
            plane.position = [0, -0.5, -0.5] // Hiển thị ảnh trước mặt người dùng
            
            // ✅ Rotate the plane to face the user
//            plane.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            
            let anchor = AnchorEntity(plane: .horizontal)
            anchor.addChild(plane)
            
            arView.scene.anchors.append(anchor)
            return true
        } catch {
            print("[ARView] ❌ Lỗi khi tải ảnh: \(error.localizedDescription)")
            return false
        }
    }
}

struct ContentView: View {

    var body: some View {
        ZStack {
            ARViewContainer(imageName: "screenshot")
        }
    }
}

//import SwiftUI
//import ARKit
//import RealityKit
//
//struct ARViewContainer: UIViewRepresentable {
//    
//    @ObservedObject var udpReceiver: UDPReceiver
//    
//    func makeUIView(context: Context) -> ARView {
//        let arView = ARView(frame: .zero)
//        
//        print("[DEBUG] 🚀 Initializing ARView...")
//
//        guard ARWorldTrackingConfiguration.isSupported else {
//            print("[ERROR] ❌ Device does not support AR.")
//            return arView
//        }
//
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal]
//        arView.session.run(config)
//
//        context.coordinator.arView = arView
//        return arView
//    }
//    
//    func updateUIView(_ uiView: ARView, context: Context) {
//        guard let image = udpReceiver.receivedImage else { return }
//        
//        Task {
//            let success = await context.coordinator.updateImage(image: image)
//            print(success ? "[DEBUG] ✅ Image updated successfully." : "[ERROR] ❌ Failed to update image.")
//        }
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        return Coordinator()
//    }
//
//    class Coordinator {
//        weak var arView: ARView?
//        private var lastImageHash: Int? // Prevents redundant updates
//
//        func updateImage(image: UIImage) async -> Bool {
//            guard let arView = arView else { return false }
//
//            let imageHash = image.pngData()?.hashValue
//            if lastImageHash == imageHash {
//                print("[DEBUG] ⏩ Image unchanged, skipping update.")
//                return true
//            }
//            lastImageHash = imageHash
//            
//            do {
//                guard let texture = try? await loadTexture(image: image) else {
//                    print("[ERROR] ❌ Could not load texture, using fallback material.")
//                    let fallbackMaterial = SimpleMaterial(color: .white, isMetallic: false)
//                    let fallbackPlane = await ModelEntity(mesh: .generatePlane(width: 0.7, height: 0.5), materials: [fallbackMaterial])
//                    
//                    await MainActor.run {
//                        fallbackPlane.position = [0, -0.5, -0.5]
//                        let anchor = AnchorEntity(plane: .horizontal)
//                        anchor.addChild(fallbackPlane)
//                        
//                        arView.scene.anchors.removeAll()
//                        arView.scene.anchors.append(anchor)
//                    }
//                    return false
//                }
//
//                var material = SimpleMaterial()
//                material.color = .init(texture: MaterialParameters.Texture(texture))
//
//                let plane = await ModelEntity(mesh: .generatePlane(width: 0.7, height: 0.5), materials: [material])
//
//                await MainActor.run {
//                    plane.position = [0, -0.5, -0.5]
//
//                    let anchor = AnchorEntity(plane: .horizontal)
//                    anchor.addChild(plane)
//
//                    arView.scene.anchors.removeAll()
//                    arView.scene.anchors.append(anchor)
//                }
//
//                return true
//            } catch {
//                print("[ERROR] ❌ Failed to load image: \(error.localizedDescription)")
//                return false
//            }
//
////            do {
////                let texture = try await loadTexture(image: image)
////                
////                
////                var material = SimpleMaterial()
////                material.color = .init(texture: MaterialParameters.Texture(texture))
////
////                let plane = await ModelEntity(mesh: .generatePlane(width: 0.7, height: 0.5), materials: [material])
////
////                await MainActor.run {
////                    plane.position = [0, -0.5, -0.5]
////                    
////                    let anchor = AnchorEntity(plane: .horizontal)
////                    anchor.addChild(plane)
////                    
////                    arView.scene.anchors.removeAll()
////                    arView.scene.anchors.append(anchor)
////                }
////
////                return true
////            } catch {
////                print("[ERROR] ❌ Failed to load image: \(error.localizedDescription)")
////                return false
////            }
//        }
//
//        private func loadTexture(image: UIImage) async throws -> TextureResource {
//            guard let cgImage = image.cgImage else {
//                throw NSError(domain: "ARView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to CGImage"])
//            }
//            return try await TextureResource(image: cgImage, options: .init(semantic: .hdrColor))
//        }
//    }
//}
//
//struct ContentView: View {
//    @StateObject private var udpReceiver = UDPReceiver()
//
//    var body: some View {
//        ZStack {
//            ARViewContainer(udpReceiver: udpReceiver)
//                .edgesIgnoringSafeArea(.all)
//            
//            VStack {
//                Spacer()
//                Text("🖥 Receiving image from macOS...")
//                    .padding()
//                    .background(Color.black.opacity(0.6))
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .padding(.bottom, 20)
//            }
//        }
//        .onAppear {
//            udpReceiver.startListening()
//        }
//    }
//}
