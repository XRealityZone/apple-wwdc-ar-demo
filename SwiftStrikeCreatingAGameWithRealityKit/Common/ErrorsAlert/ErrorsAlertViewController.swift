/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Errors Alert View Controller
*/

import os.log
import UIKit

class ErrorsAlertView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
}

class ErrorsAlertViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var errorsLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton!

    @IBAction func dismissButtonDown(_ sender: UIButton) {
        let localCompletion = completion
        self.dismiss(animated: true) { localCompletion?() }
    }

    private var titleString: String
    private var linesStrings: [String]
    private var dismissalString: String?
    private var completion: (() -> Void)?

    required init?(coder aDecoder: NSCoder) {
        titleString = ""
        linesStrings = []
        dismissalString = nil
        super.init(coder: aDecoder)
    }

    static func createInstanceFromStoryboard(title: String,
                                             lines: [String],
                                             dismissal: String? = nil,
                                             completion: (() -> Void)? = nil
    ) -> ErrorsAlertViewController {
        let storyboard = UIStoryboard(name: "ErrorsAlertViewController", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "errorsAlert")
        guard let errorAlert = viewController as? ErrorsAlertViewController else {
            fatalError("missing 'errorAlert' UIViewController in storyboard 'ErrorAlertViewController' is not ErrorAlertViewController")
        }

        errorAlert.modalPresentationStyle = .overFullScreen
        errorAlert.modalTransitionStyle = .coverVertical

        errorAlert.titleString = title
        errorAlert.linesStrings = lines
        errorAlert.dismissalString = dismissal
        errorAlert.completion = completion
        return errorAlert
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        os_log(.error, log: GameLog.general, "ErrorsAlert: title: %s", "\(titleString)")
        linesStrings.forEach { line in
            os_log(.error, log: GameLog.general, "ErrorsAlert: line: %s", "\(line)")
        }

        titleLabel?.text = titleString
        errorsLabel?.text = linesStrings.joined(separator: "\n")
        if let label = dismissalString {
            dismissButton?.setTitle(label, for: .normal)
        }
    }

}
