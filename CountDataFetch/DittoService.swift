///
//  DittoService.swift
//  CountDataFetch
//
//  Created by Eric Turner on 7/24/23.
//
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Combine
import DittoExportLogs
import DittoSwift
import SwiftUI

class DittoService: ObservableObject {
//    private static let defaultLoggingOption: DittoLogger.LoggingOptions = .error
//    @Published var loggingOption: DittoLogger.LoggingOptions
//    private var cancellables = Set<AnyCancellable>()
    
    static var shared = DittoService()
    var ditto = DittoInstance.shared.ditto
    let fetcher: DittoDataFetcher
    let testCollection: DittoCollection
    
    private var allDocsCancellable = AnyCancellable({})
    private var allDocsSubject = CurrentValueSubject<[DittoDocument], Never>([])
    func allDocsPublisher() -> AnyPublisher<[DittoDocument], Never> {
        allDocsSubject.eraseToAnyPublisher()
    }
    
    private init() {
        self.fetcher = DittoDataFetcher(ditto: ditto)
        self.testCollection = ditto.store[Env.DITTO_COLLECTION]
        
//        // make sure our log level is set _before_ starting ditto.
//        self.loggingOption = Self.storedLoggingOption()
//        
//        $loggingOption
//            .sink {[weak self] option in
//                self?.saveLoggingOption(option)
//                self?.resetLogging()
//            }
//            .store(in: &cancellables)

        syncAllDocs()
    }
    
    func syncAllDocs() {
        allDocsCancellable = testCollection
            .findAll()
            .liveQueryPublisher()
            .map { docs, _ in
                print("DS.syncAllDoc.map: docs.count: \(docs.count)")
                return docs.map { $0 }
            }
            .sink{[weak self] docs in
                guard let self = self, !docs.isEmpty else { return }
                
                fetcher.fetchAttachmentData(
                    in: docs,
                    collName: testCollection.name
                )
                
                print("DS.allDoc.sink: allDocsSubject.SEND docs.count: \(docs.count)")
                allDocsSubject.send(docs)
            }
    }
}

class DittoInstance: ObservableObject {
    static var shared = DittoInstance()
    let ditto: Ditto
    
    private static let defaultLoggingOption: DittoLogger.LoggingOptions = .error
    @Published var loggingOption: DittoLogger.LoggingOptions
    private var cancellables = Set<AnyCancellable>()


    init() {
        // make sure our log level is set _before_ starting ditto.
        self.loggingOption = Self.storedLoggingOption()

        ditto = Ditto(identity: .onlinePlayground(
            appID: Env.DITTO_APP_ID, token: Env.DITTO_PLAYGROUND_TOKEN
        ))
        
        $loggingOption
            .sink {[weak self] option in
                guard let self = self else { return }
                saveLoggingOption(option)
                resetLogging()
            }
            .store(in: &cancellables)
        
        // Prevent Xcode previews from syncing: non preview simulators and real devices can sync
        let isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if !isPreview {
            try! ditto.startSync()
        }
    }
}

extension DittoInstance {
    enum UserDefaultsKeys: String {
        case loggingOption = "live.ditto.CountDataFetch.userDefaults.loggingOption"
    }
    
    fileprivate func storedLoggingOption() -> DittoLogger.LoggingOptions {
        return Self.storedLoggingOption()
    }
    
    // static function for use in init() at launch
    fileprivate static func storedLoggingOption() -> DittoLogger.LoggingOptions {
        if let logOption = UserDefaults.standard.object(
            forKey: UserDefaultsKeys.loggingOption.rawValue
        ) as? Int {
            return DittoLogger.LoggingOptions(rawValue: logOption)!
        } else {
            return DittoLogger.LoggingOptions(rawValue: defaultLoggingOption.rawValue)!
        }
    }
    
    fileprivate func saveLoggingOption(_ option: DittoLogger.LoggingOptions) {
        UserDefaults.standard.set(option.rawValue, forKey: UserDefaultsKeys.loggingOption.rawValue)
    }

    fileprivate func resetLogging() {
        let logOption = Self.storedLoggingOption()
        switch logOption {
        case .disabled:
            DittoLogger.enabled = false
        default:
            DittoLogger.enabled = true
            DittoLogger.minimumLogLevel = DittoLogLevel(rawValue: logOption.rawValue)!
            if let logFileURL = DittoLogManager.shared.logFileURL {
                DittoLogger.setLogFileURL(logFileURL)
            }
        }
    }
}
