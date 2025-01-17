//
//  ChoosePlatformPageCoordinator.swift
//  MainAppFeatures
//
//  Created by choijunios on 8/13/24.
//

import UIKit

import PresentationUtil
import RepositoryInterface
import Util

public class ChoosePlatformPageCoordinator: Coordinator {
    
    public let navigationController: UINavigationController
    
    
    public var children: [Coordinator] = []
    public weak var parent: (Coordinator)?
    public weak var finishDelegate: (CoordinatorFinishDelegate)?
    
    
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    
    public func start() {
        
        let viewModel = ChoosePlatformPageViewModel()
        viewModel.presentMainTabBar = { [weak self] in
            
            self?.presentMainTapBar()
        }
        
        let viewController = ChoosePlatformPageViewController()
        viewController.bind(viewModel: viewModel)
        
        navigationController.pushViewController(
            viewController,
            animated: true
        )
    }
    
    public func presentMainTapBar() {
        
        let coordinator = MainScreenCoordinator(
            navigationController: navigationController
        )
        
        addChild(coordinator)
        coordinator.start()
    }
}
