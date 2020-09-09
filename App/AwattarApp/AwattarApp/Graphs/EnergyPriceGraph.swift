//
//  EnergyPriceGraph.swift
//  AwattarApp
//
//  Created by Léon Becker on 08.09.20.
//

import SwiftUI

struct EnergyPriceGraph: View {
    // Displays a graph for the price of energy for a certain time
    var awattarDataPoint: AwattarDataPoint
    var maxPrice: Float?
    
    var body: some View {
        GeometryReader { geometry -> Path in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let priceBarWidth: CGFloat
            
            if maxPrice != nil {
                priceBarWidth = CGFloat(awattarDataPoint.marketprice / maxPrice!) * width
            } else {
                priceBarWidth = width
            }
            
            return Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: priceBarWidth, height: height))
            }
        }
    }
}

struct EnergyPriceGraph_Previews: PreviewProvider {
    static var previews: some View {
        EnergyPriceGraph(awattarDataPoint: AwattarDataPoint(startTimestamp: 1599516000000, endTimestamp: 1599519600000, marketprice: 30, unit: ["Eur / MWh", "Eur / kWh"]))
            .frame(height: 60)
    }
}
