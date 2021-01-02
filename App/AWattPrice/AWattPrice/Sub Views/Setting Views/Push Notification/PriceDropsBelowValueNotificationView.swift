//
//  NewPricesNotificationView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

struct PriceDropsBelowValueNotificationSubView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var keyboardObserver: KeyboardObserver
    
    @ObservedObject var crtNotifiSetting: CurrentNotificationSetting
    
    @State var changesAndStaged = false
    @State var initialAppearFinished: Bool? = false
    @State var priceBelowValue: String = ""
    @State var priceDropsBelowValueNotificationSelection = false
    
    func getPriceBelowValueCentString(value: Double) -> String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 2

        if let result = numberFormatter.string(from: NSNumber(value: value)) {
            return result
        } else {
            return nil
        }
    }
    
    init(crtNotifiSetting: CurrentNotificationSetting) {
        _crtNotifiSetting = ObservedObject(initialValue: crtNotifiSetting)
        _priceDropsBelowValueNotificationSelection = State(initialValue: self.crtNotifiSetting.entity!.priceDropsBelowValueNotification)
        _priceBelowValue = State(initialValue: getPriceBelowValueCentString(value: self.crtNotifiSetting.entity!.priceBelowValue) ?? "")
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: nil,
            footer: Text("notificationPage.notification.priceDropsBelowValue.description")
        ) {
            VStack(spacing: 20) {
                HStack {
                    Text("notificationPage.notification.priceDropsBelowValue")
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    Toggle("", isOn: $priceDropsBelowValueNotificationSelection.animation())
                        .labelsHidden()
                        .onChange(of: priceDropsBelowValueNotificationSelection) { newValue in
                            crtNotifiSetting.changePriceDropsBelowValueNotifications(newValue: newValue)
                            initiateBackgroundNotificationUpdate(currentSetting: currentSetting, crtNotifiSetting: crtNotifiSetting)
                        }
                }
                
                if priceDropsBelowValueNotificationSelection {
                    HStack {
                        DecimalTextFieldWithDoneButton(text: $priceBelowValue, placeholder: "general.cent.long".localized(), plusMinusButton: true)
                            .fixedSize(horizontal: false, vertical: true)
                            .onChange(of: priceBelowValue) { newValue in
                                var newDoubleValue: Double = 0
                                if let newConvertedDoubleValue = newValue.doubleValue {
                                    newDoubleValue = (newConvertedDoubleValue * 100).rounded() / 100
                                }
                                crtNotifiSetting.changePriceBelowValue(newValue: newDoubleValue)
                                priceBelowValue = getPriceBelowValueCentString(value: newDoubleValue) ?? ""
                                changesAndStaged = true
                            }
                        
                        if priceBelowValue != "" {
                            Text("general.cent.short")
                                .transition(.opacity)
                        }
                    }
                    .padding(.leading, 17)
                    .padding(.trailing, 14)
                    .padding([.top, .bottom], 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hue: 0.0000, saturation: 0.0000, brightness: 0.8706), lineWidth: 2)
                    )
                }
            }
            .padding([.top, .bottom], 2)
            .onReceive(keyboardObserver.keyboardHeight) { newKeyboardHeight in
                if self.changesAndStaged && newKeyboardHeight == 0 {
                    initiateBackgroundNotificationUpdate(currentSetting: currentSetting, crtNotifiSetting: crtNotifiSetting)
                }
            }
        }
    }
}

struct PriceDropsBelowValueNotificationView: View {
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    
    var body: some View {
        PriceDropsBelowValueNotificationSubView(crtNotifiSetting: crtNotifiSetting)
    }
}

struct NewPricesNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PriceDropsBelowValueNotificationView()
                .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
                .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
        }
    }
}
