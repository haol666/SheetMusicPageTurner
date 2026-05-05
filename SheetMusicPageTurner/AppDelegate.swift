import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if #available(iOS 13.0, *) {
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
            let tabBarController = createTabBarController()
            window?.rootViewController = tabBarController
            window?.makeKeyAndVisible()
        }

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if #available(iOS 13.0, *) {
            return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        } else {
            fatalError("Should not reach here on iOS 12")
        }
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    private func createTabBarController() -> UITabBarController {
        let tabBarController = UITabBarController()

        let scoreImportVC = ScoreImportViewController()
        let scoreImportNav = UINavigationController(rootViewController: scoreImportVC)
        scoreImportNav.tabBarItem = UITabBarItem(
            title: "琴谱",
            image: UIImage(systemName: "book"),
            selectedImage: UIImage(systemName: "book.fill")
        )

        let viewController = ViewController()
        let viewControllerNav = UINavigationController(rootViewController: viewController)
        viewControllerNav.tabBarItem = UITabBarItem(
            title: "翻页",
            image: UIImage(systemName: "camera"),
            selectedImage: UIImage(systemName: "camera.fill")
        )

        tabBarController.viewControllers = [scoreImportNav, viewControllerNav]

        return tabBarController
    }
}