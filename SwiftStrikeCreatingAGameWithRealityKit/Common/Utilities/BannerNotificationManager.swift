/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Abstract out the nitty gritty of banner management from client code.
*/

import Foundation
import RealityKit

enum BannerUsage {
    case notification
    case instruction
}

class BannerNotificationManager {

    class Banner {
        let view: BannerView
        var timer: Timer?

        init(view: BannerView) {
            self.view = view
        }
    }

    private var notificationBanner: Banner
    private var instructionBanner: Banner

    private var hidden: Bool = false
    var isHidden: Bool {
        get { return hidden }
        set {
            notificationBanner.view.isHidden = newValue
            instructionBanner.view.isHidden = newValue
            hidden = newValue
        }
    }

    init(notificationBannerView: BannerView, instructionBannerView: BannerView) {
        self.notificationBanner = Banner(view: notificationBannerView)
        self.instructionBanner = Banner(view: instructionBannerView)
    }

    func setBanner(text: String, for usage: BannerUsage, animated: Bool = true, persistent: Bool = true) {
        guard !hidden else { return }

        let banner: Banner
        switch usage {
        case .notification:
            banner = notificationBanner
        case .instruction:
            banner = instructionBanner
        }
        banner.view.setText(text, animated: animated)
        banner.timer?.invalidate()
        if !persistent {
            let delay = 2.0
            banner.timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                banner.view.setText(nil, animated: true)
            }
        }
    }

    func clearBanner(for usage: BannerUsage, animated: Bool = true) {
        guard !hidden else { return }

        switch usage {
        case .notification:
            notificationBanner.view.setText(nil, animated: animated)
        case .instruction:
            instructionBanner.view.setText(nil, animated: animated)
        }
    }

    var previousInstruction: String?

    func setInstruction(text: String, animated: Bool = true, push: Bool = false) {
        if push {
            previousInstruction = instructionBanner.view.text
        }
        setBanner(text: text, for: .instruction, animated: animated)
    }

    func clearInstruction(animated: Bool = true, pop: Bool = false) {
        if pop, let previousInstruction = previousInstruction {
            setBanner(text: previousInstruction, for: .instruction)
        } else {
            clearBanner(for: .instruction, animated: animated)
        }
    }

    func updateInstructionBanner(input: String?) {
        DispatchQueue.main.async {
            if let input = input {
                self.setBanner(text: input, for: .instruction)
            } else {
                self.clearBanner(for: .instruction)
            }
        }
    }
}
