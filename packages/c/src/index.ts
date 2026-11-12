/**
 * Counts the words in a sentence, splitting on whitespace.
 */
export function countWords(sentence: string): number {
  const trimmed = sentence.trim();
  return trimmed === "" ? 0 : trimmed.split(/\s+/).length;
}
