///
//  DittoToolsListView.swift
//  CountDataFetch
//
//  Created by Eric Turner on 1/31/23.
//®
//  Copyright © 2023 DittoLive Incorporated. All rights reserved.

import Combine
import DittoDataBrowser
import DittoDiskUsage
import DittoExportLogs
import DittoPresenceViewer
import DittoSwift
import SwiftUI


struct DittoToolsListView: View {
    @ObservedObject var dittoService = DittoService.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Ditto Tools")
                        .frame(width: 400, alignment: .center)
                        .font(.title)
                }
                Section {
                    NavigationLink {
                        PresenceView(ditto: DittoService.shared.ditto)
                    } label: {
                        Text("Presence Viewer")
                    }

                    NavigationLink {
                        DataBrowser(ditto: DittoService.shared.ditto)
                    } label: {
                        Text("Data Browser")
                    }
                    
                    NavigationLink {
                        DittoDiskUsageView(ditto: DittoService.shared.ditto)
                    } label: {
                        Text("Disk Usage")
                    }
                }
            }
        }
    }
}

struct DittoToolsListView_Previews: PreviewProvider {
    static var previews: some View {
        DittoToolsListView()
    }
}
