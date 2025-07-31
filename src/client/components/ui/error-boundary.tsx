import type { ErrorInfo } from "@rbxts/react";
import type React from "@rbxts/react";
import { Component, ReactComponent } from "@rbxts/react";

interface ErrorBoundaryProps {
	fallback: (error: unknown) => React.Element;
}

interface ErrorBoundaryState {
	hasError: boolean;
	message?: unknown;
}

@ReactComponent
export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
	public state: ErrorBoundaryState = {
		hasError: false,
	};

	public componentDidCatch(message: unknown, info: ErrorInfo) {
		warn(message, info.componentStack);

		this.setState({
			hasError: true,
			message: `${message} ${info.componentStack}`,
		});
	}

	public render() {
		if (this.state.hasError) {
			return this.props.fallback(this.state.message);
		}

		return this.props.children;
	}
}
