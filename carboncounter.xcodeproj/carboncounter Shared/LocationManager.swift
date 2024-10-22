import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager
    var delegate: CLLocationManagerDelegate?
    var lastLocation: CLLocation?
    var totalDistance: CLLocationDistance = 5.0
    var totalDuration: TimeInterval = 0.0
    var isDriving = false
    var startDrivingDate: Date?
    var carYear: String = ""
    var carMake: String = ""
    var carModel: String = ""
    var emissionsPerMile = 0.0
    let parse = GPXParser()
    
    // Add a property to store car emissions data
    var userCar = [String]()
    var carData = [[String]]()
    
    // Add a property to hold GPX data
    private var gpxData: [CLLocation] = []
    private var gpxIndex = 0
    private var gpxTimer: Timer?

    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.requestWhenInUseAuthorization()

    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func startTrackingDriving() {
        isDriving = true
        startDrivingDate = Date()
        lastLocation = nil
        totalDistance = 0.0
        totalDuration = 0.0
        
        // Start simulating GPX locations
        startGPXSimulation()
    }
    
    func stopTrackingDriving() {
        isDriving = false
        startDrivingDate = nil
        stopGPXSimulation()
        
        // Calculate and print emissions
        let emissions = calculateEmissions(distance: totalDistance, duration: totalDuration, carYear: carYear, carMake: carMake, carModel: carModel, carData: carData)
        print("Total emissions for the BellevueRainier drive: \(String(format: "%.2f", emissions)) grams of CO2")
    }
    
    func startGPXSimulation() {

        
        gpxIndex = 0

            
        if self.gpxIndex < self.gpxData.count {
            let location = self.gpxData[self.gpxIndex]
            self.processLocation(location)
            self.gpxIndex += 1
        } else {
            //timer.invalidate()
            self.stopTrackingDriving()
        }
        
    }
    func loadGPXFile() {
        gpxData = parseGPXFile("bellevueRainier")
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
    
    func stopGPXSimulation() {
        gpxTimer?.invalidate()
        gpxTimer = nil
    }
    


    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isDriving else { return }
        guard let newLocation = locations.last else { return }
        
        processLocation(newLocation)
    }
    
    func processLocation(_ location: CLLocation) {
        guard isDriving else { return }
        
        if let lastLocation = lastLocation {
            var distance = location.distance(from: lastLocation)
            totalDistance += distance
            if let startDrivingDate = startDrivingDate {
                let duration = Date().timeIntervalSince(startDrivingDate)
                totalDuration += duration
            }
        }
        
        lastLocation = location
        delegate?.locationManager?(locationManager, didUpdateLocations: [location])
        
        // Check if the user is likely in a car (speed > 25 mph)
        if location.speed > 11.176 { // 25 mph in meters per second
            print("User is likely in a car.")
        }
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func updateLocation(_ location: CLLocation) {
        guard isDriving else { return }
        
        processLocation(location)
    }
    
    func calculateEmissions(distance: Double, duration: TimeInterval, carYear: String, carMake: String, carModel: String, carData: [[String]]) -> Double {
        // Find car emissions data

        for row in carData {
            if row.count >= 4 && row[0] == carYear && row[1] == carMake && row[2] == carModel {
                emissionsPerMile = (row[3] as NSString).doubleValue
                break
            }
        }
        
        let bundlePath = Bundle.main.bundlePath
        let fileManager = FileManager.default
        do {
            let items = try fileManager.contentsOfDirectory(atPath: bundlePath)
            for item in items {
                print("Found item: \(item)")
            }
        } catch {
            print("Error while enumerating files \(bundlePath): \(error.localizedDescription)")
        }
        
        if let filePath = Bundle.main.path(forResource: "bellevueRainier", ofType: "gpx") {
            let fileURL = URL(fileURLWithPath: filePath)
            let parser = GPXParser()
            let locations = parser.parseGPX(fileURL: fileURL)
            totalDistance = parser.calculateTotalDistance(locations: locations)
            print("Total distance: \(totalDistance) meters")
        } else {
            print("GPX file not found.")
        }

        
        // Convert distance to miles and calculate total emissions
        let distanceInMiles = totalDistance / 1609.34
        let totalEmissions = emissionsPerMile * distanceInMiles
        
        return totalEmissions
    }
    
    func parseGPXFile(_ fileName: String) -> [CLLocation] {
        var locations: [CLLocation] = []
        var currentElement = ""
        var currentLatitude: Double?
        var currentLongitude: Double?
        var currentTimestamp: Date?
        
        // Load the GPX file from the bundle
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "gpx") else {
            print("GPX file not found.")
            return locations
        }
        
        // Read the file data
        do {
            let fileData = try Data(contentsOf: fileURL)
            let XMLparser = XMLParser(data: fileData)
            XMLparser.delegate = GPXParserDelegate { latitude, longitude, timestamp in
                if let lat = latitude, let lon = longitude, let time = timestamp {
                    let location = CLLocation(latitude: lat, longitude: lon)
                    locations.append(location)
                }
            }
            //XMLparser.parse()
        } catch {
            print("Failed to load GPX file: \(error.localizedDescription)")
        }
        
        return locations
    }

    // Implement the XMLParserDelegate to handle the XML parsing
    class GPXParserDelegate: NSObject, XMLParserDelegate {
        private var currentElement = ""
        private var currentLatitude: Double?
        private var currentLongitude: Double?
        private var currentTimestamp: Date?
        private let locationHandler: (Double?, Double?, Date?) -> Void
        
        init(locationHandler: @escaping (Double?, Double?, Date?) -> Void) {
            self.locationHandler = locationHandler
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String : String] = [:]) {
            currentElement = elementName
            if elementName == "trkpt" {
                if let lat = attributes["lat"], let latDouble = Double(lat) {
                    currentLatitude = latDouble
                }
                if let lon = attributes["lon"], let lonDouble = Double(lon) {
                    currentLongitude = lonDouble
                }
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if currentElement == "time" {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                currentTimestamp = dateFormatter.date(from: string)
            }
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "trkpt" {
                locationHandler(currentLatitude, currentLongitude, currentTimestamp)
                currentLatitude = nil
                currentLongitude = nil
                currentTimestamp = nil
            }
        }
    }
}
