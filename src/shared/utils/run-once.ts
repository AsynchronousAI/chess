/**
 * Wraps a function so that it can only be called once.
 * Subsequent calls will not execute the function.
 * @param callback
 */
export function runOnce<Args extends Array<unknown>, Result>(callback: (...args: Args) => Result) {
	let result: Result;
	let ran = false;

	return (...args: Args): Result => {
		if (!ran) {
			ran = true;
			result = callback(...args);
		}

		return result;
	};
}
