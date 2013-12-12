//
//  Timeline+Photo.m
//  Trovebox
//
//  Created by Patrick Santana on 22/03/12.
//  Copyright 2013 Trovebox
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "Timeline+Methods.h"

@implementation Timeline (Methods)

//
// Constast for Upload Status
//
NSString * const kUploadStatusTypeCreating = @"Creating";
NSString * const kUploadStatusTypeCreated = @"Created";
NSString * const kUploadStatusTypeFailed = @"Failed";
NSString * const kUploadStatusTypeUploaded = @"Uploaded";
NSString * const kUploadStatusTypeDuplicated = @"Duplicated";
NSString * const kUploadStatusTypeLimitReached = @"LimitReached";
NSString * const kUploadStatusTypeUploading = @"Uploading";
NSString * const kUploadStatusTypeUploadFinished =@"A_UploadFinished";

+ (NSArray *) getUploadsInManagedObjectContext:(NSManagedObjectContext *) context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error){
        NSLog(@"Error to get all uploads on managed object context = %@",[error localizedDescription]);
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (Timeline *model in matches) {
        [result addObject:model];
    }
    
    // return an array of Uploads
    return result;
}

+ (NSArray *) getUploadsNotUploadedInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    
    // status not Uploaded
    request.predicate= [NSPredicate predicateWithFormat:@"status != %@", kUploadStatusTypeUploaded];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error){
        NSLog(@"Error to get all uploads on managed object context = %@",[error localizedDescription]);
    }
    
    return matches;
}

+ (int) howEntitiesTimelineInManagedObjectContext:(NSManagedObjectContext *)context type:(NSString*) type
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    request.predicate= [NSPredicate predicateWithFormat:@"status == %@", type];
    [request setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error = nil;
    NSArray *result = [context executeFetchRequest:request error:&error];
    if (error){
        NSLog(@"Error to get how many uploading = %@",[error localizedDescription]);
    }
    
    return [result count];
}

+ (void) resetEntitiesOnStateUploadingInManagedObjectContext:(NSManagedObjectContext *)context{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    request.predicate= [NSPredicate predicateWithFormat:@"status == %@", kUploadStatusTypeUploading];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    if (error){
        NSLog(@"Error to get how many uploading = %@",[error localizedDescription]);
    }
    
    for (Timeline *model in matches) {
        model.status = kUploadStatusTypeCreated;
    }
}


+ (NSArray *) getNewestPhotosInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateUploaded" ascending:NO];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error){
        NSLog(@"Error to get all newest photos on managed object context = %@",[error localizedDescription]);
    }
    
    return matches;
}


+ (void) deleteAllTimelineInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Timeline" inManagedObjectContext:context]];
    [fetchRequest setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error = nil;
    NSArray *photos = [context executeFetchRequest:fetchRequest error:&error];
    if (error){
        NSLog(@"Error getting timeline to delete all from managed object context = %@",[error localizedDescription]);
    }
    
    for (NSManagedObject *photo in photos) {
        [context deleteObject:photo];
    }
    
    NSError *saveError = nil;
    if (![context save:&saveError]){
        NSLog(@"Error delete all newest photos from managed object context = %@",[saveError localizedDescription]);
    }
}

+ (void) insertIntoCoreData:(NSArray *) rawNewestPhotos InManagedObjectContext:(NSManagedObjectContext *)context
{
    if ([rawNewestPhotos count]>0){
        BOOL checkTotalRows = YES;
        for (NSDictionary *raw in rawNewestPhotos){
            // check if object exists
            if (checkTotalRows){
                if ([[raw objectForKey:@"totalRows"] intValue] == 0){
                    return;
                }else{
                    checkTotalRows  = NO;
                }
            }
            
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
            request.predicate= [NSPredicate predicateWithFormat:@"key==%@",[NSString stringWithFormat:@"%@",[raw objectForKey:@"id"]]];
            [request setIncludesPropertyValues:NO]; //only fetch the managedObjectID
            
            NSError *error = nil;
            NSArray *matches = [context executeFetchRequest:request error:&error];
            
            if (error){
                NSLog(@"Error getting a newest photo on managed object context = %@",[error localizedDescription]);
            }
            
            if (!matches || [matches count] > 0){
#ifdef DEVELOPMENT_ENABLED
                NSLog(@"Object already exist");
#endif
            }else {
                Timeline *photo = [NSEntityDescription insertNewObjectForEntityForName:@"Timeline"
                                                                inManagedObjectContext:context];
                
                // check if it is for iPad and get details URL
                if ([DisplayUtilities isIPad]){
                    // check if ipad is retina
                    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] == YES && [[UIScreen mainScreen] scale] == 2.00) {
                        photo.photoUrl =  [NSString stringWithFormat:@"%@",[raw objectForKey:@"path1510x984xCR"]];
                        photo.photoUrlDetail = [NSString stringWithFormat:@"%@",[raw objectForKey:@"path2024x1536"]];
                    }else{
                        photo.photoUrl =  [NSString stringWithFormat:@"%@",[raw objectForKey:@"path755x492xCR"]];
                        photo.photoUrlDetail = [NSString stringWithFormat:@"%@",[raw objectForKey:@"path1024x768"]];
                    }
                }else{
                    // iphone/ipod => check retina
                    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] == YES && [[UIScreen mainScreen] scale] == 2.00) {
                        photo.photoUrl =  [NSString stringWithFormat:@"%@",[raw objectForKey:@"path620x540xCR"]];
                        photo.photoUrlDetail = [NSString stringWithFormat:@"%@",[raw objectForKey:@"path1136x640"]];
                    }else{
                        // old models
                        photo.photoUrl =  [NSString stringWithFormat:@"%@",[raw objectForKey:@"path310x270xCR"]];
                        photo.photoUrlDetail = [NSString stringWithFormat:@"%@",[raw objectForKey:@"path480x320"]];
                    }
                }
                
                NSString *title = [raw objectForKey:@"title"];
                if ([title class] == [NSNull class] || [title isEqualToString:@""])
                    photo.title = [NSString stringWithFormat:@"%@",[raw objectForKey:@"filenameOriginal"]];
                else
                    photo.title = title;
                
                NSArray *tagsResult = [raw objectForKey:@"tags"];
                NSMutableString *tags = [NSMutableString string];
                if ([tagsResult class] != [NSNull class]) {
                    int i = 1;
                    for (NSString *tagDetails in tagsResult){
                        [tags appendString:[tagDetails stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                        if ( i < [tagsResult count])
                            [tags appendString:@", "];
                        
                        i++;
                    }}
                photo.tags=tags;
                
                photo.key=[NSString stringWithFormat:@"%@",[raw objectForKey:@"id"]];
                
                // get the date taken since 1970
                double d            = [[raw objectForKey:@"dateTaken"] doubleValue];
                NSTimeInterval date =  d;
                photo.date          = [NSDate dateWithTimeIntervalSince1970:date];
                
                // permission
                if ([[raw objectForKey:@"permission"] isEqualToString:@"1"])
                    photo.permission = [NSNumber numberWithBool:YES];
                else
                    photo.permission = [NSNumber numberWithBool:NO];
                
                // latitude
                // TODO: API does not return the number in float sometimes,
                // in this case the framework will convert the NSString to NSDecimal
                // https://github.com/photo/frontend/issues/1402
                NSString *latitude = [raw objectForKey:@"latitude"];
                if ([latitude class] != [NSNull class]){
                    if ( [latitude isKindOfClass: [NSString class]] && ![latitude isEqualToString:@""]) {
                        photo.latitude = latitude;
                    }else if ( [latitude isKindOfClass: [NSNumber class]] ) {
                        photo.latitude = [((NSNumber*)latitude) stringValue];
                    }
                }
                
                // longitude
                // TODO: API does not return the number in float sometimes,
                // in this case the framework will convert the NSString to NSDecimal
                // https://github.com/photo/frontend/issues/1402
                NSString *longitude = [raw objectForKey:@"longitude"];
                if ([longitude class] != [NSNull class]){
                    if ( [longitude isKindOfClass: [NSString class]] && ![longitude isEqualToString:@""]) {
                        photo.longitude = longitude;
                    }else if ( [longitude isKindOfClass: [NSNumber class]] ) {
                        photo.longitude = [((NSNumber*)longitude) stringValue];
                    }
                }
                
                // get the date since 1970
                double dUpload            = [[raw objectForKey:@"dateUploaded"] doubleValue];
                NSTimeInterval dateUpload =  dUpload;
                photo.dateUploaded       = [NSDate dateWithTimeIntervalSince1970:dateUpload];
                
                // page url
                photo.photoPageUrl =  [raw objectForKey:@"url"];
                
                // status
                photo.status = kUploadStatusTypeUploaded;
            }
        }
        
        // save context
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Couldn't save: %@", [error localizedDescription]);
        }
    }
}

+ (NSArray *) getNextWaitingToUploadInManagedObjectContext:(NSManagedObjectContext *)context qtd:(int) quantity
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    
    // status not Uploaded
    request.predicate= [NSPredicate predicateWithFormat:@"status == %@", kUploadStatusTypeCreated];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"dateUploaded" ascending:NO];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    // set max to return
    [request setFetchLimit:quantity];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (error){
        NSLog(@"Error to get all uploads on managed object context = %@",[error localizedDescription]);
    }
    
    return matches;
}

+ (void) deleteEntitiesInManagedObjectContext:(NSManagedObjectContext *)context state:(NSString*) state
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Timeline" inManagedObjectContext:context]];
    fetchRequest.predicate= [NSPredicate predicateWithFormat:@"status == %@", state];
    [fetchRequest setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error = nil;
    NSArray *photos = [context executeFetchRequest:fetchRequest error:&error];
    if (error){
        NSLog(@"Error getting timeline to delete all from managed object context = %@",[error localizedDescription]);
    }
    
    for (NSManagedObject *photo in photos) {
        [context deleteObject:photo];
    }
}

+ (void) setUploadsStatusToCreatedInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Timeline"];
    request.predicate= [NSPredicate predicateWithFormat:@"status == %@", kUploadStatusTypeCreating];
    
    NSError *error = nil;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    if (error){
        NSLog(@"Error to get how many uploading = %@",[error localizedDescription]);
    }
    
    for (Timeline *model in matches) {
        model.status = kUploadStatusTypeCreated;
    }
}

- (NSDictionary *) toDictionary
{
    NSArray *keys = [NSArray arrayWithObjects: @"date", @"facebook", @"permission", @"status", @"title", @"twitter", @"image", @"fileName",@"tags",@"albums", nil];
    NSArray *objects = [NSArray arrayWithObjects:self.date,self.facebook,self.permission,self.status,self.title,self.twitter,self.photoDataTempUrl,self.fileName,self.tags, self.albums, nil];
    
    return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

@end
