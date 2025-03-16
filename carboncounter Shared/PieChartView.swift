//
//  PieChartView.swift
//  carboncounter
//
//  Created by Neven on 7/28/24.
//

import Foundation
import SwiftUI

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

struct PieChartView: View {
    let userEmissions: Int
    let food: Int
    let energy: Int
    let goods: Int
    
    @State private var sliceOffsets: [CGFloat] = [0, 0, 0, 0]
    
    var slices: [(Double, Color)] {
        let total = Double(userEmissions + food + energy + goods)
        if total == 0 {
            return [
                (0.25, .blue),
                (0.25, .green),
                (0.25, .orange),
                (0.25, .red)
            ]
        }
        return [
            (Double(userEmissions) / total, .blue),
            (Double(food) / total, .green),
            (Double(energy) / total, .orange),
            (Double(goods) / total, .red)
        ]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Spacer()
                
                Text("Today's Emissions")
                    .font(.title)
                
                Text("Total: \(userEmissions + food + energy + goods)g CO₂")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                ZStack {
                    ForEach(0..<slices.count, id: \.self) { index in
                        PieSlice(startAngle: .degrees(sliceStartDegree(for: index)),
                                 endAngle: .degrees(sliceEndDegree(for: index)))
                            .fill(slices[index].1)
                            .scaleEffect(1.0 + sliceOffsets[index])
                            .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5), value: sliceOffsets[index])
                    }
                }
                .frame(width: min(geometry.size.width * 0.65, 250),
                       height: min(geometry.size.width * 0.65, 250))
                .padding(.vertical, 20)
                
                VStack(alignment: .leading, spacing: 15) {
                    let total = Double(userEmissions + food + energy + goods)
                    
                    LegendItem(color: .blue,
                              label: "Car Emissions",
                              value: userEmissions,
                              percentage: total > 0 ? String(format: " (%.1f%%)", (Double(userEmissions) / total) * 100) : "")
                        .opacity(userEmissions > 0 ? 1 : 0.5)
                    
                    LegendItem(color: .green,
                              label: "Food",
                              value: food,
                              percentage: total > 0 ? String(format: " (%.1f%%)", (Double(food) / total) * 100) : "")
                        .opacity(food > 0 ? 1 : 0.5)
                    
                    LegendItem(color: .orange,
                              label: "Energy",
                              value: energy,
                              percentage: total > 0 ? String(format: " (%.1f%%)", (Double(energy) / total) * 100) : "")
                        .opacity(energy > 0 ? 1 : 0.5)
                    
                    LegendItem(color: .red,
                              label: "Goods",
                              value: goods,
                              percentage: total > 0 ? String(format: " (%.1f%%)", (Double(goods) / total) * 100) : "")
                        .opacity(goods > 0 ? 1 : 0.5)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    func sliceStartDegree(for index: Int) -> Double {
        let sum = slices[..<index].map { $0.0 }.reduce(0, +)
        return sum * 360
    }
    
    func sliceEndDegree(for index: Int) -> Double {
        let sum = slices[..<(index + 1)].map { $0.0 }.reduce(0, +)
        return sum * 360
    }
    
    func animateSlices() {
        for (index, _) in slices.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5)) {
                    sliceOffsets[index] = 0.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5)) {
                        sliceOffsets[index] = 0
                    }
                }
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let value: Int
    let percentage: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
            Text(label)
            Text("\(value)g\(percentage)")
                .foregroundColor(.gray)
        }
    }
}
