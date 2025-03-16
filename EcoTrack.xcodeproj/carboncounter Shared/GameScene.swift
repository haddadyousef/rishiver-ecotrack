import SpriteKit
import SwiftUI
import UIKit
import CoreLocation
import UserNotifications
import Foundation

class GameScene: SKScene, UITextFieldDelegate, CLLocationManagerDelegate {
    
    fileprivate var label: SKLabelNode?
    fileprivate var spinnyNode: SKShapeNode?
    var welcome = SKLabelNode()
    var startScreen = true
    var getStarted = SKLabelNode()
    var carLabel = SKLabelNode()
    var background = SKSpriteNode(imageNamed: "background")
    var homeButton: UIButton!
    var dayByDay = [0, 0, 0, 0, 0, 0, 0]
    var weekByWeek = [0, 0, 0, 0, 0]
    var stackView: UIStackView!
    var previewWindows: [UIView] = []
    var ENERGY = 10000
    var FOOD = 5000
    var GOODS = 10000
    private let locationTracker = LocationManager()
    var histogramHostingController: UIHostingController<HistogramView>?
    var pieChartHostingController: UIHostingController<PieChartView>?
    var ecotrack = SKLabelNode()
    var viewLeaderboardButton = UIButton(type: .system)

    
    var myProgressButton = UIButton(type: .system)
    var myBadgesButton = UIButton(type: .system)
    var hostingController: UIHostingController<LeaderboardView>?
    
    
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
    
    // Leaderboard variables
    var leaderboardLabel: SKLabelNode!
    var CalculateduserEmissions: Int = 0
    var otherUserEmissions = [Int]()
    
    func loadCSVFile() {
        let csvFilePath = "/Users/neven/Downloads/caremissions.csv"
        
        do {
            let csvContent = try String(contentsOfFile: csvFilePath, encoding: .utf8)
            let rows = csvContent.components(separatedBy: "\n")
            
            for (index, row) in rows.enumerated() {
                if index == 0 { continue } // Skip header row
                let columns = row.components(separatedBy: ",")
                if columns.count == 4 {
                    carData.append(columns)
                }
            }
            
            years = Array(Set(carData.map { $0[0] })).sorted()
            
        } catch {
            print("Failed to read the CSV file: \(error)")
        }
    }
    
    override func didMove(to view: SKView) {
        loadArrays()
        setupMidnightTimer()
        super.didMove(to: view)
        
        // Setup welcome and get started labels
        welcome.text = "Welcome to your personal carbon accountant"
        welcome.zPosition = 2
        welcome.fontSize = 16
        welcome.position = CGPoint(x: 0, y: 250)
        welcome.fontColor = SKColor.white
        welcome.fontName = "AvenirNext-Bold"
        addChild(welcome)
        
        getStarted.text = "Get Started"
        getStarted.fontSize = 20
        getStarted.position = CGPoint(x: 0, y: 200)
        getStarted.fontColor = SKColor.white
        getStarted.zPosition = 2
        getStarted.fontName = "AvenirNext-Bold"
        addChild(getStarted)

        
        ecotrack.text = "EcoTrack"
        ecotrack.fontSize = 30
        ecotrack.position = CGPoint(x:0, y:-350)
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
        
        homeButton = UIButton(type: .custom)
        let homeImage = UIImage(named: "EcoTracker")
        homeButton.setImage(homeImage, for: .normal)
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        let username = UserDefaults.standard.string(forKey: "username") ?? "User\(Int.random(in: 1000...9999))"
            createUser(username: username) { success in
                if success {
                    print("User created or already exists")
                    UserDefaults.standard.set(username, forKey: "username")
                } else {
                    print("Failed to create user")
                }
            }
        
        if let view = self.view {
            view.addSubview(homeButton)
            
            NSLayoutConstraint.activate([
                homeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                homeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                homeButton.widthAnchor.constraint(equalToConstant: 50),
                homeButton.heightAnchor.constraint(equalTo: homeButton.widthAnchor, multiplier: homeImage!.size.height / homeImage!.size.width)
            ])
        }

            
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
        locationTracker.loadGPXFile()  // Load GPX data
        locationTracker.startTrackingDriving()

        // Load GPX file
        customLocationManager.loadGPXFile()

    }
    
    
    func showGetStartedScreen() {
        // Show the welcome and get started labels
        welcome.isHidden = false
        getStarted.isHidden = false
    }
    
    func setupMidnightTimer() {
        // Get the current date and time
        let now = Date()
        
        // Calculate the next midnight
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            print("Error calculating next midnight")
            return
        }
        
        // Calculate the time interval until the next midnight
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        // Create and schedule the timer
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.performMidnightTasks()
            // Set up the next timer
            self?.setupMidnightTimer()
        }
    }
    
    func performMidnightTasks() {
        // Shift dayByDay array
        dayByDay.removeFirst()
        dayByDay.append(0)
        
        // Check if it's Monday (weekday == 2 in Calendar)
        let calendar = Calendar.current
        if calendar.component(.weekday, from: Date()) == 2 {
            // Shift weekByWeek array
            weekByWeek.removeFirst()
            weekByWeek.append(0)
        }
        
        // Optional: Save the updated arrays to UserDefaults
        saveArrays()
    }
    
    func saveArrays() {
        UserDefaults.standard.set(dayByDay, forKey: "dayByDay")
        UserDefaults.standard.set(weekByWeek, forKey: "weekByWeek")
    }

    func loadArrays() {
        if let savedDayByDay = UserDefaults.standard.array(forKey: "dayByDay") as? [Int] {
            dayByDay = savedDayByDay
        }
        if let savedWeekByWeek = UserDefaults.standard.array(forKey: "weekByWeek") as? [Int] {
            weekByWeek = savedWeekByWeek
        }
    }
    
    func endDrivingSession() {
        customLocationManager.isDriving = true
        if customLocationManager.isDriving {
            let emissions = customLocationManager.calculateEmissions(distance: customLocationManager.totalDistance, duration: customLocationManager.totalDuration, carYear: carYear, carMake: carMake, carModel: carModel, carData: carData)
            CalculateduserEmissions = Int(emissions)
            
            // Update dayByDay array (today's emissions)
            dayByDay[6] = CalculateduserEmissions
            
            // Update weekByWeek array (this week's emissions)
            weekByWeek[4] += CalculateduserEmissions
            
            // Save the updated arrays
            saveArrays()
            
            print("Total emissions: \(emissions) grams")
            
            // Update emissions on the server
            let username = UserDefaults.standard.string(forKey: "username") ?? "DefaultUser"
            updateEmissions(username: username, emissions: Float(CalculateduserEmissions)) { success in
                if success {
                    print("Emissions updated on server successfully")
                } else {
                    print("Failed to update emissions on server")
                }
            }
            
            customLocationManager.isDriving = false
            customLocationManager.totalDistance = 0
            customLocationManager.totalDuration = 0
        }
    }
    

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            
            if startScreen == true && getStarted.contains(location) {
                presentLocationPermissionAlert()
                welcome.isHidden = true
                getStarted.isHidden = true
                carLabel.isHidden = false
                carLabel.fontName = "AvenirNext-Bold"
                carLabel.zPosition = 2
                carLabel.fontColor = SKColor.white
            }
        }
    }
    
    func startSimulatedTrip() {
        customLocationManager.startTrackingDriving()
    }

    // Add this method to handle location updates

    
    func fetchWeeklyEmissions(completion: @escaping ([(String, Double)]?) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/weekly_emissions") else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching weekly emissions: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data returned")
                completion(nil)
                return
            }
            
            do {
                if let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    let userEmissionsList = jsonResult.compactMap { dict -> (String, Double)? in
                        guard let username = dict["username"] as? String,
                              let emissions = dict["weekly_emissions"] as? Double else {
                            return nil
                        }
                        return (username, emissions)
                    }
                    completion(userEmissionsList)
                } else {
                    print("Could not parse JSON")
                    completion(nil)
                }
            } catch {
                print("Error decoding data: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    struct UserEmissions: Codable {
        let username: String
        let weekly_emissions: Int
    }
    
    struct LeaderboardView: View {
        let userEmissions: Int
        let otherUserEmissions: [(String, Double)]
        
        var body: some View {
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your Emissions: \(userEmissions) g")
                        .foregroundColor(.black)
                }
                .padding()
                .background(Color.blue.opacity(0.6))
                .cornerRadius(10)
                
                Divider()
                    .background(Color.black)
                
                ScrollView {
                    ForEach(otherUserEmissions, id: \.0) { username, emissions in
                        HStack {
                            Text(username)
                                .foregroundColor(.black)
                            Spacer()
                            Text("\(emissions, specifier: "%.2f") g")
                                .foregroundColor(.black)
                        }
                        .padding()
                        .background(Color.green.opacity(0.6))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            //.background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }

    
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
        center.removeAllPendingNotificationRequests()  // Remove previous notifications if any
        
        // Create content for the notification
        let content = UNMutableNotificationContent()
        content.title = "Daily Carbon Emission Report"
        content.body = generateDailyReport()
        content.sound = .default
        
        // Create a trigger to fire the notification daily at a specific time
        var dateComponents = DateComponents()
        dateComponents.hour = 22  // 10 PM
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // Schedule the request with the system
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func generateDailyReport() -> String {
        let totalEmissions = customLocationManager.calculateEmissions(distance: customLocationManager.totalDistance, duration: customLocationManager.totalDuration, carYear: carYear, carMake: carMake, carModel: carModel, carData: carData)
        let distanceInMiles = customLocationManager.totalDistance / 1609.34
        
        return "Today, you drove \(distanceInMiles) miles and your carbon emissions were \(totalEmissions) grams."
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
        UserDefaults.standard.set(carYear, forKey: "carYear")
        UserDefaults.standard.set(carMake, forKey: "carMake")
        UserDefaults.standard.set(carModel, forKey: "carModel")
        locationTracker.setCarDetails(year: carYear, make: carMake, model: carModel, list: carData)
        locationTracker.startGPXSimulation()
        startSimulatedTrip()
        
        // Update car info on the server
        let username = UserDefaults.standard.string(forKey: "username") ?? "DefaultUser"
        updateCarInfo(username: username) { success in
            DispatchQueue.main.async {
                if success {
                    print("Car info updated on server successfully")
                } else {
                    print("Failed to update car info on server")
                }
                
                // Hide the pickers and confirm button
                self.yearPickerView.isHidden = true
                self.makePickerView.isHidden = true
                self.modelPickerView.isHidden = true
                self.confirmButton.isHidden = true
                
                // Show the home page
                self.setupHomePage()
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
        // Implement profile view
        print("Profile button tapped")
    }
    
    func setupHomePage() {
        
        // Clear existing views
        self.view?.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a vertical stack view for the preview windows
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create preview windows
        let pieChartWindow = createPreviewWindow(title: "Emissions", imageName: "piechart", action: #selector(pieChartTapped))
        let histogramWindow = createPreviewWindow(title: "History", imageName: "histogram", action: #selector(histogramTapped))
        let leaderboardWindow = createPreviewWindow(title: "Leaderboard", imageName: "leaderboard", action: #selector(leaderboardTapped))
        
        previewWindows = [pieChartWindow, histogramWindow, leaderboardWindow]
        
        stackView.addArrangedSubview(pieChartWindow)
        stackView.addArrangedSubview(histogramWindow)
        stackView.addArrangedSubview(leaderboardWindow)
        
        self.view?.addSubview(stackView)
        
        // Create bottom buttons
        let homeButton = createIconButton(imageName: "house.fill", action: #selector(homeButtonTapped))
        let profileButton = createIconButton(imageName: "person.fill", action: #selector(profileButtonTapped))
        
        self.view?.addSubview(homeButton)
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
        container.backgroundColor = .systemGray6
        container.layer.cornerRadius = 10
        
        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        container.addGestureRecognizer(tapGesture)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            imageView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        
        return container
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




    @objc func homeButtonTapped() {
        // Remove all subviews except the stack view and buttons
        self.view?.subviews.forEach { subview in
            if subview != stackView && !(subview is UIButton) {
                subview.removeFromSuperview()
            }
        }
        
        // Show the preview windows again
        stackView.isHidden = false
        previewWindows.forEach { $0.isHidden = false }
        UIView.animate(withDuration: 0.3) {
            self.stackView.alpha = 1
            self.previewWindows.forEach { $0.alpha = 1 }
        }
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


    
    func displayHistogram() {
        // Create the histogram view
        weekByWeek[4] = dayByDay[0] + dayByDay[1] + dayByDay[2] + dayByDay[3] + dayByDay[4] + dayByDay[5] + dayByDay[6]
        let histogramView = HistogramView(dayByDay: dayByDay, weekByWeek: weekByWeek)
        histogramHostingController = UIHostingController(rootView: histogramView)

        if let view = self.view {
            // Remove any existing histogram view
            histogramHostingController?.view.removeFromSuperview()
            
            // Set the frame to cover a portion of the screen
            let width: CGFloat = view.bounds.width * 0.9
            let height: CGFloat = view.bounds.height * 0.6
            let x = (view.bounds.width - width) / 2
            let y = (view.bounds.height - height) / 2
            
            histogramHostingController?.view.frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Add corner radius for a nicer look
            histogramHostingController?.view.layer.cornerRadius = 10
            histogramHostingController?.view.clipsToBounds = true
            
            view.addSubview(histogramHostingController!.view)
            
            // Optionally animate the presentation
            histogramHostingController?.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.histogramHostingController?.view.alpha = 1
            }
        }
    }
    
    func displayLeaderboard() {
        fetchWeeklyEmissions { userEmissionsList in
            DispatchQueue.main.async {
                guard let userEmissionsList = userEmissionsList else {
                    print("Failed to load user emissions")
                    return
                }
                self.carLabel.text = "Leaderboard"
                // Find the current user's emissions
                let currentUsername = UserDefaults.standard.string(forKey: "username") ?? "DefaultUser"
                let currentUserData = userEmissionsList.first(where: { $0.0 == currentUsername })
                //let userEmissions = currentUserData?.1 ?? 0
                self.dayByDay[0] = self.CalculateduserEmissions
                // Get other users' emissions
                let otherUserEmissions = userEmissionsList.filter { $0.0 != currentUsername }
                    .map { (username: $0.0, emissions: $0.1) }
                self.endDrivingSession()
                // Create the leaderboard view with fetched data
                let leaderboardView = LeaderboardView(
                    userEmissions: self.CalculateduserEmissions,
                    otherUserEmissions: otherUserEmissions
                )
                self.hostingController = UIHostingController(rootView: leaderboardView)
                self.hostingController?.view.backgroundColor = .white // Change background to white
                
                
                if let view = self.view {
                    // Remove any existing leaderboard view
                    self.hostingController?.view.removeFromSuperview()
                    
                    // Set the frame to cover a smaller portion of the screen
                    let width: CGFloat = view.bounds.width * 0.8 // 80% of screen width
                    let height: CGFloat = view.bounds.height * 0.5 // 60% of screen height
                    let x = (view.bounds.width - width) / 2
                    let y = (view.bounds.height - height) / 2
                    
                    self.hostingController?.view.frame = CGRect(
                        x: x,
                        y: y,
                        width: width,
                        height: height
                    )
                    
                    // Add corner radius for a nicer look
                    self.hostingController?.view.layer.cornerRadius = 10
                    self.hostingController?.view.clipsToBounds = true
                    
                    view.addSubview(self.hostingController!.view)
                    
                    // Optionally animate the presentation
                    self.hostingController?.view.alpha = 0
                    UIView.animate(withDuration: 0.3) {
                        self.hostingController?.view.alpha = 1
                    }
                }
            }
        }
    }
    

    struct HistogramView: View {
        let dayByDay: [Int]
        let weekByWeek: [Int]
        
        init(dayByDay: [Int], weekByWeek: [Int]) {
            self.dayByDay = dayByDay
            self.weekByWeek = weekByWeek
        }
        
        var body: some View {
            TabView {
                DailyHistogram(data: dayByDay)
                    .tabItem {
                        Text("Daily")
                    }
                
                WeeklyHistogram(data: weekByWeek)
                    .tabItem {
                        Text("Weekly")
                    }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }

    struct DailyHistogram: View {
        let data: [Int]
        let maxEmission: Int
        
        init(data: [Int]) {
            self.data = data
            self.maxEmission = data.max() ?? 1 // Avoid division by zero
        }
        
        var body: some View {
            VStack {
                Text("Past 7 Days")
                    .font(.title)
                    .padding()
                
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<7) { index in
                        VStack {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 30, height: 200)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 30, height: CGFloat(self.data[index]) / CGFloat(self.maxEmission) * 200)
                            }
                            Text(getDayLabel(for: index))
                                .font(.caption)
                            Text("\(self.data[index])")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                
                Text("Daily Emissions in grams CO2")
                    .font(.caption)
                    .padding()
            }
        }
        
        func getDayLabel(for index: Int) -> String {
            let today = Calendar.current.component(.weekday, from: Date())
            let dayIndex = (today - index - 2 + 7) % 7
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days[dayIndex]
        }
    }

    struct WeeklyHistogram: View {
        let data: [Int]
        let maxEmission: Int
        
        init(data: [Int]) {
            self.data = data
            self.maxEmission = data.max() ?? 1 // Avoid division by zero
        }
        
        var body: some View {
            VStack {
                Text("Past 5 Weeks")
                    .font(.title)
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
                                    .frame(width: 50, height: CGFloat(self.data[index]) / CGFloat(self.maxEmission) * 200)
                            }
                            Text("Week \(5 - index)")
                                .font(.caption)
                            Text("\(self.data[index])")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                
                Text("Weekly Emissions in grams CO2")
                    .font(.caption)
                    .padding()
            }
        }
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
    
    func createUser(username: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters = ["username": username]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
    
    func updateCarInfo(username: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user/\(username)/car") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "username": username,
            "car_year": carYear,
            "car_make": carMake,
            "car_model": carModel
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
    
    func updateEmissions(username: String, emissions: Float, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user/\(username)/emissions") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "username": username,
            "emissions": emissions
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
}
extension GameScene {
    func showPieChart() {
        carLabel.text = "Today's Emissions"
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        
        let pieChartView = PieChartView(userEmissions: CalculateduserEmissions, food: FOOD, energy: ENERGY, goods: GOODS)
        pieChartHostingController = UIHostingController(rootView: pieChartView)
        
        if let view = self.view, let hostingController = pieChartHostingController {
            // Remove any existing pie chart view
            view.subviews.first(where: { $0.tag == 100 })?.removeFromSuperview()
            
            // Set the frame to cover a portion of the screen
            let width: CGFloat = view.bounds.width * 0.9
            let height: CGFloat = view.bounds.height * 0.7
            let x = (view.bounds.width - width) / 2
            let y = (view.bounds.height - height) / 2
            
            hostingController.view.frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Add corner radius for a nicer look
            hostingController.view.layer.cornerRadius = 10
            hostingController.view.clipsToBounds = true
            hostingController.view.tag = 100
            
            view.addSubview(hostingController.view)
            
            // Animate the presentation
            hostingController.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                hostingController.view.alpha = 1
            }
        }
        
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
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
    }
}

// Histogram Preview
struct HistogramPreview: View {
    let dayByDay: [Int]
    let weekByWeek: [Int]
    
    var body: some View {
        VStack {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(dayByDay.suffix(5), id: \.self) { value in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 10, height: CGFloat(value) / CGFloat(dayByDay.max() ?? 1) * 50)
                }
            }
        }
        .frame(width: 100, height: 60)
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
                    }
                }
            }
        }
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
        }
    }
}
