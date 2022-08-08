//
// Created by Ulrik Gammelby on 07/08/2022.
// Copyright (c) 2022 Nabto. All rights reserved.
//

import Foundation
import NabtoEdgeIamUtil

struct EdgeDevice {
    let details: DeviceDetails
    var id: String {
        get {
            return "\(self.details.ProductId).\(self.details.DeviceId)"
        }
    }
    init(details: DeviceDetails) {
        self.details = details
    }
}