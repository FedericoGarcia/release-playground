/**
 * Builds a greeting for the given name, ignoring surrounding whitespace.
 */
export function greet(name: string): string {
  return `Hello, ${name.trim()}`;
}

/**
 * Builds a farewell for the given name.
 */
export function farewell(name: string): string {
  return `Goodbye, ${name}`;
}
