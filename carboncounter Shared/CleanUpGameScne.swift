//
//  CleanUpGameScne.swift
//  EcoTrack
//
//  Created by Neven Abou Gazala on 12/27/24.
//

// Organized Swift source code for GameScene
// =====================================================
// Section 1: Imports
// =====================================================
import SpriteKit
import SwiftUI
import UIKit
import CoreLocation
import UserNotifications
import Foundation
import PassKit
import AuthenticationServices

// =====================================================
// Section 2: Main Game Scene Class
// =====================================================

class GameScene: SKScene, UITextFieldDelegate, CLLocationManagerDelegate {
    // MARK: - Properties
    var timer: Timer?
    fileprivate var label: SKLabelNode?
    fileprivate var spinnyNode: SKShapeNode?
    var progressLabel: UILabel!
    var enterCarLabel: SKLabelNode!
    var homeButton: UIButton!
    var welcome = SKLabelNode()
    var startScreen = true
    var getStarted = SKLabelNode()
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

    // Arrays and counters
    var dayByDay = [0, 0, 0, 0, 0, 0, 0]
    var dailyCarEmissions = 0
    var weekByWeek = [0, 0, 0, 0, 0]
    var stackView: UIStackView!
    var previewWindows: [UIView] = []
    var ENERGY = 0
    var FOOD = 0
    var GOODS = 0

    // Managers and controllers
    private let locationTracker = LocationManager()
    var histogramHostingController: UIHostingController<HistogramView>?
    var pieChartHostingController: UIHostingController<PieChartView>?
    var profileHostingController: UIHostingController<ProfileView>?
    
    // UI Elements
    var ecotrack = SKLabelNode()
    var viewLeaderboardButton = UIButton(type: .system)
    var weeklyScore: Int = 0
    var myProgressButton = UIButton(type: .system)
    var myBadgesButton = UIButton(type: .system)
    var hostingController: UIHostingController<LeaderboardView>?
    
    // State
    var isAuthenticated = false
    
    // Pickers
    var yearPickerView: UIPickerView!
    var makePickerView: UIPickerView!
    var modelPickerView: UIPickerView!
    
    // Car Data
    var carYear: String = ""
    var carMake: String = ""
    var carModel: String = ""
    var emission: String = ""
    
    // Location
    var locationManager: CLLocationManager!
    var customLocationManager: LocationManager!
    
    // Data Arrays
    var years = [String]()
    var makes = [String]()
    var models = [String]()
    var carData = [[String]]()
    var fullNameTextField : UITextField?
    
    // Leaderboard
    var leaderboardLabel: SKLabelNode!
    var CalculateduserEmissions: Int = 0
    var otherUserEmissions = [Int]()


