///
//  ContentView.swift
//  DocsCount
//
//  Created by Eric Turner on 6/6/23.
//
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Combine
import DittoSwift
import SwiftUI

class ContentVM: ObservableObject {
    @ObservedObject private var dittoService = DittoService.shared
    @Published var presentSettingsView = false
    @Published var bigPeerCount: Int = 0
    @Published var docs = [DittoDocument]()
    @Published var isLoading = true
    private var docsCancellable = AnyCancellable({})
    private var cancellables = Set<AnyCancellable>()

    init() {
        getDocsCount(for: dittoService.sutCollection.name)
        
        $bigPeerCount
            .receive(on: DispatchQueue.main)
            .sink {[weak self] count in
                guard count > 0 else { return }
                self?.setupDocsPublisher()
            }
            .store(in: &cancellables)
    }
    
    func setupDocsPublisher() {
        self.docsCancellable = dittoService.allTestDocsPublisher()
            .sink {[weak self] docs in
                /* N.B.
                 This sink will fire initially with zero because the DittoService Combine
                 CurrentValueSubject `allDocsSubject` is initialized with an empty array.
                 
                 If there are zero documents in the queried Big Peer collection, the following guard
                 condition will cause the placeholder "Syncing..." overlay view to hang. Otherwise,
                 the "Syncing..." view will be dismissed once the HTTP `count` API results are
                 received and all the documents are synced from the Big Peer (or from the local
                 store if they've already synced).
                 */
                guard let count = self?.bigPeerCount, count > 0, docs.count >= count else { return }

                self?.docs = docs
                self?.isLoading = false
            }
    }
    
    func getDocsCount(for collectionName: String) {
        Task {
            do {
                let count = try await DocsCounter().fetchCount(from: collectionName)
                self.bigPeerCount = count
            } catch {
                self.isLoading = false
                print(error.localizedDescription)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = ContentVM()
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(vm.docs, id: \.id) { doc in
                        Text(doc.id.string ?? "dummy")
                    }
                }
            }
            // Syncing... overlay view
            .fullScreenCover(isPresented: $vm.isLoading) {
                ZStack {
                    VStack {
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black, ignoresSafeAreaEdges: .all).opacity(0.5)

                    VStack {
                        Text("Syncing...").font(.largeTitle)
                            .padding(.bottom, 48)
                        ProgressView()
                            .tint(.white)
                            .controlSize(.large)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading ) {
                    Button {
                        vm.presentSettingsView = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Docs Count: \(vm.bigPeerCount)")
                }
            }
            .sheet(isPresented: $vm.presentSettingsView) {
                DittoToolsListView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
