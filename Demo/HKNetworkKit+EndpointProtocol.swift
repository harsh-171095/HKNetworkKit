//
//  APIManager.swift
//  HKNetworkKit+Demo
//
//  Created by Harsh Kadiya on 05/03/25.
//

import Foundation
import HKNetworkKit

// `EndpointProtocol` now lives in the NetworkKit framework. All endpoint enums
// below conform to it; the framework bridges them into full requests.

typealias QueryParameters = [String: String]

extension QueryParameters {
    var toString: String {
        return map { key, value in
            return "\(key)=\(value)"
        }.joined(separator: "&")
    }
}

enum AppEndpoint: EndpointProtocol {
    
    var headers: [String : String] {
            var headers: [String: String] = [
                "platform": "ios",
                "version": "1.1",
            ]
            
            if (AppStorage.shared.token?.isNotEmptyValue ?? false) {
                headers["Authorization"] = "Bearer \(AppStorage.shared.token ?? "")"
            }
            
            return headers
    }
    
    
    var baseURL: String { return "https://{DOMIN}/PATH"}
    
    case login, register, forgotPassword
    case getProfile, updateProfile, deleteProfile
    case postScan, getAllScanHistory(QueryParameters), getScanById(String), getScanPDFById(String), consumeCredit
    case getAvailableCredits ,getCreditPackages, getUserPackages, getDeviceVersion
    case paymentInitiate, paymentVerify
    case getCalendar(QueryParameters), getScanHistoryByDate(QueryParameters)
    
    var endpoint: String{
        switch self {
            case .login:                    return "/auth/login"
            case .register:                 return "/auth/signup"
            case .forgotPassword:           return "/auth/forgot-password"
            case .postScan:                 return "/user/order-history"
            case .getAllScanHistory:        return "/user/order-history\(queryParames)"
            case .getScanById(let path):    return "/user/order-history/\(path)" // /user/scan-history/5
            case .getScanPDFById(let path): return "/billing/pdf/\(path)"
        }
    }
    
    var queryParames: String {
        switch self {
            case .getAllScanHistory(let para):  return "?\(para.toString)"
            default: return ""
        }
    }
    
    var method: String {
        switch self {
            case .login:                return "POST"
            case .register:             return "POST"
            case .forgotPassword:       return "POST"
            case .postScan:             return "POST"
            case .getScanById:          return "GET"
            case .getScanPDFById:       return "GET"
        }
    }
    
    
}

enum MyResetZoneEndpoint: EndpointProtocol {
    var baseURL: String { return "https://{DOMIN_2_EXTERNAL_APIS}/PATH"}
    
    var headers: [String : String] {
        var headers: [String: String] = [
            "platform": "ios",
        ]
        
        headers["x-api-key"] = "THERE_X_API_KEY"
        
        return headers
    }
    
    case getExternalAPI
    
    var endpoint: String {
        switch self {
            case .getExternalAPI: return "/END_POINT"
        }
    }
    
    var method: String {
        switch self {
            case .getExternalAPI: return "POST"
        }
    }
    
    var queryParames: String {
        switch self {
            default: return ""
        }
    }
    
    
    
}
