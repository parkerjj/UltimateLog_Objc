//
//  ViewController.m
//  TestApp
//
//  Created by Peigen.Liu on 6/27/19.
//  Copyright © 2019 Peigen.Liu. All rights reserved.
//

#import "ViewController.h"
@import UltimateLog_ObjC;



@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [UltimateLog setupWithPrefix:@"StarStar" withConsoleFilter:ULogFilterLevelVerbose withLogFilter:ULogFilterLevelVerbose withEncryptSeed:@"TEST"];
    
    [UltimateLog vWithTag:@"TEST" withMessage:@"This is VERBOSE"];
    [UltimateLog dWithTag:@"TEST" withMessage:@"This is DEBUG"];
    [UltimateLog iWithTag:@"TEST" withMessage:@"This is INFO"];
    [UltimateLog wWithTag:@"TEST" withMessage:@"This is WARNING"];
    [UltimateLog eWithTag:@"TEST" withMessage:@"This is ERROR"];
    [UltimateLog fWithTag:@"TEST" withMessage:@"This is FATAL"];
    
    
    [UltimateLog vWithTag:@"TEST" withMessage:@"%@",@"Test123"];
    
    NSLog(@"ZipLog: %@", [UltimateLog zipLog]);
    
}


@end
