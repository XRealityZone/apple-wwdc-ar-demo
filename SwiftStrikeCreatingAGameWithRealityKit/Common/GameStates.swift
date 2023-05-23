/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Match
*/

import Combine
import os.log
import RealityKit

/// GameStates is a state machine.
/// It consumes Input events and generates Output events.
/// Each State provides rules for mapping inputs to outputs.
/// A State can also provide a new state which should handle further Input events.
class GameStates<Input, Output> {
    
    /// Defines output output of the state transform method
    struct StateOutput {
        
        /// event to produce as output of state machine
        let outputEvent: Output?
        
        /// next state to transition to if needed
        let nextState: State?
        
        init(outputEvent: Output? = nil,
             nextState: State? = nil) {
            self.outputEvent = outputEvent
            self.nextState = nextState
        }
    }
    
    /// defines state for state machine
    struct State {
        /// here for easier debugging
        var name: String
        
        /// Defines current Input event handler logic
        let transform: (Input) -> StateOutput?
        
        init(_ name: String, _ transform: @escaping (Input) -> StateOutput?) {
            self.name = name
            self.transform = transform
        }
    }

    init() {}
    var current: State?
    private func swap(_ rule: State) {
        os_log(.default, log: GameLog.gameState, "Changing game state from %s -> %s", String(describing: current), String(describing: rule))
        current = rule
    }
    
    // To be called on every Input event and produce either output event or nil based on current state logic defined in State.transform
    // In case there is output event, method will also look for next state and swap state machine to it
    func handle(_ input: Input) -> Output? {
        guard let current = current else { fatalError("Set initial state before initializing handleGameEvents with rules") }
        guard let output = current.transform(input) else { return nil }
        defer {
            if let nextRule = output.nextState {
                swap(nextRule)
            }
        }
        return output.outputEvent
    }

    func initial(_ initial: State) {
        current = initial
    }

}

extension Publisher {
    // Returns a Publisher which:
    // * applies the rules in the given GameStates, weeding out nils
    // * shares a single subscription to the result among several downstream subscribers
    func handleGameEvents<Output>(_ rules: GameStates<Self.Output, Output>)
        -> AnyPublisher<Output, Failure> {
            return self.compactMap(rules.handle)
                .share()
                .eraseToAnyPublisher()
    }
}
