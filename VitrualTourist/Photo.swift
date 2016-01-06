//
//  Photo.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import UIKit
import CoreData

class Photo : NSManagedObject {
    
    @NSManaged var id: Int64
    @NSManaged var title: String
    @NSManaged var imagePath: String?
    @NSManaged var filePath: String?
    @NSManaged var pin: Pin
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = Int64((dictionary["id"] as? String)!)!
        title = (dictionary["title"] as? String)!
        imagePath = dictionary["url_m"] as? String
        let pieces = (dictionary["url_m"] as! String).componentsSeparatedByString("/")
        let fileName = pieces[pieces.count-1] 
        filePath = fileName
    }
    
    var image: UIImage? {
        
        get {
            return FlickrClient.Caches.imageCache.imageWithIdentifier(filePath)
        }
        
        set {
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: filePath!)
        }
    }
    
    static func photosFromResults(results: [[String : AnyObject]], pin: Pin, context: NSManagedObjectContext) -> [Photo] {
        var photos = [Photo]()
        
        for result in results {
            let photo = Photo(dictionary: result, context: context)
            photo.pin = pin
            photos.append(photo)
        }
        
        return photos
    }
    
    func delete() {
        FlickrClient.Caches.imageCache.deleteImage(self.filePath!)
        managedObjectContext?.deleteObject(self)
        
        do {
            try managedObjectContext?.save()
        } catch {
            print("Error deleting \(error)")
        }
    }
}