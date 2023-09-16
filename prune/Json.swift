//
//  Json.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

class Json: NSObject, URLSessionDelegate {
        
    func getRecord(theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {

        
        let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""
        var authType        = "Bearer"
        
        switch theEndpoint {
        case "computer-prestages":
            existingDestUrl = "\(theServer)/api/v2/\(theEndpoint)"
            existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v2", with: "/api/v2")
//            authType = "Bearer"
        default:
            existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            if JamfProServer.authType["source"] == "Basic" {
                authType = "Basic"
            }
        }
        
        WriteToLog().message(theString: "[Json.getRecord] get existing endpoints URL: \(existingDestUrl)")
        let destEncodedURL = URL(string: existingDestUrl)
        let jsonRequest    = NSMutableURLRequest(url: destEncodedURL! as URL)
        
        let semaphore = DispatchSemaphore(value: 0)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            jsonRequest.httpMethod = "GET"
            let destConf = URLSessionConfiguration.default
//            switch authType {
//            case "Basic":
//                destConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType["source"] ?? "") \(JamfProServer.authCreds["source"] ?? "")", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
//            default:
                destConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType["source"] ?? "") \(JamfProServer.authCreds["source"] ?? "")", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
//            }
            
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                destSession.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Json.getRecord] httpResponse: \(String(describing: httpResponse))")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String:AnyObject] {
//                                WriteToLog().message(theString: "[Json.getRecord] returned JSON: \(endpointJSON)")
                                completion(endpointJSON)
                            } else {
                                WriteToLog().message(theString: "[Json.getRecord] error parsing JSON for \(existingDestUrl)")
                                if let _ = String(data: data!, encoding: .utf8) {
                                    let responseData = String(data: data!, encoding: .utf8)!
                                    WriteToLog().message(theString: "[Json.getRecord] full response from GET:\n\(responseData)")
            //                        print("create data response: \(responseData)")
                                } else {
                                    WriteToLog().message(theString: "[Json.getRecord] No data was returned from post/put")
                                }
                                completion([:])
                            }
                        }
                    } else {
                        WriteToLog().message(theString: "[Json.getRecord] error during GET, HTTP Status Code: \(httpResponse.statusCode)\n")
                        if "\(httpResponse.statusCode)" == "401" {
                            Alert().display(header: "Alert", message: "Verify username and password.")
                        }
                        completion([:])
                    }
                } else {
                    WriteToLog().message(theString: "[Json.getRecord] no response for \(existingDestUrl)")
                    completion([:])
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
        }   // getRecordQ - end
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

