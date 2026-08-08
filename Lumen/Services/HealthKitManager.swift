import Foundation
import HealthKit
import SwiftData

@Observable final class HealthKitManager {
  private let store = HKHealthStore()
  var isAuthorized = false
  var lastError: String?

  private var flowType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .menstrualFlow) }
  private var spottingType: HKCategoryType? {
    HKObjectType.categoryType(forIdentifier: .intermenstrualBleeding)
  }
  private var temperatureType: HKQuantityType? {
    HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)
  }
  private var sexualType: HKCategoryType? {
    HKObjectType.categoryType(forIdentifier: .sexualActivity)
  }

  func requestAuthorization() async -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else {
      lastError = "Apple Health is unavailable on this device."
      return false
    }
    let optionalTypes: [HKSampleType?] = [flowType, spottingType, temperatureType, sexualType]
    let shareTypes = Set(optionalTypes.compactMap { $0 })
    let readTypes = Set(shareTypes.map { $0 as HKObjectType })
    do {
      try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
      isAuthorized = true
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  func write(_ entry: DailyEntry) async {
    var samples: [HKSample] = []
    let end = Calendar.current.date(byAdding: .minute, value: 1, to: entry.date) ?? entry.date
    if entry.flow != .none, let type = flowType {
      let value: Int
      switch entry.flow {
      case .spotting: value = HKCategoryValueVaginalBleeding.unspecified.rawValue
      case .light: value = HKCategoryValueVaginalBleeding.light.rawValue
      case .medium: value = HKCategoryValueVaginalBleeding.medium.rawValue
      case .heavy: value = HKCategoryValueVaginalBleeding.heavy.rawValue
      case .none: value = HKCategoryValueVaginalBleeding.none.rawValue
      }
      samples.append(
        HKCategorySample(
          type: type, value: value, start: entry.date, end: end,
          metadata: [HKMetadataKeyMenstrualCycleStart: entry.flow != .spotting]))
    }
    if entry.flow == .spotting, let type = spottingType {
      samples.append(
        HKCategorySample(
          type: type, value: HKCategoryValue.notApplicable.rawValue, start: entry.date, end: end))
    }
    if let temperature = entry.basalTemperature, let type = temperatureType {
      samples.append(
        HKQuantitySample(
          type: type, quantity: HKQuantity(unit: .degreeCelsius(), doubleValue: temperature),
          start: entry.date, end: end))
    }
    if entry.sexualActivity, let type = sexualType {
      samples.append(
        HKCategorySample(
          type: type, value: HKCategoryValue.notApplicable.rawValue, start: entry.date, end: end,
          metadata: [HKMetadataKeySexualActivityProtectionUsed: entry.protectionUsed]))
    }
    guard !samples.isEmpty else { return }
    do { try await store.save(samples) } catch { lastError = error.localizedDescription }
  }

  func importRecent(into context: ModelContext) async {
    guard isAuthorized else { return }
    let start = Calendar.current.date(byAdding: .month, value: -12, to: .now) ?? .distantPast
    let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
    do {
      async let flows = samples(for: flowType, predicate: predicate)
      async let spotting = samples(for: spottingType, predicate: predicate)
      async let temps = samples(for: temperatureType, predicate: predicate)
      async let activity = samples(for: sexualType, predicate: predicate)
      for sample in try await flows + spotting + temps + activity {
        let day = Calendar.current.startOfDay(for: sample.startDate)
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate { $0.date == day })
        let entry =
          try context.fetch(descriptor).first
          ?? {
            let item = DailyEntry(date: day)
            context.insert(item)
            return item
          }()
        if let category = sample as? HKCategorySample, category.categoryType == flowType {
          entry.flowRaw = healthFlow(category.value).rawValue
        } else if let category = sample as? HKCategorySample, category.categoryType == spottingType
        {
          entry.flowRaw = FlowLevel.spotting.rawValue
        } else if let quantity = sample as? HKQuantitySample {
          entry.basalTemperature = quantity.quantity.doubleValue(for: .degreeCelsius())
        } else if let category = sample as? HKCategorySample, category.categoryType == sexualType {
          entry.sexualActivity = true
          entry.protectionUsed =
            category.metadata?[HKMetadataKeySexualActivityProtectionUsed] as? Bool ?? false
        }
      }
      try context.save()
    } catch { lastError = error.localizedDescription }
  }

  private func samples(for type: HKSampleType?, predicate: NSPredicate) async throws -> [HKSample] {
    guard let type else { return [] }
    return try await withCheckedThrowingContinuation { continuation in
      store.execute(
        HKSampleQuery(
          sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
        ) { _, samples, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: samples ?? [])
          }
        })
    }
  }

  private func healthFlow(_ value: Int) -> FlowLevel {
    switch HKCategoryValueVaginalBleeding(rawValue: value) {
    case .light: .light
    case .medium: .medium
    case .heavy: .heavy
    case .unspecified: .spotting
    default: .none
    }
  }
}
