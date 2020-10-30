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
            let exp: XCTestExpectation

            init(_ cfg: ConfigItem, expectation exp: XCTestExpectation) {
                self.cfg = cfg
                self.exp = exp
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
                connection.start(queue: .global(qos: .background))
            }
            
            func sshTunnel(_ sshTunnel: SSHTunnelProtocol, didFailWithError error: Error) {
                print(String(describing: error))
                XCTFail("Tunnel failed")
            }
            
            func connectionDidFail(error: Error) {
                print("Delegate: connectionDidFail")
                if let nwerror = error as? NWError {
                    switch nwerror {
                    case .posix(let posixErrorCode):
                        print("Posix")

                    case .dns(let dnsServiceErrorType):
                        if let error = DNSServiceError(rawValue: dnsServiceErrorType) {
                            switch error {
                            case .noSuchRecord:
                                print("Unknown host to tunnel to")
                            default:
                                print("Unhandled DNS error")
                            }
                        } else {
                            print("Unknown DNS error")
                        }
                    
                    case .tls(let osStatus):
                        print("TLS")
                    }
                } else {
                    print("Unknown error case")
                }
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
                    setupReceive(on: connection)
                case .failed(let error):
                    self.connectionDidFail(error: error)
                case .cancelled:
                    break
                default:
                    XCTFail("State enum has expanded since this test was written, imlpement it")
                }
            }
            
            
            var total = 0
        func setupReceive(on connection: NWConnection) {
                print("Ready to receive...")
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, contentContext, isComplete, error) in
                    if let data = data, !data.isEmpty {
                        self.total = self.total + data.count
                        print("did receive \(data.count) bytes, total \(self.total)")
                    }
                    if isComplete {
                        // … handle end of stream …
                        print("EOF")
                        self.exp.fulfill()
                    } else if let error = error {
                        // … handle error …
                        print("Got error: \(String(describing: error))")
                        self.connectionDidFail(error: error)
                    } else {
                        self.setupReceive(on: connection)
                    }
                }
            }
        }
        let delegate = Delegate(cfg, expectation: exp)
        
        for t in cfg.tunnels {
            tunnel = SSHTunnel(toHostname: cfg.host, port: cfg.port, username: cfg.username, delegate: delegate, tunnelToHost: t.host, tunnelToPort: t.port)
            tunnel.connect()
        }
        
        
        waitForExpectations(timeout: 18.0) { error in
            XCTAssertNil(error)
            
        }

    }
}
