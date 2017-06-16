//
//  MTAObjectSerializer.m
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

#import <objc/runtime.h>

#import "MTAClassDescription.h"
#import "MTAEnumDescription.h"
//#import "MTALogger.h"
#import "MTAObjectIdentityProvider.h"
#import "MTAObjectSerializer.h"
#import "MTAObjectSerializerConfig.h"
#import "MTAObjectSerializerContext.h"
#import "MTAPropertyDescription.h"
#import "NSInvocation+MTAHelpers.h"
#import "UIView+MTAHelpers.h"

@interface MTAObjectSerializer ()

@end

@implementation MTAObjectSerializer {
	MTAObjectSerializerConfig *_configuration;
	MTAObjectIdentityProvider *_objectIdentityProvider;
}

- (instancetype)initWithConfiguration:(MTAObjectSerializerConfig *)configuration
			   objectIdentityProvider:(MTAObjectIdentityProvider *)objectIdentityProvider {
	self = [super init];
	if (self) {
		_configuration = configuration;
		_objectIdentityProvider = objectIdentityProvider;
	}

	return self;
}

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject {
	NSParameterAssert(rootObject != nil);

	MTAObjectSerializerContext *context = [[MTAObjectSerializerContext alloc] initWithRootObject:rootObject];

	@try {
		while ([context hasUnvisitedObjects]) {
			[self visitObject:[context dequeueUnvisitedObject] withContext:context];
		}
	} @catch (NSException *e) {
		//		MTAError(@"Failed to serialize objects: %@", e);
	}

	return @{
		@"objects": [context allSerializedObjects],
		@"rootObject": [_objectIdentityProvider identifierForObject:rootObject]
	};
}

- (void)visitObject:(NSObject *)object withContext:(MTAObjectSerializerContext *)context {
	NSParameterAssert(object != nil);
	NSParameterAssert(context != nil);

	[context addVisitedObject:object];

	NSMutableDictionary *propertyValues = [[NSMutableDictionary alloc] init];

	MTAClassDescription *classDescription = [self classDescriptionForObject:object];
	if (classDescription) {
		for (MTAPropertyDescription *propertyDescription in [classDescription propertyDescriptions]) {
            NSLog(@"------name is %@", propertyDescription.name);
			if ([propertyDescription shouldReadPropertyValueForObject:object]) {
				id propertyValue = [self propertyValueForObject:object withPropertyDescription:propertyDescription context:context];
				propertyValues[propertyDescription.name] = propertyValue ?: [NSNull null];
			}
		}
	}

	NSMutableArray *delegateMethods = [NSMutableArray array];
	id delegate;
	SEL delegateSelector = NSSelectorFromString(@"delegate");
	if ([object respondsToSelector:delegateSelector]) {
		delegate = ((id(*)(id, SEL))[object methodForSelector:delegateSelector])(object, delegateSelector);
		if (classDescription && [[classDescription delegateInfos] count] > 0 && [object respondsToSelector:delegateSelector]) {
			for (MTADelegateInfo *delegateInfo in [classDescription delegateInfos]) {
				if ([delegate respondsToSelector:NSSelectorFromString(delegateInfo.selectorName)]) {
					[delegateMethods addObject:delegateInfo.selectorName];
				}
			}
		}
	}

	NSDictionary *serializedObject = @{
		@"id": [_objectIdentityProvider identifierForObject:object],
		@"class": [self classHierarchyArrayForObject:object],
		@"properties": propertyValues,
		@"delegate": @{
			@"class": delegate ? NSStringFromClass([delegate class]) : @"",
			@"selectors": delegateMethods
		}
	};

	[context addSerializedObject:serializedObject];
}

- (NSArray *)classHierarchyArrayForObject:(NSObject *)object {
	NSMutableArray *classHierarchy = [[NSMutableArray alloc] init];

	Class aClass = [object class];
	while (aClass) {
		[classHierarchy addObject:NSStringFromClass(aClass)];
		aClass = [aClass superclass];
	}

	return [classHierarchy copy];
}

- (NSArray *)allValuesForType:(NSString *)typeName {
	NSParameterAssert(typeName != nil);

	MTATypeDescription *typeDescription = [_configuration typeWithName:typeName];
	if ([typeDescription isKindOfClass:[MTAEnumDescription class]]) {
		MTAEnumDescription *enumDescription = (MTAEnumDescription *)typeDescription;
		return [enumDescription allValues];
	}

	return @[];
}

- (NSArray *)parameterVariationsForPropertySelector:(MTAPropertySelectorDescription *)selectorDescription {
	NSAssert([selectorDescription.parameters count] <= 1, @"Currently only support selectors that take 0 to 1 arguments.");

	NSMutableArray *variations = [[NSMutableArray alloc] init];

	// TODO: write an algorithm that generates all the variations of parameter combinations.
	if ([selectorDescription.parameters count] > 0) {
		MTAPropertySelectorParameterDescription *parameterDescription = (selectorDescription.parameters)[0];
		for (id value in [self allValuesForType:parameterDescription.type]) {
			[variations addObject:@[value]];
		}
	} else {
		// An empty array of parameters (for methods that have no parameters).
		[variations addObject:@[]];
	}

	return [variations copy];
}

- (id)instanceVariableValueForObject:(id)object
				 propertyDescription:(MTAPropertyDescription *)propertyDescription {
	NSParameterAssert(object != nil);
	NSParameterAssert(propertyDescription != nil);

	Ivar ivar = class_getInstanceVariable([object class], [propertyDescription.name UTF8String]);
	if (ivar) {
		const char *objCType = ivar_getTypeEncoding(ivar);

		ptrdiff_t ivarOffset = ivar_getOffset(ivar);
		const void *objectBaseAddress = (__bridge const void *)object;
		const void *ivarAddress = (((const uint8_t *)objectBaseAddress) + ivarOffset);

		switch (objCType[0]) {
			case _C_ID:
				return object_getIvar(object, ivar);
			case _C_CHR:
				return @(*((char *)ivarAddress));
			case _C_UCHR:
				return @(*((unsigned char *)ivarAddress));
			case _C_SHT:
				return @(*((short *)ivarAddress));
			case _C_USHT:
				return @(*((unsigned short *)ivarAddress));
			case _C_INT:
				return @(*((int *)ivarAddress));
			case _C_UINT:
				return @(*((unsigned int *)ivarAddress));
			case _C_LNG:
				return @(*((long *)ivarAddress));
			case _C_ULNG:
				return @(*((unsigned long *)ivarAddress));
			case _C_LNG_LNG:
				return @(*((long long *)ivarAddress));
			case _C_ULNG_LNG:
				return @(*((unsigned long long *)ivarAddress));
			case _C_FLT:
				return @(*((float *)ivarAddress));
			case _C_DBL:
				return @(*((double *)ivarAddress));
			case _C_BOOL:
				return @(*((_Bool *)ivarAddress));
			case _C_SEL:
				return NSStringFromSelector(*((SEL *)ivarAddress));
			default:
				NSAssert(NO, @"Currently unsupported return type!");
				break;
		}
	}

	return nil;
}

- (NSInvocation *)invocationForObject:(id)object
			  withSelectorDescription:(MTAPropertySelectorDescription *)selectorDescription {
	NSUInteger __unused parameterCount = [selectorDescription.parameters count];

	SEL aSelector = NSSelectorFromString(selectorDescription.selectorName);
	NSAssert(aSelector != nil, @"Expected non-nil selector!");

	NSMethodSignature *methodSignature = [object methodSignatureForSelector:aSelector];
	NSInvocation *invocation = nil;

	if (methodSignature) {
		NSAssert([methodSignature numberOfArguments] == (parameterCount + 2), @"Unexpected number of arguments!");

		invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		invocation.selector = aSelector;
	}
	return invocation;
}

- (id)propertyValue:(id)propertyValue
	propertyDescription:(MTAPropertyDescription *)propertyDescription
				context:(MTAObjectSerializerContext *)context {
	if (propertyValue != nil) {
		if ([context isVisitedObject:propertyValue]) {
			return [_objectIdentityProvider identifierForObject:propertyValue];
		} else if ([self isNestedObjectType:propertyDescription.type]) {
			[context enqueueUnvisitedObject:propertyValue];
			return [_objectIdentityProvider identifierForObject:propertyValue];
		} else if ([propertyValue isKindOfClass:[NSArray class]] || [propertyValue isKindOfClass:[NSSet class]]) {
			NSMutableArray *arrayOfIdentifiers = [[NSMutableArray alloc] init];
			for (id value in propertyValue) {
				if ([context isVisitedObject:value] == NO) {
					[context enqueueUnvisitedObject:value];
				}

				[arrayOfIdentifiers addObject:[_objectIdentityProvider identifierForObject:value]];
			}
			propertyValue = [arrayOfIdentifiers copy];
		}
	}

	return [propertyDescription.valueTransformer transformedValue:propertyValue];
}

- (id)propertyValueForObject:(NSObject *)object
	 withPropertyDescription:(MTAPropertyDescription *)propertyDescription
					 context:(MTAObjectSerializerContext *)context {
	NSMutableArray *values = [[NSMutableArray alloc] init];


	MTAPropertySelectorDescription *selectorDescription = propertyDescription.getSelectorDescription;

	if (propertyDescription.useKeyValueCoding) {
		// the "fast" (also also simple) path is to use KVC
		id valueForKey = [object valueForKey:selectorDescription.selectorName];

		id value = [self propertyValue:valueForKey
				   propertyDescription:propertyDescription
							   context:context];

		NSDictionary *valueDictionary = @{
			@"value": (value ?: [NSNull null])
		};

		[values addObject:valueDictionary];
	} else if (propertyDescription.useInstanceVariableAccess) {
		id valueForIvar = [self instanceVariableValueForObject:object propertyDescription:propertyDescription];

		id value = [self propertyValue:valueForIvar
				   propertyDescription:propertyDescription
							   context:context];

		NSDictionary *valueDictionary = @{
			@"value": (value ?: [NSNull null])
		};

		[values addObject:valueDictionary];
	} else {
		// the "slow" NSInvocation path. Required in order to invoke methods that take parameters.
		NSInvocation *invocation = [self invocationForObject:object withSelectorDescription:selectorDescription];
		if (invocation) {
			NSArray *parameterVariations = [self parameterVariationsForPropertySelector:selectorDescription];

			for (NSArray *parameters in parameterVariations) {
				[invocation mta_setArgumentsFromArray:parameters];
				[invocation invokeWithTarget:object];

				id returnValue = [invocation mta_returnValue];

				id value = [self propertyValue:returnValue
						   propertyDescription:propertyDescription
									   context:context];

				NSDictionary *valueDictionary = @{
					@"where": @{@"parameters": parameters},
					@"value": (value ?: [NSNull null])
				};

				[values addObject:valueDictionary];
			}
		}
	}


	return @{ @"values": values };
}

- (BOOL)isNestedObjectType:(NSString *)typeName {
	return [_configuration classWithName:typeName] != nil;
}

- (MTAClassDescription *)classDescriptionForObject:(NSObject *)object {
	NSParameterAssert(object != nil);

	Class aClass = [object class];
	while (aClass != nil) {
		MTAClassDescription *classDescription = [_configuration classWithName:NSStringFromClass(aClass)];
		if (classDescription) {
			return classDescription;
		}

		aClass = [aClass superclass];
	}

	return nil;
}

@end
