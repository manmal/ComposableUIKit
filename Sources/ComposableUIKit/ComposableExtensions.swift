import Foundation

public protocol ComposableExtensionsProvider {}

public extension ComposableExtensionsProvider {
    var composable: ComposableExtension<Self> {
        get { .init(self) }
        nonmutating set {}
    }

    static var composable: ComposableExtension<Self>.Type {
        ComposableExtension<Self>.self
    }
}

public struct ComposableExtension<Base> {
    public var base: Base
    fileprivate init(_ base: Base) {
        self.base = base
    }
}
