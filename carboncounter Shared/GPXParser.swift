//
//  GPXParser.swift
//  carboncounter
//
//  Created by Neven on 7/21/24.
//

import Foundation
import CoreLocation

class GPXParser: NSObject, XMLParserDelegate {
    var coordinates: [CLLocation] = []
    var currentElement: String = ""
    var currentLatitude: String = ""
    var currentLongitude: String = ""
    var totalDistance: Double = 0.0
    
    func parseGPX(fileURL: URL) -> [CLLocation] {
        let parser = XMLParser(contentsOf: fileURL)
        parser?.delegate = self
        parser?.parse()
        return coordinates
    }
    
    // XMLParser Delegate Methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "trkpt" {
            if let lat = attributeDict["lat"], let lon = attributeDict["lon"] {
                currentLatitude = lat
                currentLongitude = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trkpt" {
            if let lat = Double(currentLatitude), let lon = Double(currentLongitude) {
                let location = CLLocation(latitude: lat, longitude: lon)
                coordinates.append(location)
            }
        }
    }
    func calculateTotalDistance(locations: [CLLocation]) -> Double {

        
        for i in 1..<locations.count {
            let previousLocation = locations[i-1]
            let currentLocation = locations[i]
            let distance = previousLocation.distance(from: currentLocation)
            totalDistance += distance
        }
        
        return totalDistance
    }
    

    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parse error: \(parseError.localizedDescription)")
    }
}

