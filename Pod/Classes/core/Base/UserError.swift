//
//  UserError.swift
//  AptoSDK
//
//  Created by Takeichi Kanzaki on 14/08/2018.
//
//

import Foundation

public class UserError: NSError {
    private let userErrorDomain = "com.shiftpayments.user.error"
    private let errorCode = 1436

    public init(message: String) {
        let userInfo = [NSLocalizedDescriptionKey: message]
        super.init(domain: userErrorDomain, code: errorCode, userInfo: userInfo)
    }

    @available(*, unavailable)
    public required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
