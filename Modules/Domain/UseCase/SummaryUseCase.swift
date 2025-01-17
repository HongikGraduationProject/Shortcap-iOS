//
//  SummaryUseCase.swift
//  UseCase
//
//  Created by choijunios on 8/19/24.
//

import Foundation

import RepositoryInterface
import Entity
import Util

import RxSwift

public protocol SummaryUseCase: UseCaseBase {
    
    /// 전체 비디오 상세정보를 제공받을 수 있는 콜드 스트림입니다.
    var summariesStream: BehaviorSubject<[SummaryItem]> { get }
    
    
    /// 요약이 완료됬었던 비디오 리스트를 요청합니다.
    func requestFetchSummarriedItems() -> Single<Result<Void, SummariesError>>
    
    
    /// 새로운 요약사항이 있는지 확인할 것을 요청합니다.
    func requestCheckNewSummary() -> Observable<Result<Void, SummariesError>>
}

public class DefaultSummaryUseCase: SummaryUseCase {
    
    @Injected var summaryRequestRepository: SummaryRequestRepository
    @Injected var summarizedItemRepository: SummarizedItemRepository
    @Injected var summaryDetailRepository: SummaryDetailRepository
    @Injected var videoCodeRepository: VideoCodeRepository
    @Injected var requestCounter: RequestCountTracker
    
    /// 최신 요약상세정보를 재공하는 콜드스트림입니다.
    public let summariesStream: BehaviorSubject<[SummaryItem]> = .init(value: [])
    
    
    private var summariesList: [SummaryItem] = []
    private let summariesListManagementQueue: DispatchQueue = .init(
        label: "com.SummaryUseCase",
        attributes: .concurrent
    )
    
    
    private let disposeBag = DisposeBag()
    
    public init() { }
    
    public func requestFetchSummarriedItems() -> Single<Result<Void, SummariesError>> {
        
        let task = summarizedItemRepository
            .requestAllSummaryItems()
            .map { [weak self] items in
                
                guard let self else { return }
                
                printIfDebug("✅ 요약완료된 숏폼개수: \(items.count)")
                
                summariesList = items
                
                publishSummaryList()
                
                return ()
            }
        
        return convert(task: task)
    }
    
    public func requestCheckNewSummary() -> Observable<Result<Void, SummariesError>> {
        
        let videoCodes = videoCodeRepository.getVideoCodes()
        
        let observables = videoCodes.map { videoCode in
            
            trackSummaryStatus(videoCode: videoCode)
                .asObservable()
        }
        
        let resultPublisher = PublishSubject<Result<Void, SummariesError>>()
        
        let serialScheduler: SerialDispatchQueueScheduler = .init(
            internalSerialQueueName: "com.requestCheckNewSummary"
        )
        
        var responseCount = 0
        
        if videoCodes.isEmpty {
            
            return .just(.success(()))
        }
        
        Observable<Void>
            .merge(observables)
            .observe(on: serialScheduler)
            .subscribe(onNext: { _ in
                
                responseCount += 1
                
                if responseCount == videoCodes.count {
                    
                    // 요약 요청 수만큼 응답 도착
                    
                    resultPublisher.onNext(.success(()))
                    resultPublisher.onCompleted()
                }
                
            }, onError: { error in
                
                responseCount += 1
                
                // 요약 요청 실패 단, 스트림이 끊어지지 않음
                
                resultPublisher.onNext(.failure(error as! SummariesError))
            })
            .disposed(by: disposeBag)
        
        return resultPublisher
    }
    
    private func trackSummaryStatus(videoCode: String, delaySeconds: Double = 0.0) -> Single<Void> {
        
        // Publishers
        let summaryResultPublisher = PublishSubject<Void>()
        
        let requestCount = requestCounter
            .requestRequestCount(videoCode: videoCode)
            .asObservable()
        
        let requestFailureCount = requestCounter
            .requestFailureCount(videoCode: videoCode)
            .asObservable()
        
        let summaryStatus: Observable<Result<SummaryStatus, SummariesError>> = convert(
            task: summaryRequestRepository
                .checkSummaryState(videoCode: videoCode)
            )
            .asObservable()
            .share()
        
        let summaryStatusRequestSuccess = summaryStatus.compactMap { $0.value }
        let summaryStatusRequestFailure = summaryStatus.compactMap { $0.error }
        
        Observable
            .combineLatest(summaryStatusRequestFailure, requestFailureCount)
            .subscribe(onNext: { [weak self, summaryResultPublisher] error, fc in
                
                guard let self else { return }
                
                if fc >= 3 {
                    
                    // 3회이상 요청 실패시
                    summaryResultPublisher.onError(SummariesError.summaryRequestFailed)
                    
                    // 트레킹중이던 값 삭제
                    requestCounter.removeRequestCount(videoCode: videoCode)
                    requestCounter.removeFailureCount(videoCode: videoCode)
                    
                    return
                }
                
                // 실패 횟수 증가
                requestCounter.countUpFailureCount(videoCode: videoCode)
                
                
                // 지연 재귀요청
                trackSummaryStatus(videoCode: videoCode, delaySeconds: 1.5)
                    .asObservable()
                    .subscribe(summaryResultPublisher)
                    .disposed(by: disposeBag)
            })
            .disposed(by: disposeBag)
        
        Observable
            .zip(summaryStatusRequestSuccess, requestCount)
            .delay(
                .milliseconds(Int(delaySeconds * 1000.0)),
                scheduler: ConcurrentDispatchQueueScheduler(qos: .default)
            )
            .observe(on: SerialDispatchQueueScheduler.init(qos: .default))
            .subscribe(onNext: { [weak self, summaryResultPublisher] requestResult, rc in
                
                guard let self else { return }
                
                let videoId = requestResult.videoSummaryId
                
                switch requestResult.status {
                case .complete:
                    
                    printIfDebug("⬇️ #\(videoId) 요약요청 작업완료")
                    
                    // 비디오 코드 삭제요청
                    videoCodeRepository.removeVideoCode(videoCode)
                    
                    
                    // 트레킹중이던 값 삭제
                    requestCounter.removeRequestCount(videoCode: videoCode)
                    requestCounter.removeFailureCount(videoCode: videoCode)
                    
                    
                    // 요약이 완료된 숏폼으로 부터 디테일정보 추출후 전송
                    requestSubDetailOfVideo(videoId: videoId) { result in
                        
                        switch result {
                        case .success:
                            
                            // 요약 디테일 확인 성공 여부 전송
                            summaryResultPublisher.onNext(())
                            summaryResultPublisher.onCompleted()
                            
                        case .failure(let error):
                            
                            // 요약 디테일 확인 실패 여부 전송
                            summaryResultPublisher.onError(error)
                        }
                    }
                    
                    
                case .processing:
                    
                    requestCounter.countUpRequestCount(videoCode: videoCode)
                    
                    if rc >= 10 {
                        
                        // 트레킹중이던 값 삭제
                        requestCounter.removeRequestCount(videoCode: videoCode)
                        requestCounter.removeFailureCount(videoCode: videoCode)
                        
                        
                        // 20회이상인 경우 더이상 요청하지 않고 비디오코드를 삭제한다.
                        videoCodeRepository.removeVideoCode(videoCode)
                        
                        summaryResultPublisher.onError(SummariesError.summaryRequestFailed)
                        
                    } else {
                        
                        // 지연 재귀요청
                        trackSummaryStatus(videoCode: videoCode, delaySeconds: 1.5)
                            .asObservable()
                            .subscribe(summaryResultPublisher)
                            .disposed(by: disposeBag)
                    }
                }
            })
            .disposed(by: disposeBag)
        
        return summaryResultPublisher
            .asSingle()
    }
    
    private func requestSubDetailOfVideo(
        videoId: Int,
        onComplete: @escaping ((Result<Void, SummariesError>) -> ())
    ) {
        
        let detailRequestTask: Single<Result<SummaryDetail, SummariesError>> = convert(task: summaryDetailRepository.fetchSummaryDetail(videoId: videoId))
        
        detailRequestTask
            .subscribe(onSuccess: { [weak self] result in
                
                guard let self else { return }
                
                switch result {
                case .success(let detail):
                    
                    let item = SummaryItem(
                        title: detail.title,
                        mainCategory: detail.mainCategory,
                        createdAt: detail.createdAt,
                        videoSummaryId: videoId
                    )
                    
                    self.summariesListManagementQueue.async(flags: .barrier) { [weak self] in
                        guard let self else { return }
                        
                        summariesList.insert(item, at: 0)
                        
                        publishSummaryList()
                        
                        onComplete(.success(()))
                    }
                    
                case .failure:
                    
                    // 디테일 요청중 에러 발생
                    
                    onComplete(.failure(SummariesError.summaryDetailRequestFailed))
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func publishSummaryList() {
        let list = Set(summariesList)
        let unDuplicatedList = Array(list)
        
        summariesStream.onNext(unDuplicatedList)
    }
}
