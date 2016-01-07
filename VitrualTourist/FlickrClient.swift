//
//  FlickrClient.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class FlickrClient: NSObject {
    
    var session: NSURLSession
    static let sharedInstance = FlickrClient()
    
    struct Constants {
        static let ApiKey = "REPLACE_THIS_WITH_YOUR_API_KEY"
        static let BaseUrl = "http://api.flickr.com/services/rest/"
        static let BaseUrlSSL = "https://api.flickr.com/services/rest/"
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
        static let LoadedNotification = "loadedPhoto"
        static let LoadedAllPhotosNotification = "loadedAllPhotos"
    }
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    
    // MARK: - All purpose task method for data
    
    func taskForResource(resource: String, parameters: [String : AnyObject], completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        var mutableParameters = parameters
        var mutableResource = resource
        
        // Add in the API Key
        mutableParameters["api_key"] = Constants.ApiKey
        mutableParameters["method"] = resource
        
        // Substitute the id parameter into the resource
        if resource.rangeOfString(":id") != nil {
            assert(parameters["id"] != nil)
            
            mutableResource = mutableResource.stringByReplacingOccurrencesOfString(":id", withString: "\(parameters["id"]!)")
            mutableParameters.removeValueForKey("id")
        }
        
        let urlString = Constants.BaseUrlSSL + FlickrClient.escapedParameters(mutableParameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                let newError = FlickrClient.errorForData(data, response: response, error: error)
                completionHandler(result: nil, error: newError)
            } else {
                FlickrClient.parseJSONWithCompletionHandler(data!, completionHandler: completionHandler)
            }
        }
        
        task.resume()
        
        return task
    }
    
    // MARK: - All purpose task method for images
    
    func taskForImage(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let url = NSURL(string: filePath)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                let newError = FlickrClient.errorForData(data, response: response, error: error)
                completionHandler(imageData: nil, error: newError)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }
    
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if data == nil {
            return error
        }
        
        do {
            let parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)
            
            if let parsedResult = parsedResult as? [String : AnyObject], errorMessage = parsedResult["status_message"] as? String {
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                return NSError(domain: "Flickr Error", code: 1, userInfo: userInfo)
            }
            
        } catch _ {}
        
        return error
    }
    
    func fetchImageListFromFlickr(pin: Pin, context: NSManagedObjectContext, completionHandler: (result: AnyObject!, error: NSError?) ->  Void) {
        let methodArguments = [
            "bbox": FlickrClient.sharedInstance.createBoundingBoxString(pin.latitude, longitude: pin.longitude),
            "safe_search": "1",
            "extras": "url_m",
            "format": "json",
            "nojsoncallback": "1",
            "per_page": "100"
        ]
        FlickrClient.sharedInstance.taskForResource("flickr.photos.search", parameters: methodArguments) { JSONResult, error in
            if let error = error {
                completionHandler(result: nil, error: error)
            } else {
                let totalPages = (JSONResult.objectForKey("photos")!["pages"] as? Int)!
                let pageLimit = min(totalPages, 40)
                let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                FlickrClient.sharedInstance.fetchImageListFromFlickrWithPage(pin, context: context, pageNumber: randomPage) { photos, error in
                    if let error = error {
                        completionHandler(result: nil, error: error)
                    } else {
                        completionHandler(result: photos, error: nil)
                    }
                }
            }
        }
    }
    
    func fetchImageListFromFlickrWithPage(pin: Pin, context: NSManagedObjectContext, pageNumber: Int, completionHandler: (result: AnyObject!, error: NSError?) ->  Void) {
        let methodArguments = [
            "bbox": FlickrClient.sharedInstance.createBoundingBoxString(pin.latitude, longitude: pin.longitude),
            "safe_search": "1",
            "extras": "url_m",
            "format": "json",
            "nojsoncallback": "1",
            "page": String(pageNumber)
        ]
        FlickrClient.sharedInstance.taskForResource("flickr.photos.search", parameters: methodArguments) { JSONResult, error in
            var photos: [Photo]?
            if let error = error {
                completionHandler(result: nil, error: error)
            } else {
                if let results = JSONResult.objectForKey("photos")!["photo"] as? [[String : AnyObject]] {
                    photos = Photo.photosFromResults(results, pin: pin, context: context)
                }
                completionHandler(result: photos, error: nil)
            }
        }
    }
    
    func downloadImagesFromFlickr(photo: Photo, addInBackground: Bool, completionHandler: (image: UIImage, error: NSError?) ->  Void) {
        FlickrClient.sharedInstance.taskForImage(photo.imagePath!) { data, error in
            if let error = error {
                print("Image download error: \(error.localizedDescription)")
            }
            
            if let data = data {
                if addInBackground {
                    photo.image = UIImage(data: data)
                }
                NSNotificationCenter.defaultCenter().postNotificationName(Constants.LoadedNotification, object: self)
                completionHandler(image: UIImage(data: data)!, error: nil)
            }
        }
    }
    
    func deleteCollection(photos: [Photo], completionHandler: (success: Bool, error: NSError?) ->  Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            for photo in photos {
                photo.delete()
            }
            completionHandler(success: true, error: nil)
        });
    }
    
    // Parsing the JSON
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error as NSError {
            parsingError = error
            parsedResult = nil
        }
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    // URL Encoding a dictionary into a parameter string
    
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            // make sure that it is a string value
            let stringValue = "\(value)"
            
            // Escape it
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            // Append it
            
            if let unwrappedEscapedValue = escapedValue {
                urlVars += [key + "=" + "\(unwrappedEscapedValue)"]
            } else {
                print("Warning: trouble excaping string \"\(stringValue)\"")
            }
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    func createBoundingBoxString(latitude: NSNumber, longitude: NSNumber) -> String {
        
        let latitude = latitude.doubleValue
        let longitude = longitude.doubleValue
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - Constants.BOUNDING_BOX_HALF_WIDTH, Constants.LON_MIN)
        let bottom_left_lat = max(latitude - Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LAT_MIN)
        let top_right_lon = min(longitude + Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LON_MAX)
        let top_right_lat = min(latitude + Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
}