//
//  ViewController.swift
//  OktaAuth Demo App
//
//  Created by Alex on 17 Dec 18.
//

import UIKit
import OktaAuthNative

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        client = AuthenticationClient(oktaDomain: URL(string: "your-org.okta.com")!, delegate: self)
        client.mfaHandler = self
        updateStatus()
    }

    private var client: AuthenticationClient!

    @IBOutlet private var stateLabel: UILabel!
    @IBOutlet private var usernameField: UITextField!
    @IBOutlet private var passwordField: UITextField!
    @IBOutlet private var loginButton: UIButton!
    @IBOutlet private var cancelButton: UIButton!
    @IBOutlet private var resetButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!

    @IBAction private func loginTapped() {
        guard let username = usernameField.text,
            let password = passwordField.text else { return }

        client.authenticate(username: username, password: password)

        activityIndicator.startAnimating()
        updateStatus()
    }
    
    @IBAction private func cancelTapped() {
        client.cancelCurrentRequest()
        activityIndicator.stopAnimating()
    }
    
    @IBAction private func resetTapped() {
        client.resetStatus()
    }

    private func updateStatus() {
        if client.status == .MFAChallenge {
            stateLabel.text = "\(client.status.description) (\(client.factorResult?.rawValue ?? "?"))"
        } else {
            stateLabel.text = client.status.description
        }
    }
}

extension ViewController: AuthenticationClientDelegate {
    func handleSuccess(sessionToken: String) {
        activityIndicator.stopAnimating()
        updateStatus()

        let alert = UIAlertController(title: "Hooray!", message: "We are logged in", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func handleError(_ error: OktaError) {
        activityIndicator.stopAnimating()
        updateStatus()

        let alert = UIAlertController(title: "Error", message: error.description, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func handleChangePassword(canSkip: Bool, callback: @escaping (_ old: String?, _ new: String?, _ skip: Bool) -> Void) {
        updateStatus()
        let alert = UIAlertController(title: "Change Password", message: "Please choose new password", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Old Password" }
        alert.addTextField { $0.placeholder = "New Password" }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let old = alert.textFields?[0].text,
                let new = alert.textFields?[1].text else { return }
            callback(old, new, false)
        }))
        if canSkip {
            alert.addAction(UIAlertAction(title: "Skip", style: .cancel, handler: { _ in
                callback(nil, nil, true)
            }))
        } else {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                self.client.cancelTransaction()
            }))
        }
        present(alert, animated: true, completion: nil)
    }

    func transactionCancelled() {
        activityIndicator.stopAnimating()
        loginButton.isEnabled = true
        updateStatus()
    }
}

extension ViewController: AuthenticationClientMFAHandler {
    func mfaSelecFactor(factors: [EmbeddedResponse.Factor], callback: @escaping (_ index: Int) -> Void) {
        updateStatus()
        
        let alert = UIAlertController(title: "Select verification factor", message: nil, preferredStyle: .actionSheet)
        factors.enumerated().forEach { i, factor in
            alert.addAction(UIAlertAction(title: factor.factorType?.description, style: .default, handler: { _ in
                callback(i)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.client.cancel()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func mfaPushStateUpdated(_ state: OktaAPISuccessResponse.FactorResult) {
        updateStatus()
    }
    
    func mfaRequestCode(factor: EmbeddedResponse.Factor, callback: @escaping (String) -> Void) {
        updateStatus()
        let factorTypeDescription = factor.factorType?.description ?? "?"
        let factorProviderDescription = factor.provider?.description ?? "?"
        
        let message = "Please enter code for \(factorTypeDescription) (\(factorProviderDescription))"
        let alert = UIAlertController(title: "MFA", message: message, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Code" }
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let code = alert.textFields?[0].text else { return }
            callback(code)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.client.cancelTransaction()
        }))
        present(alert, animated: true, completion: nil)
    }
}
