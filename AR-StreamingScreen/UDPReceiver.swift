//
//  UDPReceiver.swift
//  AR-StreamingScreen
//
//  Created by Đoàn Văn Khoan on 27/2/25.
//

import Foundation
import Network
import UIKit

class UDPReceiver: ObservableObject {
    
    @Published var receivedImage: UIImage? = nil
    private var listener: NWListener?

    func startListening() {
        let params = NWParameters.udp
        do {
            listener = try NWListener(using: params, on: 5120) /// Same port as macOS app
            listener?.newConnectionHandler = { [weak self] connection in
                self?.receiveData(from: connection)
                connection.start(queue: .global(qos: .background))
            }
            listener?.start(queue: .global(qos: .background))
            print("🟢 Listening for screen stream...")
        } catch {
            print("❌ Failed to start UDP listener: \(error)")
        }
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, _, error in
            if let data = data {
                print("🟡 Received \(data.count) bytes")
                
                if data.count > 4 {
                    let sizeData = data.prefix(4)
                    let expectedSize = Int(UInt32(bigEndian: sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }))
                    let imageData = data.dropFirst(4)
                    
                    print("📏 Expected Image Size: \(expectedSize) bytes")
                    print("📥 Received Image Size: \(imageData.count) bytes")

                    if imageData.count == expectedSize {
                        if let image = UIImage(data: imageData) {
                            DispatchQueue.main.async {
                                self?.receivedImage = image
                            }
                        } else {
                            print("🔴 Failed to convert data to UIImage")
                        }
                    } else {
                        print("⚠️ Incomplete image data")
                    }
                } else {
                    print("🔴 Not enough data to determine image size")
                }
            } else {
                print("🔴 No data received")
            }
            
            if error == nil {
                self?.receiveData(from: connection) // Continue receiving
            } else {
                print("❌ Receive error: \(String(describing: error))")
            }
        }
    }
}
