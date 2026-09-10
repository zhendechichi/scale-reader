import Foundation
import HealthKit

/// 单项写入健康的结果。
struct HealthWriteOutcome {
    let label: String
    let ok: Bool
    let message: String
}

/// HealthKit 写入服务：按类型逐个写入、逐个报错，单项失败不影响其他项。
///
/// 单位与口径说明：
/// - 体脂肪率：HealthKit 的 percent() 用“分数”表示（1.0 = 100%），所以要除以 100 再写。
/// - 骨骼肌：健康没有“骨骼肌率”，只有质量类指标，用 体重×骨骼肌率 换算出 kg，
///   写入“去脂体重 leanBodyMass”（第三方同步工具通行的近似写法）。
/// - 基础代谢：写入“静息能量”（basalEnergyBurned）。
/// - 内脏脂肪等级、身体年龄：健康没有对应类型，只保存在 App 内。
@MainActor
final class HealthService {
    private let store = HKHealthStore()

    private struct Candidate {
        let label: String
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        let value: Double?
    }

    func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func save(
        _ reading: ScaleReading,
        writeWeight: Bool,
        writeBodyFat: Bool,
        writeMuscleKg: Bool,
        writeBMI: Bool,
        writeBasalEnergy: Bool
    ) async -> [HealthWriteOutcome] {
        var outcomes: [HealthWriteOutcome] = []
        guard HKHealthStore.isHealthDataAvailable() else {
            outcomes.append(HealthWriteOutcome(label: "健康", ok: false, message: "此设备不支持 HealthKit"))
            return outcomes
        }

        let candidates: [Candidate] = [
            Candidate(label: "体重", identifier: .bodyMass,
                      unit: .gramUnit(with: .kilo), value: reading.weightKg),
            Candidate(label: "体脂肪率", identifier: .bodyFatPercentage,
                      unit: .percent(), value: reading.bodyFatPct.map { $0 / 100.0 }),
            Candidate(label: "骨骼肌", identifier: .leanBodyMass,
                      unit: .gramUnit(with: .kilo), value: reading.computedSkeletalMuscleKg),
            Candidate(label: "BMI", identifier: .bodyMassIndex,
                      unit: .count(), value: reading.bmi),
            Candidate(label: "基础代谢", identifier: .basalEnergyBurned,
                      unit: .kilocalorie(), value: reading.basalMetabolismKcal),
        ]
        let enabled = [writeWeight, writeBodyFat, writeMuscleKg, writeBMI, writeBasalEnergy]

        var toShare = Set<HKQuantityType>()
        var active: [Candidate] = []
        for (candidate, on) in zip(candidates, enabled) where on {
            guard candidate.value != nil,
                  let type = HKObjectType.quantityType(forIdentifier: candidate.identifier)
            else { continue }
            toShare.insert(type)
            active.append(candidate)
        }
        guard !active.isEmpty else { return outcomes }

        do {
            try await store.requestAuthorization(toShare: toShare, read: [])
        } catch {
            outcomes.append(HealthWriteOutcome(label: "授权", ok: false,
                                               message: "健康授权失败：\(error.localizedDescription)"))
            return outcomes
        }

        for candidate in active {
            guard let value = candidate.value,
                  let type = HKObjectType.quantityType(forIdentifier: candidate.identifier)
            else { continue }
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: candidate.unit, doubleValue: value),
                start: reading.date,
                end: reading.date
            )
            do {
                try await store.save(sample)
                outcomes.append(HealthWriteOutcome(label: candidate.label, ok: true,
                                                   message: "已写入健康"))
            } catch {
                outcomes.append(HealthWriteOutcome(label: candidate.label, ok: false,
                                                   message: "写入失败：\(error.localizedDescription)"))
            }
        }
        return outcomes
    }
}
