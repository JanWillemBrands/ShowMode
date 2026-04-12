//
//  MainViewController.swift
//  ShowMode
//
//  Created by Johannes Brands on 2026.04.12.
//

import UIKit

class MainViewController: UIViewController {

    // MARK: - Background

    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        return iv
    }()

    private let dimOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        return v
    }()

    // MARK: - Clock & Date

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 96, weight: .thin)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .light)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        return label
    }()

    // MARK: - Weather

    private let weatherIconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 40)
        label.textAlignment = .center
        return label
    }()

    private let weatherTempLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 36, weight: .light)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let weatherDescLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .light)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.textAlignment = .center
        return label
    }()

    private let weatherLocationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .light)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.text = "Padua, Italy"
        return label
    }()

    // MARK: - News

    private let newsTableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.allowsSelection = false
        return tv
    }()

    private let newsTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.text = "BBC WORLD NEWS"
        label.textAlignment = .left
        return label
    }()

    // MARK: - State

    private var newsItems: [RSSItem] = []
    private var clockTimer: Timer?
    private var weatherTimer: Timer?
    private var newsTimer: Timer?
    private var photoTimer: Timer?
    private var currentPhotoIndex = 0

    private let rssParser = RSSParser()

    private let backgroundPhotoURLs: [String] = [
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=1200&q=80",
        "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1200&q=80",
        "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=1200&q=80",
        "https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=1200&q=80",
        "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1200&q=80",
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1200&q=80",
        "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=1200&q=80",
        "https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1200&q=80"
    ]

    // MARK: - Formatters

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = TimeZone(identifier: "Europe/Rome")
        return df
    }()

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMMM yyyy"
        df.timeZone = TimeZone(identifier: "Europe/Rome")
        return df
    }()

    // MARK: - Lifecycle

    override var prefersStatusBarHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        setupNewsTable()
        updateClock()
        startTimers()
        loadBackgroundPhoto()
        fetchWeather()
        fetchNews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundImageView.frame = view.bounds
        dimOverlay.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        // Background
        view.addSubview(backgroundImageView)
        view.addSubview(dimOverlay)

        // Clock & Date stack
        let clockStack = UIStackView(arrangedSubviews: [timeLabel, dateLabel])
        clockStack.axis = .vertical
        clockStack.spacing = 4
        clockStack.alignment = .center
        clockStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clockStack)

        // Weather stack
        let weatherStack = UIStackView(arrangedSubviews: [
            weatherIconLabel, weatherTempLabel, weatherDescLabel, weatherLocationLabel
        ])
        weatherStack.axis = .vertical
        weatherStack.spacing = 2
        weatherStack.alignment = .center
        weatherStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(weatherStack)

        // News section
        newsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        newsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newsTitleLabel)
        view.addSubview(newsTableView)

        NSLayoutConstraint.activate([
            // Clock centered in upper third
            clockStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clockStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            // Weather below clock
            weatherStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            weatherStack.topAnchor.constraint(equalTo: clockStack.bottomAnchor, constant: 30),

            // News title
            newsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            newsTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            newsTitleLabel.topAnchor.constraint(equalTo: weatherStack.bottomAnchor, constant: 40),

            // News table fills bottom
            newsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newsTableView.topAnchor.constraint(equalTo: newsTitleLabel.bottomAnchor, constant: 8),
            newsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNewsTable() {
        newsTableView.dataSource = self
        newsTableView.register(NewsCell.self, forCellReuseIdentifier: NewsCell.reuseID)
    }

    // MARK: - Timers

    private func startTimers() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        newsTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchNews()
        }
        photoTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.loadBackgroundPhoto()
        }
    }

    // MARK: - Clock

    private func updateClock() {
        let now = Date()
        timeLabel.text = timeFormatter.string(from: now)
        dateLabel.text = dateFormatter.string(from: now)
    }

    // MARK: - Background Photos

    private func loadBackgroundPhoto() {
        let urlString = backgroundPhotoURLs[currentPhotoIndex % backgroundPhotoURLs.count]
        currentPhotoIndex += 1

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                UIView.transition(
                    with: self?.backgroundImageView ?? UIImageView(),
                    duration: 2.0,
                    options: .transitionCrossDissolve,
                    animations: { self?.backgroundImageView.image = image }
                )
            }
        }.resume()
    }

    // MARK: - Weather (Open-Meteo, no API key needed)

    private func fetchWeather() {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=45.4064&longitude=11.8768&current_weather=true"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current_weather"] as? [String: Any],
                      let temp = current["temperature"] as? Double,
                      let code = current["weathercode"] as? Int else { return }

                let (icon, description) = self?.weatherDescription(for: code) ?? ("", "")

                DispatchQueue.main.async {
                    self?.weatherTempLabel.text = "\(Int(round(temp)))°C"
                    self?.weatherIconLabel.text = icon
                    self?.weatherDescLabel.text = description
                }
            } catch {
                // Silently fail; will retry on next timer
            }
        }.resume()
    }

    private func weatherDescription(for code: Int) -> (String, String) {
        switch code {
        case 0: return ("☀️", "Clear sky")
        case 1: return ("🌤", "Mainly clear")
        case 2: return ("⛅️", "Partly cloudy")
        case 3: return ("☁️", "Overcast")
        case 45, 48: return ("🌫", "Fog")
        case 51, 53, 55: return ("🌦", "Drizzle")
        case 61, 63, 65: return ("🌧", "Rain")
        case 66, 67: return ("🌧", "Freezing rain")
        case 71, 73, 75: return ("❄️", "Snow")
        case 77: return ("🌨", "Snow grains")
        case 80, 81, 82: return ("🌧", "Rain showers")
        case 85, 86: return ("🌨", "Snow showers")
        case 95: return ("⛈", "Thunderstorm")
        case 96, 99: return ("⛈", "Thunderstorm with hail")
        default: return ("🌡", "Unknown")
        }
    }

    // MARK: - News

    private func fetchNews() {
        let urlString = "https://feeds.bbci.co.uk/news/world/rss.xml"
        guard let url = URL(string: urlString) else { return }

        rssParser.parse(url: url) { [weak self] items in
            DispatchQueue.main.async {
                self?.newsItems = items
                self?.newsTableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension MainViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newsItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NewsCell.reuseID, for: indexPath) as! NewsCell
        cell.configure(with: newsItems[indexPath.row])
        return cell
    }
}

// MARK: - News Cell

class NewsCell: UITableViewCell {

    static let reuseID = "NewsCell"

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return iv
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 3
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .light)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.numberOfLines = 2
        return label
    }()

    private var imageTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        thumbnailImageView.image = nil
        headlineLabel.text = nil
        summaryLabel.text = nil
    }

    private func setupLayout() {
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailImageView)

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, summaryLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            thumbnailImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            textStack.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with item: RSSItem) {
        headlineLabel.text = item.title
        summaryLabel.text = item.description

        guard let urlString = item.thumbnailURL, let url = URL(string: urlString) else { return }
        imageTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = image
            }
        }
        imageTask?.resume()
    }
}
