//
//  SummaryCell.swift
//  Shortcap
//
//  Created by choijunios on 11/14/24.
//

import UIKit

import Entity
import DSKit
import CommonUI

import RxSwift
import RxCocoa
import SimpleImageProvider

class SummaryCell: UITableViewCell {
    
    static let identifier = String(describing: SummaryCell.self)
    
    // View
    private let cellContentView = SummaryCellContentView()
    private let loadingIndicatorView: CAPLoadingIndicatorView = .init()
    
    // Observable
    var viewModel: SummaryCellVMable?
    var disposables: [Disposable] = []
    
    private let cellIsAppearedPublisher: PublishSubject<Void> = .init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setAppearance()
        setLayout()
        setObservable()
    }
    required init?(coder: NSCoder) { return nil }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        viewModel = nil
        disposables.forEach { disposable in
            disposable.dispose()
        }
        disposables.removeAll()
        
        // UI관련
        cellContentView.prepareForeReuse()
        loadingIndicatorView.turnOn(withAnimation: false)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.frame = contentView.frame.inset(by: .init(top: 0, left: 20, bottom: 14, right: 20))
    }
    
    func cellIsAppeared() {
    
        cellIsAppearedPublisher.onNext(())
    }
    
    private func setAppearance() { }
    
    private func setLayout() {
        
        // MARK: contentView
        [
            cellContentView,
            loadingIndicatorView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            cellContentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cellContentView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            cellContentView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            cellContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            loadingIndicatorView.topAnchor.constraint(equalTo: contentView.topAnchor),
            loadingIndicatorView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            loadingIndicatorView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            loadingIndicatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    private func setObservable() {
        // 내부 옵저버블
    }
    
    func bind(viewModel: SummaryCellVMable) {
        
        self.viewModel = viewModel
        
        
        let bindingDisposable = viewModel
            .summaryDetail
            .map { [weak self] detail in
                
                guard let self else { return }
                
                // 셀 썸네일
                
                if let rawCode = detail.rawVideoCode {
                    
                    let thumbNailUrl = "https://img.youtube.com/vi/\(rawCode)/mqdefault.jpg"
                    
                    cellContentView.videoImageView.simple
                        .setImage(
                            url: thumbNailUrl,
                            size: .init(width: 120, height: 160),
                            fadeOutDuration: 0.25
                        )
                }
                
                // 메인 타이틀 정보
                cellContentView.titleLabel.text = detail.title
                
                
                // 생성일시
                cellContentView.creationDateLabel.text = viewModel
                    .requestDateDiffText(date: detail.createdAt)
                
                
                // 카테고리 정보
                let categoryText = detail.mainCategory.twoLetterKorWordText
                let fullCategoryText = "\(categoryText) 카테고리에 숏폼을 저장했어요!"
                let catRange = NSRange(fullCategoryText.range(of: categoryText)!, in: fullCategoryText)
                cellContentView.categoryLabel.text = fullCategoryText
                let font = TypographyStyle.smallBold.typography.font
                
                cellContentView.categoryLabel.applyAttribute(
                    attributes: [
                        .foregroundColor : DSColors.secondary90.color,
                        .font : font
                    ],
                    range: catRange
                )
                
                // 로딩 스크린 종료, 셀이 클릭가능함
                loadingIndicatorView.turnOff()
            }
            .asObservable()
        
        
        let disposables: [Disposable?] = [
            
            // Output
            Observable
                .zip(bindingDisposable, cellIsAppearedPublisher)
                .withUnretained(self)
                .subscribe(onNext: { cell, _ in
                    
                    cell.cellContentView.titleLabel.startScrolling()
                }),
            
            // Input
            self.cellContentView
                .rx.tap
                .bind(to: viewModel.cellClicked)
        ]
        
        self.disposables = disposables.compactMap { $0 }
        
        // MARK: 디테일 정보 요청
        viewModel.requestDetail()
    }
}
