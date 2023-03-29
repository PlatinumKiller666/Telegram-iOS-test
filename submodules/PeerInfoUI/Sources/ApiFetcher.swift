//
//  ApiFetcher.swift
//  _idx_PeerInfoUI_238889D0_ios_min11.0
//
//  Created by Kirill Zolotarev on 29.03.2023.
//

import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

class DateUTC: Codable {
	var datetime: String
	var unixtime: Int

	enum CodingKeys: String, CodingKey {
		case datetime = "datetime"
		case unixtime = "unixtime"
	}
	
	static func getCurrentDate(/*complection: @escaping((_ date: DateUTC) -> Void)*/) -> Signal<DateUTC, MediaResourceDataFetchError>{
//		 let data = NSData(contentsOf: URL(string: "http://worldtimeapi.org/api/timezone/Europe/Moscow")!)
//		 let decoder = JSONDecoder()
//		 if let date = try? decoder.decode(DateUTC.self, from: data! as Data) {
//			 complection(date)
//		 }
		
		return fetchNetworkTime(url: "http://worldtimeapi.org/api/timezone/Europe/Moscow")
	}
	
	
	private static func fetchNetworkTime(url: String) -> Signal<DateUTC, MediaResourceDataFetchError> {
	 if let urlString = url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: urlString) {
		 let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
		 return Signal { subscriber in
//			 subscriber.putNext(.reset)
			 let disposable = signal.start(next: { next in
				 if let response = next as? MTHttpResponse {
					 
					 let data = response.data
					 let decoder = JSONDecoder()
					 if let date = try? decoder.decode(DateUTC.self, from: data! as Data) {
						 subscriber.putNext(date)
						 subscriber.putCompletion()
					 }
					 else {
							 subscriber.putError(.generic)
					 }
					 
				 } else {
					 subscriber.putError(.generic)
				 }
			 }, error: { _ in
				 subscriber.putError(.generic)
			 }, completed: {
			 })
			 
			 return ActionDisposable {
				 disposable?.dispose()
			 }
		 }
	 } else {
		 return .never()
	 }
 }
}
