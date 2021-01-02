//
//  NoNotificationAccessView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.01.21.
//

import SwiftUI

struct NoNotificationAccessView: View {
    var body: some View {
        CustomInsetGroupedListItem {
            VStack(alignment: .center, spacing: 30) {
                Text("To receive AWattPrice notifications, please allow these in the Settings App.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.gray)
                
                Button(action: {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }) {
                    Text("Open Settings App")
                }
                .buttonStyle(RoundedBorderButtonStyle())
            }
        }
        .disableBackgroundColor(true)
    }
}

struct NoNotificationAccessView_Previews: PreviewProvider {
    static var previews: some View {
        NoNotificationAccessView()
    }
}
