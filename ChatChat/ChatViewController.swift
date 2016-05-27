/*
* Copyright (c) 2015 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import Firebase
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
  
  var messages: [JSQMessage] = []
  var outgoingBubbleImageView: JSQMessagesBubbleImage!
  var incomingBubbleImageView: JSQMessagesBubbleImage!
    
  let rootRef = FIRDatabase.database().referenceFromURL("https://<my-firebase-app>.firebaseio.com/")
  var messageRef: FIRDatabaseReference!
  var userIsTypingRef: FIRDatabaseReference!
    
  var usersTypingQuery: FIRDatabaseQuery!
    
  private var localTyping = false
  var isTyping: Bool {
    get {
      return localTyping
    }
    set {
      localTyping = newValue
      userIsTypingRef.setValue(newValue)
    }
  }
    
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "ChatChat"
    setupBubbles()
    // No avatars!
    collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
    collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
    
    messageRef = rootRef.child("messages")
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    observeMessages()
    observeTyping()
  }
  
  override func viewDidDisappear(animated: Bool) {
    super.viewDidDisappear(animated)
  }
    
  override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
    return messages[indexPath.item]
  }
    
  override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return messages.count
  }
    
  override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
    let message = messages[indexPath.item]
    if message.senderId == senderId {
      return outgoingBubbleImageView
    } else {
      return incomingBubbleImageView
    }
  }
    
  override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
    return nil
  }
    
  override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
    let message = messages[indexPath.item]
    
    if message.senderId == senderId {
      cell.textView.textColor = UIColor.whiteColor()
    } else {
      cell.textView.textColor = UIColor.blackColor()
    }
    
    return cell
  }
    
  override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
    let itemRef = messageRef.childByAutoId()
    let messageItem = [
      "text": text,
      "senderId": senderId
    ]
    itemRef.setValue(messageItem)
    
    JSQSystemSoundPlayer.jsq_playMessageSentSound()
    
    finishSendingMessage()
    isTyping = false
  }
    
  override func textViewDidChange(textView: UITextView) {
    super.textViewDidChange(textView)
    isTyping = textView.text != ""
  }
    
  private func setupBubbles() {
    let factory = JSQMessagesBubbleImageFactory()
    outgoingBubbleImageView = factory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
    incomingBubbleImageView = factory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
  }
    
  private func observeMessages() {
    let messagesQuery = messageRef.queryLimitedToLast(25)
        
    messagesQuery.observeEventType(.ChildAdded, withBlock: { snapshot in
      let id = snapshot.value!["senderId"] as! String
      let text = snapshot.value!["text"] as! String
      self.addMessage(id, text: text)
      self.finishReceivingMessage()
    })
  }
    
  private func observeTyping() {
    let typingIndicatorRef = rootRef.child("typingIndicator")
    userIsTypingRef = typingIndicatorRef.child(senderId)
    userIsTypingRef.onDisconnectRemoveValue()
    
    usersTypingQuery = typingIndicatorRef.queryOrderedByValue().queryEqualToValue(true)
    usersTypingQuery.observeEventType(.Value, withBlock: { snapshot in
      // You're the only one typing, don't show the indicator
      if snapshot.childrenCount == 1 && self.isTyping { return }
      
      // Are there others typing?
      self.showTypingIndicator = snapshot.childrenCount > 0
      self.scrollToBottomAnimated(true)
    })
  }
    
  func addMessage(id: String, text: String) {
    let message = JSQMessage(senderId: id, displayName: "", text: text)
    messages.append(message)
  }
  
}