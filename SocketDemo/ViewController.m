//
//  ViewController.m
//  SocketDemo
//
//  Created by Paul Wilkinson on 22/12/2014.
//  Copyright (c) 2014 Paul Wilkinson. All rights reserved.
//

#import "ViewController.h"
#import <ifaddrs.h>
#import <arpa/inet.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *IPLabel;
@property (weak, nonatomic) IBOutlet UITextView *receivedText;
@property (weak, nonatomic) IBOutlet UITextField *destinationHost;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UITextField *messageText;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;
@property (strong,nonatomic) GCDAsyncSocket *serverSocket;
@property (strong,nonatomic) GCDAsyncSocket *partnerSocket;
@property (strong,nonatomic) NSString *myIP;
@property NSInteger port;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.receivedText.text=@"";
    self.myIP=[self getIPAddress];
    self.port=6666;
    [self createServerSocket:self.port];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setUIState];
}

- (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
    
}


-(void) createServerSocket:(NSInteger)port {
    self.serverSocket=[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![self.serverSocket acceptOnPort:port error:&error])
        {
        NSLog(@"I goofed: %@", error);
        }
}



-(void)setUIState {
    
    self.IPLabel.text=[NSString stringWithFormat:@"My IP %@",self.myIP];
    
    if (self.partnerSocket != nil) {
        [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        self.destinationHost.enabled=NO;
        self.messageText.enabled=YES;
    }
    else {
        [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        self.destinationHost.enabled=YES;
        self.sendButton.enabled=NO;
        self.messageText.enabled=NO;
        if (self.destinationHost.text.length >0) {
            self.connectButton.enabled=YES;
        }
        else {
            self.connectButton.enabled=NO;
        }
    }
   
}

#pragma mark - Socket delegate methods

- (void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    NSLog(@"New incoming connection");
    if (self.partnerSocket == nil) {
        self.partnerSocket=newSocket;
        NSString *welcomeMsg=[NSString stringWithFormat:@"You are now connected to %@",self.myIP];
        
        [newSocket writeData:[welcomeMsg dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        [newSocket writeData:[GCDAsyncSocket CRLFData] withTimeout:1000 tag:0];
        [self.partnerSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setUIState];
        });
    }
    else {
        [newSocket disconnect];
    }
}

-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"Connected to host %@",host);
    [self.partnerSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    [self setUIState];
}

-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (self.partnerSocket!=nil) {
        self.partnerSocket.delegate=nil;
    }
    self.partnerSocket=nil;
    NSLog(@"Socket disconnected with error %@",err);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setUIState];
    });
}

-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"Finished writing");
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *receivedText=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.receivedText.text=[NSString stringWithFormat:@"%@%@",self.receivedText.text,receivedText];
    [self.partnerSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

#pragma mark - button action handlers

-(IBAction)sendPressed:(id)sender {
    [self.partnerSocket writeData:[self.messageText.text dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    [self.partnerSocket writeData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

-(IBAction)connectPressed:(id)sender {
    
    if (self.partnerSocket !=nil) {
        self.partnerSocket=nil;
        [self.partnerSocket disconnect];
        self.partnerSocket=nil;
    }
    
    self.partnerSocket=[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [self.partnerSocket connectToHost:self.destinationHost.text onPort:self.port error:nil];
    [self.destinationHost resignFirstResponder];
    
}

-(void) keyboardDidShow:(NSNotification *)notification{
    NSDictionary *info = notification.userInfo;
    CGRect keyboardFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    [UIView animateWithDuration:0.1 animations:^{
        self.bottomConstraint.constant = keyboardFrame.size.height+20;
    }];
    
}

-(void) keyboardDidHide:(NSNotification *)notification {
    [UIView animateWithDuration:0.1 animations:^{
        self.bottomConstraint.constant = 8;
    }];
}

-(BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSString *newValue=[textField.text stringByReplacingCharactersInRange:range withString:string];
    
    BOOL hasChars=(newValue.length >0);
    
    if (textField == self.destinationHost) {
        self.connectButton.enabled=hasChars;
    }
    else if (textField == self.messageText) {
        self.sendButton.enabled=hasChars;
    }
    
    return YES;
}
-(BOOL) textFieldShouldReturn:(UITextField *)textField {
    if (textField==self.destinationHost) {
        [self connectPressed:self.connectButton];
    }
    else {
        [self sendPressed:self.sendButton];
    }
    [textField resignFirstResponder];
    return YES;
}

@end
