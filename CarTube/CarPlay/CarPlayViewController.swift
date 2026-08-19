//
//  CarPlayViewController.swift
//  TrollTubeTest
//
//  Created by Rory Madden on 20/12/22.
//

import WebKit
import SwiftUI
import Speech
import AVFAudio

// This is the view controller shown on an in car's head unit display with CarPlay.
class CarPlayViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    
    private var webView: WKWebView = WKWebView()
    private var keyboardView: UIView = UIView()
    private var screenOffLabel: UIView = UIView()
    private var resultsController: SearchResultsViewController!
    private var micButton: MicButton!
    private var speechService: SpeechRecognizerService?

    // Build the WKWebViewConfiguration reflecting current settings — used by both
    // initial load (viewDidLoad) and in-place reconfiguration (applyConfigurationInPlace).
    func applyConfiguration() -> WKWebViewConfiguration {
        // Add any enabled scripts
        let sponsorBlockOn = UserDefaults.standard.bool(forKey: "SponsorBlockOn")
        let ageRestrictBypassOn = UserDefaults.standard.bool(forKey: "AgeRestrictBypassOn")
        let adBlockerOn = UserDefaults.standard.bool(forKey: "AdBlockerOn")
        let webConfiguration = WKWebViewConfiguration()
        var enabledScripts: [String] = []
        if sponsorBlockOn {
            enabledScripts.append("SponsorBlock")
        }
        if ageRestrictBypassOn {
            enabledScripts.append("AgeRestrictBypass")
        }
        if adBlockerOn {
            enabledScripts.append("AdBlocker")
        }

        // Add our custom CSS and JS
        enabledScripts.append("CustomLayout")

        enabledScripts.forEach { item in
            guard let scriptPath = Bundle.main.path(forResource: item, ofType: "js"),
                  let scriptSource = try? String(contentsOfFile: scriptPath) else { return }
            let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            webConfiguration.userContentController.addUserScript(userScript)
        }

        // Apply custom zoom & hide the open app button
        let zoomScript = "let meta = document.createElement('meta'); meta.name = 'viewport'; meta.content = 'initial-scale=\(Double(UserDefaults.standard.integer(forKey: "Zoom")) / 100.0), maximum-scale=\(Double(UserDefaults.standard.integer(forKey: "Zoom")) / 100.0), user-scalable=no'; const head = document.head; head.appendChild(meta); let css = document.createElement('style'); css.type = 'text/css'; css.innerHTML = '.open-app-button { display: none; }'; head.appendChild(css);"
        let zoomUserScript = WKUserScript(source: zoomScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webConfiguration.userContentController.addUserScript(zoomUserScript)

        webConfiguration.userContentController.add(self, name: "keyboard") // allow JS to activate the keyboard
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.allowsPictureInPictureMediaPlayback = false
        webConfiguration.allowsAirPlayForMediaPlayback = false
        webConfiguration.requiresUserActionForMediaPlayback = false

        return webConfiguration
    }

    // Tear down and re-create the webview with the current settings applied — replaces
    // the previous quit-to-apply contract; the app keeps running.
    func applyConfigurationInPlace() {
        let previousURL = webView.url
        let keyboardVisible = !keyboardView.isHidden

        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()

        let newWebView = WKWebView(frame: view.frame, configuration: applyConfiguration())
        newWebView.allowsLinkPreview = false
        newWebView.allowsBackForwardNavigationGestures = false
        newWebView.scrollView.minimumZoomScale = 1
        newWebView.scrollView.maximumZoomScale = 1
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self

        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        swipeLeftRecognizer.direction = .left
        swipeRightRecognizer.direction = .right
        newWebView.addGestureRecognizer(swipeLeftRecognizer)
        newWebView.addGestureRecognizer(swipeRightRecognizer)

        if keyboardVisible {
            newWebView.frame.size.height = view.bounds.size.height - keyboardView.frame.size.height
        }

        webView = newWebView
        view.insertSubview(webView, belowSubview: keyboardView)

        if let previousURL = previousURL {
            webView.load(URLRequest(url: previousURL))
        } else {
            goHome()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register self as the CarPlay view controller
        CarPlaySingleton.shared.setCPVC(controller: self)

        // Set up the main webview
        webView = WKWebView(frame: view.frame, configuration: applyConfiguration())
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Add recogniser for refreshing
//        let refreshControl = UIRefreshControl()
//        refreshControl.addTarget(self, action: #selector(reloadWebView(_:)), for: .valueChanged)
//        webView.scrollView.addSubview(refreshControl)

        // Add recognisers for back and forward
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(recognizer:)))
        swipeLeftRecognizer.direction = .left
        swipeRightRecognizer.direction = .right
        webView.addGestureRecognizer(swipeLeftRecognizer)
        webView.addGestureRecognizer(swipeRightRecognizer)

        // Check if the user tried to play something before CarPlay was loaded, otherwise load homepage
        if let urlString = CarPlaySingleton.shared.getCachedVideo() {
            CarPlaySingleton.shared.clearCachedVideo()
            loadUrl(urlString)
        } else {
            goHome()
        }

        self.view.addSubview(webView)

        // Add a view for our keyboard
        let keyboardController = UIHostingController(rootView: KeyboardView(width: view.bounds.width))
        self.addChild(keyboardController)
        self.view.addSubview(keyboardController.view)
        keyboardController.view.frame = CGRect(x: Int(view.bounds.origin.x), y: Int(view.bounds.height * 2/5), width: Int(view.bounds.width), height: Int(view.bounds.height * 3/5))
        self.keyboardView = keyboardController.view
        self.keyboardView.isHidden = true
        
        // Create a label that displays when the user turns their screen off
        screenOffLabel = UIView(frame: view.bounds)
        screenOffLabel.backgroundColor = .white
        screenOffLabel.isUserInteractionEnabled = false
        screenOffLabel.alpha = 0
        self.view.addSubview(screenOffLabel)
        let label = UILabel(frame: screenOffLabel.bounds)
        label.text = "Tap your phone screen once to resume CarTube."
        label.textAlignment = .center
        label.textColor = .black
        screenOffLabel.addSubview(label)

        // Add the search results overlay, below screenOffLabel so it never blocks the wake warning
        resultsController = SearchResultsViewController(
            onSelect: { [weak self] videoId in
                CarPlaySingleton.shared.loadUrl(YT_EMBED + videoId)
                CarPlaySingleton.shared.dismissSearchResults()
            },
            onClose: { [weak self] in
                CarPlaySingleton.shared.dismissSearchResults()
            },
            onRetry: { [weak self] in
                CarPlaySingleton.shared.dismissSearchResults()
                CarPlaySingleton.shared.toggleKeyboard()
            }
        )
        self.addChild(resultsController)
        resultsController.view.frame = view.bounds
        resultsController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        resultsController.view.isHidden = true
        view.insertSubview(resultsController.view, belowSubview: screenOffLabel)

        // Push-to-talk mic button — 16pt below the top safe-area edge, 16pt from the
        // trailing edge; hidden until the availability gate says otherwise (VOX-01).
        let micInset: CGFloat = 16.0
        let micDiameter: CGFloat = 56.0
        micButton = MicButton(frame: CGRect(
            x: view.bounds.width - micInset - micDiameter,
            y: view.safeAreaInsets.top + micInset,
            width: micDiameter,
            height: micDiameter
        ))
        micButton.isHidden = true
        micButton.onTouchDown = { [weak self] in
            self?.speechService?.startListening()
            self?.micButton.setListening(true)
        }
        micButton.onTouchUp = { [weak self] in
            self?.speechService?.stopListening()
            self?.micButton.setListening(false)
        }
        view.insertSubview(micButton, belowSubview: screenOffLabel)
        refreshMicButtonVisibility()

        let splashController = UIHostingController(rootView: SplashScreen())
        self.addChild(splashController)
        splashController.view.frame = view.bounds
        splashController.view.isUserInteractionEnabled = false
        self.view.addSubview(splashController.view)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut, animations: {
                splashController.view.alpha = 0
            }, completion: {_ in
                splashController.removeFromParent()
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshMicButtonVisibility()
    }

    // viewDidLoad computes the mic button's y-position from view.safeAreaInsets.top
    // before the view has been through a layout pass (it runs before
    // window.makeKeyAndVisible()), so the initial value is unreliable on head units
    // with a non-zero top safe area. Re-apply it here on every layout pass instead.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard micButton != nil else { return }
        micButton.frame.origin.y = view.safeAreaInsets.top + 16.0
    }

    // Re-evaluates the pure VoiceSearchAvailability gate against live system statuses
    // and shows/hides the mic button accordingly (VOX-01) — never touches the webview.
    func refreshMicButtonVisibility() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        let onDeviceSupported = VoiceSearchAvailability.probeOnDeviceSupport()
        let state = VoiceSearchAvailability.evaluate(speechStatus: speechStatus, micStatus: micStatus, onDeviceSupported: onDeviceSupported)

        guard state == .ready else {
            speechService = nil
            micButton.isHidden = true
            return
        }

        if speechService == nil {
            speechService = SpeechRecognizerService(
                onSubmit: { transcript in
                    Task { @MainActor in
                        CarPlaySingleton.shared.submitSearchQuery(transcript)
                    }
                },
                onFailure: { [weak self] outcome in
                    guard let self else { return }
                    let hint: VoiceHint = (outcome == .unavailable) ? .unavailable : .noSpeech
                    self.micButton.showHint(hint) { [weak self] in
                        self?.refreshMicButtonVisibility()
                    }
                }
            )
        }
        micButton.isHidden = !resultsController.view.isHidden
    }

    // Refresh webpage
//    @objc func reloadWebView(_ sender: UIRefreshControl) {
//        webView.reload()
//        sender.endRefreshing()
//    }
    
    // Back and forward navigation
    @objc private func handleSwipe(recognizer: UISwipeGestureRecognizer) {
        if (recognizer.direction == .left) {
            if webView.canGoForward {
                webView.goForward()
                
                let arrowImageView = UIImageView(image: UIImage(systemName: "arrow.right"))
                arrowImageView.isUserInteractionEnabled = false
                arrowImageView.tintColor = .white
                arrowImageView.frame.size.width = arrowImageView.frame.size.width * 2
                arrowImageView.frame.size.height = arrowImageView.frame.size.height * 2
                arrowImageView.frame.origin.x = view.frame.width
                arrowImageView.frame.origin.y = (view.frame.height / 2) - (arrowImageView.frame.size.height / 2)
                arrowImageView.layer.shadowColor = UIColor.black.cgColor
                arrowImageView.layer.shadowOpacity = 0.5
                arrowImageView.layer.shadowOffset = CGSize(width: 2, height: 2)
                arrowImageView.layer.shadowRadius = 5
                view.addSubview(arrowImageView)

                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: [], animations: {
                    arrowImageView.frame.origin.x -= arrowImageView.frame.width * 1.4
                }, completion: {_ in
                    UIView.animate(withDuration: 0.1, animations: {
                        arrowImageView.alpha = 0
                    }, completion: {_ in
                        arrowImageView.removeFromSuperview()
                    })
                })
            }
        }

        if (recognizer.direction == .right) {
            if webView.canGoBack {
                webView.goBack()
                
                let arrowImageView = UIImageView(image: UIImage(systemName: "arrow.left"))
                arrowImageView.isUserInteractionEnabled = false
                arrowImageView.tintColor = .white
                arrowImageView.frame.size.width = arrowImageView.frame.size.width * 2
                arrowImageView.frame.size.height = arrowImageView.frame.size.height * 2
                arrowImageView.frame.origin.x = -arrowImageView.frame.width
                arrowImageView.frame.origin.y = (view.frame.height / 2) - (arrowImageView.frame.size.height / 2)
                arrowImageView.layer.shadowColor = UIColor.black.cgColor
                arrowImageView.layer.shadowOpacity = 0.5
                arrowImageView.layer.shadowOffset = CGSize(width: 2, height: 2)
                arrowImageView.layer.shadowRadius = 5
                view.addSubview(arrowImageView)

                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: [], animations: {
                    arrowImageView.frame.origin.x += arrowImageView.frame.width * 1.4
                }, completion: {_ in
                    UIView.animate(withDuration: 0.1, animations: {
                        arrowImageView.alpha = 0
                    }, completion: {_ in
                        arrowImageView.removeFromSuperview()
                    })
                })
            }
        }
    }
    
    func disablePersistence() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func enablePersistence() {
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // Warn the user to tap their screen
    func showWarningLabel() {
        self.screenOffLabel.alpha = 1
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut, animations: {
                self.screenOffLabel.alpha = 0
            }, completion: nil)
        }
    }
    
    // Send keystrokes to the web view
    func sendInput(_ input: String) {
        webView._simulateTextEntered(input)
    }
    
    // Send a backspace to the web view
    func backspaceInput() {
        // not recommended, but works
        self.webView.evaluateJavaScript("document.execCommand('delete')")
    }
    
    // Go to YouTube homepage
    func goHome() {
        loadUrl(YT_HOME)
    }
    
    // Go back
    func goBack() {
        webView.goBack()
    }
    
    // Load a string as a URL into the web view
    func loadUrl(_ urlString: String) {
        let youtubeURL = URL(string: urlString)!
        let youtubeRequest = URLRequest(url: youtubeURL)
//        youtubeRequest.setValue(YT_HOME, forHTTPHeaderField: "Referer")
        webView.load(youtubeRequest)
    }
    
    // Show or hide the keyboard
    func toggleKeyboard() {
        if keyboardView.isHidden {
            self.keyboardView.isHidden = false
            self.webView.frame.size.height = view.bounds.size.height - self.keyboardView.frame.size.height
        } else {
            self.keyboardView.isHidden = true
            self.webView.frame.size.height = view.bounds.size.height
        }
    }
    
    // Show search results in the overlay — never touches the webview (UI-01)
    func showSearchResults(_ state: SearchResultsState) {
        resultsController.update(state)
        resultsController.view.isHidden = false
        micButton.isHidden = true
    }

    // Dismiss the search results overlay — never touches the webview (UI-01)
    func dismissSearchResults() {
        resultsController.view.isHidden = true
        refreshMicButtonVisibility()
    }

    // Helper func for JS to show or hide the keyboard
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "keyboard" {
            if message.body as? String == "hide" {
                self.keyboardView.isHidden = true
                self.webView.frame.size.height = view.bounds.size.height
            } else if message.body as? String == "show" {
                self.keyboardView.isHidden = false
                self.webView.frame.size.height = view.bounds.size.height - self.keyboardView.frame.size.height
            }
        }
    }
    
    // Perform any necessary tricks after a page finishes loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

    }

    // Stop the web view from creating any new web views, handle them here
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            guard let urlString = navigationAction.request.url?.absoluteString else { return nil }
            loadUrl(urlString)
        }
        return nil
    }
}
