//
//  WebServices.swift
//  nexovor-technology
//
//  Created by Harsh Kadiya on 05/03/25.
//

import Foundation

class WebServices {
    
        // START: Authentication
    func loginUser(request: UserLoginRequest, completion: @escaping (Result<APIResultWrapper<AuthResponseModel>, Error>) -> Void)
    {
        guard let jsonData = try? JSONEncoder().encode(request) else { return }
        
        APIService.shared.request(FirstEndpoint.login, body: jsonData, completion: completion)
    }
    
    func registerUser(request: UserRegisterRequest, completion: @escaping (Result<APIResultWrapper<AuthResponseModel>, Error>) -> Void)
    {
        guard let jsonData = try? JSONEncoder().encode(request) else { return }
        APIService.shared.request(FirstEndpoint.register, body: jsonData, completion: completion)
    }
    
    func forgotPassword(request: ForgotPasswordRequest, completion: @escaping (Result<APIResultWrapper<EmptyDecodable>, Error>) -> Void)
    {
        guard let jsonData = try? JSONEncoder().encode(request) else { return }
        APIService.shared.request(FirstEndpoint.forgotPassword, body: jsonData, completion: completion)
    }
    
    //
    func postOrder(_ request: PostScanRequest,
                  completion: @escaping (Result<APIResultWrapper<ScanResponse>, Error>) -> Void)
    {
        guard let jsonData = try? JSONEncoder().encode(request) else { return }
        APIService.shared.request(FirstEndpoint.postOrder, body: jsonData, completion: completion)
    }
    
    func getAllOrderHistory(page: Int = 1, completion: @escaping (Result<APIResultWrapper<ScanHistoryResponse>, Error>) -> Void)
    {
        let queryItems: QueryParameters = [
            "page": String(page),
            "limit": String(10),
        ]
        
        APIService.shared.request(FirstEndpoint.getAllOrderHistory(queryItems), completion: completion)
    }
    
    func getOrderById(scan id: Int, completion: @escaping (Result<APIResultWrapper<ScanResponse>, Error>) -> Void)
    {
        
        APIService.shared.request(FirstEndpoint.getOrderById(id.toString), completion: completion)
    }
    
    func getOrderPDFById(scan id: Int, completion: @escaping (Result<APIResultWrapper<ScanPDFResponse>, Error>) -> Void)
    {
        
        APIService.shared.request(FirstEndpoint.getOrderPDFById(id.toString), completion: completion)
    }
    
}
