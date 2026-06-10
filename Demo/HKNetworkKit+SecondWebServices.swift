
//
//  HKNetworkKit+SecondEndpoint.swift
//  nexovor-technology
//
//  Created by Harsh Kadiya on 05/03/25.
//

import Foundation

class SecondEndpoint {
    
    // START: Authentication
    func getExternalAPI(request: ScanHistory, completion: @escaping (Result<RecommedationsModel, Error>) -> Void)
    {
        guard let jsonData = try? JSONEncoder().encode(request) else { return }
        APIService.shared.request(SecondEndpoint.getExternalAPI, body: jsonData, completion: completion)
    }
    
}
