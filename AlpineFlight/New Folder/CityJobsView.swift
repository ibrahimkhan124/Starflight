import SwiftUI

/// A destination inside Flight tools; the parent sheet owns pausing and resuming.
struct CityJobsView: View {
    @ObservedObject var engine: GameEngine
    var onOpenMap: () -> Void = {}
    var onOpenCareer: () -> Void = {}
    var onOpenContracts: (CityJobKind) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: horizontalSizeClass == .regular ? 2 : 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Work among the neon towers")
                    .font(.title2.bold())
                Text("Flight and job timers are paused while this board is open. Every ship can take a job.")
                    .font(.subheadline).foregroundStyle(.white)
                HStack {
                    Button("City map",action:onOpenMap).flightButtonGlass().accessibilityIdentifier("Open city map from jobs")
                    Spacer()
                    Button("Career log",action:onOpenCareer).flightButtonGlass().accessibilityIdentifier("Open city career")
                }.buttonStyle(.bordered)
                CityCareerSummary(engine:engine)

                if let notice = engine.cityJobNotice {
                    Text(notice).font(.subheadline).foregroundStyle(.white)
                        .accessibilityIdentifier("City job notice")
                }

                if let active = engine.cityJobs.active {
                    activeJob(active)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(CityJobKind.allCases) { kind in
                        jobCard(kind)
                    }
                }

                instructions
                Text("\(engine.economy.completedCityJobs) city jobs completed")
                    .font(.caption).monospacedDigit().foregroundStyle(.white)
                    .accessibilityIdentifier("City jobs completed")
            }
            .padding(20)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("City jobs scroll")
        .background(FlightStyle.ink)
        .foregroundStyle(.white)
        .tint(.white)
        .preferredColorScheme(.dark)
        .navigationTitle("Coruscant jobs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.flightButtonGlass()
                    .accessibilityIdentifier("City jobs done")
            }
        }
    }

    private func activeJob(_ kind: CityJobKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT JOB").font(.caption.weight(.bold)).tracking(1.2)
                .foregroundStyle(.white)
            Text(engine.cityJobs.contract?.title ?? kind.title).font(.title3.bold())
            Text(engine.cityJobs.status).font(.subheadline)
                .accessibilityIdentifier("City job status")
            if let target = engine.cityJobs.target {
                Text("Next skyport: \(target.name)")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("City job target")
            }
            HStack(spacing: 16) {
                Text("Stop \(engine.cityJobs.stage + 1) of \(engine.cityJobs.route.count)")
                if let remaining = engine.cityJobs.timeRemaining {
                    Text("Time left \(duration(remaining))")
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("City job time remaining")
                } else {
                    Text("No time limit")
                }
            }.font(.caption).monospacedDigit()
            ProgressView(value:Double(engine.cityJobs.progress))
                .tint(.white).accessibilityLabel("Job route progress")
            Text(engine.hud.cityJobDetail).font(.caption).foregroundStyle(.white)
                .accessibilityIdentifier("City job approach")
            Text(engine.cityJobs.conditionFeedback).font(.caption).foregroundStyle(.white)
                .accessibilityIdentifier("City job condition")
            if engine.cityJobs.docking {
                Text("Docked · \(duration(engine.cityJobs.serviceRemaining)) service remaining. Resume flight to finish servicing.")
                    .font(.caption).foregroundStyle(.white)
            }
            Text("Finish this job or cancel it before accepting another.")
                .font(.caption).foregroundStyle(.white)
            Button("Cancel job", role: .destructive) { engine.cancelCityJob() }.flightButtonGlass()
                .buttonStyle(.bordered)
                .accessibilityIdentifier("Cancel city job")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(FlightStyle.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FlightStyle.mint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Active city job")
    }

    private func jobCard(_ kind: CityJobKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind.title).font(.headline)
                .frame(minHeight: 26, alignment: .topLeading)
            Text(kind.summary).font(.subheadline)
                .frame(minHeight: 52, alignment: .topLeading)
            HStack(spacing: 12) {
                Text("\(kind.rewardCredits) credits").foregroundStyle(.white)
                Spacer(minLength: 4)
                Text(kind.timeLimit.map { duration($0) + " limit" } ?? "Untimed")
                    .foregroundStyle(.white)
            }.font(.caption.weight(.semibold)).monospacedDigit()
            Text(rules(for: kind)).font(.caption).foregroundStyle(.white)
                .frame(minHeight: 44, alignment: .topLeading)
            Button("Accept \(kind.title)") {
                engine.acceptCityJob(kind)
                dismiss()
            }.flightButtonGlass()
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.white)
            .frame(minHeight: 44)
            .disabled(engine.cityJobs.active != nil || engine.bounty.contract != nil || engine.homeLanding.plot != nil)
            .accessibilityIdentifier("Accept city job \(kind.id)")
            Button("Compare 3 contracts") { onOpenContracts(kind) }.flightButtonGlass()
                .buttonStyle(.bordered).accessibilityIdentifier("Browse city contracts " + kind.id)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("City job \(kind.id)")
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How city jobs work").font(.headline)
            Text("Accept a job, then close Flight tools with Resume. Follow the navigation bearing to the marked neon skyport, matching its height as well as its position.")
            Text("Follow the climb or descend guidance to the skyport's 180 m altitude. Approach assist slows your ship inside 1.1 km; aim for less than 120 kt. ETA appears while you are moving towards it. Within 450 m, use Dock on the flight HUD. Service usually takes three seconds; specialist surveys take five or eight. Press Depart to continue.")
            Text("Compare contracts to choose a different route. Keep passengers comfortable, cargo intact and patients stable with gentle turns. A completed contract always pays its base reward; eligible specialist jobs add a quality bonus. The career log saves debriefs and unlocks new work.")
            Text("Finish every stop to receive the listed credits. Rewards are saved only when the whole job is complete; partial routes and cancelled jobs earn no credits. Timed jobs must finish before their deadline.")
            Text("Jobs last for this flight. Leaving Coruscant, cancelling or crashing ends an unfinished job; only completed work pays.")
        }
        .font(.caption).foregroundStyle(.white)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private func rules(for kind: CityJobKind) -> String {
        switch kind {
        case .shuttle: return "Three pickup and drop-off pairs. Dock at six stops in order; take your time."
        case .courier: return "Dock at Neon Market, Industrial Quarter and Senate District before the timer expires."
        case .rescue: return "Dock in the Industrial Quarter to collect the patient, then deliver them to the Medical Centre."
        case .patrol: return "Dock and scan at the Spaceport, Market, Senate and Industrial Quarter. No deadline."
        }
    }

    private func duration(_ seconds: Float) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
