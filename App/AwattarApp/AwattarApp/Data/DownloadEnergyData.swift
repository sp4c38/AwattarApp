//
//  DownloadEnergyData.swift
//  AwattarApp
//
//  Created by Léon Becker on 07.09.20.
//

import Foundation

struct EnergyPricePoint: Hashable, Codable {
    var startTimestamp: Int
    var endTimestamp: Int
    var marketprice: Float
    
    enum CodingKeys: String, CodingKey {
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case marketprice = "marketprice"
    }
}

struct EnergyData: Codable {
    var prices: [EnergyPricePoint]
    var minPrice: Float = 0
    var maxPrice: Float = 0
    
    enum CodingKeys: String, CodingKey {
        case prices = "prices"
    }
}

struct Profile: Hashable {
    var name: String
    var imageName: String
}

struct ProfilesData {
    var profiles = [
        Profile(name: "HOURLY", imageName: "hourlyProfilePicture"),
        Profile(name: "HOURLY-CAP", imageName: "hourlyCapProfilePicture"),
        Profile(name: "YEARLY", imageName: "yearlyProfilePicture")]
}

class AwattarData: ObservableObject {
    // Needs to be an observable object because the data is downloaded asynchronously from the server
    // and views need to check when downloading the data finished
    
    @Published var networkConnectionError = false
    @Published var energyData: EnergyData? = nil // Energy Data with all hours included
    @Published var profilesData = ProfilesData()

    init() {
        var energyRequest = URLRequest(
                        url: URL(string: "https://www.space8.me:9173/awattar_app/data/")!,
                        cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy)
        
        energyRequest.httpMethod = "GET"
        
        let _ = URLSession.shared.dataTask(with: energyRequest) { data, response, error in
            let jsonDecoder = JSONDecoder()
            var decodedData = EnergyData(prices: [], minPrice: 0, maxPrice: 0)
            
            if let data = data {
                do {
                    decodedData = try jsonDecoder.decode(EnergyData.self, from: data)
                    let currentHour = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date())!

                    var usedPricesDecodedData = [EnergyPricePoint]()
                    var minPrice: Float? = nil
                    var maxPrice: Float? = nil
                    
                    for hourPoint in decodedData.prices {
                        if Date(timeIntervalSince1970: TimeInterval(hourPoint.startTimestamp)) >= currentHour {
                            usedPricesDecodedData.append(hourPoint)
                            if maxPrice == nil || hourPoint.marketprice > maxPrice! {
                                maxPrice = hourPoint.marketprice
                            }
                            
                            if minPrice == nil {
                                if hourPoint.marketprice < 0 {
                                    minPrice = hourPoint.marketprice
                                }
                            } else if hourPoint.marketprice < minPrice! {
                                minPrice = hourPoint.marketprice
                            }
                        }
                    }
                    
                    
                    DispatchQueue.main.async {
                        self.energyData = EnergyData(prices: usedPricesDecodedData, minPrice: (minPrice != nil ? minPrice! : 0), maxPrice: (maxPrice != nil ? maxPrice! : 0))
                    }
                } catch {
                    fatalError("Could not decode returned JSON data from server.")
                }
            } else {
                if let error = error as NSError?, error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet {
                    DispatchQueue.main.async {
                        self.networkConnectionError = true
                    }
                }
            }
        }.resume()
    }
}
