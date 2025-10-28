//
//  NSAttributedString+Emojis.swift
//  Streamoji
//
//  Created by Matheus Cardoso on 30/06/20.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class EmojiTextAttachment: NSTextAttachment {
    var emojiData: Data?
}

extension NSAttributedString {
    internal func insertingEmojis(
        _ emojis: [String: EmojiSource],
        rendering: EmojiRendering
    ) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self)

        var ranges = attributedString.getMatches()
        let notMatched = attributedString.insertEmojis(
            emojis,
            in: string.filterOutRangesInsideCode(ranges: ranges),
            rendering: rendering
        )
        ranges = attributedString.getMatches(excludingRanges: notMatched)
        attributedString.insertEmojis(
            emojis,
            in: string.filterOutRangesInsideCode(ranges: ranges),
            rendering: rendering
        )

        return attributedString
    }
    
    private func getMatches(
        excludingRanges: [NSRange] = []
    ) -> [NSRange] {
        var ranges = [NSRange]()
        var lastMatchIndex = 0
        for range in excludingRanges {
            ranges.append(NSRange(location: lastMatchIndex, length: range.location - lastMatchIndex + 1))
            lastMatchIndex = range.location + range.length - 1
        }
        ranges.append(NSRange(location: lastMatchIndex, length: length - lastMatchIndex))

        let regex = try? NSRegularExpression(pattern: ":(\\w|-|\\+)+:", options: [])
        let matchRanges = ranges.map { range in regex?.matches(in: string, options: [], range: range).map { $0.range(at: 0) } ?? [] }
        return matchRanges.reduce(into: [NSRange]()) { $0.append(contentsOf: $1) }
    }
}

extension NSMutableAttributedString {
    @discardableResult
    internal func insertEmojis(
        _ emojis: [String: EmojiSource],
        in ranges: [NSRange],
        rendering: EmojiRendering
    ) -> [NSRange] {
        var offset = 0
        var notMatched = [NSRange]()

        for range in ranges {
            let transformedRange = NSRange(location: range.location - offset, length: range.length)
            let replacementString = self.attributedSubstring(from: transformedRange)
            
            #if os(macOS)
            let font = replacementString.attribute(.font, at: 0, effectiveRange: .none) as? NSFont
            #else
            let font = replacementString.attribute(.font, at: 0, effectiveRange: .none) as? UIFont
            #endif
            
            let paragraphStyle = replacementString.attribute(.paragraphStyle, at: 0, effectiveRange: .none) as? NSParagraphStyle
            
            let emojiAttachment = EmojiTextAttachment()
            
            #if os(macOS)
            // Workaround to possible macOS bug; bounds are ignored if image is nil.
            emojiAttachment.image = NSImage()
            #endif
            
            let fontSize = (font?.pointSize ?? 22.0) * CGFloat(rendering.scale)
            let capHeight = (font?.capHeight ?? 22.0) * CGFloat(rendering.scale)
            let yOffset = (capHeight - fontSize) / 2.0
            emojiAttachment.bounds = CGRect(x: 0, y: yOffset, width: fontSize, height: fontSize)
            
            let emojiAttributedString = NSMutableAttributedString(attachment: emojiAttachment)
            
            if let font = font, let paragraphStyle = paragraphStyle {
                emojiAttributedString.setAttributes(
                    [.font: font, .paragraphStyle: paragraphStyle, .attachment: emojiAttachment],
                    range: .init(location: 0, length: emojiAttributedString.length)
                )
            }

            if var emoji = emojis[replacementString.string.replacingOccurrences(of: ":", with: "")] {
                if case .alias(let alias) = emoji {
                    emoji = emojis[alias] ?? emoji
                }
                
                let data = try! JSONEncoder().encode(emoji)
                emojiAttachment.emojiData = data
                #if !os(macOS)
                emojiAttachment.image = UIImage()
                #endif
                
                self.replaceCharacters(
                    in: transformedRange,
                    with: emojiAttributedString
                )

                offset += replacementString.length - 1
            } else {
                notMatched.append(transformedRange)
            }
        }

        return notMatched
    }
}
