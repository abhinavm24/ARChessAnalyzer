//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#ifndef Header_h
#define Header_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImageConverter : NSObject
+(NSMutableArray< UIImage * > *)ConvertImage:(UIImage *)image;
+(UIImage *)DetectChessBoard:(UIImage *)image;
//+(void)setBounds:(int)x : (int)y : (int)width : (int)height;
+(bool)isBoard:(UIImage *)image;
@end

#endif /* Header_h */
