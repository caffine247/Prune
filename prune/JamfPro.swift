//
//  JamfPro.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

class JamfPro: NSObject, URLSessionDelegate {
    
    var theUapiQ = OperationQueue() // create operation queue for API calls
        
    func jpapiAction(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
//            print("[jpapiAction] token check")
            if theResult == "success" {
                
                if method.lowercased() == "skip" {
                    completion(["JPAPI_result":"failed", "JPAPI_response":000])
                    return
                }
                
                URLCache.shared.removeAllCachedResponses()
                var path = ""
                
                switch endpoint {
                case  "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
                    path = "v1/\(endpoint)"
                default:
                    path = "v2/\(endpoint)"
                }
                
                var urlString = "\(serverUrl)/api/\(path)"
                urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
                if id != "" && id != "0" {
                    urlString = urlString + "/\(id)"
                }
                //        print("[Jpapi] urlString: \(urlString)")
                
                let url            = URL(string: "\(urlString)")
                let configuration  = URLSessionConfiguration.ephemeral
                var request        = URLRequest(url: url!)
                request.httpMethod = method.uppercased()
                
                if apiData.count > 0 {
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
                
                //        print("[Jpapi.action] Attempting \(method) on \(urlString).")
                
                configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    session.finishTasksAndInvalidate()
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String:Any] {
                                completion(endpointJSON)
                                return
                            } else {    // if let endpointJSON error
                                if httpResponse.statusCode == 204 && endpoint == "auth/invalidate-token" {
                                    completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                                } else {
                                    completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                                }
                                return
                            }
                        } else {    // if httpResponse.statusCode <200 or >299
                            completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                            return
                        }
                    } else {
                        completion([:])
                        return
                    }
                })
                task.resume()
            }
        }
    }
    
    func apiGetAll(serverUrl: String, endpoint: String, completion: @escaping (_ returnedJSON: (String,[[String: Any]])) -> Void) {
        getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
//            print("[jpapiAction] token check")
            if theResult == "success" {
                
//                if method.lowercased() == "skip" {
//                    completion([["JPAPI_result":"failed", "JPAPI_response":000]])
//                    return
//                }
                
                URLCache.shared.removeAllCachedResponses()
                var path = ""
                
                switch endpoint {
                case  "buildings":
                    path = "v1/\(endpoint)"
                default:
                    path = "v2/\(endpoint)"
                }
                
                var urlString = "\(serverUrl)/api/\(path)"
                urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
                
//                print("[Jpapi.apiGetAll] urlString: \(urlString)")
                
                let url            = URL(string: "\(urlString)")
                let configuration  = URLSessionConfiguration.ephemeral
                var request        = URLRequest(url: url!)
                
                request.httpMethod = "GET"
                
                //        print("[Jpapi.action] Attempting \(method) on \(urlString).")
                
                configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    session.finishTasksAndInvalidate()
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [[String:Any]] {
                                completion(("success", endpointJSON))
                                return
                            } else {
                                completion(("failed",[["JPAPI_response":httpResponse.statusCode]]))
                                return
                            }
                        } else {    // if httpResponse.statusCode <200 or >299
                            completion(("failed",[["JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString]]))
                            return
                        }
                    } else {
                        completion(("failed",[[:]]))
                        return
                    }
                })
                task.resume()
            }
        }
    }
    
        
    let userDefaults = UserDefaults.standard
    //    var tokenLife    = 30
    var components   = DateComponents()
    func getToken(serverUrl: String, whichServer: String = "source", base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {


//        WriteToLog().message(theString: "[getToken] token for \(whichServer) server: \(serverUrl)")
//        print("[getToken] JamfProServer.username[\(whichServer)]: \(String(describing: JamfProServer.username))")
//        print("[getToken] JamfProServer.password[\(whichServer)]: \(String(describing: JamfProServer.password?.prefix(1)))")
//        print("[getToken] JamfProServer.server[\(whichServer)]: \(String(describing: JamfProServer.source))")
//        print("[getToken] JamfProServer.server[\(whichServer)]: \(String(describing: JamfProServer.url))")
       
//        JamfProServer.url = serverUrl

        URLCache.shared.removeAllCachedResponses()

        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"

        var apiClient = ( userDefaults.integer(forKey: "\(whichServer)UseApiClient") == 1 ) ? true:false

        if apiClient {
            tokenUrlString = "\(serverUrl)/api/oauth/token"
        }

        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
        //        print("[getToken] tokenUrlString: \(tokenUrlString)")

        let tokenUrl       = URL(string: "\(tokenUrlString)")
        guard let _ = URL(string: "\(tokenUrlString)") else {
            print("problem constructing the URL from \(tokenUrlString)")
            WriteToLog().message(theString: "[getToken] problem constructing the URL from \(tokenUrlString)")
            completion((500, "failed"))
            return
        }
        //        print("[getToken] tokenUrl: \(tokenUrl!)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"

        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: JamfProServer.tokenCreated)

        //        print("[getToken] JamfProServer.validToken[\(whichServer)]: \(String(describing: JamfProServer.validToken))")
        //        print("[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
        //        print("[getToken] \(whichServer)  token exipres in: \((JamfProServer.authExpires)*60)")
        //        print("[getToken] JamfProServer.currentCred[\(whichServer)]: \(String(describing: JamfProServer.currentCred))")

        if !( JamfProServer.validToken && tokenAgeInSeconds < (JamfProServer.authExpires)*60 ) || (JamfProServer.currentCred != base64creds) {
            WriteToLog().message(theString: "[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
            WriteToLog().message(theString: "[getToken] Attempting to retrieve token from \(String(describing: tokenUrl))")
            
            if apiClient {
                let clientId = JamfProServer.username
                let secret   = JamfProServer.password
                let clientString = "grant_type=client_credentials&client_id=\(String(describing: clientId))&client_secret=\(String(describing: secret))"
        //                print("[getToken] \(whichServer) clientString: \(clientString)")

                let requestData = clientString.data(using: .utf8)
                request.httpBody = requestData
                configuration.httpAdditionalHeaders = ["Content-Type" : "application/x-www-form-urlencoded", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = clientString
            } else {
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = base64creds
            }
            
//            print("[getToken] \(whichServer) tokenUrlString: \(tokenUrlString)")
//            print("[getToken]    \(whichServer) base64creds: \(base64creds)")
            
            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                            if let endpointJSON = json as? [String: Any] {
                                JamfProServer.accessToken   = apiClient ? (endpointJSON["access_token"] as? String ?? "")!:(endpointJSON["token"] as? String ?? "")!
        //                                print("[getToken] \(whichServer) token: \(String(describing: JamfProServer.authCreds))")
                                JamfProServer.base64Creds = base64creds
                                if apiClient {
                                    JamfProServer.authExpires = 20 //(endpointJSON["expires_in"] as? String ?? "")!
                                } else {
                                    JamfProServer.authExpires = (endpointJSON["expires"] as? Double ?? 20)!
                                }
                                JamfProServer.tokenCreated = Date()
                                JamfProServer.validToken   = true
                                JamfProServer.authType     = "Bearer"
                                
                                //                      print("[JamfPro] result of token request: \(endpointJSON)")
                                WriteToLog().message(theString: "[getToken] new token created for \(serverUrl)")
                                
                                if JamfProServer.version == "" {
                                    // get Jamf Pro version - start
                                    jpapiAction(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.accessToken, method: "GET") {
                                        (result: [String:Any]) in
                                        let versionString = result["version"] as! String
                                        
                                        if versionString != "" {
                                            WriteToLog().message(theString: "[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
                                            JamfProServer.version = versionString
                                            let tmpArray = versionString.components(separatedBy: ".")
                                            if tmpArray.count > 2 {
                                                for i in 0...2 {
                                                    switch i {
                                                    case 0:
                                                        JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                                    case 1:
                                                        JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                                    case 2:
                                                        let tmp = tmpArray[i].components(separatedBy: "-")
                                                        JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                                        if tmp.count > 1 {
                                                            JamfProServer.build = tmp[1]
                                                        }
                                                    default:
                                                        break
                                                    }
                                                }
                                                if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                                    JamfProServer.authType = "Bearer"
                                                    WriteToLog().message(theString: "[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                                    
                                                } else {
                                                    JamfProServer.authType    = "Basic"
                                                    JamfProServer.accessToken = base64creds
                                                    WriteToLog().message(theString: "[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                                }
//                                                if JamfProServer.authType == "Bearer" {
        //                                                    WriteToLog().message(theString: "[JamfPro.getVersion] call token refresh process for \(serverUrl)")
//                                                }
                                                completion((200, "success"))
                                                return
                                            }
                                        }
                                    }
                                    // get Jamf Pro version - end
                                } else {
                                    completion((200, "success"))
                                    return
                                }
                            } else {    // if let endpointJSON error
                                WriteToLog().message(theString: "[getToken] JSON error.\n\(String(describing: json))")
                                JamfProServer.validToken  = false
                                completion((httpResponse.statusCode, "failed"))
                                return
                            }
                        } else {
                            // server down?
                            Alert().display(header: "", message: "Failed to get an expected response from \(String(describing: serverUrl)).")
                            WriteToLog().message(theString: "[TokenDelegate.getToken] Failed to get an expected response from \(String(describing: serverUrl)).  Status Code: \(httpResponse.statusCode)")
                            JamfProServer.validToken = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        Alert().display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)")
                        WriteToLog().message(theString: "[getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode)")
                        JamfProServer.validToken  = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    Alert().display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.")
                    WriteToLog().message(theString: "[getToken] token response error from \(serverUrl).  Verify url and port")
                    JamfProServer.validToken  = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
//            WriteToLog().message(theString: "[getToken] Use existing token from \(String(describing: tokenUrl))")
            completion((200, "success"))
            return
        }
    }
}
