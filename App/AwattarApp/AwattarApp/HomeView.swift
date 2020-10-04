//
//  ContentView.swift
//  AwattarApp
//
//  Created by Léon Becker on 06.09.20.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var hourPriceInfoViewNavControl: Int? = 0
    @State var settingIsPresented: Bool = false
    
    @GestureState var isPressed = false
    
    var hourFormatter: DateFormatter
    var numberFormatter: NumberFormatter
    
    init() {
        hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "H"
        
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = Locale(identifier: "de_DE")
        numberFormatter.currencySymbol = "ct"
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2
    }
    
    var body: some View {
        NavigationView {
            if awattarData.energyData != nil {
                VStack {
                    Divider()

                    HStack {
                        Text("pricePerKwh")
                            .font(.subheadline)
                            .padding(.leading, 10)
                            .padding(.top, 8)

                        Spacer()

                        Text("hourOfDay")
                            .font(.subheadline)
                            .padding(.trailing, 25)
                    }
                    .padding(.bottom, 5)
                    
                    EnergyPriceGraph()
                        .shadow(radius: 3)
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                }
                .sheet(isPresented: $settingIsPresented) {
                    SettingsPageView()
                        .environment(\.managedObjectContext, managedObjectContext)
                }
                .navigationBarTitle("elecPrice")
                .navigationBarItems(trailing:
                    Button(action: {
                        settingIsPresented = true
                    }) {
                        Image(systemName: "gear")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(Color.blue)
                    }
                )
                .navigationBarTitleDisplayMode(.large)
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    ProgressView("")
                    Spacer()
                }
            }
        }
        .onAppear {
            currentSetting.setSetting(managedObjectContext: managedObjectContext)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting())
    }
}
