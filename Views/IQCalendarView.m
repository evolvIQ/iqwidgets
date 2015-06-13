//
//  IQCalendarView.m
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

#import "IQCalendarView.h"
#import "IQCalendarHeaderView.h"
#import <QuartzCore/QuartzCore.h>

@interface IQCalendarArea : UIView {
    CGGradientRef gradient;
    CGColorRef lightBorder;
    CGColorRef darkBorder;
}
- (void)setTintColor:(UIColor*)tintColor;
@end

#define kCalendarStateCurrent 1
#define kCalendarStateSelected 2
#define kCalendarStateOutOfRange 4
#define kCalendarStateOutsideCurrentMonth 8
#define kCalendarStateSelectionStart 16
#define kCalendarStateSelectionEnd 32

@interface IQCalendarRow : UIView {
    UILabel* days[7];
    CGFloat dayContentSize;
    int state[7];
    UIColor* selectionColor;
    UIColor* currentDayColor;
}
- (void)setSelectionColor:(UIColor*)color;
- (void)setCurrentDayColor:(UIColor*)color;
@property (nonatomic, retain) UIColor* textColor;
@property (nonatomic, retain) UIColor* selectedTextColor;
- (void)setDayContentSize:(CGFloat)dayContentSize;
- (UIFont*)dayFont;
- (void)setDayFont:(UIFont*)dayFont;
- (void)setDays:(NSDate*)firstDay delta:(int)dayDelta calendar:(NSCalendar*)cal monthStart:(NSDate*)ms monthEnd:(NSDate*)me selStart:(NSDate*)selStart selEnd:(NSDate*)selEnd selDays:(NSSet*)days currentDay:(NSDate*)currentDay selectionMode:(IQCalendarSelectionMode)selectionMode formatter:(NSDateFormatter*)fmt;
@end

@interface IQCalendarView (PrivateMethods)
- (void)setupCalendarView;
- (void)redisplayDays;
@end

@implementation IQCalendarView
@synthesize tintColor, headerTextColor, selectionColor, currentDayColor, textColor, selectedTextColor;
@synthesize calendar, currentDay, dayContentSize, selectionMode, showCurrentDay;
@synthesize selectionStart, selectionEnd, selectedDays;
@synthesize contentDelegate;

#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupCalendarView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupCalendarView];
    }
    return self;
}

+ (Class) headerViewClass
{
    return [IQCalendarHeaderView class];
}

- (void) setupCalendarView
{
    CGRect r = self.bounds;
    showCurrentDay = YES;
    currentDay = [NSDate date];
    self.calendar = [NSCalendar currentCalendar];
    self.tintColor = [UIColor colorWithRed:204/255.0 green:204/255.0 blue:209/255.0 alpha:1];
    self.headerTextColor = [UIColor colorWithRed:.15 green:.1 blue:0 alpha:1];
    self.selectionColor = [UIColor colorWithRed:25/255.0 green:128/255.0 blue:229/255.0 alpha:1];
    self.currentDayColor = [UIColor colorWithRed:133/255.0 green:155/255.0 blue:180/255.0 alpha:1];
    header = (UIView*)[[[[self class] headerViewClass] alloc] initWithFrame:CGRectMake(0, 0, r.size.width, 44)];
    if([header respondsToSelector:@selector(setTintColor:)]) {
        [(id)header setTintColor:tintColor];
    }
    if([header respondsToSelector:@selector(setCornerCalendarUnits:)]) {
        [(id)header setCornerCalendarUnits:0];
    }
    if([header respondsToSelector:@selector(setTitleCalendarUnits:)]) {
        [(id)header setTitleCalendarUnits:NSMonthCalendarUnit|NSYearCalendarUnit];
    }
    if([header respondsToSelector:@selector(setItemCalendarUnits:)]) {
        [(id)header setItemCalendarUnits:NSWeekdayCalendarUnit];
    }
    if([header respondsToSelector:@selector(setDisplayArrows:)]) {
        [(id)header setDisplayArrows:YES];
    }
    if([header respondsToSelector:@selector(setDelegate:)]) {
        [(id)header setDelegate:self];
    }
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:header];
    CGFloat ht = r.size.height-44;
    calendarArea = [[IQCalendarArea alloc] initWithFrame:CGRectMake(0, 44, r.size.width, ht)];
    [self addSubview:calendarArea];
    [calendarArea setTintColor:tintColor];
    calendarArea.clipsToBounds = YES;
    calendarArea.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    for(int i=0; i<9; i++) {
        rows[i] = [[IQCalendarRow alloc] initWithFrame:CGRectMake(0, 44+ht/5.0*i, r.size.width, ht/5.0)];
        [rows[i] setSelectionColor:selectionColor];
        [rows[i] setCurrentDayColor:currentDayColor];
        [calendarArea addSubview:rows[i]];
    }
    dayFormatter = [[NSDateFormatter alloc] init];
    [dayFormatter setDateFormat:@"d"];
    [self displayDay:currentDay animated:NO];
    displayDate = nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect r = calendarArea.bounds;
    CGFloat ht = round(r.size.height/5.0);
    for(int i=0; i<9; i++) {
        rows[i].frame = CGRectMake(0, ht*i, r.size.width, ht);
    }
}

- (UIView*)headerView
{
    return header;
}

#pragma mark User interaction

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(touches.count == 1) {
        inDrag = YES;
        UITouch* touch = [[touches objectEnumerator] nextObject];
        dragStart = [touch locationInView:self];
        NSDate* d = [self dateFromPoint:dragStart];
        if(selectionMode == IQCalendarSelectionRangeEnd) {
            if(selectionStart == nil || [d compare:selectionStart] == NSOrderedAscending) {
                selectionStart = d;
            }
            selectionEnd = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        } else if(selectionMode == IQCalendarSelectionRangeStart) {
            if(selectionEnd == nil || [d compare:selectionEnd] == NSOrderedDescending) {
                selectionEnd = d;
            }
            selectionStart = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        } else if(selectionMode == IQCalendarSelectionMulti) {
            [self setSelected:![self isDaySelected:d] forDay:d];
        } else {
            selectionStart = d;
            selectionEnd = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
        [self redisplayDays];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    inDrag = NO;
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    inDrag = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(touches.count == 1 && inDrag) {
        NSDate* d = [self dateFromTouch:[[touches objectEnumerator] nextObject]];
        if(selectionMode == IQCalendarSelectionRange) {
            NSDate* d0 = [self dateFromPoint:dragStart];
            if([d compare:d0] == NSOrderedAscending) {
                selectionStart = d;
                selectionEnd = d0;
            } else {
                selectionStart = d0;
                selectionEnd = d;
            }
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        } else if(selectionMode == IQCalendarSelectionSingle) {
            selectionStart = d;
            selectionEnd = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        } else if(selectionMode == IQCalendarSelectionRangeEnd) {
            if([d compare:selectionStart] == NSOrderedAscending) {
                selectionStart = d;
            }
            selectionEnd = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        } else if(selectionMode == IQCalendarSelectionRangeStart) {
            if([d compare:selectionEnd] == NSOrderedDescending) {
                selectionEnd = d;
            }
            selectionStart = d;
            [self sendActionsForControlEvents:UIControlEventValueChanged];
        }
        [self redisplayDays];
    }
}

- (NSDate*)dateFromPoint:(CGPoint)pt
{
    CGRect r = calendarArea.frame;
    pt.x -= r.origin.x;
    pt.y -= r.origin.y;
    if(pt.y > 0) {
        int row = pt.y * 5.0 / calendarArea.bounds.size.height;
        int col = pt.x * 7.0 / calendarArea.bounds.size.width;
        if(row < 0 || row > 5 || col < 0 || col > 6) return nil;
        NSDateComponents* comp = [[NSDateComponents alloc] init];
        comp.day = col + 7*row;
        NSDate* date = [calendar dateByAddingComponents:comp toDate:self.firstDisplayedDay options:0];
        
        return date;
    }
    return nil;
}

- (NSDate*)dateFromTouch:(UITouch*)touch
{
    return [self dateFromPoint:[touch locationInView:self]];
}

#pragma mark Properties

- (void)setSelectionMode:(IQCalendarSelectionMode)newMode
{
    selectionMode = newMode;
    [self redisplayDays];
}

- (void)setSelectionColor:(UIColor *)sc
{
    for(int i=0; i<9; i++) {
        [rows[i] setSelectionColor:sc];
    }
    selectionColor = sc;
}

- (void)setTintColor:(UIColor *)tc
{
    if([header respondsToSelector:@selector(setTintColor:)]) {
        [(id)header setTintColor:tc];
    }
    [calendarArea setTintColor:tintColor];
    tintColor = tc;
    [calendarArea setNeedsDisplay];
}

- (void)setTextColor:(UIColor *)tc
{
    for(int i=0; i<9; i++) {
        [rows[i] setTextColor:tc];
    }
    textColor = tc;
    [self redisplayDays];
}

- (void)setSelectedTextColor:(UIColor *)tc
{
    for(int i=0; i<9; i++) {
        [rows[i] setSelectedTextColor:tc];
    }
    selectedTextColor = tc;
    [self redisplayDays];
}

- (void)setHeaderTextColor:(UIColor *)tc
{
    if([header respondsToSelector:@selector(setTextColor:)]) {
        [(id)header setTextColor:tc];
    }
    headerTextColor = tc;
}

- (void)setHeaderShadowOffset:(CGSize)offset
{
    if([header respondsToSelector:@selector(setShadowOffset:)]) {
        [(id)header setShadowOffset:offset];
    }
    headerShadowOffset = offset;
}

- (CGFloat)dayContentSize
{
    return dayContentSize;
}

- (void)setDayContentSize:(CGFloat)value
{
    dayContentSize = value;
    for(int i=0; i<9; i++) {
        [rows[i] setDayContentSize:value];
    }
}

- (UIFont*)dayFont
{
    return rows[0].dayFont;
}

- (void)setDayFont:(UIFont*)value
{
    for(int i=0; i<9; i++) {
        [rows[i] setDayFont:value];
    }
}

#pragma mark Header delegate

- (void) headerView:(UIView<IQCalendarHeader>*)view didReceiveInteraction:(IQCalendarHeaderViewUserInteraction)interaction
{
    if(interaction == IQCalendarHeaderViewUserInteractionNext) {
        [self displayNextMonth];
    } else if(interaction == IQCalendarHeaderViewUserInteractionPrev) {
        [self displayPreviousMonth];
    }
}

#pragma mark Date navigation
- (void)setCurrentDay:(NSDate*)date display:(BOOL)display animated:(BOOL)animated
{
    currentDay = date;
}

- (void)setCurrentDay:(NSDate *)date
{
    [self setCurrentDay:date display:YES animated:YES];
}

- (void)_redisplayDays
{
    if(needsDayRedisplay) {
        needsDayRedisplay = NO;
        if([contentDelegate respondsToSelector:@selector(calendarViewWillLayoutRows:)]) {
            [contentDelegate calendarViewWillLayoutRows:self];
        }
        for(int i=0; i<5; i++) {
            [rows[i] setDays:self.firstDisplayedDay delta:7*i calendar:calendar monthStart:self.firstDayInDisplayMonth monthEnd:self.lastDayInDisplayMonth selStart:selectionStart selEnd:selectionEnd  selDays:selectedDays currentDay:showCurrentDay?currentDay:nil selectionMode:selectionMode formatter:dayFormatter];
            CGRect b = rows[i].bounds;
            b.origin.y += dayContentSize;
            b.size.height -= dayContentSize;
            NSDateComponents* cmpnts = [[NSDateComponents alloc] init];
            cmpnts.day = 7*i;
            NSDate* first = [calendar dateByAddingComponents:cmpnts toDate:self.firstDisplayedDay options:0];
            cmpnts.day += 7;
            NSDate* last = [calendar dateByAddingComponents:cmpnts toDate:self.firstDisplayedDay options:0];
            [contentDelegate calendarView:self layoutRow:rows[i] startDate:first endDate:last contentRect:b];
        }
        if([contentDelegate respondsToSelector:@selector(calendarViewDidLayoutRows:)]) {
            [contentDelegate calendarViewDidLayoutRows:self];
        }
    }
}

- (void)redisplayDays
{
    if(!needsDayRedisplay) {
        needsDayRedisplay = YES;
        [self performSelectorOnMainThread:@selector(_redisplayDays) withObject:self waitUntilDone:NO];
    }
}

- (void)displayDay:(NSDate*)day animated:(BOOL)animated
{
    NSTimeInterval d = [self.firstDayInDisplayMonth timeIntervalSinceReferenceDate];
    BOOL firstSet = (displayDate == nil);
    displayDate = day;
    NSDate* monthStart = self.firstDayInDisplayMonth;
    NSTimeInterval dn = [monthStart timeIntervalSinceReferenceDate];
    // TODO: This logic needs to be improved to take into account months requiring six weeks!
    if(dn != d || firstSet) {
        if([header respondsToSelector:@selector(setItems:count:cornerWidth:startTime:titleOffset:animated:)]) {
            IQCalendarHeaderItem items[7];
            NSDate* start = self.firstDisplayedDay;
            NSDateComponents* cmpnts = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:start];
            for(int i=0; i<7; i++) {
                items[i].timeOffset = [[calendar dateFromComponents:cmpnts] timeIntervalSinceDate:start];
                cmpnts.day += 1;
            }
            [(id)header setItems:items count:7 cornerWidth:0 startTime:start titleOffset:7*24*3600 animated:animated];
            if(firstSet || animated == NO) {
                [self redisplayDays];
            } else {
                CGRect r = calendarArea.bounds;
                CGFloat ht = round(r.size.height/5.0);
                IQCalendarRow* newrows[9];
                if(dn < d) {
                    for(int i=5; i<9; i++) {
                        rows[i].frame = CGRectMake(0, ht*(i-9), r.size.width, ht);
                    }
                    for(int i=0; i<9; i++) {
                        newrows[(i+4)%9] = rows[i];
                    }
                } else {
                    for(int i=0; i<9; i++) {
                        rows[i].frame = CGRectMake(0, ht*i, r.size.width, ht);
                    }
                    for(int i=0; i<9; i++) {
                        newrows[i] = rows[(i+4)%9];
                    }
                }
                memcpy(rows, newrows, sizeof(rows));
                
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDuration:.5];
                [self redisplayDays];
                if(dn < d) {
                    for(int i=0; i<9; i++) {
                        rows[i].frame = CGRectMake(0, ht*i, r.size.width, ht);
                    }
                } else {
                    for(int i=0; i<5; i++) {
                        rows[i].frame = CGRectMake(0, ht*i, r.size.width, ht);
                        if(i<4) rows[i+5].frame = CGRectMake(0, ht*(i-4), r.size.width, ht);
                    }
                }
                [UIView commitAnimations];
            }
        }
    }
}
- (void)displayNextMonth
{    
    [self displayDay:self.firstDayInNextMonth animated:YES];
}
- (void)displayPreviousMonth
{
    [self displayDay:self.lastDayInPreviousMonth animated:YES];
}

- (void)setSelectionIntervalFrom:(NSDate*)startDate to:(NSDate*)endDate animated:(BOOL)animated
{
    if(startDate == nil && endDate == nil) {
        [self clearSelection];
        return;
    }
    selectedDays = nil;
    if(startDate == nil) startDate = endDate;
    selectionStart = startDate;
    if(endDate == nil) endDate = startDate;
    selectionEnd = endDate;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [self redisplayDays];
}

- (void)clearSelection
{
    selectedDays = nil;
    selectionStart = nil;
    selectionEnd = nil;
    [self redisplayDays];
}

-(NSDate*)dayForDate:(NSDate*)date
{
    NSDateComponents* cmpnts = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
    return [calendar dateFromComponents:cmpnts];
}

- (void)setSelected:(BOOL)selected forDay:(NSDate*)day
{
    if(selectedDays == nil) {
        if(!selected && (selectionStart == nil || selectionEnd == nil)) return;
        selectedDays = [NSMutableSet set];
    }
    if(selectionStart != nil && selectionEnd != nil) {
        NSDate* d = [self dayForDate:selectionStart];
        NSDateComponents* cmpnts = [[NSDateComponents alloc] init];
        cmpnts.day = 1;
        while([d compare:selectionEnd] != NSOrderedDescending) {
            [(NSMutableSet*)selectedDays addObject:d];
            d = [calendar dateByAddingComponents:cmpnts toDate:d options:0];
        }
    }
    selectionStart = nil;
    selectionEnd = nil;
    if(selected) [(NSMutableSet*)selectedDays addObject:[self dayForDate:day]];
    else [(NSMutableSet*)selectedDays removeObject:[self dayForDate:day]];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [self redisplayDays];
}
- (BOOL)isDaySelected:(NSDate*)day
{
    if(selectionStart != nil && selectionEnd != nil) {
        if([selectionStart compare:day] != NSOrderedDescending && [day compare:selectionEnd] != NSOrderedDescending)
            return YES;
    }
    return [selectedDays containsObject:[self dayForDate:day]];
}
- (void)setActiveSelectionRangeFrom:(NSDate*)startDate to:(NSDate*)endDate
{
    activeRangeStart = startDate;
    activeRangeEnd = endDate;
    [self redisplayDays];
}

-(NSDate*)firstDayInDisplayMonth
{
    NSDate* date = displayDate;
    if(!date) date = currentDay;
    if(!date) date = [NSDate date];
    NSDateComponents* cmpnts = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
    cmpnts.day = 1;
    return [calendar dateFromComponents:cmpnts];
}

-(NSDate*)lastDayInDisplayMonth
{
    NSDate* date = displayDate;
    if(!date) date = currentDay;
    if(!date) date = [NSDate date];
    NSDateComponents* cmpnts = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
    cmpnts.day = 0;
    cmpnts.month += 1;
    return [calendar dateFromComponents:cmpnts];
}

-(NSDate*)firstDisplayedDay
{
    NSDateComponents* cmpnts = [calendar components:NSWeekdayCalendarUnit|NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:self.firstDayInDisplayMonth];
    int daysSinceWeekStart = (int)cmpnts.weekday - (int)[calendar firstWeekday];
    cmpnts.day -= daysSinceWeekStart;
    return [calendar dateFromComponents:cmpnts];
}

-(NSDate*)lastDisplayedDay
{
    NSDateComponents* cmpnts = [calendar components:NSWeekdayCalendarUnit|NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:self.firstDisplayedDay];
    cmpnts.day += 5*7 - 1;
    return [calendar dateFromComponents:cmpnts];
}

-(NSDate*)firstDayInNextMonth
{
    NSDate* date = displayDate;
    if(!date) date = currentDay;
    if(!date) date = [NSDate date];
    NSDateComponents* cmpnts = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
    cmpnts.day = 1;
    cmpnts.month += 1;
    return [calendar dateFromComponents:cmpnts];
}

-(NSDate*)lastDayInPreviousMonth
{
    NSDate* date = displayDate;
    if(!date) date = currentDay;
    if(!date) date = [NSDate date];
    NSDateComponents* cmpnts = [calendar components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:date];
    cmpnts.day = 0;
    return [calendar dateFromComponents:cmpnts];
}
@end

@implementation IQCalendarArea
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
    }
    return self;
}

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (void)setTintColor:(UIColor*)tintColor
{
    CAGradientLayer* layer = (CAGradientLayer*)self.layer;
    CGColorRef tint = [tintColor CGColor];
    const CGFloat* cmpnts = CGColorGetComponents(tint);
    CGFloat colors[] = {
        cmpnts[0]+.1, cmpnts[1]+.1, cmpnts[2]+.1, 1,
        cmpnts[0], cmpnts[1], cmpnts[2], 1,
        cmpnts[0]-.12, cmpnts[1]-.12, cmpnts[2]-.12, 1,
    };
    CGColorRef c1 = CGColorCreate(CGColorGetColorSpace([tintColor CGColor]), colors);
    CGColorRef c2 = CGColorCreate(CGColorGetColorSpace([tintColor CGColor]), colors+4);
    layer.colors = [NSArray arrayWithObjects:(id)CFBridgingRelease(c1), (id)CFBridgingRelease(c2), nil];
    //[layer setNeedsDisplay];
}

@end

@implementation IQCalendarRow
@synthesize textColor, selectedTextColor;
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = NO;
        for(int i=0; i<7; i++) {
            days[i] = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            days[i].text = [NSString stringWithFormat:@"%d", i];
            days[i].font = [UIFont boldSystemFontOfSize:16];
            days[i].textAlignment = UITextAlignmentCenter;
            days[i].shadowColor = [UIColor whiteColor];
            days[i].backgroundColor = [UIColor clearColor];
            days[i].shadowOffset = CGSizeMake(0, 1);
            [self addSubview:days[i]];
        }
    }
    return self;
}

- (void)setSelectionColor:(UIColor *)color
{
    selectionColor = color;
    [self setNeedsDisplay];
}

- (void)setCurrentDayColor:(UIColor *)color
{
    currentDayColor = color;
    [self setNeedsDisplay];
}

- (void)setDayContentSize:(CGFloat)value
{
    dayContentSize = value;
    [self setNeedsLayout];
}

- (UIFont*)dayFont
{
    return days[0].font;
}

- (void)setDayFont:(UIFont*)dayFont
{
    for(int i=0; i<7; i++) {
        days[i].font = dayFont;
    }
}

- (void)layoutSubviews
{
    CGRect bnds = self.bounds;
    for(int i=0; i<7; i++) {
        days[i].frame = CGRectMake(round(i*bnds.size.width/7), 0, round(bnds.size.width/7), bnds.size.height-dayContentSize);
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect bnds = self.bounds;
    UIColor* lightBorder = [UIColor colorWithWhite:1 alpha:0.7];
    UIColor* darkBorder = [UIColor colorWithWhite:0 alpha:0.25];
    const static CGFloat kArrowHeight = 16.0f;
    const static CGFloat kArrowWidth = 8.0f;
    for(int i=0; i<7; i++) {
        CGFloat x = bnds.size.width / 7.0 * i;
        CGContextSaveGState(ctx);
        CGRect r = CGRectMake(round(x), 0, round(bnds.size.width / 7.0), bnds.size.height);
        
        CGContextMoveToPoint(ctx, r.origin.x, r.origin.y);
        CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y);
        if(state[i] & kCalendarStateSelectionEnd) {
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height-kArrowHeight));
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + kArrowWidth, r.origin.y+.5*r.size.height);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height+kArrowHeight));
        }
        CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y + r.size.height);
        CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y + r.size.height);
        if(state[i] & kCalendarStateSelectionStart) {
            CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height+kArrowHeight));
            CGContextAddLineToPoint(ctx, r.origin.x - kArrowWidth, r.origin.y+.5*r.size.height);
            CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height-kArrowHeight));
        }
        CGContextClip(ctx);
        
        if(state[i] & kCalendarStateCurrent) {
            if(state[i] & kCalendarStateSelected) {
                if(selectionColor != nil) CGContextSetFillColorWithColor(ctx, [selectionColor CGColor]);
            } else {
                if(currentDayColor != nil) CGContextSetFillColorWithColor(ctx, [currentDayColor CGColor]);
            }
            
            CGContextFillRect(ctx, CGRectMake(r.origin.x - kArrowWidth, r.origin.y, r.size.width + 2 * kArrowWidth, r.size.height));
            CGContextMoveToPoint(ctx, r.origin.x - 10, r.origin.y - 10);
            CGContextAddLineToPoint(ctx, r.origin.x - 10, r.origin.y + r.size.height + 10);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + 20, r.origin.y + r.size.height + 10);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + 20, r.origin.y - 10);
            CGContextClosePath(ctx);
            CGContextMoveToPoint(ctx, r.origin.x, r.origin.y);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y);
            if(state[i] & kCalendarStateSelectionEnd) {
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height-kArrowHeight));
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + kArrowWidth, r.origin.y+.5*r.size.height);
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height+kArrowHeight));
            }
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y + r.size.height);
            CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y + r.size.height);
            if(state[i] & kCalendarStateSelectionStart) {
                CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height+kArrowHeight));
                CGContextAddLineToPoint(ctx, r.origin.x - kArrowWidth, r.origin.y+.5*r.size.height);
                CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height-kArrowHeight));
            }
            CGContextSetFillColorWithColor(ctx, [[UIColor whiteColor] CGColor]);
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 10, [[UIColor blackColor] CGColor]);
            CGContextFillPath(ctx);
        } else if(state[i] & kCalendarStateSelected) {
            if(selectionColor != nil) CGContextSetFillColorWithColor(ctx, [selectionColor CGColor]);
            BOOL leftShadow = (i>0) && ((state[i-1] & (kCalendarStateSelected|kCalendarStateCurrent))==0);
            BOOL rightShadow = (i<6) && ((state[i+1] & (kCalendarStateSelected|kCalendarStateCurrent))==0);
            CGRect r = CGRectMake(round(x), 0, round(bnds.size.width / 7.0), bnds.size.height);
            
            
            CGContextFillRect(ctx, CGRectMake(r.origin.x - kArrowWidth, r.origin.y, r.size.width + 2 * kArrowWidth, r.size.height));
            CGContextMoveToPoint(ctx, r.origin.x - 10, r.origin.y - 10);
            CGContextAddLineToPoint(ctx, r.origin.x - 10, r.origin.y + r.size.height + 10);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + 10, r.origin.y + r.size.height + 10);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + 10, r.origin.y - 10);
            CGContextClosePath(ctx);
            if(!leftShadow) {
                r.origin.x -= 10;
                r.size.width += 10;
            }
            if(!rightShadow) {
                r.size.width += 10;
            }
            CGContextMoveToPoint(ctx, r.origin.x, r.origin.y);
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y);
            if(state[i] & kCalendarStateSelectionEnd) {
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height-kArrowHeight));
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width + kArrowWidth, r.origin.y+.5*r.size.height);
                CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y+.5*(r.size.height+kArrowHeight));
            }
            CGContextAddLineToPoint(ctx, r.origin.x + r.size.width, r.origin.y + r.size.height);
            CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y + r.size.height);
            if(state[i] & kCalendarStateSelectionStart) {
                CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height+kArrowHeight));
                CGContextAddLineToPoint(ctx, r.origin.x - kArrowWidth, r.origin.y+.5*r.size.height);
                CGContextAddLineToPoint(ctx, r.origin.x, r.origin.y+.5*(r.size.height-kArrowHeight));
            }
            CGContextSetFillColorWithColor(ctx, [[UIColor whiteColor] CGColor]);
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 6, [[UIColor colorWithWhite:0 alpha:0.75] CGColor]);
            CGContextFillPath(ctx);
            
        } else if((state[i] & kCalendarStateOutOfRange) == 0) {
            CGContextMoveToPoint(ctx, round(x)+.5, bnds.size.height-.5);
            if(i>0 && state[i-1] & kCalendarStateSelectionEnd) {
                CGContextAddLineToPoint(ctx, round(x)+.5, .5*(bnds.size.height+kArrowHeight));
                CGContextAddLineToPoint(ctx, round(x)+.5+kArrowWidth, .5*(bnds.size.height));
                CGContextAddLineToPoint(ctx, round(x)+.5, .5*(bnds.size.height-kArrowHeight));
            }
            CGContextAddLineToPoint(ctx, round(x)+.5, .5);
            CGContextAddLineToPoint(ctx, round(x+bnds.size.width / 7.0)-1, .5);
            CGContextSetStrokeColorWithColor(ctx, [lightBorder CGColor]);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, round(x+bnds.size.width / 7.0)-.5, .5);
            if(i<6 && state[i+1] & kCalendarStateSelectionStart) {
                CGContextAddLineToPoint(ctx, round(x+bnds.size.width / 7.0)-.5, .5*(bnds.size.height-kArrowHeight));
                CGContextAddLineToPoint(ctx, round(x+bnds.size.width / 7.0)+.5-kArrowWidth, .5*(bnds.size.height));
                CGContextAddLineToPoint(ctx, round(x+bnds.size.width / 7.0)-.5, .5*(bnds.size.height+kArrowHeight));
            }
            CGContextAddLineToPoint(ctx, round(x+bnds.size.width / 7.0)-.5, bnds.size.height-.5);
            CGContextAddLineToPoint(ctx, round(x)+.5, bnds.size.height-.5);
            CGContextSetStrokeColorWithColor(ctx, [darkBorder CGColor]);
            CGContextStrokePath(ctx);
        }
        CGContextRestoreGState(ctx);
    }
}
- (void)setDays:(NSDate*)firstDay delta:(int)dayDelta calendar:(NSCalendar*)cal monthStart:(NSDate*)ms monthEnd:(NSDate*)me selStart:(NSDate*)selStart selEnd:(NSDate*)selEnd selDays:(NSSet*)selDays currentDay:(NSDate*)currentDay selectionMode:(IQCalendarSelectionMode)selectionMode formatter:(NSDateFormatter*)fmt
{
    NSDateComponents* cmpnts = [NSDateComponents new];
    cmpnts.day = dayDelta;
    NSDate* nextdt = [cal dateByAddingComponents:cmpnts toDate:firstDay options:0];
    for(int i=0; i<7; i++) {
        cmpnts.day = (i+1) + dayDelta;
        NSDate* dt = nextdt;
        nextdt = [cal dateByAddingComponents:cmpnts toDate:firstDay options:0];
        state[i] = 0;
        if([dt compare:currentDay] != NSOrderedDescending && [nextdt compare:currentDay] == NSOrderedDescending) {
            state[i] |= kCalendarStateCurrent;
        }
        if(selStart != nil || selEnd != nil) {
            if([selStart compare:dt] != NSOrderedDescending && [dt compare:selEnd] != NSOrderedDescending) {
                state[i] |= kCalendarStateSelected;
            }
        } else if([selDays containsObject:dt]) {
            state[i] |= kCalendarStateSelected;
        }
        if([dt compare:ms] == NSOrderedAscending) {
            state[i] |= kCalendarStateOutsideCurrentMonth;
        } else if([dt compare:me] == NSOrderedDescending) {
            state[i] |= kCalendarStateOutsideCurrentMonth;
        }
        if(selectionMode == IQCalendarSelectionRangeEnd) {
            if(i > 0 && !(state[i] & kCalendarStateSelected) && (state[i-1] & kCalendarStateSelected)) {
                state[i-1] |= kCalendarStateSelectionEnd;
            }
        } else if(selectionMode == IQCalendarSelectionRangeStart) {
            if(i > 0 && !(state[i-1] & kCalendarStateSelected) && state[i] & kCalendarStateSelected) {
                state[i] |= kCalendarStateSelectionStart;
            }
        }
        days[i].text = [fmt stringFromDate:dt];
        if(state[i] & kCalendarStateSelected) {
            days[i].textColor = [UIColor whiteColor];
            days[i].shadowColor = [UIColor colorWithWhite:0 alpha:0.75];
        } else if(state[i] & kCalendarStateCurrent) {
            days[i].textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
            days[i].shadowColor = [UIColor colorWithWhite:0 alpha:0.75];
        } else if(state[i] & kCalendarStateOutsideCurrentMonth) {
            days[i].textColor = [UIColor grayColor];
            days[i].shadowColor = [UIColor whiteColor];
        } else {
            days[i].textColor = [UIColor blackColor];
            days[i].shadowColor = [UIColor whiteColor];
        }
    }
    [self setNeedsDisplay];
}
@end

