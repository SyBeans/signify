class Phrase {
  final String english;
  final String filipino;
  final String category;
  const Phrase(this.english, this.filipino, this.category);
}

const List<Phrase> phrasebookData = [
  Phrase('I need help!', 'Kailangan ko ng tulong!', 'Emergency'),
  Phrase('Call a doctor!', 'Tumawag ng doktor!', 'Emergency'),
  Phrase("There's an emergency!", 'May emergency!', 'Emergency'),
  Phrase('Call the police!', 'Tumawag ng pulis!', 'Emergency'),

  Phrase('Good day', 'Magandang araw', 'Greetings'),
  Phrase('I am Jonathan', 'Ako si Jonathan', 'Greetings'),
  Phrase('Good morning', 'Magandang umaga', 'Greetings'),
  Phrase('Thank you', 'Salamat', 'Greetings'),
  Phrase('You are welcome', 'Walang anuman', 'Greetings'),

  Phrase('My stomach hurts', 'Masakit ang tiyan ko', 'Medical'),
  Phrase('I need medicine', 'Kailangan ko ng gamot', 'Medical'),
  Phrase('I have a fever', 'May lagnat ako', 'Medical'),
  Phrase('Where is the hospital?', 'Nasaan ang ospital?', 'Medical'),

  Phrase('Where is the bus stop?', 'Saan ang paradahan?', 'Travel'),
  Phrase('How much is this?', 'Magkano ito?', 'Travel'),
  Phrase('Where is the CR?', 'Nasaan ang CR?', 'Travel'),

  Phrase('I am hungry', 'Nagugutom ako', 'Food'),
  Phrase('Water please', 'Tubig po', 'Food'),
  Phrase('More rice please', 'Dagdag kanin po', 'Food'),

  Phrase('I do not understand', 'Hindi ko maintindihan', 'School'),
  Phrase('Please repeat', 'Pakiulit po', 'School'),
];
