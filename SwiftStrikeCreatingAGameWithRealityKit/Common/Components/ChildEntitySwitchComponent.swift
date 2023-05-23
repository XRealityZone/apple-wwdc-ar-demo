/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ChildEntitySwitchComponent
*/

import os.log
import RealityKit

///
/// ChildEntitySwitchComponent is used to swap between several different named
/// child entities.  This works as basically a multiple-choice option, where only one of the
/// named child entities will be visible and enabled at a time.

struct ChildEntitySwitchComponent: Component {
    /// Holds the name of which Entity is visible and enabled. When this value
    /// changes, the child entity with the same name will be enabled, while
    /// all other child entities in `childEntityNamesList` will be disabled.
    fileprivate var currentChildEntityName: String = ""

    /// This is holds the names of all child entities that can be swapped between. Only
    /// the entitiy identified by `currentChildEntityName` will be visible and enabled.
    /// All other child entities listed here will be disabled.
    var childEntityNamesList: [String] = []
}

extension ChildEntitySwitchComponent: Codable {}

protocol HasChildEntitySwitch where Self: Entity {}

extension HasChildEntitySwitch {

    var childEntitySwitch: ChildEntitySwitchComponent {
        get { return components[ChildEntitySwitchComponent.self] ?? ChildEntitySwitchComponent() }
        set { components[ChildEntitySwitchComponent.self] = newValue }
    }

    /// enableChildEntityNamed() only acts when the state is changed to
    /// reduce the impact of enabling/disabling ModelEntities.
    /// Also, if the name is not found, then no work is done
    func enableChildrenEntities(named name: String) {
        guard !childEntitySwitch.childEntityNamesList.isEmpty else {
            fatalError("ChildEntitySwitchComponent not 'configure'd.")
        }
        guard childEntitySwitch.childEntityNamesList.contains(name),
        name != childEntitySwitch.currentChildEntityName else { return }

        // search and enable the child entity if found
        var success = false
        let maxDepth = 3
        forEachInHierarchy { (child, depth) in
            if depth <= maxDepth && child.name == name {
                child.isEnabled = true
                os_log(.default, log: GameLog.general, "Entity %s, Child %s - enabled", "\(self.name)", "\(child.name)")
                success = true
            }
        }

        // make sure we found and enabled an Entity before
        // we disable all the others
        if success {
            forEachInHierarchy { (child, depth) in
                if depth <= maxDepth && child.name != name && childEntitySwitch.childEntityNamesList.contains(child.name) {
                    child.isEnabled = false
                    os_log(.default, log: GameLog.general, "Entity %s, Child %s - disabled", "\(self.name)", "\(child.name)")
                }
            }
            childEntitySwitch.currentChildEntityName = name
        }
    }

}
