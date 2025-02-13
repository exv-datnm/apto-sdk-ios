//
//  NSMutableAttributedString.swift
//  AptoSDK
//
//  Created by Ivan Oliver Martínez on 13/06/16.
//
//

import UIKit

public extension NSMutableAttributedString {
    internal static func createFrom(string: String, font: UIFont, color: UIColor) -> NSMutableAttributedString {
        let retVal = NSMutableAttributedString(string: string, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: color,
        ])
        return retVal
    }

    func replacePlainTextStyle(font: UIFont, color: UIColor, lineSpacing: CGFloat = 0,
                               paragraphSpacing: CGFloat = 12)
    {
        let range = NSRange(location: 0, length: length)
        enumerateAttribute(NSAttributedString.Key.font,
                           in: range,
                           options: .longestEffectiveRangeNotRequired) { attribute, range, _ in
            guard attribute is UIFont else { return }
            self.removeAttribute(NSAttributedString.Key.font, range: range)
            self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
            self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
            let mutableParagraphStyle = NSMutableParagraphStyle()
            mutableParagraphStyle.lineSpacing = lineSpacing
            mutableParagraphStyle.paragraphSpacing = paragraphSpacing
            self.addAttributes([.paragraphStyle: mutableParagraphStyle], range: range)
        }
    }

    func replaceLinkStyle(font: UIFont, color: UIColor, lineSpacing: CGFloat = 0, paragraphSpacing: CGFloat = 12) {
        let range = NSRange(location: 0, length: length)
        enumerateAttribute(NSAttributedString.Key.link,
                           in: range,
                           options: .longestEffectiveRangeNotRequired) { attribute, range, _ in
            guard attribute is URL else { return }
            self.removeAttribute(NSAttributedString.Key.font, range: range)
            self.removeAttribute(NSAttributedString.Key.foregroundColor, range: range)
            self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
            self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
            let mutableParagraphStyle = NSMutableParagraphStyle()
            mutableParagraphStyle.lineSpacing = lineSpacing
            mutableParagraphStyle.paragraphSpacing = paragraphSpacing
            self.addAttributes([.paragraphStyle: mutableParagraphStyle], range: range)
        }
    }
}
