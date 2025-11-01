//
//  Farm view.swift
//  Hub
//
//  Created by Linux on 31.10.25.
//

import SwiftUI
#if os(macOS)
import IOKit.ps
import IOKit.pwr_mgt
#elseif os(iOS)
import Combine
#endif

struct FarmView: View {
  @State var minimumBattery: Float = 80
  @State var blackOverlay: Bool = true
  @Bindable var farm = Farm.main
  var body: some View {
    List {
      VStack(alignment: .leading) {
        Text(text)
        HStack {
          Slider(value: $minimumBattery, in: 0...100, step: 5)
            .frame(maxWidth: 200)
          Image(battery: minimumBattery, charging: false)
        }
      }
      Toggle("Lower brightness", isOn: $farm.lowerBrightness)
      Toggle("Black overlay", isOn: $blackOverlay)
      Button("Start") {
        farm.isRunning = true
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
      .toggleStyle(.switch)
      .overlay {
        if farm.isRunning {
          Color.black.opacity(blackOverlay ? 1 : 0.001).onTapGesture {
            farm.isRunning = false
          }.ignoresSafeArea()
        }
      }.statusBarHidden(farm.isRunning)
  }
  var text: LocalizedStringKey {
    if minimumBattery == 0 {
      return "Run until turned off"
    } else if minimumBattery == 1 {
      return "Run while charging"
    } else {
      return "Run while charging or battery level is above \(Int(minimumBattery))%"
    }
  }
}

extension Image {
  init(battery: Float, charging: Bool) {
    if charging {
      self.init(systemName: "battery.100percent.bolt")
    } else {
      switch battery {
      case ...10:
        self.init(systemName: "battery.0percent")
      case 5...30:
        self.init(systemName: "battery.25percent")
      case 30...60:
        self.init(systemName: "battery.50percent")
      case 60...85:
        self.init(systemName: "battery.75percent")
      default:
        self.init(systemName: "battery.100percent")
      }
    }
  }
}

@Observable
class Farm {
  static let main = Farm()
  var battery: BatteryStatus?
  var isRunning = false {
    didSet {
      guard isRunning != oldValue else { return }
      preventSleep(enabled: isRunning)
      lowerBrightness(enabled: isRunning)
      if isRunning {
        trackBattery()
      } else {
        stopTrackingBattery()
      }
    }
  }
  var lowerBrightness: Bool = true
  
#if os(macOS)
  private var powerSourceRunLoopSource: CFRunLoopSource?
  private var sleepAssertionID: IOPMAssertionID = 0
#elseif os(iOS)
  private var brightness: CGFloat?
  weak var screen: UIScreen?
  private var powerTracking: AnyCancellable?
  private var farmTracking: AnyCancellable?
#endif
  
  init() {
    battery = batteryStatus()
#if os(iOS)
    farmTracking = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink { [unowned self] _ in
      isRunning = false
    }
#endif
  }
  
  struct BatteryStatus {
    var level: Float
    var charging: Bool
  }
  
  private func batteryStatus() -> BatteryStatus? {
#if os(macOS)
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
    for ps in sources {
      let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as! [String: AnyObject]
      guard let capacity = info[kIOPSCurrentCapacityKey] as? Int else { continue }
      guard let max = info[kIOPSMaxCapacityKey] as? Int else { continue }
      return BatteryStatus(level: Float(capacity) / Float(max), charging: info[kIOPSPowerSourceStateKey] as? String != "Battery Power")
    }
    return nil
#elseif os(iOS)
    let state = UIDevice.current.batteryState
    return BatteryStatus(level: UIDevice.current.batteryLevel, charging: state == .charging || state == .full)
#endif
  }
  
  private func trackBattery() {
#if os(macOS)
    let context = Unmanaged.passUnretained(self).toOpaque()
    let callback: IOPowerSourceCallbackType = { context in
      guard let context = context else { return }
      Unmanaged<Farm>.fromOpaque(context).takeUnretainedValue().updateBatteryStatus()
    }
    
    powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(callback, context).takeRetainedValue()
    if let runLoopSource = powerSourceRunLoopSource {
      CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
#elseif os(iOS)
    UIDevice.current.isBatteryMonitoringEnabled = true
    powerTracking = NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
      .combineLatest(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)).sink { [unowned self] _, _ in
        updateBatteryStatus()
    }
#endif
  }
  
  private func stopTrackingBattery() {
#if os(macOS)
    if let runLoopSource = powerSourceRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
#elseif os(iOS)
    NotificationCenter.default.removeObserver(self)
#endif
  }
  
  private func preventSleep(enabled: Bool) {
#if os(macOS)
    if enabled {
      // Prevent sleep - create assertion if not already active
      if sleepAssertionID == 0 {
        let result = IOPMAssertionCreateWithName(
          kIOPMAssertionTypeNoIdleSleep as CFString,
          IOPMAssertionLevel(kIOPMAssertionLevelOn),
          "Preventing system sleep" as CFString,
          &sleepAssertionID
        )
        if result != kIOReturnSuccess {
          print("Failed to create sleep assertion: \(result)")
        }
      }
    } else {
      // Allow sleep - release assertion if active
      if sleepAssertionID != 0 {
        IOPMAssertionRelease(sleepAssertionID)
        sleepAssertionID = 0
      }
    }
#elseif os(iOS)
    UIApplication.shared.isIdleTimerDisabled = enabled
#endif
  }
  
  private func updateBatteryStatus() {
    battery = batteryStatus()
  }
  
  private func lowerBrightness(enabled: Bool) {
#if os(iOS)
    if enabled {
      if lowerBrightness {
        screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        if let screen {
          brightness = screen.brightness
          screen.brightness = 0
        }
      }
    } else if let brightness {
      screen?.brightness = brightness
    }
#endif
  }
}

#Preview {
  FarmView()
}
