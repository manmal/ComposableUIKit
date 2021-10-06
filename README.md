# ComposableUIKit

The [ComposableArchitecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA) library provides a way of structuring Swift code with the Redux-pattern. It is highly optimized for SwiftUI, and works really well there. But UIKit is still highly relevant, and, as-is, it does not really lend itself to the Redux pattern. UIKit is not declarative like SwiftUI, but imperative. 

This Swift package provides tools that enable you to build a bridge between TCA and UIKit. 
Right now,  `UINavigationController` is supported.

## Usage

### `UINavigationController`

Provided you already have setup TCA with a State (e.g. `UnauthenticatedState`) and an Action (e.g. `UnauthenticatedAction`), you will need to add dismiss cases to your Action (e.g. `dismissLogin`) which sets the corresponding substate to `nil` (e.g. `state.login = nil`).

Create an enum (e.g. `UnauthenticatedNavSegmentID`), with one case for each sub-state (=segment) you want to display. It's best to have one segment for every sub-reducer.

Create a function that makes a `UINavigationController`, and an extension for the segment id enum like this: 

```swift
import ComposableArchitecture
import ComposableUIKit

func makeNavigationController(
    store: Store<UnauthenticatedState, UnauthenticatedAction>
) -> UINavigationController {
    UINavigationController()
        .composable
        .bind(
            store: unauthenticatedStore,
            makeRootSegment: { unauthenticatedStore in
                makeUnauthenticatedRootSegment(
                    store: unauthenticatedStore,
                    dependencies: dependencies.decorated
                )
            },
            makeDismissAction: \.dismissAction
        )
}

extension UnauthenticatedNavSegmentID {
    var dismissAction: UnauthenticatedAction? {
        switch self {
        case .root:
            return nil
        case .login:
            return .dismissLogin
        case .registration:
            return .dismissRegistration
        case .resetPassword:
            return .login(.dismissResetPassword)
        }
    }
}
```

The resulting `UINavigationController` can be used however you like, like in a modal or in a `UITabbar`. Just make sure to not call any methods on the navigation controller that change its view controller hierarchy - all manipulation must be done via the TCA state and the binding.

The binding on the navigation controller is active as long as the navigation controller exists, or until `navigationController.composable.bindingLifetime.cancel()` is called, or until `.composable.bind(...)` is called again.

The root segment could look like this:

```swift
private func makeUnauthenticatedRootSegment(
    store: Store<UnauthenticatedState, UnauthenticatedAction>
) -> NavSegment<UnauthenticatedNavSegmentID> {
    NavSegment(
        id: .root,
        store: store,
        viewControllers: { store in
            NavSegment.ViewController(
                store: store,
                make: UnauthenticatedRootViewController.init(viewStore:)
            )
        },
        nextSegment: { store in
            NavSegment.Next(
                store: store,
                toLocalState: \.login,
                fromLocalAction: UnauthenticatedAction.login,
                make: makeLoginSegment
            )
            NavSegment.Next(
                store: store,
                toLocalState: \.registration,
                fromLocalAction: UnauthenticatedAction.registration,
                make: makeRegistrationSegment
            )
        }
    )
}

```

As you can see, multiple `NavSegment.Next` elements can be added to each segment, even though **only one of them can be active**. If both are active (because `.login` and `registration` are both non-nil), then only the first (login) will be used.

The number of displayed viewControllers (`NavSegment.ViewController`) is not restricted, so each TCA sub-state can display as many view controllers as necessary. 

`NavSegment.ViewController.init()` lets you either use the current TCA state level (e.g. `UnauthenticatedState`), or a sub-state. Additionally, a `showIf` parameter lets you conditionally add/remove view controllers depending on the TCA state.  

`NavSegment`s can be arbitrarily deeply stacked, and they are created only if their parent segment is active. When the user dismisses a view controller (e.g. via back button, back swipe, or long-press on back button), then  `.dismissAction` will be used to notify the TCA `Store`, starting with the deepest-nested sub-reducer.

## Contact

🐦 Contact me via Twitter [@manuelmaly](https://twitter.com/manuelmaly)

## 0.1.0

- Added `UINavigationController` bridge (`UINavigationController.composable.bind(...)`)
