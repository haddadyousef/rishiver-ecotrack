//
//  LeaderBoardView.swift
//  carboncounter
//
//  Created by Neven on 7/17/24.
//

import SwiftUI

struct LeaderboardView: View {
    let userEmissions: Int
    let otherUserEmissions: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leaderboard:")
                .font(.headline)
            
            Text("You: \(userEmissions) grams")
            
            ForEach(0..<otherUserEmissions.count, id: \.self) { index in
                Text("User \(index + 1): \(otherUserEmissions[index]) grams")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
        .animation(.easeInOut(duration: 0.5)) // Example animation
    }
}
