/**
 * Maps an object to a new object with the same keys, but values are
 * mapped using the provided mapper function.
 * @param object
 * @param mapper
 */
export function mapProperties<K extends string, V, T>(
	object: Readonly<Record<K, undefined | V>>,
	mapper: (value: V, key: K) => T | undefined,
): Readonly<Partial<Record<K, T>>>;

export function mapProperties<K extends string, V, T>(
	object: Readonly<Record<K, V>>,
	mapper: (value: V, key: K) => T,
): Readonly<Record<K, T>>;

export function mapProperties<K extends string, V, T>(
	object: Readonly<Record<K, undefined | V>>,
	mapper: (value: V, key: K) => T | undefined,
): Readonly<Partial<Record<K, T>>> {
	const result: Partial<Record<K, T>> = {};

	for (const [key, value] of object as unknown as Map<K, V>) {
		result[key] = mapper(value, key);
	}

	return result;
}

/**
 * Replaces a property on an object with a new value. Only changes the
 * property if the value is not undefined.
 * @param object
 * @param key
 * @param mapper
 */
export function mapProperty<T extends object, K extends keyof T>(
	object: T,
	key: K,
	mapper: (value: NonNullable<T[K]>) => T[K] | undefined,
): T {
	if (object[key] !== undefined) {
		const copy = table.clone(object);
		copy[key] = mapper(object[key]!)!;
		return copy;
	}

	return object;
}

/**
 * Creates a new array of values given a length and a mapper function.
 * @param length
 * @param mapper
 */
export function fillArray<T extends defined>(length: number, mapper: (index: number) => T): Array<T> {
	return new Array(length, 0).map((_, index) => mapper(index));
}

/**
 * Clones the first object and merges the second object into it. Useful
 * for creating a new object without iterating over the first object.
 * @param object
 * @param patch
 */
export function assign<K extends string, V>(object: Record<K, V>, patch: Record<K, V>): Record<K, V> {
	const result = table.clone(object);

	for (const [key, value] of patch as unknown as Map<K, V>) {
		result[key] = value;
	}

	return result;
}

/**
 * Returns a shuffled copy of the given array.
 * @param array
 */
export function shuffle<T extends defined>(array: Array<T>): Array<T> {
	const result = table.clone(array);
	const random = new Random();

	for (const index of $range(result.size() - 1, 1, -1)) {
		const randomIndex = random.NextInteger(0, index);
		const temporary = result[index];
		result[index] = result[randomIndex];
		result[randomIndex] = temporary;
	}

	return result;
}

export function countProperties(object: object): number {
	let size = 0;

	for (const _ of pairs(object)) {
		size += 1;
	}

	return size;
}
