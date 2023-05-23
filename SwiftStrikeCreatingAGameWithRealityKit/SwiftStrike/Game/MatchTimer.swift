/*
See LICENSE folder for this sample’s licensing information.

Abstract:
MatchObserver
*/

import Foundation
import os.log

class MatchTimer {
    private var lastNow = Date()
    private var maxTime: Double = 0.0
    private var timeLeft: Double = 0.0
    private var timeRange = CountdownTime()
    private var timeRangeUpdated = false

    var maxSeconds: Double { return timeRange.duration }
    var secondsLeft: Double { return timeLeft }

    var range: CountdownTime { timeRangeUpdated = false; return timeRange }
    var rangeChanged: Bool { return timeRangeUpdated }

    ///
    /// start() is called to initialize count down timer max value
    /// and get "now" for future time deltas
    ///
    func start(withSeconds: Int) {
        maxTime = Double(withSeconds)
        timeLeft = maxTime
        lastNow = Date()
        timeRange = CountdownTime(start: lastNow, duration: maxTime)
        timeRangeUpdated = true
    }

    ///
    /// tick() should be called frequently to update timer as well as
    /// animation of progress ring and low timer bounce
    /// returns true if clock is still running, false if count down has reached 0
    ///
    let minimumTick = 1.0 / 60.0   // minimum time before doing update work
    func tick() -> Bool {
        guard timeLeft > 0.0 else { return false }

        let now = Date()
        let deltaNow = now.timeIntervalSince(lastNow)

        // we don't really care about real-time
        // we want to tick the second counter once
        // every time the real-time delta is greater
        // than one second
        // (this also helps during debugging with
        // breakpoints)
        // but we also need to get < 1 sec resolution
        // updates for animation
        let deltaSec: Double = min(deltaNow, 1.0)

        // we don't want to update faster than is required
        // for smooth progress ring, and other animation
        if deltaSec >= minimumTick {
            #if DEBUG
            let oldSec = Int(timeLeft)
            #endif

            timeLeft -= deltaSec
            if timeLeft < 0.0 {
                timeLeft = 0.0
            }
            lastNow = now

            // if we have performance problems or a programmer
            // has added breakpoints and is debugging,
            // deltaNow will be greater than deltaSec
            // and we will have divergence of the actual
            // start and end times for the timer
            // we need to stay in sync across the network
            // so it is required that we update the timer
            // range and mark it so
            let newEndTime = lastNow.addingTimeInterval(timeLeft)
            if newEndTime != timeRange.end {
                #if DEBUG
                let deltaTime = newEndTime.timeIntervalSince(timeRange.end)
                #endif
                timeRange = CountdownTime(end: newEndTime, duration: maxSeconds)
                timeRangeUpdated = true
                #if DEBUG
                os_log(.default, log: GameLog.general, "MatchTimer tick() - time range shifted forward by %s", "\(deltaTime)")
                #endif
            }

            #if DEBUG
            let newSec = Int(timeLeft)
            if oldSec != newSec {
                os_log(.default, log: GameLog.general, "MatchTimer tick() - %s sec left (delta %s)", "\(newSec)", "\(deltaNow)")
            }
            #endif
        }
        return timeLeft > 0.0
    }

}
