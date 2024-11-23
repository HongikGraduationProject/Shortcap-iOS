//
//  CategoryAdditionCO.swift
//  MainAppFeatures
//
//  Created by choijunios on 8/18/24.
//

import UIKit
import Entity
import PresentationUtil

public class CategoryAdditionPageCoordinator: Coordinator {
    
    public let navigationController: UINavigationController
    
    public var viewController: UIViewController?
    public var children: [Coordinator] = []
    public var parent: (Coordinator)?
    public var finishDelegate: (CoordinatorFinishDelegate)?
    
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    public func start() {
        let vc = CategoryAdditionVC()
        
        navigationController.pushViewController(vc, animated: false)
    }

}
