import { greet } from "@fedegarcia/playground-a";

/**
 * Builds an uppercase greeting, reusing the peer package.
 */
export function shout(name: string): string {
  return greet(name).toUpperCase();
}
