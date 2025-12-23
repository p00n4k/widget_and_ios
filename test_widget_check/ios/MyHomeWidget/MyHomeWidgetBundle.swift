//
//  MyHomeWidgetBundle.swift
//  MyHomeWidget
//
//  Created by Pawin on 27/2/2568 BE.
//

import WidgetKit
import SwiftUI

@main
struct MyHomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyHomeWidget()

        if #available(iOS 18.0, *) {
            MyHomeWidgetControl()
            MyHomeWidgetLiveActivity()
        }
    }
}
