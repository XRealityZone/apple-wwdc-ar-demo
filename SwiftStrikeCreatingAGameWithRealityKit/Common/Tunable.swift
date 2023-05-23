/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Tunable
*/

class TunableScalar<ScalarType> where ScalarType: Comparable {

    let label: String
    let minimum: ScalarType
    let maximum: ScalarType
    private let defaultValue: ScalarType
    let step: ScalarType?

    var value: ScalarType

    init(_ label: String, min: ScalarType, max: ScalarType, def: ScalarType, step: ScalarType? = nil) {
        self.label = label
        self.minimum = min
        self.maximum = max
        self.defaultValue = def
        self.step = step

        self.value = def
    }

}

class TunableBool {

    let label: String
    private let defaultValue: Bool

    var value: Bool

    init(_ label: String, def: Bool) {
        self.label = label
        self.defaultValue = def

        self.value = def
    }

}
