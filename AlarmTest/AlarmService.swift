import AlarmKit
import Foundation
import Observation
import SwiftUI

/// Type de métadonnées exigé par AlarmKit (vide pour ce test).
struct AlarmTestMetadata: AlarmMetadata {}

/// Toute la logique AlarmKit.
/// (Nommé `AlarmService` car `AlarmManager` est déjà un type d'AlarmKit.)
@MainActor
@Observable
final class AlarmService {

    // MARK: État affiché

    private(set) var authorizationText = "Inconnue"
    private(set) var isAuthorized = false
    private(set) var alarmText = "Aucune alarme programmée"
    private(set) var hasAlarm = false
    private(set) var message = "Prêt."

    private let manager = AlarmManager.shared

    // MARK: Cycle de vie

    /// Lit l'état initial puis écoute les changements d'alarmes.
    func start() async {
        refresh()
        for await alarms in manager.alarmUpdates {
            apply(alarms)
        }
    }

    /// Relit l'autorisation et les alarmes auprès d'AlarmKit.
    func refresh() {
        setAuthorization(manager.authorizationState)
        guard isAuthorized else {
            apply([])
            return
        }
        do {
            apply(try manager.alarms)
        } catch {
            message = "Lecture des alarmes impossible : \(error.localizedDescription)"
        }
    }

    // MARK: Actions

    func requestAuthorization() async {
        do {
            let state = try await manager.requestAuthorization()
            setAuthorization(state)
            message = isAuthorized
                ? "Autorisation accordée."
                : "Autorisation refusée. Activez-la dans Réglages > AlarmTest."
            refresh()
        } catch {
            message = "Échec de la demande d'autorisation : \(error.localizedDescription)"
        }
    }

    func scheduleInOneMinute() async {
        do {
            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else {
                message = "Impossible de programmer : autorisation manquante."
                return
            }

            // Une seule alarme à la fois pour ce test.
            try cancelAll()

            let fireDate = Date().addingTimeInterval(60)

            let alert = AlarmPresentation.Alert(title: "Test AlarmKit")

            let attributes = AlarmAttributes<AlarmTestMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: AlarmTestMetadata(),
                tintColor: .orange
            )

            let configuration = AlarmManager.AlarmConfiguration<AlarmTestMetadata>.alarm(
                schedule: .fixed(fireDate),
                attributes: attributes
            )

            _ = try await manager.schedule(id: UUID(), configuration: configuration)

            refresh()
            message = "Alarme programmée dans 1 minute. Vous pouvez fermer l'app."
        } catch {
            message = "Programmation impossible : \(error.localizedDescription)"
        }
    }

    func cancelAlarm() {
        do {
            try cancelAll()
            refresh()
            message = "Alarme annulée."
        } catch {
            message = "Annulation impossible : \(error.localizedDescription)"
        }
    }

    // MARK: Helpers privés

    private func cancelAll() throws {
        for alarm in try manager.alarms {
            try manager.cancel(id: alarm.id)
        }
    }

    private func apply(_ alarms: [Alarm]) {
        guard let alarm = alarms.first else {
            hasAlarm = false
            alarmText = "Aucune alarme programmée"
            return
        }

        hasAlarm = true

        if alarm.state == .alerting {
            alarmText = "L'alarme sonne"
        } else if case .fixed(let date)? = alarm.schedule {
            alarmText = "Alarme programmée à \(date.formatted(date: .omitted, time: .standard))"
        } else {
            alarmText = "Alarme programmée"
        }
    }

    private func setAuthorization(_ state: AlarmManager.AuthorizationState) {
        switch state {
        case .authorized:
            authorizationText = "Autorisée"
            isAuthorized = true
        case .denied:
            authorizationText = "Refusée"
            isAuthorized = false
        case .notDetermined:
            authorizationText = "Non demandée"
            isAuthorized = false
        @unknown default:
            authorizationText = "Inconnue"
            isAuthorized = false
        }
    }
}