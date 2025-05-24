import SpriteKit
import SwiftUI
import UIKit
import CoreLocation
import UserNotifications
import Foundation
import PassKit
import AuthenticationServices
//import Stripe
import BackgroundTasks


class GameScene: SKScene, UITextFieldDelegate, CLLocationManagerDelegate {
    
    var signInOverlay: UIView!
    var usernameTextField: UITextField!
    var signInButton: UIButton!
    var createAccountLabel: UILabel!
    var overlayBlurView: UIVisualEffectView!

    private var cachedLeaderboardPosition: Int?
    private var lastLeaderboardFetch: Date?
    var timer: Timer?
    fileprivate var label: SKLabelNode?
    fileprivate var spinnyNode: SKShapeNode?
    var progressLabel: UILabel!
    var enterCarLabel: SKLabelNode!
    var homeButton: UIButton!
    var welcome = SKLabelNode()
    var startScreen = true
    var getStartedButton: UIButton!
    var carLabel = SKLabelNode()
    var progress = SKLabelNode()
    var drivingStatusLabel: SKLabelNode?
    var background = SKSpriteNode(imageNamed: "background")
    var logoImage: UIImageView!
    var carbonOffsetsPurchased: Int = 0
    var carbonOffsetPurchaseHostingController: UIHostingController<CarbonOffsetPurchaseView>?
    var paymentController: PKPaymentAuthorizationViewController?
    private let paymentHandler = PaymentHandler()
    @State private var allTimeEmissions: Int = 0
    var dailyCounter = 0
    var totalKg: Int!
    var resetButton: UIButton!
    var userFullName: String = "Default User"
    let nameTextField = UITextField()
    private var doneButton: UIButton?
    
    var lastNightWeeklyScore: Double {
        get {
            return UserDefaults.standard.double(forKey: "lastNightWeeklyScore")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastNightWeeklyScore")
            UserDefaults.standard.synchronize()
        }
    }
    
    var userScore = 0
    var dayByDay: [DailyEmissions] = Array(repeating: DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0), count: 7)
    
    // Add property to track current day's emissions
    var currentDayEmissions: DailyEmissions {
        get {
            return DailyEmissions(
                carEmissions: dailyCarEmissions,
                food: FOOD,
                energy: ENERGY,
                goods: GOODS
            )
        }
    }
    var dailyCarEmissions = 0
    var weekByWeek = [0, 0, 0, 0, 0]
    var stackView: UIStackView!
    var previewWindows: [UIView] = []
    var ENERGY = 0
    var FOOD = 0
    var GOODS = 0
    private let locationTracker = LocationManager()
    var histogramHostingController: UIHostingController<HistogramView>?
    var pieChartHostingController: UIHostingController<PieChartView>?
    var profileHostingController: UIHostingController<ProfileView>?
    var ecotrack = SKLabelNode()
    var viewLeaderboardButton = UIButton(type: .system)
    var weeklyScore: Int = 0
    var offsetGrams: Int = UserDefaults.standard.integer(forKey: "offsetGrams")

    
    var myProgressButton = UIButton(type: .system)
    var myBadgesButton = UIButton(type: .system)
    var hostingController: UIHostingController<LeaderboardView>?
    
    var isAuthenticated = false
    
    
    // UIPickerView declarations
    var yearPickerView: UIPickerView!
    var makePickerView: UIPickerView!
    var modelPickerView: UIPickerView!
    
    // UIStackView declaration
    
    // Variables to store input
    var carYear: String = ""
    var carMake: String = ""
    var carModel: String = ""
    var emission: String = ""
    
    // UIButton declaration
    var confirmButton: UIButton!
    
    // Location Manager
    var locationManager: CLLocationManager!
    var customLocationManager: LocationManager!
    
    // Data for pickers
    var years = [String]()
    var makes = [String]()
    var models = [String]()
    var carData = [[String]]()
    var fullNameTextField : UITextField?

    
    // Leaderboard variables
    var leaderboardLabel: SKLabelNode!
    var CalculateduserEmissions: Int = 0
    var otherUserEmissions = [Int]()
    
    func startSignInWithAppleFlow() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    
    func setupResetButton() {
        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset Daily Data", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = .systemBlue
        resetButton.layer.cornerRadius = 8
        resetButton.addTarget(self, action: #selector(resetDailyData), for: .touchUpInside)
        if let view = self.view {
            view.addSubview(resetButton)
            resetButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                resetButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                resetButton.widthAnchor.constraint(equalToConstant: 150),
                resetButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }
    
    @objc func resetDailyData() {
        dailyCarEmissions = 0
        totalKg = 0
        saveArrays()
    }
    
    
    func loadCSVFile() -> [[String]]? {
        guard let path = Bundle.main.path(forResource: "caremissionsreal", ofType: "csv") else {
            print("CSV file not found in app bundle.")
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var result: [[String]] = []
            
            let rows = content.components(separatedBy: .newlines)
            for (index, row) in rows.enumerated() {
                // Only keep even-indexed rows (including 0)
                if index % 2 == 0 {
                    let columns = row.components(separatedBy: ",")
                    if !columns.isEmpty {
                        result.append(columns)
                    }
                }
            }
            
            // Filter out arrays with length 1
            result = result.filter { $0.count > 1 }
            
            print("CSV file successfully loaded from app bundle with odd indices removed and short arrays filtered")
            return result
        } catch {
            print("Error loading CSV file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func removeShortArrays() {
        carData = carData.filter { $0.count > 1 }
        
        print("Filtered carData: \(carData)")
    }
    


    func updateProfile() {
        print(allTimeEmissions)
        if let profileView = profileHostingController?.rootView as? ProfileView {
            let updatedProfileView = ProfileView(
                username: profileView.username,
                allTimeEmissions: self.allTimeEmissions, // Use the class property
                dailyEmissionsAverage: profileView.dailyEmissionsAverage,
                carDetails: profileView.carDetails,
                leaderboardPosition: profileView.leaderboardPosition,
                carbonCreditsPurchased: carbonOffsetsPurchased, totalKg: totalKg
            )
            profileHostingController?.rootView = updatedProfileView
        }
    }
    
    func start() {
        // Schedule the timer to check every 2 minutes
        timer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(checkTime), userInfo: nil, repeats: true)
    }

    @objc func checkTime() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = .pst
        let currentTime = dateFormatter.string(from: Date())
        
        // Update FOOD, GOODS, and ENERGY every 2 minutes
        updateEmissionsData()
        
        if currentTime == "21:30" {
            updateEnergyAfterDriving()
        }
        if currentTime == "00:00" {
            // Check if it's Monday
            let calendar = Calendar.current
            if calendar.component(.weekday, from: Date()) == 2 {
                // It's Monday, reset everything to 0
                lastNightWeeklyScore = 0
            } else {
                // Not Monday, store current weekly score
                lastNightWeeklyScore = Double(weekByWeek[4])
            }
            performMidnightTasks()
        }
    }
    
    func updateEmissionsData() {
        // Fetch updated data from backend
        if let username = UserDefaults.standard.string(forKey: "userFullName") {
            fetchUserEmissions(username: username)
        }
    }
    
    override func didMove(to view: SKView) {

        loadArrays()
        setupBackgroundTasks()
        setupMidnightTimer()
        start()
        setupNotificationHandler()
        updateWeeklyHistogram()
        hideAppleSignInButton()
        super.didMove(to: view)
        if UIDevice.isIPad10thGeneration {
            ecotrack.isHidden = true
        }
        
        // Setup welcome and get started labels
        welcome.text = "Welcome to your personal carbon accountant"
        welcome.zPosition = 2
        welcome.fontSize = 14
        welcome.position = CGPoint(x: 0, y: 162.5)
        welcome.fontColor = SKColor.white
        welcome.fontName = "AvenirNext-Bold"
        addChild(welcome)
        
//        StripeAPI.defaultPublishableKey = "pk_live_51Q9qgvIkPhKQ4Pu3bt6Dj2uXUEVHCX39Y4r9WmracCglvD1J52Ued55IbJR4i4WTRkqHRTViUAksYhV0cYUbdriX00LtKC7lPS"
        
        fullNameTextField = UITextField(frame: CGRect(x: (size.width - 280) / 2, y: size.height / 2 - 20, width: 280, height: 40))
        guard let fullNameTextField = fullNameTextField else { return }

        // Configure the text field
        fullNameTextField.placeholder = "Enter your full name"
        fullNameTextField.borderStyle = .roundedRect
        fullNameTextField.autocorrectionType = .no
        fullNameTextField.returnKeyType = .done
        fullNameTextField.delegate = self
        fullNameTextField.backgroundColor = UIColor.white
        fullNameTextField.isHidden = true
        view.addSubview(fullNameTextField)
        
        enterCarLabel = SKLabelNode(text: "Select your car")
        enterCarLabel.zPosition = 2
        enterCarLabel.fontSize = 30
        enterCarLabel.position = CGPoint(x: 0, y: 250)
        enterCarLabel.fontColor = SKColor.white
        enterCarLabel.fontName = "AvenirNext-Bold"
        enterCarLabel.isHidden = true
        addChild(enterCarLabel)

        
        doneButton = UIButton(frame: CGRect(x: (size.width - 100) / 2, y: 500, width: 100, height: 40))
        guard let doneButton = doneButton else { return }

        // Configure the button
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.backgroundColor = .blue // Set button background color
        doneButton.layer.cornerRadius = 5 // Rounded corners
        doneButton.addTarget(self, action: #selector(doneButtonPressed), for: .touchUpInside)
        doneButton.isHidden = true
        view.addSubview(doneButton)
        
        

        
        
        drivingStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        
        // Set up the label properties
        if let drivingStatusLabel = drivingStatusLabel {
            drivingStatusLabel.fontSize = 14
            drivingStatusLabel.fontColor = .white
            drivingStatusLabel.horizontalAlignmentMode = .right
            drivingStatusLabel.verticalAlignmentMode = .top
            drivingStatusLabel.zPosition = 100 // Ensure it's above other elements
            drivingStatusLabel.position = CGPoint(x: 0, y: 0)
            drivingStatusLabel.isHidden = true
            
            // Add the label to the scene
            //self.addChild(drivingStatusLabel)
        }
        
        getStartedButton = UIButton(type: .system)
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 24)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.backgroundColor = .systemGreen
        getStartedButton.layer.cornerRadius = 10
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(getStartedButton)

        // Position the button in the center of the screen
        NSLayoutConstraint.activate([
            getStartedButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            getStartedButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            getStartedButton.widthAnchor.constraint(equalToConstant: 200),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50)
        ])


        
        ecotrack.text = "EcoTrack"
        ecotrack.fontSize = 30
        ecotrack.position = CGPoint(x:0, y:325)
        ecotrack.fontColor = SKColor.white
        ecotrack.zPosition = 2
        ecotrack.fontName = "AvenirNext-Bold"
        addChild(ecotrack)
        
        background.zPosition = 1
        background.position = CGPoint(x: 0, y: 0)
        addChild(background)
        if let savedCarYear = UserDefaults.standard.string(forKey: "carYear"),
           let savedCarMake = UserDefaults.standard.string(forKey: "carMake"),
           let savedCarModel = UserDefaults.standard.string(forKey: "carModel") {
            // Use saved information
            carYear = savedCarYear
            carMake = savedCarMake
            carModel = savedCarModel
            
            // Show home page
            
            setupHomePage()
        } else {
            // No saved information, show the get started screen
            showGetStartedScreen()
        }
        
        if let csvData = loadCSVFile() {
            carData = csvData
            years = Array(Set(carData.map { $0[0] })).sorted()
            makes = Array(Set(carData.map { $0[1] })).sorted()
            models = Array(Set(carData.map { $0[2] })).sorted()
            
            print("Years: \(years)")
            print("Makes: \(makes)")
            print("Models: \(models)")
        } else {
            print("Failed to load CSV data")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDrivingStatusChanged), name: .drivingStatusChanged, object: nil)


        
        // Setup logo image
//        logoImage = UIImageView(image: UIImage(named: "EcoTracker"))
//        logoImage.contentMode = .scaleAspectFit
//        logoImage.translatesAutoresizingMaskIntoConstraints = false
//

        
        homeButton = UIButton(type: .system)

        view.addSubview(homeButton)
        NotificationCenter.default.addObserver(self, selector: #selector(drivingStatusChanged), name: .drivingStatusChanged, object: nil)


            
            // Add tap gesture recognizer to the image view

        
        
        carLabel = self.childNode(withName: "carquestion") as! SKLabelNode
        carLabel.isHidden = true
        
        loadCSVFile()
        
        // Initialize LocationManager
        customLocationManager = LocationManager()
        customLocationManager.delegate = self
        
        // Request notification permission and schedule daily notifications
        requestNotificationPermission()
        scheduleDailyNotification()
        
        // Check for saved car information
        if let savedCarYear = UserDefaults.standard.string(forKey: "carYear"),
           let savedCarMake = UserDefaults.standard.string(forKey: "carMake"),
           let savedCarModel = UserDefaults.standard.string(forKey: "carModel") {
            // Use saved information
            carYear = savedCarYear
            carMake = savedCarMake
            carModel = savedCarModel
        } else {
            // No saved information, show the get started screen
            showGetStartedScreen()
        }
        
        // Setup leaderboard label
        leaderboardLabel = SKLabelNode()
        leaderboardLabel.fontSize = 20
        leaderboardLabel.fontColor = SKColor.black
        leaderboardLabel.position = CGPoint(x: 0, y: 100)
        leaderboardLabel.isHidden = true
        leaderboardLabel.zPosition = 2
        addChild(leaderboardLabel)
        
        locationTracker.delegate = self
 // Load GPX data
        locationTracker.startTrackingDriving()

        // Load GPX file


    }

    
//SETUP METHODS----------------------------------
    
    func showGetStartedScreen() {
        // Show the welcome label and get started button
        welcome.isHidden = false
        getStartedButton.isHidden = false
        
        // Remove any existing Apple ID button
        view?.viewWithTag(100)?.removeFromSuperview()
        
        guard let view = self.view else { return }
        
        // Show the ecotrack SKLabelNode and adjust its position
        ecotrack.isHidden = true
        // Move the ecotrack label down a bit (adjust the y value as needed)
        ecotrack.position = CGPoint(x: 0, y: 285)  // Original was y: 325, now lowered to 300
        
        // Add YouTube button to the top-right corner
        let youtubeButton = UIButton(type: .system)
        youtubeButton.tag = 201 // Tag for easy removal later
        
        // Use YouTube icon or SF Symbol as fallback
        if let youtubeImage = UIImage(named: "youtube-icon") {
            youtubeButton.setImage(youtubeImage, for: .normal)
        } else {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            let playImage = UIImage(systemName: "play.rectangle.fill", withConfiguration: symbolConfig)?.withTintColor(.red, renderingMode: .alwaysOriginal)
            youtubeButton.setImage(playImage, for: .normal)
        }
        
        youtubeButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        youtubeButton.layer.cornerRadius = 20
        youtubeButton.translatesAutoresizingMaskIntoConstraints = false
        youtubeButton.addTarget(self, action: #selector(youtubeButtonTapped), for: .touchUpInside)
        view.addSubview(youtubeButton)
        
        // Position the YouTube button in the top-right corner
        NSLayoutConstraint.activate([
            youtubeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            youtubeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20), // More to the right
            youtubeButton.widthAnchor.constraint(equalToConstant: 40),
            youtubeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add a bouncing "About Us" label at the bottom
        let aboutUsButton = UIButton(type: .system)
        aboutUsButton.tag = 202 // Tag for easy removal later
        aboutUsButton.setTitle("About Us", for: .normal)
        aboutUsButton.setTitleColor(.white, for: .normal)
        aboutUsButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        aboutUsButton.translatesAutoresizingMaskIntoConstraints = false
        aboutUsButton.addTarget(self, action: #selector(aboutUsButtonTapped), for: .touchUpInside)
        view.addSubview(aboutUsButton)
        
        NSLayoutConstraint.activate([
            aboutUsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            aboutUsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            aboutUsButton.widthAnchor.constraint(equalToConstant: 120),
            aboutUsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    // Handle YouTube button tap
    @objc func youtubeButtonTapped() {
        // Open YouTube channel URL
        if let youtubeURL = URL(string: "https://www.youtube.com/@EcoTrack-r7l") {
            if UIApplication.shared.canOpenURL(youtubeURL) {
                UIApplication.shared.open(youtubeURL, options: [:], completionHandler: nil)
            }
        }
    }

    // Handle About Us button tap
    @objc func aboutUsButtonTapped() {
        // Create and show About Us view
        showAboutUsOverlay()
    }

    func showAboutUsOverlay() {
        guard let view = self.view else { return }
        
        // Overlay container with background blur
        let overlayView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        overlayView.tag = 203
        overlayView.frame = view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.alpha = 0
        view.addSubview(overlayView)
        
        // About Us container
        let aboutContainer = UIView()
        aboutContainer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        aboutContainer.layer.cornerRadius = 16
        aboutContainer.translatesAutoresizingMaskIntoConstraints = false
        overlayView.contentView.addSubview(aboutContainer)
        
        // Initial position off-screen (for animation)
        NSLayoutConstraint.activate([
            aboutContainer.leadingAnchor.constraint(equalTo: overlayView.contentView.leadingAnchor, constant: 20),
            aboutContainer.trailingAnchor.constraint(equalTo: overlayView.contentView.trailingAnchor, constant: -20),
            aboutContainer.heightAnchor.constraint(equalToConstant: 400),
            // Position below screen initially (will animate up)
            aboutContainer.topAnchor.constraint(equalTo: overlayView.contentView.bottomAnchor)
        ])
        
        view.layoutIfNeeded() // Force layout before animation
        
        // About Us title
        let titleLabel = UILabel()
        titleLabel.text = "About EcoTrack"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutContainer.addSubview(titleLabel)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeAboutUs), for: .touchUpInside)
        aboutContainer.addSubview(closeButton)
        
        // About Us content
        let contentText = UITextView()
        contentText.text = """
        EcoTrack is a personal carbon footprint tracker that helps you monitor and reduce your environmental impact.
        
        Our mission is to make carbon tracking simple and accessible for everyone. By understanding your daily carbon emissions, you can make more informed choices that benefit the planet.
        
        The EcoTrack team is passionate about environmental sustainability and leveraging technology to create positive change in the world.
        
        Version 1.0
        © 2025 EcoTrack Team
        """
        contentText.font = UIFont.systemFont(ofSize: 16)
        contentText.textAlignment = .left
        contentText.isEditable = false
        contentText.backgroundColor = .clear
        contentText.translatesAutoresizingMaskIntoConstraints = false
        aboutContainer.addSubview(contentText)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: aboutContainer.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: aboutContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: aboutContainer.trailingAnchor),
            
            closeButton.topAnchor.constraint(equalTo: aboutContainer.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: aboutContainer.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            contentText.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            contentText.leadingAnchor.constraint(equalTo: aboutContainer.leadingAnchor, constant: 20),
            contentText.trailingAnchor.constraint(equalTo: aboutContainer.trailingAnchor, constant: -20),
            contentText.bottomAnchor.constraint(equalTo: aboutContainer.bottomAnchor, constant: -20)
        ])
        
        // Animate the overlay and about container
        UIView.animate(withDuration: 0.3, animations: {
            overlayView.alpha = 1
        }, completion: { _ in
            // Change the container's position constraint
            overlayView.contentView.constraints.first { $0.firstItem === aboutContainer && $0.firstAttribute == .top }?.isActive = false
            
            NSLayoutConstraint.activate([
                aboutContainer.centerYAnchor.constraint(equalTo: overlayView.contentView.centerYAnchor)
            ])
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
                overlayView.contentView.layoutIfNeeded()
            }, completion: nil)
        })
    }

    @objc func closeAboutUs() {
        guard let overlayView = view?.viewWithTag(203) as? UIVisualEffectView else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            overlayView.alpha = 0
        }, completion: { _ in
            overlayView.removeFromSuperview()
        })
    }
    
    @objc func getStartedButtonTapped() {
        welcome.isHidden = true
        getStartedButton.isHidden = true
        
        // Show sign-in overlay instead of the Apple sign-in button
        showSignInOverlay()
    }
    
    func showSignInOverlay() {
        // Create blur effect for the background
        let blurEffect = UIBlurEffect(style: .dark)
        overlayBlurView = UIVisualEffectView(effect: blurEffect)
        overlayBlurView.frame = view?.bounds ?? CGRect.zero
        overlayBlurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view?.addSubview(overlayBlurView)
        
        // Create the sign-in overlay container
        signInOverlay = UIView()
        signInOverlay.backgroundColor = .white
        signInOverlay.layer.cornerRadius = 15
        signInOverlay.translatesAutoresizingMaskIntoConstraints = false
        view?.addSubview(signInOverlay)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "Sign In"
        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 22)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        signInOverlay.addSubview(titleLabel)
        
        // Create username text field
        usernameTextField = UITextField()
        usernameTextField.placeholder = "Enter your username"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.autocorrectionType = .no
        usernameTextField.returnKeyType = .done
        usernameTextField.delegate = self
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        signInOverlay.addSubview(usernameTextField)
        
        // Create sign in button
        signInButton = UIButton(type: .system)
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        signInButton.backgroundColor = .systemGreen
        signInButton.setTitleColor(.white, for: .normal)
        signInButton.layer.cornerRadius = 10
        signInButton.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInOverlay.addSubview(signInButton)
        
        // Create "Don't have an account?" label
        createAccountLabel = UILabel()
        createAccountLabel.text = "Don't have an account?"
        createAccountLabel.font = UIFont.systemFont(ofSize: 16)
        createAccountLabel.textColor = .systemBlue
        createAccountLabel.textAlignment = .center
        createAccountLabel.isUserInteractionEnabled = true
        createAccountLabel.translatesAutoresizingMaskIntoConstraints = false
        signInOverlay.addSubview(createAccountLabel)
        
        // Add tap gesture to the label
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(createAccountTapped))
        createAccountLabel.addGestureRecognizer(tapGesture)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            signInOverlay.centerXAnchor.constraint(equalTo: view!.centerXAnchor),
            signInOverlay.centerYAnchor.constraint(equalTo: view!.centerYAnchor),
            signInOverlay.widthAnchor.constraint(equalToConstant: 300),
            signInOverlay.heightAnchor.constraint(equalToConstant: 250),
            
            titleLabel.topAnchor.constraint(equalTo: signInOverlay.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: signInOverlay.centerXAnchor),
            
            usernameTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            usernameTextField.leadingAnchor.constraint(equalTo: signInOverlay.leadingAnchor, constant: 20),
            usernameTextField.trailingAnchor.constraint(equalTo: signInOverlay.trailingAnchor, constant: -20),
            usernameTextField.heightAnchor.constraint(equalToConstant: 40),
            
            signInButton.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 30),
            signInButton.leadingAnchor.constraint(equalTo: signInOverlay.leadingAnchor, constant: 20),
            signInButton.trailingAnchor.constraint(equalTo: signInOverlay.trailingAnchor, constant: -20),
            signInButton.heightAnchor.constraint(equalToConstant: 45),
            
            createAccountLabel.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 20),
            createAccountLabel.centerXAnchor.constraint(equalTo: signInOverlay.centerXAnchor)
        ])
    }
    
    @objc func signInButtonTapped() {
        guard let username = usernameTextField.text, !username.isEmpty else {
            // Show an alert if username is empty
            let alert = UIAlertController(title: "Error", message: "Please enter a username", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            view?.window?.rootViewController?.present(alert, animated: true)
            return
        }
        
        // Show loading indicator
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        // Check if the username exists in the backend
        checkUsernameExists(username: username) { [weak self] exists in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                loadingView.stopAnimation()
                loadingView.removeFromSuperview()
                
                if exists {
                    // Username exists, save it and load user data
                    UserDefaults.standard.set(username, forKey: "userFullName")
                    UserDefaults.standard.synchronize()
                    
                    // Remove the sign-in overlay
                    self.removeSignInOverlay()
                    
                    // Load user data and set up home page
                    self.loadUserData(username: username)
                } else {
                    // Username doesn't exist, show error
                    let alert = UIAlertController(title: "User Not Found",
                                                 message: "No account found with this username. Do you want to create a new account?",
                                                 preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    alert.addAction(UIAlertAction(title: "Create Account", style: .default) { _ in
                        self.createAccountTapped()
                    })
                    
                    self.view?.window?.rootViewController?.present(alert, animated: true)
                }
            }
        }
    }

    // Add this method to check if a username exists in the backend
    func checkUsernameExists(username: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetUserEmissions") else {
            completion(false)
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "username", value: username)]
        
        guard let finalUrl = components?.url else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: finalUrl) { data, response, error in
            if let error = error {
                print("Error checking username: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let data = data, !data.isEmpty {
                        do {
                            // Try to decode the response
                            let stats = try JSONDecoder().decode(UserStats.self, from: data)
                            // If we can decode the data and the username matches, the user exists
                            completion(stats.username == username)
                        } catch {
                            // If we can't decode the response, assume the user doesn't exist
                            print("Error decoding user data: \(error)")
                            completion(false)
                        }
                    } else {
                        // Empty data means no user found
                        completion(false)
                    }
                } else {
                    // Non-200 status code means something went wrong
                    completion(false)
                }
            } else {
                // No HTTP response means something went wrong
                completion(false)
            }
        }.resume()
    }

    // Add this method to load user data from the backend
    func loadUserData(username: String) {
        // Show loading indicator
        let loadingViewController = showLoadingView(withMessage: "Loading your data...")
        
        // Fetch user's emissions data
        EmissionsCache.shared.getEmissionsData(username: username, forceRefresh: true) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingView(loadingViewController)
                
                switch result {
                case .success(let stats):
                    // Update local state with the data from the backend
                    self.FOOD = stats.currentDayEmissions.food
                    self.ENERGY = stats.currentDayEmissions.energy
                    self.GOODS = stats.currentDayEmissions.goods
                    self.dailyCarEmissions = stats.currentDayEmissions.carEmissions
                    self.weekByWeek = stats.weeklyHistory
                    self.dayByDay = stats.dailyHistory
                    
                    // Save the updated values
                    self.saveArrays()
                    
                    // Fetch car details specifically as they might be stored differently
                    self.fetchUserCarDetails(username: username) { carFound in
                        if carFound {
                            // Car details found, go straight to home
                            self.setupHomePage()
                        } else {
                            // Car details missing, show car selection overlay
                            self.showCarSelectionOverlay()
                        }
                    }
                    
                case .failure(let error):
                    print("Failed to load user data: \(error)")
                    // Show error message
                    let alert = UIAlertController(title: "Error",
                                                 message: "Failed to load your data. Please try again.",
                                                 preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.view?.window?.rootViewController?.present(alert, animated: true)
                }
            }
        }
    }
    
    func fetchUserCarDetails(username: String, completion: @escaping (Bool) -> Void) {
        // For this example, I'll assume the car details are stored in UserDefaults
        // In a real app, you might want to fetch them from the backend
        if let savedCarYear = UserDefaults.standard.string(forKey: "carYear"),
           let savedCarMake = UserDefaults.standard.string(forKey: "carMake"),
           let savedCarModel = UserDefaults.standard.string(forKey: "carModel"),
           !savedCarYear.isEmpty && !savedCarMake.isEmpty && !savedCarModel.isEmpty {
            
            // Car details found, update local properties
            carYear = savedCarYear
            carMake = savedCarMake
            carModel = savedCarModel
            completion(true)
            
        } else {
            // No car details found
            completion(false)
        }
    }

    // Add this method to show car selection in a modal overlay
    func showCarSelectionOverlay() {
        // Create the overlay container
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view?.addSubview(overlayView)
        
        // Make the overlay fill the screen
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view!.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view!.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view!.bottomAnchor)
        ])
        
        // Create the car selection window
        let windowView = UIView()
        windowView.backgroundColor = .white
        windowView.layer.cornerRadius = 15
        windowView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(windowView)
        
        // Size and position the window
        NSLayoutConstraint.activate([
            windowView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            windowView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            windowView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.9),
            windowView.heightAnchor.constraint(equalTo: overlayView.heightAnchor, multiplier: 0.7)
        ])
        
        // Create a container view to hold all content and center it vertically
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        windowView.addSubview(containerView)
        
        // Center the container vertically and horizontally
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: windowView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: windowView.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: windowView.widthAnchor, multiplier: 0.9),
            // Let the height be determined by content
        ])
        
        // Add a title label
        let titleLabel = UILabel()
        titleLabel.text = "Select Your Car"
        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 22)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // Create and configure the picker views
        yearPickerView = createPickerView()
        makePickerView = createPickerView()
        modelPickerView = createPickerView()
        
        // Set up picker views data sources and delegates
        yearPickerView.dataSource = self
        yearPickerView.delegate = self
        makePickerView.dataSource = self
        makePickerView.delegate = self
        modelPickerView.dataSource = self
        modelPickerView.delegate = self
        
        // Create label for each picker
        let yearLabel = UILabel()
        yearLabel.text = "Year"
        yearLabel.textAlignment = .center
        yearLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let makeLabel = UILabel()
        makeLabel.text = "Make"
        makeLabel.textAlignment = .center
        makeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let modelLabel = UILabel()
        modelLabel.text = "Model"
        modelLabel.textAlignment = .center
        modelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let labelStackView = UIStackView(arrangedSubviews: [yearLabel, makeLabel, modelLabel])
        labelStackView.axis = .horizontal
        labelStackView.distribution = .fillEqually
        labelStackView.spacing = 10
        labelStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(labelStackView)
        
        NSLayoutConstraint.activate([
            labelStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            labelStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            labelStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            labelStackView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Create a stack view for the pickers
        let pickerStackView = UIStackView(arrangedSubviews: [yearPickerView, makePickerView, modelPickerView])
        pickerStackView.axis = .horizontal
        pickerStackView.distribution = .fillEqually
        pickerStackView.spacing = 10
        pickerStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pickerStackView)
        
        NSLayoutConstraint.activate([
            pickerStackView.topAnchor.constraint(equalTo: labelStackView.bottomAnchor, constant: 5),
            pickerStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerStackView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Create a confirmation button
        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        confirmButton.backgroundColor = .systemGreen
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 10
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(confirmCarSelection), for: .touchUpInside)
        containerView.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            confirmButton.topAnchor.constraint(equalTo: pickerStackView.bottomAnchor, constant: 40),
            confirmButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 200),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),
            confirmButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Initialize the picker data
        if let csvData = loadCSVFile() {
            carData = csvData
            years = Array(Set(carData.map { $0[0] })).sorted()
            if let firstYear = years.first {
                carYear = firstYear
                makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
                if let firstMake = makes.first {
                    carMake = firstMake
                    models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
                    carModel = models.first ?? ""
                }
            }
        }
        
        // Refresh the pickers
        yearPickerView.reloadAllComponents()
        makePickerView.reloadAllComponents()
        modelPickerView.reloadAllComponents()
        
        // Set the initial selected rows
        yearPickerView.selectRow(0, inComponent: 0, animated: false)
        makePickerView.selectRow(0, inComponent: 0, animated: false)
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
    }

    @objc func confirmCarSelection() {
        // Save the selected car information
        UserDefaults.standard.set(carYear, forKey: "carYear")
        UserDefaults.standard.set(carMake, forKey: "carMake")
        UserDefaults.standard.set(carModel, forKey: "carModel")
        UserDefaults.standard.synchronize()
        
        // Update location tracker with car details
        locationTracker.setCarDetails(year: carYear, make: carMake, model: carModel, list: carData)
        
        // Remove the overlay and proceed to home
        if let overlayView = view?.subviews.first(where: { $0.backgroundColor?.isEqual(UIColor.black.withAlphaComponent(0.7)) ?? false }) {
            UIView.animate(withDuration: 0.3, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
                self.setupHomePage()
            }
        } else {
            // In case we can't find the overlay, still go to home
            setupHomePage()
        }
    }

    @objc func createAccountTapped() {
        // Remove the sign-in overlay
        removeSignInOverlay()
        
        // Show car selection overlay for new users
        showCarSelectionForNewUser()
    }
    
    func showCarSelectionForNewUser() {
        // Create the overlay container
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view?.addSubview(overlayView)
        
        // Make the overlay fill the screen
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view!.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view!.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view!.bottomAnchor)
        ])
        
        // Create the car selection window
        let windowView = UIView()
        windowView.backgroundColor = .white
        windowView.layer.cornerRadius = 15
        windowView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(windowView)
        
        // Size and position the window
        NSLayoutConstraint.activate([
            windowView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            windowView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            windowView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.9),
            windowView.heightAnchor.constraint(equalTo: overlayView.heightAnchor, multiplier: 0.7)
        ])
        
        // Create a container view to hold all content and center it vertically
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        windowView.addSubview(containerView)
        
        // Center the container vertically and horizontally
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: windowView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: windowView.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: windowView.widthAnchor, multiplier: 0.9),
            // Let the height be determined by content
        ])
        
        // Add a title label
        let titleLabel = UILabel()
        titleLabel.text = "Select Your Car"
        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 22)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        // Create and configure the picker views
        yearPickerView = createPickerView()
        makePickerView = createPickerView()
        modelPickerView = createPickerView()
        
        // Set up picker views data sources and delegates
        yearPickerView.dataSource = self
        yearPickerView.delegate = self
        makePickerView.dataSource = self
        makePickerView.delegate = self
        modelPickerView.dataSource = self
        modelPickerView.delegate = self
        
        // Create label for each picker
        let yearLabel = UILabel()
        yearLabel.text = "Year"
        yearLabel.textAlignment = .center
        yearLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let makeLabel = UILabel()
        makeLabel.text = "Make"
        makeLabel.textAlignment = .center
        makeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let modelLabel = UILabel()
        modelLabel.text = "Model"
        modelLabel.textAlignment = .center
        modelLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        let labelStackView = UIStackView(arrangedSubviews: [yearLabel, makeLabel, modelLabel])
        labelStackView.axis = .horizontal
        labelStackView.distribution = .fillEqually
        labelStackView.spacing = 10
        labelStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(labelStackView)
        
        NSLayoutConstraint.activate([
            labelStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            labelStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            labelStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            labelStackView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Create a stack view for the pickers
        let pickerStackView = UIStackView(arrangedSubviews: [yearPickerView, makePickerView, modelPickerView])
        pickerStackView.axis = .horizontal
        pickerStackView.distribution = .fillEqually
        pickerStackView.spacing = 10
        pickerStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pickerStackView)
        
        NSLayoutConstraint.activate([
            pickerStackView.topAnchor.constraint(equalTo: labelStackView.bottomAnchor, constant: 5),
            pickerStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerStackView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        // Create a next button
        let nextButton = UIButton(type: .system)
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        nextButton.backgroundColor = .systemGreen
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 10
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(newUserCarSelectionConfirmed), for: .touchUpInside)
        containerView.addSubview(nextButton)
        
        NSLayoutConstraint.activate([
            nextButton.topAnchor.constraint(equalTo: pickerStackView.bottomAnchor, constant: 40),
            nextButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 200),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
            nextButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // Initialize the picker data
        if let csvData = loadCSVFile() {
            carData = csvData
            years = Array(Set(carData.map { $0[0] })).sorted()
            if let firstYear = years.first {
                carYear = firstYear
                makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
                if let firstMake = makes.first {
                    carMake = firstMake
                    models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
                    carModel = models.first ?? ""
                }
            }
        }
        
        // Refresh the pickers
        yearPickerView.reloadAllComponents()
        makePickerView.reloadAllComponents()
        modelPickerView.reloadAllComponents()
        
        // Set the initial selected rows
        yearPickerView.selectRow(0, inComponent: 0, animated: false)
        makePickerView.selectRow(0, inComponent: 0, animated: false)
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
    }
    
    @objc func newUserCarSelectionConfirmed() {
        // Save the selected car information
        UserDefaults.standard.set(carYear, forKey: "carYear")
        UserDefaults.standard.set(carMake, forKey: "carMake")
        UserDefaults.standard.set(carModel, forKey: "carModel")
        UserDefaults.standard.synchronize()
        
        // Update location tracker with car details
        locationTracker.setCarDetails(year: carYear, make: carMake, model: carModel, list: carData)
        
        // Find and remove the car selection overlay
        if let overlayView = view?.subviews.first(where: { $0.backgroundColor?.isEqual(UIColor.black.withAlphaComponent(0.7)) ?? false }) {
            overlayView.removeFromSuperview()
            
            // Now prompt for user's name
            showUserNamePrompt()
        }
    }
    
    func showUserNamePrompt() {
        // Create the overlay container
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view?.addSubview(overlayView)
        
        // Make the overlay fill the screen
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view!.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view!.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view!.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view!.bottomAnchor)
        ])
        
        // Create the name input window
        let windowView = UIView()
        windowView.backgroundColor = .white
        windowView.layer.cornerRadius = 15
        windowView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(windowView)
        
        // Size and position the window
        NSLayoutConstraint.activate([
            windowView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            windowView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            windowView.widthAnchor.constraint(equalTo: overlayView.widthAnchor, multiplier: 0.9),
            windowView.heightAnchor.constraint(equalToConstant: 250)
        ])
        
        // Add a title label
        let titleLabel = UILabel()
        titleLabel.text = "Create Account - Your Name"
        titleLabel.font = UIFont(name: "AvenirNext-Bold", size: 22)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        windowView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: windowView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: windowView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: windowView.trailingAnchor, constant: -20)
        ])
        
        // Add instruction text
        let instructionLabel = UILabel()
        instructionLabel.text = "This will be shown on the leaderboard"
        instructionLabel.font = UIFont.systemFont(ofSize: 12)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.numberOfLines = 0
        windowView.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            instructionLabel.leadingAnchor.constraint(equalTo: windowView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: windowView.trailingAnchor, constant: -20)
        ])
        
        // Add name text field
        let nameTextField = UITextField()
        nameTextField.placeholder = "Enter your name"
        nameTextField.borderStyle = .roundedRect
        nameTextField.autocorrectionType = .no
        nameTextField.returnKeyType = .done
        nameTextField.delegate = self
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        windowView.addSubview(nameTextField)
        
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: windowView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: windowView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Create a finish button
        let finishButton = UIButton(type: .system)
        finishButton.setTitle("Finish", for: .normal)
        finishButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        finishButton.backgroundColor = .systemGreen
        finishButton.setTitleColor(.white, for: .normal)
        finishButton.layer.cornerRadius = 10
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Use a closure to capture the nameTextField reference
        finishButton.addTarget(self, action: #selector(finishAccountCreation(_:)), for: .touchUpInside)
        finishButton.tag = 1001 // Just to have a unique identifier
        
        // Store the text field in the button's layer using associated objects
        objc_setAssociatedObject(finishButton, UnsafeRawPointer(bitPattern: 1)!, nameTextField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        windowView.addSubview(finishButton)
        
        NSLayoutConstraint.activate([
            finishButton.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 30),
            finishButton.centerXAnchor.constraint(equalTo: windowView.centerXAnchor),
            finishButton.widthAnchor.constraint(equalToConstant: 200),
            finishButton.heightAnchor.constraint(equalToConstant: 50),
            finishButton.bottomAnchor.constraint(lessThanOrEqualTo: windowView.bottomAnchor, constant: -20)
        ])
        
        // Focus the text field
        nameTextField.becomeFirstResponder()
    }

    @objc func finishAccountCreation(_ sender: UIButton) {
        // Retrieve the text field from associated objects
        guard let nameTextField = objc_getAssociatedObject(sender, UnsafeRawPointer(bitPattern: 1)!) as? UITextField,
              let name = nameTextField.text, !name.isEmpty else {
            // Show alert if name is empty
            let alert = UIAlertController(title: "Error", message: "Please enter your name", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            view?.window?.rootViewController?.present(alert, animated: true)
            return
        }
        
        // Save the name to UserDefaults
        UserDefaults.standard.set(name, forKey: "userFullName")
        UserDefaults.standard.synchronize()
        
        // Find and remove the name input overlay
        if let overlayView = view?.subviews.first(where: { $0.backgroundColor?.isEqual(UIColor.black.withAlphaComponent(0.7)) ?? false }) {
            UIView.animate(withDuration: 0.3, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
                
                // Create a new account on the backend
                self.createNewAccountOnBackend(username: name)
            }
        }
    }

    func createNewAccountOnBackend(username: String) {
        // Show loading indicator
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        // Create parameters for the new account
        let parameters: [String: Any] = [
            "username": username,
            "food": 0,
            "energy": 0,
            "goods": 0,
            "car": 0
        ]
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions") else {
            loadingView.removeFromSuperview()
            showAccountCreationError()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    loadingView.stopAnimation()
                    loadingView.removeFromSuperview()
                    
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error creating account: \(error)")
                        self.showAccountCreationError()
                        return
                    }
                    
                    if (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) {
                        // Account created successfully
                        self.showAccountCreationSuccess()
                        
                        // Initialize the emissions data
                        self.FOOD = 0
                        self.ENERGY = 0
                        self.GOODS = 0
                        self.dailyCarEmissions = 0
                        self.saveArrays()
                        
                        // Set up the home page
                        self.setupHomePage()
                    } else {
                        self.showAccountCreationError()
                    }
                }
            }.resume()
        } catch {
            loadingView.removeFromSuperview()
            showAccountCreationError()
        }
    }

    func showAccountCreationSuccess() {
        let alert = UIAlertController(title: "Success", message: "Your account has been created successfully!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view?.window?.rootViewController?.present(alert, animated: true)
    }

    func showAccountCreationError() {
        let alert = UIAlertController(title: "Error", message: "There was a problem creating your account. Please try again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        view?.window?.rootViewController?.present(alert, animated: true)
    }
    
    
    
    

    func removeSignInOverlay() {
        // Remove the overlay with animation
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayBlurView.alpha = 0
            self.signInOverlay.alpha = 0
        }) { _ in
            self.overlayBlurView.removeFromSuperview()
            self.signInOverlay.removeFromSuperview()
        }
    }
    
    @objc func doneButtonPressed() {
        guard let name = fullNameTextField?.text, !name.isEmpty else {
            print("No name entered")
            return
        }
        // Handle what happens when the done button is pressed
        doneButton?.isHidden = true
        fullNameTextField?.isHidden = true
        setupHomePage()
        
        // Save the name to UserDefaults
        UserDefaults.standard.set(name, forKey: "userFullName")
        UserDefaults.standard.synchronize()
        print("Saved name to UserDefaults: \(name)")

    }
    
    func showAppleSignInButton() {
        if let view = self.view {
            if isAuthenticated == false {
                let authorizationButton = ASAuthorizationAppleIDButton()
                authorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
                
                // Add the button to your view
                authorizationButton.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
                authorizationButton.center = view.center
                authorizationButton.tag = 100 // Add a tag for easy removal later
                view.addSubview(authorizationButton)
            }
            isAuthenticated = true

        }
    }
    
    func hideAppleSignInButton() {
        if let view = self.view {
            // Find the Apple Sign In button using its tag and remove it
            if let appleSignInButton = view.viewWithTag(100) {
                appleSignInButton.removeFromSuperview()
            }
        }
    }

    @objc func handleAuthorizationAppleIDButtonPress() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    

    
    func getDayLabels() -> [String] {
        let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 2  // Adjust so Monday is index 0
        var labels = [String]()
        for i in 0..<7 {
            let dayIndex = (todayIndex - i + 7) % 7  // Wrap around
            labels.append(daysOfWeek[dayIndex])
        }
        return labels.reversed()  // Reverse to match the histogram order
    }
    

    

    
    func setupMidnightTimer() {
        
        var calendar = Calendar.current
        calendar.timeZone = .pst
        let midnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)!
        let timer = Timer(fire: midnight, interval: 86400, repeats: true) { _ in
            self.performMidnightTasks()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    




    // Add this function to update ENERGY when driving ends
    func updateEnergyAfterDriving() {

    }
    
    func fetchUserEmissions(username: String) {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetUserEmissions?") else { return }
        
        let queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "days", value: "7")
        ]
        
        var urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        urlComps.queryItems = queryItems
        
        guard let finalURL = urlComps.url else { return }
        
        URLSession.shared.dataTask(with: finalURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching emissions: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                let emissionsData = try JSONDecoder().decode(EmissionsResponse.self, from: data)
                
                DispatchQueue.main.async {
                    // Update UI with latest emissions data
                    self.FOOD = emissionsData.emissions[emissionsData.latestDate]?.food ?? 0
                    self.GOODS = emissionsData.emissions[emissionsData.latestDate]?.goods ?? 0
                    self.dailyCarEmissions = Int(emissionsData.emissions[emissionsData.latestDate]?.carEmissions ?? 0)
                    
                    self.saveArrays()
                }
            } catch {
                print("Error decoding emissions data: \(error)")
            }
        }.resume()
    }
    
    func fetchUserHistory(completion: @escaping ([DailyEmissions]?) -> Void) {
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        guard let url = URL(string: "https://your-function-app-url/api/userhistory/\(userName)") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let userData = try? JSONDecoder().decode(UserScoreData.self, from: data) else {
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                self.dayByDay = userData.dailyHistory
                self.saveArrays()
                completion(userData.dailyHistory)
            }
        }.resume()
    }
    
    func setupDailyEnergyUpdate() {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = 21 // 9 PM
        dateComponents.minute = 30 // 30 minutes past the hour

        // Get the next 9:30 PM
        guard let nextUpdateTime = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .nextTime) else {
            print("Could not calculate next update time")
            return
        }

        // Calculate the time interval until the next 9:30 PM
        let timeInterval = nextUpdateTime.timeIntervalSinceNow

        // Create and schedule the timer
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.updateEnergyAfterDriving()
            self?.setupDailyEnergyUpdate() // Schedule the next day's update
        }
    }
    
    func sendDailyUpdate() {
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        let userScore = weekByWeek[4] + FOOD + ENERGY + GOODS + offsetGrams
        
        let parameters: [String: Any] = [
            "userId": userName,
            "weeklyScore": userScore,
            "dailyHistory": dayByDay.map { [
                "carEmissions": $0.carEmissions,
                "food": $0.food,
                "energy": $0.energy,
                "goods": $0.goods
            ]},
            "currentDayEmissions": [
                "carEmissions": dailyCarEmissions,
                "food": FOOD,
                "energy": ENERGY,
                "goods": GOODS
            ]
        ]
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/updateweeklyscore?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending daily update: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Daily update response status code: \(httpResponse.statusCode)")
            }
        }.resume()
    }

    func performMidnightTasks() {
        var calendar = Calendar.current
        calendar.timeZone = .pst
        let lastUpdate = UserDefaults.standard.object(forKey: "lastEmissionsUpdate") as? Date ?? Date()
        if !calendar.isDate(lastUpdate, inSameDayAs: Date()) {
            // Reset ALL daily emissions
            dailyCarEmissions = 0
            FOOD = 0
            ENERGY = 0
            GOODS = 0
            UserDefaults.standard.set(Date(), forKey: "lastEmissionsUpdate")
            
            // Send reset to backend FIRST
            updateEmissionsOnBackend()
            
            // Then save arrays
            saveArrays()
            
            // Clear cache AFTER reset is complete
            EmissionsCache.shared.clearCache()
            
            // Now fetch the fresh data
            if let username = UserDefaults.standard.string(forKey: "userFullName") {
                fetchUserEmissions(username: username)
            }
        }
    }
    
    func saveArrays() {
        UserDefaults.standard.set(ENERGY, forKey: "ENERGY")
        UserDefaults.standard.set(FOOD, forKey: "FOOD")
        UserDefaults.standard.set(GOODS, forKey: "GOODS")
        UserDefaults.standard.set(totalKg, forKey: "totalKg")
        UserDefaults.standard.set(dailyCarEmissions, forKey: "dailyCarEmissions")
        UserDefaults.standard.set(carbonOffsetsPurchased, forKey: "carbonOffsetsPurchased")
        UserDefaults.standard.set(offsetGrams, forKey: "offsetGrams")
        
        // Save daily history
        if let encoded = try? JSONEncoder().encode(dayByDay) {
            UserDefaults.standard.set(encoded, forKey: "dayByDay")
        }
        
        UserDefaults.standard.set(weekByWeek, forKey: "weekByWeek")
        UserDefaults.standard.synchronize()
        
        // Clear caches to force refresh on next fetch
        EmissionsCache.shared.clearCache()
        LeaderboardCache.shared.clearCache()
    }
    func loadArrays() {
        totalKg = UserDefaults.standard.integer(forKey: "totalKg")
        carbonOffsetsPurchased = UserDefaults.standard.integer(forKey: "carbonOffsetsPurchased")
        FOOD = UserDefaults.standard.integer(forKey: "FOOD")
        GOODS = UserDefaults.standard.integer(forKey: "GOODS")
        ENERGY = UserDefaults.standard.integer(forKey: "ENERGY")
        dailyCarEmissions = UserDefaults.standard.integer(forKey: "dailyCarEmissions")
        offsetGrams = UserDefaults.standard.integer(forKey: "offsetGrams")
        
        // Load dayByDay with proper error handling
        if let savedDayByDay = UserDefaults.standard.data(forKey: "dayByDay"),
           let decodedDayByDay = try? JSONDecoder().decode([DailyEmissions].self, from: savedDayByDay) {
            dayByDay = decodedDayByDay
        } else {
            // Initialize with default values if loading fails
            dayByDay = Array(repeating: DailyEmissions(carEmissions: 1, food: 1, energy: 1, goods: 1), count: 7)
        }
        
        // Load weekByWeek with proper initialization
        if let savedWeekByWeek = UserDefaults.standard.array(forKey: "weekByWeek") as? [Int] {
            weekByWeek = savedWeekByWeek
        } else {
            // Initialize with default values if loading fails
            weekByWeek = Array(repeating: 0, count: 5)
        }
        
        // Debug print
        print("Loaded dayByDay: \(dayByDay.map { $0.total })")
        print("Loaded weekByWeek: \(weekByWeek)")
    }
    
    func endDrivingSession() {
        let emissions = customLocationManager.calculateEmissions(
            distance: customLocationManager.totalDistance,
            duration: customLocationManager.totalDuration,
            carYear: carYear,
            carMake: carMake,
            carModel: carModel,
            carData: carData
        )
        
        // Update local state first
        self.dailyCarEmissions = Int(emissions)
        self.saveArrays()
        
        // Clear caches to force refresh
        EmissionsCache.shared.clearCache()
        
        // First get the weekly totals from EmissionsCache
        guard let username = UserDefaults.standard.string(forKey: "userFullName") else { return }
        
        EmissionsCache.shared.getEmissionsData(username: username) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let stats):
                let weeklyTotals = stats.weeklyHistory
                
                // Now update backend with correct weekly score
                let parameters: [String: Any] = [
                    "username": username,
                    "food": self.FOOD,
                    "energy": self.ENERGY,
                    "goods": self.GOODS,
                    "car": self.dailyCarEmissions,
                    "weeklyScore": weeklyTotals[0]  // Use weeklyTotals[0] which has the correct calculation
                ]
                
                guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                    
                    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                        if (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) {
                            // Refresh data after successful update
                            DispatchQueue.main.async {
                                self?.refreshAllViews()
                            }
                        } else {
                            print("Failed to update emissions: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }.resume()
                } catch {
                    print("Error serializing parameters: \(error)")
                }
                
            case .failure(let error):
                print("Failed to get emissions data: \(error)")
            }
        }
    }

    func refreshAllViews() {
        // Refresh histogram
        if let histogramView = histogramHostingController?.rootView as? HistogramView {
            displayHistogram()
        }
        
        // Refresh pie chart
        if let pieChartView = pieChartHostingController?.rootView as? PieChartView {
            showPieChart()
        }
        
        // Refresh leaderboard
        if let leaderboardView = hostingController?.rootView as? LeaderboardView {
            displayLeaderboard()
        }
    }
    

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
    
    func startSimulatedTrip() {
        customLocationManager.startTrackingDriving()
        customLocationManager.isDriving = true
    }
    
// BACKEND CDOMMUNICATION -------------------------

    // Add this method to handle location updates


    
    func sendScore(name: String, score: Int, completion: @escaping (Bool) -> Void) {
        // Replace with your Azure Function endpoint
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions?") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "username": name,
            "food": FOOD,
            "energy": ENERGY,
            "goods": GOODS,
            "car": dailyCarEmissions
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing JSON: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending score: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }

    
    
    

    
    private func fetchAndDisplayLeaderboard() {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetLeaderboard?") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching leaderboard data: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let leaderboardData = try JSONDecoder().decode(LeaderboardResponse.self, from: data)
                    // Note: The backend will handle the sorting in ascending order
                    let leaderboardView = LeaderboardView(leaderboardData: leaderboardData.leaderboard)
                    self.hostingController?.rootView = leaderboardView
                    
                } catch {
                    print("Error decoding leaderboard data: \(error)")
                }
            }
        }.resume()
    }
    

    


// NOTIS -------------------------------------------------
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    

    func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        // Schedule notification for midnight update
        let midnightContent = UNMutableNotificationContent()
        midnightContent.sound = nil // Silent notification
        midnightContent.title = "" // Empty title
        midnightContent.userInfo = ["type": "midnight_update"]
        
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let midnightRequest = UNNotificationRequest(
            identifier: "midnight_update",
            content: midnightContent,
            trigger: trigger
        )
        
        // Schedule the regular daily report notification
        let reportContent = UNMutableNotificationContent()
        reportContent.title = "Daily Carbon Emission Report"
        //reportContent.body = generateDailyReport()
        reportContent.sound = .default
        
        dateComponents.hour = 22 // 10 PM
        let reportTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let reportRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: reportContent,
            trigger: reportTrigger
        )
        
        // Schedule both notifications
        center.add(midnightRequest) { error in
            if let error = error {
                print("Failed to schedule midnight notification: \(error)")
            }
        }
        
        center.add(reportRequest) { error in
            if let error = error {
                print("Failed to schedule report notification: \(error)")
            }
        }
    }
    
    func setupNotificationHandler() {
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permission if not already granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    //func generateDailyReport() -> String {

        //let yesterday = Int(dayByDay[5].carEmissions)+dayByDay[5].energy+dayByDay[5].food+dayByDay[5].goods
        //let today = Int(dayByDay[6].carEmissions)+dayByDay[6].energy+dayByDay[6].food+dayByDay[6].goods
        
        //if yesterday>today {
            //return "Today, your carbon footprint was \(today) grams, which is \(yesterday-today) grams less than yesterday."
        //}
        //return "Today, your carbon footprint was \(today) grams, which is \(today-yesterday) grams more than yesterday."
    //}
    
    func updateDrivingStatusLabel() {
        // Safely update the label text based on driving status
        drivingStatusLabel?.isHidden = false
        if let drivingStatusLabel = drivingStatusLabel {
            drivingStatusLabel.text = customLocationManager.isDriving ? "Driving: Yes" : "Driving: No"
//            print(customLocationManager.isDriving)
            drivingStatusLabel.fontColor = customLocationManager.isDriving ? .green : .red
        }
    }
    
    @objc func handleDrivingStatusChanged() {
        if !locationTracker.isDriving {
            // Get the emissions from the last driving interval
            let emissions = locationTracker.calculateAndPrintEmissions()
            print("Driving stopped. Emissions: \(emissions) grams")
            
            // Update local storage
            dailyCarEmissions += Int(emissions)
            saveArrays()
            
            // Update UI
            updateUIWithNewEmissions()
            
            // Send to backend
            updateEmissionsOnBackend()
        }
    }
    
    func updateEmissionsOnBackend() {
        let username = UserDefaults.standard.string(forKey: "userFullName") ?? "DefaultUser"
        
        // First, fetch the latest data from the backend
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetUserEmissions") else { return }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "username", value: username)]
        
        guard let fetchUrl = components?.url else { return }
        
        // Show a small loading indicator if needed
        let loadingTag = 9999
        if let existingLoading = self.view?.viewWithTag(loadingTag) {
            existingLoading.removeFromSuperview()
        }
        
        print("Fetching latest emission values before update...")
        
        URLSession.shared.dataTask(with: fetchUrl) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching latest emissions: \(error)")
                self.sendLocalEmissionsToBackend(username: username)
                return
            }
            
            guard let data = data else {
                print("No data received when fetching emissions")
                self.sendLocalEmissionsToBackend(username: username)
                return
            }
            
            do {
                // Decode the response to get the latest values
                let stats = try JSONDecoder().decode(UserStats.self, from: data)
                
                // Get today's date in the format used by the backend
                let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
                let todayString = String(today)
                
                // Get the latest values for today
                if let todayEmissions = stats.emissions[todayString] {
                    // Use the backend values for FOOD, ENERGY, GOODS
                    let parameters: [String: Any] = [
                        "username": username,
                        "food": todayEmissions.food,
                        "energy": todayEmissions.energy,
                        "goods": todayEmissions.goods,
                        "car": self.dailyCarEmissions  // Use our local car emissions value
                    ]
                    
                    self.sendUpdatedEmissionsToBackend(parameters: parameters)
                } else {
                    // If no data for today, use our local values
                    self.sendLocalEmissionsToBackend(username: username)
                }
                
            } catch {
                print("Error decoding emissions data: \(error)")
                self.sendLocalEmissionsToBackend(username: username)
            }
        }.resume()
    }

    // Helper method to send local values
    private func sendLocalEmissionsToBackend(username: String) {
        let parameters: [String: Any] = [
            "username": username,
            "food": self.FOOD,
            "energy": self.ENERGY,
            "goods": self.GOODS,
            "car": self.dailyCarEmissions
        ]
        
        sendUpdatedEmissionsToBackend(parameters: parameters)
    }

    // Helper method to send the actual request
    private func sendUpdatedEmissionsToBackend(parameters: [String: Any]) {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            
            print("Sending updated emissions to backend with car: \(parameters["car"] ?? "unknown")")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("Error updating emissions: \(error)")
                    return
                }
                
                if (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) {
                    print("Emissions updated successfully on backend")
                    
                    // Update local values to match what was sent
                    DispatchQueue.main.async {
                        self?.FOOD = parameters["food"] as? Int ?? self?.FOOD ?? 0
                        self?.ENERGY = parameters["energy"] as? Int ?? self?.ENERGY ?? 0
                        self?.GOODS = parameters["goods"] as? Int ?? self?.GOODS ?? 0
                        // Don't update dailyCarEmissions since that's what we just sent
                        
                        // Clear cache to force refresh on next fetch
                        EmissionsCache.shared.clearCache()
                    }
                }
            }.resume()
        } catch {
            print("Error serializing parameters: \(error)")
        }
    }
    
    func updateUIWithNewEmissions() {
        // Update histograms and charts if they're currently displayed
        if pieChartHostingController != nil {
            showPieChart()
        }
        
        if histogramHostingController != nil {
            displayHistogram()
        }
        
        // Update profile if displayed
        updateProfile()
    }

    func updateLocalEmissions(emissions: Double) {
        // Update the last day and week values
        //dayByDay[dayByDay.count - 1] += Int(emissions)
        //weekByWeek[weekByWeek.count - 1] += Int(emissions)
        //allTimeEmissions += Int(emissions)
        
        // Update the histograms, pie chart, and leaderboard
    }


    
    func presentLocationPermissionAlert() {
        let alert = UIAlertController(title: "Location Permission", message: "This app needs access to your location to provide a personalized experience.", preferredStyle: .alert)
        
        let allowAction = UIAlertAction(title: "Allow", style: .default) { _ in
            self.requestLocationPermission()  // Request location permission when user taps "Allow"
        }
        
        let denyAction = UIAlertAction(title: "Deny", style: .cancel) { _ in
            // Handle the denial if needed
            self.showCarInputFields()  // Show input fields even if location permission is denied
        }
        
        alert.addAction(allowAction)
        alert.addAction(denyAction)
        
        if let view = self.view, let viewController = view.window?.rootViewController {
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    
    
    func requestLocationPermission() {
        customLocationManager.requestLocationPermission()
        showCarInputFields()  // Show input fields after requesting location permission
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // This method will be called with real-time location updates
        guard let location = locations.last else { return }
    }
    
    func showCarInputFields() {
        hideAppleSignInButton()
        enterCarLabel.isHidden = false
        // Create and configure UIPickerViews
        yearPickerView = createPickerView()
        makePickerView = createPickerView()
        modelPickerView = createPickerView()
        
        // Create and configure UIStackView for horizontal layout
        let hStackView = UIStackView(arrangedSubviews: [yearPickerView, makePickerView, modelPickerView])
        hStackView.axis = .horizontal
        hStackView.alignment = .center
        hStackView.distribution = .fillEqually
        hStackView.spacing = 0
        
        // Set the frame and position of the hStackView
        hStackView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        view?.addSubview(hStackView)
        
        // Add constraints to center the hStackView
        hStackView.centerXAnchor.constraint(equalTo: view!.centerXAnchor).isActive = true
        hStackView.centerYAnchor.constraint(equalTo: view!.centerYAnchor).isActive = true
        hStackView.widthAnchor.constraint(equalTo: view!.widthAnchor, multiplier: 1).isActive = true
        hStackView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        
        // Create and configure UIButton
        confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        view?.addSubview(confirmButton)
        
        if let firstYear = years.first {
            carYear = firstYear
            makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
            if let firstMake = makes.first {
                carMake = firstMake
                models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
                carModel = models.first ?? ""
            }
        }

        yearPickerView.selectRow(0, inComponent: 0, animated: false)
        makePickerView.selectRow(0, inComponent: 0, animated: false)
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
        
        // Add constraints to position the confirmButton below the hStackView
        confirmButton.centerXAnchor.constraint(equalTo: view!.centerXAnchor).isActive = true
        confirmButton.topAnchor.constraint(equalTo: hStackView.bottomAnchor, constant: 20).isActive = true
        confirmButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        confirmButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // Set the data source and delegate of the pickers
        yearPickerView.dataSource = self
        yearPickerView.delegate = self
        makePickerView.dataSource = self
        makePickerView.delegate = self
        modelPickerView.dataSource = self
        modelPickerView.delegate = self
    }
    
    func createPickerView() -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        return pickerView
    }
    
    @objc func confirmButtonTapped() {
        print("Confirmed car: \(carYear) \(carMake) \(carModel)")
        endDrivingSession()
        // Save the selected car information
        enterCarLabel.isHidden = true
        UserDefaults.standard.set(carYear, forKey: "carYear")
        UserDefaults.standard.set(carMake, forKey: "carMake")
        UserDefaults.standard.set(carModel, forKey: "carModel")
        locationTracker.setCarDetails(year: carYear, make: carMake, model: carModel, list: carData)
        startSimulatedTrip()
        
        // Update car info on the server
        let username = UserDefaults.standard.string(forKey: "userFullName") ?? "DefaultUser"
        self.yearPickerView.isHidden = true
        self.makePickerView.isHidden = true
        self.modelPickerView.isHidden = true
        self.confirmButton.isHidden = true
        self.fullNameTextField!.isHidden = false
        self.fullNameTextField!.becomeFirstResponder()
        self.doneButton!.isHidden = false
    }
    
    @objc func donateCarbonCredits() {
        let purchaseView = CarbonOffsetPurchaseView(
            isPresented: .constant(true),
            allTimeEmissions: $allTimeEmissions, // Use a binding to the class property
            onPurchase: { quantity, kgPerUnit in
                self.purchaseCarbonOffsets(quantity: quantity, kgPerUnit: kgPerUnit)
            },
            onCancel: {
                self.dismissCarbonOffsetPurchaseScreen()
                self.profileButtonTapped()
            },
            updateProfile: self.updateProfile
        )
        
        carbonOffsetPurchaseHostingController = UIHostingController(rootView: purchaseView)
        
        if let hostingController = carbonOffsetPurchaseHostingController, let view = self.view {
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: view.bounds.height - 200)
            view.addSubview(hostingController.view)
            
            // Animate the presentation
            hostingController.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                hostingController.view.alpha = 1
            }
            
            // Hide the donate button
            if let donateButton = view.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Buy Carbon Offsets" }) as? UIButton {
                donateButton.isHidden = true
            }
        }
    }

    func purchaseCarbonOffsets(quantity: Int, kgPerUnit: Int) {
        hideAppleSignInButton()
        let offsetGrams = quantity * kgPerUnit * 1000
        let parameters: [String: Any] = [
            "userId": UserDefaults.standard.string(forKey: "userFullName") ?? "",
            "offsetGrams": offsetGrams
        ]
        

    }
    


    
    func dismissCarbonOffsetPurchaseScreen() {
        if let hostingController = carbonOffsetPurchaseHostingController {
            UIView.animate(withDuration: 0.3, animations: {
                hostingController.view.alpha = 0
            }) { _ in
                hostingController.view.removeFromSuperview()
                self.carbonOffsetPurchaseHostingController = nil
                
                // Show the donate button again
                if let donateButton = self.view?.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Buy Carbon Offsets" }) as? UIButton {
                    donateButton.isHidden = false
                }
            }
        }
    }
    
    @objc func showFullLeaderboard() {
        // Existing leaderboard display code

        displayLeaderboard()
    }
    
    

    @objc func showFullHistogram() {
        displayHistogram()
    }

    @objc func showFullPieChart() {
        showPieChart()
    }

    @objc func profileButtonTapped() {
        if self.profileHostingController != nil { return }
        
        // Hide all previews and other views
        homeButtonTapped()
        stackView.isHidden = true
        previewWindows.forEach { $0.isHidden = true }
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        
        // Show profile immediately with loading state
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        let carDetails = "\(carYear) \(carMake) \(carModel)"
        
        // Create initial profile view with loading state
        let profileView = ProfileView(
            username: userName,
            allTimeEmissions: self.allTimeEmissions,
            dailyEmissionsAverage: 0, // Will update
            carDetails: carDetails,
            leaderboardPosition: 0, // Will update
            carbonCreditsPurchased: self.carbonOffsetsPurchased,
            totalKg: self.totalKg
        )
        
        // Show the view immediately
        self.profileHostingController = UIHostingController(rootView: profileView)
        
        if let view = self.view {
            setupProfileUI(in: view)
            
            // Update data asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let daysTracked = max(1, self.weekByWeek.filter { $0 > 0 }.count * 7)
                let dailyAverage = Double(self.allTimeEmissions) / Double(daysTracked)
                
                self.getLeaderboardPosition { position in
                    DispatchQueue.main.async {
                        // Update the profile view with actual data
                        let updatedProfileView = ProfileView(
                            username: userName,
                            allTimeEmissions: self.allTimeEmissions,
                            dailyEmissionsAverage: dailyAverage,
                            carDetails: carDetails,
                            leaderboardPosition: position,
                            carbonCreditsPurchased: self.carbonOffsetsPurchased,
                            totalKg: self.totalKg
                        )
                        self.profileHostingController?.rootView = updatedProfileView
                    }
                }
            }
        }
    }

    private func setupProfileUI(in view: UIView) {
        guard let hostingController = self.profileHostingController else { return }
        
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(
            x: 20,
            y: 100,
            width: view.bounds.width - 40,
            height: view.bounds.height - 250
        )
        
        view.addSubview(hostingController.view)
        
        // Create "Delete Account" button (red)
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete Account", for: .normal)
        deleteButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.backgroundColor = .systemRed
        deleteButton.layer.cornerRadius = 10
        deleteButton.addTarget(self, action: #selector(self.deleteAccountButtonTapped), for: .touchUpInside)
        
        // Create "Sign Out" button (light green)
        let signOutButton = UIButton(type: .system)
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        signOutButton.setTitleColor(.white, for: .normal)
        signOutButton.backgroundColor = UIColor(red: 144/255, green: 238/255, blue: 144/255, alpha: 1.0) // Light green
        signOutButton.layer.cornerRadius = 10
        signOutButton.addTarget(self, action: #selector(self.signOutButtonTapped), for: .touchUpInside)
        
        // Position the buttons
        deleteButton.frame = CGRect(
            x: 20,
            y: hostingController.view.frame.maxY - 100, // Position above the sign out button
            width: view.bounds.width - 40,
            height: 50
        )
        
        signOutButton.frame = CGRect(
            x: 20,
            y: hostingController.view.frame.maxY - 40,
            width: view.bounds.width - 40,
            height: 50
        )
        
        // Animate the presentation
        hostingController.view.alpha = 0
        deleteButton.alpha = 0
        signOutButton.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1
            deleteButton.alpha = 1
            signOutButton.alpha = 1
            view.backgroundColor = .black
        }
        
        view.addSubview(deleteButton)
        view.addSubview(signOutButton)
        
        // Update the carLabel
        self.carLabel.text = "My Profile"
    }
    
    @objc func signOutButtonTapped() {
        // Show confirmation alert
        let alert = UIAlertController(title: "Sign Out",
                                     message: "Are you sure you want to sign out? This will clear all your local data.",
                                     preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.performSignOut()
        })
        
        view?.window?.rootViewController?.present(alert, animated: true)
    }

    func performSignOut() {
        // Clear user-related data from UserDefaults
        let userDefaultsKeys = [
            "userFullName",
            "carYear",
            "carMake",
            "carModel",
            "ENERGY",
            "FOOD",
            "GOODS",
            "totalKg",
            "dailyCarEmissions",
            "carbonOffsetsPurchased",
            "offsetGrams",
            "dayByDay",
            "weekByWeek"
        ]
        
        for key in userDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // Reset local variables
        carYear = ""
        carMake = ""
        carModel = ""
        ENERGY = 0
        FOOD = 0
        GOODS = 0
        dailyCarEmissions = 0
        totalKg = 0
        carbonOffsetsPurchased = 0
        offsetGrams = 0
        dayByDay = Array(repeating: DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0), count: 7)
        weekByWeek = [0, 0, 0, 0, 0]
        
        // Clear caches
        EmissionsCache.shared.clearCache()
        LeaderboardCache.shared.clearCache()
        
        // Dismiss profile view and clear UI
        if let hostingController = self.profileHostingController {
            UIView.animate(withDuration: 0.3, animations: {
                hostingController.view.alpha = 0
                self.view?.backgroundColor = .white
            }) { _ in
                hostingController.view.removeFromSuperview()
                self.profileHostingController = nil
                
                // Clear all UIKit subviews except the basic scene nodes
                self.view?.subviews.forEach { $0.removeFromSuperview() }
                
                // Make sure nodes are shown
                self.welcome.isHidden = false
                self.ecotrack.isHidden = true
                self.background.isHidden = false
                
                // Recreate the Get Started button first
                self.createGetStartedButton()
                
                // Then show the full Get Started screen (which includes About Us)
                self.showGetStartedScreen()
            }
        } else {
            // If profile view is not showing
            self.view?.subviews.forEach { $0.removeFromSuperview() }
            
            // Make sure nodes are shown
            self.welcome.isHidden = false
            self.ecotrack.isHidden = true
            self.background.isHidden = false
            
            // Recreate the Get Started button first
            self.createGetStartedButton()
            
            // Then show the full Get Started screen
            self.showGetStartedScreen()
        }
    }
    
    func createGetStartedButton() {
        guard let view = self.view else { return }
        
        // Create a new Get Started button
        getStartedButton = UIButton(type: .system)
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 24)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.backgroundColor = .systemGreen
        getStartedButton.layer.cornerRadius = 10
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(getStartedButton)
        
        // Position the button in the center of the screen
        NSLayoutConstraint.activate([
            getStartedButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            getStartedButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            getStartedButton.widthAnchor.constraint(equalToConstant: 200),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Make sure the button is visible
        getStartedButton.isHidden = false
    }
    
    @objc func deleteAccountButtonTapped() {
        // Show confirmation alert
        let alert = UIAlertController(title: "Delete Account",
                                     message: "Are you sure you want to delete your account? This action cannot be undone.",
                                     preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            // Simply perform the same actions as sign out
            self?.performSignOut()
            
            // Show success message
            let alert = UIAlertController(title: "Account Deleted",
                                         message: "Your account has been deleted.",
                                         preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.view?.window?.rootViewController?.present(alert, animated: true)
        })
        
        view?.window?.rootViewController?.present(alert, animated: true)
    }

    func performDeleteAccount() {
        // Show loading indicator
        let loadingViewController = showLoadingView(withMessage: "Deleting account...")
        
        // Get the username
        guard let username = UserDefaults.standard.string(forKey: "userFullName") else {
            hideLoadingView(loadingViewController)
            return
        }
        
        // Call API to delete the account on the server
        deleteAccountOnBackend(username: username) { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingView(loadingViewController)
                
                if success {
                    // If successful, perform the same actions as sign out
                    self.performSignOut()
                    
                    // Show success message
                    let alert = UIAlertController(title: "Account Deleted",
                                                 message: "Your account has been successfully deleted.",
                                                 preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.view?.window?.rootViewController?.present(alert, animated: true)
                } else {
                    // Show error message
                    let alert = UIAlertController(title: "Error",
                                                 message: "Failed to delete your account. Please try again later.",
                                                 preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.view?.window?.rootViewController?.present(alert, animated: true)
                }
            }
        }
    }

    func deleteAccountOnBackend(username: String, completion: @escaping (Bool) -> Void) {
        // Create the request URL
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/DeleteUser") else {
            completion(false)
            return
        }
        
        // Create the request parameters
        let parameters: [String: Any] = [
            "username": username
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert parameters to JSON data
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing delete request parameters: \(error)")
            completion(false)
            return
        }
        
        // Make the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error deleting account: \(error)")
                completion(false)
                return
            }
            
            // Check the response status code
            if let httpResponse = response as? HTTPURLResponse {
                completion((200...299).contains(httpResponse.statusCode))
            } else {
                completion(false)
            }
        }.resume()
    }
    
    func recreateGetStartedButton() {
        guard let view = self.view else { return }
        
        // Create a new Get Started button
        getStartedButton = UIButton(type: .system)
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 24)
        getStartedButton.setTitleColor(.white, for: .normal)
        getStartedButton.backgroundColor = .systemGreen
        getStartedButton.layer.cornerRadius = 10
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(getStartedButton)
        
        // Position the button in the center of the screen
        NSLayoutConstraint.activate([
            getStartedButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            getStartedButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            getStartedButton.widthAnchor.constraint(equalToConstant: 200),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Make sure the button is visible
        getStartedButton.isHidden = false
    }






    @objc func dismissProfile() {
        if let hostingController = self.profileHostingController {
            UIView.animate(withDuration: 0.3, animations: {
                hostingController.view.alpha = 0
                self.view?.backgroundColor = .white
            }) { _ in
                hostingController.view.removeFromSuperview()
                self.profileHostingController = nil
                self.setupHomePage()
            }
        }
    }
    
    func getLeaderboardPosition(completion: @escaping (Int) -> Void) {
        // Return cached value if less than 1 minute old
        if let position = cachedLeaderboardPosition,
           let lastFetch = lastLeaderboardFetch,
           Date().timeIntervalSince(lastFetch) < 60 {
            completion(position)
            return
        }
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetLeaderboard?") else {
            completion(0)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let data = data,
               let leaderboardData = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
                // Change sorting order to ascending (lowest first)
                let sortedLeaderboard = leaderboardData.sorted { $0.weeklyScore < $1.weeklyScore }
                let position = sortedLeaderboard.firstIndex(where: {
                    $0.userId == UserDefaults.standard.string(forKey: "userFullName")
                }).map { $0 + 1 } ?? 0
                
                self.cachedLeaderboardPosition = position
                self.lastLeaderboardFetch = Date()
                completion(position)
            } else {
                completion(0)
            }
        }.resume()
    }
    
    
    
    func setupHomePage() {
        hideAppleSignInButton()
        welcome.isHidden = true
        getStartedButton.isHidden = true
        ecotrack.isHidden = true
        // Clear existing views
        self.view?.subviews.forEach { $0.removeFromSuperview() }
        dismissProfile()
        // Set the main view background to white
        self.view?.backgroundColor = .white
        
        // Create a vertical stack view for the preview windows
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create preview windows
        let pieChartWindow = createPreviewWindow(title: "Breakdown", imageName: "piechart", action: #selector(pieChartTapped))
        let histogramWindow = createPreviewWindow(title: "Progress", imageName: "histogram", action: #selector(histogramTapped))
        let leaderboardWindow = createPreviewWindow(title: "Leaderboard", imageName: "leaderboard", action: #selector(leaderboardTapped))
        previewWindows = [pieChartWindow, histogramWindow, leaderboardWindow]
        stackView.addArrangedSubview(pieChartWindow)
        stackView.addArrangedSubview(histogramWindow)
        stackView.addArrangedSubview(leaderboardWindow)
        self.view?.addSubview(stackView)
        
        // Create home button (black, bottom left)
        homeButton = UIButton(type: .system)
        homeButton.setImage(UIImage(systemName: "house.fill"), for: .normal)
        homeButton.tintColor = .black  // Set the color to black
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        self.view?.addSubview(homeButton)
        
        // Create profile button (bottom right)
        let profileButton = createIconButton(imageName: "person.fill", action: #selector(profileButtonTapped))
        self.view?.addSubview(profileButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: self.view!.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: self.view!.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: homeButton.topAnchor, constant: -20),
            
            homeButton.leadingAnchor.constraint(equalTo: self.view!.leadingAnchor, constant: 20),
            homeButton.bottomAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            homeButton.widthAnchor.constraint(equalToConstant: 44),
            homeButton.heightAnchor.constraint(equalToConstant: 44),
            
            profileButton.trailingAnchor.constraint(equalTo: self.view!.trailingAnchor, constant: -20),
            profileButton.bottomAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 44),
            profileButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // Helper function to create preview windows
    func createPreviewWindow(title: String, imageName: String, action: Selector) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.lightGray.cgColor
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold) // Increased font size from 12 to 16
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let contentView: UIView
        let sampledaily = [3, 7, 2, 5, 8, 4, 6]
        let sampleweekly = [20, 25, 18, 30, 22]
        
        if title == "Progress" {
            let histogramPreview = HistogramPreview(dayByDay: sampledaily, weekByWeek: sampleweekly)
            contentView = UIHostingController(rootView: histogramPreview).view
        } else {
            contentView = UIImageView(image: UIImage(named: imageName))
            (contentView as? UIImageView)?.contentMode = .scaleAspectFit
        }
        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        container.addGestureRecognizer(tapGesture)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10), // Increased top padding
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10), // Increased spacing
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5)
        ])
        
        return container
    }
    
    @objc func drivingStatusChanged() {
        DispatchQueue.main.async {
            self.updateDrivingStatusLabel()
        }
    }
    
    @objc func pieChartTapped() {
        hidePreviews {
            self.showFullPieChart()
        }
    }

    @objc func histogramTapped() {
        hidePreviews {
            self.showFullHistogram()
        }
    }

    @objc func leaderboardTapped() {
        hidePreviews {
            self.showFullLeaderboard()
        }
    }
    
    func hidePreviews(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.stackView.alpha = 0
            self.previewWindows.forEach { $0.alpha = 0 }
        }) { _ in
            self.stackView.isHidden = true
            self.previewWindows.forEach { $0.isHidden = true }
            completion()
        }
    }

    // Helper function to create icon buttons
    func createIconButton(imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    func fetchOtherUserEmissions() -> [(String, Double)] {
        // This should return an array of tuples with username and emissions
        // For now, we'll return dummy data
        return [("User1", 100.0), ("User2", 150.0), ("User3", 200.0)]
    }
    
    func fetchWeeklyEmissions(completion: @escaping (WeeklyEmissions?) -> Void) {
        guard let userID = UserDefaults.standard.string(forKey: "userFullName"),
              let url = URL(string: "https://your-function-app/api/weekly/\(userID)") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let weeklyData = try? JSONDecoder().decode(WeeklyEmissions.self, from: data) else {
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                completion(weeklyData)
            }
        }.resume()
    }

    struct WeeklyEmissions: Codable {
        let carEmissions: Int
        let food: Int
        let energy: Int
        let goods: Int
        let offsetGrams: Int
        
        var total: Int {
            return carEmissions + food + energy + goods - offsetGrams
        }
    }

    @objc func homeButtonTapped() {
        dismissProfile()
        print("Home Button Tapped")
        
        // Remove views
        if let profileWindow = self.view?.viewWithTag(100) {
            profileWindow.removeFromSuperview()
        }
        
        [self.hostingController, self.pieChartHostingController, self.histogramHostingController].forEach { controller in
            controller?.view.removeFromSuperview()
            controller?.removeFromParent()
        }
        
        // Setup the home page
        setupHomePage()
        
        // Show the preview windows again
        stackView.isHidden = false
        previewWindows.forEach { $0.isHidden = false }
        UIView.animate(withDuration: 0.3) {
            self.stackView.alpha = 1
            self.previewWindows.forEach { $0.alpha = 1 }
            self.view?.backgroundColor = .white
        }
        
        // Reset the carLabel text
        carLabel.text = "EcoTrack"
        
        // Hide other buttons that might be visible
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        progress.isHidden = true
        // Bring progress label to front
    }


    
    
    func showNewButtons() {
        // Create and configure the 'View Leaderboard' button
        carLabel.text = "Main Menu"
        viewLeaderboardButton.setTitle("View Leaderboard", for: .normal)
        viewLeaderboardButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)  // Set font
        viewLeaderboardButton.setTitleColor(.white, for: .normal)
        viewLeaderboardButton.addTarget(self, action: #selector(viewLeaderboardButtonTapped), for: .touchUpInside)
        viewLeaderboardButton.isHidden = false
        
        // Create and configure the 'My Progress' button
        
        myProgressButton.setTitle("My Progress", for: .normal)
        myProgressButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)  // Set font
        myProgressButton.setTitleColor(.white, for: .normal)
        myProgressButton.addTarget(self, action: #selector(myProgressButtonTapped), for: .touchUpInside)
        myProgressButton.isHidden = false
        
        
        // Create and configure the 'My Badges' button
        
        
        myBadgesButton.setTitle("Today's Emissions", for: .normal)
        myBadgesButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)
        myBadgesButton.setTitleColor(.white, for: .normal)
        myBadgesButton.addTarget(self, action: #selector(todaysEmissionsButtonTapped), for: .touchUpInside)
        myBadgesButton.isHidden = false
        
        // Add buttons to the view
        if let view = self.view {
            // Create a vertical stack view to hold the buttons
            let vStackView = UIStackView(arrangedSubviews: [viewLeaderboardButton, myProgressButton, myBadgesButton])
            vStackView.axis = .vertical
            vStackView.alignment = .center
            vStackView.distribution = .equalSpacing
            vStackView.spacing = 20
            vStackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(vStackView)
            NSLayoutConstraint.activate([
                vStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                vStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                viewLeaderboardButton.widthAnchor.constraint(equalToConstant: 200),
                myProgressButton.widthAnchor.constraint(equalToConstant: 200),
                myBadgesButton.widthAnchor.constraint(equalToConstant: 200)
            ])
        }
    }
    
    @objc func todaysEmissionsButtonTapped() {
        showPieChart()
    }

    @objc func viewLeaderboardButtonTapped() {
        //let userEmissions = 0  // User's emissions are initially set to 0
        let randomEmissions1 = Int.random(in: 0...500)
        let randomEmissions2 = Int.random(in: 0...500)
        let randomEmissions3 = Int.random(in: 0...500)
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        // Store other users' emissions for display
        let otherUserEmissions = [randomEmissions1, randomEmissions2, randomEmissions3]
        displayLeaderboard()
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)

    }

    @objc func myProgressButtonTapped() {
        carLabel.text = "My Progress"
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        
        // Create and display the histogram
        displayHistogram()
        
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
    }
    
    func handleDrivingStopped() {
        let emissions = locationTracker.calculateAndPrintEmissions()
        dailyCarEmissions += Int(emissions)
        UserDefaults.standard.set(dailyCarEmissions, forKey: "dailyCarEmissions")
        UserDefaults.standard.synchronize()
        endDrivingSession()
    }

    func updateWeeklyHistogram() {
        //let weeklyEmissions = calculateWeeklyEmissions()  // Calculate the sum of the week // Store the weekly emissions in the last index
        print("weekByWeek updated: \(weekByWeek)")
    }
    



    
    func displayHistogram() {
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        guard let username = UserDefaults.standard.string(forKey: "userFullName") else {
            loadingView.removeFromSuperview()
            print("No username found")
            return
        }
        
        EmissionsCache.shared.getEmissionsData(username: username) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                loadingView.stopAnimation()
                loadingView.removeFromSuperview()
                
                switch result {
                case .success(let stats):
                    // Pass the reversed weekly history
                    let histogramView = HistogramView(
                        dayByDay: stats.dailyHistory,
                        weekByWeek: stats.weeklyHistory.reversed()
                    )
                    self.histogramHostingController = UIHostingController(rootView: histogramView)
                    
                    if let hostingController = self.histogramHostingController, let view = self.view {
                        let width: CGFloat = view.bounds.width * 0.9
                        let height: CGFloat = view.bounds.height * 0.7
                        let x = (view.bounds.width - width) / 2
                        let y = (view.bounds.height - height) / 2
                        
                        hostingController.view.frame = CGRect(x: x, y: y, width: width, height: height)
                        hostingController.view.tag = 101
                        view.addSubview(hostingController.view)
                    }
                    
                case .failure(let error):
                    print("Failed to load histogram data: \(error)")
                    // Show error in game scene
                    if let viewController = self.view?.window?.rootViewController {
                        let alert = UIAlertController(title: "Error",
                                                      message: "Failed to load data. Please try again.",
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        viewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    

    func displayLeaderboard() {
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        LeaderboardCache.shared.getLeaderboardData { [weak self] result in
            DispatchQueue.main.async {
                loadingView.stopAnimation()
                loadingView.removeFromSuperview()
                
                switch result {
                case .success(let leaderboardData):
                    let leaderboardView = LeaderboardView(leaderboardData: leaderboardData)
                    self?.hostingController = UIHostingController(rootView: leaderboardView)
                    
                    if let view = self?.view {
                        let width: CGFloat = view.bounds.width * 0.9
                        let height: CGFloat = view.bounds.height * 0.7
                        let x = (view.bounds.width - width) / 2
                        let y = (view.bounds.height - height) / 2
                        
                        self?.hostingController?.view.frame = CGRect(x: x, y: y, width: width, height: height)
                        self?.hostingController?.view.layer.cornerRadius = 10
                        self?.hostingController?.view.clipsToBounds = true
                        view.addSubview(self?.hostingController!.view ?? UIView())
                    }
                    
                case .failure(let error):
                    print("Error loading leaderboard: \(error)")
                    if let viewController = self?.view?.window?.rootViewController {
                        let alert = UIAlertController(title: "Error",
                                                    message: "Failed to load leaderboard. Please try again.",
                                                    preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        viewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    func setupBackgroundTasks() {
        // Register for hourly background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.ecotrack.hourlyupdate", using: nil) { task in
            let drivingMinutes = self.locationTracker.getLastHourDrivingMinutes()
            //let hourlyEnergy = 600 - (10 * drivingMinutes)
            
            // Update ENERGY
            //self.ENERGY += max(0, hourlyEnergy)
            
            // Update backend
            self.updateBackendWithNewEnergy()
            
            // Schedule next task
            self.scheduleNextHourlyUpdate()
            
            task.setTaskCompleted(success: true)
        }
        
        // Start the schedule
        scheduleNextHourlyUpdate()
    }

    func scheduleNextHourlyUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: "com.ecotrack.hourlyupdate")
        
        // Calculate time until next hour
        let calendar = Calendar.current
        let now = Date()
        if let nextHour = calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) {
            request.earliestBeginDate = nextHour
            
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("Could not schedule hourly update: \(error)")
            }
        }
    }

    func handleHourlyUpdate(completion: @escaping (Bool) -> Void) {

    }
    
    func updateBackendWithNewEnergy() {
        let parameters: [String: Any] = [
            "username": UserDefaults.standard.string(forKey: "userFullName") ?? "",
            "food": self.FOOD,
            "energy": self.ENERGY,
            "goods": self.GOODS,
            "car": self.dailyCarEmissions
        ]
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            
            URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                if let error = error {
                    print("Error updating emissions: \(error)")
                    return
                }
                
                if (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) {
                    // Success - update local cache
                    EmissionsCache.shared.clearCache()
                }
            }.resume()
        } catch {
            print("Error serializing parameters: \(error)")
        }
    }
    
    func sendScoreAndFetchLeaderboard(userName: String) {
        // Remove local score calculation since backend will handle it
        self.sendScore(name: userName, score: 0) { success in
            if success {
                self.fetchAndDisplayLeaderboard()
            } else {
                print("Failed to send score")
            }
        }
    }
    


    // Define a struct to match the backend's data structure
    struct LeaderboardEntry: Codable {
        let username: String
        let total_emissions: Double

        // If you still need to use userId and weeklyScore in your views,
        // you can add computed properties
        var userId: String { username }
        var weeklyScore: Double { total_emissions }
    }
    
    struct LeaderboardResponse: Codable {
        let leaderboard: [LeaderboardEntry]
    }

    struct LeaderboardView: View {
        let leaderboardData: [LeaderboardEntry]
        
        var body: some View {
            VStack {
                Text("Leaderboard")
                    .font(.title)
                    .padding()
                List(leaderboardData.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .font(.headline)
                            .frame(width: 30, alignment: .leading)
                        
                        Text(leaderboardData[index].userId)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(Int(leaderboardData[index].weeklyScore))")
                            .font(.body)
                    }
                    .listRowBackground(
                        isCurrentUser(leaderboardData[index].userId) ?
                            Color.green.opacity(0.2) :
                            Color.clear
                    )
                }
            }
        }
        
        private func isCurrentUser(_ userId: String) -> Bool {
            let currentUser = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
            return userId == currentUser
        }
    }

    struct HistogramView: View {
        let dayByDay: [DailyEmissions]
        let weekByWeek: [Int]
        @State private var currentPage = 0
        
        var body: some View {
            VStack {
                TabView(selection: $currentPage) {
                    DailyHistogram(emissions: dayByDay)
                        .tag(0)
                    
                    WeeklyHistogram(data: weekByWeek)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<2) { index in
                        Circle()
                            .fill(currentPage == index ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    struct DailyHistogram: View {
        let emissions: [DailyEmissions]
        
        // Use the exact backend data
        private var normalizedEmissions: [DailyEmissions] {
            let emptyEmission = DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0)
            var result = Array(repeating: emptyEmission, count: 7)
            
            // Ensure we only display the last 7 days of data
            // Ensure we only display the last 7 days of data
            let recentEmissions = emissions.suffix(7)
            for (i, emission) in recentEmissions.enumerated() {
                // Place the most recent emission (last in the array) at index 6 (rightmost)
                let index = 6 - (recentEmissions.count - 1 - i)
                if index >= 0 {
                    result[index] = emission
                }
            }
            
            return result
        }
        
        var maxEmission: Int {
            normalizedEmissions.map { $0.total }.max() ?? 1
        }
        
        var body: some View {
            VStack {
                Text("Past 7 Days")
                    .font(.title)
                    .padding()
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7) { index in
                        VStack {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 40, height: 200)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 40, height: CGFloat(normalizedEmissions[index].total) / CGFloat(maxEmission) * 200)
                            }
                            Text(DailyHistogram.getDayLabel(for: index))
                                .font(.caption)
                            Text("\(normalizedEmissions[index].total)")
                                .font(.system(size: 8))
                        }
                    }
                }
                .padding()
                
                Text("Daily Emissions in grams CO2")
                    .font(.caption)
                    .padding()
            }
        }
        
        static func getDayLabel(for index: Int) -> String {
            let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            var calendar = Calendar.current
            calendar.timeZone = .pst
            let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
            return daysOfWeek[(todayIndex - (6 - index) + 7) % 7]
        }
    }
    


    struct WeeklyHistogram: View {
        let data: [Int]  // This should now contain properly processed weekly data
        
        private var maxEmission: Int {
            return data.max() ?? 1
        }
        
        var body: some View {
            VStack {
                Text("Past 5 Weeks")
                    .font(.system(size: 30))
                    .padding()
                
                HStack(alignment: .bottom, spacing: 20) {
                    ForEach(0..<5) { index in
                        VStack {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 50, height: 200)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 50, height: data[index] > 0 ? CGFloat(data[index]) / CGFloat(maxEmission) * 200 : 0)
                            }
                            Text("Week \(5 - index)")
                                .font(.system(size: 10))
                            Text("\(data[index])")
                                .font(.system(size: 8))
                        }
                    }
                }
                .padding()
                
                Text("Weekly Emissions in grams CO2")
                    .font(.system(size: 12))
                    .padding()
            }
        }
    }


    func createProgressLabel() -> UILabel {
        let label = UILabel(frame: CGRect(x: 30, y: 100, width: 200, height: 30))
        label.text = "Progress"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.isHidden = true // Initially hidden
        return label
    }
    

    
    // Implement UITextFieldDelegate methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Handle the event when text field editing begins
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Handle the event when text field editing ends
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Handle the event when return key is pressed
        textField.resignFirstResponder()
        return true
    }
}

extension TimeZone {
    static let pst = TimeZone(identifier: "America/Los_Angeles")!
}

// Conform to UIPickerViewDataSource and UIPickerViewDelegate
extension GameScene: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case yearPickerView:
            return years.count
        case makePickerView:
            return makes.count
        case modelPickerView:
            return models.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case yearPickerView:
            return years[row]
        case makePickerView:
            return makes[row]
        case modelPickerView:
            return models[row]
        default:
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case yearPickerView:
            carYear = years[row]
            makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
            print("Selected Year: \(carYear), Available Makes: \(makes)")
            makePickerView.reloadAllComponents()
            makePickerView.selectRow(0, inComponent: 0, animated: false)
            carMake = makes.first ?? ""
            updateModels()
        case makePickerView:
            if row < makes.count {
                carMake = makes[row]
                print("Selected Make: \(carMake)")
                updateModels()
            } else {
                print("Error: Selected row \(row) is out of bounds for makes array with count \(makes.count)")
            }
        case modelPickerView:
            if row < models.count {
                carModel = models[row]
                print("Selected Model: \(carModel)")
            } else {
                print("Error: Selected row \(row) is out of bounds for models array with count \(models.count)")
            }
        default:
            break
        }
    }

    func updateModels() {
        models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
        print("Available Models: \(models)")
        modelPickerView.reloadAllComponents()
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
        carModel = models.first ?? ""
    }
}
extension GameScene {
    

    
    func showPickerViews() {
        // Remove any existing picker views
        yearPickerView?.removeFromSuperview()
        makePickerView?.removeFromSuperview()
        modelPickerView?.removeFromSuperview()
        
        // Create and setup picker views

        // Show the car label
        carLabel.isHidden = false
        carLabel.fontName = "AvenirNext-Bold"
        carLabel.zPosition = 2
        carLabel.fontColor = SKColor.white
        
        // Request location permission
        presentLocationPermissionAlert()
    }
    

    
    func updateEmissions(username: String, emissions: EmissionData) {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/UpdateEmissions?") else { return }
        
        let parameters: [String: Any] = [
            "username": userFullName,
            "food": emissions.food,
            "energy": emissions.energy,
            "goods": emissions.goods,
            "car": emissions.car
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error updating emissions: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Update emissions response: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    struct DailyEmissions: Codable {
        var carEmissions: Int
        var food: Int
        var energy: Int
        var goods: Int
        
        var total: Int {
            return carEmissions + food + energy + goods
        }
        
        enum CodingKeys: String, CodingKey {
            case carEmissions = "car"
            case food
            case energy
            case goods
        }
    }

    struct UserScoreData: Codable {
        let userId: String
        let weeklyScore: Int
        let dailyHistory: [DailyEmissions]
        let currentDayEmissions: DailyEmissions
    }
    
    struct UserStats: Codable {
        var username: String
        var emissions: [String: DailyEmissions]
        var weeklyHistory: [Int] = [0, 0, 0, 0, 0]  // Add this property
        
        // Computed properties to provide the data in the format your views expect
        var weeklyScore: Double = 0  // Change this to a variable
        
        var dailyHistory: [DailyEmissions] {
            // Sort dates and get last 7 days of emissions
            let sortedDates = emissions.keys.sorted()
            let last7Days = sortedDates.suffix(7)
            return last7Days.map { emissions[$0] ?? DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0) }
        }
        
        var currentDayEmissions: DailyEmissions {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
            return emissions[String(today)] ?? DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0)
        }
    }
    
    struct EmissionsResponse: Codable {
        let username: String
        let emissions: [String: DailyEmissions]
        
        var latestDate: String {
            return emissions.keys.sorted().last ?? ""
        }
    }

    struct EmissionData: Codable {
        let food: Int
        let energy: Int
        let goods: Int
        let car: Int
    }
    
    class LeaderboardCache {
        static let shared = LeaderboardCache()
        
        private let cacheExpirationInterval: TimeInterval = 1200 // 5 minutes
        private var lastFetchTime: Date?
        private var cachedLeaderboardData: [LeaderboardEntry]?
        private var isLoading: Bool = false
        
        func getLeaderboardData(forceRefresh: Bool = false, completion: @escaping (Result<[LeaderboardEntry], Error>) -> Void) {
            // Return cached data if valid
            if !forceRefresh,
               let lastFetch = lastFetchTime,
               let cachedData = cachedLeaderboardData,
               Date().timeIntervalSince(lastFetch) < cacheExpirationInterval {
                completion(.success(cachedData))
                return
            }
            
            guard !isLoading else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.getLeaderboardData(forceRefresh: forceRefresh, completion: completion)
                }
                return
            }
            
            isLoading = true
            
            guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetLeaderboard") else {
                isLoading = false
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                defer { self?.isLoading = false }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(LeaderboardResponse.self, from: data)
                    let leaderboardData = response.leaderboard
                        .filter { $0.userId != "Not found" }
                        .sorted { $0.weeklyScore < $1.weeklyScore }
                    
                    self?.cachedLeaderboardData = leaderboardData
                    self?.lastFetchTime = Date()
                    completion(.success(leaderboardData))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
        
        func clearCache() {
            cachedLeaderboardData = nil
            lastFetchTime = nil
        }
    }
    
    class EmissionsCache {
        static let shared = EmissionsCache()
        
        private let cacheExpirationInterval: TimeInterval = 1200 // 5 minutes
        private var lastFetchTime: Date?
        private var cachedEmissionsData: UserStats?
        private var isLoading: Bool = false
        
        // In EmissionsCache class
        private func processWeeklyData(emissions: [String: DailyEmissions]) -> [Int] {
            let calendar = Calendar.current
            let today = Date()
            var weeklyTotals = [0, 0, 0, 0, 0]

            // Get start of current week (Monday)
            let weekStart = calendar.nextDate(
                after: today,
                matching: DateComponents(weekday: 2), // Monday is weekday 2 in the Gregorian calendar
                matchingPolicy: .previousTimePreservingSmallerComponents
            )!
            
            // Sort dates in descending order (newest first)
            let sortedDates = emissions.keys.sorted(by: >)
            
            for dateStr in sortedDates {
                guard let date = ISO8601DateFormatter().date(from: dateStr + "T00:00:00Z") else { continue }
                let emission = emissions[dateStr]!
                
                // Calculate weeks difference
                let weekDiff = calendar.dateComponents([.weekOfYear], from: date, to: weekStart).weekOfYear ?? 0
                
                // If date is in the past 5 weeks
                if weekDiff >= 0 && weekDiff < 5 {
                    let total = emission.carEmissions + emission.food + emission.energy + emission.goods
                    weeklyTotals[weekDiff] += total
                }
            }
            
            print("Weekly totals calculated: \(weeklyTotals)")
            return weeklyTotals
        }
        
        func getEmissionsData(username: String, forceRefresh: Bool = false, completion: @escaping (Result<UserStats, Error>) -> Void) {
            guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/GetUserEmissions") else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.queryItems = [
                URLQueryItem(name: "username", value: username)
            ]
            
            guard let finalUrl = urlComponents?.url else { return }
            
            URLSession.shared.dataTask(with: finalUrl) { data, response, error in
                // Error handling code remains the same
                
                do {
                    var stats = try JSONDecoder().decode(UserStats.self, from: data!)
                    
                    let calendar = Calendar.current
                    var weeklyTotals = [0, 0, 0, 0, 0]
                    
                    // Sort dates from newest to oldest
                    let sortedDates = stats.emissions.keys.sorted(by: >)
                    
                    // Get today's date
                    let today = Date()
                    
                    // Find this Monday (the Monday of the current week)
                    var todayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
                    todayComponents.weekday = 2 // Monday is weekday 2 in Gregorian calendar
                    let thisMonday = calendar.date(from: todayComponents)!
                    
                    print("Today: \(today), This Monday: \(thisMonday)")
                    
                    // Process each date
                    for dateStr in sortedDates {
                        guard let date = ISO8601DateFormatter().date(from: dateStr + "T00:00:00Z") else { continue }
                        
                        // Get the Monday of this date's week
                        var dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                        dateComponents.weekday = 2 // Monday
                        let dateMonday = calendar.date(from: dateComponents)!
                        
                        // Calculate weeks difference
                        let weeksDiff = calendar.dateComponents([.weekOfYear], from: dateMonday, to: thisMonday).weekOfYear ?? 0
                        
                        // If within the last 5 weeks
                        if weeksDiff >= 0 && weeksDiff < 5 {
                            let emission = stats.emissions[dateStr]!
                            let dailyTotal = emission.carEmissions + emission.food + emission.energy + emission.goods
                            weeklyTotals[weeksDiff] += dailyTotal
                            print("Date: \(dateStr), Week: \(weeksDiff + 1), Monday: \(dateMonday), Daily Total: \(dailyTotal)")
                        }
                    }
                    
                    print("Final weekly totals: \(weeklyTotals)")
                    stats.weeklyHistory = weeklyTotals
                    stats.weeklyScore = Double(weeklyTotals[0])  // Current week's total
                    
                    completion(.success(stats))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }
        
        func clearCache() {
            cachedEmissionsData = nil
            lastFetchTime = nil
        }
    }

}
extension GameScene {

    func showPieChart() {
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        guard let username = UserDefaults.standard.string(forKey: "userFullName") else {
            loadingView.removeFromSuperview()
            print("No username found")
            return
        }
        
        EmissionsCache.shared.getEmissionsData(username: username) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                loadingView.stopAnimation()
                loadingView.removeFromSuperview()
                
                switch result {
                case .success(let stats):
                    // Get today's date in the format used by the backend
                    let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
                    let todayString = String(today)
                    
                    // Get current day's emissions from the stats
                    let currentDayEmissions = stats.emissions[todayString] ?? DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0)
                    
                    let pieChartView = PieChartView(
                        userEmissions: currentDayEmissions.carEmissions, // Use car emissions from the response
                        food: currentDayEmissions.food,
                        energy: currentDayEmissions.energy,
                        goods: currentDayEmissions.goods
                    )
                    
                    print("Debug - Pie Chart Values:")
                    print("Car Emissions: \(currentDayEmissions.carEmissions)")
                    print("Food: \(currentDayEmissions.food)")
                    print("Energy: \(currentDayEmissions.energy)")
                    print("Goods: \(currentDayEmissions.goods)")
                    
                    self.pieChartHostingController = UIHostingController(rootView: pieChartView)
                    
                    if let view = self.view {
                        let width: CGFloat = view.bounds.width * 0.9
                        let height: CGFloat = view.bounds.height * 0.7
                        let x = (view.bounds.width - width) / 2
                        let y = (view.bounds.height - height) / 2
                        
                        self.pieChartHostingController?.view.frame = CGRect(x: x, y: y, width: width, height: height)
                        self.pieChartHostingController?.view.tag = 100
                        view.addSubview(self.pieChartHostingController!.view)
                    }
                    
                case .failure(let error):
                    print("Failed to load pie chart data: \(error)")
                    if let viewController = self.view?.window?.rootViewController {
                        let alert = UIAlertController(title: "Error",
                                                    message: "Failed to load data. Please try again.",
                                                    preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        viewController.present(alert, animated: true)
                    }
                }
            }
        }
    }
}

struct PieChartPreview: View {
    let userEmissions: Int
    let food: Int
    let energy: Int
    let goods: Int
    
    var body: some View {
        PieChartView(userEmissions: userEmissions, food: food, energy: energy, goods: goods)
            .frame(width: 100, height: 100)
            .background(Color.white) // Changed from Color.black to Color.white
    }
}

// Histogram Preview
struct HistogramPreview: View {
    let dayByDay: [Int]
    let weekByWeek: [Int]
    
    var body: some View {
        GeometryReader { outerGeometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7) { index in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: outerGeometry.size.width * 0.9 / 9,
                               height: CGFloat(dayByDay[index]) / CGFloat(dayByDay.max() ?? 1) * outerGeometry.size.height * 0.63)
                }
            }
            .frame(width: outerGeometry.size.width * 0.9, height: outerGeometry.size.height * 0.9, alignment: .bottom)
            .position(x: outerGeometry.size.width / 2, y: outerGeometry.size.height * 0.4) // Changed from 0.6 to 0.5
        }
    }
}


// Leaderboard Preview
struct LeaderboardPreview: View {
    let userEmissions: (String, Double)
    let otherEmissions: [(String, Double)]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<min(5, otherEmissions.count + 1), id: \.self) { index in
                    if index < otherEmissions.count && otherEmissions[index].1 > userEmissions.1 {
                        EmissionBar(username: otherEmissions[index].0,
                                    emission: otherEmissions[index].1,
                                    maxEmission: otherEmissions[0].1,
                                    width: geometry.size.width,
                                    height: geometry.size.height / 5)
                    } else {
                        EmissionBar(username: userEmissions.0,
                                    emission: userEmissions.1,
                                    maxEmission: otherEmissions[0].1,
                                    width: geometry.size.width,
                                    height: geometry.size.height / 5)
                            .foregroundColor(.green)
                            .background(Color.white) // Changed from Color.black to Color.white
                    }
                }
            }
        }
        .background(Color.white) // Added this line to ensure the entire preview has a white background
    }
}



struct EmissionBar: View {
    let username: String
    let emission: Double
    let maxEmission: Double
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: CGFloat(emission / maxEmission) * width * 0.8, height: height)
            Text(username.prefix(3))
                .font(.system(size: 10))
                .frame(width: width * 0.2, alignment: .leading)
                .foregroundColor(.white) // Added this line to ensure text is visible on white background
        }
        .background(Color.white) // Added this line to ensure the entire bar has a white background
    }
}



struct ProfileView: View {
    let username: String
    @State var allTimeEmissions: Int
    let dailyEmissionsAverage: Double
    let carDetails: String
    let leaderboardPosition: Int
    let carbonCreditsPurchased: Int
    let totalKg: Int  // Changed from carbonOffsetsKg to totalKg

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile: \(username)")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Car: \(carDetails)")
                Text("KGs of CO2 removed (Carbon Offsets):(\(totalKg) kg)")  // Modified this line
            }
            .font(.body)
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}


struct CarbonOffsetPurchaseView: View {
    @Binding var isPresented: Bool
    @Binding var allTimeEmissions: Int
    var onPurchase: (Int, Int) -> Void
    var onCancel: () -> Void
    var updateProfile: () -> Void
    
    @State private var selectedOption: Int? = nil
    @State private var quantity: String = ""
    @State private var showingPaymentSheet = false
    
    private let paymentHandler = PaymentHandler()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Buy Carbon Offsets")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                Button(action: { selectedOption = 400 }) {
                    HStack {
                        Text("400 kg for $7.99")
                        Spacer()
                        if selectedOption == 400 {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .background(selectedOption == 400 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                
                Button(action: { selectedOption = 30 }) {
                    HStack {
                        Text("30 kg for $0.99")
                        Spacer()
                        if selectedOption == 30 {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .background(selectedOption == 30 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                
                HStack {
                    Text("Quantity:")
                    TextField("Enter quantity", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(selectedOption == nil)
                        .opacity(selectedOption == nil ? 0.5 : 1)
                }
                .padding(.top)
                
                if let selected = selectedOption, let qty = Int(quantity), !quantity.isEmpty {
                    ApplePayButton(type: .buy, style: .black) {
                        let amount = selected == 400 ? 7.99 : 0.99
                        let totalAmount = amount * Double(qty)
                        paymentHandler.startPayment(amount: totalAmount) { success in
                            if success {
                                onPurchase(qty, selected)
                                allTimeEmissions -= qty * selected // Decrease allTimeEmissions
                                updateProfile()
                                isPresented = false
                            }
                        }
                    }
                    .frame(height: 45)
                    .disabled(selectedOption == nil || quantity.isEmpty)
                }
                
                Button(action: {
                    isPresented = false
                    onCancel()
                }) {
                    Text("Cancel")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
}

struct LoadingView: View {
    @State private var isSpinning = false
    @State private var isPulsing = false
    let message: String
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            // Loading container
            VStack {
                ZStack {
                    // Spinning circle
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .rotationEffect(Angle(degrees: isSpinning ? 360 : 0))
                        .animation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)
                    
                    // Logo
                    Image("leaf_logo") // Make sure to add your logo to Assets.xcassets
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                }
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 8)
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
        }
        .onAppear {
            isSpinning = true
            isPulsing = true
        }
    }
}

// Helper extension for GameScene
extension GameScene {
    func showLoadingView(withMessage message: String) -> UIViewController {
        let loadingView = LoadingView(message: message)
        let hostingController = UIHostingController(rootView: loadingView)
        hostingController.view.backgroundColor = .clear
        
        if let view = self.view {
            hostingController.view.frame = view.bounds
            view.addSubview(hostingController.view)
        }
        
        return hostingController
    }
    
    func hideLoadingView(_ loadingViewController: UIViewController) {
        DispatchQueue.main.async {
            loadingViewController.view.removeFromSuperview()
        }
    }
}




struct ApplePayButton: UIViewRepresentable {
    var type: PKPaymentButtonType
    var style: PKPaymentButtonStyle
    var action: () -> Void
    
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        var action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            action()
        }
    }
}

class PaymentHandler: NSObject {
    
    var paymentCompletion: ((Bool) -> Void)?
    
    func startPayment(amount: Double, completion: @escaping (Bool) -> Void) {
        self.paymentCompletion = completion
        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = "merchant.com.ecotrack"
        paymentRequest.supportedNetworks = [.visa, .masterCard, .amex]
        paymentRequest.supportedCountries = ["US", "CA"]
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        
        let carbonOffset = PKPaymentSummaryItem(label: "Carbon Offset", amount: NSDecimalNumber(value: amount))
        paymentRequest.paymentSummaryItems = [carbonOffset]
        
        let controller = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        if let controller = controller {
            controller.delegate = self
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(controller, animated: true, completion: nil)
            }
        }
    }
}

extension PaymentHandler: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Process the payment here
        // For this example, we'll just simulate a successful payment
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        self.paymentCompletion?(true)
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.dismiss(animated: true, completion: nil)
        }
        // If the payment wasn't successful (e.g., user cancelled), call the completion handler with false
        if self.paymentCompletion != nil {
            self.paymentCompletion?(false)
            self.paymentCompletion = nil
        }
    }
}
extension Notification.Name {
    static let drivingStatusChanged = Notification.Name("drivingStatusChanged")
}

extension GameScene: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Retrieve the user's email
            if let email = appleIDCredential.email {
                // Save the email to UserDefaults
                UserDefaults.standard.set(email, forKey: "UserEmail")
                print("User Email saved: \(email)")
            } else {
                print("Email is not available.")
            }
            // Check if car details are already saved
            if UserDefaults.standard.string(forKey: "carYear") == nil ||
               UserDefaults.standard.string(forKey: "carMake") == nil ||
               UserDefaults.standard.string(forKey: "carModel") == nil {
                // Car details are not saved, show the car input fields
                DispatchQueue.main.async {
                    self.showCarInputFields()
                }
            } else {
                // Car details are already saved, proceed to the home page
                DispatchQueue.main.async {
                    self.setupHomePage()
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle sign-in error
        print("Apple ID authorization failed: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension GameScene: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view!.window!
    }
}

class LoadingDotsView: UIView {
    private var dotViews: [UIView] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var loadingLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
        setupDots()
        startAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
        setupDots()
        startAnimation()
    }
    
    private func setupLabel() {
        loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        loadingLabel.text = "Loading"
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: 14)
        addSubview(loadingLabel)
    }
    
    private func setupDots() {
        for i in 0..<3 {
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            dot.backgroundColor = .white
            dot.layer.cornerRadius = 5
            dot.center = CGPoint(x: center.x + CGFloat(i - 1) * 20, y: center.y)
            addSubview(dot)
            dotViews.append(dot)
        }
        centerDotsAndLabel()
    }
    
    private func centerDotsAndLabel() {
        // Center label above dots
        loadingLabel.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2 - 35)
        
        // Center dots below label
        let totalWidth = CGFloat(dotViews.count - 1) * 20
        let startX = (bounds.width - totalWidth) / 2
        
        for (index, dot) in dotViews.enumerated() {
            dot.center = CGPoint(x: startX + CGFloat(index) * 20, y: bounds.height / 2 + 10)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        centerDotsAndLabel()
    }
    
    private func startAnimation() {
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateAnimation() {
        let elapsed = CACurrentMediaTime() - startTime
        
        for (index, dot) in dotViews.enumerated() {
            let delay = Double(index) * 0.2
            let y = -10 * sin(2 * .pi * (elapsed - delay))
            dot.transform = CGAffineTransform(translationX: 0, y: y)
        }
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    deinit {
        stopAnimation()
    }
}
extension GameScene: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier == "midnight_update" {
            // Check if it's Monday
            let calendar = Calendar.current
            if calendar.component(.weekday, from: Date()) == 2 {
                // It's Monday, reset to 0
                self.lastNightWeeklyScore = 0
            } else {
                // Not Monday, store current weekly score
                self.lastNightWeeklyScore = Double(self.weekByWeek[4])
            }
            UserDefaults.standard.synchronize()
            
            // Perform midnight tasks
            self.performMidnightTasks()
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
extension UIDevice {
    static var isIPad10thGeneration: Bool {
        // iPad 10th gen has model identifier "iPad13,18" or "iPad13,19"
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String(validatingUTF8: ptr)
            }
        }
        
        // Check for iPad 10th generation model identifiers
        return modelCode == "iPad13,18" || modelCode == "iPad13,19" ||
               // For Simulator testing:
               (UIDevice.current.userInterfaceIdiom == .pad &&
                UIScreen.main.bounds.size.height == 2360 &&
                UIScreen.main.bounds.size.width == 1640)
    }
}

