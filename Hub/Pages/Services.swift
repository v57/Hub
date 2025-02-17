//
//  Services.swift
//  Hub
//
//  Created by Dmitry Kozlov on 16/2/25.
//

import SwiftUI

struct Services: View {
  var body: some View {
    List {
      if let status = hub.status {
        ForEach(status.services, id: \.name) { service in
          Service(service: service)
        }
      }
    }.navigationTitle("\(hub.status?.requests ?? 0) requests")
  }
}
struct Service: View {
  let service: Status.Service
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 6) {
        Text(service.name)
        OnlineStatus.online.view
      }
      Text("\(service.requests) requests").font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  Services()
}
