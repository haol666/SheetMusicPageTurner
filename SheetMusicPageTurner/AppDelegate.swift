import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        let tabBarController = createTabBarController()
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        return true
    }

    private func createTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()

        let scoreImportVC = ScoreImportViewController()
        let scoreImportNav = UINavigationController(rootViewController: scoreImportVC)

        if #available(iOS 13.0, *) {
            scoreImportNav.tabBarItem = UITabBarItem(
                title: "琴谱",
                image: UIImage(systemName: "book"),
                selectedImage: UIImage(systemName: "book.fill")
            )
        } else {
            scoreImportNav.tabBarItem = UITabBarItem(
                title: "琴谱",
                image: UIImage(named: "book"),
                selectedImage: UIImage(named: "book")
            )
        }

        let viewController = ViewController()
        let viewControllerNav = UINavigationController(rootViewController: viewController)

        if #available(iOS 13.0, *) {
            viewControllerNav.tabBarItem = UITabBarItem(
                title: "翻页",
                image: UIImage(systemName: "camera"),
                selectedImage: UIImage(systemName: "camera.fill")
            )
        } else {
            viewControllerNav.tabBarItem = UITabBarItem(
                title: "翻页",
                image: UIImage(named: "camera"),
                selectedImage: UIImage(named: "camera")
            )
        }

        tabBarController.viewControllers = [scoreImportNav, viewControllerNav]

        return tabBarController
    }
}