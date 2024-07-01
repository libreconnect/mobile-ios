//
//  HealthKitManager.swift
//  libreconnect
//
//  Created by Nathael Bonnal on 30/06/2024.
//

import Foundation
import HealthKit
import Combine
import UserNotifications

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var stepCount: Double = 0
    @Published var stepSamples: [HKQuantitySample] = []
    
    private let dateFormatter: ISO8601DateFormatter
    
    init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]
        requestNotificationAuthorization()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let healthDataToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: healthDataToRead) { success, error in
            completion(success, error)
            if success {
                self.startStepCountObserver()
            }
        }
    }
    
    func fetchStepCount(completion: @escaping (Double?, Error?) -> Void) {
        let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: nil, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            
            let stepCount = sum.doubleValue(for: HKUnit.count())
            completion(stepCount, nil)
        }
        
        healthStore.execute(query)
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
                       self?.sendAllStepsToServer(stepSamples: stepSamples)
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
    
    private func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    private func sendStepCountNotification(stepCount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "New Step Count Data"
        content.body = "Your step count has been updated to \(Int(stepCount)) steps."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error = error {
                print("Error adding notification: \(error)")
            }
        }
    }
    
    private func sendStepCountToServer(stepCount: Double) {
        guard let url = URL(string: "http://localhost:3333/steps") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let json: [String: Any] = ["steps": stepCount]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("HTTP Request Failed \(error)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("HTTP Response Body: \(responseString)")
            }
        }
        task.resume()
    }
    
    private func sendAllStepsToServer(stepSamples: [HKQuantitySample]) {
        guard let url = URL(string: "http://localhost:3333/steps") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let stepsData = stepSamples.map { sample -> [String: Any] in
            let quantity = sample.quantity.doubleValue(for: HKUnit.count())
            let startDate = dateFormatter.string(from: sample.startDate)
            let endDate = dateFormatter.string(from: sample.endDate)
            return [
                "quantity": quantity,
                "startDate": startDate,
                "endDate": endDate
            ]
        }
        
        let json: [String: Any] = ["steps": stepsData]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("HTTP Request Failed \(error)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("HTTP Response Body: \(responseString)")
            }
        }
        task.resume()
    }
}
