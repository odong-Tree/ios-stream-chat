//
//  ChatRoom.swift
//  StreamChat
//
//  Created by 김동빈 on 2021/04/27.
//

import UIKit

protocol ChatRoomDelegate: AnyObject {
    func receive(message: Message)
}

class ChatRoom: NSObject {
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var username = ""
    let maxReadLength = 300
    
    weak var delegate: ChatRoomDelegate?
    
    func setupNetworkCommunication() {
        createSocketToHost(url: ChatHost.url as CFString, port: ChatHost.port)
        
        guard let inputStream = self.inputStream, let outputStream = self.outputStream else {
            return
        }
        
        inputStream.delegate = self
        inputStream.schedule(in: .current, forMode: .common)
        outputStream.schedule(in: .current, forMode: .common)
        
        inputStream.open()
        outputStream.open()
    }
    
    private func createSocketToHost(url: CFString, port: UInt32) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, url, port, &readStream, &writeStream)
        
        inputStream = readStream?.takeRetainedValue()
        outputStream = writeStream?.takeRetainedValue()
    }
    
    func joinChat(username: String) {
        let data = "USR_NAME::{\(username)}".data(using: .utf8)!
        self.username = username
        
        _ = data.withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("Error joining chat")
                return
            }
            
            guard let outputStream = self.outputStream else {
                return
            }
            
            outputStream.write(pointer, maxLength: data.count)
        }
    }
}

extension ChatRoom: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            print("new message received")
            readAvailableBytes(stream: aStream as! InputStream)
        case .endEncountered:
            print("new message received")
        case .errorOccurred:
            print("error occurred")
        case .hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
        }
    }
    
    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        guard let inputStream = self.inputStream else {
            return
        }
        
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0, let error = stream.streamError {
                print(error)
                break
            }
            
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                delegate?.receive(message: message)
                print(message)
            }
        }
    }
   
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>, length: Int) -> Message? {
      guard let stringArray = String(bytesNoCopy: buffer, length: length, encoding: .utf8, freeWhenDone: true)?.components(separatedBy: ":"),
        let name = stringArray.first,
        let message = stringArray.last
        else {
          return nil
      }
        
      let messageSender: MessageSender =
        (name == self.username) ? .ourself : .someoneElse
      return Message(message: message, messageSender: messageSender, username: name)
    }
}
