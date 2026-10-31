import '../entities/braille_cell.dart';

/// Every piece of text the app vibrates flows through this interface.
///
/// The default implementation is [BrailleTranslator]. An `AgentTextProcessor`
/// can later wrap it (decorator): summarise / simplify the text via the LLM,
/// then delegate to the inner translator for the actual Braille mapping.
abstract interface class ITextProcessor {
  Future<BrailleDocument> process(String input);
}
