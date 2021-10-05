import Combine
import CombineLifetime
import CombineProperty
import ComposableArchitecture
import Foundation
import UIKit

public extension ComposableExtension where Base: UINavigationController {
    func bind<State: Equatable, Action, SegmentID: Equatable & Comparable>(
        store: Store<State, Action>,
        makeRootSegment: @escaping (Store<State, Action>) -> NavSegment<SegmentID>,
        makeDismissAction: @escaping (SegmentID) -> Action?
    ) -> Base {
        bind(
            store: store,
            removeStoreDuplicates: ==,
            makeRootSegment: makeRootSegment,
            makeDismissAction: makeDismissAction
        )
    }
    
    func bind<State, Action, SegmentID: Equatable & Comparable>(
        store: Store<State, Action>,
        removeStoreDuplicates isDuplicate: @escaping (State, State) -> Bool,
        makeRootSegment: @escaping (Store<State, Action>) -> NavSegment<SegmentID>,
        makeDismissAction: @escaping (SegmentID) -> Action?
    ) -> Base {
        let lifetime = Lifetime()
        base.composable.bindingLifetime = lifetime 
        let viewStore = ViewStore(store, removeDuplicates: isDuplicate)
        
        let delegate = NavigationControllerDelegate()
        base.delegate = delegate
        
        // Retain until lifetime is released or cancelled
        lifetime.observeEnded {
            _ = delegate
        }
        
        let rootSegment = makeRootSegment(store)
        let navStates = rootSegment.makeAllStates()
        
        base.setViewControllers(
            navStates.value.flatMap(\.viewControllers),
            animated: false
        )
        
        lifetime += navStates
            .subsequentValues
            .debounce(for: 0.01, scheduler: DispatchQueue.main)
            .sink { [weak base] navStates in
                guard let navigationController = base else { return }
                navigationController.setViewControllers(
                    navStates.flatMap(\.viewControllers),
                    animated: true
                )
            }
        
        lifetime += delegate
            .didShowViewController
            .subscribe(on: DispatchQueue.main) // prevent UINavigationController glitch
            .sink { [weak base] _ in
                guard let navigationController = base else { return }
                removeSegmentsNoLongerInHierarchy(
                    navigationController: navigationController,
                    navStates: navStates,
                    viewStore: viewStore,
                    makeDismissAction: makeDismissAction
                )
            }
        
        return base
    }
}

private func removeSegmentsNoLongerInHierarchy<SegmentID, State, Action>(
    navigationController: UINavigationController,
    navStates: Property<[NavSegment<SegmentID>.State]>,
    viewStore: ViewStore<State, Action>,
    makeDismissAction: @escaping (SegmentID) -> Action?
) {
    var viewControllerIdx = 0
    var firstSegmentToRemove: SegmentID? = nil
    for (segmentIdx, navState) in navStates.value.enumerated() {
        for (idxInSegment, viewController) in navState.viewControllers.enumerated() {
            guard viewControllerIdx < navigationController.viewControllers.count else {
                firstSegmentToRemove = navState.id
                break
            }
            defer { viewControllerIdx += 1 }
            guard navigationController.viewControllers[viewControllerIdx] !== viewController else {
                break
            }

            if idxInSegment == 0 {
                // Remove this (and following) segment(s)
                firstSegmentToRemove = navState.id
            } else if segmentIdx < navStates.value.count - 1 {
                // Remove next (and following) segment(s)
                firstSegmentToRemove = navStates.value[segmentIdx + 1].id
            } else {
                assertionFailure("""
                It looks like a view controller was pushed
                from outside the NavigationCoordinator
                """)
            }
        }
        if firstSegmentToRemove != nil {
            break
        }
    }

    guard let firstSegmentToRemove = firstSegmentToRemove else { return }
    for navState in navStates.value.reversed() {
        guard
            navState.id == firstSegmentToRemove,
            let action = makeDismissAction(navState.id)
        else { continue }
        viewStore.send(action)
    }
}
