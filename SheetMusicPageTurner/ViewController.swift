import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let visionQueue = DispatchQueue(label: "visionQueue")
    private var captureLayer: AVCaptureVideoPreviewLayer?
    
    // 乐谱查看相关
    private var currentPage = 0
    private let totalPages = 10 // 模拟页数，实际应根据导入的乐谱文件确定
    
    // 动作识别相关
    private var isMouthOpenEnabled = true
    private var isHeadNodEnabled = true
    private var mouthOpenThreshold: CGFloat = 0.5
    private var headNodThreshold: CGFloat = 0.05
    
    // 防止重复触发
    private var lastActionTime = Date().timeIntervalSince1970
    private let actionCooldown = 1.0 // 1秒冷却时间
    
    // UI元素
    private let pageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // 页面指示器
        pageLabel.text = "第 \(currentPage + 1) 页，共 \(totalPages) 页"
        pageLabel.textAlignment = .center
        pageLabel.font = UIFont.systemFont(ofSize: 16)
        view.addSubview(pageLabel)
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // 动作按钮
        actionButton.setTitle("手动翻页", for: .normal)
        actionButton.addTarget(self, action: #selector(manualPageTurn), for: .touchUpInside)
        view.addSubview(actionButton)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: pageLabel.topAnchor, constant: -20)
        ])
        
        // 设置按钮
        settingsButton.setTitle("设置", for: .normal)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
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
        captureLayer?.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        captureLayer?.videoGravity = .resizeAspectFill
        captureLayer?.cornerRadius = 50
        captureLayer?.position = CGPoint(x: view.frame.width - 60, y: 60)
        if let layer = captureLayer {
            view.layer.addSublayer(layer)
        }
        
        session.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] req, err in
            self?.handleFace(request: req)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        
        try? handler.perform([request])
    }
    
    func handleFace(request: VNRequest) {
        guard let results = request.results as? [VNFaceObservation] else { return }
        
        for face in results {
            guard let landmarks = face.landmarks else { continue }
            
            if isMouthOpenEnabled {
                detectMouth(landmarks: landmarks)
            }
            
            if isHeadNodEnabled {
                detectHeadNod(face: face, landmarks: landmarks)
            }
        }
    }
    
    func detectMouth(landmarks: VNFaceLandmarks2D) {
        guard let outerLips = landmarks.outerLips else { return }
        
        let points = outerLips.normalizedPoints
        
        // 取上下嘴唇中点
        let top = points[3]
        let bottom = points[9]
        let left = points[0]
        let right = points[6]
        
        let mouthHeight = abs(top.y - bottom.y)
        let mouthWidth = abs(left.x - right.x)
        
        let mar = mouthHeight / mouthWidth
        
        if mar > mouthOpenThreshold {
            performPageTurn()
        }
    }
    
    func detectHeadNod(face: VNFaceObservation, landmarks: VNFaceLandmarks2D) {
        guard let nose = landmarks.nose, let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye else { return }
        
        let nosePoint = nose.normalizedPoints.first!
        let leftEyePoint = leftEye.normalizedPoints.first!
        let rightEyePoint = rightEye.normalizedPoints.first!
        
        let eyeCenterY = (leftEyePoint.y + rightEyePoint.y) / 2
        
        // 检测点头动作（鼻子相对于眼睛中心的垂直位置变化）
        let delta = nosePoint.y - eyeCenterY
        
        if delta > headNodThreshold {
            performPageTurn()
        }
    }
    
    private func performPageTurn() {
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastActionTime < actionCooldown {
            return
        }
        
        lastActionTime = currentTime
        
        DispatchQueue.main.async {
            self.currentPage = (self.currentPage + 1) % self.totalPages
            self.pageLabel.text = "第 \(self.currentPage + 1) 页，共 \(self.totalPages) 页"
            print("执行翻页操作，当前页: \(self.currentPage + 1)")
        }
    }
    
    @objc private func manualPageTurn() {
        currentPage = (currentPage + 1) % totalPages
        pageLabel.text = "第 \(currentPage + 1) 页，共 \(totalPages) 页"
        print("手动翻页，当前页: \(currentPage + 1)")
    }
    
    @objc private func openSettings() {
        // 这里可以实现设置界面，允许用户调整动作识别的灵敏度和类型
        print("打开设置界面")
    }
}
