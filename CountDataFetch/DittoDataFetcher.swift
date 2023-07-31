///
//  DittoDataFetcher.swift
//  CountDataFetch
//
//  Created by Eric Turner on 7/30/23.
//
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Combine
import DittoSwift
import Foundation

struct FetcherWrapper {
    let id: String
    let fetcher: DittoAttachmentFetcher
}

actor DittoDataFetcher {
    let ditto: Ditto
    private var fetchers = [String: FetcherWrapper]()
    private var fetcherQueue = DispatchQueue(label: "live.ditto.dataFetcherQueue", qos: .utility, attributes: .concurrent)
    
    init(ditto: Ditto) {
        self.ditto = ditto
    }
    
    nonisolated func fetchAttachmentData(in docs: [DittoDocument], collName: String) {
        Task(priority: .utility) {
            print("fetchAttachmentData(): await fetchData())")
            await fetchData(in: docs, collName: collName)
        }
    }
    
    private func fetchData(in docs: [DittoDocument], collName: String) async {
        print("DF.fetchData() --> in: START BACKGROUND ATTACHMENT DATA FETCH: \(Date().description)")
        
        for doc in docs {
            guard let token = doc["content"].attachmentToken else {
                print("[DF.docs loop doc contained no token --> continue")
                continue
            }
            
            let fetcherId = UUID().uuidString
            let docId = doc.id.stringValue
            if let fetcher = await fetcher(
                token: token,
                collName: collName,
                id: fetcherId,
                docId: docId
            ) {
                let fetcherWrapper = FetcherWrapper(id: fetcherId, fetcher: fetcher)
                addFetcher(fetcherWrapper, docId: docId)
            }
        }
    }

    private func fetcher(
        token: DittoAttachmentToken,
        collName: String,
        id: String,
        docId: String
    ) async -> DittoAttachmentFetcher? {
        
        return ditto.store[collName].fetchAttachment(
            token: token,
            deliverOn: fetcherQueue
        ) {[weak self] event in
            let fetcherId = id
            let docId = docId
            
            guard let self = self else {
                print("[fetcher \(fetcherId)] callback: NO SELF --> RETURN")
                return
            }
            
            switch event {
            case .progress(let downloadedBytes, let totalBytes):
                _ = Double(downloadedBytes) / Double(totalBytes)
//              print("[taskGroup.fetcher \(fetcherId)] -- PROGRESS -- return")
                return
            case .completed(let attachment):
                do {
                    // access data to check for error
                    _ = try attachment.getData()
                    print("[fetcher.docId \(docId)] success")
                } catch {
                    print("[fetcher.docId \(docId)] getData() FAIL with error: \(error.localizedDescription)")
                }
            default:
                print("[fetcher.docId \(docId)] ERROR .default case for event")
            }

            Task(priority: .utility) {
                await self.completedFetch(id: fetcherId, docId: docId)
            }
        }
    }

    private func addFetcher(_ wrapper: FetcherWrapper, docId: String) {
        print("DF.addFetcher() for docId: \(docId)")
        fetchers[wrapper.id] = wrapper
        print("DF.addFetcher(): fetchers.count \(fetchers.count)")
    }

    func completedFetch(id: String, docId: String) {
        print("DF.completedFetch() for docId: \(docId)")
        fetchers.removeValue(forKey: id)
        print("DF.completedFetch(): fetchers.count: \(fetchers.count)")
        
        if fetchers.isEmpty {
            print("DF.fetchData(): BACKGROUND ATTACHMENT DATA FETCH FINISH: \(Date().description)")
        }
    }
}
