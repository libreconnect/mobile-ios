//
//  HealthKitBaseManager.swift
//  libreconnect
//
//  Created by Nathael Bonnal on 01/07/2024.
//

import Foundation
import HealthKit

class HealthKitBaseManager {
    public let healthStore = HKHealthStore()
    
    init() {
        requestAuthorization { success, error in
            if success {
                self.enableBackgroundDelivery()
            }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        fatalError("Must override")
    }
    
    func enableBackgroundDelivery() {
        fatalError("Must override")
    }
}
