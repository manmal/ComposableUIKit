import Foundation
import Combine
import UIKit

@objc
class NavigationControllerDelegate: NSObject, UINavigationControllerDelegate {
    typealias DidShowViewController = (UINavigationController, UIViewController, animated: Bool)

    var didShowViewController: AnyPublisher<DidShowViewController, Never> {
        didShowViewControllerSubject.eraseToAnyPublisher()
    }

    private let didShowViewControllerSubject = PassthroughSubject<DidShowViewController, Never>()

    @objc public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        didShowViewControllerSubject.send(
            (navigationController, viewController, animated)
        )
    }
}
