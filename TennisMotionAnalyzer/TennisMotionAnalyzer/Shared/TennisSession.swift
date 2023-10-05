//
//  TennisSession.swift
//  TennisMotionAnalyzer
//
//  Created by Pavel Shadrin on 13.08.2023.
//

import Foundation
import CoreMotion

struct SessionAccelerometerSnapshot: Codable {
    let timestamp: TimeInterval
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
}

struct SessionGyroscopeSnapshot: Codable {
    let timestamp: TimeInterval
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
}

struct SessionMotionData: Codable {
    let accelerometerSnapshots: [SessionAccelerometerSnapshot]
    let gyroscopeSnapshots: [SessionGyroscopeSnapshot]
}

struct TennisSession: Codable {
    let dateStarted: Date
    let dateFinished: Date
    let sessionData: SessionMotionData
    
    init(dateStarted: Date, dateFinished: Date, accelerometerData: [CMAccelerometerData], gyroscopeData: [CMDeviceMotion]) {
        self.dateStarted = dateStarted
        self.dateFinished = dateFinished
        
        let accSnapshots = accelerometerData.map { data in
            SessionAccelerometerSnapshot(timestamp: data.timestamp, accelerationX: data.acceleration.x, accelerationY: data.acceleration.y, accelerationZ: data.acceleration.z)
        }
        
        let gyrSnapshots = gyroscopeData.map { data in
            SessionGyroscopeSnapshot(timestamp: data.timestamp, rotationX: data.rotationRate.x, rotationY: data.rotationRate.y, rotationZ: data.rotationRate.z)
        }
        
        self.sessionData = SessionMotionData(accelerometerSnapshots: accSnapshots, gyroscopeSnapshots: gyrSnapshots)
    }
    
    func encodeIt() -> Data {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            return encoded
        }
        
        return Data()
    }
    
    static func decodeIt(_ data: Data) -> TennisSession {        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(TennisSession.self, from: data) {
            return decoded
        }
        
        return TennisSession(dateStarted: Date(), dateFinished: Date(), accelerometerData: [], gyroscopeData: [])
    }
    
    func createAcceletometerDataCSV(includeHeader: Bool = true) -> String {
        var csvString = includeHeader ? "\("Timestamp"),\("X"),\("Y"),\("Z")\n\n" : ""
        for snapshot in sessionData.accelerometerSnapshots {
            csvString = csvString.appending("\(snapshot.timestamp),\(snapshot.accelerationX),\(snapshot.accelerationY),\(snapshot.accelerationZ)\n")
        }
        return csvString
    }
    
    func createGyroscopeDataCSV(includeHeader: Bool = true) -> String {
        var csvString = includeHeader ? "\("Timestamp"),\("X"),\("Y"),\("Z")\n\n" : ""
        for snapshot in sessionData.gyroscopeSnapshots {
            csvString = csvString.appending("\(snapshot.timestamp),\(snapshot.rotationX),\(snapshot.rotationY),\(snapshot.rotationZ)\n")
        }
        return csvString
    }
}
