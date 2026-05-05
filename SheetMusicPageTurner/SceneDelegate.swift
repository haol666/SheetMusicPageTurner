import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        let tabBarController = createTabBarController()

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
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