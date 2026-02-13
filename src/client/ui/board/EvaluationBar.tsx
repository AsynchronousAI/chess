import React, {
  useEffect,
  useState,
  forwardRef,
  useImperativeHandle,
} from "@rbxts/react";
import { useMotion } from "@rbxts/pretty-react-hooks";
import { usePx } from "../hooks/usePx";
import { useFlameworkDependency } from "@rbxts/flamework-react-utils";
import { Gameplay } from "client/controllers/gameplay";
import { RunService } from "@rbxts/services";
import { BitBoard } from "shared/engine/bitboard";

export interface EvaluationBarProps {
  size: UDim2;
  position: UDim2;
  analysis: string;
}

export interface EvaluationBarRef {
  setEval: (value: number) => void;
  setMate: (value: number) => void;
}

export const EvaluationBar = forwardRef<EvaluationBarRef, EvaluationBarProps>(
  (props, ref) => {
    const gameplay = RunService.IsRunning()
      ? useFlameworkDependency<Gameplay>()
      : undefined;
    const board = gameplay?.useBoard() ?? BitBoard.create();
    const px = usePx();

    const [evaluation, setEval] = useState(0);
    const [mate, setMate] = useState(0);
    const [evalBar, evalBarMotion] = useMotion(0.5);
    const [evalText, setEvalText] = useState("");

    useImperativeHandle(ref, () => ({
      setEval,
      setMate,
    }));

    useEffect(() => {
      if (props.analysis === "stalemate" || props.analysis === "insufficent") {
        evalBarMotion.spring(0.5);
        setEval(-1);
        setEvalText("1/2");
      } else if (props.analysis === "checkmate") {
        /* checkmate */
        evalBarMotion.spring(mate > 0 ? 0 : 1);
        setEval(mate > 0 ? 1 : -1);
        setEvalText(mate > 0 ? "1-0" : "0-1");
      } else if (mate > 0) {
        /* black mate */
        evalBarMotion.spring(0);
        setEval(1);
        setEvalText(`M${mate - 1}`);
      } else if (mate < 0) {
        /* white mate */
        evalBarMotion.spring(1);
        setEval(-1);
        setEvalText(`M${math.abs(mate - 2)}`);
      } else {
        /* midgame */
        const scale = 1500;
        const probability = 1 / (1 + math.pow(10, evaluation / scale));
        const mapped = math.min(math.max(probability, 0), 1);

        evalBarMotion.spring(mapped);
        setEvalText(
          string.format(
            "%.1f",
            (evaluation > 0 ? evaluation : 1 - evaluation) / 100,
          ),
        );
      }
    }, [evaluation, mate, board]);

    return (
      <frame
        Size={props.size}
        AnchorPoint={new Vector2(0.5, 0.5)}
        Position={props.position}
        BackgroundColor3={Color3.fromHex("#403E39")}
        BorderSizePixel={0}
      >
        <uicorner CornerRadius={new UDim(0, px(2))} />
        <frame
          Size={evalBar.map((value) => new UDim2(1, 0, value, 0))}
          Position={evalBar.map((value) => new UDim2(0, 0, 1 - value, 0))}
          BackgroundColor3={new Color3(1, 1, 1)}
          BorderSizePixel={0}
        />
        <textlabel
          Size={new UDim2(1, 0, 0, px(20))}
          Text={evalText}
          BackgroundTransparency={1}
          TextColor3={
            evaluation <= 0 ? new Color3(0.45, 0.45, 0.45) : new Color3(1, 1, 1)
          }
          Font={Enum.Font.SourceSansBold}
          TextSize={px(14)}
          Position={
            evaluation <= 0
              ? new UDim2(0, 0, 1, -px(25))
              : new UDim2(0, 0, 0, px(2))
          }
        />
      </frame>
    );
  },
);
