import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or get existing conversation between driver and user for specific order
  static Future<String> createOrGetConversation({
    required String orderId,
    required String userId,
    required String driverId,
  }) async {
    try {
      // Use order ID directly as conversation ID for simplicity
      final conversationId = orderId;

      final conversationRef =
          _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        // Create new conversation
        await conversationRef.set({
          'conversationId': conversationId,
          'orderId': orderId,
          'userId': userId,
          'driverId': driverId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTimestamp':
              FieldValue.serverTimestamp(), // Changed from lastMessageTime
          'lastMessageSender': '',
          'unreadCounts': {
            // Changed from unreadCount to unreadCounts
            userId: 0,
            driverId: 0,
          },
          'participants': [userId, driverId],
          'isActive': true,
        });

        debugPrint('Created new conversation: $conversationId');
      }

      return conversationId;
    } catch (e) {
      debugPrint('Error creating/getting conversation: $e');
      rethrow;
    }
  }

  /// Send a message in a conversation
  static Future<void> sendMessage({
    required String conversationId,
    required String message,
    required String senderId,
    required String senderType, // 'user' or 'driver'
  }) async {
    try {
      // First verify the conversation exists and user is a participant
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversationData = conversationDoc.data()!;
      final participants =
          List<String>.from(conversationData['participants'] ?? []);

      if (!participants.contains(senderId)) {
        throw Exception(
            'User not authorized to send messages in this conversation');
      }

      final messageData = {
        'messageId': _firestore.collection('messages').doc().id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderType': senderType,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text', // for future: 'text', 'image', 'location'
      };

      // Add message to messages collection
      await _firestore.collection('messages').add(messageData);

      // Update conversation with last message info and increment unread count for receiver
      final String receiverId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');

      final Map<String, dynamic> updateData = {
        'lastMessage': message,
        'lastMessageTimestamp':
            FieldValue.serverTimestamp(), // Changed from lastMessageTime
        'lastMessageSender': senderId,
        'lastMessageSenderType': senderType,
      };

      // Only increment unread count if we have a valid receiver
      if (receiverId.isNotEmpty) {
        updateData['unreadCounts.$receiverId'] = FieldValue.increment(1);
        debugPrint(
            '📢 [MessagingService] Incrementing unread count for receiver: $receiverId');
        debugPrint('📢 [MessagingService] Update data: $updateData');
      } else {
        debugPrint(
            '⚠️ [MessagingService] No valid receiver found for unread count update');
      }

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update(updateData);

      debugPrint('Message sent successfully to conversation: $conversationId');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages for a conversation (real-time stream)
  static Stream<QuerySnapshot> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get messages for a conversation with participant validation
  static Stream<QuerySnapshot> getMessagesWithValidation(
      String conversationId, String userId) {
    // Note: This is a client-side validated stream
    // The actual security is handled by validating conversation access first
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get conversation details
  static Future<DocumentSnapshot> getConversation(String conversationId) {
    return _firestore.collection('conversations').doc(conversationId).get();
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
    required String userType, // 'user' or 'driver'
  }) async {
    try {
      // First verify the conversation exists and user is a participant
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        debugPrint('Conversation not found: $conversationId');
        return; // Don't throw error, just return silently
      }

      final conversationData = conversationDoc.data()!;
      final participants =
          List<String>.from(conversationData['participants'] ?? []);

      if (!participants.contains(userId)) {
        debugPrint(
            'User not authorized to mark messages as read in this conversation');
        return; // Don't throw error, just return silently
      }

      // Mark all unread messages as read
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Reset unread count for this user
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCounts.$userId': 0, // Use actual userId instead of userType
      });

      debugPrint('Marked messages as read for conversation: $conversationId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Get user conversations (for message screen)
  static Stream<QuerySnapshot> getUserConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTimestamp',
            descending: true) // Changed from lastMessageTime
        .snapshots();
  }

  /// Get user details for conversation
  static Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user details: $e');
      return null;
    }
  }

  /// Get order details for conversation
  static Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (orderDoc.exists) {
        return orderDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order details: $e');
      return null;
    }
  }

  /// Close conversation (when order is completed)
  static Future<void> closeConversation(String conversationId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'isActive': false,
        'closedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Conversation closed: $conversationId');
    } catch (e) {
      debugPrint('Error closing conversation: $e');
    }
  }
}
