//
//  CheapestHourManager.swift
//  AwattarApp
//
//  Created by Léon Becker on 22.10.20.
//

import Foundation

/// An object which manages the calculation of when the cheapest hours are for energy consumption
class CheapestHourManager: ObservableObject {
    // The power output of the electric device in kW
    @Published var powerOutputString = ""
    @Published var powerOutput: Double = 0

    // The energy usage the electric device shall consume in kWh
    @Published var energyUsageString = ""
    @Published var energyUsage: Double = 0

    // Time range from startDate to endDate in which to find the cheapest hours
    @Published var startDate = Date()
    @Published var endDate = Date().addingTimeInterval(3600)

    @Published var timeOfUsage: Double = 0

    /// The results of the calculation of the cheapest hours for usage which are represented in an HourPair object.
    @Published var cheapestHoursForUsage: HourPair? = nil
    /// A variable set to true if calculations have been performed but no cheapest hours were found.
    @Published var errorOccurredFindingCheapestHours = false
}

extension CheapestHourManager {
    /// Sets the values after the user entered them. This includes calculating time intervals and formatting raw text strings to floats.
    /// If errors occur because of wrong input of the user and values cannot be set correctly a list is returned with error values.
    /// - Returns: Returns a list with error values if any occur. If no errors occur a list is also returned but with a success value.
    ///     - [0] all values were entered correctly
    ///     - [1] powerOutputString is empty
    ///     - [2] powerOutputString contains wrong characters
    ///     - [3] energyUsageString is empty
    ///     - [4] energyUsageString contains wrong characters
    ///     - [5] the time which is needed with current power output and energy usage is smaller than the time range specified.
    ///     - [6] not supported in this beta release
    func setValues() -> [Int] {
        cheapestHoursForUsage = nil
        var errorValues = [Int]()

        if powerOutputString.replacingOccurrences(of: " ", with: "") == "" {
            errorValues.append(1)
        } else {
            if let powerOutputConverted = powerOutputString.doubleValue {
                powerOutput = powerOutputConverted
            } else {
                errorValues.append(2)
            }
        }

        if energyUsageString.replacingOccurrences(of: " ", with: "") == "" {
            errorValues.append(3)
        } else {
            if let energyUsageConverted = energyUsageString.doubleValue {
                energyUsage = energyUsageConverted
            } else {
                errorValues.append(4)
            }
        }

        if !(errorValues.count > 0) {
            let timeOfUsageInSeconds = (energyUsage / powerOutput) * 60 * 60
            let timeRangeMax = abs(startDate.timeIntervalSince(endDate))
            if timeOfUsageInSeconds <= timeRangeMax {
                timeOfUsage = timeOfUsageInSeconds / 60 / 60 // Convert time of usage back to hours
            } else {
                timeOfUsage = timeOfUsageInSeconds / 60 / 60 // Also set the time of usage even if an error occurres to help to deliver a better error description
                errorValues.append(5)
            }
        }

        if !(errorValues.count > 0) {
            errorValues.append(0)
        }

        return errorValues
    }
}

extension CheapestHourManager {
    /// Sets the selected time interval to tonight from 20pm first day to 7am next day
    func setTimeIntervalThisNight(energyData: EnergyData) {
        var possibleStartDate = Date()
        if Calendar.current.component(.hour, from: Date()) >= 0, Calendar.current.component(.hour, from: Date()) < 7 {
            possibleStartDate = Date()
        } else {
            possibleStartDate = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        }
        var firstPossibleStartDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[0].startTimestamp))

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var possibleEndDate = Date()
        if Calendar.current.component(.hour, from: Date()) >= 0, Calendar.current.component(.hour, from: Date()) < 7 {
            possibleEndDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        } else {
            possibleEndDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!
        }
        let lastPossibleEndDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[energyData.prices.count - 1].endTimestamp))

        if possibleStartDate >= firstPossibleStartDate, possibleStartDate <= lastPossibleEndDate {
            startDate = possibleStartDate
        } else {
            firstPossibleStartDate = Date()
            startDate = firstPossibleStartDate
        }

        if possibleEndDate > lastPossibleEndDate {
            endDate = lastPossibleEndDate
        } else {
            endDate = possibleEndDate
        }
    }
    
    /// Sets the selected time interval to the next x hours
    func setTimeInterval(forNextHourAmount hourAmount: Int, energyData: EnergyData) {
        startDate = Date()
        let possibleEndDate = Calendar.current.date(byAdding: .hour, value: hourAmount, to: Date())!
        let lastPossibleEndDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[energyData.prices.count - 1].endTimestamp))

        if possibleEndDate > lastPossibleEndDate {
            endDate = lastPossibleEndDate
        } else {
            endDate = possibleEndDate
        }
    }
}

/// A pair of one, two, three or more EnergyPricePoints. This object supports functionallity to
/// calculate the average price and to calculate the prices for the hourly awattar tariff.
class HourPair {
    var averagePrice: Double = 0
    var associatedPricePoints: [EnergyPricePoint]
    /// Final energy cost which is calculated with a certain power (kW) a electrical
    /// consumer uses and the time of the usage.
    var hourlyEnergyCosts: Double?

    init(associatedPricePoints: [EnergyPricePoint]) {
        self.associatedPricePoints = associatedPricePoints
    }

    /// Caluclates the average price from the energy price of all to this HourPair
    /// associated price points without VAT included.
    func calculateAveragePrice() {
        var pricesTogether: Double = 0
        var totalMinutes: Double = 0
        for pricePoint in associatedPricePoints {
            let pricePointMinuteLength: Double = Date(timeIntervalSince1970:
                TimeInterval(pricePoint.startTimestamp)
            )
            .timeIntervalSince(Date(timeIntervalSince1970:
                TimeInterval(pricePoint.endTimestamp))
            ) / 60
            pricesTogether += pricePointMinuteLength * pricePoint.marketprice
            totalMinutes += pricePointMinuteLength
        }
        averagePrice = pricesTogether / totalMinutes
    }

    func calculateHourlyPrice(currentSetting: CurrentSetting) {
        hourlyEnergyCosts = nil
        var hourlyPrice: Double = 0

        if currentSetting.entity!.awattarTariffIndex == 0 {
            for hourPair in associatedPricePoints {
                let lengthOfIntervene = Double(abs(hourPair.endTimestamp - hourPair.startTimestamp)) / 60 / 60 // In hours
                var price = hourPair.marketprice

                if currentSetting.entity!.pricesWithVAT {
                    price *= currentSetting.currentVATToUse
                }

                let basePrice: Double = lengthOfIntervene * currentSetting.entity!.awattarBaseElectricityPrice

                hourlyPrice += (lengthOfIntervene * price) + basePrice
            }

            hourlyEnergyCosts = hourlyPrice
        }
    }
}

extension CheapestHourManager {
    func createHourPairs(forHours timeRangeNumber: Int, fromStartTime startTime: Date, toEndTime endTime: Date, with energyData: EnergyData) -> [HourPair] {
        // Create all HourPair's for later comparison
        var allPairs = [HourPair]()
        for hourIndex in 0 ..< energyData.prices.count {
            if hourIndex + (timeRangeNumber - 1) <= energyData.prices.count - 1 {
                let hourStartDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex].startTimestamp))

                let maxHourThisPairEndDate = Date(timeIntervalSince1970: TimeInterval(energyData.prices[hourIndex + timeRangeNumber - 1].endTimestamp))

                if hourStartDate >= startTime, maxHourThisPairEndDate <= endTime {
                    let newPairNode = HourPair(associatedPricePoints: [energyData.prices[hourIndex]])

                    for nextHourIndex in 1 ..< timeRangeNumber {
                        newPairNode.associatedPricePoints.append(energyData.prices[hourIndex + nextHourIndex])
                    }

                    newPairNode.calculateAveragePrice()
                    allPairs.append(newPairNode)
                }
            }
        }

        return allPairs
    }
}

extension CheapestHourManager {
    func compareHourPairs(allPairs: [HourPair]) -> Int? {
        // Compare all hour pairs to find the index of the hour pair with the smallest average price
        var cheapestPairIndex: Int?
        for pairIndex in 0 ..< allPairs.count {
            if cheapestPairIndex != nil {
                if allPairs[pairIndex].averagePrice < allPairs[cheapestPairIndex!].averagePrice {
                    cheapestPairIndex = pairIndex
                }
            } else {
                cheapestPairIndex = pairIndex
            }
        }

        return cheapestPairIndex
    }
}


extension CheapestHourManager {
    /**
     Function to calculate when energy prices are cheapest.
     - Returns: Doesn't return value directly. Instead sets cheapestHoursForUsage of CheapestHourManager to the result HourPair.
     - Parameter energyData: Current energy data (data downloaded from the server)
     */
    func calculateCheapestHours(energyData: EnergyData, currentSetting _: CurrentSetting) {
        DispatchQueue.global(qos: .userInitiated).async {
            var startTime = self.startDate
            var endTime = self.endDate
            let timeRangeNumber = Int(self.timeOfUsage.rounded(.up))

            var startTimeDifference = 0
            var endTimeDifference = 0

            if Calendar.current.component(.minute, from: startTime) != 0 {
                startTimeDifference = Calendar.current.component(.minute, from: startTime)
                startTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: startTime),
                    minute: 0,
                    second: 0,
                    of: startTime
                )! // Set the minute and second of the start time both to zero
            }

            if Calendar.current.component(.minute, from: self.endDate) != 0 {
                endTimeDifference = Calendar.current.component(.minute, from: self.endDate)
                endTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: endTime), minute: 0, second: 0, of: endTime)!
                endTime = endTime.addingTimeInterval(3600)
                // Set the end time to the start of the next following hour
            }

            func recursiveSearch(with allPairs: [HourPair], lastCheapestPairIndex: Int? = nil) -> Int? {
                // print("Running recursive search to find cheapest time")
                var cheapestPairIndex = self.compareHourPairs(allPairs: allPairs)

                if cheapestPairIndex != nil {
                    if lastCheapestPairIndex != cheapestPairIndex {
                        var performAnotherSearch = false

                        let cheapestPair = allPairs[cheapestPairIndex!]
                        var maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                        let startTimeHourEnd = startTime.addingTimeInterval(3600)
                        let endTimeHourStart = endTime.addingTimeInterval(-3600)
                        let startDateFirstItem = Date(timeIntervalSince1970: TimeInterval(cheapestPair.associatedPricePoints[0].startTimestamp))
                        let endDateLastItem = Date(timeIntervalSince1970: TimeInterval(cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp))

                        var intervenesWithStartHour = false
                        if startDateFirstItem >= startTime, startDateFirstItem < startTimeHourEnd {
                            intervenesWithStartHour = true
                        }
                        var intervenesWithEndHour = false
                        if endDateLastItem > endTimeHourStart, endDateLastItem <= endTime {
                            intervenesWithEndHour = true
                        }

                        func searchAndAddFollowingItem(timestamp: Int) {
                            // Find next following energy price point
                            for item in energyData.prices {
                                if item.startTimestamp == timestamp {
                                    cheapestPair.associatedPricePoints.append(item)
                                    // print("Found the missing energy price point with start timestamp \(item.startTimestamp).")
                                    break
                                }
                            }
                        }

                        if intervenesWithStartHour, !intervenesWithEndHour, startTimeDifference != 0 {
                            // print("Intervenes with start hour")
                            searchAndAddFollowingItem(timestamp: Int(endDateLastItem.timeIntervalSince1970))
                            maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                            cheapestPair.associatedPricePoints[0].startTimestamp += startTimeDifference * 60
                            cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp -= (60 - startTimeDifference) * 60
                            performAnotherSearch = true
                        }

                        func searchAndAddPreFollowingItem(timestamp: Int) {
                            // Find the pre-following price point
                            for item in energyData.prices {
                                if item.endTimestamp == timestamp {
                                    // print("Found the missing energy price point with end timestamp \(item.endTimestamp).")
                                    cheapestPair.associatedPricePoints.insert(item, at: 0)
                                    break
                                }
                            }
                        }

                        if intervenesWithEndHour, !intervenesWithStartHour, endTimeDifference != 0 {
                            // print("Intervenes with end hour")
                            searchAndAddPreFollowingItem(timestamp: Int(startDateFirstItem.timeIntervalSince1970))
                            maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                            cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp -= (60 - endTimeDifference) * 60
                            cheapestPair.associatedPricePoints[0].startTimestamp += endTimeDifference * 60
                            performAnotherSearch = true
                        }

                        if intervenesWithStartHour, intervenesWithEndHour {
                            // print("Intervenes with both start and end hour")
                            // No need to change something
                        }

                        if performAnotherSearch {
                            cheapestPair.calculateAveragePrice()
                            cheapestPairIndex = recursiveSearch(with: allPairs, lastCheapestPairIndex: cheapestPairIndex)
                        }
                    }
                } else {
                    return nil
                }

                return cheapestPairIndex
            }

            let allPairs = self.createHourPairs(forHours: timeRangeNumber, fromStartTime: startTime, toEndTime: endTime, with: energyData)
            let results = recursiveSearch(with: allPairs)
            let cheapestHourPairIndex = results

            if cheapestHourPairIndex != nil {
                let cheapestPair = allPairs[cheapestHourPairIndex!]

                let timeRangeDifference = ((((Double(timeRangeNumber) - self.timeOfUsage) * 10000).rounded(.down) / 10000) * 60).rounded(.down)
                if timeRangeDifference != 0 {
                    let maxPointIndex = cheapestPair.associatedPricePoints.count - 1

                    // If the user searches for a time with hours and minutes like 2,3h or 1h 40min than this if statment triggers
                    // It makes sure that the start timestamp and end timestamp is set correctly to met the users wished output (hours and minutes)
                    if cheapestPair.associatedPricePoints[0].marketprice <= cheapestPair.associatedPricePoints[maxPointIndex].marketprice {
                        cheapestPair.associatedPricePoints[maxPointIndex].endTimestamp -= Int(timeRangeDifference * 60)
                    } else {
                        cheapestPair.associatedPricePoints[0].startTimestamp += Int(timeRangeDifference * 60)
                    }
                }

//                if currentSetting.setting != nil {
//                    cheapestPair.calculateHourlyPrice(currentSetting: currentSetting)
//                }
            }

            DispatchQueue.main.async {
                if cheapestHourPairIndex != nil {
                    self.cheapestHoursForUsage = allPairs[cheapestHourPairIndex!]
                } else {
                    self.errorOccurredFindingCheapestHours = true
                }
            }
        }
    }
}