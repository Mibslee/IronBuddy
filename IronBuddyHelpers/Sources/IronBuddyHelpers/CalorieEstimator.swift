//
//  CalorieEstimator.swift
//

import Foundation

public enum CalorieEstimator {
    public static func estimateCalories(mets: Double, weightKg: Double, durationMinutes: Int) -> Int {
        Int((mets * weightKg * Double(durationMinutes) / 60.0).rounded())
    }
}
