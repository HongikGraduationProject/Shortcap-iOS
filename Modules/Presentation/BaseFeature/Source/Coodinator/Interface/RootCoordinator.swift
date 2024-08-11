//
//  RootCoordinator.swift
//  BaseFeature
//
//  Created by choijunios on 8/11/24.
//

import Foundation

public protocol RootCoordinator: Coordinator {
    // Flow
    func showMainTabBarFlow()
    
    // Screen
    func showCategorySelectionScreen()
    func showShortFormHuntingScreen()
}