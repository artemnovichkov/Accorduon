import SwiftUI

/// The strip above the accordion: song picker, melody progress, and air gauge.
struct SongBar: View {
    @Binding var song: Song?
    @Binding var step: Int
    @Binding var isAirLocked: Bool
    let hint: String
    let pressure: Double

    var body: some View {
        HStack(spacing: 16) {
            Picker("Song", selection: $song) {
                Text("Free Play").tag(Song?.none)
                ForEach(Song.all) { song in
                    Text(song.title).tag(Optional(song))
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            if let song {
                if step < song.notes.count {
                    MelodyStrip(notes: song.notes, step: step)
                } else {
                    Text("Bravo! 🎉")
                        .font(.headline)
                    Button("Again", systemImage: "arrow.counterclockwise") {
                        step = 0
                    }
                    Spacer()
                }
            } else {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Toggle("Auto Air", systemImage: "wind", isOn: $isAirLocked)
                .toggleStyle(.button)
                .help("Keep the bellows full, so keys play without pumping")

            AirGauge(pressure: pressure)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct MelodyStrip: View {
    let notes: [Note]
    let step: Int

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(notes.indices, id: \.self) { index in
                        Text(notes[index].name)
                            .font(.callout.monospaced().bold())
                            .frame(minWidth: 28)
                            .padding(.vertical, 4)
                            .background(index == step ? Color.accentColor : Color.white.opacity(0.1), in: .capsule)
                            .foregroundStyle(index == step ? .black : index < step ? .secondary : .primary)
                            .id(index)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: step) {
                withAnimation {
                    reader.scrollTo(step, anchor: .center)
                }
            }
        }
    }
}

private struct AirGauge: View {
    let pressure: Double

    var body: some View {
        HStack(spacing: 6) {
            Gauge(value: pressure) {
                Text("Air")
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(.accentColor)
            .frame(width: 80)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
