//
//  MainViewController.swift
//  ShowMode
//

import UIKit
import WebKit

// MARK: - Weather Forecast Model

struct DayForecast {
    let dayName: String
    let icon: String
    let high: Int
    let low: Int
}

// MARK: - MainViewController

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
        v.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        return v
    }()

    // MARK: - Clock & Date

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 86, weight: .thin)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.5
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 22, weight: .light)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.5
        return label
    }()

    // MARK: - Weather

    private let weatherIconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 72)
        label.textAlignment = .center
        return label
    }()

    private let weatherTempLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 48, weight: .light)
        label.textColor = .white
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.5
        return label
    }()

    private let weatherDetailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .light)
        label.textColor = .white
        label.numberOfLines = 2
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.4
        return label
    }()

    private let weatherLocationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .light)
        label.textColor = .white
        label.textAlignment = .right
        label.text = "Padua, Italy"
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.4
        return label
    }()

    // MARK: - Weekly Forecast

    private let forecastStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalCentering
        return stack
    }()

    // MARK: - News

    private let newsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.allowsSelection = true
        cv.isPagingEnabled = true
        return cv
    }()

    private let newsTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        label.text = "VENETO EVENTS"
        label.textAlignment = .left
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 2
        label.layer.shadowOpacity = 0.4
        return label
    }()

    // MARK: - Web Overlay

    private var overlayBackground: UIView?
    private var overlayWebView: WKWebView?

    // MARK: - State

    private var newsItems: [RSSItem] = []
    private var feniceItems: [RSSItem] = []
    private var newsDisplayOffset = 0
    private var clockTimer: Timer?
    private var weatherTimer: Timer?
    private var newsTimer: Timer?
    private var photoTimer: Timer?
    private var displayCycleTimer: Timer?
    private var currentPhotoIndex = 0
    private let itemsPerPage = 6
    private let newsParser = RSSParser()
    private let feniceScraper = LaFeniceScraper()

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

    private let dayNameFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.timeZone = TimeZone(identifier: "Europe/Rome")
        return df
    }()

    // MARK: - Lifecycle

    override var prefersStatusBarHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        print(">>> MainViewController viewDidLoad")
        view.backgroundColor = .red  // DEBUG: should be visible if VC loads
        setupLayout()
        setupCollections()
        updateClock()
        startTimers()
        loadBackgroundPhoto()
        fetchWeather()
        fetchNews()
        print(">>> MainViewController viewDidLoad complete")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundImageView.frame = view.bounds
        dimOverlay.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backgroundImageView)
        view.addSubview(dimOverlay)

        // Left: clock + date
        let clockStack = UIStackView(arrangedSubviews: [timeLabel, dateLabel])
        clockStack.axis = .vertical
        clockStack.spacing = 2
        clockStack.alignment = .center

        // Right: weather — icon and temp+details side by side
        let tempDetailStack = UIStackView(arrangedSubviews: [weatherTempLabel, weatherDetailLabel])
        tempDetailStack.axis = .vertical
        tempDetailStack.spacing = 1
        tempDetailStack.alignment = .leading

        let weatherRow = UIStackView(arrangedSubviews: [weatherIconLabel, tempDetailStack])
        weatherRow.axis = .horizontal
        weatherRow.spacing = 6
        weatherRow.alignment = .center

        let weatherStack = UIStackView(arrangedSubviews: [weatherRow, weatherLocationLabel])
        weatherStack.axis = .vertical
        weatherStack.spacing = 2
        weatherStack.alignment = .trailing

        // Top row
        let topRow = UIStackView(arrangedSubviews: [clockStack, weatherStack])
        topRow.axis = .horizontal
        topRow.distribution = .equalCentering
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topRow)

        // Forecast
        forecastStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(forecastStack)

        // Events
        newsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        newsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newsTitleLabel)
        view.addSubview(newsCollectionView)

        let topAnchor: NSLayoutYAxisAnchor
        if #available(iOS 11.0, *) {
            topAnchor = view.safeAreaLayoutGuide.topAnchor
        } else {
            topAnchor = topLayoutGuide.bottomAnchor
        }

        // Three rows: 3 * 112 cell + 2 * 10 spacing = 356
        let collectionHeight: CGFloat = 356

        // Spacers: forecast→events (3x), events→bottom (1x)
        let spacer1 = UILayoutGuide()
        let spacer2 = UILayoutGuide()
        view.addLayoutGuide(spacer1)
        view.addLayoutGuide(spacer2)

        NSLayoutConstraint.activate([
            // Top row
            topRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            topRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            topRow.topAnchor.constraint(equalTo: topAnchor, constant: 30),

            // Forecast centred horizontally
            forecastStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forecastStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 30),

            // Spacer 1: between forecast and events
            spacer1.topAnchor.constraint(equalTo: forecastStack.bottomAnchor),
            spacer1.bottomAnchor.constraint(equalTo: newsTitleLabel.topAnchor),

            // Events header
            newsTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            newsTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Events collection — 3-row height
            newsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            newsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            newsCollectionView.topAnchor.constraint(equalTo: newsTitleLabel.bottomAnchor, constant: 6),
            newsCollectionView.heightAnchor.constraint(equalToConstant: collectionHeight),

            // Spacer 2: below events to bottom
            spacer2.topAnchor.constraint(equalTo: newsCollectionView.bottomAnchor),
            spacer2.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Spacer 1 (forecast→events) is 3x spacer 2 (events→bottom)
            spacer1.heightAnchor.constraint(equalTo: spacer2.heightAnchor, multiplier: 3)
        ])
    }

    private func setupCollections() {
        newsCollectionView.dataSource = self
        newsCollectionView.delegate = self
        newsCollectionView.register(NewsCardCell.self, forCellWithReuseIdentifier: NewsCardCell.reuseID)
    }

    // MARK: - Timers

    private func startTimers() {
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 60*10, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        newsTimer = Timer.scheduledTimer(withTimeInterval: 60*60, repeats: true) { [weak self] _ in
            self?.fetchNews()
        }
        photoTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.loadBackgroundPhoto()
        }
        displayCycleTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.cycleDisplayedItems()
        }
    }

    private func cycleDisplayedItems() {
        if newsItems.count > itemsPerPage {
            newsDisplayOffset = (newsDisplayOffset + itemsPerPage) % newsItems.count
            UIView.transition(with: newsCollectionView, duration: 1.0, options: .transitionCrossDissolve, animations: {
                self.newsCollectionView.reloadData()
            })
        }
    }

    // MARK: - Clock

    private func updateClock() {
        let now = Date()
        timeLabel.text = timeFormatter.string(from: now)
        dateLabel.text = dateFormatter.string(from: now)
    }

    // MARK: - Background Photos

    // Dolomites & Venice — darker/moody shots for text contrast
    private let naturePhotoIDs = [
        // Dolomites — dramatic peaks & valleys
        "photo-1519681393784-d120267933ba",  // Mountains under stars, dark sky
        "photo-1516706704781-c1ae29b5100e",  // Tre Cime di Lavaredo
        "photo-1529963183134-fed3c3f7e80c",  // Dolomites misty sunset
        "photo-1508193638397-1c4234db14d8",  // Seceda ridgeline moody
        "photo-1543785832-5b03de1dc20d",      // Dark alpine lake reflection
        "photo-1470770903676-69b98201ea1c",  // Mountain meadow dusk
        "photo-1464822759023-fed622ff2c3b",  // Peak at golden hour
        "photo-1491002052546-bf38f186af56",  // Dark mountain lake
        "photo-1540206395-68808572332f",      // Snowy Dolomites range
        "photo-1507400492013-162706c8c05e",  // Alpe di Siusi twilight
        "photo-1511497584788-876760111969",  // Misty mountain forest
        "photo-1509023464722-18d996393ca8",  // Dark storm clouds mountains
        // Venice — twilight & atmospheric
        "photo-1523906834658-6e24ef2386f9",  // Venice Grand Canal
        "photo-1534113414509-0eec2bfb493f",  // Venice at dusk, dark water
        "photo-1514890547357-a9ee288728e0",  // Venice gondola twilight
        "photo-1559717865-a99cac1c95d8",      // Venice canal moody blue
        "photo-1498307833015-e7b400441eb8",  // Venice sunset silhouette
        "photo-1549880338-65ddcdfd017b",      // Venice dark canal night
        "photo-1518098268026-4e89f1a2cd8e",  // Venice bridge at dusk
        "photo-1604580864964-0462f5d5b1a8",  // Venice dark architecture
    ]

    private func loadBackgroundPhoto() {
        let id = naturePhotoIDs[currentPhotoIndex % naturePhotoIDs.count]
        currentPhotoIndex += 1
        let urlString = "https://images.unsplash.com/\(id)?w=768&h=1024&fit=crop&q=90"

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

    // MARK: - Weather

    private func fetchWeather() {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=45.4064&longitude=11.8768&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=Europe%2FRome"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else { return }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current_weather"] as? [String: Any],
                      let temp = current["temperature"] as? Double,
                      let code = current["weathercode"] as? Int else { return }

                let (icon, description) = self.weatherDescription(for: code)

                var forecasts: [DayForecast] = []
                var highToday: Int?
                var lowToday: Int?

                if let daily = json["daily"] as? [String: Any],
                   let dates = daily["time"] as? [String],
                   let maxTemps = daily["temperature_2m_max"] as? [Double],
                   let minTemps = daily["temperature_2m_min"] as? [Double],
                   let codes = daily["weathercode"] as? [Int] {

                    let isoFormatter = DateFormatter()
                    isoFormatter.dateFormat = "yyyy-MM-dd"
                    isoFormatter.timeZone = TimeZone(identifier: "Europe/Rome")

                    if maxTemps.count > 0 {
                        highToday = Int(round(maxTemps[0]))
                        lowToday = Int(round(minTemps[0]))
                    }

                    for i in 1..<min(dates.count, 7) {
                        var dayName = "?"
                        if let date = isoFormatter.date(from: dates[i]) {
                            dayName = self.dayNameFormatter.string(from: date)
                        }
                        let (dayIcon, _) = self.weatherDescription(for: codes[i])
                        forecasts.append(DayForecast(
                            dayName: dayName,
                            icon: dayIcon,
                            high: Int(round(maxTemps[i])),
                            low: Int(round(minTemps[i]))
                        ))
                    }
                }

                DispatchQueue.main.async {
                    self.weatherTempLabel.text = "\(Int(round(temp)))\u{00B0}C"
                    self.weatherIconLabel.text = icon
                    var detail = description
                    if let h = highToday, let l = lowToday {
                        detail += "  H:\(h)\u{00B0} L:\(l)\u{00B0}"
                    }
                    self.weatherDetailLabel.text = detail
                    self.updateForecast(forecasts)
                }
            } catch {}
        }.resume()
    }

    private func updateForecast(_ forecasts: [DayForecast]) {
        forecastStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for day in forecasts {
            let dayLabel = UILabel()
            dayLabel.text = day.dayName
            dayLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            dayLabel.textColor = .white
            dayLabel.textAlignment = .center
            dayLabel.layer.shadowColor = UIColor.black.cgColor
            dayLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
            dayLabel.layer.shadowRadius = 2
            dayLabel.layer.shadowOpacity = 0.4

            let iconLabel = UILabel()
            iconLabel.text = day.icon
            iconLabel.font = UIFont.systemFont(ofSize: 48)
            iconLabel.textAlignment = .center

            let tempLabel = UILabel()
            tempLabel.text = "\(day.high)\u{00B0}/\(day.low)\u{00B0}"
            tempLabel.font = UIFont.systemFont(ofSize: 17, weight: .light)
            tempLabel.textColor = .white
            tempLabel.textAlignment = .center
            tempLabel.layer.shadowColor = UIColor.black.cgColor
            tempLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
            tempLabel.layer.shadowRadius = 2
            tempLabel.layer.shadowOpacity = 0.4

            let col = UIStackView(arrangedSubviews: [dayLabel, iconLabel, tempLabel])
            col.axis = .vertical
            col.spacing = 2
            col.alignment = .center
            col.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

            forecastStack.addArrangedSubview(col)
        }
    }

    private func weatherDescription(for code: Int) -> (String, String) {
        switch code {
        case 0: return ("\u{2600}\u{FE0F}", "Clear sky")
        case 1: return ("\u{1F324}\u{FE0F}", "Mainly clear")
        case 2: return ("\u{26C5}\u{FE0F}", "Partly cloudy")
        case 3: return ("\u{2601}\u{FE0F}", "Overcast")
        case 45, 48: return ("\u{1F32B}\u{FE0F}", "Fog")
        case 51, 53, 55: return ("\u{1F326}\u{FE0F}", "Drizzle")
        case 61, 63, 65: return ("\u{1F327}\u{FE0F}", "Rain")
        case 66, 67: return ("\u{1F327}\u{FE0F}", "Freezing rain")
        case 71, 73, 75: return ("\u{2744}\u{FE0F}", "Snow")
        case 77: return ("\u{1F328}\u{FE0F}", "Snow grains")
        case 80, 81, 82: return ("\u{1F327}\u{FE0F}", "Rain showers")
        case 85, 86: return ("\u{1F328}\u{FE0F}", "Snow showers")
        case 95: return ("\u{26C8}\u{FE0F}", "Thunderstorm")
        case 96, 99: return ("\u{26C8}\u{FE0F}", "Thunderstorm with hail")
        default: return ("\u{1F321}\u{FE0F}", "Unknown")
        }
    }
    // MARK: - News

    private func fetchNews() {
        fetchRSSFeed()
        fetchLaFenice()
    }

    private func mergeAndReload() {
        let seen = Set(feniceItems.compactMap { $0.link })
        let filtered = newsItems.filter { item in
            guard let link = item.link else { return true }
            return !seen.contains(link)
        }
        let merged = filtered + feniceItems
        newsItems = merged
        newsCollectionView.reloadData()
    }

    private func fetchRSSFeed() {
        let urlString = "https://janwillembrands.github.io/veneto-events/events.rss"
        guard let url = URL(string: urlString) else { return }

        newsParser.parse(url: url) { [weak self] items in
            DispatchQueue.main.async {
                self?.newsItems = items
                self?.mergeAndReload()
            }
        }
    }

    private func fetchLaFenice() {
        feniceScraper.fetch { [weak self] items in
            DispatchQueue.main.async {
                self?.feniceItems = items
                self?.mergeAndReload()
            }
        }
    }

    // MARK: - Web Overlay

    private func showOverlay(urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }

        let bg = UIView(frame: view.bounds)
        bg.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissOverlay))
        tap.delegate = self
        bg.addGestureRecognizer(tap)
        view.addSubview(bg)
        overlayBackground = bg

        let inset: CGFloat = 30
        let webFrame = bg.bounds.insetBy(dx: inset, dy: inset + 20)

        let webView = WKWebView(frame: webFrame)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.layer.cornerRadius = 12
        webView.clipsToBounds = true
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.load(URLRequest(url: url))
        bg.addSubview(webView)
        overlayWebView = webView
    }

    @objc private func dismissOverlay() {
        overlayWebView?.removeFromSuperview()
        overlayWebView = nil
        overlayBackground?.removeFromSuperview()
        overlayBackground = nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MainViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let webView = overlayWebView, webView.frame.contains(touch.location(in: overlayBackground)) {
            return false
        }
        return true
    }
}

// MARK: - UICollectionView DataSource & Delegate

extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    private func visibleItems(from items: [RSSItem], offset: Int) -> [RSSItem] {
        guard !items.isEmpty else { return [] }
        var result: [RSSItem] = []
        for i in 0..<min(itemsPerPage, items.count) {
            let idx = (offset + i) % items.count
            result.append(items[idx])
        }
        return result
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(itemsPerPage, newsItems.count)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NewsCardCell.reuseID, for: indexPath) as! NewsCardCell
        let visible = visibleItems(from: newsItems, offset: newsDisplayOffset)
        if indexPath.item < visible.count {
            cell.configure(with: visible[indexPath.item])
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 10
        let width = (collectionView.bounds.width - spacing) / 2
        return CGSize(width: width, height: 112)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let visible = visibleItems(from: newsItems, offset: newsDisplayOffset)
        if indexPath.item < visible.count {
            showOverlay(urlString: visible[indexPath.item].link)
        }
    }
}

// MARK: - News Card Cell (Collection View)

class NewsCardCell: UICollectionViewCell {

    static let reuseID = "NewsCardCell"

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        v.layer.cornerRadius = 10
        v.clipsToBounds = true
        return v
    }()

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        return iv
    }()

    private let headlineLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 2
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.numberOfLines = 2
        return label
    }()

    private var imageTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        dateLabel.text = nil
    }

    private func setupLayout() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(thumbnailImageView)

        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(headlineLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Square thumbnail
            thumbnailImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 6),
            thumbnailImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 100),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 100),

            // Title + date stacked on the right
            headlineLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 10),
            headlineLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            headlineLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),

            dateLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: headlineLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with item: RSSItem) {
        headlineLabel.text = item.title
        // First line: "Venue • dates", second line: "type — source"
        let descLines = item.description.components(separatedBy: "\n")
        dateLabel.text = descLines.first

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
