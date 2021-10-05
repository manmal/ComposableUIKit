import Combine
import CombineProperty
import ComposableArchitecture
import Foundation
import UIKit

public extension NavSegment {
    init<State: Equatable, Action>(
        id: SegmentID,
        store: Store<State, Action>,
        @ViewControllersBuilder<State, Action> viewControllers: (Store<State, Action>)
            -> Property<[UIViewController]>,
        @NextBuilder<State, Action> nextSegment: (Store<State, Action>) -> Property<Self?>?
    ) {
        self.init(
            id: id,
            viewControllers: viewControllers(store),
            next: nextSegment(store)
        )
    }
}

public extension NavSegment {
    @resultBuilder
    struct NextBuilder<State: Equatable, Action> {
        public static func buildBlock(_ properties: Property<NavSegment?>?...)
            -> Property<NavSegment?>? {
            let compacted = properties.compactMap { $0 }
            guard !compacted.isEmpty else { return nil }
            return compacted
                .combineLatest(emptySentinel: nil)
                .map { $0.compactMap { $0 }.first }
        }

        public static func buildExpression(_: Void) -> Property<NavSegment<SegmentID>?>? {
            nil
        }

        public static func buildExpression<LocalState, LocalAction>(
            _ next: Next<State, Action, LocalState, LocalAction>
        ) -> Property<NavSegment<SegmentID>?> {
            let subject = CurrentValueSubject<Store<LocalState, LocalAction>?, Never>(nil)
            let cancellable = next
                .store
                .scope(state: next.toLocalState, action: next.fromLocalAction)
                .ifLet(
                    then: { store in
                        subject.value = store
                    },
                    else: {
                        subject.value = nil
                    }
                )

            return Property<Store<LocalState, LocalAction>?>(subject)
            .map { store in
                _ = cancellable
                return store.map { next.make($0) }
            }
        }
    }

    struct Next<State, Action, LocalState, LocalAction> {
        let store: Store<State, Action>
        let toLocalState: (State) -> LocalState?
        let fromLocalAction: (LocalAction) -> Action
        let make: (Store<LocalState, LocalAction>) -> NavSegment
        
        public init(
            store: Store<State, Action>,
            toLocalState: @escaping (State) -> LocalState?,
            fromLocalAction: @escaping (LocalAction) -> Action,
            make: @escaping (Store<LocalState, LocalAction>) -> NavSegment<SegmentID>
        ) {
            self.store = store
            self.toLocalState = toLocalState
            self.fromLocalAction = fromLocalAction
            self.make = make
        }
    }
}

public extension NavSegment {
    @resultBuilder
    struct ViewControllersBuilder<State: Equatable, Action> {
        public static func buildBlock(_ properties: Property<UIViewController?>?...)
            -> Property<[UIViewController]> {
            let compacted = properties.compactMap { $0 }
            guard !compacted.isEmpty else { return .init([]) }
            return compacted
                .combineLatest(emptySentinel: nil)
                .map { $0.compactMap { $0 } }
        }

        public static func buildExpression<LocalState: Equatable, LocalAction>(
            _ vc: ViewController<State, Action, LocalState, LocalAction>
        ) -> Property<UIViewController?>? {
            vc.store
                .makeViewControllerProperty(
                    state: vc.toLocalState,
                    action: vc.fromLocalAction,
                    showIf: vc.showIf,
                    makeViewController: vc.make
                )
        }

        public static func buildExpression(_: Void) -> Property<UIViewController?>? {
            nil
        }
    }

    struct ViewController<State, Action, LocalState, LocalAction> {
        let store: Store<State, Action>
        let toLocalState: (State) -> LocalState?
        let fromLocalAction: (LocalAction) -> Action
        let showIf: (State) -> Bool
        let make: (ViewStore<LocalState, LocalAction>) -> UIViewController
        
        public init(
            store: Store<State, Action>,
            toLocalState: @escaping (State) -> LocalState?,
            fromLocalAction: @escaping (LocalAction) -> Action,
            showIf: @escaping (State) -> Bool,
            make: @escaping (ViewStore<LocalState, LocalAction>) -> UIViewController
        ) {
            self.store = store
            self.toLocalState = toLocalState
            self.fromLocalAction = fromLocalAction
            self.showIf = showIf
            self.make = make
        }
    }
}

public extension NavSegment.ViewController {
    init(
        store: Store<State, Action>,
        state toLocalState: @escaping (State) -> LocalState?,
        action fromLocalAction: @escaping (LocalAction) -> Action,
        showIf: @escaping (State) -> Bool = { _ in true },
        make: @escaping (ViewStore<LocalState, LocalAction>) -> UIViewController
    ) {
        self.init(
            store: store,
            toLocalState: toLocalState,
            fromLocalAction: fromLocalAction,
            showIf: showIf,
            make: make
        )
    }
}

public extension NavSegment.ViewController where State == LocalState, Action == LocalAction {
    init(
        store: Store<State, Action>,
        showIf: @escaping (State) -> Bool = { _ in true },
        make: @escaping (ViewStore<State, Action>) -> UIViewController
    ) {
        self.init(
            store: store,
            toLocalState: { $0 },
            fromLocalAction: { $0 },
            showIf: showIf,
            make: make
        )
    }
}

public extension Store where State: Equatable {
    func scopedProperty<LocalState, LocalAction>(
        state toLocalState: @escaping (State) -> LocalState?,
        action fromLocalAction: @escaping (LocalAction) -> Action
    ) -> Property<Store<LocalState, LocalAction>?> {
        let subject = CurrentValueSubject<Store<LocalState, LocalAction>?, Never>(nil)
        let cancellable =
            scope(
                state: toLocalState,
                action: fromLocalAction
            )
            .ifLet(
                then: { store in
                    subject.value = store
                },
                else: {
                    subject.value = nil
                }
            )
        return .init(subject)
            .map {
                _ = cancellable
                return $0
            }
    }

    func makeNavSegmentProperty<Wrapped, SegmentID: Equatable & Comparable>(
        makeSegmentWithStore: @escaping MakeSegmentWithStore<Wrapped, SegmentID>
    ) -> Property<NavSegment<SegmentID>?> where State == Wrapped? {
        let subject = CurrentValueSubject<NavSegment<SegmentID>?, Never>(nil)
        let cancellable = ifLet { store in
            subject.value = makeSegmentWithStore(store)
        } else: { [subject] in
            subject.value = nil
        }
        return .init(subject)
            .map {
                _ = cancellable
                return $0
            }
    }

    func makeViewControllerProperty<
        ViewController: UIViewController,
        LocalState: Equatable,
        LocalAction
    >(
        state toLocalState: @escaping (State) -> LocalState?,
        action fromLocalAction: @escaping (LocalAction) -> Action,
        showIf: ((State) -> Bool)?,
        makeViewController: @escaping (ViewStore<LocalState, LocalAction>) -> ViewController
    ) -> Property<ViewController?> {
        let show: Property<Bool> = {
            guard let showIf = showIf else { return .init(true) }
            let viewStore = ViewStore(self)
            return Property(
                initial: showIf(viewStore.state),
                then: viewStore.publisher.map(showIf).removeDuplicates()
            )
        }()
        return show
            .map { [weak self] show -> Property<ViewController?> in
                guard
                    let self = self,
                    show
                else { return .init(nil) }
                return self
                    .scopedProperty(
                        state: toLocalState,
                        action: fromLocalAction
                    )
                    .map { $0.map { makeViewController(ViewStore($0)) } }
            }
            .switchToLatest()
    }

    typealias MakeSegmentWithStore<Value, SegmentID: Equatable & Comparable> = (
        Store<Value, Action>
    ) -> NavSegment<SegmentID>
}
