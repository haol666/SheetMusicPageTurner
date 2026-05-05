import UIKit
import PDFKit

class ScoreManager {
    static let shared = ScoreManager()

    private(set) var scores: [Score] = []
    private let documentsDirectory: URL
    private let scoresFileURL: URL

    struct Score: Codable {
        let id: UUID
        let name: String
        let pageFileNames: [String]
        let createdAt: Date
    }

    private init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        scoresFileURL = documentsDirectory.appendingPathComponent("scores.json")
        loadScores()
    }

    private func loadScores() {
        guard FileManager.default.fileExists(atPath: scoresFileURL.path) else {
            scores = []
            return
        }

        do {
            let data = try Data(contentsOf: scoresFileURL)
            scores = try JSONDecoder().decode([Score].self, from: data)
        } catch {
            print("Failed to load scores: \(error)")
            scores = []
        }
    }

    private func saveScores() {
        do {
            let data = try JSONEncoder().encode(scores)
            try data.write(to: scoresFileURL)
        } catch {
            print("Failed to save scores: \(error)")
        }
    }

    func importPDF(from url: URL) -> Score? {
        print("ScoreManager: importPDF called with URL: \(url)")

        guard let document = PDFDocument(url: url) else {
            print("ScoreManager: Failed to create PDFDocument from: \(url)")
            return nil
        }
        print("ScoreManager: PDFDocument created, pages: \(document.pageCount)")

        let scoreId = UUID()
        let scoreDir = documentsDirectory.appendingPathComponent(scoreId.uuidString)

        do {
            try FileManager.default.createDirectory(at: scoreDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create score directory: \(error)")
            return nil
        }

        var pageFileNames: [String] = []
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

            let fileName = "page_\(i).png"
            let fileURL = scoreDir.appendingPathComponent(fileName)

            if let data = image.pngData() {
                do {
                    try data.write(to: fileURL)
                    pageFileNames.append(fileName)
                } catch {
                    print("Failed to write page \(i): \(error)")
                }
            }
        }
        print("ScoreManager: Saved \(pageFileNames.count) pages")

        let score = Score(
            id: scoreId,
            name: url.deletingPathExtension().lastPathComponent,
            pageFileNames: pageFileNames,
            createdAt: Date()
        )

        scores.append(score)
        saveScores()
        print("ScoreManager: Score added successfully, total scores: \(scores.count)")

        return score
    }

    func importImages(from urls: [URL]) -> Score? {
        let scoreId = UUID()
        let scoreDir = documentsDirectory.appendingPathComponent(scoreId.uuidString)

        do {
            try FileManager.default.createDirectory(at: scoreDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create score directory: \(error)")
            return nil
        }

        var pageFileNames: [String] = []
        for (index, url) in urls.enumerated() {
            guard let image = UIImage(contentsOfFile: url.path) else { continue }

            let fileName = "page_\(index).png"
            let fileURL = scoreDir.appendingPathComponent(fileName)

            if let data = image.pngData() {
                try? data.write(to: fileURL)
                pageFileNames.append(fileName)
            }
        }

        guard !pageFileNames.isEmpty else { return nil }

        let score = Score(
            id: scoreId,
            name: "新建琴谱 \(scores.count + 1)",
            pageFileNames: pageFileNames,
            createdAt: Date()
        )
        scores.append(score)
        saveScores()
        return score
    }

    func deleteScore(at index: Int) {
        guard index >= 0 && index < scores.count else { return }

        let score = scores[index]
        let scoreDir = documentsDirectory.appendingPathComponent(score.id.uuidString)

        try? FileManager.default.removeItem(at: scoreDir)

        scores.remove(at: index)
        saveScores()
    }

    func getScore(at index: Int) -> Score? {
        guard index >= 0 && index < scores.count else { return nil }
        return scores[index]
    }

    func getPages(for score: Score) -> [UIImage] {
        let scoreDir = documentsDirectory.appendingPathComponent(score.id.uuidString)

        var pages: [UIImage] = []
        for fileName in score.pageFileNames {
            let fileURL = scoreDir.appendingPathComponent(fileName)
            if let image = UIImage(contentsOfFile: fileURL.path) {
                pages.append(image)
            }
        }
        return pages
    }
}