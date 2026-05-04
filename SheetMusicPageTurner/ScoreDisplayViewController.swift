import UIKit

class ScoreDisplayViewController: UIViewController {

    private let score: ScoreManager.Score
    private var currentPage = 0
    private let scrollView = UIScrollView()
    private let pageImageView = UIImageView()
    private let pageLabel = UILabel()
    private let pageControl = UIPageControl()

    init(score: ScoreManager.Score) {
        self.score = score
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayPage(currentPage)
    }

    private func setupUI() {
        title = score.name
        view.backgroundColor = .systemBackground

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(gestureRecognizer)

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        pageImageView.contentMode = .scaleAspectFit
        scrollView.addSubview(pageImageView)

        pageLabel.textAlignment = .center
        pageLabel.font = UIFont.systemFont(ofSize: 16)
        view.addSubview(pageLabel)

        pageControl.numberOfPages = score.pages.count
        pageControl.currentPage = 0
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        view.addSubview(pageControl)

        setupConstraints()
    }

    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        pageImageView.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false

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

            pageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            pageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func displayPage(_ page: Int) {
        guard page >= 0 && page < score.pages.count else { return }
        currentPage = page
        pageImageView.image = score.pages[page]
        pageLabel.text = "第 \(page + 1) 页，共 \(score.pages.count) 页"
        pageControl.currentPage = page
        scrollView.setZoomScale(1.0, animated: false)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let screenWidth = view.bounds.width

        if location.x < screenWidth / 3 {
            previousPage()
        } else if location.x > screenWidth * 2 / 3 {
            nextPage()
        }
    }

    @objc private func pageControlChanged() {
        displayPage(pageControl.currentPage)
    }

    private func nextPage() {
        guard currentPage < score.pages.count - 1 else { return }
        displayPage(currentPage + 1)
    }

    private func previousPage() {
        guard currentPage > 0 else { return }
        displayPage(currentPage - 1)
    }
}

extension ScoreDisplayViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return pageImageView
    }
}