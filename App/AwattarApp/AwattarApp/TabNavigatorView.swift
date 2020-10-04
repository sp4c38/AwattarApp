//
//  MainView.swift
//  AwattarApp
//
//  Created by Léon Becker on 13.09.20.
//

import SwiftUI

struct TabNavigatorView: View {
    @EnvironmentObject var awattarData: AwattarData
    
    var body: some View {
        if awattarData.energyData != nil {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "bolt")
                        Text("elecPrice")
                    }
                
                ConsumptionComparisonView()
                    .tabItem {
                        Image(systemName: "rectangle.and.text.magnifyingglass")
                        Text("usage")
                    }
            }
        } else {
            VStack(spacing: 40) {
                if awattarData.energyData == nil {
                    Spacer()
                    ProgressView("")
                    Text("loadingData")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
        }
    }
}

struct TabNavigatorView_Previews: PreviewProvider {
    static var previews: some View {
        TabNavigatorView()
    }
}