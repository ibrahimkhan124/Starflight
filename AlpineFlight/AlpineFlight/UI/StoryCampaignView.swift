import SwiftUI
import AVFoundation

struct StoryCampaignView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReplay = false
    @State private var selected: StoryChapter?
    @State private var narrator = AVSpeechSynthesizer()
    private var progress: StoryCampaignProgress { engine.storyProgress }
    private var chapter: StoryChapter { selected ?? progress.current ?? .dawn }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                VStack(alignment:.leading,spacing:8) {
                    Text("THE LAST BEACON").font(FlightStyle.displayFont(28)).foregroundStyle(FlightPalette.gold)
                    Text("An original Starflight campaign").font(.subheadline).foregroundStyle(FlightPalette.secondary)
                    ProgressView(value:Double(progress.completed.count),total:7).tint(FlightPalette.cyan)
                    Text("\(progress.completed.count) / 7 chapters complete").font(.caption).monospacedDigit()
                        .accessibilityIdentifier("Story campaign progress")
                    if progress.accepted || !progress.completed.isEmpty {
                        Button { confirmReplay = true } label: { Label("Replay story from beginning",systemImage:"arrow.counterclockwise") }
                            .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.cyan,expands:false))
                            .disabled(engine.storyLaunching || engine.interiorHome != nil)
                            .accessibilityIdentifier("Replay story")
                        Text("Start again and make different choices. Ships, credits and other progress are kept. Chapter bonuses are paid once.")
                            .font(.caption).foregroundStyle(FlightPalette.secondary)
                    }
                }
                if let ending = progress.ending {
                    VStack(alignment:.leading,spacing:10) {
                        Label(ending.title,systemImage:"sparkles").font(.title2.bold()).foregroundStyle(FlightPalette.gold)
                        Text(progress.epilogue).font(.body)
                        Text("Your title and completed chapters are saved. The galaxy remains open for free flight.").font(.caption).foregroundStyle(FlightPalette.teal)
                    }.padding().background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:16))
                } else if progress.finished {
                    Text(StoryChapter.dawn.debrief).font(.body)
                    Text("What will you do with the beacon codes?").font(.headline)
                    ForEach(StoryEnding.allCases) { ending in
                        Button(ending.choice) { engine.chooseStoryEnding(ending) }
                            .buttonStyle(MenuActionButtonStyle(accent:FlightPalette.cyan))
                            .accessibilityIdentifier("Story ending " + ending.rawValue)
                    }
                    Text("This choice determines your saved epilogue and pilot title.").font(.caption).foregroundStyle(FlightPalette.secondary)
                }
                if let last = progress.lastCompleted, selected == nil, !progress.finished {
                    VStack(alignment:.leading,spacing:10) {
                        Label("Chapter \(last.number) secured" + (engine.economy.storyRewardAvailable(for:last) ? " · +\(last.reward) credits":" · replay complete"),systemImage:"checkmark.seal.fill")
                            .foregroundStyle(FlightPalette.teal).font(.headline)
                        Text(progress.debrief(for:last)).font(.body)
                    }.padding().background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:16))
                }
                VStack(alignment:.leading,spacing:14) {
                    Text("CHAPTER \(chapter.number) · \(chapter.location.uppercased())").font(.caption.bold()).foregroundStyle(FlightPalette.cyan)
                    Text(chapter.title).font(.title2.bold()).accessibilityIdentifier("Story chapter title")
                    if chapter == progress.current {
                        if chapter == .signal && (!progress.accepted || (progress.approach == nil && !progress.passengerSafe)) {
                            Text("Your flight plan").font(.headline)
                            ForEach(StoryApproach.allCases) { choice in
                                Button { engine.chooseStoryApproach(choice) } label: {
                                    VStack(alignment:.leading,spacing:5) {
                                        Label(choice.title,systemImage:progress.plan == choice ? "checkmark.circle.fill":"circle")
                                        Text(choice.detail).font(.caption)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                }.buttonStyle(MenuActionButtonStyle(accent:progress.plan == choice ? FlightPalette.gold:FlightPalette.cyan))
                                    .accessibilityIdentifier("Story approach " + choice.rawValue)
                                    .accessibilityValue(progress.plan == choice ? "Selected":"Not selected")
                            }
                        }
                        if chapter == .canopy && (!progress.accepted || (progress.relayChoice == nil && progress.scouts.isEmpty)) {
                            Text("Decide how to transmit").font(.headline)
                            ForEach(StoryRelayChoice.allCases) { choice in
                                Button { engine.chooseStoryRelay(choice) } label: {
                                    VStack(alignment:.leading,spacing:5) {
                                        Label(choice.title,systemImage:progress.relay == choice ? "checkmark.circle.fill":"circle")
                                        Text(choice.detail).font(.caption)
                                    }.frame(maxWidth:.infinity,alignment:.leading)
                                }.buttonStyle(MenuActionButtonStyle(accent:progress.relay == choice ? FlightPalette.gold:FlightPalette.cyan))
                                    .accessibilityIdentifier("Story relay " + choice.rawValue)
                                    .accessibilityValue(progress.relay == choice ? "Selected":"Not selected")
                            }
                        }
                        if progress.accepted {
                            Text("Flight plan · " + progress.plan.title + (chapter.rawValue >= StoryChapter.canopy.rawValue ? " · " + progress.relay.title : ""))
                                .font(.caption).foregroundStyle(FlightPalette.gold)
                        }
                        Label("Incoming transmission",systemImage:"waveform").font(.caption.bold()).foregroundStyle(FlightPalette.teal)
                        Text(progress.transmission).font(.subheadline).italic().accessibilityIdentifier("Story transmission")
                    }
                    Text(progress.briefing(for:chapter)).font(.body).fixedSize(horizontal:false,vertical:true)
                    ForEach(progress.dialogue(for:chapter).indices,id:\.self) { index in
                        let line = progress.dialogue(for:chapter)[index]
                        VStack(alignment:.leading,spacing:5) {
                            Text(line.speaker == "Droid" ? engine.settings.droid.name:line.speaker).font(.caption.bold()).foregroundStyle(FlightPalette.teal)
                            Text("“" + line.text + "”").font(.subheadline).italic()
                        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
                    }
                    if progress.completed.contains(chapter.id) {
                        Text(progress.debrief(for:chapter)).foregroundStyle(FlightPalette.secondary)
                    } else {
                        Label(progress.objective(for:chapter),systemImage:"location.north.circle").font(.headline).foregroundStyle(FlightPalette.gold)
                        if progress.accepted { Text(progress.objectiveProgress).foregroundStyle(FlightPalette.cyan).accessibilityIdentifier("Story objective progress") }
                        Text(chapter.hint).font(.subheadline).foregroundStyle(FlightPalette.secondary)
                        Text(engine.economy.storyRewardAvailable(for:chapter) ? "Chapter reward: \(chapter.reward) credits · paid once":"Replay · chapter bonus already collected").font(.caption).foregroundStyle(FlightPalette.teal)
                        if chapter == .whiteout || chapter == .canopy { Text("Campaign weather conditions apply during this story flight. Your normal weather setting is preserved.").font(.caption) }
                    }
                    Button("Read briefing aloud") {
                        narrator.stopSpeaking(at:.immediate)
                        let speech = AVSpeechUtterance(string:"Chapter \(chapter.number). " + chapter.title + ". " + progress.briefing(for:chapter) + " Your objective. " + progress.objective(for:chapter))
                        speech.rate = AVSpeechUtteranceDefaultSpeechRate*0.9
                        speech.volume = engine.settings.soundVolume
                        speech.voice = AVSpeechSynthesisVoice(language:"en-GB")
                        narrator.speak(speech)
                    }.buttonStyle(MenuActionButtonStyle(expands:false)).disabled(!engine.settings.soundEnabled)
                    Text("Briefing narration uses the device's system voice.").font(.caption2).foregroundStyle(FlightPalette.secondary)
                }
                if !progress.evidence.isEmpty {
                    DisclosureGroup("Evidence journal · \(progress.evidence.count) recovered") {
                        ForEach(progress.evidence.indices,id:\.self) { i in
                            VStack(alignment:.leading,spacing:6) {
                                Text(progress.evidence[i].0).font(.headline).foregroundStyle(FlightPalette.cyan)
                                Text(progress.evidence[i].1).font(.subheadline)
                            }.padding(.vertical,8)
                        }
                    }.accessibilityIdentifier("Story evidence journal")
                }
                Divider()
                Text("Chapter transmissions").font(.headline)
                ForEach(StoryChapter.allCases) { item in
                    let unlocked = item.rawValue <= progress.completed.count
                    Button { selected = item } label: {
                        HStack(spacing:12) {
                            Image(systemName:progress.completed.contains(item.id) ? "checkmark.circle.fill":unlocked ? "waveform":"lock.fill")
                            Text("\(item.number) · " + (unlocked ? item.title:"Encrypted transmission"))
                            Spacer()
                        }
                    }.buttonStyle(MenuActionButtonStyle(accent:unlocked ? FlightPalette.cyan:FlightPalette.secondary))
                        .disabled(!unlocked).accessibilityIdentifier("Story chapter \(item.number)")
                }
            }.padding(20).frame(maxWidth:760).frame(maxWidth:.infinity)
        }.accessibilityIdentifier("Story briefing scroll").background(FlightStyle.ink).foregroundStyle(.white)
            .safeAreaInset(edge:.bottom) {
                if chapter == progress.current {
                    VStack(spacing:6) {
                        Button(progress.accepted ? "Restart chapter flight":"Launch chapter \(chapter.number)") {
                            narrator.stopSpeaking(at:.immediate); engine.launchStoryChapter(); dismiss()
                        }.buttonStyle(MenuActionButtonStyle(accent:FlightPalette.gold,prominent:true))
                            .disabled(engine.storyLaunching || engine.interiorHome != nil).accessibilityIdentifier("Launch story chapter")
                        Text("Starts a new flight. Campaign progress survives crashes; podracers use the starter ship.")
                            .font(.caption2).foregroundStyle(FlightPalette.secondary).multilineTextAlignment(.center)
                    }.padding(12).frame(maxWidth:760).frame(maxWidth:.infinity).background(FlightStyle.ink.opacity(0.97))
                }
            }
            .navigationTitle("Story campaign")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().accessibilityIdentifier("Close story campaign") } }
            .alert("Replay The Last Beacon?",isPresented:$confirmReplay) {
                Button("Start story again") {
                    narrator.stopSpeaking(at:.immediate)
                    if engine.restartStoryCampaign() { selected = nil }
                }.accessibilityIdentifier("Confirm story replay")
                Button("Keep current story",role:.cancel) { }
            } message: {
                Text("This restarts all seven chapters and clears this run's choices, evidence and ending. Your ships, credits and other game progress stay. Previously collected chapter bonuses are not paid again.")
            }
            .onDisappear { narrator.stopSpeaking(at:.immediate) }
    }
}

struct StoryFlightBadge: View {
    @ObservedObject var engine:GameEngine
    var body: some View {
        if engine.storyFlightActive,let chapter = engine.storyProgress.current, engine.activeEmergency == nil {
            Text("CH \(chapter.number) · " + engine.storyProgress.objectiveProgress)
                .font(.system(size:11,weight:.semibold)).foregroundStyle(FlightPalette.gold)
                .multilineTextAlignment(.center).lineLimit(2).padding(10).frame(maxWidth:360)
                .background(.black.opacity(0.88),in:RoundedRectangle(cornerRadius:12))
                .accessibilityIdentifier("Story flight objective").allowsHitTesting(false)
        }
    }
}
