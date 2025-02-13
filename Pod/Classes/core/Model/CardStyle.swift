//
//  CardStyle.swift
//  AptoSDK
//
//  Created by Ivan Oliver Martínez on 31/10/2018.
//

import SwiftyJSON
import UIKit

public enum CardBackgroundStyle: Equatable {
    case image(url: URL)
    case color(color: UIColor)
}

extension CardBackgroundStyle: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.image) {
            let url = try container.decode(URL.self, forKey: .image)
            self = .image(url: url)
        } else {
            let codableColor = try container.decode(UIColor.CodableWrapper.self, forKey: .color)
            self = .color(color: codableColor.value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .image(url):
            try container.encode(url, forKey: .image)
        case let .color(color):
            try container.encode(UIColor.CodableWrapper(color), forKey: .color)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case image
        case color
    }
}

public struct CardStyle: Codable {
    public let background: CardBackgroundStyle
    public let textColor: String?
    public let balanceSelectorImage: String?
    public let cardLogo: URL?

    public init(
        background: CardBackgroundStyle,
        textColor: String?,
        balanceSelectorImage: String?,
        cardLogo: URL?
    ) {
        self.background = background
        self.textColor = textColor
        self.balanceSelectorImage = balanceSelectorImage
        self.cardLogo = cardLogo
    }
}

extension JSON {
    var cardStyle: CardStyle? {
        guard let background = self["background"].cardBackgroundStyle else {
            ErrorLogger.defaultInstance().log(error: ServiceError(code: ServiceError.ErrorCodes.jsonError,
                                                                  reason: "Can't parse Card Style \(self)"))
            return nil
        }
        let textColor = self["text_color"].string
        let balanceSelectorImage = self["balance_selector_asset"].string
        let logo = self["background"]["card_logo"].string ?? ""
        let cardLogo = !logo.isEmpty ? URL(string: logo) : nil
        return CardStyle(background: background,
                         textColor: textColor,
                         balanceSelectorImage: balanceSelectorImage,
                         cardLogo: cardLogo)
    }

    var cardBackgroundStyle: CardBackgroundStyle? {
        guard let rawBackgroundType = self["background_type"].string else {
            ErrorLogger.defaultInstance().log(error: ServiceError(code: ServiceError.ErrorCodes.jsonError,
                                                                  reason: "Can't parse Card Background Style \(self)"))
            return nil
        }
        if rawBackgroundType == "image",
           let rawBackgroundImage = self["background_image"].string,
           let backgroundImageURL = URL(string: rawBackgroundImage)
        {
            return CardBackgroundStyle.image(url: backgroundImageURL)
        }
        if rawBackgroundType == "color",
           let rawColor = self["background_color"].string,
           let color = UIColor.colorFromHexString(rawColor)
        {
            return CardBackgroundStyle.color(color: color)
        }
        return nil
    }
}
