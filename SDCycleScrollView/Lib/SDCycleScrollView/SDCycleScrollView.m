//
//  SDCycleScrollView.m
//  SDCycleScrollView
//
//  Created by aier on 15-3-22.
//  Copyright (c) 2015年 GSD. All rights reserved.
//

/*
 
 *********************************************************************************
 *
 * 🌟🌟🌟 新建SDCycleScrollView交流QQ群：185534916 🌟🌟🌟
 *
 * 在您使用此自动轮播库的过程中如果出现bug请及时以以下任意一种方式联系我们，我们会及时修复bug并
 * 帮您解决问题。
 * 新浪微博:GSD_iOS
 * Email : gsdios@126.com
 * GitHub: https://github.com/gsdios
 *
 * 另（我的自动布局库SDAutoLayout）：
 *  一行代码搞定自动布局！支持Cell和Tableview高度自适应，Label和ScrollView内容自适应，致力于
 *  做最简单易用的AutoLayout库。
 * 视频教程：http://www.letv.com/ptv/vplay/24038772.html
 * 用法示例：https://github.com/gsdios/SDAutoLayout/blob/master/README.md
 * GitHub：https://github.com/gsdios/SDAutoLayout
 *********************************************************************************
 
 */


#import "SDCycleScrollView.h"
#import "SDCollectionViewCell.h"
#import "TAPageControl.h"
#import <objc/runtime.h>

#define kCycleScrollViewInitialPageControlDotSize CGSizeMake(10, 10)

static NSString * const kCellReuseIdentifier = @"SDCycleScrollViewCellReuseIdentifier";

@interface SDReuseCellInfo : NSObject
@property (nonatomic, assign) BOOL isNib;
@property (nonatomic, readonly) Class cellClass;
@property (nonatomic, copy, readonly) NSString *reuseIdentifier;
- (instancetype)initWithCellClass:(Class)cellClass cellNib:(nullable UINib *)nib reuseIdentifier:(NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

@implementation SDReuseCellInfo
- (instancetype)initWithCellClass:(Class)cellClass cellNib:(nullable UINib *)nib reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super init];
    if (self) {
        _isNib = (nib != nil && [nib isMemberOfClass:UINib.class]);
        _cellClass = cellClass;
        _reuseIdentifier = reuseIdentifier;
    }
    return self;
}
@end

@interface SDCycleScrollView () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, weak) UICollectionView *mainView; // 显示图片的collectionView
@property (nonatomic, weak) UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, strong) NSArray *imagePathsGroup;
@property (nonatomic, weak) NSTimer *timer;
@property (nonatomic, assign) NSInteger totalItemsCount;
@property (nonatomic, weak) UIControl *pageControl;
@property (nonatomic, strong) UIImageView *backgroundImageView; // 当imageURLs为空时的背景图
@property (null_resettable, nonatomic, strong) NSMutableArray<SDReuseCellInfo *> *reuseCellInfos;
@end

@implementation SDCycleScrollView

- (NSMutableArray<SDReuseCellInfo *> *)reuseCellInfos {
    if (!_reuseCellInfos) {
        _reuseCellInfos = @[].mutableCopy;
    }
    return _reuseCellInfos;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self initialization];
        [self setupMainView];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self initialization];
    [self setupMainView];
}

- (void)initialization
{
    _pageControlAliment = SDCycleScrollViewPageContolAlimentCenter;
    _autoScrollTimeInterval = 2.0;
    _titleLabelTextColor = [UIColor whiteColor];
    _titleLabelTextFont= [UIFont systemFontOfSize:14];
    _titleLabelBackgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    _titleLabelHeight = 30;
    _titleLabelTextAlignment = NSTextAlignmentLeft;
    _autoScroll = YES;
    _infiniteLoop = YES;
    _showPageControl = YES;
    _pageControlDotSize = kCycleScrollViewInitialPageControlDotSize;
    _pageControlBottomOffset = 0;
    _pageControlRightOffset = 0;
    _pageControlStyle = SDCycleScrollViewPageContolStyleClassic;
    _hidesForSinglePage = YES;
    _currentPageDotColor = [UIColor whiteColor];
    _pageDotColor = [UIColor lightGrayColor];
    _bannerImageViewContentMode = UIViewContentModeScaleToFill;
    
    self.backgroundColor = [UIColor clearColor];
    
}

+ (instancetype)cycleScrollViewWithFrame:(CGRect)frame imageNamesGroup:(NSArray *)imageNamesGroup
{
    SDCycleScrollView *cycleScrollView = [[self alloc] initWithFrame:frame];
    cycleScrollView.localizationImageNamesGroup = [NSMutableArray arrayWithArray:imageNamesGroup];
    return cycleScrollView;
}

+ (instancetype)cycleScrollViewWithFrame:(CGRect)frame shouldInfiniteLoop:(BOOL)infiniteLoop imageNamesGroup:(NSArray *)imageNamesGroup
{
    SDCycleScrollView *cycleScrollView = [[self alloc] initWithFrame:frame];
    cycleScrollView.infiniteLoop = infiniteLoop;
    cycleScrollView.localizationImageNamesGroup = [NSMutableArray arrayWithArray:imageNamesGroup];
    return cycleScrollView;
}

+ (instancetype)cycleScrollViewWithFrame:(CGRect)frame imageURLStringsGroup:(NSArray *)imageURLsGroup
{
    SDCycleScrollView *cycleScrollView = [[self alloc] initWithFrame:frame];
    cycleScrollView.imageURLStringsGroup = [NSMutableArray arrayWithArray:imageURLsGroup];
    return cycleScrollView;
}

+ (instancetype)cycleScrollViewWithFrame:(CGRect)frame delegate:(id<SDCycleScrollViewDelegate>)delegate placeholderImage:(UIImage *)placeholderImage
{
    SDCycleScrollView *cycleScrollView = [[self alloc] initWithFrame:frame];
    cycleScrollView.delegate = delegate;
    cycleScrollView.placeholderImage = placeholderImage;
    
    return cycleScrollView;
}

// 设置显示图片的collectionView
- (void)setupMainView
{
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = 0;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _flowLayout = flowLayout;
    
    UICollectionView *mainView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:flowLayout];
    mainView.backgroundColor = [UIColor clearColor];
    mainView.pagingEnabled = YES;
    mainView.showsHorizontalScrollIndicator = NO;
    mainView.showsVerticalScrollIndicator = NO;
    [mainView registerClass:[SDCollectionViewCell class] forCellWithReuseIdentifier:kCellReuseIdentifier];
    
    mainView.dataSource = self;
    mainView.delegate = self;
    mainView.scrollsToTop = NO;
    [self addSubview:mainView];
    _mainView = mainView;
}


#pragma mark - properties

- (void)setDelegate:(id<SDCycleScrollViewDelegate>)delegate
{
    _delegate = delegate;
    
    if ([self.delegate respondsToSelector:@selector(customCollectionViewCellClassForCycleScrollView:)] && [self.delegate customCollectionViewCellClassForCycleScrollView:self]) {
        [self.mainView registerClass:[self.delegate customCollectionViewCellClassForCycleScrollView:self] forCellWithReuseIdentifier:kCellReuseIdentifier];
    } else if ([self.delegate respondsToSelector:@selector(customCollectionViewCellNibForCycleScrollView:)] && [self.delegate customCollectionViewCellNibForCycleScrollView:self]) {
        [self.mainView registerNib:[self.delegate customCollectionViewCellNibForCycleScrollView:self] forCellWithReuseIdentifier:kCellReuseIdentifier];
    }
}

- (void)setPlaceholderImage:(UIImage *)placeholderImage
{
    _placeholderImage = placeholderImage;
    
    if (!self.backgroundImageView) {
        UIImageView *bgImageView = [UIImageView new];
        bgImageView.contentMode = _bannerImageViewContentMode;
        [self insertSubview:bgImageView belowSubview:self.mainView];
        self.backgroundImageView = bgImageView;
    }
    
    self.backgroundImageView.image = placeholderImage;
}

- (void)setPageControlDotSize:(CGSize)pageControlDotSize
{
    _pageControlDotSize = pageControlDotSize;
    [self setupPageControl];
    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageContol = (TAPageControl *)_pageControl;
        pageContol.dotSize = pageControlDotSize;
    }
}

- (void)setShowPageControl:(BOOL)showPageControl
{
    _showPageControl = showPageControl;
    
    _pageControl.hidden = !showPageControl;
}

- (void)setCurrentPageDotColor:(UIColor *)currentPageDotColor
{
    _currentPageDotColor = currentPageDotColor;
    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageControl = (TAPageControl *)_pageControl;
        pageControl.dotColor = currentPageDotColor;
    } else {
        UIPageControl *pageControl = (UIPageControl *)_pageControl;
        pageControl.currentPageIndicatorTintColor = currentPageDotColor;
    }
    
}

- (void)setPageDotColor:(UIColor *)pageDotColor
{
    _pageDotColor = pageDotColor;
    
    if ([self.pageControl isKindOfClass:[UIPageControl class]]) {
        UIPageControl *pageControl = (UIPageControl *)_pageControl;
        pageControl.pageIndicatorTintColor = pageDotColor;
    }
}

- (void)setCurrentPageDotImage:(UIImage *)currentPageDotImage
{
    _currentPageDotImage = currentPageDotImage;
    
    if (self.pageControlStyle != SDCycleScrollViewPageContolStyleAnimated) {
        self.pageControlStyle = SDCycleScrollViewPageContolStyleAnimated;
    }
    
    [self setCustomPageControlDotImage:currentPageDotImage isCurrentPageDot:YES];
}

- (void)setPageDotImage:(UIImage *)pageDotImage
{
    _pageDotImage = pageDotImage;
    
    if (self.pageControlStyle != SDCycleScrollViewPageContolStyleAnimated) {
        self.pageControlStyle = SDCycleScrollViewPageContolStyleAnimated;
    }
    
    [self setCustomPageControlDotImage:pageDotImage isCurrentPageDot:NO];
}

- (void)setCustomPageControlDotImage:(UIImage *)image isCurrentPageDot:(BOOL)isCurrentPageDot
{
    if (!image || !self.pageControl) return;
    
    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageControl = (TAPageControl *)_pageControl;
        if (isCurrentPageDot) {
            pageControl.currentDotImage = image;
        } else {
            pageControl.dotImage = image;
        }
    }
}

- (void)setInfiniteLoop:(BOOL)infiniteLoop
{
    _infiniteLoop = infiniteLoop;
    
    if (self.imagePathsGroup.count) {
        self.imagePathsGroup = self.imagePathsGroup;
    }
}

-(void)setAutoScroll:(BOOL)autoScroll{
    _autoScroll = autoScroll;
    
    [self invalidateTimer];
    
    if (_autoScroll) {
        [self setupTimer];
    }
}

- (void)setScrollDirection:(UICollectionViewScrollDirection)scrollDirection
{
    _scrollDirection = scrollDirection;
    
    _flowLayout.scrollDirection = scrollDirection;
}

- (void)setAutoScrollTimeInterval:(CGFloat)autoScrollTimeInterval
{
    _autoScrollTimeInterval = autoScrollTimeInterval;
    
    [self setAutoScroll:self.autoScroll];
}

- (void)setPageControlStyle:(SDCycleScrollViewPageContolStyle)pageControlStyle
{
    _pageControlStyle = pageControlStyle;
    
    [self setupPageControl];
}

- (void)setImagePathsGroup:(NSArray *)imagePathsGroup
{
    [self invalidateTimer];
    
    _imagePathsGroup = imagePathsGroup;
    
    _totalItemsCount = self.infiniteLoop ? self.imagePathsGroup.count * 100 : self.imagePathsGroup.count;
    
    if (imagePathsGroup.count > 1) { // 由于 !=1 包含count == 0等情况
        self.mainView.scrollEnabled = YES;
        [self setAutoScroll:self.autoScroll];
    } else {
        self.mainView.scrollEnabled = NO;
        [self invalidateTimer];
    }
    
    [self setupPageControl];
    [self.mainView reloadData];
}

- (void)setImageURLStringsGroup:(NSArray *)imageURLStringsGroup
{
    _imageURLStringsGroup = imageURLStringsGroup;
    
    NSMutableArray *temp = [NSMutableArray new];
    [_imageURLStringsGroup enumerateObjectsUsingBlock:^(NSString * obj, NSUInteger idx, BOOL * stop) {
        NSString *urlString;
        if ([obj isKindOfClass:[NSString class]]) {
            urlString = obj;
        } else if ([obj isKindOfClass:[NSURL class]]) {
            NSURL *url = (NSURL *)obj;
            urlString = [url absoluteString];
        }
        if (urlString) {
            [temp addObject:urlString];
        }
    }];
    self.imagePathsGroup = [temp copy];
}

- (void)setLocalizationImageNamesGroup:(NSArray *)localizationImageNamesGroup
{
    _localizationImageNamesGroup = localizationImageNamesGroup;
    self.imagePathsGroup = [localizationImageNamesGroup copy];
}

- (void)setTitlesGroup:(NSArray *)titlesGroup
{
    _titlesGroup = titlesGroup;
    if (self.onlyDisplayText) {
        NSMutableArray *temp = [NSMutableArray new];
        for (int i = 0; i < _titlesGroup.count; i++) {
            [temp addObject:@""];
        }
        self.backgroundColor = [UIColor clearColor];
        self.imageURLStringsGroup = [temp copy];
    }
}

- (void)setBannerImageViewContentMode:(UIViewContentMode)bannerImageViewContentMode {
    
    _bannerImageViewContentMode = bannerImageViewContentMode;
    
    _backgroundImageView.contentMode = _bannerImageViewContentMode;
}

- (void)disableScrollGesture {
    self.mainView.canCancelContentTouches = NO;
    for (UIGestureRecognizer *gesture in self.mainView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            [self.mainView removeGestureRecognizer:gesture];
        }
    }
}

#pragma mark - actions

- (void)setupTimer
{
    [self invalidateTimer]; // 创建定时器前先停止定时器，不然会出现僵尸定时器，导致轮播频率错误
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:self.autoScrollTimeInterval target:self selector:@selector(automaticScroll) userInfo:nil repeats:YES];
    _timer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)invalidateTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)setupPageControl
{
    if (_pageControl) [_pageControl removeFromSuperview]; // 重新加载数据时调整
    
    if (self.imagePathsGroup.count == 0 || self.onlyDisplayText) return;
    
    if ((self.imagePathsGroup.count == 1) && self.hidesForSinglePage) return;
    
    NSInteger indexOnPageControl = [self pageControlIndexWithCurrentCellIndex:[self currentIndex]];

    switch (self.pageControlStyle) {
        case SDCycleScrollViewPageContolStyleAnimated:
        {
            TAPageControl *pageControl = [[TAPageControl alloc] init];
            pageControl.numberOfPages = self.imagePathsGroup.count;
            pageControl.dotColor = self.currentPageDotColor;
            pageControl.userInteractionEnabled = NO;
            pageControl.currentPage = indexOnPageControl;
            [self addSubview:pageControl];
            _pageControl = pageControl;
        }
            break;
            
        case SDCycleScrollViewPageContolStyleClassic:
        {
            UIPageControl *pageControl = [[UIPageControl alloc] init];
            pageControl.numberOfPages = self.imagePathsGroup.count;
            pageControl.currentPageIndicatorTintColor = self.currentPageDotColor;
            pageControl.pageIndicatorTintColor = self.pageDotColor;
            pageControl.userInteractionEnabled = NO;
            pageControl.currentPage = indexOnPageControl;
            [self addSubview:pageControl];
            _pageControl = pageControl;
        }
            break;
            
        default:
            break;
    }
    
    // 重设pagecontroldot图片
    if (self.currentPageDotImage) {
        self.currentPageDotImage = self.currentPageDotImage;
    }
    if (self.pageDotImage) {
        self.pageDotImage = self.pageDotImage;
    }
}


- (void)automaticScroll
{
    if (0 == _totalItemsCount) return;
    NSInteger currentIndex = [self currentIndex];
    NSInteger targetIndex = currentIndex + 1;
    [self scrollToIndex:targetIndex];
}

- (void)scrollToIndex:(NSInteger)targetIndex
{
    if (targetIndex >= _totalItemsCount) {
        if (self.infiniteLoop) {
            targetIndex = _totalItemsCount * 0.5;
            [_mainView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
        }
        return;
    }
    [_mainView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:YES];
}

- (NSInteger)currentIndex
{
    if (_mainView.frame.size.width == 0 || _mainView.frame.size.height == 0) {
        return 0;
    }
    
    NSInteger index = 0;
    
    if (_flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
        index = (_mainView.contentOffset.x + _flowLayout.itemSize.width * 0.5) / _flowLayout.itemSize.width;
    } else {
        index = (_mainView.contentOffset.y + _flowLayout.itemSize.height * 0.5) / _flowLayout.itemSize.height;
    }
    
    return MAX(0, index);
}

- (NSInteger)pageControlIndexWithCurrentCellIndex:(NSInteger)index
{
    return (NSInteger)index % self.imagePathsGroup.count;
}

- (NSString *)cellReuseIdentifierForClass:(Class)cellClass nib:(nullable UINib *)cellNib isNib:(BOOL)isNib {
    __block NSString *reuseIdentifier = nil;
    [self.reuseCellInfos enumerateObjectsUsingBlock:^(SDReuseCellInfo *info, NSUInteger idx, BOOL * _Nonnull stop) {
        if (info.isNib == isNib && info.cellClass != nil && info.cellClass == cellClass && info.reuseIdentifier != nil) {
            reuseIdentifier = info.reuseIdentifier;
            *stop = YES;
        }
    }];
    if (!reuseIdentifier) {
        reuseIdentifier = [NSString stringWithFormat:@"SD_%@_%@ReuseIdentifier", NSStringFromClass(cellClass), isNib ? @"nibCell" : @"cell"];
        if (isNib) {
            [self.mainView registerNib:cellNib forCellWithReuseIdentifier:reuseIdentifier];
        } else {
            [self.mainView registerClass:cellClass forCellWithReuseIdentifier:reuseIdentifier];
        }
        SDReuseCellInfo *cellInfo = [[SDReuseCellInfo alloc] initWithCellClass:cellClass cellNib:cellNib reuseIdentifier:reuseIdentifier];
        [self.reuseCellInfos addObject:cellInfo];
    }
    return reuseIdentifier;
}

#pragma mark - life circles

- (void)layoutSubviews
{
    self.delegate = self.delegate;
    
    [super layoutSubviews];

    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;

    if (width <= 0 || height <= 0) return;

    _flowLayout.itemSize = self.frame.size;
    
    _mainView.frame = self.bounds;
    
    if (_mainView.contentOffset.x == 0 &&  _totalItemsCount) {
        int targetIndex = 0;
        if (self.infiniteLoop) {
            targetIndex = _totalItemsCount * 0.5;
        }else{
            targetIndex = 0;
        }
        [_mainView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
    }
    
    CGSize size = CGSizeZero;
    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageControl = (TAPageControl *)_pageControl;
        if (!(self.pageDotImage && self.currentPageDotImage && CGSizeEqualToSize(kCycleScrollViewInitialPageControlDotSize, self.pageControlDotSize))) {
            pageControl.dotSize = self.pageControlDotSize;
        }
        size = [pageControl sizeForNumberOfPages:self.imagePathsGroup.count];
    } else {
        size = CGSizeMake(self.imagePathsGroup.count * self.pageControlDotSize.width * 1.5, self.pageControlDotSize.height);
        // ios14 需要按照系统规则适配pageControl size
        if (@available(iOS 14.0, *)) {
            if ([self.pageControl isKindOfClass:[UIPageControl class]]) {
                UIPageControl *pageControl = (UIPageControl *)_pageControl;
                size.width = [pageControl sizeForNumberOfPages:self.imagePathsGroup.count].width;
            }
        }
    }
    CGFloat x = (self.frame.size.width - size.width) * 0.5;
    if (self.pageControlAliment == SDCycleScrollViewPageContolAlimentRight) {
        x = self.mainView.frame.size.width - size.width - 10;
    }
    CGFloat y = self.mainView.frame.size.height - size.height - 10;
    
    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageControl = (TAPageControl *)_pageControl;
        [pageControl sizeToFit];
    }
    
    CGRect pageControlFrame = CGRectMake(x, y, size.width, size.height);
    pageControlFrame.origin.y -= self.pageControlBottomOffset;
    pageControlFrame.origin.x -= self.pageControlRightOffset;
    self.pageControl.frame = pageControlFrame;
    self.pageControl.hidden = !_showPageControl;
    
    if (self.backgroundImageView) {
        self.backgroundImageView.contentMode = _bannerImageViewContentMode;
        self.backgroundImageView.frame = self.bounds;
    }
    
}

//解决当父View释放时，当前视图因为被Timer强引用而不能释放的问题
- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (!newSuperview) {
        [self invalidateTimer];
    }
}

//解决当timer释放后 回调scrollViewDidScroll时访问野指针导致崩溃
- (void)dealloc {
    _mainView.delegate = nil;
    _mainView.dataSource = nil;
}

#pragma mark - public actions

- (void)adjustWhenControllerViewWillAppear
{
    long targetIndex = [self currentIndex];
    if (targetIndex < _totalItemsCount) {
        [_mainView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:targetIndex inSection:0] atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _totalItemsCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {

    NSInteger itemIndex = [self pageControlIndexWithCurrentCellIndex:indexPath.item];

    if (self.delegate != nil) {
        if ([self.delegate respondsToSelector:@selector(customCollectionViewCellSourceForCycleScrollView:forIndex:)]) {
            id object = [self.delegate customCollectionViewCellSourceForCycleScrollView:self forIndex:itemIndex];
            if ([object isKindOfClass:UINib.class]) {
                UINib *customCellNib = (UINib *)object;
                NSArray *nibInObjects = [customCellNib instantiateWithOwner:nil options:nil];
                id firstNibInObject = nibInObjects.firstObject;
                if (firstNibInObject != nil && [firstNibInObject isKindOfClass:UICollectionViewCell.class]) {
                    NSString *cellReuseIdentifier = [self cellReuseIdentifierForClass:[firstNibInObject class] nib:customCellNib isNib:YES];
                    return [collectionView dequeueReusableCellWithReuseIdentifier:cellReuseIdentifier forIndexPath:indexPath];
                }
            } else if (class_isMetaClass(object_getClass(object))) {
                Class customCellClass = (Class)object;
                if ([customCellClass.new isKindOfClass:UICollectionViewCell.class]) {
                    NSString *cellReuseIdentifier = [self cellReuseIdentifierForClass:customCellClass nib:nil isNib:NO];
                    return [collectionView dequeueReusableCellWithReuseIdentifier:cellReuseIdentifier forIndexPath:indexPath];
                }
            }
        }
    }

    return [collectionView dequeueReusableCellWithReuseIdentifier:kCellReuseIdentifier forIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger itemIndex = [self pageControlIndexWithCurrentCellIndex:indexPath.item];
    
    if (![cell isKindOfClass:SDCollectionViewCell.class]) {
        if ([self.delegate respondsToSelector:@selector(cycleScrollView:willDisplayCell:forIndex:)]) {
            [self.delegate cycleScrollView:self willDisplayCell:cell forIndex:itemIndex];
        }
        return;
    }
    
    SDCollectionViewCell *aCell = (SDCollectionViewCell *)cell;
    
    NSString *imagePath = self.imagePathsGroup[itemIndex];
    
    if (!self.onlyDisplayText && [imagePath isKindOfClass:[NSString class]]) {
        if ([imagePath hasPrefix:@"http"]) {
            
        } else {
            UIImage *image = [UIImage imageNamed:imagePath];
            if (!image) {
                image = [UIImage imageWithContentsOfFile:imagePath];
            }
            aCell.imageView.image = image;
        }
    } else if (!self.onlyDisplayText && [imagePath isKindOfClass:[UIImage class]]) {
        aCell.imageView.image = (UIImage *)imagePath;
    }
    
    if (_titlesGroup.count && itemIndex < _titlesGroup.count) {
        aCell.title = _titlesGroup[itemIndex];
    }
    
    if (!aCell.hasConfigured) {
        aCell.titleLabelBackgroundColor = self.titleLabelBackgroundColor;
        aCell.titleLabelHeight = self.titleLabelHeight;
        aCell.titleLabelTextAlignment = self.titleLabelTextAlignment;
        aCell.titleLabelTextColor = self.titleLabelTextColor;
        aCell.titleLabelTextFont = self.titleLabelTextFont;
        aCell.hasConfigured = YES;
        aCell.imageView.contentMode = self.bannerImageViewContentMode;
        aCell.clipsToBounds = YES;
        aCell.onlyDisplayText = self.onlyDisplayText;
    }
    
    if ([self.delegate respondsToSelector:@selector(cycleScrollView:willDisplayImageView:forIndex:)]) {
        [self.delegate cycleScrollView:self willDisplayImageView:aCell.imageView forIndex:itemIndex];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger itemIndex = [self pageControlIndexWithCurrentCellIndex:indexPath.item];
    
    if ([cell isKindOfClass:SDCollectionViewCell.class]) {
        SDCollectionViewCell *aCell = (SDCollectionViewCell *)cell;
        if ([self.delegate respondsToSelector:@selector(cycleScrollView:didEndDisplayingImageView:forIndex:)]) {
            [self.delegate cycleScrollView:self didEndDisplayingImageView:aCell.imageView forIndex:itemIndex];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(cycleScrollView:didEndDisplayingCell:forIndex:)]) {
            [self.delegate cycleScrollView:self didEndDisplayingCell:cell forIndex:itemIndex];
        }
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSInteger itemIndex = [self pageControlIndexWithCurrentCellIndex:indexPath.item];
    
    if ([self.delegate respondsToSelector:@selector(cycleScrollView:didSelectItemAtIndex:)]) {
        [self.delegate cycleScrollView:self didSelectItemAtIndex:itemIndex];
    }
    
    if (self.clickItemOperationBlock != nil) {
        self.clickItemOperationBlock(itemIndex);
    }
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!self.imagePathsGroup.count) return; // 解决清除timer时偶尔会出现的问题
    NSInteger itemIndex = [self currentIndex];
    NSInteger indexOnPageControl = [self pageControlIndexWithCurrentCellIndex:itemIndex];

    if ([self.pageControl isKindOfClass:[TAPageControl class]]) {
        TAPageControl *pageControl = (TAPageControl *)_pageControl;
        pageControl.currentPage = indexOnPageControl;
    } else {
        UIPageControl *pageControl = (UIPageControl *)_pageControl;
        pageControl.currentPage = indexOnPageControl;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.autoScroll) {
        [self invalidateTimer];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (self.autoScroll) {
        [self setupTimer];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self scrollViewDidEndScrollingAnimation:self.mainView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (!self.imagePathsGroup.count) return; // 解决清除timer时偶尔会出现的问题
    NSInteger itemIndex = [self currentIndex];
    NSInteger indexOnPageControl = [self pageControlIndexWithCurrentCellIndex:itemIndex];
    
    if ([self.delegate respondsToSelector:@selector(cycleScrollView:didScrollToIndex:)]) {
        [self.delegate cycleScrollView:self didScrollToIndex:indexOnPageControl];
    } else if (self.itemDidScrollOperationBlock) {
        self.itemDidScrollOperationBlock(indexOnPageControl);
    }
}

- (void)makeScrollViewScrollToIndex:(NSInteger)index{
    if (self.autoScroll) {
        [self invalidateTimer];
    }
    if (0 == _totalItemsCount) return;
    
    [self scrollToIndex:(int)(_totalItemsCount * 0.5 + index)];
    
    if (self.autoScroll) {
        [self setupTimer];
    }
}

@end
