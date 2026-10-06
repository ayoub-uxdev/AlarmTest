import SwiftUI

struct ContentView: View {

    @State private var service = AlarmService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section("Autorisation AlarmKit") {
                    LabeledContent("État", value: service.authorizationText)

                    Button("Autoriser") {
                        Task { await service.requestAuthorization() }
                    }
                    .disabled(service.isAuthorized)
                }

                Section("Alarme") {
                    Text(service.alarmText)

                    Button("Programmer dans 1 minute") {
                        Task { await service.scheduleInOneMinute() }
                    }

                    Button("Annuler", role: .destructive) {
                        service.cancelAlarm()
                    }
                    .disabled(!service.hasAlarm)
                }

                Section("Dernier message") {
                    Text(service.message)
                }
            }
            .navigationTitle("AlarmTest")
        }
        .task {
            await service.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                service.refresh()
            }
        }
    }
}