//
//  PhotoAlbumViewController.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    var pin: Pin?
    var totalPhotoCount: Int = 0
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", argumentArray: [self.pin!]);
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBarHidden = false
        navigationItem.title = nil
        activityIndicator.stopAnimating()
        
        noImagesLabel.hidden = (pin!.photos.count > 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.addAnnotation(pin!)
        centerMapOnLocation(pin!.coordinate)
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
        
        fetchedResultsController.delegate = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadedAllPhotos:", name: FlickrClient.Constants.LoadedAllPhotosNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadedPhoto:", name: FlickrClient.Constants.LoadedNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    func centerMapOnLocation(coordinate: CLLocationCoordinate2D) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, 2000, 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func loadedPhoto(photo: Photo) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView.reloadData()
        }
    }
    
    func loadedAllPhotos(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {
            self.newCollectionButton.enabled = true
            self.activityIndicator.stopAnimating()
        }
    }
    
    @IBAction func grabNewCollection(sender: AnyObject) {
        activityIndicator.startAnimating()
        activityIndicator.hidden = false
        newCollectionButton.enabled = false
        noImagesLabel.hidden = false
        
        let photos = (pin?.photos)! as [Photo]
        FlickrClient.sharedInstance().deleteCollection(photos) { success, error in
            if success {
                FlickrClient.sharedInstance().fetchImageListFromFlickr(self.pin!, context: self.sharedContext) { photos, error in
                    self.totalPhotoCount = (photos as! [Photo]).count
                    self.noImagesLabel.hidden = true
                    for photo in (photos as? [Photo])! {
                        FlickrClient.sharedInstance().downloadImagesFromFlickr(photo, addInBackground: false) { image, error in
                            photo.image = image
                        }
                    }
                }
            }
        }
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
            switch type {
            case .Insert:
                insertedIndexPaths.append(newIndexPath!)
                break
            case .Delete:
                deletedIndexPaths.append(indexPath!)
                break
            case .Update:
                updatedIndexPaths.append(indexPath!)
                break
            default: ()
            }
            
            CoreDataStackManager.sharedInstance().saveContext()

    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                if (self.pin?.photos.count >= 1) {
                    self.collectionView.reloadData()
                } else {
                    self.collectionView.insertItemsAtIndexPaths([indexPath])
                }
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
        
        if (totalPhotoCount > 0 && pin?.photos.count == totalPhotoCount) {
            NSNotificationCenter.defaultCenter().postNotificationName(FlickrClient.Constants.LoadedAllPhotosNotification, object: nil)
        }
    }
}

extension PhotoAlbumViewController : UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            let layout = collectionViewLayout as? UICollectionViewFlowLayout
            layout!.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            layout!.minimumLineSpacing = 0
            layout!.minimumInteritemSpacing = 0
            
            let kWhateverHeightYouWant = floor(self.collectionView.frame.size.width/3)
            return CGSizeMake(kWhateverHeightYouWant, kWhateverHeightYouWant)
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![0]
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! PhotoCell
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        photo.delete()
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func configureCell(cell: PhotoCell, atIndexPath indexPath: NSIndexPath) {
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        var flickrImage = UIImage(named: "imagePlaceholder")
        cell.image!.image = nil
        
        if photo.imagePath == "" {
            flickrImage = UIImage(named: "noImage")
        } else if photo.image != nil {
            flickrImage = photo.image
        }
        
        cell.image!.image = flickrImage
    }
}