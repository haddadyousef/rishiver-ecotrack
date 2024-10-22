import CoreLocation
import Foundation

class LocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager
    var delegate: CLLocationManagerDelegate?
    var lastLocation: CLLocation?
    var totalDistance: CLLocationDistance = 0.0
    var totalDuration: TimeInterval = 0.0
    var startDrivingDate: Date?
    var carYear: String = ""
    var carMake: String = ""
    var carModel: String = ""
    var emissionsPerMile = 0.0
    
    var userCar = [String]()
    var carData = [[String]]()
    
    var speedTimer: Timer?
    
    var dailyDrivingDuration: TimeInterval = 0.0
    var lastDrivingEndTime: Date?
    
    var isDriving: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .drivingStatusChanged, object: nil)
            
            if !isDriving {
                calculateAndPrintEmissions()
            }
        }
    }
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.requestWhenInUseAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        startLocationUpdates()
        startMonitoringSignificantLocationChanges()
        initializeDailyTracking()
    }
    
    func startMonitoringSignificantLocationChanges() {
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func stopMonitoringSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse:
            requestAlwaysAuthorization()
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func startTrackingDriving() {
        startDrivingDate = Date()
        lastLocation = nil
        totalDistance = 0.0
        totalDuration = 0.0
        
        // Reset daily driving duration at the start of a new day
        if !Calendar.current.isDateInToday(lastDrivingEndTime ?? Date.distantPast) {
            dailyDrivingDuration = 0.0
        }
    }
    
    func stopTrackingDriving() {
        if let startDate = startDrivingDate {
            let drivingDuration = Date().timeIntervalSince(startDate)
            dailyDrivingDuration += drivingDuration
            lastDrivingEndTime = Date()
            
            saveDailyDrivingDuration()
        }
        startDrivingDate = nil
    }
    
    func setCarDetails(year: String, make: String, model: String, list: [[String]]) {
        carYear = year
        carMake = make
        carModel = model
        userCar.append(carYear)
        userCar.append(carMake)
        userCar.append(carModel)
        carData = list
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        processLocation(newLocation)
    }
    
    func processLocation(_ location: CLLocation) {
        guard let lastLocation = lastLocation else {
            self.lastLocation = location
            return
        }
        
        let distance = location.distance(from: lastLocation)
        totalDistance += distance
        
        if let startDrivingDate = startDrivingDate {
            let duration = Date().timeIntervalSince(startDrivingDate)
            totalDuration += duration
        }
        
        self.lastLocation = location
        let currentSpeed = location.speed
        
        if currentSpeed >= 0 {
            let speedInMph = currentSpeed * 2.23694 // Convert from m/s to mph
            print("Current speed: \(String(format: "%.2f", speedInMph)) mph")
            if currentSpeed > 4.47 { // 4.47 m/s is 10MPH
                if !isDriving {
                    isDriving = true
                    print("User started moving.")
                    startTrackingDriving()
                }
            } else {
                if isDriving {
                    isDriving = false
                    print("User stopped moving.")
                    stopTrackingDriving()
                }
            }
        }
    }
    
    func calculateAndPrintEmissions() -> Double {
        let distanceInMiles = totalDistance / 1609.34 // Convert to miles
        let totalEmissions = emissionsPerMile * distanceInMiles
        print("Emissions per mile: \(String(format: "%.2f", emissionsPerMile)) grams of CO2")
        print("Distance traveled while driving: \(String(format: "%.2f", totalDistance)) meters")
        print("Total emissions for the distance: \(String(format: "%.2f", totalEmissions)) grams of CO2")
        
        totalDistance = 0.0
        return totalEmissions
    }
    
    func calculateAndSendEmissions() -> Double {
        let emissions = calculateAndPrintEmissions()
        return emissions
    }
    
    
    
    func startSpeedTimer() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let location = self.lastLocation else { return }
            let speedInMph = location.speed * 2.23694 // Convert from m/s to mph
            print("Current speed: \(String(format: "%.2f", speedInMph)) mph")
        }
    }
    
    func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
    
    func findEmissionsPerMiles(carYear: String, carMake: String, carModel: String, carData: [[String]]) {
        for row in carData {
            if row.count >= 4 && row[0] == carYear && row[1] == carMake && row[2] == carModel {
                emissionsPerMile = (row[3] as NSString).doubleValue
                break
            }
        }
    }
    
    func calculateEmissions(distance: Double, duration: TimeInterval, carYear: String, carMake: String, carModel: String, carData: [[String]]) -> Double {
        for row in carData {
            if row.count >= 4 && row[0] == carYear && row[1] == carMake && row[2] == carModel {
                emissionsPerMile = (row[3] as NSString).doubleValue
                break
            }
        }
        
        let distanceInMiles = totalDistance / 1609.34
        let totalEmissions = emissionsPerMile * distanceInMiles
        
        return totalEmissions
    }
    
    func restoreEmissionsData() -> Double {
        let defaults = UserDefaults.standard
        return defaults.double(forKey: "allTimeEmissions")
    }
    
    func calculateAndSaveEmissions() -> Double {
        let emissions = calculateAndPrintEmissions()
        saveEmissionsToUserDefaults(emissions: emissions)
        return emissions
    }
    
    func saveEmissionsToUserDefaults(emissions: Double) {
        let defaults = UserDefaults.standard
        var allTimeEmissions = defaults.double(forKey: "allTimeEmissions")
        allTimeEmissions += emissions
        defaults.set(allTimeEmissions, forKey: "allTimeEmissions")
    }
    
    func setDrivingTimeToZero() {
        // Set the daily driving duration to zero
        dailyDrivingDuration = 0.0
        
        // Update the last driving end time to now
        lastDrivingEndTime = Date()
        
        // Save the updated values
        saveDailyDrivingDuration()
        
        print("Driving time has been reset to zero.")
    }
    
    func saveDailyDrivingDuration() {
        let defaults = UserDefaults.standard
        defaults.set(dailyDrivingDuration, forKey: "dailyDrivingDuration")
        defaults.set(lastDrivingEndTime, forKey: "lastDrivingEndTime")
    }
    
    func loadDailyDrivingDuration() {
        let defaults = UserDefaults.standard
        dailyDrivingDuration = defaults.double(forKey: "dailyDrivingDuration")
        lastDrivingEndTime = defaults.object(forKey: "lastDrivingEndTime") as? Date
        
        // Reset daily driving duration if it's a new day
        if let lastEndTime = lastDrivingEndTime, !Calendar.current.isDateInToday(lastEndTime) {
            dailyDrivingDuration = 0.0
            saveDailyDrivingDuration()
        }
    }
    
    public var drivingTimeInHours: Double {
        return dailyDrivingDuration / 3600.0
    }
    
    func getDailyDrivingDurationString() -> String {
        let hours = Int(dailyDrivingDuration) / 3600
        let minutes = Int(dailyDrivingDuration) % 3600 / 60
        let seconds = Int(dailyDrivingDuration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func initializeDailyTracking() {
        loadDailyDrivingDuration()
    }
}
