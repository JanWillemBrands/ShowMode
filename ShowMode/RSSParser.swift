//
//  RSSParser.swift
//  ShowMode
//
//  Created by Johannes Brands on 2026.04.12.
//

import Foundation

struct RSSItem {
    let title: String
    let description: String
    let thumbnailURL: String?
}

class RSSParser: NSObject, XMLParserDelegate {

    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentThumbnailURL: String?
    private var isInsideItem = false
    private var completion: (([RSSItem]) -> Void)?

    func parse(url: URL, completion: @escaping ([RSSItem]) -> Void) {
        self.completion = completion

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                completion([])
                return
            }
            self.items = []
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            completion(self.items)
        }.resume()
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentDescription = ""
            currentThumbnailURL = nil
        }
        // BBC RSS uses <media:thumbnail url="..."/>
        if isInsideItem && (elementName == "media:thumbnail" || elementName == "thumbnail") {
            if let url = attributeDict["url"] {
                currentThumbnailURL = url
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "description":
            currentDescription += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            let item = RSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                thumbnailURL: currentThumbnailURL
            )
            items.append(item)
            isInsideItem = false
        }
        // Reset currentElement when closing a tag to avoid appending stray characters
        if currentElement == elementName {
            currentElement = ""
        }
    }
}
