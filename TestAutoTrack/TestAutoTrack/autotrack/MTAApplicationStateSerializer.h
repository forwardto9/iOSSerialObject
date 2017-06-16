//
//  MTAApplicationStateSerializer.h
//  SensorsAnalyticsSDK
//
//	Created by tyzual on 9/3/2017
//	Copyright (c) 2017 Tencent. All rights reserved.
//
//  Created by 雨晗 on 1/18/16.
//  Copyright (c) 2016年 SensorsData. All rights reserved.
//
/// Copyright (c) 2014 Mixpanel. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MTAObjectSerializerConfig;
@class MTAObjectIdentityProvider;

@interface MTAApplicationStateSerializer : NSObject

- (instancetype)initWithApplication:(UIApplication *)application
					  configuration:(MTAObjectSerializerConfig *)configuration
			 objectIdentityProvider:(MTAObjectIdentityProvider *)objectIdentityProvider;

- (UIImage *)screenshotImageForWindow:(UIWindow *)window;

- (NSDictionary *)objectHierarchyForWindow:(UIWindow *)window;

- (NSDictionary *)objectHierarchyForVC:(UIResponder *)window;

@end
