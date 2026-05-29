import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxmybill/Colors.dart';

class AiChatPage extends StatefulWidget {
  final String uid;
  final String role;

  const AiChatPage({super.key, this.uid = '', this.role = 'staff'});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final List<_ChatMessage> _messages = [];
  final ScrollController _chatScrollController = ScrollController();
  int _botReplyCount = 0;
  bool _isResettingChat = false;
  bool _awaitingHelpfulFeedback = false;
  String _activeTopic = 'general';

  static const int _helpfulnessPromptThreshold = 3;

  final List<String> _starterPrompts = const [
    'How to increase daily sales?',
    'How to reduce credit dues?',
    'Best way to track expenses?',
    'How to improve staff billing speed?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            'Hi! I am your business assistant. Tap a suggestion or ask me anything about sales, dues, expenses, or staff workflow.',
        isBot: true,
      ),
    );
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    super.dispose();
  }

  List<String> get _activePrompts => _buildPromptsForTopic(_activeTopic);

  String _topicFromText(String input) {
    final query = input.toLowerCase();
    if (query.contains('sales') ||
        query.contains('customer') ||
        query.contains('repeat'))
      return 'sales';
    if (query.contains('credit') ||
        query.contains('due') ||
        query.contains('collection'))
      return 'credit';
    if (query.contains('expense') ||
        query.contains('stock') ||
        query.contains('purchase'))
      return 'expense';
    if (query.contains('staff') ||
        query.contains('billing') ||
        query.contains('bill'))
      return 'staff';
    if (query.contains('report')) return 'report';
    return 'general';
  }

  List<String> _buildPromptsForTopic(String topic) {
    switch (topic) {
      case 'sales':
        return const [
          'How can I increase repeat customers?',
          'Which product should I push more?',
          'How do I offer better discounts?',
          'How do I convert walk-ins faster?',
        ];
      case 'credit':
        return const [
          'How can I follow up overdue customers?',
          'When should I send payment reminders?',
          'How do I reduce pending dues?',
          'How can I handle slow-paying customers?',
        ];
      case 'expense':
        return const [
          'How do I reduce waste and extra spending?',
          'Which expenses should I review weekly?',
          'How can I track stock purchase better?',
          'How do I control supplier costs?',
        ];
      case 'staff':
        return const [
          'How do I make billing faster?',
          'How can staff avoid billing mistakes?',
          'How do I train new staff quickly?',
          'How can I assign better roles?',
        ];
      case 'report':
        return const [
          'Which report should I open first?',
          'How do I read daily sales trends?',
          'How can I check overdue credit?',
          'How do I use reports to improve profit?',
        ];
      default:
        return _starterPrompts;
    }
  }

  void _showHelpfulPrompt() {
    if (_awaitingHelpfulFeedback || _isResettingChat) return;
    setState(() {
      _awaitingHelpfulFeedback = true;
      _messages.add(const _ChatMessage(text: 'Was I helpful?', isBot: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _resetChatSession() {
    if (_isResettingChat) return;
    _isResettingChat = true;
    _awaitingHelpfulFeedback = false;
    _activeTopic = 'general';
    setState(() {
      _messages.add(
        const _ChatMessage(
          text: 'This chat is complete. Starting a new chat now...',
          isBot: true,
        ),
      );
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..add(
            const _ChatMessage(
              text:
                  'New chat started. Tap a suggestion below and I will help with your business.',
              isBot: true,
            ),
          );
        _botReplyCount = 0;
        _isResettingChat = false;
        _awaitingHelpfulFeedback = false;
        _activeTopic = 'general';
      });
      _scrollToBottom();
    });
  }

  void _sendMessage(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty || _isResettingChat) return;

    if (_awaitingHelpfulFeedback) {
      _handleHelpfulFeedback(text);
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
    });
    _scrollToBottom();
    _activeTopic = _topicFromText(text);

    final reply = _buildBotReply(text);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: reply, isBot: true));
        _botReplyCount++;
      });
      _scrollToBottom();
      if (_botReplyCount >= _helpfulnessPromptThreshold) {
        _showHelpfulPrompt();
      }
    });
  }

  void _handleHelpfulFeedback(String answer) {
    final normalized = answer.trim().toLowerCase();

    if (normalized == 'yes') {
      setState(() {
        _messages.add(const _ChatMessage(text: 'Yes', isBot: false));
      });
      _scrollToBottom();
      _resetChatSession();
      return;
    }

    if (normalized == 'no') {
      setState(() {
        _messages.add(const _ChatMessage(text: 'No', isBot: false));
        _messages.add(
          const _ChatMessage(
            text: 'No problem — here are more questions you can try.',
            isBot: true,
          ),
        );
        _botReplyCount = 0;
        _awaitingHelpfulFeedback = false;
        _activeTopic = 'general';
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: answer, isBot: false));
      _messages.add(
        const _ChatMessage(text: 'Please tap Yes or No below.', isBot: true),
      );
    });
    _scrollToBottom();
  }

  String _buildBotReply(String input) {
    final query = input.toLowerCase();

    if (query.contains('sales')) {
      return 'Try this: 1) Follow up old customers weekly, 2) use quotation for big-value customers, 3) push fast-moving items near billing counter, and 4) track top 10 products every evening.';
    }

    if (query.contains('credit') || query.contains('due')) {
      return 'For dues: 1) set clear due date while billing, 2) call customers 2 days before due date, 3) review Credit & Dues every morning, and 4) reduce credit limit for slow-paying customers.';
    }

    if (query.contains('expense')) {
      return 'To control expenses: record every spend on the same day, use categories properly, check weekly category totals, and compare expense trend with last month before reordering stock.';
    }

    if (query.contains('staff') || query.contains('team')) {
      return 'For staff performance: assign clear billing roles, track bills per staff daily, train shortcuts for common items, and review mistakes once per week with quick feedback.';
    }

    if (query.contains('report')) {
      return 'Use reports daily in this order: sales summary -> unsettled credit -> top products -> expense trend. This gives fast insight for next-day action.';
    }

    return 'Good question. I can help with sales growth, credit collection, expense control, and report-based actions. Try asking with keywords like sales, credit, expenses, staff, or report.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MAXX AI',
          style: TextStyle(
            color: kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final bubbleColor = msg.isBot ? kWhite : kPrimaryColor;
                final textColor = msg.isBot ? kBlack87 : kWhite;

                return Align(
                  alignment: msg.isBot
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(color: textColor, fontSize: 13.5),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Suggested Questions',
                      style: TextStyle(
                        color: kBlack54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_awaitingHelpfulFeedback)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _sendMessage('yes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A853),
                              foregroundColor: kWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Yes'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _sendMessage('no'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA4335),
                              foregroundColor: kWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('No'),
                          ),
                        ),
                      ],
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activePrompts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final prompt = _activePrompts[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _sendMessage(prompt),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kGrey200),
                            ),
                            child: Text(
                              prompt,
                              style: const TextStyle(
                                color: kBlack87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6AE00)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFE6AE00),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Chat box coming soon',
                          style: TextStyle(
                            color: Color(0xFFB8860B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;

  const _ChatMessage({required this.text, required this.isBot});
}
