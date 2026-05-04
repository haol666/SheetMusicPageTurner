import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private var captureLayer: AVCaptureVideoPreviewLayer?

    private let scrollView = UIScrollView()
    private let pageImageView = UIImageView()
    private let pageLabel = UILabel()
    private let cameraPreviewView = UIView()
    private let actionButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let noScoreLabel = UILabel()

    private var currentScore: ScoreManager.Score?
    private var currentPage = 0

    private let mouthOpenThreshold: CGFloat = 0.5
    private let headNodThreshold: CGFloat = 0.05
    private var lastActionTime = Date().timeIntervalSince1970
    private let actionCooldown = 1.0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        loadCurrentScore()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCurrentScore()
        if !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func setupUI() {
        title = "面部翻页"
        view.backgroundColor = .white

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        pageImageView.contentMode = .scaleAspectFit
        scrollView.addSubview(pageImageView)

        noScoreLabel.text = "请先在琴谱管理中添加琴谱"
        noScoreLabel.textAlignment = .center
        noScoreLabel.textColor = .gray
        noScoreLabel.font = UIFont.systemFont(ofSize: 18)
        noScoreLabel.isHidden = true
        view.addSubview(noScoreLabel)

        pageLabel.textAlignment = .center
        pageLabel.font = UIFont.systemFont(ofSize: 16)
        pageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        pageLabel.textColor = .white
        pageLabel.layer.cornerRadius = 8
        pageLabel.clipsToBounds = true
        view.addSubview(pageLabel)

        cameraPreviewView.backgroundColor = .black
        cameraPreviewView.layer.cornerRadius = 50
        cameraPreviewView.clipsToBounds = true
        cameraPreviewView.layer.borderWidth = 2
        cameraPreviewView.layer.borderColor = UIColor.white.cgColor
        view.addSubview(cameraPreviewView)

        actionButton.setTitle("手动翻页", for: .normal)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 8
        actionButton.addTarget(self, action: #selector(manualPageTurn), for: .touchUpInside)
        view.addSubview(actionButton)

        settingsButton.setTitle("设置", for: .normal)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)

        setupConstraints()
        setupGesture()
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        pageImageView.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        cameraPreviewView.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        noScoreLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            pageImageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            pageImageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            pageImageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            pageImageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            pageImageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            pageImageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            noScoreLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noScoreLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            pageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            pageLabel.heightAnchor.constraint(equalToConstant: 40),

            cameraPreviewView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cameraPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cameraPreviewView.widthAnchor.constraint(equalToConstant: 100),
            cameraPreviewView.heightAnchor.constraint(equalToConstant: 100),

            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 120),
            actionButton.heightAnchor.constraint(equalToConstant: 44),

            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])
    }

    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)
    }

    private func loadCurrentScore() {
        if let firstScore = ScoreManager.shared.scores.first {
            currentScore = firstScore
            currentPage = 0
            displayCurrentPage()
            scrollView.isHidden = false
            noScoreLabel.isHidden = true
        } else {
            currentScore = nil
            scrollView.isHidden = true
            noScoreLabel.isHidden = false
            pageLabel.isHidden = true
            actionButton.isHidden = true
        }
    }

    private func displayCurrentPage() {
        guard let score = currentScore,
              currentPage >= 0 && currentPage < score.pages.count else { return }

        pageImageView.image = score.pages[currentPage]
        pageLabel.text = "  第 \(currentPage + 1) / \(score.pages.count) 页  "
        pageLabel.isHidden = false
        actionButton.isHidden = false
        scrollView.setZoomScale(1.0, animated: false)
    }

    private func setupCamera() {
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("无法获取前置摄像头")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("摄像头输入错误: \(error)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: visionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        captureLayer = AVCaptureVideoPreviewLayer(session: session)
        captureLayer?.videoGravity = .resizeAspectFill
        cameraPreviewView.layer.addSublayer(captureLayer!)

        DispatchQueue.main.async {
            self.captureLayer?.frame = self.cameraPreviewView.bounds
        }

        session.startRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureLayer?.frame = cameraPreviewView.bounds
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard currentScore != nil else { return }

        let location = gesture.location(in: view)
        let screenWidth = view.bounds.width

        if location.x < screenWidth / 3 {
            previousPage()
        } else if location.x > screenWidth * 2 / 3 {
            nextPage()
        }
    }

    @objc private func manualPageTurn() {
        nextPage()
    }

    private func nextPage() {
        guard let score = currentScore else { return }
        guard currentPage < score.pages.count - 1 else { return }

        performPageTurn {
            self.currentPage += 1
            self.displayCurrentPage()
        }
    }

    private func previousPage() {
        guard let score = currentScore else { return }
        guard currentPage > 0 else { return }

        performPageTurn {
            self.currentPage -= 1
            self.displayCurrentPage()
        }
    }

    private func performPageTurn(completion: @escaping () -> Void) {
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastActionTime < actionCooldown {
            return
        }

        lastActionTime = currentTime

        DispatchQueue.main.async {
            completion()
        }
    }

    @objc private func openSettings() {
        let alert = UIAlertController(title: "设置", message: "调整面部识别灵敏度", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 高", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.3
        })

        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 中", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.5
        })

        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 低", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.7
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        present(alert, animated: true)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] req, err in
            self?.handleFace(request: req)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])

        try? handler.perform([request])
    }

    private func handleFace(request: VNRequest) {
        guard let results = request.results as? [VNFaceObservation] else { return }

        for face in results {
            guard let landmarks = face.landmarks else { continue }
            detectMouth(landmarks: landmarks)
        }
    }

    private func detectMouth(landmarks: VNFaceLandmarks2D) {
        guard let outerLips = landmarks.outerLips else { return }

        let points = outerLips.normalizedPoints
        guard points.count >= 10 else { return }

        let top = points[3]
        let bottom = points[9]
        let left = points[0]
        let right = points[6]

        let mouthHeight = abs(top.y - bottom.y)
        let mouthWidth = abs(left.x - right.x)

        let mar = mouthHeight / mouthWidth

        if mar > mouthOpenThreshold {
            DispatchQueue.main.async {
                self.nextPage()
            }
        }
    }
}

extension ViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pageImageView
    }
}