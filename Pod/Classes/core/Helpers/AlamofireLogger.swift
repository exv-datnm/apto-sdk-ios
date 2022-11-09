//
//  AlamofireLogger.swift
//  AptoCoreSDK
//
//  Created by Dat Ng on 9/11/2022.
//

import Foundation
import Alamofire
import SwiftyJSON

final class AptoAlamofireLogger: EventMonitor {

    func requestDidResume(_ request: Request) {
        guard AptoPlatform.shared.debugLogEnable else { return }

        request.cURLDescription(calling: { (curl) in
            print(curl)
        })
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        guard AptoPlatform.shared.debugLogEnable else { return }

        print("Response Received: \(response.debugDescription)")
        print("Response Headers: \(String(describing: response.response?.allHeaderFields))")
    }
}
