import XCTest
import SSHTunnel
import Network

class IntegrationTests: XCTestCase {

    var config: Config!
    var tunnel: SSHTunnel!
    
    override func setUp() {
        super.setUp()
        
        let testPath = URL(fileURLWithPath: #file).deletingLastPathComponent().path
        let filePath = "\(testPath)/config.json"
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        config = try! JSONDecoder().decode(Config.self, from: data)
    }
    
    func testTunnelWithPrivateKey() throws {

        let exp = expectation(description: "Tunnel complete")
        let cfg = config.default
        
        
        class Delegate: SSHTunnelDelegate {
            
            let cfg: ConfigItem

            init(_ cfg: ConfigItem) {
                self.cfg = cfg
            }
            
            func sshTunnel(_ sshTunnel: SSHTunnelProtocol, returnedFingerprint fingerprintData: String) {
                sshTunnel.fingerprintIsAcceptable(true)
            }
            
            func sshTunnel(_ sshTunnel: SSHTunnelProtocol, requestsAuthentication methods: [AuthenticationMethods]) {
                let data = AuthenticationData.certificate(privateKeyPath: cfg.authentication.privateKeyURL, passphrase: cfg.authentication.passphrase)
                sshTunnel.sendAuthenticationData(data)
            }
            
            var connection: NWConnection! = nil
            func sshTunnel(_ sshTunnel: SSHTunnelProtocol, beganListeningOn port: Int) {
                let tunnel = cfg.tunnels.first!
                let port: NWEndpoint.Port = NWEndpoint.Port(rawValue: NWEndpoint.Port.RawValue(port))!
                connection = NWConnection(host: "localhost", port: port, using: .tcp)
                connection.stateUpdateHandler = self.stateDidChange(to:)
                self.setupReceive(on: connection)
                connection.start(queue: .global(qos: .background))

            }
            
            func sshTunnel(_ sshTunnel: SSHTunnelProtocol, didFailWithError error: Error) {
                print(String(describing: error))
                XCTFail("Tunnel failed")
            }
            
            func connectionDidFail(error: Error) {
                print("connectionDidFail")
            }
            
            func stateDidChange(to state: NWConnection.State) {
                switch state {
                case .setup:
                    break
                case .waiting(let error):
                    self.connectionDidFail(error: error)
                case .preparing:
                    break
                case .ready:
                    print("Connected")
                    
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { (data, context, isComplete, error) in
                        print("Got data:")
                        if let data = data {
                            print(String(data: data, encoding: .utf8)!)
                        }
                        if let error = error {
                            print("Got error:")
                            print(String(describing: error))
                        }
                        if isComplete {
                            print("All done")
                            self.connection.cancel()
                        }
                    }

                case .failed(let error):
                    self.connectionDidFail(error: error)
                case .cancelled:
                    break
                }
            }
            
            func setupReceive(on connection: NWConnection) {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, contentContext, isComplete, error) in
                    if let data = data, !data.isEmpty {
                        // … process the data …
                        print("did receive \(data.count) bytes")
                    }
                    if isComplete {
                        // … handle end of stream …
                        print("EOF")
                    } else if let error = error {
                        // … handle error …
                        self.connectionDidFail(error: error)
                    } else {
                        self.setupReceive(on: connection)
                    }
                }
            }
        }
        let delegate = Delegate(cfg)
        
        
        tunnel = SSHTunnel(toHostname: cfg.host, port: cfg.port, username: cfg.username, delegate: delegate)
        tunnel.connect()
        
        waitForExpectations(timeout: 25.0) { error in
            XCTAssertNil(error)
            
        }

    }
}
