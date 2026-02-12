import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "apple" asset catalog image resource.
    static let apple = ImageResource(name: "apple", bundle: resourceBundle)

    /// The "dingyue" asset catalog image resource.
    static let dingyue = ImageResource(name: "dingyue", bundle: resourceBundle)

    /// The "fantuan_duanlian" asset catalog image resource.
    static let fantuanDuanlian = ImageResource(name: "fantuan_duanlian", bundle: resourceBundle)

    /// The "fantuan_water" asset catalog image resource.
    static let fantuanWater = ImageResource(name: "fantuan_water", bundle: resourceBundle)

    /// The "first" asset catalog image resource.
    static let first = ImageResource(name: "first", bundle: resourceBundle)

    /// The "login_card_title" asset catalog image resource.
    static let loginCardTitle = ImageResource(name: "login_card_title", bundle: resourceBundle)

    /// The "onboarding_hero" asset catalog image resource.
    static let onboardingHero = ImageResource(name: "onboarding_hero", bundle: resourceBundle)

    /// The "riceball_boy" asset catalog image resource.
    static let riceballBoy = ImageResource(name: "riceball_boy", bundle: resourceBundle)

    /// The "riceball_camera" asset catalog image resource.
    static let riceballCamera = ImageResource(name: "riceball_camera", bundle: resourceBundle)

    /// The "riceball_eat" asset catalog image resource.
    static let riceballEat = ImageResource(name: "riceball_eat", bundle: resourceBundle)

    /// The "riceball_girl" asset catalog image resource.
    static let riceballGirl = ImageResource(name: "riceball_girl", bundle: resourceBundle)

    /// The "riceball_meditate" asset catalog image resource.
    static let riceballMeditate = ImageResource(name: "riceball_meditate", bundle: resourceBundle)

    /// The "riceball_run" asset catalog image resource.
    static let riceballRun = ImageResource(name: "riceball_run", bundle: resourceBundle)

    /// The "slogan" asset catalog image resource.
    static let slogan = ImageResource(name: "slogan", bundle: resourceBundle)

    /// The "vip" asset catalog image resource.
    static let vip = ImageResource(name: "vip", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "apple" asset catalog image.
    static var apple: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .apple)
#else
        .init()
#endif
    }

    /// The "dingyue" asset catalog image.
    static var dingyue: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dingyue)
#else
        .init()
#endif
    }

    /// The "fantuan_duanlian" asset catalog image.
    static var fantuanDuanlian: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fantuanDuanlian)
#else
        .init()
#endif
    }

    /// The "fantuan_water" asset catalog image.
    static var fantuanWater: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .fantuanWater)
#else
        .init()
#endif
    }

    /// The "first" asset catalog image.
    static var first: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .first)
#else
        .init()
#endif
    }

    /// The "login_card_title" asset catalog image.
    static var loginCardTitle: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .loginCardTitle)
#else
        .init()
#endif
    }

    /// The "onboarding_hero" asset catalog image.
    static var onboardingHero: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .onboardingHero)
#else
        .init()
#endif
    }

    /// The "riceball_boy" asset catalog image.
    static var riceballBoy: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballBoy)
#else
        .init()
#endif
    }

    /// The "riceball_camera" asset catalog image.
    static var riceballCamera: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballCamera)
#else
        .init()
#endif
    }

    /// The "riceball_eat" asset catalog image.
    static var riceballEat: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballEat)
#else
        .init()
#endif
    }

    /// The "riceball_girl" asset catalog image.
    static var riceballGirl: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballGirl)
#else
        .init()
#endif
    }

    /// The "riceball_meditate" asset catalog image.
    static var riceballMeditate: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballMeditate)
#else
        .init()
#endif
    }

    /// The "riceball_run" asset catalog image.
    static var riceballRun: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .riceballRun)
#else
        .init()
#endif
    }

    /// The "slogan" asset catalog image.
    static var slogan: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .slogan)
#else
        .init()
#endif
    }

    /// The "vip" asset catalog image.
    static var vip: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .vip)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "apple" asset catalog image.
    static var apple: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .apple)
#else
        .init()
#endif
    }

    /// The "dingyue" asset catalog image.
    static var dingyue: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dingyue)
#else
        .init()
#endif
    }

    /// The "fantuan_duanlian" asset catalog image.
    static var fantuanDuanlian: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .fantuanDuanlian)
#else
        .init()
#endif
    }

    /// The "fantuan_water" asset catalog image.
    static var fantuanWater: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .fantuanWater)
#else
        .init()
#endif
    }

    /// The "first" asset catalog image.
    static var first: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .first)
#else
        .init()
#endif
    }

    /// The "login_card_title" asset catalog image.
    static var loginCardTitle: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .loginCardTitle)
#else
        .init()
#endif
    }

    /// The "onboarding_hero" asset catalog image.
    static var onboardingHero: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .onboardingHero)
#else
        .init()
#endif
    }

    /// The "riceball_boy" asset catalog image.
    static var riceballBoy: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballBoy)
#else
        .init()
#endif
    }

    /// The "riceball_camera" asset catalog image.
    static var riceballCamera: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballCamera)
#else
        .init()
#endif
    }

    /// The "riceball_eat" asset catalog image.
    static var riceballEat: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballEat)
#else
        .init()
#endif
    }

    /// The "riceball_girl" asset catalog image.
    static var riceballGirl: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballGirl)
#else
        .init()
#endif
    }

    /// The "riceball_meditate" asset catalog image.
    static var riceballMeditate: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballMeditate)
#else
        .init()
#endif
    }

    /// The "riceball_run" asset catalog image.
    static var riceballRun: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .riceballRun)
#else
        .init()
#endif
    }

    /// The "slogan" asset catalog image.
    static var slogan: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .slogan)
#else
        .init()
#endif
    }

    /// The "vip" asset catalog image.
    static var vip: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .vip)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}

protocol _ACResourceInitProtocol {}
extension AppKit.NSImage: _ACResourceInitProtocol {}

@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension _ACResourceInitProtocol {

    /// Initialize a `NSImage` with an image resource.
    init(resource: ImageResource) {
        self = resource.bundle.image(forResource: NSImage.Name(resource.name))! as! Self
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(resource: ColorResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}

@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(resource: ImageResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(_ resource: ImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif