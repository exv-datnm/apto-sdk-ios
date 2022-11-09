//
//  AlamofireLogger.swift
//  AptoCoreSDK
//
//  Created by Dat Ng on 9/11/2022.
//

import Foundation
import Alamofire
import SwiftyJSON

public final class AptoAlamofireLogger: EventMonitor {

    func requestDidResume(_ request: Request) {
        request.cURLDescription(calling: { (curl) in
            print(curl)
        })
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: AFDataResponse<Value>) {
        print("Response Received: \(response.debugDescription)")
        print("Response Headers: \(String(describing: response.response?.allHeaderFields))")
    }
}
