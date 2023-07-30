///
//  DittoService.swift
//  CountDataFetch
//
//  Created by Eric Turner on 7/24/23.
//
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Combine
import DittoSwift
import SwiftUI

class DittoService: ObservableObject {
    static var shared = DittoService()
    var ditto = DittoInstance.shared.ditto
    let fetcher: DittoDataFetcher
    let collection: DittoCollection
    
    private var allDocsCancellable = AnyCancellable({})
    private var allDocsSubject = CurrentValueSubject<[DittoDocument], Never>([])

    func allTestDocsPublisher() -> AnyPublisher<[DittoDocument], Never> {
        allDocsSubject.eraseToAnyPublisher()
    }
    
    init() {
        self.fetcher = DittoDataFetcher(ditto: ditto)
        self.collection = ditto.store[Env.DITTO_COLLECTION]
        syncAllDocs()
        
        /* FOR TESTING: force a new sync after 30 seconds
         
        forceSyncAfter(.now() + 30)
         
         */
    }
    
    func syncAllDocs() {
        self.allDocsCancellable = collection
            .findAll()
            .liveQueryPublisher()
            .map { docs, _ in
                print("DS.allDoc.map: docs.count: \(docs.count)")
                return docs.map { $0 }
            }
            .sink{[weak self] docs in
                guard let self = self, !docs.isEmpty else { return }
                
//                print("DS.allDoc.sink: START BACKGROUND ATTACHMENT DATA FETCH: \(Date().description)")
                fetcher.fetchAttachmentData(
                    in: docs,
                    collName: collection.name
                )
                
                print("DS.allDoc.sink: allDocsSubject.SEND docs.count: \(docs.count)")
                allDocsSubject.send(docs)
            }
    }
    
    //TEST
    func forceSyncAfter(_ someTime: DispatchTime) {
        DispatchQueue.main.asyncAfter(deadline: someTime) {[weak self] in
            print("""
            
            ==============================================================
                    DS.init() TEST - timer fired. CALL syncAllDocs()
            ==============================================================
            
            """)
            self?.syncAllDocs()
        }
    }
}

class DittoInstance: ObservableObject {
    static var shared = DittoInstance()
    let ditto: Ditto

    init() {
        ditto = Ditto(identity: .onlinePlayground(
            appID: Env.DITTO_APP_ID, token: Env.DITTO_PLAYGROUND_TOKEN
        ))
        
        // Prevent Xcode previews from syncing: non preview simulators and real devices can sync
        let isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if !isPreview {
            // make sure our log level is set _before_ starting ditto.
//            DittoLogger.minimumLogLevel = .debug
            DittoLogger.enabled = false //disabled to watch UI/fetch task log statements
            
            try! ditto.startSync()
        }
    }
}
