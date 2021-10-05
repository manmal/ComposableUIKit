import Combine
import CombineProperty
import Foundation
import UIKit

public struct NavSegment<SegmentID: Equatable & Comparable> {
    let id: SegmentID
    var viewControllers: Property<[UIViewController]>
    var next: Property<Self?>?
}

public extension NavSegment {
    struct State: Equatable {
        let id: SegmentID
        let viewControllers: [UIViewController]

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Returns `self`'s and all descendants' states.
    func makeAllStates() -> Property<[State]> {
        guard let next = next else {
            return viewControllers.map { [.init(id: id, viewControllers: $0)] }
        }
        return viewControllers
            .combineLatest(next)
            .map { viewControllers, next -> Property<[State]> in
                let currentState = [State(id: id, viewControllers: viewControllers)]
                guard let next = next else {
                    return .init(currentState)
                }
                return next.makeAllStates().map { currentState + $0 }
            }
            .switchToLatest()
    }
}
