//
//  SummaySearchCell.swift
//  Shortcap
//
//  Created by choijunios on 11/24/24.
//

import UIKit

import DSKit

class SummaySearchCell: UITableViewCell {
    
    static let identifier = String(describing: SummaySearchCell.self)
    
    private let titleLabel: CapLabel = {
        let label = CapLabel()
        label.typographyStyle = .baseRegular
        return label
    }()
    
    private let categoryLabel: CapLabel = {
        let label = CapLabel()
        label.typographyStyle = .smallRegular
        label.attrTextColor = DSColors.gray40.color
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
            
        setLayout()
    }
    required init?(coder: NSCoder) { nil }
    
    private func setLayout() {
        
        let labelStack = VStack([
            titleLabel,
            categoryLabel,
        ], spacing: 5, alignment: .leading)
        
        contentView.addSubview(labelStack)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
            
        
        NSLayoutConstraint.activate([
            
            labelStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            labelStack.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20),
            labelStack.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            labelStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    func bind(titleText: String, categoryText: String) {
        
        self.titleLabel.text = titleText
        self.categoryLabel.text = categoryText
    }
}
