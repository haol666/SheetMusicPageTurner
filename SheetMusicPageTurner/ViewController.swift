import UIKit
import AVFoundation
import Vision

enum PageTurnAction: Int, CaseIterable {
    case mouthOpen = 0
    case blink = 1
    case headNod = 2

    var title: String {
        switch self {
        case .mouthOpen: return "张嘴"
        case .blink: return "眨眼"
        case .headNod: return "点头"
        }
    }
}

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
    private let gestureHintLabel = UILabel()

    private var currentScore: ScoreManager.Score?
    private var currentPage = 0

    private var mouthOpenThreshold: CGFloat = 0.7
    private var headNodThreshold: CGFloat = 0.12
    private var eyeBlinkThreshold: CGFloat = 0.2

    var forwardAction: PageTurnAction = .mouthOpen
    var backwardAction: PageTurnAction = .headNod
    var forwardThreshold: CGFloat = 0.7
    var backwardThreshold: CGFloat = 0.12

    private var lastActionTime = Date().timeIntervalSince1970
    private let actionCooldown = 1.0

    private var previousNoseY: CGFloat = 0.5
    private var isFirstFaceDetection = true

    private var lastMouthOpenTime: TimeInterval = 0
    private var lastHeadNodTime: TimeInterval = 0
    private var lastBlinkTime: TimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
        loadCurrentScore()
        updateGestureHint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCurrentScore()
        isFirstFaceDetection = true
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

        gestureHintLabel.textAlignment = .center
        gestureHintLabel.font = UIFont.systemFont(ofSize: 12)
        gestureHintLabel.textColor = .gray
        gestureHintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        gestureHintLabel.layer.cornerRadius = 4
        gestureHintLabel.clipsToBounds = true
        view.addSubview(gestureHintLabel)

        actionButton.setTitle("下一页", for: .normal)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 8
        actionButton.addTarget(self, action: #selector(manualNextPage), for: .touchUpInside)
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
        gestureHintLabel.translatesAutoresizingMaskIntoConstraints = false

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

            gestureHintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 130),
            gestureHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gestureHintLabel.widthAnchor.constraint(equalToConstant: 280),
            gestureHintLabel.heightAnchor.constraint(equalToConstant: 30),

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
            gestureHintLabel.isHidden = false
        } else {
            currentScore = nil
            scrollView.isHidden = true
            noScoreLabel.isHidden = false
            pageLabel.isHidden = true
            actionButton.isHidden = true
            gestureHintLabel.isHidden = true
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

    @objc private func manualNextPage() {
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
        guard currentScore != nil else { return }
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

    private func updateGestureHint() {
        gestureHintLabel.text = "\(forwardAction.title)→下一页 | \(backwardAction.title)→上一页"
    }

    @objc private func openSettings() {
        let alert = UIAlertController(title: "翻页设置", message: "自定义向前向后翻页动作", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "向前翻页动作", style: .default) { [weak self] _ in
            self?.showActionSelection(forForward: true)
        })

        alert.addAction(UIAlertAction(title: "向后翻页动作", style: .default) { [weak self] _ in
            self?.showActionSelection(forForward: false)
        })

        alert.addAction(UIAlertAction(title: "调整阈值", style: .default) { [weak self] _ in
            self?.showThresholdAdjustment()
        })

        alert.addAction(UIAlertAction(title: "重置为默认", style: .destructive) { [weak self] _ in
            self?.resetToDefault()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = settingsButton
            popover.sourceRect = settingsButton.bounds
        }

        present(alert, animated: true)
    }

    private func showActionSelection(forForward: Bool) {
        let alert = UIAlertController(
            title: forForward ? "选择向前翻页动作" : "选择向后翻页动作",
            message: nil,
            preferredStyle: .actionSheet
        )

        for action in PageTurnAction.allCases {
            let title = action.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                if forForward {
                    self?.forwardAction = action
                } else {
                    self?.backwardAction = action
                }
                self?.updateGestureHint()
            })
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showThresholdAdjustment() {
        let alert = UIAlertController(title: "调整阈值", message: "灵敏度设置（值越小越灵敏）", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 高 (0.3)", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.3
        })
        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 中 (0.5)", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.5
        })
        alert.addAction(UIAlertAction(title: "张嘴灵敏度: 低 (0.7)", style: .default) { [weak self] _ in
            self?.mouthOpenThreshold = 0.7
        })

        alert.addAction(UIAlertAction(title: "眨眼灵敏度: 高 (0.1)", style: .default) { [weak self] _ in
            self?.eyeBlinkThreshold = 0.1
        })
        alert.addAction(UIAlertAction(title: "眨眼灵敏度: 中 (0.2)", style: .default) { [weak self] _ in
            self?.eyeBlinkThreshold = 0.2
        })
        alert.addAction(UIAlertAction(title: "眨眼灵敏度: 低 (0.35)", style: .default) { [weak self] _ in
            self?.eyeBlinkThreshold = 0.35
        })

        alert.addAction(UIAlertAction(title: "点头灵敏度: 高 (0.05)", style: .default) { [weak self] _ in
            self?.headNodThreshold = 0.05
        })
        alert.addAction(UIAlertAction(title: "点头灵敏度: 中 (0.08)", style: .default) { [weak self] _ in
            self?.headNodThreshold = 0.08
        })
        alert.addAction(UIAlertAction(title: "点头灵敏度: 低 (0.12)", style: .default) { [weak self] _ in
            self?.headNodThreshold = 0.12
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func resetToDefault() {
        forwardAction = .mouthOpen
        backwardAction = .headNod
        mouthOpenThreshold = 0.7
        headNodThreshold = 0.12
        eyeBlinkThreshold = 0.2
        updateGestureHint()
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

            let currentTime = Date().timeIntervalSince1970

            if forwardAction == .mouthOpen && currentTime - lastMouthOpenTime > actionCooldown {
                if detectMouthOpen(landmarks: landmarks) {
                    lastMouthOpenTime = currentTime
                    DispatchQueue.main.async {
                        self.nextPage()
                    }
                }
            } else if forwardAction == .blink && currentTime - lastBlinkTime > actionCooldown {
                if detectBlink(landmarks: landmarks) {
                    lastBlinkTime = currentTime
                    DispatchQueue.main.async {
                        self.nextPage()
                    }
                }
            } else if forwardAction == .headNod && currentTime - lastHeadNodTime > actionCooldown {
                if detectHeadNod(landmarks: landmarks) {
                    lastHeadNodTime = currentTime
                    DispatchQueue.main.async {
                        self.nextPage()
                    }
                }
            }

            if backwardAction == .mouthOpen && currentTime - lastMouthOpenTime > actionCooldown {
                if detectMouthOpen(landmarks: landmarks) {
                    lastMouthOpenTime = currentTime
                    DispatchQueue.main.async {
                        self.previousPage()
                    }
                }
            } else if backwardAction == .blink && currentTime - lastBlinkTime > actionCooldown {
                if detectBlink(landmarks: landmarks) {
                    lastBlinkTime = currentTime
                    DispatchQueue.main.async {
                        self.previousPage()
                    }
                }
            } else if backwardAction == .headNod && currentTime - lastHeadNodTime > actionCooldown {
                if detectHeadNod(landmarks: landmarks) {
                    lastHeadNodTime = currentTime
                    DispatchQueue.main.async {
                        self.previousPage()
                    }
                }
            }
        }
    }

    private func detectMouthOpen(landmarks: VNFaceLandmarks2D) -> Bool {
        guard let outerLips = landmarks.outerLips else { return false }

        let points = outerLips.normalizedPoints
        guard points.count >= 10 else { return false }

        let top = points[3]
        let bottom = points[9]
        let left = points[0]
        let right = points[6]

        let mouthHeight = abs(top.y - bottom.y)
        let mouthWidth = abs(left.x - right.x)

        let mar = mouthHeight / mouthWidth

        return mar > mouthOpenThreshold
    }

    private func detectBlink(landmarks: VNFaceLandmarks2D) -> Bool {
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return false }

        guard leftEye.normalizedPoints.count >= 6,
              rightEye.normalizedPoints.count >= 6 else { return false }

        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints

        let leftEyeHeight = abs(leftEyePoints[1].y - leftEyePoints[5].y)
        let leftEyeWidth = abs(leftEyePoints[0].x - leftEyePoints[3].x)

        let rightEyeHeight = abs(rightEyePoints[1].y - rightEyePoints[5].y)
        let rightEyeWidth = abs(rightEyePoints[0].x - rightEyePoints[3].x)

        let leftEAR = leftEyeHeight / leftEyeWidth
        let rightEAR = rightEyeHeight / rightEyeWidth

        let ear = (leftEAR + rightEAR) / 2

        return ear < eyeBlinkThreshold
    }

    private func detectHeadNod(landmarks: VNFaceLandmarks2D) -> Bool {
        guard let nose = landmarks.nose else { return false }

        guard nose.normalizedPoints.count > 0 else { return false }

        let nosePoint = nose.normalizedPoints[0]

        if isFirstFaceDetection {
            previousNoseY = nosePoint.y
            isFirstFaceDetection = false
            return false
        }

        let noseDelta = nosePoint.y - previousNoseY
        previousNoseY = nosePoint.y

        return noseDelta > headNodThreshold
    }
}

extension ViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pageImageView
    }
}