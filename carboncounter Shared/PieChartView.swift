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
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            
            // Calculate sizes based on available space
            let padding: CGFloat = 20
            let titleHeight: CGFloat = 80
            let legendHeight: CGFloat = 120 // Fixed height for 4 legend items
            let chartAreaHeight = availableHeight - titleHeight - legendHeight - (padding * 3)
            
            // Pie chart size - constrained by both width and available height
            let maxChartSize = min(availableWidth * 0.7, chartAreaHeight)
            let chartSize = max(maxChartSize, 100) // Minimum size
            
            VStack(spacing: padding) {
                // Title section - fixed height
                VStack(spacing: 8) {
                    Text("Today's Emissions")
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text("Total: \(userEmissions + food + energy + goods)g CO₂")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(height: titleHeight)
                
                // Pie chart - constrained size
                ZStack {
                    ForEach(0..<slices.count, id: \.self) { index in
                        PieSlice(startAngle: .degrees(sliceStartDegree(for: index)),
                                 endAngle: .degrees(sliceEndDegree(for: index)))
                            .fill(slices[index].1)
                            .scaleEffect(1.0 + sliceOffsets[index])
                            .animation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.5), value: sliceOffsets[index])
                    }
                }
                .frame(width: chartSize, height: chartSize)
                .clipped() // Ensure chart doesn't overflow
                
                // Legend section with scroll indicator
                ZStack(alignment: .trailing) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
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
                        .padding(.trailing, 8) // Add padding to make room for scroll indicator
                    }
                    
                    // Custom scroll indicator
                    VStack {
                        Spacer()
                        
                        // Scroll indicator line
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 2, height: legendHeight * 0.8)
                            .cornerRadius(1)
                        
                        Spacer()
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: legendHeight)
            }
            .padding(padding)
            .frame(width: availableWidth, height: availableHeight)
        }
        .clipped() // Final safety net to prevent any overflow
        .onAppear {
            animateSlices()
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
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            Text("\(value)g\(percentage)")
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 24) // Fixed height for consistent spacing
    }
}
