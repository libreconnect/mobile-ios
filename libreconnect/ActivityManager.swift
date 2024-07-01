//
//  ActivityManager.swift
//  libreconnect
//
//  Created by Nathael Bonnal on 01/07/2024.
//

import Foundation
import HealthKit
import Combine

class ActivityManager: HealthKitBaseManager, ObservableObject {
    @Published var stepCount: Double = 0
    @Published var stepSamples: [HKQuantitySample] = []
    
    private let dateFormatter: ISO8601DateFormatter
        
    override init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]
        super.init()
    }
    
    override func requestAuthorization(completion: @escaping (Bool, (any Error)?) -> Void) {
        let healthDataToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: healthDataToRead) { success, error in
            completion(success, error)
            if success {
                self.startStepCountObserver()
            }
        }
    }
    
    func fetchAllStepCount(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: stepCountType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            completion(samples as? [HKQuantitySample], error)
        }
        
        healthStore.execute(query)
    }
    
    private func startStepCountObserver() {
        let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKObserverQuery(sampleType: stepCountType, predicate: nil) { [weak self] _, completionHandler, error in
            if error != nil {
                return
            }
            self?.fetchAllStepCount { stepSamples, error in
                if let stepSamples = stepSamples {
                    DispatchQueue.main.async {
                        self?.stepSamples = stepSamples
                        self?.stepCount = stepSamples.map { $0.quantity.doubleValue(for: HKUnit.count()) }.reduce(0, +)
                        //self?.sendAllStepsToServer(stepSamples: stepSamples)
                    }
                }
                completionHandler()
            }
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate) { success, error in
            if !success {
                print("Failed to enable background delivery: \(String(describing: error))")
            }
        }
    }
    
    override func enableBackgroundDelivery() {
        let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate) { success, error in
            if !success {
               print("Failed to enable background delivery: \(String(describing: error))")
            }
        }
    }
}
