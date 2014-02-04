//
//  JobUploaderController.h
//  Trovebox
//
//  Created by Patrick Santana on 03/07/12.
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

#import "JobUploaderDelegate.h"
#import "WebService.h"
#import "NSDictionarySerializer.h"
#import "Timeline+Methods.h"
#import "Synced+Methods.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "AssetsLibraryUtilities.h"
#import <ImageIO/ImageIO.h>


@interface JobUploaderController : NSObject 

// get the instance
+ (JobUploaderController*) getController;

// methods
- (void) start;
- (void) stop;
- (BOOL) isRunning;

@end
