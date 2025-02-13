//
//  NetworkManager.swift
//  AptoSDK
//
//  Created by Takeichi Kanzaki on 06/07/2018.
//
//

import Alamofire
import AlamofireNetworkActivityIndicator
import FTLinearActivityIndicator
import SwiftyJSON
import TrustKit

public struct NetworkRequest {
    let url: URLConvertible
    let method: HTTPMethod
    let parameters: [String: Any]?
    let body: String?
    let headers: [String: String]
    let filterInvalidTokenResult: Bool
    let callback: Swift.Result<JSON, NSError>.Callback
}

public protocol NetworkManagerProtocol {
    var delegate: SessionDelegate { get }

    func request(_ networkRequest: NetworkRequest)
    func runPendingRequests()
}

final class NetworkManager: NetworkManagerProtocol {
    private let manager: Session
    private let reachabilityManager: NetworkReachabilityManager?
    private let notificationHandler: NotificationHandler
    private var configuration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180 // seconds
        configuration.timeoutIntervalForResource = 180

        return configuration
    }()

    private var pendingRequests = [NetworkRequest]()

    private static var certPinningConfig: [String: [String: AnyObject]] = [:]
    private static let setupCertPinningConfig: Void = {
        TrustKit.initSharedInstance(withConfiguration: [kTSKPinnedDomains: NetworkManager.certPinningConfig])
        return ()
    }()

    var delegate: SessionDelegate {
        return manager.delegate
    }

    init(
        baseURL: URL? = nil, certPinningConfig: [String: [String: AnyObject]]? = nil,
        allowSelfSignedCertificate: Bool = false, notificationHandler: NotificationHandler)
    {
        self.notificationHandler = notificationHandler
        if let baseURL = baseURL, let host = baseURL.host, allowSelfSignedCertificate {
            let serverTrustPolicies: [String: ServerTrustEvaluating] = [
                "\(host)": DisabledTrustEvaluator(),
            ]
            let serverTrustManager = ServerTrustManager(evaluators: serverTrustPolicies)
            manager = Session(configuration: configuration, serverTrustManager: serverTrustManager, eventMonitors: [ AptoAlamofireLogger() ])
            reachabilityManager = NetworkReachabilityManager(host: baseURL.absoluteString)
        } else {
            manager = Session(configuration: configuration, eventMonitors: [ AptoAlamofireLogger() ])
            reachabilityManager = NetworkReachabilityManager()
        }
        reachabilityManager?.startListening(onUpdatePerforming: networkStatusChanged(_:))
        if let certPinningConfig = certPinningConfig {
            setupCertificatePinning(certPinningConfig)
        }
        UIApplication.configureLinearNetworkActivityIndicatorIfNeeded()
        NetworkActivityIndicatorManager.shared.isEnabled = true
        NetworkActivityIndicatorManager.shared.startDelay = 0
        NetworkActivityIndicatorManager.shared.completionDelay = 0.5
    }

    func request(_ request: NetworkRequest) {
        if (request.body != nil) {
            bodyRequest(request)
            return
        }

        let httpHeaders = HTTPHeaders(completeHeaders(request.headers))
        manager.request(request.url,
                        method: request.method,
                        parameters: request.parameters,
                        encoding: JSONEncoding.default,
                        headers: httpHeaders)
            .responseJSON { [unowned self] response in
                let processedResponse = self.processResponse(response).map { json -> JSON in JSON(json) }
                switch processedResponse {
                case .failure:
                    self.processErrorResponse(processedResponse, request: request)
                case .success:
                    request.callback(processedResponse)
                }
            }
    }

    private func bodyRequest(_ request: NetworkRequest) {
        guard let body = request.body, let url = try? request.url.asURL() else {
            return
        }

        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = request.method.rawValue
        urlReq.headers = HTTPHeaders(request.headers)
        urlReq.httpBody = (body).data(using: .utf8)

        manager.request(urlReq).responseJSON{[unowned self] response in
            let processedResponse = self.processResponse(response).map { json -> JSON in JSON(json) }
            switch processedResponse {
            case .failure:
                self.processErrorResponse(processedResponse, request: request)
            case .success:
                request.callback(processedResponse)
            }
        }
    }

    func runPendingRequests() {
        let requests = pendingRequests
        pendingRequests.removeAll()
        for req in requests {
            request(req)
        }
    }

    private func setupCertificatePinning(_ certPinningConfig: [String: [String: AnyObject]]) {
        NetworkManager.certPinningConfig = certPinningConfig
        _ = NetworkManager.setupCertPinningConfig
    }

    private func completeHeaders(_ headers: [String: String]) -> [String: String] {
        var retVal = headers
        retVal["X-Api-Version"] = "1.0"
        retVal["X-SDK-Version"] = AptoSDK.version
        retVal["X-Device"] = "iOS"
        retVal["X-Device-Version"] = "\(UIDevice.current.platform) - \(UIDevice.current.systemVersion)"
        return retVal
    }

    private func processResponse(_ response: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        if let originalError = response.error {
            ErrorLogger.defaultInstance().log(error: originalError)
        }

        switch response.response?.statusCode {
        case 401:
            return processInvalidSession(response: response)
        case 412:
            return processSDKDeprecated(response: response)
        case 429:
            return processServerError(with: .tooManyRequests, response: response)
        case 503:
            return processServerMaintenance(response: response)
        case .some(400 ..< 500):
            return process400(response: response)
        case .some(500 ..< 600):
            return process500(response: response)
        default:
            return processSuccess(response: response)
        }
    }

    private func processSuccess(response: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        if response.result.error != nil {
            debugPrint(response)
        }

        switch response.result {
        case let .success(value):
            return .success(value as AnyObject)
        case let .failure(error):
            return .failure(error as NSError)
        }
    }

    private func processInvalidSession(response: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        let json = JSON(response.value ?? "")
        let error = json.backendError ?? BackendError(code: .invalidSession)
        if isInvalidSession(error) {
            notificationHandler.postNotification(.UserTokenSessionInvalidNotification, userInfo: ["error": error])
        } else if error.sessionExpiredError() {
            notificationHandler.postNotification(.UserTokenSessionExpiredNotification, userInfo: ["error": error])
        }
        ErrorLogger.defaultInstance().log(error: error)
        return .failure(error)
    }

    private func isInvalidSession(_ error: BackendError) -> Bool {
        error.unknownSessionError() || error.isSessionAuthError ||
            error.isEmptySession || error.invalidSessionError()
    }

    private func processSDKDeprecated(response _: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        let error = BackendError(code: .sdkDeprecated)
        ErrorLogger.defaultInstance().log(error: error)
        return .failure(error)
    }

    private func process400(response: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        let json = JSON(response.value ?? "")
        let error = json.backendError ?? BackendError(code: .incorrectParameters)
        return .failure(error)
    }

    private func processServerMaintenance(response _: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        let error = BackendError(code: .serverMaintenance)
        return .failure(error)
    }

    private func processServerError(with code: BackendError.ErrorCodes,
                                    response _: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError>
    {
        let error = BackendError(code: code)
        return .failure(error)
    }

    private func process500(response: DataResponse<Any, AFError>) -> Swift.Result<AnyObject, NSError> {
        switch response.result {
        case let .success(data):
            if let dict = data as? [String: Any], let rawCode = dict["code"] as? Int,
               let code = BackendError.ErrorCodes(rawValue: rawCode)
            {
                let error = BackendError(code: code, reason: response.error?.localizedDescription)
                return .failure(error)
            } else {
                let error = BackendError(code: .serviceUnavailable, reason: response.error?.localizedDescription)
                return .failure(error)
            }
        case .failure:
            let error = BackendError(code: .serviceUnavailable, reason: response.error?.localizedDescription)
            return .failure(error)
        }
    }

    private func processErrorResponse(_ response: Swift.Result<JSON, NSError>, request: NetworkRequest) {
        if response.isNetworkNotReachableError() {
            pendingRequests.append(request)
            notificationHandler.postNotification(.NetworkNotReachableNotification)
        } else if response.isServerMaintenanceError() {
            pendingRequests.append(request)
            notificationHandler.postNotification(.ServerMaintenanceNotification)
        } else if response.isSessionExpiredError() {
            if !request.filterInvalidTokenResult {
                request.callback(response)
            }
        } else if response.isSDKDeprecatedError() {
            notificationHandler.postNotification(.SDKDeprecatedNotification)
        } else if response.isKYCNotPassedError {
            pendingRequests.append(request)
            notificationHandler.postNotification(.KYCNotPassedNotification)
        } else {
            request.callback(response)
        }
    }
}

// Handle reachability changes
extension NetworkManager {
    private func networkStatusChanged(_ status: NetworkReachabilityManager.NetworkReachabilityStatus) {
        switch status {
        case .reachable:
            notificationHandler.postNotification(.NetworkReachableNotification)
            runPendingRequests()
        default:
            break
        }
    }
}

extension Swift.Result {
    func isSessionExpiredError() -> Bool {
        switch self {
        case let .failure(error):
            if let backendError = error as? BackendError {
                return backendError.sessionExpiredError()
            }
            return false
        default:
            return false
        }
    }

    func isServerMaintenanceError() -> Bool {
        switch self {
        case let .failure(error):
            return ((error as NSError).code == BackendError.ErrorCodes.serverMaintenance.rawValue)
        default:
            return false
        }
    }

    func isNetworkNotReachableError() -> Bool {
        switch self {
        case let .failure(error):
            return ((error as NSError).code == BackendError.ErrorCodes.networkNotAvailable.rawValue)
        default:
            return false
        }
    }

    func isSDKDeprecatedError() -> Bool {
        switch self {
        case let .failure(error):
            if let backendError = error as? BackendError {
                return backendError.sdkDeprecated()
            }
            return false
        default:
            return false
        }
    }

    var isKYCNotPassedError: Bool {
        switch self {
        case let .failure(error):
            if let backendError = error as? BackendError {
                return backendError.isKYCNotPassedError
            }
            return false
        default:
            return false
        }
    }
}

public extension Notification.Name {
    static let NetworkReachableNotification = Notification.Name("NetworkReachableNotification")
    static let NetworkNotReachableNotification = Notification.Name("NetworkNotReachableNotification")
    static let ServerMaintenanceNotification = Notification.Name("ServerMaintenanceNotification")
    static let SDKDeprecatedNotification = Notification.Name("SDKDeprecatedNotification")
    static let KYCNotPassedNotification = Notification.Name("KYCNotPassedNotification")
}
