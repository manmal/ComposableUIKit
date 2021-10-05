import CombineLifetime
import Foundation
import UIKit

public extension ComposableExtension where Base: UIViewController {
    var bindingLifetime: Lifetime {
        get { associatedObject(base: base, key: &lifetimeKey, initialiser: Lifetime.init) }
        set { associateObject(base: base, key: &lifetimeKey, value: newValue) }
    }
}

extension UIViewController: ComposableExtensionsProvider {}

private var lifetimeKey: UInt8 = 0

private func associatedObject<ValueType: AnyObject>(
    base: AnyObject,
    key: UnsafePointer<UInt8>,
    initialiser: () -> ValueType
) -> ValueType {
    if let associated = objc_getAssociatedObject(base, key)
        as? ValueType { return associated }
    let associated = initialiser()
    objc_setAssociatedObject(
        base,
        key,
        associated,
        .OBJC_ASSOCIATION_RETAIN
    )
    return associated
}

private func associateObject<ValueType: AnyObject>(
    base: AnyObject,
    key: UnsafePointer<UInt8>,
    value: ValueType
) {
    objc_setAssociatedObject(
        base,
        key,
        value,
        .OBJC_ASSOCIATION_RETAIN
    )
}
