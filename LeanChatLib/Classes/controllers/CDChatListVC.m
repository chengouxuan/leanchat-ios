//
//  CDChatListController.m
//  AVOSChatDemo
//
//  Created by Qihe Bian on 7/25/14.
//  Copyright (c) 2014 AVOS. All rights reserved.
//

#import "CDChatListVC.h"
#import "CDIMClientStatusView.h"
#import "CDStorage.h"
#import "UIView+XHRemoteImage.h"
#import "CDChatListRoomCell.h"
#import "CDIM.h"
#import "CDMacros.h"

@interface CDChatListVC () <CDIMClientStatusViewDelegate>

@property (nonatomic) CDIMClientStatusView *clientStatusView;

@property (nonatomic, strong) NSMutableArray *rooms;

@property (nonatomic, strong) CDNotify *notify;

@property (nonatomic, strong) CDIM *im;

@property (nonatomic, strong) CDStorage *storage;

@property (nonatomic, strong) CDIMConfig *imConfig;

@end

static NSMutableArray *cacheConvs;

@implementation CDChatListVC

static NSString *cellIdentifier = @"ContactCell";

- (instancetype)init {
    if ((self = [super init])) {
        _rooms = [[NSMutableArray alloc] init];
        _im = [CDIM sharedInstance];
        _storage = [CDStorage sharedInstance];
        _notify = [CDNotify sharedInstance];
        _imConfig = [CDIMConfig config];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[CDChatListRoomCell class] forCellReuseIdentifier:[CDChatListRoomCell identifier]];
    
    [self.clientStatusView observeIMClientUpdate];
    self.refreshControl = [self getRefreshControl];
    
    [_notify addMsgObserver:self selector:@selector(refresh)];
    [_notify addSessionObserver:self selector:@selector(sessionChanged)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    WEAKSELF
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [weakSelf refresh:nil];
    });
}

- (void)dealloc {
    [_notify removeMsgObserver:self];
    [_notify removeSessionObserver:self];
}

#pragma mark - Propertys

- (CDIMClientStatusView *)clientStatusView {
    if (_clientStatusView == nil) {
        _clientStatusView = [[CDIMClientStatusView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), kCDIMClientStatusViewHight)];
        [_clientStatusView setDelegate:self];
    }
    return _clientStatusView;
}

- (UIRefreshControl *)getRefreshControl {
    UIRefreshControl *refreshConrol;
    refreshConrol = [[UIRefreshControl alloc] init];
    [refreshConrol addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    return refreshConrol;
}

#pragma mark - notification

- (void)sessionChanged {
}

- (void)refresh {
    [self refresh:nil];
}

#pragma mark

- (void)stopRefreshControl:(UIRefreshControl *)refreshControl {
    if (refreshControl != nil && [[refreshControl class] isSubclassOfClass:[UIRefreshControl class]]) {
        [refreshControl endRefreshing];
    }
}

- (BOOL)filterError:(NSError *)error {
    if (error) {
        [[[UIAlertView alloc]
          initWithTitle:nil message:[NSString stringWithFormat:@"%@", error] delegate:nil
          cancelButtonTitle:@"确定" otherButtonTitles:nil] show];
        return NO;
    }
    return YES;
}

- (void)refresh:(UIRefreshControl *)refreshControl {
    if ([_im isOpened] == NO) {
        [self stopRefreshControl:refreshControl];
        //return;
    }
    [self.im findRecentRoomsWithBlock: ^(NSArray *objects, NSError *error) {
        [self stopRefreshControl:refreshControl];
        if ([self filterError:error]) {
            _rooms = objects;
            [self.tableView reloadData];
            NSInteger totalUnreadCount = 0;
            for (CDRoom *room in _rooms) {
                totalUnreadCount += room.unreadCount;
            }
            if ([self.chatListDelegate respondsToSelector:@selector(setBadgeWithTotalUnreadCount:)]) {
                [self.chatListDelegate setBadgeWithTotalUnreadCount:totalUnreadCount];
            }
        }
    }];
}

#pragma mark - table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_rooms count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CDChatListRoomCell *cell = [tableView dequeueReusableCellWithIdentifier:[CDChatListRoomCell identifier]];
    CDRoom *room = [_rooms objectAtIndex:indexPath.row];
    cell.room=room;
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        CDRoom *room = [_rooms objectAtIndex:indexPath.row];
        [_storage deleteRoomByConvid:room.conv.conversationId];
        [self refresh];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return true;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CDRoom *room = [_rooms objectAtIndex:indexPath.row];
    if ([self.chatListDelegate respondsToSelector:@selector(viewController:didSelectConv:)]) {
        [self.chatListDelegate viewController:self didSelectConv:room.conv];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [CDChatListRoomCell heightOfCell];
}

#pragma mark -- CDSessionDelegateMethods

- (void)onIMClientPauseWithStatusView:(CDIMClientStatusView *)view {
    self.tableView.tableHeaderView = view;
}

- (void)onIMClientOpenWithStatusView:(CDIMClientStatusView *)view {
    self.tableView.tableHeaderView = nil;
}

@end
