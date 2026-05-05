import UIKit
import PhotosUI
import UniformTypeIdentifiers

class ScoreImportViewController: UIViewController {

    private let tableView = UITableView()
    private var scores: [ScoreManager.Score] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadScores()
    }

    private func setupUI() {
        title = "琴谱管理"
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addScore)
        )

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ScoreCell")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadScores() {
        scores = ScoreManager.shared.scores
        tableView.reloadData()
    }

    @objc private func addScore() {
        let alert = UIAlertController(title: "导入琴谱", message: "请选择导入方式", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "从PDF导入", style: .default) { [weak self] _ in
            self?.importPDF()
        })

        alert.addAction(UIAlertAction(title: "从图片导入", style: .default) { [weak self] _ in
            self?.importImages()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        present(alert, animated: true)
    }

    private func importPDF() {
        if #available(iOS 14.0, *) {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            present(documentPicker, animated: true)
        } else {
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["com.adobe.pdf"], in: .import)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            present(documentPicker, animated: true)
        }
    }

    private func importImages() {
        if #available(iOS 14.0, *) {
            var config = PHPickerConfiguration()
            config.selectionLimit = 20
            config.filter = .images

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = false
            present(picker, animated: true)
        }
    }

    private func openScore(at index: Int) {
        guard let score = ScoreManager.shared.getScore(at: index) else { return }
        let displayVC = ScoreDisplayViewController(score: score)
        navigationController?.pushViewController(displayVC, animated: true)
    }

    private func deleteScore(at index: Int) {
        ScoreManager.shared.deleteScore(at: index)
        loadScores()
    }
}

extension ScoreImportViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scores.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScoreCell", for: indexPath)
        let score = scores[indexPath.row]
        if #available(iOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = score.name
            content.secondaryText = "\(score.pages.count) 页"
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = score.name
            cell.detailTextLabel?.text = "\(score.pages.count) 页"
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openScore(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteScore(at: indexPath.row)
        }
    }
}

extension ScoreImportViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            if let score = ScoreManager.shared.importPDF(from: url) {
                loadScores()
                openScore(at: scores.firstIndex(where: { $0.id == score.id }) ?? 0)
            } else {
                showError("无法读取PDF文件")
            }
        }
    }
}

extension ScoreImportViewController: PHPickerViewControllerDelegate {
    @available(iOS 14.0, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        var urls: [URL] = []
        let group = DispatchGroup()

        for result in results {
            group.enter()
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let url = url {
                    let tempDir = FileManager.default.temporaryDirectory
                    let destURL = tempDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: destURL)
                    urls.append(destURL)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            if let score = ScoreManager.shared.importImages(from: urls) {
                self?.loadScores()
                self?.openScore(at: self?.scores.firstIndex(where: { $0.id == score.id }) ?? 0)
            } else {
                self?.showError("无法读取图片文件")
            }
        }
    }
}

extension ScoreImportViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let image = info[.originalImage] as? UIImage {
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "image_\(Date().timeIntervalSince1970).png"
            let destURL = tempDir.appendingPathComponent(fileName)

            if let data = image.pngData() {
                try? data.write(to: destURL)

                if let score = ScoreManager.shared.importImages(from: [destURL]) {
                    loadScores()
                    openScore(at: scores.firstIndex(where: { $0.id == score.id }) ?? 0)
                } else {
                    showError("无法保存图片")
                }
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}