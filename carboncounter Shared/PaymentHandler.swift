//
//  PaymentHandler.swift
//  carboncounter
//
//  Created by Neven Abou Gazala on 10/16/24.
//

import Foundation
import Stripe
import PassKit

class PaymentHandler: NSObject, PKPaymentAuthorizationViewControllerDelegate, STPApplePayContextDelegate {

    static let shared = PaymentHandler()
    
    private override init() {}
    
    // Call this function to begin the Apple Pay process
    func startApplePay(withItems items: [PKPaymentSummaryItem], viewController: UIViewController) {
        let paymentRequest = StripeAPI.paymentRequest(withMerchantIdentifier: "your.merchant.identifier", country: "US", currency: "USD")
        paymentRequest.paymentSummaryItems = items
        
        if StripeAPI.canSubmitPaymentRequest(paymentRequest) {
            let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self)
            applePayContext?.presentApplePay(on: viewController)
        } else {
            print("Apple Pay is not available on this device.")
        }
    }
    
    // STPApplePayContextDelegate methods
    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: STPPaymentMethod, paymentInformation: PKPayment, completion: @escaping STPIntentClientSecretCompletionBlock) {
        // Call your backend to create a PaymentIntent and pass the clientSecret back to Stripe
        MyAPIClient.shared.createPaymentIntent { (clientSecret, error) in
            if let clientSecret = clientSecret {
                completion(clientSecret, nil)
            } else {
                completion(nil, error)
            }
        }
    }

    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPApplePayContext.PaymentStatus, error: Error?) {
        switch status {
        case .success:
            print("Apple Pay payment completed successfully!")
            // Notify GameScene or handle success as needed
        case .error:
            print("Apple Pay payment failed: \(error?.localizedDescription ?? "unknown error")")
        case .userCancellation:
            print("Apple Pay payment was cancelled by the user.")
        }
    }
}

// Helper API Client for creating PaymentIntent on your server
class MyAPIClient {
    static let shared = MyAPIClient()
    
    private init() {}
    
    func createPaymentIntent(completion: @escaping (String?, Error?) -> Void) {
        // Make a call to your backend to create a PaymentIntent
        // Replace with your actual backend endpoint
        let url = URL(string: "https://your-backend.com/create-payment-intent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let clientSecret = json["clientSecret"] as? String {
                completion(clientSecret, nil)
            } else {
                completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"]))
            }
        }.resume()
    }
}
