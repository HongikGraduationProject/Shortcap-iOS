//
//  SummariesVM.swift
//  MainAppFeatures
//
//  Created by choijunios on 8/22/24.
//

import UIKit

import Entity
import UseCase
import CommonUI
import Util


import RxCocoa
import RxSwift

protocol SummariesVMable {
    
    // Input
    var currentSelectedCategoryForFilter: PublishSubject<MainCategory> { get }
    
    
    // Output
    var alert: Driver<CapAlertVO> { get }
    var summaryItems: Driver<[SummaryItem]> { get }
    
    func createCellVM(videoId: Int) -> SummaryCellVM
}

/// 요약화면 전체를 담당하는 VM입니다.
class SummaryDetailPageViewModel: SummariesVMable {
    
    @Injected private var summaryUseCase: SummaryUseCase
    @Injected private var summaryDetailRepository: SummaryDetailRepository
    
    
    // Navigation
    var showSummaryDetailPage: ((Int) -> ())?
    
    
    private let requestAllSummaryItems: BehaviorSubject<Void> = .init(value: ())
    let currentSelectedCategoryForFilter: PublishSubject<MainCategory> = .init()
    
    // Output
    private(set) var summaryItems: Driver<[SummaryItem]> = .empty()
    var alert: Driver<CapAlertVO> = .empty()
    
    private let disposeBag = DisposeBag()
    
    init() {
        
        // MARK: 스트림 연결
        let summaryItemList = summaryUseCase
            .summariesStream

        
        // MARK: 필터적용
        self.summaryItems = Observable
            .combineLatest(summaryItemList, currentSelectedCategoryForFilter)
            .map { (items, category) in
                
                if category == .all {
                    
                    return items
                }
                
                return items.filter({ $0.mainCategory == category })
            }
            .asDriver(onErrorJustReturn: [])
        
        
        let requestAllSummaryItemsResult = requestAllSummaryItems
            .withUnretained(self)
            .flatMap { (vm, _) in
                vm.summaryUseCase
                    .requestFetchSummarriedItems()
            }
            .share()
        
        let initialRequestSuccess = requestAllSummaryItemsResult.compactMap { $0.value }
        let initialRequestFailure = requestAllSummaryItemsResult.compactMap { $0.error }
        
        
        // 앱이 다시 엑티비 되는 경우, 로컬에 저장된 요약목록을 확인합니다.
        // 최초 불러오기에 성공한 경우, 로컬에 저장된 요약목록을 확인합니다.
        
        let activeNotification = NotificationCenter.default.rx
            .notification(UIApplication.didBecomeActiveNotification)
            .map({ _ in })
            .asObservable()
        
        Observable
            .merge(initialRequestSuccess, activeNotification)
            .withUnretained(self)
            .subscribe { (vm, _) in
                
                vm.summaryUseCase
                    .requestCheckNewSummary()
            }
            .disposed(by: disposeBag)
        
        
        // MARK: Alert, 최초로 리스트를 불러오는 요청이 실패할 경우
        alert = initialRequestFailure
            .map { error in
                CapAlertVO(title: "요약 불러오기 오류", message: error.message,
                    info: [
                        "닫기": { exit(0) },
                        "재시도하기": { [weak self] in
                            self?.requestAllSummaryItems.onNext(())
                        }
                    ]
                )
            }
            .asDriver(onErrorDriveWith: .never())
    }

    func createCellVM(videoId: Int) -> SummaryCellVM {
        
        let cellVM = SummaryCellVM(videoId: videoId)
        
        if let presentDetail = showSummaryDetailPage {
            
            cellVM.presentDetailPage = presentDetail
        }
        
        return cellVM
    }
}