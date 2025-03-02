//
//  UDPReceiver.swift
//  AR-StreamingScreen
//
//  Created by Đoàn Văn Khoan on 27/2/25.
//

import Foundation
import SwiftUI
import Network
import CoreVideo

class UDPReceiver: ObservableObject {
    
    private var listener: NWListener?
    private let port: NWEndpoint.Port = 5120
    
    /// Image data JPEG
    @Published var receivedImage: UIImage? = nil
    private var imageDataBuffer = Data()
    
    /// CVPixelBuffer
    @Published var receivedPixelBuffer: CVPixelBuffer?
    private var pixelBufferDataBuffer = Data()
    
    func startListening() {
        let params = NWParameters.udp
        do {
            listener = try NWListener(using: params, on: port)
            listener?.newConnectionHandler = { [weak self] connection in
                
                self?.receiveDataJPEG(from: connection)
                
//                self?.receiveDataPixelBuffer(from: connection)
                
                connection.start(queue: .global(qos: .background))
            }
            listener?.start(queue: .global(qos: .background))
            print("🟢 Listening for screen stream on port \(port)")
        } catch {
            print("❌ Failed to start UDP listener: \(error)")
        }
    }
    
    /// CVPixelBuffer
    private func receiveDataPixelBuffer(from connection: NWConnection) {
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) {
            [weak self] data, _, _, error in
            
            guard let self = self,
                  let data = data else {
                print("🔴 No data received")
                return
            }
            
            pixelBufferDataBuffer.append(data)
            
            if pixelBufferDataBuffer.count < 4 {
                
                let sizeData = pixelBufferDataBuffer.prefix(4)
                let expectedSize = Int(
                    UInt32(
                        bigEndian: sizeData.withUnsafeBytes{
                            $0.load(
                                as: UInt32.self
                            )
                        })
                )
                
                if pixelBufferDataBuffer.count - 4 >= expectedSize {
                    
                    let pixelBufferRawData = pixelBufferDataBuffer.dropFirst(4).prefix(expectedSize)
                    
                    if let pixelBuffer = self.createPixelBuffer(from: pixelBufferRawData) {
                        
                        DispatchQueue.main.async { [weak self] in
                            self?.receivedPixelBuffer = pixelBuffer
                        }
                        
                    } else {
                        print("🔴 Failed to convert to CVPixelBuffer")
                    }
                    
                    pixelBufferDataBuffer.removeFirst(4 + expectedSize)
                }
                
            }
            
            if error == nil {
                self.receiveDataPixelBuffer(from: connection)
            } else {
                print("❌ Receive error: \(error!)")
            }
        }
        
    }
    
    /// Create Pixel Buffer
    private func createPixelBuffer(from data: Data) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        let width = 640
        let height = 360
        let pixelFormat = kCVPixelFormatType_32BGRA
        
        let attrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferBytesPerRowAlignmentKey: width * 4,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attrs as CFDictionary, &pixelBuffer)
        
        guard status == kCVReturnSuccess,
              let buffer = pixelBuffer
        else {
            print("🔴 Failed to create CVPixelBuffer")
            return nil
        }
        
        /// Lock
        CVPixelBufferLockBaseAddress(buffer, .init(rawValue: 0))
        
        if let pixelData = CVPixelBufferGetBaseAddress(buffer) {
            data.copyBytes(to: pixelData.assumingMemoryBound(to: UInt8.self), count: data.count)
        }
        
        /// Unlock
        CVPixelBufferUnlockBaseAddress(buffer, .init(rawValue: 0))
        
        return buffer
    }
    
    /// JPEG
    private func receiveDataJPEG(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data else {
                print("🔴 No data received")
                return
            }
            
            imageDataBuffer.append(data)
            
            if imageDataBuffer.count > 4 {
                let sizeData = imageDataBuffer.prefix(4)
                let expectedSize = Int(UInt32(bigEndian: sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }))
                
                if imageDataBuffer.count - 4 >= expectedSize {
                    let imageData = imageDataBuffer.dropFirst(4).prefix(expectedSize)
                    
                    if let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.receivedImage = image
                        }
                    } else {
                        print("🔴 Failed to convert to UIImage")
                    }
                    
                    imageDataBuffer.removeFirst(4 + expectedSize)
                }
            }
            
            if error == nil {
                self.receiveDataJPEG(from: connection)
            } else {
                print("❌ Receive error: \(error!)")
            }
        }
    }
}
