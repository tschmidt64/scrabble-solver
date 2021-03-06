//
//  OpenCVUtils.h
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/13/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@interface OpenCVWrapper : NSObject

+ (NSString *)openCVVersionString;
+ (UIImage *)processImage:(UIImage *)image;
+ (UIImage *)addRectangles:(UIImage *)image
               withTopLeft:(CGPoint)topLeft
              withTopRight:(CGPoint)topRight
            withBottomLeft:(CGPoint)bottomLeft
           withBottomRight:(CGPoint)bottomRight;
+ (int)openCVNumber;

@end


NS_ASSUME_NONNULL_END
