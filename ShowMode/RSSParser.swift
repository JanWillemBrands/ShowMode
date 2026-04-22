//
//  RSSParser.swift
//  ShowMode
//

import Foundation

struct RSSItem {
    let title: String
    let description: String
    let thumbnailURL: String?
    let link: String?
}

class RSSParser: NSObject, XMLParserDelegate {

    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentThumbnailURL: String?
    private var currentLink = ""
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
            currentLink = ""
        }
        if isInsideItem {
            // BBC uses media:thumbnail, Repubblica uses enclosure with image type
            if elementName == "media:thumbnail" || elementName == "thumbnail" {
                if let url = attributeDict["url"] {
                    currentThumbnailURL = url
                }
            }
            if elementName == "enclosure" {
                if let type = attributeDict["type"], type.hasPrefix("image"),
                   let url = attributeDict["url"] {
                    currentThumbnailURL = url
                }
            }
            // Also check media:content
            if elementName == "media:content" {
                if let medium = attributeDict["medium"], medium == "image",
                   let url = attributeDict["url"] {
                    currentThumbnailURL = currentThumbnailURL ?? url
                }
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
        case "link":
            currentLink += string
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
                thumbnailURL: currentThumbnailURL,
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            items.append(item)
            isInsideItem = false
        }
        if currentElement == elementName {
            currentElement = ""
        }
    }
}
