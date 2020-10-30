import Foundation

public enum DNSServiceError: Int32, Error {
    
    case noError = 0
    case unknown = -65537
    case noSuchName = -65538
    case noMemory  = -65539
    case badParam = -65540
    case badReference = -65541
    case badState = -65542
    case badFlags = -65543
    case unsupported = -65544
    case notInitialized = -65545
    case alreadyRegistered = -65547
    case nameConflict = -65548
    case invalid = -65549
    case firewall = -65550
    case incompatible = -65551
    case badInterfaceIndex = -65552
    case refused = -65553
    case noSuchRecord = -65554
    case noAuth = -65555
    case noSuchKey = -65556
    case natTraversal = -65557
    case doubleNAT = -65558
    case badTime = -65559
}

