//
//  ScheduleTests.m
//  IQWidgets for iOS
//
//  Copyright 2011 EvolvIQ
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "TestUtil.h"
#import "IQWidgets.h"


@interface ScheduleTests : XCTestCase {
}
@end

@implementation ScheduleTests

- (void)testDateAssignment
{
    IQScheduleView* cv = [[IQScheduleView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    
    [cv setStartDate:D(@"2010-01-13 05:43") endDate:D(@"2010-01-15 05:43") animated:NO];
    XCTAssertEqual(cv.numberOfDays, 3, @"Incorrect number of days");
    XCTAssertEqualObjects(cv.startDate, D(@"2010-01-13 00:00"), @"Invalid start date");
    XCTAssertEqualObjects(cv.endDate, D(@"2010-01-15 00:00"), @"Invalid end date");
    
    cv = [[IQScheduleView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    
    [cv setStartDate:D(@"2010-01-13 05:43") endDate:D(@"2010-01-15 05:43") animated:NO];
    XCTAssertNotNil(cv.startDate, @"startDate is nil");
    XCTAssertNotNil(cv.endDate, @"endDate is nil");
}

- (void)testWeekAssignment
{
    IQScheduleView* cv = [[IQScheduleView alloc] initWithFrame:CGRectMake(0,0,0,0)];
    [cv.calendar setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"sv-SE"]];
    XCTAssertEqual(cv.calendar.firstWeekday, 2U, @"First weekday should be Monday");
    [cv setWeekWithDate:D(@"2011-02-16 23:59") workdays:NO animated:NO];
    XCTAssertEqual(cv.numberOfDays, 7, @"Should be a whole week");
    XCTAssertEqualObjects(cv.startDate, D(@"2011-02-14 00:00"), @"Invalid start date");
    XCTAssertEqualObjects(cv.endDate, D(@"2011-02-20 00:00"), @"Invalid end date");
    [cv.calendar setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en-US"]];
    XCTAssertEqual(cv.calendar.firstWeekday, 1U, @"First weekday should be Sunday");
    [cv setWeekWithDate:D(@"2011-02-16 23:59") workdays:NO animated:NO];
    XCTAssertEqual(cv.numberOfDays, 7, @"Should be a whole week");
    XCTAssertEqualObjects(cv.startDate, D(@"2011-02-13 00:00"), @"Invalid start date");
    XCTAssertEqualObjects(cv.endDate, D(@"2011-02-19 00:00"), @"Invalid end date");
    
    [cv setWeekWithDate:D(@"2011-02-16 23:59") workdays:YES animated:NO];
    XCTAssertEqual(cv.numberOfDays, 5, @"Should be a working week");
    XCTAssertEqualObjects(cv.startDate, D(@"2011-02-14 00:00"), @"Invalid start date");
    XCTAssertEqualObjects(cv.endDate, D(@"2011-02-18 00:00"), @"Invalid end date");
    
    NSLog(@"Dates: %@, %@", cv.startDate, cv.endDate);
    
}

@end
