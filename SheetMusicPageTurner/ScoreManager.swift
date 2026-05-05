import UIKit
import PDFKit

class ScoreManager {
    static let shared = ScoreManager()

    private(set) var scores: [Score] = []
    private let documentsDirectory: URL

    struct Score {
        let id: UUID
        let name: String
        let pages: [UIImage]
        let createdAt: Date
    }

    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func importPDF(from url: URL) -> Score? {
        print("ScoreManager: importPDF called with URL: \(url)")
        
        guard let document = PDFDocument(url: url) else {
            print("ScoreManager: Failed to create PDFDocument from: \(url)")
            return nil
        }
        print("ScoreManager: PDFDocument created, pages: \(document.pageCount)")
        
        var pages: [UIImage] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            pages.append(image)
        }
        print("ScoreManager: Rendered \(pages.count) pages")
        
        let score = Score(
            id: UUID(),
            name: url.deletingPathExtension().lastPathComponent,
            pages: pages,
            createdAt: Date()
        )
        
        scores.append(score)
        print("ScoreManager: Score added successfully, total scores: \(scores.count)")
        
        return score
    }

    func importImages(from urls: [URL]) -> Score? {
        var pages: [UIImage] = []
        for url in urls {
            guard let image = UIImage(contentsOfFile: url.path) else { continue }
            pages.append(image)
        }

        guard !pages.isEmpty else { return nil }

        let score = Score(
            id: UUID(),
            name: "新建琴谱 \(scores.count + 1)",
            pages: pages,
            createdAt: Date()
        )
        scores.append(score)
        return score
    }

    func deleteScore(at index: Int) {
        guard index >= 0 && index < scores.count else { return }
        scores.remove(at: index)
    }

    func getScore(at index: Int) -> Score? {
        guard index >= 0 && index < scores.count else { return nil }
        return scores[index]
    }
}