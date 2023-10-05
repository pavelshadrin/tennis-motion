//
//  ContentView.swift
//  TennisMotionAnalyzerWatch Watch App
//
//  Created by Pavel Shadrin on 13.08.2023.
//

import CoreMotion
import SwiftUI
import HealthKit
import WatchConnectivity

enum RecordingState {
    case idle
    case active
}

class Model: NSObject, ObservableObject, WCSessionDelegate {
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    var lastSessionStartDate: Date?
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let e = error {
            print("\(e)")
        }
    }
}

struct ContentView: View {
    @State private var state: RecordingState = .idle
    
    let sensorManager = CMBatchedSensorManager()
    let healthStore = HKHealthStore()
    let session = WCSession.default
    
    @StateObject var model = Model()
    
    var body: some View {
        let recordingButtonTitle = state == .idle ? "Start Recording" : "Stop Recording"
        VStack {
            Button(recordingButtonTitle) {
                state == .idle ? self.startWorkout(workoutType: .tennis) : self.stopCurrentWorkout()
            }
        }
        .padding()
        .navigationTitle("Tennis Motion Data")
        .onAppear {
            self.requestAuthorization()
            
            if WCSession.isSupported() {
                session.delegate = self.model
                session.activate()
            }
        }
    }
    
    private func startWorkout(workoutType: HKWorkoutActivityType) {
        guard CMBatchedSensorManager.isAccelerometerSupported && CMBatchedSensorManager.isDeviceMotionSupported else {
            return
        }
        
        model.lastSessionStartDate = Date()
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor

        do {
            model.session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            model.builder = model.session?.associatedWorkoutBuilder()
        } catch {
            return
        }

        model.builder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        let startDate = Date()
        model.session?.startActivity(with: startDate)
        model.builder?.beginCollection(withStart: startDate) { (success, error) in
            if success {
                self.state = .active
            }
            
            Task {
                do {
                    for try await data in CMBatchedSensorManager().accelerometerUpdates() {
                        let tennisSession = TennisSession(dateStarted: Date(), dateFinished: Date(), accelerometerData: data, gyroscopeData: [])
                        
                        sendToiPhone(tennisSession: tennisSession)
                    }
                } catch let error as NSError {
                    print("\(error)")
                }
            }
            
            Task {
                do {
                    for try await data in CMBatchedSensorManager().deviceMotionUpdates() {
                        let tennisSession = TennisSession(dateStarted: Date(), dateFinished: Date(), accelerometerData: [], gyroscopeData: data)
                        
                        sendToiPhone(tennisSession: tennisSession)
                    }
                } catch let error as NSError {
                    print("\(error)")
                }
            }
        }
    }
    
    private func sendToiPhone(tennisSession: TennisSession) {
        let dict: [String : Any] = ["data": tennisSession.encodeIt()]
        session.sendMessage(dict, replyHandler: { reply in
            print("Got reply from iPhone")
        }, errorHandler: { error in
            print("Failed to send data to iPhone: \(error)")
        })
    }
    
    private func stopCurrentWorkout() {
        self.state = .idle
        model.builder?.workoutSession?.stopActivity(with: Date())
        CMBatchedSensorManager().stopAccelerometerUpdates()
        CMBatchedSensorManager().stopDeviceMotionUpdates()
    }
    
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.activitySummaryType()
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
