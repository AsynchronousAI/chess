import Charm, { Atom, subscribe } from "@rbxts/charm";

type ConstructorArgs<T> = T extends new (...args: infer U) => unknown
  ? U
  : never;
type InferSignalArguments<T> =
  T extends RBXScriptSignal<(...args: infer U) => unknown> ? U : never;
type CallbackBindable<
  F extends (...args: any[]) => any = (...args: any[]) => any,
> = {
  setCallback: (this: CallbackBindable<F>, callback: F) => void;
};
export interface Connectable<T extends unknown[] = unknown[]> {
  Connect?(callback: (...args: T) => void): unknown;
  connect?(callback: (...args: T) => void): unknown;
}

/** @metadata macro */
export function Event<T extends Connectable>(event?: T) {
  /* For flamework */
  assert(event);
  return (
    ctor: Record<any, any>,
    methodName: string,
    _: TypedPropertyDescriptor<(...args: InferSignalArguments<T>) => void>,
  ) => {
    const old = ctor.constructor as (
      instance: object,
      ...args: ConstructorArgs<T>
    ) => object;
    const method = ctor[methodName] as (
      self: object,
      ...args: InferSignalArguments<T>
    ) => void;

    ctor.constructor = function (this: object, ...args: ConstructorArgs<T>) {
      const instance = old(this, ...args);

      if (event["Connect"] !== undefined) {
        event.Connect((...eventArgs) =>
          method(this, ...(eventArgs as InferSignalArguments<T>)),
        );
      } else if (event["connect"] !== undefined) {
        event.connect((...eventArgs) =>
          method(this, ...(eventArgs as InferSignalArguments<T>)),
        );
      }

      return instance;
    };
  };
}

/** @metadata macro */
export function Function<T extends CallbackBindable>(event?: T) {
  assert(event);

  return (
    ctor: Record<any, any>,
    methodName: string,
    _: TypedPropertyDescriptor<(...args: InferSignalArguments<T>) => void>,
  ) => {
    const originalConstructor = ctor.constructor as (
      instance: object,
      ...args: ConstructorArgs<T>
    ) => object;
    const method = ctor[methodName] as (
      self: object,
      ...args: InferSignalArguments<T>
    ) => void;

    ctor.constructor = function (this: object, ...args: ConstructorArgs<T>) {
      const instance = originalConstructor(this, ...args);
      event.setCallback((...eventArgs) => {
        return method(this, ...(eventArgs as InferSignalArguments<T>));
      });
      return instance;
    };
  };
}

/** @metadata macro */
type AtomArguments<T> = [state: T, prev: T];
export function Atom<T>(event?: Charm.Atom<T>) {
  assert(event);

  return (
    ctor: Record<any, any>,
    methodName: string,
    _: TypedPropertyDescriptor<(...args: InferSignalArguments<T>) => void>,
  ) => {
    const originalConstructor = ctor.constructor as (
      instance: object,
      ...args: ConstructorArgs<T>
    ) => object;
    const method = ctor[methodName] as (
      self: object,
      ...args: AtomArguments<T>
    ) => void;

    ctor.constructor = function (this: object, ...args: ConstructorArgs<T>) {
      const instance = originalConstructor(this, ...args);
      subscribe(event, (...eventArgs) => {
        return method(this, ...eventArgs);
      });
      return instance;
    };
  };
}
