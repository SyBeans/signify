// Complete mapping of the 105 FSL labels to Filipino
const Map<String, String> englishToFilipino = {
  // Greetings & Basics
  'GOOD MORNING': 'Magandang umaga',
  'GOOD AFTERNOON': 'Magandang hapon',
  'GOOD EVENING': 'Magandang gabi',
  'HELLO': 'Kumusta',
  'HOW ARE YOU': 'Kumusta ka?',
  'IM FINE': 'Mabuti naman ako',
  'NICE TO MEET YOU': 'Kinagagalak kong makilala ka',
  'THANK YOU': 'Salamat',
  'YOURE WELCOME': 'Walang anuman',
  'SEE YOU TOMORROW': 'Kita tayo bukas',

  // Understanding & Responses
  'UNDERSTAND': 'Naiintindihan',
  'DON’T UNDERSTAND': 'Hindi naiintindihan', // Curly apostrophe
  'DON\'T UNDERSTAND': 'Hindi naiintindihan', // Straight apostrophe
  'KNOW': 'Alam',
  'DON’T KNOW': 'Hindi alam',
  'DON\'T KNOW': 'Hindi alam',
  'NO': 'Hindi',
  'YES': 'Oo',
  'WRONG': 'Mali',
  'CORRECT': 'Tama',
  'SLOW': 'Mabagal',
  'FAST': 'Mabilis',

  // Numbers
  'ONE': 'Isa', 'TWO': 'Dalawa', 'THREE': 'Tatlo', 'FOUR': 'Apat',
  'FIVE': 'Lima', 'SIX': 'Anim', 'SEVEN': 'Pito', 'EIGHT': 'Walo',
  'NINE': 'Siyam', 'NINE ': 'Siyam', 'TEN': 'Sampu',

  // Months
  'JANUARY': 'Enero', 'FEBRUARY': 'Pebrero', 'MARCH': 'Marso', 'APRIL': 'Abril',
  'MAY': 'Mayo', 'JUNE': 'Hunyo', 'JULY': 'Hulyo', 'AUGUST': 'Agosto',
  'SEPTEMBER': 'Setyembre',
  'OCTOBER': 'Oktubre',
  'NOVEMBER': 'Nobyembre',
  'DECEMBER': 'Disyembre',

  // Days
  'MONDAY': 'Lunes',
  'TUESDAY': 'Martes',
  'WEDNESDAY': 'Miyerkules',
  'THURSDAY': 'Huwebes',
  'FRIDAY': 'Biyernes', 'SATURDAY': 'Sabado', 'SUNDAY': 'Linggo',
  'TODAY': 'Ngayon', 'TOMORROW': 'Bukas', 'YESTERDAY': 'Kahapon',

  // Family
  'FATHER': 'Tatay',
  'MOTHER': 'Nanay',
  'SON': 'Anak na lalaki',
  'DAUGHTER': 'Anak na babae',
  'GRANDFATHER': 'Lolo',
  'GRANDMOTHER': 'Lola',
  'UNCLE': 'Tito',
  'AUNTIE': 'Tita',
  'COUSIN': 'Pinsan', 'PARENTS': 'Mga magulang',

  // People
  'BOY': 'Batang lalaki',
  'GIRL': 'Batang babae',
  'MAN': 'Lalaki',
  'WOMAN': 'Babae',
  'DEAF': 'Bingi',
  'HARD OF HEARING': 'Mahina ang pandinig',
  'WEELCHAIR PERSON': 'Taong may wheelchair',
  'BLIND': 'Bulag', 'DEAF BLIND': 'Bingi at bulag', 'MARRIED': 'Kasal',

  // Colors
  'BLUE': 'Asul', 'GREEN': 'Berde', 'RED': 'Pula', 'BROWN': 'Kayumanggi',
  'BLACK': 'Itim', 'WHITE': 'Puti', 'YELLOW': 'Dilaw', 'ORANGE': 'Kahel',
  'GRAY': 'Kulay-abo',
  'PINK': 'Rosas',
  'VIOLET': 'Lila',
  'LIGHT': 'Maliwanag',
  'DARK': 'Madilim',

  // Food & Drinks
  'BREAD': 'Tinapay', 'EGG': 'Itlog', 'FISH': 'Isda', 'MEAT': 'Karne',
  'CHICKEN': 'Manok', 'SPAGHETTI': 'Spaghetti', 'RICE': 'Kanin',
  'LONGANISA': 'Longganisa', 'SHRIMP': 'Hipon', 'CRAB': 'Alimango',
  'HOT': 'Mainit', 'COLD': 'Malamig', 'JUICE': 'Katas', 'MILK': 'Gatas',
  'COFFEE': 'Kape', 'TEA': 'Tsaa', 'BEER': 'Serbesa', 'WINE': 'Alak',
  'SUGAR': 'Asukal', 'NO SUGAR': 'Walang asukal',
};

// Bulletproof lookup function
String getFilipino(String englishLabel) {
  // 1. Normalize curly apostrophes to straight
  String normalized = englishLabel.replaceAll('’', "'").trim().toUpperCase();

  // 2. Exact match
  if (englishToFilipino.containsKey(normalized)) {
    return englishToFilipino[normalized]!;
  }

  // 3. Fallback loop (in case of trailing spaces in the map keys)
  for (final entry in englishToFilipino.entries) {
    final key = entry.key.replaceAll('’', "'").trim().toUpperCase();
    if (key == normalized) return entry.value;
  }

  return englishLabel; // Return original if truly not found
}
