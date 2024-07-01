//
//  HeartManager.swift
//  libreconnect
//
//  Created by Nathael Bonnal on 01/07/2024.
//

import Foundation
import HealthKit
import Combine

class HeartManager: HealthKitBaseManager, ObservableObject {
    @Published var heartRateSamples: [HKQuantitySample] = []
    
    override init() {
        super.init()
    }
    
    override func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let healthDataToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        DispatchQueue.main.async {
            self.healthStore.requestAuthorization(toShare: nil, read: healthDataToRead) { success, error in
                completion(success, error)
                if success {
                    self.fetchHeartRate { heartRateSamples, error in
                        if let heartRateSamples = heartRateSamples {
                            DispatchQueue.main.async {
                                self.heartRateSamples = heartRateSamples
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func enableBackgroundDelivery() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        self.healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in 
            if !success {
                print("Failed to enable background delivery: \(String(describing: error))")
            }
        }
    }
    
    func fetchHeartRate(completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
            completion(samples as? [HKQuantitySample], error)
        }
        
        healthStore.execute(query)
    }

    func startHeartRateQuery() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            guard let self = self, let newSamples = samples as? [HKQuantitySample] else {
                return
            }
            self.anchor = newAnchor
            DispatchQueue.main.async {
                self.heartRateSamples.append(contentsOf: newSamples)
            }
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in 
            guard let self = self, let newSamples = samples as? [HKQuantitySample] else {
                return
            }

            self.anchor = newAnchor
            DispatchQueue.main.async {
                self.heartRateSamples.append(contentsOf: newSamples)
            }
        }
    }
}
