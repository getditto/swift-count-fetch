///
//  DocsCounter.swift
//  CountDataFetch
//
//  Created by Eric Turner on 7/14/23.
//
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Foundation


struct DocsCounter {
    let session = URLSession.shared
    let environment: String = "cloud.ditto.live"
    
    /* json structure of the count query request
    {
      "collection": [collection name],
      "query": "true"
    }
    */
    func request(_ endpoint: String) -> URLRequest {
        var url = URL(string: "https://\(Env.DITTO_APP_ID).\(environment)/api/v3/store")!
        url = url.appendingPathComponent(endpoint)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("AAAAAAAAAAAAAAAAAAAABQ==", forHTTPHeaderField: "X-HYDRA-CLIENT-ID")
        req.setValue("Bearer \(Env.DITTO_API_KEY)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        return req
    }
    
    func fetchCount(from collName: String) async throws -> Int {
        struct RequestData: Encodable {
            let collection: String
            let query: String
        }
        
        struct BigPeerCount: Decodable {
            let count: Int
            let txnId: Int
        }
        
        let encoder = JSONEncoder()
        do {
            let requestData = try encoder.encode(RequestData(collection: collName, query: "true"))
            let (data, _) = try await URLSession.shared.upload(for: request("count"), from: requestData)
            let bpCount = try JSONDecoder().decode(BigPeerCount.self, from: data)
            return bpCount.count
        } catch {
            print(error.localizedDescription)
            throw error
        }
    }
}
