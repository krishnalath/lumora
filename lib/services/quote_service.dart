import 'dart:math';

class QuoteService {
  static final List<Map<String, String>> _quotes = [
    {
      'text': 'The only way to do great work is to love what you do.',
      'author': 'Steve Jobs'
    },
    {
      'text': 'It always seems impossible until it is done.',
      'author': 'Nelson Mandela'
    },
    {
      'text': 'Success is not final, failure is not fatal: it is the courage to continue that counts.',
      'author': 'Winston Churchill'
    },
    {
      'text': 'You are never too old to set another goal or to dream a new dream.',
      'author': 'C.S. Lewis'
    },
    {
      'text': 'The future belongs to those who believe in the beauty of their dreams.',
      'author': 'Eleanor Roosevelt'
    },
    {
      'text': 'Believe you can and you are halfway there.',
      'author': 'Theodore Roosevelt'
    },
    {
      'text': 'Act as if what you do makes a difference. It does.',
      'author': 'William James'
    },
    {
      'text': 'Don\'t watch the clock; do what it does. Keep going.',
      'author': 'Sam Levenson'
    },
    {
      'text': 'Start where you are. Use what you have. Do what you can.',
      'author': 'Arthur Ashe'
    },
    {
      'text': 'Peace is not the absence of trouble, but the presence of God.',
      'author': 'UNKNOWN'
    },
  ];

  static Future<Map<String, String>> fetchRandomQuote() async {
    // Simulate a tiny network delay for the loading animation effect
    await Future.delayed(const Duration(milliseconds: 500));
    
    final random = Random();
    final index = random.nextInt(_quotes.length);
    return _quotes[index];
  }
}
