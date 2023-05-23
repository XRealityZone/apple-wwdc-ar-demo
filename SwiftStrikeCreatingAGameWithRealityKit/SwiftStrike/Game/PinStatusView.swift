/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PinStatusView
*/

import os.log
import UIKit

@IBDesignable
class PinStatusView: UIView {
    //
    // Properties for IB
    //
    @IBInspectable var pinUpImage: UIImage?
    @IBInspectable var pinDownImage: UIImage?
    @IBInspectable var pinUpColor: UIColor = .white
    @IBInspectable var pinDownColor: UIColor = .darkGray
    @IBInspectable var viewBackgroundColor: UIColor = .clear
    @IBInspectable var rows: Int = 4
    @IBInspectable var horizontalPinSpacePad: CGFloat = 0.20
    @IBInspectable var verticalPinSpacePad: CGFloat = 0.10

    @IBInspectable var enableDebugMode: Bool = false

    //
    // External Properties
    //
    var pinStatusUpImage: UIImage? {
        get { return pinUpImage }
        set {
            pinUpImage = newValue
            setNeedsDisplay()
        }
    }

    var pinStatusDownImage: UIImage? {
        get { return pinDownImage }
        set {
            pinDownImage = newValue
            setNeedsDisplay()
        }
    }

    var enableDebug: Bool {
        get { return enableDebugMode }
        set {
            let changed = enableDebugMode != newValue
            enableDebugMode = newValue
            if changed {
                updateDebugTapGestureRecognizers()
                setNeedsDisplay()
            }
        }
    }

    var displayedTeam: Team {
        get { return team }
        set {
            let changed = team != newValue
            team = newValue
            if enableDebug && changed {
                setNeedsDisplay()
            }
        }
    }

    //
    // External API
    //
    func pinStatus(_ id: Int, upState: Bool) {
        if let pin = pins.first(where: { $0.id == id }) {
            pin.upState = upState
            setNeedsDisplay()
        }
    }

    func pinsReset() {
        for pin in pins {
            pinStatus(pin.id, upState: true)
        }
    }

    //
    // Internal
    //
    var lastDrawRect: CGRect = CGRect()
    class Pin {
        static var uniquePinId: Int = 1

        init(id: Int, rect: CGRect, upState: Bool) {
            self.id = id
            self.rect = rect
            self.upState = upState
        }

        init(_ id: Int = 0) {
            var newId = id
            if newId == 0 {
                newId = Pin.uniquePinId
                Pin.uniquePinId += 1
            }
            self.id = newId
            self.rect = CGRect()
            self.upState = true
        }

        var id: Int
        var rect: CGRect
        var upState: Bool
    }
    private var team: Team = .none
    private var pins: [Pin] = []
    private var pinsDirty: Bool = false

    private var singleTap: UITapGestureRecognizer?
    private var doubleTap: UITapGestureRecognizer?
    private var tripleTap: UITapGestureRecognizer?
    private func createDebugTapGestureRecognizers() {
        singleTap = UITapGestureRecognizer(target: self, action: #selector(didTap(recognizer:)))
        doubleTap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap(recognizer:)))
        doubleTap?.numberOfTapsRequired = 2
        tripleTap = UITapGestureRecognizer(target: self, action: #selector(didTripleTap(recognizer:)))
        tripleTap?.numberOfTapsRequired = 3
    }
    private func updateDebugTapGestureRecognizers() {
        if enableDebugMode {
            addGestureRecognizer(singleTap!)
            addGestureRecognizer(doubleTap!)
            addGestureRecognizer(tripleTap!)
        } else {
            removeGestureRecognizer(singleTap!)
            removeGestureRecognizer(doubleTap!)
            removeGestureRecognizer(tripleTap!)
        }
    }

    //
    // Init
    //
    private func setupView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        createDebugTapGestureRecognizers()
        updateDebugTapGestureRecognizers()
    }

    private func findPinByLocation(_ location: CGPoint) -> Pin? {
        for pin in pins {
            if pin.rect.contains(location) {
                return pin
            }
        }
        return nil
    }

    @objc
    private func didTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        if let pin = findPinByLocation(location) {
            pinStatus(pin.id, upState: pin.upState != true)
            os_log(.debug, log: GameLog.general, "TAP pin %s, is %s", "\(pin.id)", pin.upState ? "up" : "down")
        }
    }

    @objc
    private func didDoubleTap(recognizer: UITapGestureRecognizer) {
        for pin in pins {
            pinStatus(pin.id, upState: false)
        }
        os_log(.debug, log: GameLog.general, "DOUBLE_TAP")
    }

    @objc
    private func didTripleTap(recognizer: UITapGestureRecognizer) {
        pinsReset()
        os_log(.debug, log: GameLog.general, "TRIPLE_TAP")
    }

    // init from code
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    // init from xib or storyboard
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    //
    // Draw
    //
    private func placePins(_ frameRect: CGRect) {
        let gridHeight = CGFloat(Int(frameRect.height / CGFloat(rows)))
        let pinHeight = gridHeight * (1.0 - verticalPinSpacePad)
        let gridWidth = CGFloat(Int(frameRect.width / CGFloat(rows)))
        let pinWidth = gridWidth * (1.0 - horizontalPinSpacePad)
        // after this, use pinSize, NOT pinWidth or pinHeight,
        // we need a perfect square/circle for the image or circle
        let pinSize = min(pinWidth, pinHeight)
        let centerX = frameRect.width * 0.5
        // draw pins top to bottom (like upside down bowling pin layout)
        // such that 1 is at top, 7-10 are at the bottom right to left
        let firstPinRowY = (gridHeight - pinSize) * 0.5
        var rect = CGRect(x: centerX - (pinSize * 0.5), y: firstPinRowY, width: pinSize, height: pinSize)
        var pinIndex = 0
        for row in 1...rows {
            rect.origin.x = (centerX + (CGFloat(row) * gridWidth * 0.5)) - gridWidth + ((gridWidth - pinSize) * 0.5)
            for _ in 1...row {
                // lazy creation of array of pins
                if pins.count <= pinIndex {
                    pins.append(Pin(id: pinIndex + 1, rect: rect, upState: true))
                } else {
                    let pin = pins[pinIndex]
                    pin.rect = rect
                }
                pinIndex += 1
                rect.origin.x -= gridWidth
            }
            rect.origin.y += gridHeight
        }
    }

    private func fillRect(_ rect: CGRect, fillColor: UIColor) {
        fillColor.setFill()
        let backgroundPath = UIBezierPath(rect: rect)
        backgroundPath.fill()
    }

    private func drawPin(_ pin: Pin) {
        let pinImage: UIImage? = pin.upState ? pinUpImage : pinDownImage
        if let image = pinImage {
            image.draw(in: pin.rect)
            return
        }
        let center = pin.rect.center
        let radius: CGFloat = min((pin.rect.size.height * 0.5), (pin.rect.size.width * 0.5))
        let radiansPerCircle: Float = 2.0 * .pi
        let backgroundPath = UIBezierPath()
        let pinColor: UIColor
        if pin.upState {
            pinColor = pinUpColor
        } else {
            pinColor = pinDownColor
        }
        pinColor.setFill()
        backgroundPath.move(to: center)
        backgroundPath.addArc(withCenter: center, radius: radius, startAngle: 0.0, endAngle: CGFloat(radiansPerCircle), clockwise: true)
        backgroundPath.close()
        backgroundPath.fill()
    }

    override func draw(_ frameRect: CGRect) {
        super.draw(frameRect)

        let drawRect = frameRect

        if lastDrawRect != drawRect {
            placePins(drawRect)
            lastDrawRect = drawRect
        }

        // draw view background
        fillRect(drawRect, fillColor: viewBackgroundColor)

        for pin in pins {
            drawPin(pin)
        }

        let teamFontSize: CGFloat = 18.0
        let teamFontWeight = UIFont.Weight.medium
        let teamFontColor = UIColor.white
        let teamFontBackgroundColor = UIColor(displayP3Red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)

        if enableDebug {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let font = UIFont.systemFont(ofSize: teamFontSize, weight: teamFontWeight)
            let attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                             .foregroundColor: teamFontColor,
                                                             .paragraphStyle: paragraphStyle]
            let nsString = NSAttributedString(string: "\(team)", attributes: attributes)
            let size = nsString.size()
            let center = drawRect.center
            let textRect = CGRect(x: center.x - (size.width * 0.5), y: center.y - (size.height * 0.5),
                          width: size.width, height: size.height)
            textRect.inset(by: UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
            fillRect(textRect, fillColor: teamFontBackgroundColor)
            textRect.inset(by: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
            nsString.draw(in: textRect)
        }
    }

    func uprightStateChanged(team: Team, mask: UprightMask) {
        // this check and set is only required for the force start cheat
        guard displayedTeam != .none else {
//            assertionFailure("Error! no displayedTeam set.")
            return
        }
        if team == displayedTeam {
            for (index, pin) in pins.enumerated() {
                pin.upState = !mask[index]
            }
            setNeedsDisplay()
        }
    }
}
