#ifndef CGVirtualDisplaySPI_h
#define CGVirtualDisplaySPI_h

// Private CoreGraphics SPI for creating virtual displays. There is no public
// header for these classes; CoreGraphics implements them at runtime and this
// file only declares the surface Skylight calls. Modeled on the interfaces
// DeskPad (github.com/Stengo/DeskPad) and BetterDisplay reverse-engineered
// for the same SPI. Do not add anything here beyond what VirtualDisplay/
// actually calls — this header, plus VirtualDisplayController.swift, is the
// one place CGVirtualDisplay usage is allowed (see SPEC.md Boundaries).

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class CGVirtualDisplayDescriptor;

@interface CGVirtualDisplayMode : NSObject

@property (readonly, nonatomic) CGFloat refreshRate;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;

- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height refreshRate:(CGFloat)refreshRate;

@end

@interface CGVirtualDisplaySettings : NSObject

@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;

- (instancetype)init;

@end

@interface CGVirtualDisplay : NSObject

@property (readonly, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (readonly, nonatomic) unsigned int hiDPI;
@property (readonly, nonatomic) CGDirectDisplayID displayID;
@property (readonly, nonatomic, nullable) id terminationHandler;
@property (readonly, nonatomic) dispatch_queue_t queue;
@property (readonly, nonatomic) unsigned int maxPixelsHigh;
@property (readonly, nonatomic) unsigned int maxPixelsWide;
@property (readonly, nonatomic) CGSize sizeInMillimeters;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) unsigned int serialNum;
@property (readonly, nonatomic) unsigned int productID;
@property (readonly, nonatomic) unsigned int vendorID;

- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;

@end

@interface CGVirtualDisplayDescriptor : NSObject

@property (retain, nonatomic) dispatch_queue_t queue;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int serialNum;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
@property (copy, nonatomic) void (^terminationHandler)(id, CGVirtualDisplay *);

- (instancetype)init;
- (nullable dispatch_queue_t)dispatchQueue;
- (void)setDispatchQueue:(dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END

#endif /* CGVirtualDisplaySPI_h */
