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
    
    @NSManaged var title: String
    @NSManaged var imagePath: String?
    @NSManaged var pin: Pin
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        title = (dictionary["title"] as? String)!
        imagePath = dictionary["imagePath"] as? String
    }
    
    var image: UIImage? {
        
        get {
            return FlickrClient.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        
        set {
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath!)
        }
    }
}