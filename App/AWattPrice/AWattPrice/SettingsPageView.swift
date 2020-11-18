//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SceneKit
import SwiftUI

/// A place for the user to modify certain settings. Those changes are automatically stored (if modified) in persistent storage.
struct SettingsPageView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            CustomInsetGroupedList {
                PricesWithVatIncludedSetting()
                    .onTapGesture {
                            self.hideKeyboard()
                    }

                AwattarTariffSelectionSetting()

                GetHelpView()
                    .onTapGesture {
                            self.hideKeyboard()
                    }

                AppVersionView()
                    .onTapGesture {
                        self.hideKeyboard()
                    }
            }
            .navigationTitle("settings")
            .navigationViewStyle(StackNavigationViewStyle())
            .navigationBarItems(trailing: DoneNavigationBarItem(presentationMode: presentationMode))
        }
    }
    
    struct DoneNavigationBarItem: View {
        @EnvironmentObject var currentSetting: CurrentSetting
        @Binding var presentationMode: PresentationMode
        
        var body: some View {
            Button(action: {
                currentSetting.validateTariffAndEnergyPriceSet()
                presentationMode.dismiss()
            }) {
                HStack {
                    Text("Done")
                        .bold()
                        .font(.subheadline)
                }
                .foregroundColor(Color.blue)
                .padding(5)
                .padding([.leading, .trailing], 3)
            }
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
