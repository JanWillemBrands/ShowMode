//
//  LaFeniceScraper.swift
//  ShowMode
//

import Foundation

class LaFeniceScraper {

    private static let pageURL = "https://www.teatrolafenice.it/en/whats-on/"
    private static let apiURL = "https://api.github.com/repos/JanWillemBrands/veneto-events/contents/docs/fenice.json"

    private var lastUploadedContent: Data?

    private let isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Europe/Rome")
        return df
    }()

    func fetch(completion: @escaping ([RSSItem]) -> Void) {
        guard let url = URL(string: LaFeniceScraper.pageURL) else {
            completion([])
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("ShowMode/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let html = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }
            let (items, rawEvents) = self.parseHTML(html)
            if !rawEvents.isEmpty {
                self.uploadToGitHub(rawEvents)
            }
            completion(items)
        }.resume()
    }

    // MARK: - HTML Parsing

    private func parseHTML(_ html: String) -> ([RSSItem], [[String: String]]) {
        var items: [RSSItem] = []
        var rawEvents: [[String: String]] = []
        let today = Date()
        let calendar = Calendar.current

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Rome")

        var searchStart = html.startIndex
        while let rowRange = html.range(of: "data-list-id=\"", range: searchStart..<html.endIndex) {
            let idStart = rowRange.upperBound
            guard let idEnd = html.range(of: "\"", range: idStart..<html.endIndex) else { break }
            let dateStr = String(html[idStart..<idEnd.lowerBound])
            searchStart = idEnd.upperBound

            guard let rowDate = dateFormatter.date(from: dateStr) else { continue }
            if rowDate < calendar.startOfDay(for: today) { continue }

            let nextRowRange = html.range(of: "data-list-id=\"", range: searchStart..<html.endIndex)
            let blockEnd = nextRowRange?.lowerBound ?? html.endIndex
            let block = String(html[searchStart..<blockEnd])
            let (blockItems, blockRaw) = parseEventBlock(block, rowDate: rowDate)
            items.append(contentsOf: blockItems)
            rawEvents.append(contentsOf: blockRaw)

            if nextRowRange == nil { break }
        }

        return (items, rawEvents)
    }

    private func parseEventBlock(_ block: String, rowDate: Date) -> ([RSSItem], [[String: String]]) {
        var items: [RSSItem] = []
        var rawEvents: [[String: String]] = []
        let marker = "sn_calendar_block_list_row_group_i"

        var searchStart = block.startIndex
        while let eventRange = block.range(of: marker, range: searchStart..<block.endIndex) {
            searchStart = eventRange.upperBound

            let nextEvent = block.range(of: marker, range: searchStart..<block.endIndex)
            let eventEnd = nextEvent?.lowerBound ?? block.endIndex
            let eventHTML = String(block[searchStart..<eventEnd])

            let title = extractTagContent(eventHTML, className: "title")
            if title.isEmpty { continue }

            let category = extractTagContent(eventHTML, className: "category")
            let venue = extractTagContent(eventHTML, className: "place")
            let link = extractHref(eventHTML)
            let image = extractImgSrc(eventHTML)

            let venueName = venue.isEmpty ? "La Fenice" : venue
            let datePart = formatDate(rowDate)
            let categoryPart = category.isEmpty ? "" : category + " \u{2014} "
            let desc = "\(venueName) \u{2022} \(datePart)\n\(categoryPart)La Fenice"

            items.append(RSSItem(
                title: title,
                description: desc,
                thumbnailURL: image,
                link: link
            ))

            rawEvents.append([
                "title": title,
                "start": isoFormatter.string(from: rowDate),
                "url": link ?? "",
                "venue": venueName,
                "type": category,
                "source": "La Fenice",
                "image": image ?? "",
            ])
        }

        return (items, rawEvents)
    }

    // MARK: - GitHub Upload

    private func uploadToGitHub(_ events: [[String: String]]) {
        guard let token = Bundle.main.infoDictionary?["GitHubToken"] as? String,
              !token.isEmpty else { return }

        let payload: [String: Any] = ["events": events]
        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys, .prettyPrinted]
        ) else { return }

        if let last = lastUploadedContent, last == jsonData { return }

        guard let apiURL = URL(string: LaFeniceScraper.apiURL) else { return }

        var getRequest = URLRequest(url: apiURL)
        getRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        getRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: getRequest) { [weak self] data, _, _ in
            var sha: String?
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                sha = json["sha"] as? String
                if let existing = json["content"] as? String {
                    let cleaned = existing.replacingOccurrences(of: "\n", with: "")
                    if let existingData = Data(base64Encoded: cleaned),
                       existingData == jsonData {
                        self?.lastUploadedContent = jsonData
                        return
                    }
                }
            }

            var body: [String: Any] = [
                "message": "Update La Fenice events [from iPad]",
                "content": jsonData.base64EncodedString(),
            ]
            if let sha = sha {
                body["sha"] = sha
            }

            guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

            var putRequest = URLRequest(url: apiURL)
            putRequest.httpMethod = "PUT"
            putRequest.httpBody = bodyData
            putRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            putRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: putRequest) { _, response, _ in
                if let http = response as? HTTPURLResponse,
                   http.statusCode == 200 || http.statusCode == 201 {
                    self?.lastUploadedContent = jsonData
                    print("La Fenice: uploaded \(events.count) events to GitHub")
                }
            }.resume()
        }.resume()
    }

    // MARK: - HTML Helpers

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd MMM"
        df.timeZone = TimeZone(identifier: "Europe/Rome")
        return df.string(from: date)
    }

    private func extractTagContent(_ html: String, className: String) -> String {
        guard let classRange = html.range(of: "class=\"\(className)\"") else { return "" }
        guard let tagClose = html.range(of: ">", range: classRange.upperBound..<html.endIndex) else { return "" }
        guard let endTag = html.range(of: "<", range: tagClose.upperBound..<html.endIndex) else { return "" }
        return decodeHTMLEntities(String(html[tagClose.upperBound..<endTag.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                        ("&quot;", "\""), ("&apos;", "'"), ("&#8217;", "\u{2019}"),
                        ("&#8216;", "\u{2018}"), ("&#8211;", "\u{2013}"),
                        ("&#8212;", "\u{2014}"), ("&#8230;", "\u{2026}")]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }

    private func extractHref(_ html: String) -> String? {
        guard let hrefRange = html.range(of: "href=\"") else { return nil }
        let start = hrefRange.upperBound
        guard let end = html.range(of: "\"", range: start..<html.endIndex) else { return nil }
        let url = String(html[start..<end.lowerBound])
        return url.isEmpty ? nil : url
    }

    private func extractImgSrc(_ html: String) -> String? {
        guard let figureRange = html.range(of: "<figure") else { return nil }
        guard let srcRange = html.range(of: "src=\"", range: figureRange.upperBound..<html.endIndex) else { return nil }
        let start = srcRange.upperBound
        guard let end = html.range(of: "\"", range: start..<html.endIndex) else { return nil }
        let url = String(html[start..<end.lowerBound])
        return url.isEmpty ? nil : url
    }
}
