//
//  OpenCVUtils.m
//  ScrabbleSolver
//
//  Created by Taylor Schmidt on 9/13/20.
//  Copyright © 2020 Taylor Schmidt. All rights reserved.
//

#import "OpenCVWrapper.h"
#include <stdio.h>
#include <stdlib.h>
#include "opencv2/imgproc/imgproc.hpp"

using namespace std;

RNG rng(12345);
typedef cv::Point3_<uint8_t> Pixel;



@interface UIImage (fixOrientation)

- (UIImage *)normalizedImage;

@end

@implementation UIImage (fixOrientation)

- (UIImage *)normalizedImage {
    if (self.imageOrientation == UIImageOrientationUp) return self;

    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    [self drawInRect:(CGRect){0, 0, self.size}];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}
@end

@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (int)openCVNumber {
    return ColorConversionCodes::COLOR_RGB2GRAY;
}

+ (UIImage *)addRectangles:(UIImage *)image
               withTopLeft:(CGPoint)topLeft
              withTopRight:(CGPoint)topRight
            withBottomLeft:(CGPoint)bottomLeft
           withBottomRight:(CGPoint)bottomRight {
    if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationRight) {
        image = [image normalizedImage];
    }
    
    Mat mat;
    UIImageToMat(image, mat);
    cv::Size matSize = mat.size();
//    int size = 24;
//    vector<cv::Rect> rects = {
//        cv::Rect(topLeft.x, matSize.height - topLeft.y, size, size),
//        cv::Rect(topRight.x, matSize.height - topRight.y, size, size),
//        cv::Rect(bottomLeft.x, matSize.height - bottomLeft.y, size, size),
//        cv::Rect(bottomRight.x, matSize.height - bottomRight.y, size, size),
//    };
//    for (cv::Rect r : rects) {
//        cv::rectangle(mat, r, cv::Scalar(0,0,0), -1);
//    }
//    Mat output = mat;
    
    
    
    Mat output(1200, 1200, mat.type());
    std::vector<cv::Point2f> points = {
        cv::Point2f(topLeft.x, matSize.height - topLeft.y),
        cv::Point2f(topRight.x, matSize.height - topRight.y),
        cv::Point2f(bottomLeft.x, matSize.height - bottomLeft.y),
        cv::Point2f(bottomRight.x, matSize.height - bottomRight.y),
    };

    std::vector<cv::Point2f> outputPoints = {
        cv::Point2f(CGFloat(0), CGFloat(0)),
        cv::Point2f(CGFloat(output.cols - 1), CGFloat(0)),
        cv::Point2f(CGFloat(0), CGFloat(output.rows - 1)),
        cv::Point2f(CGFloat(output.cols - 1), CGFloat(output.rows - 1)),
    };

    Mat transform = getPerspectiveTransform(points, outputPoints);
    warpPerspective(mat, output, transform, output.size());

    UIImage *resultImage = MatToUIImage(output);
    return resultImage;
}

+ (UIImage *)processImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationRight) {
        image = [image normalizedImage];
    }
    Mat inputMat;
    UIImageToMat(image, inputMat);
    
    // Grayscale
//    std::cout << "Gray!" << std::endl;
    Mat gray;
    cvtColor(inputMat, gray, ColorConversionCodes::COLOR_RGB2GRAY);
    UIImage *result = MatToUIImage(gray);
    return result;

    
//    cv::Size patternsize(7, 7);
//    vector<Point2f> corners;
//    findChessboardCorners(gray, patternsize, corners);
//    bool patternfound = findChessboardCorners(
//        gray,
//        patternsize,
//        corners,
//        CALIB_CB_ADAPTIVE_THRESH + CALIB_CB_NORMALIZE_IMAGE + CALIB_CB_FAST_CHECK
//    );
//
//    if (patternfound) {
//        std::cout << "Pattern found!" << std::endl;
//        cornerSubPix(gray, corners, cv::Size(11, 11), cv::Size(-1, -1), TermCriteria(TermCriteria::EPS + TermCriteria::MAX_ITER, 30, 0.1));
//    } else {
//        std::cout << "NOT found!" << std::endl;
//    }
//
//    drawChessboardCorners(inputMat, patternsize, Mat(corners), patternfound);
    
    
//    Mat claheImg;
//    cv::Ptr<CLAHE> clahe = createCLAHE(4, cv::Size(8,8));
//    clahe->apply(gray, claheImg);
//
//    Mat gaussianBlurred;
//    GaussianBlur(claheImg, gaussianBlurred, cv::Size(3,3), 1);
//
//    Mat bilateralBlurred;
//    bilateralFilter(gaussianBlurred, bilateralBlurred, 64, 128, 32);
//    // Threshold
//    std::cout << "Thresh!" << std::endl;
//    Mat thresh;
//    threshold(bilateralBlurred, thresh, 127, 255, cv::THRESH_BINARY + cv::THRESH_OTSU);
//
//
//
//    std::cout << "Canny!" << std::endl;
//    Mat canny_output;
//    Canny(thresh, canny_output, 100, 100 * 2, 3);
//
//    // Contours
//    std::cout << "Contours!" << std::endl;
//    vector<vector<cv::Point>> contours;
//    vector<Vec4i> hierarchy;
////
//    findContours(canny_output, contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE, cv::Point(0,0));
//
//    std::cout << "Drawn!" << std::endl;
//    Mat drawnContours = Mat::zeros(canny_output.size(), CV_8UC3);
////    drawContours(drawnContours, contours, -1, Scalar(0,255,0));
//    for( int i = 0; i< contours.size(); i++ )
//    {
//        Scalar color = Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
//        drawContours( drawnContours, contours, i, color, 2, 8, hierarchy, 0, cv::Point() );
//    }

//    UIImage *result = MatToUIImage(inputMat);
//    return result;
}

@end

