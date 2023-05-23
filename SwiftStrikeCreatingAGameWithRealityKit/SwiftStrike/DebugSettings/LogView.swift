/*
See LICENSE folder for this sample’s licensing information.

Abstract:
LogView
*/

import UIKit

var logStorageMaxLines = 100
private var logStorage: [String] = []

struct LogViewOutputStream: TextOutputStream {
    mutating func write(_ string: String) {
        logStorage.append(string)
        NotificationCenter.default.post(name: Notification.Name.logViewLogMessageUpdate, object: string)
    }
}

var logViewStream = LogViewOutputStream() // global stream

extension Notification.Name {
    static let logViewLogMessageUpdate = Notification.Name("logViewLogMessageUpdate")
}

final class LogView: UIView {

    static func createAndShow(in view: UIView) {
        let logView = LogView()
        view.addSubview(logView)
        let screenBounds = UIScreen.main.bounds
        NSLayoutConstraint.activate([
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            logView.widthAnchor.constraint(equalToConstant: screenBounds.width - 40),
            logView.heightAnchor.constraint(equalToConstant: screenBounds.height / 3.0)
            ])
    }

    let textView = UITextView()
    var noteToken: NSObjectProtocol?

    var needsUpdate = false
    var showing: Bool = true {
        didSet {
            isHidden = !showing
            if !oldValue {
                loadFromStorage()
            }
        }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25)
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.cornerRadius = 10
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false

        addSubview(textView)
        let margins = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: -margins.left),
            topAnchor.constraint(equalTo: textView.topAnchor, constant: -margins.top),
            trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: margins.right),
            bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: margins.bottom)
            ])
        textView.font = UIFont.systemFont(ofSize: 12)
        textView.isEditable = false
        textView.isSelectable = false
        textView.textColor = #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1)
        textView.backgroundColor = .clear
        textView.isUserInteractionEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        noteToken = NotificationCenter.default.addObserver(forName: Notification.Name.logViewLogMessageUpdate,
                                                           object: nil, queue: .main) { note in
                                                            guard let string = note.object as? String else { return }
                                                            self.update(with: string)
        }
        loadFromStorage()
    }

    private func loadFromStorage() {
        if logStorage.count > logStorageMaxLines * 2 {
            logStorage.removeLast(logStorage.count - logStorageMaxLines)
        }
        textView.text = logStorage.reversed().joined()
    }

    private func update(with string: String) {
        if !isHidden {
            // don't perform potentially expensive string concatination if we aren't on screen
            self.textView.text = string + self.textView.text
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
