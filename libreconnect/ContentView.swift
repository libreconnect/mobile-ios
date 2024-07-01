//
//  ContentView.swift
//  libreconnect
//
//  Created by Nathael Bonnal on 30/06/2024.
//

import SwiftUI
import HealthKitUI

struct ContentView: View {
    @StateObject private var activityManager = ActivityManager()
    @StateObject private var heartManager = HeartManager()
    
    var body: some View {
        VStack {
            Text("Total Step Count: \(Int(activityManager.stepCount))")
                .padding()
            
            Text("Recent Heart Rates:")
                .padding()
            
            List(heartManager.heartRateSamples, id: \.uuid) { sample in
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                Text("\(bpm) BPM")
            }
        }
        .onAppear {
            activityManager.requestAuthorization { success, error in
                if success {
                    activityManager.fetchAllStepCount { stepSamples, error in
                        if let stepSamples = stepSamples {
                            self.activityManager.stepSamples = stepSamples
                            self.activityManager.stepCount = stepSamples.map { $0.quantity.doubleValue(for: HKUnit.count()) }.reduce(0, +)
                        }
                    }
                }
            }
            
            heartManager.requestAuthorization { success, error in
                if success {
                    heartManager.fetchHeartRate { heartRateSamples, error in
                        if let heartRateSamples = heartRateSamples {
                            self.heartManager.heartRateSamples = heartRateSamples
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
