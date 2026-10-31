/// Placeholder for the external LLM agent.
///
/// Planned uses:
///  * summarise long texts before they are vibrated (via an AgentTextProcessor
///    that wraps BrailleTranslator behind ITextProcessor);
///  * read the learner's analytics JSON (AnalyticsCalculator.exportJson) and
///    suggest HapticProfileModel speed changes (HapticProfileModel.scaled).
class AgentService {
  // TODO: Integrate REST/WebSocket for AI agent communication.
}
