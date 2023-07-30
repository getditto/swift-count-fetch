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
    private var fetcherTask: Task<Void, Never>?
    
    init(ditto: Ditto) {
        self.ditto = ditto
    }
    
    nonisolated func fetchAttachmentData(in docs: [DittoDocument], collName: String) {
        Task {
            if let _ = await fetcherTask {
                await resetFetch()
            }
            await fetchData(in: docs, collName: collName)
        }
    }
    
    private func fetchData(in docs: [DittoDocument], collName: String) {
        print("DF.fetchData(): START BACKGROUND ATTACHMENT DATA FETCH: \(Date().description)")
        
        fetcherTask = Task (priority: .background) {
            
            await withTaskGroup(of: Void.self) {[weak self] taskGroup in
                guard let self = self else {
                    print("[taskGroup.loop] -- top of withTaskGroup --: NO SELF --> RETURN")
                    return
                }
                guard let task = await fetcherTask, !task.isCancelled else {
                    print("taskGroup detected fetcherTask CANCELED. CALL taskGroup.cancelAll() --> RETURN")
                    taskGroup.cancelAll()
                    return
                }
                
                for doc in docs {
                    guard let token = doc["content"].attachmentToken else {
                        print("[taskGroup.loop] doc contained no token --> continue")
                        continue
                    }
                    
                    guard taskGroup.addTaskUnlessCancelled(
                        operation: {[weak self] in
                            guard let self = self else {
                                print("top of addTaskUnlessCancelled: NO SELF --> RETURN")
                                return
                            }
                            
                            let fetcherId = UUID().uuidString
                            if let fetcher = await fetcher(
                                token: token,
                                collName: collName,
                                id: fetcherId,
                                docId: doc.id.stringValue
                            ) {
                                let fetcherWrapper = FetcherWrapper(id: fetcherId, fetcher: fetcher)
                                await self.addFetcher(fetcherWrapper)
                            }
                        }) else {
                        print("taskGroup.addTaskUnlessCancelled: detected CANCELLED --> RETURN")
                        return
                    }
                }
            }
        }
    }

    private func fetcher(
        token: DittoAttachmentToken,
        collName: String,
        id: String,
        docId: String
    ) async -> DittoAttachmentFetcher? {
        guard let task = fetcherTask, !task.isCancelled else {
            print("[taskGroup.fetcher for docId: \(docId)] detected CANCELED task BEFORE fetch call --> RETURN")
            return nil
        }
        
        return ditto.store[collName].fetchAttachment(token: token) {[weak self] event in
            let fetcherId = id
            let docId = docId
            
            guard !task.isCancelled else {
                print("[taskGroup.fetcher \(fetcherId)] detected CANCELLED task IN fetch callback --> RETURN")
                return
            }
            
            guard let self = self else {
                print("taskGroup.fetcher \(fetcherId)] callback: NO SELF --> RETURN")
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
                    print("[taskGroup.fetcher.docId \(docId)] success")
                } catch {
                    print("[taskGroup.fetcher.docId \(docId)] getData() FAIL with error: \(error.localizedDescription)")
                }
            default:
                print("[taskGroup.fetcher.docId \(docId)] ERROR .default case for event")
            }

            Task {
                await self.completedFetch(id: id, docId: docId)
            }
        }
    }
        
    private func resetFetch() {
        print("reset() --> in")
        if let task = fetcherTask {
            print("\n\n<------------------------- SET TASK CANCEL --------------------------->\n\n")
            task.cancel()
            cancelFetchers()
            fetchers.removeAll()
        }
    }
    
    private func addFetcher(_ wrapper: FetcherWrapper) {
        fetchers[wrapper.id] = wrapper
    }

    func completedFetch(id: String, docId: String) {
        if let wrapper = fetchers[id] {
            print("DF.fetcher complete for docId: \(docId)")
            fetchers.removeValue(forKey: id)
        }
    }

    private func cancelFetchers() {
        print("DF.cancelFetchers() --> in")
        for (_, wrapper) in fetchers {
            wrapper.fetcher.stop()
        }
    }
}

/* initial attempted implementation
private func fetchData(in docs: [DittoDocument], collName: String) {
    print("DF.fetchData(): START BACKGROUND ATTACHMENT DATA FETCH: \(Date().description)")
    
    fetcherTask = Task (priority: .background) {
        
        await withTaskGroup(of: Void.self) {[weak self] taskGroup in
            guard let self = self else {
                print("[taskGroup.loop] -- top of withTaskGroup --: NO SELF --> RETURN")
                return
            }
            guard let task = await fetcherTask, !task.isCancelled else {
                print("taskGroup detected fetcherTask CANCELED. CALL taskGroup.cancelAll() --> RETURN")
                taskGroup.cancelAll()
                return
            }
            
            for doc in docs {
                guard let token = doc["content"].attachmentToken else {
                    print("[taskGroup.loop] doc contained no token --> continue")
                    continue
                }
                
                guard taskGroup.addTaskUnlessCancelled(
                    operation: {[weak self] in
                        guard let self = self else {
                            print("top of addTaskUnlessCancelled: NO SELF --> RETURN")
                            return
                        }
                        
                        let fetcherId = UUID().uuidString
                        if let fetcher = await fetcher(
                            token: token,
                            collName: collName,
                            id: fetcherId,
                            docId: doc.id.stringValue
                        ) {
                            let fetcherWrapper = FetcherWrapper(id: fetcherId, fetcher: fetcher)
                            await self.addFetcher(fetcherWrapper)
                        }
                    }) else {
                    print("taskGroup.addTaskUnlessCancelled: detected CANCELLED --> break")
                    return
                }
            }
        }
    }
}

private func fetcher(token: DittoAttachmentToken, collName: String, id: String, docId: String) async -> DittoAttachmentFetcher? {
    
    guard let task = fetcherTask, !task.isCancelled else {
        print("[taskGroup.fetcher for docId: \(docId)] detected CANCELED task BEFORE fetch call --> RETURN")
        return nil
    }
    
    return ditto.store[collName].fetchAttachment(
        token: token,
        id: id, //fetcherId,
        docId: docId,
        deliverOn: .main,
//            completion: completion,
        onFetchEvent: {[weak self] event in
//            {[weak self] event in
            let fetcherId = id
            let docId = docId
//                let completion = completion
            
            guard !task.isCancelled else {
                print("[taskGroup.fetcher \(fetcherId)] detected CANCELLED task IN fetch callback --> RETURN")
                return
            }
            
            guard let self = self else {
                print("taskGroup.fetcher \(fetcherId)] callback: NO SELF --> RETURN")
                return
            }
            
            switch event {
            case .progress(let downloadedBytes, let totalBytes):
                _ = Double(downloadedBytes) / Double(totalBytes)
//                                print("[taskGroup.fetcher \(fetcherId)] -- PROGRESS -- return")
                return
            case .completed(let attachment):
                do {
                    // access data to check for error
                    _ = try attachment.getData()
                    print("[taskGroup.fetcher.docId \(docId)] success")
                } catch {
                    print("[taskGroup.fetcher.docId \(docId)] getData() FAIL with error: \(error.localizedDescription)")
                }
            default:
                print("[taskGroup.fetcher.docId \(docId)] ERROR .default case for event")
            }

//                completion(fetcherId, docId)
            Task { await self.completedFetch(id: id, docId: docId) }
        }
    )
}
*/
