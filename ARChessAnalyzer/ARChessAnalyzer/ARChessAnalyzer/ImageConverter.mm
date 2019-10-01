//
//  ImageConverter.cpp
//  OpenCVtest
//
//  Created by Anav Mehta on 5/19/19.
//  Copyright © 2019 Anav Mehta. All rights reserved.
//
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "OpenCV-Bridging-Header.h"

@implementation ImageConverter : NSObject

#define SQUARE_SIDE_LENGTH 227
#define BOUNDS 3000
std::vector<cv::Vec4i > hp, vp;
std::vector<cv::Point2f > intersectionsP;
int sqlen=SQUARE_SIDE_LENGTH;
int board_len=sqlen*8;
cv::Rect boundingRect;
cv::Mat overLayMat;
cv::Scalar overlayColor( 255, 0, 255 );
cv::Scalar boundingColor (0, 0, 255);
cv::Scalar gridColor(255, 0, 0);

double median( cv::Mat channel ) {
    double m = (channel.rows*channel.cols) / 2;
    int bin = 0;
    double med = -1.0;
    
    int histSize = 256;
    float range[] = { 0, 256 };
    const float* histRange = { range };
    bool uniform = true;
    bool accumulate = false;
    cv::Mat hist;
    cv::calcHist( &channel, 1, 0, cv::Mat(), hist, 1, &histSize, &histRange, uniform, accumulate );
    
    for ( int i = 0; i < histSize && med < 0.0; ++i ) {
        bin += cvRound( hist.at< float >( i ) );
        if ( bin > m && med < 0.0 )
            med = i;
    }
    
    return med;
}

cv::Mat auto_canny(cv::Mat image, float sigma=0.33) {
    
    // Canny edge detection with automatic thresholds.
    // compute the median of the single channel pixel intensities
    double v;
    v = median(image);
    
    // apply automatic Canny edge detection using the computed median
    int lower, upper;
    cv::Mat edged;
    lower = int(fmax(0, (1.0 - sigma) * v));
    upper = int(fmin(255, (1.0 + sigma) * v));
    //cv::Canny(image, edged, lower, upper, 3); 8/15
    cv::Canny(image, edged, lower, upper);

    
    // return the edged image
    return edged;
}


int numLines(std::vector<cv::Vec4i > lines) {
    int x0, y0, x1, y1;
    cv::Vec4i line;
    int num=0;
    for(int i=0;i<lines.size();i++) {
        line = lines[i];
        x0=line[0];
        y0=line[1];
        x1=line[2];
        y1=line[3];
        if(x0 > BOUNDS || y0 > BOUNDS || x1 > BOUNDS || y1 > BOUNDS || x0 < -BOUNDS || y0 < -BOUNDS || y1 < -BOUNDS || x1 < -BOUNDS) {
                         continue;
        }
        num++;
    }
    return(num);
}
void hor_vert_linesP(std::vector<cv::Vec4i > lines) {
    //A line is given by rho and theta. Given a list of lines, returns a list of
    //horizontal lines (theta=90 deg) and a list of vertical lines (theta=0 deg).
    int x0, y0, x1, y1;
    cv::Vec4i line;
    float slope;
    float factor=4.0;
    for(int i=0;i<lines.size();i++) {
        line = lines[i];
        x0=line[0];
        y0=line[1];
        x1=line[2];
        y1=line[3];
        if(x0 > BOUNDS || y0 > BOUNDS || x1 > BOUNDS || y1 > BOUNDS || x0 < -BOUNDS || y0 < -BOUNDS || y1 < -BOUNDS || x1 < -BOUNDS) {
            continue;
        }
        slope = (float) (y1-y0)/(float) (x1-x0);
        if(slope < 0.0625*factor && slope > -0.0625*factor) {
            hp.push_back(line);
        } else if (slope > 40.0/factor || slope < -40.0/factor) {
            vp.push_back(line);
        }

    }
}

// Finds the intersection of two lines, or returns false.
// The lines are defined by (o1, p1) and (o2, p2).

// Finds the intersection of two lines, or returns false.
// The lines are defined by (o1, p1) and (o2, p2).

void intersectionP(std::vector<cv::Vec4i > h, std::vector<cv::Vec4i > v) {
    cv::Point2f o2;
    cv::Point2f o1;
    cv::Point2f p1;
    cv::Point2f p2;
    cv::Point2f x;
    cv::Point2f d1;
    cv::Point2f d2;
    cv::Point2f r;
    float cross;
    double t1;
    for(int i=0;i<h.size();i++) {
        o1.x = h[i][0];
        o1.y = h[i][1];
        p1.x = h[i][2];
        p1.y = h[i][3];
        for(int j=0;j<v.size();j++) {
            o2.x = v[j][0];
            o2.y = v[j][1];
            p2.x = v[j][2];
            p2.y = v[j][3];
            
            x = o2 - o1;
            d1 = p1 - o1;
            d2 = p2 - o2;
    
            cross = d1.x*d2.y - d1.y*d2.x;
            if (abs(cross) > /*EPS*/1e-8) {
                t1 = (x.x * d2.y - x.y * d2.x)/cross;
                r = o1 + d1 * t1;
                if(r.x < -BOUNDS || r.x > BOUNDS || r.y > BOUNDS || r.y < -BOUNDS ){
                    continue;
                }
                if(((fmin(o1.x,p1.x) <= r.x <= fmax(o1.x,p1.x)) &&
                   (fmin(o1.y,p1.y) <= r.y <= fmax(o1.y,p1.y))) &&
                   ((fmin(o2.x,p2.x) <= r.x <= fmax(o2.x,p2.x)) &&
                    (fmin(o2.y,p2.y) <= r.y <= fmax(o2.y,p2.y)))) {
                       intersectionsP.push_back(r);
                   }
            }
        }
    }
}

cv::Mat four_point_transform(cv::Mat img, std::vector<cv::Point2f> corners, int fp=0) {
    cv::Mat newimg;
    std::vector<cv::Point2f> pts;
    cv::Size board_sz(board_len+2*fp,board_len+2*fp);
    pts.push_back(cv::Point2f(0,0));
    pts.push_back(cv::Point2f(0,board_len+2*fp));
    pts.push_back(cv::Point2f(board_len+2*fp,board_len+2*fp));
    pts.push_back(cv::Point2f(board_len+2*fp,0));

    
    cv::Mat M = cv::getPerspectiveTransform(corners, pts);
    cv::warpPerspective(img, newimg, M, board_sz);
    return newimg;
}



void showPoints(std::vector<cv::Point2f> intersections, cv::Mat mat) {
    for( size_t i = 0; i < intersections.size(); i++ ) {
        cv::Point2f pt = intersections[i];
        cv::circle(mat, pt, 5, overlayColor, -1);
    }
}
bool outOfBounds(int x, int y) {
    if(x > BOUNDS || y > BOUNDS || x < -BOUNDS || y < -BOUNDS) {return(true);}
    return(false);
}

void showLines(std::vector<cv::Vec4i> lines, cv::Mat mat) {
    for( size_t i = 0; i < lines.size(); i++ ) {
        cv::Vec4i l = lines[i];
        if(outOfBounds(l[0], l[1]) || outOfBounds(l[2],l[3])) {continue;}
        cv::line( mat, cv::Point(l[0], l[1]), cv::Point(l[2], l[3]), overlayColor, 3, cv::FILLED);
    }
}

void mergeRelatedLines(std::vector<cv::Vec4i> *lines) {
    std::vector<cv::Vec4i>::iterator current;
    for(current=lines->begin();current!=lines->end();current++) {
        if((*current)[0]==-4000 && (*current)[1]==-4000) continue;
        cv::Point pt1current, pt2current;
        pt1current.x = (*current)[0];
        pt1current.y = (*current)[1];
        pt2current.x = (*current)[2];
        pt2current.y = (*current)[3];
        std::vector<cv::Vec4i>::iterator    pos;
        for(pos=lines->begin();pos!=lines->end();pos++) {
            if(*current==*pos) continue;
            if(fabs((*pos)[0]-(*current)[0])<20 && fabs((*pos)[1]-(*current)[1])<20 && fabs((*pos)[2]-(*current)[2])<20 && fabs((*pos)[3]-(*current)[3])<20) {
                cv::Point pt1, pt2;
                pt1.x = (*pos)[0];
                pt1.y = (*pos)[1];
                pt2.x = (*pos)[2];
                pt2.y = (*pos)[3];
                if(((double)(pt1.x-pt1current.x)*(pt1.x-pt1current.x) + (pt1.y-pt1current.y)*(pt1.y-pt1current.y)<64*64) &&
                   ((double)(pt2.x-pt2current.x)*(pt2.x-pt2current.x) + (pt2.y-pt2current.y)*(pt2.y-pt2current.y)<64*64)) {
                    // Merge the two
                    (*current)[0] = ((*current)[0]+(*pos)[0])/2;
                    
                    (*current)[1] = ((*current)[1]+(*pos)[1])/2;
                    (*current)[2] = ((*current)[2]+(*pos)[2])/2;
                    
                    (*current)[3] = ((*current)[3]+(*pos)[3])/2;
                    
                    (*pos)[0]=-4000;
                    (*pos)[1]=-4000;
                    (*pos)[2]=-4000;
                    (*pos)[3]=-4000;
                }
            }
        }
    }
}



cv::Rect * DetectBoard(UIImage * image) {
    cv::Mat mat, gray, edges;
    UIImage * edgeIm, * grayIm;
    float maxx,minx,maxy,miny;
    std::vector<cv::Vec4i> linesP;
    overLayMat.release();
    minx=miny=INT_MAX;
    maxx=maxy=-INT_MAX;
    cv::Mat labels;
    int clusterCount = 32;

    UIImageToMat(image, mat);
    cv::cvtColor(mat, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(3,3),0);
    
    /*
    cv::bitwise_not(gray, gray);
    grayIm = MatToUIImage(gray);
    cv::Canny(gray, edges, 255*0.33, 255*0.66,3);*/
    edges = auto_canny(gray);
    edgeIm = MatToUIImage(edges);
    //cv::HoughLinesP(edges, linesP, 1, CV_PI/180,50,30,30);
    //cv::HoughLinesP(edges, linesP, 1, CV_PI/180,200,30,30);
    //cv::HoughLinesP(edges, linesP, 1, CV_PI/180,80,30,20);
    //cv::HoughLinesP(edges, linesP, 1, CV_PI/180,200); // 8/15
    cv::HoughLinesP(edges, linesP, 1, CV_PI/180,50,40,50);

    hp.clear();vp.clear();intersectionsP.clear();
    hor_vert_linesP(linesP);
    mergeRelatedLines(&hp);
    mergeRelatedLines(&vp);

    intersectionP(hp, vp);

    if(hp.size() < 9 || vp.size() < 9) return(nil);
    if (intersectionsP.size() < 32) return(nil);
    if(numLines(hp) < 9 || numLines(vp) < 9) return(nil);

    std::vector<cv::Point2f> centers;
    kmeans(intersectionsP, clusterCount, labels,
                                cv::TermCriteria(cv::TermCriteria::EPS+cv::TermCriteria::COUNT, 10, 1.0),
                                3, cv::KMEANS_PP_CENTERS, centers);

    for(int i=0;i<centers.size();i++){
        minx = fmin(minx, centers[i].x);
        maxx = fmax(maxx, centers[i].x);
        miny = fmin(miny, centers[i].y);
        maxy = fmax(maxy, centers[i].y);
    }
    float aspect_ratio = float((maxx-minx))/float((maxy-miny));
    printf("%f\n", aspect_ratio);
    if(aspect_ratio > 1.03 || aspect_ratio < 0.97) return (nil);
    showLines(hp, mat);
    showLines(vp, mat);
    showPoints(intersectionsP, mat);
    cv::rectangle(mat, cv::Point(minx,miny), cv::Point(maxx,maxy), overlayColor, 3,cv::FILLED, 0 );

    for (int i = 0; i < (int)centers.size(); ++i) {
        cv::Point2f c = centers[i];
        cv::circle(mat, c, 40, overlayColor, 1, cv::FILLED );
    }
    grayIm = MatToUIImage(mat);
    mat.copyTo(overLayMat);
    boundingRect = cv::Rect(minx, miny, maxx-minx, maxy-miny);
    return(&boundingRect);
}

+(UIImage *)DetectChessBoard:(UIImage *)image {
    cv::Mat mat;
    UIImage * tmp;
    UIImageToMat(image, mat);
    cv::Rect * rect = DetectBoard(image);
    if(rect == nil) return (nil);
    cv::rectangle(mat, cv::Point(rect->x,rect->y), cv::Point(rect->x+rect->width,rect->y+rect->height), boundingColor, 5,cv::FILLED, 0 );
    float yoff=rect->height/8.0;
    float xoff=rect->width/8.0;

    for(int i=0;i<8;i++) {
        cv::line(mat, cv::Point(rect->x,rect->y+i*yoff), cv::Point(rect->x+rect->width,rect->y+i*yoff), gridColor, 5, cv::FILLED);
        cv::line(mat, cv::Point(rect->x+i*xoff,rect->y), cv::Point(rect->x+i*xoff,rect->y+rect->height),gridColor, 5, cv::FILLED);
    }

    cv::circle(mat, cv::Point(rect->x,rect->y), 10, boundingColor, cv::FILLED);
    cv::circle(mat, cv::Point(rect->x+rect->width,rect->y), 10, boundingColor, cv::FILLED);
    cv::circle(mat, cv::Point(rect->x,rect->y+rect->height), 10, boundingColor, cv::FILLED);
    cv::circle(mat, cv::Point(rect->x+rect->width,rect->y+rect->height), 10, boundingColor, cv::FILLED);
    mat = mat + overLayMat;
    tmp = MatToUIImage(mat);
    return(tmp);

}



+(NSMutableArray< UIImage * > *)ConvertImageBounds:(UIImage *)image : (float) x : (float) y :  (float) width : (float) height{
    
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:64];

    return arr;
    
}

+(NSMutableArray< UIImage * > *)ConvertImage:(UIImage *)image{
    cv::Mat mat;
    UIImage * tmp;
    std::vector<cv::Point2f> corners, pts;
    cv::Mat newimg;
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:64];
    
    UIImageToMat(image, mat);
    int fp = 3;
    
    corners.push_back(cv::Point2f(boundingRect.x-fp, boundingRect.y-fp));
    corners.push_back(cv::Point2f(boundingRect.x-fp, boundingRect.y+boundingRect.height+fp));
    corners.push_back(cv::Point2f(boundingRect.x+boundingRect.width+fp, boundingRect.y+boundingRect.height+fp));
    corners.push_back(cv::Point2f(boundingRect.x+boundingRect.width+fp, boundingRect.y-fp));

    newimg = four_point_transform(mat, corners, fp);
    tmp = MatToUIImage(newimg);
    cv::Mat box;
    
    for(int i=0;i<8;i++){
        for(int j=0;j<8;j++){
            box = newimg(cv::Rect(j*sqlen,i*sqlen,sqlen+2*fp,sqlen+2*fp));
            tmp = MatToUIImage(box);
            [arr addObject:tmp];
        }
    }
    return arr;
    
}


@end
