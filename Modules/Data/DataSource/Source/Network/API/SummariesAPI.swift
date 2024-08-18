//
//  SummariesAPI.swift
//  DataSource
//
//  Created by choijunios on 8/12/24.
//

import Foundation
import Moya
import Alamofire

/// AuthAPI
public enum SummariesAPI {
    
    case listAll
    case checkSummaryStatus(videoCode: String)
    case fetchSummaryDetail(videoId: Int)
}

extension SummariesAPI: BaseAPI {

    public var apiType: APIType { .summaries }
    
    public var method: Moya.Method {
        
        switch self {
        case .listAll:
            .get
        case .checkSummaryStatus:
            .get
        case .fetchSummaryDetail:
            .get
        }
    }
    
    public var path: String {
        switch self {
        case .listAll:
            "/list/all"
        case .checkSummaryStatus(let videoCode):
            "/status/\(videoCode)"
        case .fetchSummaryDetail(let videoId):
            "/\(videoId)"
        }
    }
    
    var bodyParameters: Parameters? {
        var params: Parameters = [:]
        switch self {
        default:
            params = [:]
        }
        return params
    }
    
    var parameterEncoding: ParameterEncoding {
        switch self {
        default:
            return JSONEncoding.default
        }
    }
    
    public var task: Task {
        switch self {
        default:
            .requestPlain
        }
    }
}
