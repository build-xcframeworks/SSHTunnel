//
//  SSHTunnelConnection.swift
//  SSHTunnel
//
//  Created by Joe VanDeventer on 8/30/17.
//  Copyright © 2017 Lindell Digital. All rights reserved.
//

import Foundation

class SSHTunnelConnection: Operation {
    private let queue = DispatchQueue(label: "SSHConnectionQueue")
    private var _executing = false
    private var _finished = false
    
    var channel: SSH2Channel?
    let session: SSH2Session
    let remoteHost: String
    let remotePort: Int
    let connectionSocket: Socket
    
    override var isExecuting: Bool {
        get {
            return _executing
        }
        set {
            if _executing != newValue {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }
    
    override var isFinished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
    
    override var isAsynchronous: Bool {
        return true
    }

    required init(session: SSH2Session, socket: Socket, remoteHost: String = "localhost", remotePort: Int) {
        self.session = session
        self.connectionSocket = socket
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    override func start() {
        guard self.isCancelled == false else {
            self.isFinished = true
            return
        }
        
        isExecuting = true

        self.channel = libssh2_channel_direct_tcpip_ex(self.session, self.remoteHost, Int32(self.remotePort), "127.0.0.1", 22)
        libssh2_channel_set_blocking(self.channel, 0)

        // Select is exactly the wrong thing to be using now that individual connections are split out into
        // operations. Fix this.
        while self.isCancelled == false {
            // Create our buffer - probably a good place to use Data
            let bufferSize = 16384
            var requestBuffer:Array<UInt8> = Array(repeating: 0, count: bufferSize)
            var requestLength = 0
            
            // Create an arbitrary time value to be written to
            var tv = timeval()
            tv.tv_sec = 0
            tv.tv_usec = 500

            // File descriptor set
            var fds = fd_set.zeroed()
            fds.set(forSocket: self.connectionSocket)

            // Wait for input - should rewrite to use kqueue
            let rc = select(self.connectionSocket + 1, &fds, nil, nil, &tv)
            if rc != 0, fds.isSet(forSocket: self.connectionSocket) {
                // Wait till we receive data on the socket
                let bytesRead = recv(self.connectionSocket, &requestBuffer, bufferSize, 0)
                
                requestLength = requestLength + bytesRead
                
                let receivedData = Data(bytes:requestBuffer[0 ... requestLength])
                
                let _ = receivedData.withUnsafeBytes() { (ptr:UnsafePointer<Int8>) in
                    libssh2_channel_write_ex(channel, 0, ptr, requestLength)
                }
            }
            
            RECEIVER_LOOP: while true {
                var sendBuffer:Array<Int8> = Array(repeating: 0, count: bufferSize)
                let len = libssh2_channel_read_ex(self.channel, 0, &sendBuffer, sendBuffer.capacity)

                if len < 0 {
                    switch Int32(len) {
                    case LIBSSH2_ERROR_SOCKET_NONE:
                        print("This used to be a generic error message")
                    case LIBSSH2_ERROR_EAGAIN:
                        break
                    default:
                        print("Unhandled error: \(len)")
                    }

                    break RECEIVER_LOOP
                }
                
                var wr = 0
                while wr < len {
                    var sub = Array<Int8>(sendBuffer[wr..<len])
                    
                    let i = send(self.connectionSocket, &sub, len - wr, 0)
                    if i < 0 {
                        print("Error while sending data")
                        self.cancel()
                        break
                    } else {
                        wr += i
                    }
                }
            }
        }
        
        self.disconnect()
    }
    
    private func disconnect() {
        if let channel = self.channel {
            libssh2_channel_close(channel)
            libssh2_channel_free(channel)
        }
        close(self.connectionSocket)
    }
    
    deinit {
        self.disconnect()
    }
}

