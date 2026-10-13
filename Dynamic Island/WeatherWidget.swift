
import SwiftUI
import Foundation
import Combine

struct WeatherWidget: View {
    @StateObject private var weather = WeatherManager()

    private let background = Color.white.opacity(0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 10, weight: .semibold))

                Text("Weather")
                    .font(.system(size: 9, weight: .semibold))

                Spacer(minLength: 0)

                Button {
                    Task { await weather.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .help("Refresh weather")
            }
            .foregroundStyle(.white.opacity(0.85))

            if let temperature = weather.temperature {
                HStack(spacing: 7) {
                    Image(systemName: weather.symbol)
                        .font(.system(size: 27))
                        .foregroundStyle(.yellow)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(temperature)°C")
                            .font(.system(size: 21, weight: .medium))
                            .monospacedDigit()

                        Text(weather.condition)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    Text("H: \(weather.high.map { "\($0)°" } ?? "—")")
                    Spacer()
                    Text("L: \(weather.low.map { "\($0)°" } ?? "—")")
                }
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

                HStack {
                    Label(
                        weather.feelsLike.map { "\($0)°" } ?? "—",
                        systemImage: "thermometer.medium"
                    )

                    Spacer(minLength: 0)

                    Label(
                        weather.wind.map { "\($0) km/h" } ?? "—",
                        systemImage: "wind"
                    )
                }
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.65))
            } else {
                Spacer(minLength: 0)

                Text(weather.errorMessage ?? "Loading weather…")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background(
            background,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .task {
            await weather.refresh()

            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: 900_000_000_000
                )
                guard !Task.isCancelled else { break }
                await weather.refresh()
            }
        }
    }
}

@MainActor
final class WeatherManager: ObservableObject {
    @Published private(set) var temperature: Int?
    @Published private(set) var feelsLike: Int?
    @Published private(set) var high: Int?
    @Published private(set) var low: Int?
    @Published private(set) var wind: Int?
    @Published private(set) var condition = "Loading…"
    @Published private(set) var symbol = "cloud.sun.fill"
    @Published private(set) var errorMessage: String?

    func refresh() async {
        let urlString = """
        https://api.open-meteo.com/v1/forecast?latitude=37.978&longitude=-0.683&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=Europe%2FMadrid
        """

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid weather URL"
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let result = try JSONDecoder().decode(
                WeatherResponse.self,
                from: data
            )

            temperature = Int(result.current.temperature.rounded())
            feelsLike = Int(result.current.feelsLike.rounded())
            wind = Int(result.current.windSpeed.rounded())
            high = result.daily.maximum.first.map { Int($0.rounded()) }
            low = result.daily.minimum.first.map { Int($0.rounded()) }

            condition = Self.condition(result.current.code)
            symbol = Self.symbol(result.current.code)
            errorMessage = nil
        } catch {
            errorMessage = "Weather unavailable — tap refresh"
            print("Weather error: \(error)")
        }
    }

    private static func condition(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "Current conditions"
        }
    }

    private static func symbol(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67: return "cloud.drizzle.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.rain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }
}

private struct WeatherResponse: Decodable {
    let current: Current
    let daily: Daily

    struct Current: Decodable {
        let temperature: Double
        let feelsLike: Double
        let code: Int
        let windSpeed: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case feelsLike = "apparent_temperature"
            case code = "weather_code"
            case windSpeed = "wind_speed_10m"
        }
    }

    struct Daily: Decodable {
        let maximum: [Double]
        let minimum: [Double]

        enum CodingKeys: String, CodingKey {
            case maximum = "temperature_2m_max"
            case minimum = "temperature_2m_min"
        }
    }
}
