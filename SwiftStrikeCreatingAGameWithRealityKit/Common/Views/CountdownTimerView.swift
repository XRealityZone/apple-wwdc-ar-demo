/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helpers for Bundle
*/

import os.log
import UIKit

struct CountdownTime: Equatable, Codable {

    var end: Date
    var duration: TimeInterval

    init() {
        self.end = Date()
        self.duration = 0.0
    }

    init(start: Date, end: Date) {
        guard end >= start else {
            self.end = Date()
            self.duration = 0.0
            return
        }
        self.end = end
        self.duration = end.timeIntervalSince(start)
    }

    init(start: Date, duration: TimeInterval) {
        guard duration >= 0.0 else {
            self.end = Date()
            self.duration = 0.0
            return
        }
        self.end = start + duration
        self.duration = duration
    }

    init(end: Date, duration: TimeInterval) {
        guard duration >= 0.0 else {
            self.end = Date()
            self.duration = 0.0
            return
        }
        self.end = end
        self.duration = duration
    }

}

@IBDesignable
final class CountdownTimerView: UIView {
    //
    // Properties exposed to IB...
    //
    @IBInspectable var viewInset: Int = 2
    @IBInspectable var ringEmptyThickness: Int = 3
    @IBInspectable var ringFillThickness: Int = 3

    @IBInspectable var viewBackgroundColor: UIColor = .clear

    @IBInspectable var fontSize: CGFloat = 16.0
    @IBInspectable var fontBackgroundColor: UIColor = .clear
    @IBInspectable var fontColor: UIColor = .white
    @IBInspectable var fontShadowColor: UIColor = UIColor(#colorLiteral(red: 0.7175212502, green: 0.7175212502, blue: 0.7175212502, alpha: 0.3523877641))
    @IBInspectable var fontShadowOffsetWidth: CGFloat = 0.0
    @IBInspectable var fontShadowOffsetHeight: CGFloat = 1.0
    @IBInspectable var fontShadowBlur: CGFloat = 1.0

    @IBInspectable var ringEmptyColor: UIColor = UIColor(#colorLiteral(red: 0.7175212502, green: 0.7175212502, blue: 0.7175212502, alpha: 0.3523877641))
    @IBInspectable var ringFillColor: UIColor = .white

    @IBInspectable var enableDebugMode: Bool = false

    //
    // External Properties
    //
    var enableDebug: Bool {
        get { return enableDebugMode }
        set {
            if enableDebugMode != newValue {
                enableDebugMode = newValue
                updateDebugTapGestureRecognizers()
            }
        }
    }

    //
    // External APIs
    //
    func setRange(_ newRange: CountdownTime) {
        guard newRange != range else { return }
        range = newRange
        updateTimeFormat()
        secondsLeft = range.end.timeIntervalSinceNow.clamped(lowerBound: 0.0, upperBound: range.duration)
        updateProgress()
        os_log(.debug, log: GameLog.general, "CountdownTimerView - setRange()")
    }

    func tick() {
        guard range.duration != 0.0 else { return }
        secondsLeft = range.end.timeIntervalSinceNow.clamped(lowerBound: 0.0, upperBound: range.duration)
        updateProgress()
    }

    //
    // Internal
    //
    private var range: CountdownTime = CountdownTime()
    private var secondsLeft: Double = 10.0

    private var font: UIFont = .systemFont(ofSize: 12.0, weight: .medium)
    private var progress: Float = 0.0   // 0-1, 0 is start time/empty, 1 is out of time/full
    private var timeFormat: String = ""

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

    private func updateProgress() {
        let current = secondsLeft.clamped(lowerBound: 0, upperBound: range.duration)
        progress = Float(current / range.duration)
        // progress 0-1, 1 is start time/full, 0 is out of time/empty
        progress = progress.clamped(lowerBound: 0.0, upperBound: 1.0)
        setNeedsDisplay()
    }

    private func updateTimeFormat() {
        timeFormat = ""
        if range.duration >= (10 * 60) {
            timeFormat += "0"
        } else if range.duration >= 60 {
            timeFormat += "0"
        }
        timeFormat += ":00"
        setNeedsDisplay()
    }
    
    private func rectForNSAttributedString(_ drawRect: CGRect, nsAttributedString: NSAttributedString) -> CGRect {
        let size = nsAttributedString.size()
        let center = drawRect.center
        return CGRect(x: center.x - (size.width * 0.5), y: center.y - (size.height * 0.5),
                      width: size.width, height: size.height)
    }
    
    //
    // Init
    //
    private func setupView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        font = .systemFont(ofSize: fontSize, weight: .medium)

        updateTimeFormat()  // force time format setup
        updateProgress()

        createDebugTapGestureRecognizers()
        updateDebugTapGestureRecognizers()
    }

    @objc
    private func didTap(recognizer: UITapGestureRecognizer) {
        //let location = recognizer.location(in: self)
        secondsLeft = max(0, secondsLeft - 1)
        updateProgress()
        os_log(.debug, log: GameLog.general, "TAP")
    }

    @objc
    private func didDoubleTap(recognizer: UITapGestureRecognizer) {
        //let location = recognizer.location(in: self)
        secondsLeft = max(0, secondsLeft - 10)
        updateProgress()
        os_log(.debug, log: GameLog.general, "DOUBLE_TAP")
    }

    @objc
    private func didTripleTap(recognizer: UITapGestureRecognizer) {
        //let location = recognizer.location(in: self)
        secondsLeft = range.duration
        updateProgress()
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
    private func fillRect(_ rect: CGRect, fillColor: UIColor) {
        fillColor.setFill()
        let backgroundPath = UIBezierPath(rect: rect)
        backgroundPath.fill()
    }

    private func drawPercentageArc(_ rect: CGRect, portion: Float, strokeColor: UIColor, thickness: Int) {
        guard portion > 0.0 else { return }

        let cgThickness = CGFloat(thickness)
        let center = rect.center
        let radius: CGFloat = min((rect.size.height * 0.5), (rect.size.width * 0.5)) - (cgThickness * CGFloat(0.5))
        let radiansPerCircle: Float = 2.0 * .pi
        let start: Float = radiansPerCircle * 0.75
        let clampedPortion = portion.clamped(lowerBound: 0.0, upperBound: 1.0)
        var end: Float = start + (radiansPerCircle * clampedPortion)
        // wrap end
        if end > radiansPerCircle { end = end - radiansPerCircle }
        strokeColor.setStroke()
        // create a pie chart style fill of a ring
        let backgroundPath: UIBezierPath
        if portion < 1.0 {
            backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: CGFloat(start), endAngle: CGFloat(end), clockwise: true)
        } else {
            backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0.0, endAngle: CGFloat(radiansPerCircle), clockwise: true)
        }
        backgroundPath.lineWidth = cgThickness
        backgroundPath.stroke()
    }

    private func drawTime(_ drawRect: CGRect) {
        let minutes = Int(secondsLeft / 60)
        let seconds = Int(secondsLeft.truncatingRemainder(dividingBy: 60))
        let secondTens = seconds / 10
        let secondOnes = seconds % 10
        var timeString: String = ""
        if range.duration >= (10 * 60) {
            let minuteTens = minutes / 10
            timeString += "\(minuteTens)"
        }
        if range.duration >= 60 {
            let minuteOnes = minutes % 10
            timeString += "\(minuteOnes)"
        }
        timeString += ":\(secondTens)\(secondOnes)"

        fillRect(drawRect, fillColor: fontBackgroundColor)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        var attributes: [NSAttributedString.Key: Any] = [.font: font,
                                                         .foregroundColor: fontColor,
                                                         .paragraphStyle: paragraphStyle]
        if fontShadowOffsetWidth != 0.0 || fontShadowOffsetHeight != 0.0 || fontShadowBlur != 0.0 {
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: fontShadowOffsetWidth, height: fontShadowOffsetHeight)
            shadow.shadowBlurRadius = fontShadowBlur
            shadow.shadowColor = fontShadowColor
            attributes[.shadow] = shadow
        }
        let nsTimeString = NSAttributedString(string: timeString, attributes: attributes)
        let rect = rectForNSAttributedString(drawRect, nsAttributedString: nsTimeString)
        nsTimeString.draw(in: rect)
    }

    override func draw(_ frameRect: CGRect) {
        super.draw(frameRect)

        var drawRect = frameRect

        // draw view background
        if viewBackgroundColor != .clear {
            fillRect(drawRect, fillColor: viewBackgroundColor)
        }

        // inset for ring from view
        drawRect = drawRect.insetBy(dx: CGFloat(viewInset), dy: CGFloat(viewInset))

        // draw full ring empty background
        drawPercentageArc(drawRect, portion: 1.0, strokeColor: ringEmptyColor, thickness: ringEmptyThickness)

        // draw portion of circle to represent fill progress
        drawPercentageArc(drawRect, portion: progress, strokeColor: ringFillColor, thickness: ringFillThickness)

        // inset rect for time digits
        let inset = CGFloat(max(ringEmptyThickness, ringFillThickness))
        drawRect = drawRect.insetBy(dx: inset, dy: inset)

        // draw time digits
        drawTime(drawRect)
    }

}
