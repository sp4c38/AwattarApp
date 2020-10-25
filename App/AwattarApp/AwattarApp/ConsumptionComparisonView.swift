//
//  ConsumptionComparator.swift
//  AwattarApp
//
//  Created by Léon Becker on 19.09.20.
//

import SwiftUI

extension AnyTransition {
    /// A transition used for presenting a view with extra information to the screen.
    static var extraInformationTransition: AnyTransition {
        let insertion = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        let removal = AnyTransition.opacity // AnyTransition.scale(scale: 2).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

/// Input field for the power output of the consumer
struct PowerOutputInputField: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("powerOutput")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            HStack {
                TextField("inKw", text: $cheapestHourManager.powerOutputString.animation())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing, 5)
                
                if cheapestHourManager.powerOutputString != "" {
                    Text("kW")
                        .transition(.opacity)
                }
            }
            .padding(.leading, 17)
            .padding(.trailing, 14)
            .padding([.top, .bottom], 10)
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Input field for the energy usage which the consumer shall consume
struct EnergyUsageInputField: View {
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("energyUsage")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            HStack {
                TextField("inKwh", text: $cheapestHourManager.energyUsageString.animation())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .padding(.trailing, 5)
                
                if cheapestHourManager.energyUsageString != "" {
                    Text("kWh")
                        .transition(.opacity)
                }
            }
            .padding(.leading, 17)
            .padding(.trailing, 14)
            .padding([.top, .bottom], 10)
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// A input field for the length of the usage in the consumption comparison view.
//struct LengthOfUsageInputField: View {
//    @EnvironmentObject var cheapestHourManager: CheapestHourManager
//        
//    var body: some View {
//        VStack(alignment: .leading, spacing: 5) {
//            HStack(spacing: 5) {
//                Text("lengthOfUsage")
//                    .font(.title3)
//                    .bold()
//
//                Spacer()
//            }
//
//            TimeIntervalPicker()
//                .transition(.opacity)
//        }
//        .frame(maxWidth: .infinity)
//    }
//}

/// A input field for the time range in the consumption comparison view.
struct TimeRangeInputField: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("timeRange")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("from")
                        .bold()
                        .font(.callout)
                        .foregroundColor(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314))
                    
                    Spacer()
                    
                    DatePicker(selection: $cheapestHourManager.startDate, displayedComponents: [.date, .hourAndMinute], label: {})
                        .labelsHidden()
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
 
                HStack {
                    Text("to")
                        .bold()
                        .font(.callout)
                        .foregroundColor(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.4314))
                    
                    Spacer()
                    
                    DatePicker(selection: $cheapestHourManager.endDate, displayedComponents: [.date, .hourAndMinute], label: {})
                        .labelsHidden()
                }
                .padding(5)
                .padding([.leading, .trailing], 2)
                .background(
                    colorScheme == .light ?
                        Color(hue: 0.6667, saturation: 0.0083, brightness: 0.9412) :
                        Color(hue: 0.0000, saturation: 0.0000, brightness: 0.1429)
                )
                .cornerRadius(7)
            }
            .padding([.leading, .trailing], 3)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A view which allows the user to find the cheapest hours for using energy. It optionally can also show the final price which the user would have to pay to aWATTar if consuming the specified amount of energy.
struct ConsumptionComparisonView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    @EnvironmentObject var cheapestHourManager: CheapestHourManager
    
    /// State variable which if set to true triggers that extra informations is shown of what this view does because it may not be exactly clear to the user at first usage.
    @State var showInfo = false
    @State var redirectToComparisonResults: Int? = 0
    
    /**
     A time range which goes from the start time of the first energy price data point to the end time of the last energy price data point downloaded from the server
    - This time range is used in date pickers to make only times selectable for which also energy price data points currently exist
    */
    var energyDataTimeRange: ClosedRange<Date> {
        let maxHourIndex = awattarData.energyData!.prices.count - 1
        
        // Add one or subtract one to not overlap to the next or previouse day
        let min = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[0].startTimestamp + 1))
        let max = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp - 1))
        
        return min...max
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if awattarData.energyData != nil && currentSetting.setting != nil {
                    ScrollView {
                        VStack(alignment: .center, spacing: 20) {
                            PowerOutputInputField()
                            EnergyUsageInputField()
//                            LengthOfUsageInputField()
                            TimeRangeInputField()
                        }
                        .padding(.top, 20)
                        .padding([.leading, .trailing], 20)
                        .padding(.bottom, 10)
                    }


                    NavigationLink(destination: ConsumptionResultView(), tag: 1, selection: $redirectToComparisonResults) {
                    }

                    // Button to perform calculations to find cheapest hours and to redirect to the result view to show the results calculated
                    Button(action: {
                        redirectToComparisonResults = 1
                    }) {
                        HStack {
                            Text("showResults")
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.white)
                                .padding(.leading, 10)
                        }
                    }
                    .buttonStyle(ActionButtonStyle())
                    .padding(.bottom, 16)
                    .padding([.leading, .trailing], 15)
                    .padding(.top, 10)
                } else {
                    if awattarData.networkConnectionError == false {
                        // no network connection error
                        // download in progress

                        LoadingView()
                    } else {
                        // network connection error
                        // can't fulfill download

                        NetworkConnectionErrorView()
                            .transition(.opacity)
                    }
                }
            }
            .onAppear {
                if awattarData.energyData != nil {
                    let maxHourIndex = awattarData.energyData!.prices.count - 1

                    // Set end date of the end date time picker to the maximal currently time where energy price data points exist
                    cheapestHourManager.endDate = Date(timeIntervalSince1970: TimeInterval(awattarData.energyData!.prices[maxHourIndex].endTimestamp))
                }
            }
            .navigationBarTitle("usage")
            .navigationBarItems(trailing:
                Button(action: {
                    withAnimation {
                        showInfo.toggle()
                    }
                }) {
                    Image(systemName: "info.circle")
                }
            )
            .onTapGesture {
                self.hideKeyboard()
            }
        }
    }
}

struct ConsumptionComparatorView_Previews: PreviewProvider {
    static var previews: some View {
//        TimeRangeInputField()
//            .environmentObject(CheapestHourManager())
//            .preferredColorScheme(.dark)
        
        ConsumptionComparisonView()
            .environmentObject(CheapestHourManager())
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
            .preferredColorScheme(.dark)
    }
}
