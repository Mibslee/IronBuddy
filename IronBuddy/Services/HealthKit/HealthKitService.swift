//
//  HealthKitService.swift
//  IronBuddy
//

import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    private let healthStore = HKHealthStore()

    private enum SaveError: Error {
        case energyTypeUnavailable
    }

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// 首次启动由 App 触发；失败不抛，由调用方决定是否提示。
    func requestWorkoutWriteAuthorizationIfNeeded() async {
        guard isHealthDataAvailable() else { return }
        guard let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let toShare: Set<HKSampleType> = [HKObjectType.workoutType(), active]
        let toRead: Set<HKObjectType> = [HKObjectType.workoutType()]

        do {
            try await healthStore.requestAuthorization(toShare: toShare, read: toRead)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitAuthRequested)
        } catch {
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.healthKitAuthRequested)
        }
    }

    /// HKWorkoutBuilder + brand metadata；能量使用 `activeEnergyBurned`。写入失败请在外层捕获，不阻塞训练流程。
    func saveWorkout(type: String, start: Date, end: Date, calories: Double, notes: String) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        var meta: [String: Any] = [HKMetadataKeyWorkoutBrandName: "IronBuddy"]
        meta["ExerciseType"] = type
        if !notes.isEmpty { meta["Notes"] = notes }
        try await builder.addMetadata(meta)

        if calories > 0 {
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                throw SaveError.energyTypeUnavailable
            }
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
            let sample = HKQuantitySample(type: energyType, quantity: quantity, start: start, end: end)
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: end)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            builder.finishWorkout { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], any Error>) in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKWorkout]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}
