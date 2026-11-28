import Foundation

// Degrees from the chip's sensors. macOS has no public call for this on Apple Silicon, so this uses private IOKit
// functions that monitoring tools rely on. They are looked up by name at run time: if a later macOS removes or
// changes them, the result is nil and the panel shows macOS's public thermal level instead.

final class TemperatureSensors {
	private typealias Create = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
	private typealias SetMatching = @convention(c) (AnyObject, CFDictionary) -> Int32
	private typealias CopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
	private typealias CopyProperty = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?
	private typealias CopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
	private typealias FloatValue = @convention(c) (AnyObject, Int32) -> Double

	private static let temperatureEvent: Int64 = 15                  // kIOHIDEventTypeTemperature
	private static let temperatureField = Int32(15 << 16)            // the value field of that event type
	private static let appleVendorPage = 0xff00, temperatureUsage = 5

	private let copyEvent: CopyEvent
	private let floatValue: FloatValue
	private let client: AnyObject                                    // must outlive the services it handed out
	private let sensors: [(name: String, service: AnyObject)]

	init?() {
		guard let library = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
		      let create: Create = Self.symbol(library, "IOHIDEventSystemClientCreate"),
		      let setMatching: SetMatching = Self.symbol(library, "IOHIDEventSystemClientSetMatching"),
		      let copyServices: CopyServices = Self.symbol(library, "IOHIDEventSystemClientCopyServices"),
		      let copyProperty: CopyProperty = Self.symbol(library, "IOHIDServiceClientCopyProperty"),
		      let copyEvent: CopyEvent = Self.symbol(library, "IOHIDServiceClientCopyEvent"),
		      let floatValue: FloatValue = Self.symbol(library, "IOHIDEventGetFloatValue"),
		      let client = create(kCFAllocatorDefault)?.takeRetainedValue() else { return nil }
		_ = setMatching(client, ["PrimaryUsagePage": Self.appleVendorPage, "PrimaryUsage": Self.temperatureUsage] as CFDictionary)
		guard let services = copyServices(client)?.takeRetainedValue() as [AnyObject]? else { return nil }
		self.copyEvent = copyEvent
		self.floatValue = floatValue
		self.client = client
		sensors = services.compactMap { service in
			guard let name = copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String else { return nil }
			return (name, service)
		}
		if sensors.isEmpty { return nil }
	}

	func readings() -> [(name: String, celsius: Double)] {
		sensors.compactMap { sensor in
			guard let event = copyEvent(sensor.service, Self.temperatureEvent, 0, 0)?.takeRetainedValue() else { return nil }
			return (sensor.name, floatValue(event, Self.temperatureField))
		}
	}

	private static func symbol<T>(_ library: UnsafeMutableRawPointer, _ name: String) -> T? {
		dlsym(library, name).map { unsafeBitCast($0, to: T.self) }
	}
}
